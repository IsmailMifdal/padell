import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  BookingSource,
  BookingStatus,
  CourtType,
  MatchStatus,
  PaymentMethod,
  PaymentMode,
  PaymentStatus,
  Prisma,
  Role,
  User,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { randomBytes, randomInt } from 'node:crypto';
import { PrismaService } from '../../infra/prisma/prisma.service';

/** Domaine des comptes de démonstration (joueurs, propriétaires, invités). */
export const DEMO_DOMAIN = '@demo.padel.ma';
const GUEST_PREFIX = 'invite-';
const GUEST_TTL_DAYS = 7;
const REFRESH_DAYS_AHEAD = 14;
const MOROCCO_UTC_OFFSET_MIN = 60;
const SLOT_MIN = 90;
const SLOTS = Array.from({ length: 10 }, (_, i) => 480 + SLOT_MIN * i); // 08:00 → 21:30
const SCORES = ['6-4, 6-3', '7-5, 6-4', '4-6, 6-3, 6-2', '6-2, 6-1', '7-6, 6-4'];

// Aléatoire de crypto (pas Math.random) : aucun enjeu de sécurité ici, mais un seul générateur partout.
type DemoCourt = { id: string; clubId: string; type: CourtType };
type DemoPlayer = { id: string; level: number };
type Slot = { courtId: string; clubId: string; start: Date; end: Date; price: number };

const pick = <T>(items: readonly T[]): T => items[randomInt(items.length)];
const chance = (probability: number): boolean => randomInt(1_000_000) < probability * 1_000_000;
/** n éléments distincts tirés au hasard (Fisher-Yates partiel). */
const sample = <T>(items: readonly T[], n: number): T[] => {
  const copy = [...items];
  for (let i = 0; i < Math.min(n, copy.length); i++) {
    const j = i + randomInt(copy.length - i);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, n);
};

/**
 * Mode démo (DEMO_MODE=true), pour une vitrine de portfolio :
 * - compte invité par visiteur, déjà rempli (POST /auth/demo) ;
 * - remplissage automatique de tout compte joueur vide à la connexion ;
 * - chaque nuit : réservations et matchs à venir régénérés, comptes invités expirés supprimés.
 * Les clubs et joueurs de démo sont ceux dont l'email se termine par DEMO_DOMAIN.
 */
