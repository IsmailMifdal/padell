import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  BookingStatus,
  MatchPlayerStatus,
  MatchStatus,
  MatchVisibility,
  PaymentMode,
  Prisma,
} from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { BookingsService } from '../bookings/bookings.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { RatePlayersDto, SubmitScoreDto } from './dto/score-rating.dto';
import { SearchMatchesQuery } from './dto/search-matches.query';

export const MATCH_SIZE = 4;
// Un match incomplet est annulé automatiquement 2 h avant le début
const AUTO_CANCEL_HOURS_BEFORE = 2;
// Désistement : remboursement intégral jusqu'à 24 h avant, rien ensuite
const WITHDRAW_FREE_HOURS = 24;

const PLAYER_PUBLIC_SELECT = {
  id: true,
  profile: {
    select: { firstName: true, lastName: true, avatarUrl: true, level: true },
  },
} as const;

@Injectable()
export class MatchesService {
  private readonly logger = new Logger(MatchesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly bookings: BookingsService,
    private readonly payments: PaymentsService,
    private readonly notifications: NotificationsService,
  ) {}

  // ---------------------------------------------------------------- création

  /**
   * Crée un match ouvert : le créneau est réservé (booking en attente de
   * paiement) et le créateur devient le premier participant. Il paie ensuite
   * sa part via POST /payments/matches/:id/session.
   */
  async create(user: AuthUser, dto: CreateMatchDto) {
    if (dto.levelMax < dto.levelMin) {
      throw new BadRequestException('levelMax doit être ≥ levelMin');
    }

    const booking = await this.bookings.create(user, {
      courtId: dto.courtId,
      startsAt: dto.startsAt,
      durationMin: dto.durationMin,
      paymentMode: PaymentMode.ONLINE,
    });

    const court = await this.prisma.court.findUniqueOrThrow({
      where: { id: dto.courtId },
      select: { clubId: true },
    });

    const pricePerPlayer =
      Math.round((Number(booking.priceMad) / MATCH_SIZE) * 100) / 100;

    return this.prisma.match.create({
      data: {
        creatorId: user.userId,
        bookingId: booking.id,
        clubId: court.clubId,
        startsAt: booking.startsAt,
        durationMin: dto.durationMin,
        levelMin: dto.levelMin,
        levelMax: dto.levelMax,
        visibility: dto.visibility ?? MatchVisibility.PUBLIC,
        pricePerPlayerMad: pricePerPlayer,
        players: {
          create: { playerId: user.userId, status: MatchPlayerStatus.ACCEPTED },
        },
      },
      include: { players: true },
    });
  }

  // --------------------------------------------------------------- recherche

  async search(query: SearchMatchesQuery) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    const where: Prisma.MatchWhereInput = {
      status: MatchStatus.OPEN,
      visibility: MatchVisibility.PUBLIC,
      startsAt: { gt: new Date() },
      ...(query.city
        ? { club: { city: { equals: query.city, mode: Prisma.QueryMode.insensitive } } }
        : {}),
    };
    if (query.date) {
      const [y, m, d] = query.date.split('-').map(Number);
      where.startsAt = { gte: new Date(y, m - 1, d), lt: new Date(y, m - 1, d + 1) };
    }

    // Recherche par géolocalisation : on retient d'abord les clubs dans le
    // rayon (PostGIS) puis on filtre les matchs sur ces clubs.
    let distanceByClub: Map<string, number> | null = null;
    if (query.lat !== undefined && query.lng !== undefined) {
      const radiusM = (query.radiusKm ?? 25) * 1000;
      const nearby = await this.prisma.$queryRaw<
        Array<{ id: string; distance_m: number }>
      >`
        SELECT c.id,
               ST_Distance(
                 ST_SetSRID(ST_MakePoint(c.longitude::float8, c.latitude::float8), 4326)::geography,
                 ST_SetSRID(ST_MakePoint(${query.lng}::float8, ${query.lat}::float8), 4326)::geography
               ) AS distance_m
        FROM clubs c
        WHERE c.status = 'APPROVED'
          AND ST_DWithin(
                ST_SetSRID(ST_MakePoint(c.longitude::float8, c.latitude::float8), 4326)::geography,
                ST_SetSRID(ST_MakePoint(${query.lng}::float8, ${query.lat}::float8), 4326)::geography,
                ${radiusM}
              )
      `;
      distanceByClub = new Map(nearby.map((r) => [r.id, Math.round(r.distance_m)]));
      where.clubId = { in: nearby.map((r) => r.id) };
    }

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.match.findMany({
        where,
        include: {
          club: { select: { id: true, name: true, city: true, address: true } },
          players: {
            where: { status: MatchPlayerStatus.ACCEPTED },
            select: { player: { select: PLAYER_PUBLIC_SELECT } },
          },
        },
        orderBy: { startsAt: 'asc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.match.count({ where }),
    ]);

    // Annotation de la distance + tri par proximité si géoloc fournie
    const items = rows.map((m) => ({
      ...m,
      distanceM: distanceByClub?.get(m.clubId) ?? null,
    }));
    if (distanceByClub) {
      items.sort((a, b) => (a.distanceM ?? 0) - (b.distanceM ?? 0));
    }

    return { page, limit, total, items };
  }

