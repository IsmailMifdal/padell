import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  Booking,
  BookingSource,
  BookingStatus,
  ClubStatus,
  PaymentMode,
  Prisma,
  Role,
} from '@prisma/client';
import { randomBytes } from 'crypto';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { LockService } from '../../infra/redis/lock.service';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { WaitlistService } from './waitlist.service';

// Délai pour finaliser un paiement en ligne avant libération du créneau
export const PAYMENT_WINDOW_MINUTES = 10;
const LOCK_TTL_SECONDS = PAYMENT_WINDOW_MINUTES * 60;

@Injectable()
export class BookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly locks: LockService,
    private readonly payments: PaymentsService,
    private readonly waitlist: WaitlistService,
  ) {}

  async create(user: AuthUser, dto: CreateBookingDto): Promise<Booking> {
    const startsAt = new Date(dto.startsAt);
    if (Number.isNaN(startsAt.getTime()) || startsAt <= new Date()) {
      throw new BadRequestException('Le créneau doit être dans le futur');
    }
    const endsAt = new Date(startsAt.getTime() + dto.durationMin * 60 * 1000);

    const court = await this.prisma.court.findUnique({
      where: { id: dto.courtId },
      include: { club: { include: { openingHours: true } } },
    });
    if (!court || !court.active || court.club.status !== ClubStatus.APPROVED) {
      throw new NotFoundException('Terrain introuvable');
    }
    if (dto.paymentMode === PaymentMode.ON_SITE && !court.club.paymentOnSiteAllowed) {
      throw new BadRequestException("Ce club n'accepte pas le paiement sur place");
    }

    const priceMad = await this.resolvePrice(court.id, court.club.openingHours, startsAt, dto.durationMin);

    // Verrou Redis : premier arrivé, premier servi pendant la fenêtre de paiement
    const lockKey = `lock:court:${court.id}:${startsAt.toISOString()}`;
    const lockToken = await this.locks.acquire(lockKey, LOCK_TTL_SECONDS);
    if (!lockToken) {
      throw new ConflictException('Ce créneau est en cours de réservation par un autre joueur');
    }

    try {
      const isOnSite = dto.paymentMode === PaymentMode.ON_SITE;
      const booking = await this.prisma.booking.create({
        data: {
          courtId: court.id,
          bookedById: user.userId,
          startsAt,
          endsAt,
          priceMad,
          paymentMode: dto.paymentMode,
          status: isOnSite ? BookingStatus.CONFIRMED : BookingStatus.PENDING_PAYMENT,
          qrCode: isOnSite ? this.generateQr() : null,
        },
      });
      return booking;
    } catch (e) {
      await this.locks.release(lockKey, lockToken);
      // Contrainte EXCLUDE : filet de sécurité final au niveau base
      if (this.isOverlapViolation(e)) {
        throw new ConflictException('Ce créneau vient d’être réservé');
      }
      throw e;
    }
  }

  async findMine(user: AuthUser) {
    return this.prisma.booking.findMany({
      where: { bookedById: user.userId },
      include: {
        court: { select: { name: true, club: { select: { id: true, name: true, address: true, city: true } } } },
      },
      orderBy: { startsAt: 'desc' },
      take: 100,
    });
  }

  async findOne(user: AuthUser, id: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        court: { select: { name: true, clubId: true, club: { select: { name: true, address: true, ownerId: true } } } },
      },
    });
    if (!booking) throw new NotFoundException('Réservation introuvable');
    const allowed =
      booking.bookedById === user.userId ||
      booking.court.club.ownerId === user.userId ||
      user.roles.includes(Role.ADMIN);
    if (!allowed) throw new ForbiddenException('Accès refusé');
    return booking;
  }

  /**
   * Annulation par le joueur. La politique du club décide du remboursement
   * (traité au module payments) ; ici on libère le créneau.
   */
  async cancel(user: AuthUser, id: string, reason?: string) {
    const booking = await this.findOne(user, id);
    if (
      booking.status !== BookingStatus.CONFIRMED &&
      booking.status !== BookingStatus.PENDING_PAYMENT
    ) {
      throw new BadRequestException('Cette réservation ne peut plus être annulée');
    }
    if (booking.startsAt <= new Date()) {
      throw new BadRequestException('Le créneau est déjà commencé ou passé');
    }

    const cancelled = await this.prisma.booking.update({
      where: { id },
      data: {
        status: BookingStatus.CANCELLED,
        cancellationReason: reason ?? 'Annulée par le joueur',
      },
    });
    // Remboursement éventuel selon la politique d'annulation du club
    await this.payments.refundForCancelledBooking(id);
    // Liste d'attente : préviens les joueurs qui guettent ce club/jour
    await this.waitlist.notifyFreedSlot(booking.court.clubId, booking.startsAt);
    return cancelled;
  }

  /** Un paiement en ligne non finalisé libère le créneau après 10 minutes. */
  @Cron(CronExpression.EVERY_MINUTE)
  async expirePendingPayments() {
    await this.prisma.booking.updateMany({
      where: {
        status: BookingStatus.PENDING_PAYMENT,
        source: BookingSource.APP,
        // Les réservations de match suivent leur propre cycle (annulation H-2)
        match: null,
        createdAt: { lt: new Date(Date.now() - PAYMENT_WINDOW_MINUTES * 60 * 1000) },
      },
      data: {
        status: BookingStatus.CANCELLED,
        cancellationReason: 'Paiement non finalisé dans le délai',
      },
    });
  }

  // ----------------------------------------------------------------- interne

  private generateQr(): string {
    return randomBytes(16).toString('hex');
  }

  private isOverlapViolation(e: unknown): boolean {
    const message =
      e instanceof Prisma.PrismaClientKnownRequestError
        ? `${e.message} ${JSON.stringify(e.meta ?? {})}`
        : e instanceof Error
          ? e.message
          : '';
    return message.includes('bookings_no_overlap') || message.includes('23P01');
  }

  /** Le créneau doit correspondre exactement à la grille d'une règle tarifaire. */
  private async resolvePrice(
    courtId: string,
    openingHours: Array<{ dayOfWeek: number; openMin: number; closeMin: number }>,
    startsAt: Date,
    durationMin: number,
  ): Promise<number> {
    const isoDay = startsAt.getDay() === 0 ? 7 : startsAt.getDay();
    const startMin = startsAt.getHours() * 60 + startsAt.getMinutes();
    const endMin = startMin + durationMin;

    const opening = openingHours.find((h) => h.dayOfWeek === isoDay);
    if (!opening || startMin < opening.openMin || endMin > opening.closeMin) {
      throw new BadRequestException('Le club est fermé sur ce créneau');
    }

    const rule = await this.prisma.pricingRule.findFirst({
      where: {
        courtId,
        dayOfWeek: isoDay,
        durationMin,
        startMin: { lte: startMin },
        endMin: { gte: endMin },
      },
    });
    if (!rule || (startMin - rule.startMin) % rule.durationMin !== 0) {
      throw new BadRequestException('Aucun créneau réservable à cet horaire');
    }
    return Number(rule.priceMad);
  }
}