@Injectable()
export class DemoService {
  private readonly logger = new Logger(DemoService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  get enabled(): boolean {
    return this.config.get<string>('DEMO_MODE') === 'true';
  }

  /** Compte invité jetable, rempli de données ; supprimé après GUEST_TTL_DAYS. */
  async createGuest(): Promise<User> {
    const suffix = randomBytes(4).toString('hex');
    const user = await this.prisma.user.create({
      data: {
        email: `${GUEST_PREFIX}${suffix}${DEMO_DOMAIN}`,
        passwordHash: await bcrypt.hash(randomBytes(24).toString('hex'), 10),
        profile: {
          create: {
            firstName: 'Visiteur',
            lastName: suffix.slice(0, 4).toUpperCase(),
            city: 'Casablanca',
            level: 3.5,
            eloRating: 1200,
          },
        },
      },
    });
    await this.seedUser(user.id);
    return user;
  }

  /** Remplit un compte joueur qui n'a encore ni réservation ni match. Ne lève jamais. */
  async seedIfEmpty(user: Pick<User, 'id' | 'roles'>): Promise<void> {
    if (!this.enabled || user.roles.includes(Role.ADMIN)) return;
    try {
      const [bookings, matches] = await Promise.all([
        this.prisma.booking.count({ where: { bookedById: user.id } }),
        this.prisma.matchPlayer.count({ where: { playerId: user.id } }),
      ]);
      if (bookings + matches === 0) await this.seedUser(user.id);
    } catch (e) {
      this.logger.warn(`Remplissage démo impossible pour ${user.id} : ${String(e)}`);
    }
  }

  /** Profil, favoris, réservations passées et à venir, matchs, notes et notifications. */
  async seedUser(userId: string): Promise<void> {
    const courts = await this.demoCourts('Casablanca');
    const mates = (await this.demoPlayers()).filter((p) => p.level >= 2.5 && p.level <= 4.5);
    if (courts.length === 0 || mates.length < 3) {
      this.logger.warn('Données de plateforme de démo absentes : remplissage ignoré');
      return;
    }
    const clubIds = [...new Set(courts.map((c) => c.clubId))];
    await this.completeProfile(userId, clubIds);
    const mateIds = mates.map((m) => m.id);
    await this.seedPast(userId, courts, mateIds);
    await this.seedUpcoming(userId, courts, mateIds);
    await this.joinOpenMatches(userId, clubIds);
    await this.seedNotifications(userId);
    await this.refreshMatchesPlayed([userId]);
  }

  private async completeProfile(userId: string, clubIds: string[]): Promise<void> {
    const profile = await this.prisma.playerProfile.findUnique({ where: { userId } });
    if (profile) {
      await this.prisma.playerProfile.update({
        where: { userId },
        data: {
          city: profile.city ?? 'Casablanca',
          level: Number(profile.level) === 2 ? 3.5 : profile.level,
          handedness: profile.handedness ?? 'RIGHT',
          courtPosition: profile.courtPosition ?? 'LEFT',
        },
      });
    }
    await this.prisma.favoriteClub.createMany({
      data: clubIds.slice(0, 3).map((clubId) => ({ userId, clubId })),
      skipDuplicates: true,
    });
  }

  /** 6 réservations jouées, dont 4 matchs avec score et notes reçues, et 2 avis de club. */
  private async seedPast(userId: string, courts: DemoCourt[], mates: string[]): Promise<void> {
    for (const [i, dayOffset] of [-27, -21, -16, -11, -6, -3].entries()) {
      const slot = await this.freeSlot(courts, dayOffset);
      if (!slot) continue;
      const booking = await this.createBooking(userId, slot, BookingStatus.COMPLETED);
      if (i < 4) await this.seedPlayedMatch(userId, booking, slot, mates);
      if (i === 1 || i === 4) {
        await this.prisma.clubReview.create({
          data: { clubId: slot.clubId, bookingId: booking.id, userId, rating: 5, comment: 'Très bon club, terrains au top.' },
        });
      }
    }
  }

  private async seedPlayedMatch(userId: string, booking: { id: string }, slot: Slot, mates: string[]): Promise<void> {
    const team = sample(mates, 3);
    const winners = chance(0.6) ? [userId, team[0]] : team.slice(1);
    const match = await this.createMatch(userId, booking, slot, MatchStatus.PLAYED, team, {
      winnerIds: winners,
      score: pick(SCORES),
    });
    await this.prisma.rating.createMany({
      data: team.map((raterId) => ({
        matchId: match.id,
        raterId,
        ratedId: userId,
        punctuality: randomInt(4, 6),
        fairplay: randomInt(4, 6),
        levelAccuracy: randomInt(3, 6),
      })),
    });
  }

  /** Une réservation simple, un match confirmé, un match ouvert (avec demande), un paiement sur place. */
  private async seedUpcoming(userId: string, courts: DemoCourt[], mates: string[]): Promise<void> {
    const plan: Array<[number, 'single' | 'confirmed' | 'open' | 'onsite']> = [
      [1, 'single'],
      [2, 'confirmed'],
      [4, 'open'],
      [6, 'onsite'],
    ];
    for (const [dayOffset, kind] of plan) {
      const slot = await this.freeSlot(courts, dayOffset);
      if (!slot) continue;
      const mode = kind === 'onsite' ? PaymentMode.ON_SITE : PaymentMode.ONLINE;
      const booking = await this.createBooking(userId, slot, BookingStatus.CONFIRMED, mode);
      if (kind === 'confirmed') {
        await this.createMatch(userId, booking, slot, MatchStatus.CONFIRMED, sample(mates, 3));
      } else if (kind === 'open') {
        const [partner, requester] = sample(mates, 2);
        const match = await this.createMatch(userId, booking, slot, MatchStatus.OPEN, [partner]);
        await this.prisma.matchPlayer.create({
          data: { matchId: match.id, playerId: requester, status: 'REQUESTED' },
        });
      }
    }
  }

  /** Rejoint deux matchs ouverts d'autres joueurs (au moins 3 h avant le début). */
  private async joinOpenMatches(userId: string, clubIds: string[]): Promise<void> {
    const openMatches = await this.prisma.match.findMany({
      where: {
        status: MatchStatus.OPEN,
        startsAt: { gt: new Date(Date.now() + 3 * 3_600_000) },
        clubId: { in: clubIds },
        creatorId: { not: userId },
      },
      include: { players: { where: { status: 'ACCEPTED' } } },
      orderBy: { startsAt: 'asc' },
      take: 20,
    });
    const joinable = openMatches.filter((m) => m.players.length <= 2).slice(0, 2);
    await this.prisma.matchPlayer.createMany({
      data: joinable.map((m) => ({ matchId: m.id, playerId: userId, team: 2, status: 'ACCEPTED' as const })),
    });
  }

  private async seedNotifications(userId: string): Promise<void> {
    const items: Array<[string, string, string, boolean]> = [
      ['BOOKING_REMINDER', 'Rappel de réservation', 'Ton terrain t’attend demain. Arrive 10 min avant.', false],
      ['MATCH_JOIN_REQUEST', 'Nouvelle demande', 'Un joueur veut rejoindre ton match ouvert.', false],
      ['MATCH_FULL', 'Match complet', 'Ton match de padel est complet : 4 joueurs confirmés.', true],
      ['RATING_RECEIVED', 'Nouvelle note', 'Tes partenaires t’ont noté après ton dernier match.', true],
    ];
    await this.prisma.notification.createMany({
      data: items.map(([type, title, body, read]) => ({
        userId,
        type,
        title,
        body,
        data: { demo: true },
        readAt: read ? new Date() : null,
      })),
    });
  }

  /** Chaque nuit : la démo reste « vivante » (créneaux pris, matchs à venir) et les invités expirent. */
  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async nightly(): Promise<void> {
    if (!this.enabled) return;
    try {
      await this.closePastActivity();
      await this.fillUpcomingDays();
      await this.deleteExpiredGuests();
    } catch (e) {
      this.logger.error(`Rafraîchissement de la démo en échec : ${String(e)}`);
    }
  }

  /** Réservations et matchs passés des clubs de démo : terminés et joués, avec un score. */
  async closePastActivity(): Promise<void> {
    const now = new Date();
    const demoClub = { court: { club: { owner: { email: { endsWith: DEMO_DOMAIN } } } } };
    await this.prisma.booking.updateMany({
      where: { ...demoClub, status: BookingStatus.CONFIRMED, endsAt: { lt: now } },
      data: { status: BookingStatus.COMPLETED },
    });
    const played = await this.prisma.match.findMany({
      where: {
        status: MatchStatus.CONFIRMED,
        startsAt: { lt: now },
        club: { owner: { email: { endsWith: DEMO_DOMAIN } } },
      },
      include: { players: { where: { status: 'ACCEPTED' } } },
    });
    for (const match of played) {
      const ids = match.players.map((p) => p.playerId);
      const team1 = match.players.filter((p) => p.team === 1).map((p) => p.playerId);
      await this.prisma.match.update({
        where: { id: match.id },
        data: {
          status: MatchStatus.PLAYED,
          score: { winnerIds: chance(0.5) && team1.length ? team1 : ids.slice(2), score: pick(SCORES) },
        },
      });
    }
    await this.refreshMatchesPlayed(played.flatMap((m) => m.players.map((p) => p.playerId)));
  }

  /** Ajoute de l'activité de joueurs de démo sur les jours à venir qui n'en ont pas encore. */
  async fillUpcomingDays(): Promise<void> {
    const courts = await this.demoCourts();
    const players = await this.demoPlayers();
    if (courts.length === 0 || players.length < 4) return;
    for (let dayOffset = 0; dayOffset <= REFRESH_DAYS_AHEAD; dayOffset++) {
      const day = this.moroccoDay(dayOffset);
      for (const court of courts) {
        await this.fillCourtDay(court, day, players);
      }
    }
  }

  /** Remplit un terrain pour un jour sans aucune réservation (plus de monde le soir et le week-end). */
  private async fillCourtDay(court: DemoCourt, day: Date, players: DemoPlayer[]): Promise<void> {
    const existing = await this.prisma.booking.count({
      where: { courtId: court.id, startsAt: { gte: this.toUtc(day, 0), lt: this.toUtc(day, 24 * 60) } },
    });
    if (existing > 0) return;
    const weekend = day.getUTCDay() === 0 || day.getUTCDay() === 6;
    for (const startMin of SLOTS) {
      const slot = this.slotFor(court, day, startMin);
      const occupancy = weekend || startMin >= 1020 ? 0.6 : 0.28;
      if (slot.end <= new Date() || !chance(occupancy)) continue;
      const booker = pick(players);
      const booking = await this.createBooking(booker.id, slot, BookingStatus.CONFIRMED);
      if (chance(0.35)) await this.createOpenOrFullMatch(booker, booking, slot, players);
    }
  }

  private async createOpenOrFullMatch(
    booker: DemoPlayer,
    booking: { id: string },
    slot: Slot,
    players: DemoPlayer[],
  ): Promise<void> {
    const others = players.filter((p) => p.id !== booker.id && Math.abs(p.level - booker.level) <= 1);
    const team = sample(others, pick([0, 1, 2, 3, 3])).map((p) => p.id);
    const status = team.length === 3 ? MatchStatus.CONFIRMED : MatchStatus.OPEN;
    await this.createMatch(booker.id, booking, slot, status, team, undefined, booker.level);
  }

  /** Supprime les comptes invités plus vieux que GUEST_TTL_DAYS, avec toutes leurs données. */
  async deleteExpiredGuests(): Promise<number> {
    const guests = await this.prisma.user.findMany({
      where: {
        email: { startsWith: GUEST_PREFIX, endsWith: DEMO_DOMAIN },
        createdAt: { lt: new Date(Date.now() - GUEST_TTL_DAYS * 86_400_000) },
      },
      select: { id: true },
    });
    for (const { id } of guests) {
      const created = await this.prisma.match.findMany({ where: { creatorId: id }, select: { id: true } });
      const matchIds = created.map((m) => m.id);
      await this.prisma.$transaction([
        this.prisma.rating.deleteMany({
          where: { OR: [{ raterId: id }, { ratedId: id }, { matchId: { in: matchIds } }] },
        }),
        this.prisma.chatMessage.deleteMany({ where: { OR: [{ senderId: id }, { matchId: { in: matchIds } }] } }),
        this.prisma.matchPlayer.deleteMany({ where: { OR: [{ playerId: id }, { matchId: { in: matchIds } }] } }),
        this.prisma.match.deleteMany({ where: { id: { in: matchIds } } }),
        this.prisma.clubReview.deleteMany({ where: { OR: [{ userId: id }, { booking: { bookedById: id } }] } }),
        this.prisma.payment.deleteMany({ where: { OR: [{ userId: id }, { booking: { bookedById: id } }] } }),
        this.prisma.booking.deleteMany({ where: { bookedById: id } }),
        this.prisma.report.deleteMany({ where: { reporterId: id } }),
        this.prisma.user.delete({ where: { id } }),
      ]);
    }
    if (guests.length) this.logger.log(`${guests.length} compte(s) invité(s) expiré(s) supprimé(s)`);
    return guests.length;
  }

  // ----------------------------------------------------------------- interne

  private async demoCourts(city?: string): Promise<DemoCourt[]> {
    const courts = await this.prisma.court.findMany({
      where: {
        active: true,
        club: { status: 'APPROVED', ...(city ? { city } : {}), owner: { email: { endsWith: DEMO_DOMAIN } } },
      },
      select: { id: true, clubId: true, type: true },
    });
    return courts;
  }

  private async demoPlayers(): Promise<DemoPlayer[]> {
    const profiles = await this.prisma.playerProfile.findMany({
      where: { user: { email: { startsWith: 'joueur', endsWith: DEMO_DOMAIN } } },
      select: { userId: true, level: true },
    });
    return profiles.map((p) => ({ id: p.userId, level: Number(p.level) }));
  }

  /** Jour civil marocain (minuit UTC du jour) décalé de dayOffset jours. */
  private moroccoDay(dayOffset: number): Date {
    const local = new Date(Date.now() + MOROCCO_UTC_OFFSET_MIN * 60_000);
    return new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate() + dayOffset));
  }

  private toUtc(day: Date, minutes: number): Date {
    return new Date(day.getTime() + (minutes - MOROCCO_UTC_OFFSET_MIN) * 60_000);
  }

  private slotFor(court: DemoCourt, day: Date, startMin: number): Slot {
    const weekend = day.getUTCDay() === 0 || day.getUTCDay() === 6;
    const price =
      (weekend || startMin >= 1020 ? 400 : 300) + (court.type === CourtType.PANORAMIC ? 50 : 0);
    const start = this.toUtc(day, startMin);
    return { courtId: court.id, clubId: court.clubId, start, end: new Date(start.getTime() + SLOT_MIN * 60_000), price };
  }

  /** Créneau du soir sans réservation active (ni jouée) sur l'un des terrains donnés. */
  private async freeSlot(courts: DemoCourt[], dayOffset: number): Promise<Slot | null> {
    const day = this.moroccoDay(dayOffset);
    for (let attempt = 0; attempt < 60; attempt++) {
      const startMin = pick(SLOTS.filter((s) => s >= 1020));
      const slot = this.slotFor(pick(courts), day, startMin);
      const taken = await this.prisma.booking.findFirst({
        where: {
          courtId: slot.courtId,
          startsAt: { lt: slot.end },
          endsAt: { gt: slot.start },
          status: { in: [BookingStatus.PENDING_PAYMENT, BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
        },
        select: { id: true },
      });
      if (!taken) return slot;
    }
    return null;
  }

  private createBooking(
    userId: string,
    slot: Slot,
    status: BookingStatus,
    mode: PaymentMode = chance(0.6) ? PaymentMode.ONLINE : PaymentMode.ON_SITE,
  ) {
    const paid = status === BookingStatus.COMPLETED || mode === PaymentMode.ONLINE;
    return this.prisma.booking.create({
      data: {
        courtId: slot.courtId,
        bookedById: userId,
        startsAt: slot.start,
        endsAt: slot.end,
        priceMad: slot.price,
        status,
        source: BookingSource.APP,
        paymentMode: mode,
        qrCode: randomBytes(16).toString('hex'),
        ...(paid
          ? {
              payments: {
                create: {
                  userId,
                  amountMad: slot.price,
                  commissionMad: Math.round(slot.price * 10) / 100,
                  method: mode === PaymentMode.ONLINE ? PaymentMethod.CMI : PaymentMethod.ON_SITE,
                  status: PaymentStatus.PAID,
                },
              },
            }
          : {}),
      },
    });
  }

  private createMatch(
    creatorId: string,
    booking: { id: string },
    slot: Slot,
    status: MatchStatus,
    others: string[],
    score?: Prisma.InputJsonValue,
    level = 3.5,
  ) {
    return this.prisma.match.create({
      data: {
        creatorId,
        bookingId: booking.id,
        clubId: slot.clubId,
        startsAt: slot.start,
        durationMin: SLOT_MIN,
        levelMin: Math.max(1, level - 0.5),
        levelMax: Math.min(7, level + 0.5),
        pricePerPlayerMad: Math.round(slot.price * 25) / 100,
        status,
        score,
        players: {
          create: [creatorId, ...others].map((playerId, i) => ({
            playerId,
            team: i < 2 ? 1 : 2,
            status: 'ACCEPTED' as const,
          })),
        },
      },
    });
  }

  private async refreshMatchesPlayed(userIds: string[]): Promise<void> {
    for (const userId of new Set(userIds)) {
      const played = await this.prisma.matchPlayer.count({
        where: { playerId: userId, status: 'ACCEPTED', match: { status: MatchStatus.PLAYED } },
      });
      await this.prisma.playerProfile.updateMany({ where: { userId }, data: { matchesPlayed: played } });
    }
  }
}