  async findOne(id: string) {
    const match = await this.prisma.match.findUnique({
      where: { id },
      include: {
        club: { select: { id: true, name: true, city: true, address: true } },
        players: {
          where: { status: { in: [MatchPlayerStatus.ACCEPTED, MatchPlayerStatus.REQUESTED] } },
          include: {
            player: { select: PLAYER_PUBLIC_SELECT },
            // Statut du paiement de la part (l'app masque « Payer » si PAID)
            payment: { select: { status: true } },
          },
        },
      },
    });
    if (!match) throw new NotFoundException('Match introuvable');
    return match;
  }

  async findMine(user: AuthUser) {
    return this.prisma.match.findMany({
      where: {
        players: {
          some: {
            playerId: user.userId,
            status: { in: [MatchPlayerStatus.ACCEPTED, MatchPlayerStatus.REQUESTED] },
          },
        },
      },
      include: {
        club: { select: { id: true, name: true, city: true, address: true } },
        players: {
          where: { status: MatchPlayerStatus.ACCEPTED },
          select: { status: true, player: { select: PLAYER_PUBLIC_SELECT } },
        },
      },
      orderBy: { startsAt: 'desc' },
      take: 100,
    });
  }

  // ------------------------------------------------------------- suggestions

  /**
   * « Pour toi » (docs/02 §5.3) :
   * score = 0.40×compatibilité niveau + 0.25×proximité
   *       + 0.20×disponibilité déclarée + 0.15×affinité (déjà joué ensemble).
   */
  async suggestions(user: AuthUser, lat: number, lng: number) {
    const radiusKm = 50;
    const results = await this.search({ lat, lng, radiusKm, limit: 50 });

    const profile = await this.prisma.playerProfile.findUnique({
      where: { userId: user.userId },
      include: { availabilities: true },
    });
    const myLevel = Number(profile?.level ?? 2);

    // Joueurs déjà croisés (matchs joués/confirmés communs)
    const pastMates = await this.prisma.matchPlayer.findMany({
      where: {
        status: MatchPlayerStatus.ACCEPTED,
        match: {
          status: { in: [MatchStatus.PLAYED, MatchStatus.CONFIRMED] },
          players: {
            some: { playerId: user.userId, status: MatchPlayerStatus.ACCEPTED },
          },
        },
        NOT: { playerId: user.userId },
      },
      select: { playerId: true },
    });
    const mates = new Set(pastMates.map((m) => m.playerId));

    const scored = results.items
      // Pas de suggestion sur ses propres matchs ni ceux qu'on a rejoints
      .filter(
        (m) =>
          m.creatorId !== user.userId &&
          !m.players.some((p: any) => p.player?.id === user.userId),
      )
      .map((m) => {
        const mid = (Number(m.levelMin) + Number(m.levelMax)) / 2;
        const levelScore = Math.max(0, 1 - Math.abs(myLevel - mid) / 2);
        const proximity = 1 - (m.distanceM ?? 0) / (radiusKm * 1000);

        const day = m.startsAt.getDay() === 0 ? 7 : m.startsAt.getDay();
        const minutes = m.startsAt.getHours() * 60 + m.startsAt.getMinutes();
        const available = (profile?.availabilities ?? []).some(
          (a) =>
            a.dayOfWeek === day && a.startMin <= minutes && a.endMin >= minutes,
        );
        const affinity = m.players.some((p: any) => mates.has(p.player?.id))
          ? 1
          : 0;

        const compat =
          0.4 * levelScore +
          0.25 * proximity +
          0.2 * (available ? 1 : 0.3) +
          0.15 * affinity;
        return { ...m, compatScore: Math.round(compat * 100) };
      })
      .sort((a, b) => b.compatScore - a.compatScore)
      .slice(0, 10);

    return scored;
  }

  // --------------------------------------------------------- rejoindre/gérer

