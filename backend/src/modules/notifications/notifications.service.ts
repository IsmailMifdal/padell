import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { BookingStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { PushService } from './push.service';

export type NotificationType =
  | 'BOOKING_CONFIRMED'
  | 'BOOKING_CANCELLED'
  | 'BOOKING_REMINDER'
  | 'MATCH_JOIN_REQUEST'
  | 'MATCH_REQUEST_ACCEPTED'
  | 'MATCH_CONFIRMED'
  | 'MATCH_CANCELLED'
  | 'MATCH_PLAYER_WITHDREW'
  | 'CHAT_MESSAGE';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
  ) {}

  /** Enregistre la notification en base et pousse vers les appareils. */
  async notify(
    userId: string,
    type: NotificationType,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    await this.prisma.notification.create({
      data: { userId, type, title, body, data: data as Prisma.InputJsonValue },
    });
    const tokens = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    await this.push.send(
      tokens.map((t) => t.token),
      title,
      body,
      { type, ...data },
    );
  }

  async notifyMany(
    userIds: string[],
    type: NotificationType,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    await Promise.all(userIds.map((id) => this.notify(id, type, title, body, data)));
  }

  // ------------------------------------------------------------------- inbox

  async list(userId: string, unreadOnly = false) {
    return this.prisma.notification.findMany({
      where: { userId, ...(unreadOnly ? { readAt: null } : {}) },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async markRead(userId: string, notificationId?: string) {
    await this.prisma.notification.updateMany({
      where: {
        userId,
        readAt: null,
        ...(notificationId ? { id: notificationId } : {}),
      },
      data: { readAt: new Date() },
    });
  }

  async registerDevice(userId: string, token: string, platform?: string) {
    return this.prisma.deviceToken.upsert({
      where: { token },
      create: { userId, token, platform: platform ?? null },
      update: { userId, platform: platform ?? null },
    });
  }

  // ---------------------------------------------------------------- rappels

  /** Rappel 2 h avant chaque réservation confirmée (déduplication en base). */
  @Cron(CronExpression.EVERY_10_MINUTES)
  async sendBookingReminders() {
    const windowStart = new Date(Date.now() + 105 * 60 * 1000); // H-1h45
    const windowEnd = new Date(Date.now() + 2 * 60 * 60 * 1000); // H-2h

    const upcoming = await this.prisma.booking.findMany({
      where: {
        status: BookingStatus.CONFIRMED,
        bookedById: { not: null },
        startsAt: { gte: windowStart, lte: windowEnd },
      },
      include: { court: { select: { name: true, club: { select: { name: true } } } } },
    });

    for (const booking of upcoming) {
      const already = await this.prisma.notification.findFirst({
        where: {
          userId: booking.bookedById!,
          type: 'BOOKING_REMINDER',
          data: { path: ['bookingId'], equals: booking.id },
        },
      });
      if (already) continue;
      const time = booking.startsAt.toTimeString().slice(0, 5);
      await this.notify(
        booking.bookedById!,
        'BOOKING_REMINDER',
        'Votre match approche 🎾',
        `Rendez-vous à ${time} — ${booking.court.club.name}, ${booking.court.name}`,
        { bookingId: booking.id },
      );
    }
  }
}
