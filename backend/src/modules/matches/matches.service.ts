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
          include: { player: { select: PLAYER_PUBLIC_SELECT } },
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
    await this.prisma.match.update({
      where: { id: matchId },
      data: { status: MatchStatus.CANCELLED },
    });
    if (bookingId) {
      await this.prisma.booking.update({
        where: { id: bookingId },
        data: { status: BookingStatus.CANCELLED, cancellationReason: reason },
      });
    }
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