  async join(user: AuthUser, matchId: string) {
    const match = await this.getOpenMatch(matchId);

    const profile = await this.prisma.playerProfile.findUnique({
      where: { userId: user.userId },
      select: { level: true },
    });
    const level = Number(profile?.level ?? 0);
    if (level < Number(match.levelMin) || level > Number(match.levelMax)) {
      throw new BadRequestException(
        `Ce match est réservé aux niveaux ${match.levelMin} à ${match.levelMax}`,
      );
    }

    const existing = await this.prisma.matchPlayer.findUnique({
      where: { matchId_playerId: { matchId, playerId: user.userId } },
    });
    if (existing) {
      if (
        existing.status === MatchPlayerStatus.REQUESTED ||
        existing.status === MatchPlayerStatus.ACCEPTED
      ) {
        throw new BadRequestException('Vous participez déjà à ce match');
      }
      if (existing.status === MatchPlayerStatus.DECLINED) {
        throw new ForbiddenException('Votre demande a été refusée');
      }
      // WITHDRAWN → nouvelle demande
      const rejoined = await this.prisma.matchPlayer.update({
        where: { id: existing.id },
        data: { status: MatchPlayerStatus.REQUESTED, paymentId: null, joinedAt: new Date() },
      });
      await this.notifyJoinRequest(match.creatorId, matchId);
      return rejoined;
    }

    const created = await this.prisma.matchPlayer.create({
      data: { matchId, playerId: user.userId },
    });
    await this.notifyJoinRequest(match.creatorId, matchId);
    return created;
  }

  private async notifyJoinRequest(creatorId: string, matchId: string) {
    await this.notifications.notify(
      creatorId,
      'MATCH_JOIN_REQUEST',
      'Nouvelle demande pour votre match',
      'Un joueur souhaite rejoindre votre match — acceptez ou refusez sa demande',
      { matchId },
    );
  }

  async respondToRequest(
    user: AuthUser,
    matchId: string,
    playerId: string,
    accept: boolean,
  ) {
    const match = await this.getOpenMatch(matchId);
    if (match.creatorId !== user.userId) {
      throw new ForbiddenException('Seul le créateur du match peut gérer les demandes');
    }

    const request = await this.prisma.matchPlayer.findUnique({
      where: { matchId_playerId: { matchId, playerId } },
    });
    if (!request || request.status !== MatchPlayerStatus.REQUESTED) {
      throw new NotFoundException('Demande introuvable');
    }

    if (!accept) {
      return this.prisma.matchPlayer.update({
        where: { id: request.id },
        data: { status: MatchPlayerStatus.DECLINED },
      });
    }

    const acceptedCount = await this.prisma.matchPlayer.count({
      where: { matchId, status: MatchPlayerStatus.ACCEPTED },
    });
    if (acceptedCount >= MATCH_SIZE) {
      throw new BadRequestException('Le match est déjà complet');
    }

    const updated = await this.prisma.matchPlayer.update({
      where: { id: request.id },
      data: { status: MatchPlayerStatus.ACCEPTED },
    });
    await this.notifications.notify(
      playerId,
      'MATCH_REQUEST_ACCEPTED',
      'Demande acceptée 🎾',
      'Vous êtes accepté dans le match — payez votre part pour confirmer votre place',
      { matchId },
    );
    if (acceptedCount + 1 >= MATCH_SIZE) {
      await this.prisma.match.update({
        where: { id: matchId },
        data: { status: MatchStatus.FULL },
      });
    }
    return updated;
  }

  /** Désistement : la place est ré-ouverte ; remboursement selon le délai. */
  async withdraw(user: AuthUser, matchId: string) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('Match introuvable');
    if (match.status === MatchStatus.CANCELLED || match.status === MatchStatus.PLAYED) {
      throw new BadRequestException('Ce match est terminé ou annulé');
    }
    if (match.creatorId === user.userId) {
      throw new BadRequestException(
        'Le créateur ne peut pas se désister : utilisez l’annulation du match',
      );
    }

    const membership = await this.prisma.matchPlayer.findUnique({
      where: { matchId_playerId: { matchId, playerId: user.userId } },
    });
    if (
      !membership ||
      (membership.status !== MatchPlayerStatus.ACCEPTED &&
        membership.status !== MatchPlayerStatus.REQUESTED)
    ) {
      throw new BadRequestException('Vous ne participez pas à ce match');
    }

    const hoursBefore = (match.startsAt.getTime() - Date.now()) / 3_600_000;
    const refundPercent = hoursBefore >= WITHDRAW_FREE_HOURS ? 100 : 0;

