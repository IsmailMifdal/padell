import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  BookingStatus,
  MatchPlayerStatus,
  MatchStatus,
  PaymentMethod,
  PaymentStatus,
  PayoutStatus,
} from '@prisma/client';
import { randomBytes } from 'crypto';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CmiService } from './cmi.service';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cmi: CmiService,
    private readonly notifications: NotificationsService,
  ) {}

  // ------------------------------------------------- session de paiement CMI

  /** Crée la session CMI d'une réservation en attente de paiement. */
  async createBookingSession(user: AuthUser, bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        court: { include: { club: true } },
        bookedBy: { include: { profile: true } },
      },
    });
    if (!booking || booking.bookedById !== user.userId) {
      throw new NotFoundException('Réservation introuvable');
    }
    if (booking.status !== BookingStatus.PENDING_PAYMENT) {
      throw new BadRequestException("Cette réservation n'attend pas de paiement");
    }

    const amount = Number(booking.priceMad);
    const commission =
      Math.round(amount * Number(booking.court.club.commissionRate)) / 100;

    // Un paiement INITIATED réutilisable par réservation (idempotence côté app)
    let payment = await this.prisma.payment.findFirst({
      where: { bookingId, status: PaymentStatus.INITIATED, method: PaymentMethod.CMI },
    });
    if (!payment) {
      payment = await this.prisma.payment.create({
        data: {
          userId: user.userId,
          bookingId,
          amountMad: amount,
          commissionMad: commission,
          method: PaymentMethod.CMI,
          cmiOrderId: `BKG-${bookingId}`,
        },
      });
    }

    const profile = booking.bookedBy?.profile;
    return this.cmi.buildPaymentForm({
      orderId: payment.cmiOrderId!,
      amountMad: amount,
      email: booking.bookedBy?.email,
      billToName: profile ? `${profile.firstName} ${profile.lastName}` : 'Joueur Padel',
    });
  }

  /** Crée la session CMI de la part d'un joueur dans un match. */
  async createMatchSession(user: AuthUser, matchId: string) {
    const membership = await this.prisma.matchPlayer.findUnique({
      where: { matchId_playerId: { matchId, playerId: user.userId } },
      include: {
        match: { include: { club: true } },
        payment: true,
        player: { include: { profile: true } },
      },
    });
    if (!membership || membership.status !== MatchPlayerStatus.ACCEPTED) {
      throw new BadRequestException(
        'Vous devez être accepté dans ce match avant de payer votre part',
      );
    }
    if (membership.payment?.status === PaymentStatus.PAID) {
      throw new BadRequestException('Votre part est déjà payée');
    }
    if (
      membership.match.status !== MatchStatus.OPEN &&
      membership.match.status !== MatchStatus.FULL
    ) {
      throw new BadRequestException("Ce match n'attend plus de paiement");
    }

    const amount = Number(membership.match.pricePerPlayerMad);
    const commission =
      Math.round(amount * Number(membership.match.club.commissionRate)) / 100;

    let payment = membership.payment;
    if (!payment || payment.status === PaymentStatus.FAILED) {
      payment = await this.prisma.payment.create({
        data: {
          userId: user.userId,
          matchId,
          amountMad: amount,
          commissionMad: commission,
          method: PaymentMethod.CMI,
          cmiOrderId: `MTC-${membership.id}-${Date.now().toString(36)}`,
        },
      });
      await this.prisma.matchPlayer.update({
        where: { id: membership.id },
        data: { paymentId: payment.id },
      });
    }

    const profile = membership.player.profile;
    return this.cmi.buildPaymentForm({
      orderId: payment.cmiOrderId!,
      amountMad: amount,
      email: membership.player.email,
      billToName: profile ? `${profile.firstName} ${profile.lastName}` : 'Joueur Padel',
    });
  }

  /** Trace le remboursement (total ou partiel) d'une part de match. */
  async refundMatchShare(paymentId: string, percent: number): Promise<void> {
    const payment = await this.prisma.payment.findUnique({ where: { id: paymentId } });
    if (!payment || payment.status !== PaymentStatus.PAID) return;
    const refund = Math.round(Number(payment.amountMad) * percent) / 100;
    await this.prisma.payment.update({
      where: { id: paymentId },
      data: {
        status: refund > 0 ? PaymentStatus.REFUNDED : PaymentStatus.PAID,
        refundAmountMad: refund,
      },
    });
    if (refund > 0) {
      this.logger.log(
        `Remboursement part de match : ${refund} MAD à traiter (payment ${paymentId})`,
      );
    }
  }

  // ------------------------------------------------------------ webhook CMI

  /**
   * Callback serveur CMI (signé). Idempotent : un second appel pour un
   * paiement déjà traité répond ACTION=POSTAUTH sans double confirmation.
   */
  async handleCmiCallback(body: Record<string, string>): Promise<string> {
    if (!this.cmi.verifyCallback(body)) {
      this.logger.warn(`Callback CMI avec signature invalide (oid=${body.oid})`);
      return 'FAILURE';
    }

    const payment = await this.prisma.payment.findUnique({
      where: { cmiOrderId: body.oid },
      include: { booking: true },
    });
    if (!payment) {
      this.logger.warn(`Callback CMI pour commande inconnue oid=${body.oid}`);
      return 'FAILURE';
    }
    // Idempotence : déjà traité
    if (payment.status === PaymentStatus.PAID) return 'ACTION=POSTAUTH';
    if (payment.status === PaymentStatus.FAILED) return 'APPROVED';

    if (this.cmi.isSuccess(body)) {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: PaymentStatus.PAID,
          cmiTransactionId: body.TransId ?? null,
        },
      });
      if (payment.bookingId) {
        // Confirmation de la réservation + génération du QR de check-in
        await this.prisma.booking.update({
          where: { id: payment.bookingId },
          data: {
            status: BookingStatus.CONFIRMED,
            qrCode: randomBytes(16).toString('hex'),
          },
        });
        await this.notifications.notify(
          payment.userId,
          'BOOKING_CONFIRMED',
          'Réservation confirmée ✅',
          'Votre paiement est validé — retrouvez votre QR code dans Mes réservations',
          { bookingId: payment.bookingId },
        );
      }
      if (payment.matchId) {
        await this.confirmMatchIfComplete(payment.matchId);
      }
      return 'ACTION=POSTAUTH';
    }

    await this.prisma.payment.update({
      where: { id: payment.id },
      data: { status: PaymentStatus.FAILED, cmiTransactionId: body.TransId ?? null },
    });
    if (payment.bookingId && payment.booking?.status === BookingStatus.PENDING_PAYMENT) {
      await this.prisma.booking.update({
        where: { id: payment.bookingId },
        data: {
          status: BookingStatus.CANCELLED,
          cancellationReason: 'Paiement refusé',
        },
      });
    }
    return 'APPROVED';
  }

  /** 4 parts payées → match confirmé + réservation confirmée avec QR. */
  private async confirmMatchIfComplete(matchId: string): Promise<void> {
    const paidCount = await this.prisma.matchPlayer.count({
      where: {
        matchId,
        status: MatchPlayerStatus.ACCEPTED,
        payment: { status: PaymentStatus.PAID },
      },
    });
    if (paidCount < 4) return;

    const match = await this.prisma.match.update({
      where: { id: matchId },
      data: { status: MatchStatus.CONFIRMED },
    });
    if (match.bookingId) {
      await this.prisma.booking.update({
        where: { id: match.bookingId },
        data: {
          status: BookingStatus.CONFIRMED,
          qrCode: randomBytes(16).toString('hex'),
        },
      });
    }
    const players = await this.prisma.matchPlayer.findMany({
      where: { matchId, status: MatchPlayerStatus.ACCEPTED },
      select: { playerId: true },
    });
    await this.notifications.notifyMany(
      players.map((p) => p.playerId),
      'MATCH_CONFIRMED',
      'Match confirmé 🎾',
      'Les 4 parts sont payées : votre match est confirmé, à bientôt sur le terrain !',
      { matchId },
    );
    this.logger.log(`Match ${matchId} complet : confirmé avec sa réservation`);
  }

  // ------------------------------------------------------------ remboursement

  /**
   * Applique la politique d'annulation du club à une réservation annulée.
   * Le remboursement effectif CMI se fait via le back-office marchand ;
   * ici on trace le montant dû.
   */
  async refundForCancelledBooking(bookingId: string): Promise<void> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { court: { include: { club: true } } },
    });
    if (!booking) return;

    const payment = await this.prisma.payment.findFirst({
      where: { bookingId, status: PaymentStatus.PAID },
    });
    if (!payment) return;

    const policy = (booking.court.club.cancellationPolicy ?? {}) as {
      freeUntilHours?: number;
      lateRefundPercent?: number;
    };
    const freeUntilHours = policy.freeUntilHours ?? 24;
    const lateRefundPercent = policy.lateRefundPercent ?? 0;

    const hoursBefore =
      (booking.startsAt.getTime() - Date.now()) / (60 * 60 * 1000);
    const percent = hoursBefore >= freeUntilHours ? 100 : lateRefundPercent;
    const refund =
      Math.round(Number(payment.amountMad) * percent) / 100;

    await this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: refund > 0 ? PaymentStatus.REFUNDED : PaymentStatus.PAID,
        refundAmountMad: refund,
      },
    });
    this.logger.log(
      `Remboursement ${refund} MAD (${percent}%) à traiter pour booking ${bookingId}`,
    );
  }

  // ----------------------------------------------------------------- payouts

  /** Calcule (ou recalcule) le reversement d'un club sur une période. */
  async computePayout(clubId: string, periodStart: Date, periodEnd: Date) {
    const payments = await this.prisma.payment.findMany({
      where: {
        method: PaymentMethod.CMI,
        status: { in: [PaymentStatus.PAID, PaymentStatus.REFUNDED] },
        booking: {
          court: { clubId },
          startsAt: { gte: periodStart, lt: periodEnd },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
        },
      },
    });

    let gross = 0;
    let commission = 0;
    for (const p of payments) {
      const kept = Number(p.amountMad) - Number(p.refundAmountMad ?? 0);
      if (kept <= 0) continue;
      gross += kept;
      commission += Number(p.commissionMad) * (kept / Number(p.amountMad));
    }
    gross = Math.round(gross * 100) / 100;
    commission = Math.round(commission * 100) / 100;
    const net = Math.round((gross - commission) * 100) / 100;

    return this.prisma.payout.upsert({
      where: {
        clubId_periodStart_periodEnd: { clubId, periodStart, periodEnd },
      },
      create: {
        clubId,
        periodStart,
        periodEnd,
        grossMad: gross,
        commissionMad: commission,
        netMad: net,
      },
      update: {
        grossMad: gross,
        commissionMad: commission,
        netMad: net,
      },
    });
  }

  async listPayouts(clubId: string) {
    return this.prisma.payout.findMany({
      where: { clubId },
      orderBy: { periodStart: 'desc' },
    });
  }

  async markPayoutPaid(payoutId: string) {
    return this.prisma.payout.update({
      where: { id: payoutId },
      data: { status: PayoutStatus.PAID, paidAt: new Date() },
    });
  }

  async findMine(user: AuthUser) {
    return this.prisma.payment.findMany({
      where: { userId: user.userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }
}
