import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  BookingSource,
  BookingStatus,
  PaymentMode,
  Prisma,
} from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { WaitlistService } from '../bookings/waitlist.service';
import { ClubsService } from '../clubs/clubs.service';
import {
  BlockSlotDto,
  CalendarQuery,
  CheckinDto,
  ManualBookingDto,
} from './dto/owner.dto';

@Injectable()
export class OwnerService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clubs: ClubsService,
    private readonly waitlist: WaitlistService,
  ) {}

  /** Calendrier du club : toutes les réservations actives sur la période. */
  async calendar(user: AuthUser, clubId: string, query: CalendarQuery) {
    await this.clubs.assertOwnership(user, clubId);
    const from = new Date(`${query.from}T00:00:00`);
    const to = new Date(`${query.to}T23:59:59`);
    if (to < from) throw new BadRequestException('Période invalide');

    return this.prisma.booking.findMany({
      where: {
        court: { clubId },
        startsAt: { gte: from, lte: to },
        status: {
          in: [BookingStatus.PENDING_PAYMENT, BookingStatus.CONFIRMED, BookingStatus.COMPLETED],
        },
      },
      include: {
        court: { select: { id: true, name: true } },
        bookedBy: {
          select: { id: true, phone: true, profile: { select: { firstName: true, lastName: true } } },
        },
        match: { select: { id: true, status: true } },
      },
      orderBy: { startsAt: 'asc' },
    });
  }

  /** Réservation manuelle (téléphone / comptoir), payée sur place. */
  async createManualBooking(user: AuthUser, clubId: string, dto: ManualBookingDto) {
    await this.clubs.assertOwnership(user, clubId);
    return this.createOwnerBooking(clubId, {
      courtId: dto.courtId,
      startsAt: dto.startsAt,
      durationMin: dto.durationMin,
      source: BookingSource.MANUAL,
      priceMad: dto.priceMad ?? 0,
      paymentMode: PaymentMode.ON_SITE,
      reason: dto.customerName ? `Réservation manuelle : ${dto.customerName}` : null,
    });
  }

  /** Blocage d'un créneau (maintenance, cours...). */
  async blockSlot(user: AuthUser, clubId: string, dto: BlockSlotDto) {
    await this.clubs.assertOwnership(user, clubId);
    return this.createOwnerBooking(clubId, {
      courtId: dto.courtId,
      startsAt: dto.startsAt,
      durationMin: dto.durationMin,
      source: BookingSource.BLOCKED,
      priceMad: 0,
      paymentMode: null,
      reason: dto.reason ?? 'Créneau bloqué',
    });
  }

  /** Annulation côté club d'une réservation (manuelle, blocage ou joueur). */
  async cancelBooking(user: AuthUser, clubId: string, bookingId: string, reason?: string) {
    await this.clubs.assertOwnership(user, clubId);
    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, court: { clubId } },
    });
    if (!booking) throw new NotFoundException('Réservation introuvable');
    if (
      booking.status !== BookingStatus.CONFIRMED &&
      booking.status !== BookingStatus.PENDING_PAYMENT
    ) {
      throw new BadRequestException('Cette réservation ne peut plus être annulée');
    }
    const cancelled = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: BookingStatus.CANCELLED,
        cancellationReason: reason ?? 'Annulée par le club',
      },
    });
    await this.waitlist.notifyFreedSlot(clubId, booking.startsAt);
    return cancelled;
  }

  /** Statistiques d'exploitation du club sur les N derniers jours. */
  async stats(user: AuthUser, clubId: string, days = 30) {
    await this.clubs.assertOwnership(user, clubId);
    const since = new Date(Date.now() - days * 24 * 3600 * 1000);

    const bookings = await this.prisma.booking.findMany({
      where: {
        court: { clubId },
        startsAt: { gte: since },
        source: { not: BookingSource.BLOCKED },
      },
      select: { status: true, priceMad: true, startsAt: true, source: true },
    });

    const active = bookings.filter(
      (b) =>
        b.status === BookingStatus.CONFIRMED ||
        b.status === BookingStatus.COMPLETED,
    );
    const revenue = active.reduce((s, b) => s + Number(b.priceMad), 0);

    // Répartition des réservations par heure de début (heures creuses/pleines)
    const byHour: Record<number, number> = {};
    for (const b of active) {
      const h = b.startsAt.getHours();
      byHour[h] = (byHour[h] ?? 0) + 1;
    }

    const cancelled = bookings.filter(
      (b) => b.status === BookingStatus.CANCELLED,
    ).length;

    return {
      days,
      totalBookings: active.length,
      cancelledBookings: cancelled,
      revenueMad: Math.round(revenue * 100) / 100,
      manualShare: active.length
        ? Math.round(
            (active.filter((b) => b.source === BookingSource.MANUAL).length /
              active.length) *
              100,
          )
        : 0,
      byHour,
    };
  }

  /** Check-in par scan du QR code à l'accueil du club. */
  async checkin(user: AuthUser, clubId: string, dto: CheckinDto) {
    await this.clubs.assertOwnership(user, clubId);
    const booking = await this.prisma.booking.findFirst({
      where: { qrCode: dto.qrCode, court: { clubId } },
      include: {
        court: { select: { name: true } },
        bookedBy: { select: { profile: { select: { firstName: true, lastName: true } } } },
      },
    });
    if (!booking) throw new NotFoundException('QR code inconnu pour ce club');
    if (booking.status !== BookingStatus.CONFIRMED) {
      throw new BadRequestException(
        `Réservation non valide pour check-in (statut : ${booking.status})`,
      );
    }
    return this.prisma.booking.update({
      where: { id: booking.id },
      data: { status: BookingStatus.COMPLETED },
      include: { court: { select: { name: true } } },
    });
  }

  // ----------------------------------------------------------------- interne

  private async createOwnerBooking(
    clubId: string,
    params: {
      courtId: string;
      startsAt: string;
      durationMin: number;
      source: BookingSource;
      priceMad: number;
      paymentMode: PaymentMode | null;
      reason: string | null;
    },
  ) {
    const court = await this.prisma.court.findFirst({
      where: { id: params.courtId, clubId },
    });
    if (!court) throw new NotFoundException('Terrain introuvable dans ce club');

    const startsAt = new Date(params.startsAt);
    if (Number.isNaN(startsAt.getTime())) {
      throw new BadRequestException('Date de début invalide');
    }
    const endsAt = new Date(startsAt.getTime() + params.durationMin * 60 * 1000);

    try {
      return await this.prisma.booking.create({
        data: {
          courtId: params.courtId,
          startsAt,
          endsAt,
          priceMad: params.priceMad,
          status: BookingStatus.CONFIRMED,
          source: params.source,
          paymentMode: params.paymentMode,
          note: params.reason,
        },
      });
    } catch (e) {
      const message =
        e instanceof Prisma.PrismaClientKnownRequestError
          ? `${e.message} ${JSON.stringify(e.meta ?? {})}`
          : e instanceof Error
            ? e.message
            : '';
      if (message.includes('bookings_no_overlap') || message.includes('23P01')) {
        throw new ConflictException('Un créneau existe déjà sur cette plage');
      }
      throw e;
    }
  }
}