    await this.prisma.matchPlayer.update({
      where: { id: membership.id },
      data: { status: MatchPlayerStatus.WITHDRAWN },
    });
    if (membership.paymentId) {
      await this.payments.refundMatchShare(membership.paymentId, refundPercent);
    }

    // La place est ré-ouverte
    if (match.status === MatchStatus.FULL || match.status === MatchStatus.CONFIRMED) {
      await this.prisma.match.update({
        where: { id: matchId },
        data: { status: MatchStatus.OPEN },
      });
    }
    await this.notifications.notify(
      match.creatorId,
      'MATCH_PLAYER_WITHDREW',
      'Un joueur s’est désisté',
      'Une place est de nouveau ouverte dans votre match',
      { matchId },
    );
    return { withdrawn: true, refundPercent };
  }

  /** Annulation par le créateur : rembourse toutes les parts payées. */
  async cancel(user: AuthUser, matchId: string) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { players: true },
    });
    if (!match) throw new NotFoundException('Match introuvable');
    if (match.creatorId !== user.userId) {
      throw new ForbiddenException('Seul le créateur peut annuler le match');
    }
    if (match.status === MatchStatus.CANCELLED || match.status === MatchStatus.PLAYED) {
      throw new BadRequestException('Ce match est déjà terminé ou annulé');
    }

    await this.cancelMatchInternal(match.id, match.bookingId, 'Annulé par le créateur');
    return { cancelled: true };
  }

  // ------------------------------------------------------------- score & ELO

  /**
   * Saisie du score par l'organisateur une fois le match commencé/terminé :
   * statut PLAYED + mise à jour ELO et niveau des 4 joueurs.
   */
  async submitScore(user: AuthUser, matchId: string, dto: SubmitScoreDto) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: {
        players: { where: { status: MatchPlayerStatus.ACCEPTED } },
      },
    });
    if (!match) throw new NotFoundException('Match introuvable');
    if (match.creatorId !== user.userId) {
      throw new ForbiddenException("Seul l'organisateur peut saisir le score");
    }
    if (match.status === MatchStatus.PLAYED) {
      throw new BadRequestException('Le score de ce match est déjà enregistré');
    }
    if (match.status === MatchStatus.CANCELLED) {
      throw new BadRequestException('Ce match a été annulé');
    }
    if (match.startsAt > new Date()) {
      throw new BadRequestException("Le match n'a pas encore commencé");
    }

    const playerIds = match.players.map((p) => p.playerId);
    if (playerIds.length !== MATCH_SIZE) {
      throw new BadRequestException('Le match doit avoir 4 joueurs acceptés');
    }
    const winners = [...new Set(dto.winnerIds)];
    if (winners.length !== 2 || !winners.every((w) => playerIds.includes(w))) {
      throw new BadRequestException(
        'winnerIds : exactement 2 joueurs distincts du match',
      );
    }
    const losers = playerIds.filter((p) => !winners.includes(p));

    await this.prisma.match.update({
      where: { id: matchId },
      data: {
        status: MatchStatus.PLAYED,
        score: { winnerIds: winners, score: dto.score ?? null },
      },
    });
    await this.applyElo(winners, losers);

    await this.notifications.notifyMany(
      playerIds.filter((p) => p !== user.userId),
      'MATCH_CONFIRMED',
      'Score enregistré 🏆',
      'Le score du match est saisi — notez vos partenaires et suivez votre niveau',
      { matchId },
    );
    return { played: true };
  }

  /**
   * ELO adapté padel (docs/02 §5.4) : rating moyen d'équipe, K=32
   * (16 après 30 matchs), niveau 1.0-7.0 projeté depuis l'ELO.
   */
  private async applyElo(winners: string[], losers: string[]) {
    const profiles = await this.prisma.playerProfile.findMany({
      where: { userId: { in: [...winners, ...losers] } },
    });
    const byId = new Map(profiles.map((p) => [p.userId, p]));
    const avg = (ids: string[]) =>
      ids.reduce((s, id) => s + (byId.get(id)?.eloRating ?? 1000), 0) /
      ids.length;

    const winAvg = avg(winners);
    const loseAvg = avg(losers);
    const expectedWin = 1 / (1 + Math.pow(10, (loseAvg - winAvg) / 400));

    for (const id of [...winners, ...losers]) {
      const profile = byId.get(id);
      if (!profile) continue;
      const isWinner = winners.includes(id);
      const k = profile.matchesPlayed >= 30 ? 16 : 32;
      const delta = Math.round(k * ((isWinner ? 1 : 0) - expectedWin));
      const newElo = Math.max(400, profile.eloRating + delta);
      // Projection niveau : elo 800 → 1.0 · 1000 → 2.0 · 2000 → 7.0
      const level = Math.min(7, Math.max(1, (newElo - 600) / 200));
      await this.prisma.playerProfile.update({
        where: { userId: id },
        data: {
          eloRating: newElo,
          matchesPlayed: { increment: 1 },
          level: Math.round(level * 10) / 10,
        },
      });
    }
  }

  // ---------------------------------------------------------------- notation

  /** Notation des partenaires (match joué uniquement, une fois par joueur). */
  async ratePlayers(user: AuthUser, matchId: string, dto: RatePlayersDto) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { players: { where: { status: MatchPlayerStatus.ACCEPTED } } },
    });
    if (!match) throw new NotFoundException('Match introuvable');
    if (match.status !== MatchStatus.PLAYED) {
      throw new BadRequestException(
        'Les joueurs se notent une fois le score enregistré',
      );
    }
    const playerIds = match.players.map((p) => p.playerId);
    if (!playerIds.includes(user.userId)) {
      throw new ForbiddenException('Vous ne participez pas à ce match');
    }
    for (const item of dto.items) {
      if (item.playerId === user.userId) {
        throw new BadRequestException('Impossible de se noter soi-même');
      }
      if (!playerIds.includes(item.playerId)) {
        throw new BadRequestException('Joueur hors du match');
      }
    }

    await this.prisma.rating.createMany({
      data: dto.items.map((i) => ({
        matchId,
        raterId: user.userId,
        ratedId: i.playerId,
        punctuality: i.punctuality,
        fairplay: i.fairplay,
        levelAccuracy: i.levelAccuracy,
      })),
      skipDuplicates: true,
    });
    return { rated: dto.items.length };
  }

  /** Ids des joueurs que j'ai déjà notés sur ce match (pour masquer l'UI). */
  async myRatings(user: AuthUser, matchId: string) {
    const ratings = await this.prisma.rating.findMany({
      where: { matchId, raterId: user.userId },
      select: { ratedId: true },
    });
    return ratings.map((r) => r.ratedId);
  }

  // --------------------------------------------------------------------- job

  /** Annulation automatique des matchs incomplets à H-2 + remboursements. */
  @Cron(CronExpression.EVERY_5_MINUTES)
  async cancelIncompleteMatches() {
    const deadline = new Date(Date.now() + AUTO_CANCEL_HOURS_BEFORE * 3_600_000);
    const matches = await this.prisma.match.findMany({
      where: {
        status: { in: [MatchStatus.OPEN, MatchStatus.FULL] },
        startsAt: { lte: deadline },
      },
      select: { id: true, bookingId: true },
    });
    for (const match of matches) {
      this.logger.log(`Match ${match.id} incomplet à H-2 : annulation automatique`);
      await this.cancelMatchInternal(
        match.id,
        match.bookingId,
        'Match incomplet 2 h avant le début',
      );
    }
  }

  // ----------------------------------------------------------------- interne

  private async cancelMatchInternal(
    matchId: string,
    bookingId: string | null,
    reason: string,
  ) {
    // Atomique : un match annulé ne doit jamais garder un créneau réservé
    await this.prisma.$transaction([
      this.prisma.match.update({
        where: { id: matchId },
        data: { status: MatchStatus.CANCELLED },
      }),
      ...(bookingId
        ? [
            this.prisma.booking.update({
              where: { id: bookingId },
              data: {
                status: BookingStatus.CANCELLED,
                cancellationReason: reason,
              },
            }),
          ]
        : []),
    ]);
    // Remboursement intégral de toutes les parts payées
    const paid = await this.prisma.matchPlayer.findMany({
      where: { matchId, paymentId: { not: null } },
      select: { paymentId: true },
    });
    for (const p of paid) {
      await this.payments.refundMatchShare(p.paymentId!, 100);
    }
    const players = await this.prisma.matchPlayer.findMany({
      where: { matchId, status: MatchPlayerStatus.ACCEPTED },
      select: { playerId: true },
    });
    await this.notifications.notifyMany(
      players.map((p) => p.playerId),
      'MATCH_CANCELLED',
      'Match annulé',
      `${reason} — les parts payées seront remboursées`,
      { matchId },
    );
  }

  private async getOpenMatch(matchId: string) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('Match introuvable');
    if (match.status !== MatchStatus.OPEN && match.status !== MatchStatus.FULL) {
      throw new BadRequestException("Ce match n'est plus ouvert");
    }
    if (match.startsAt <= new Date()) {
      throw new BadRequestException('Ce match est déjà commencé');
    }
    return match;
  }
}
