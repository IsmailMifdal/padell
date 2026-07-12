import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ClubStatus } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

/**
 * Liste d'attente : un joueur s'inscrit sur un club + jour complet ;
 * dès qu'une réservation de ce jour est annulée, tous les inscrits sont
 * notifiés et retirés de la liste.
 */
@Injectable()
export class WaitlistService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async join(userId: string, clubId: string, dateStr: string) {
    const club = await this.prisma.club.findUnique({ where: { id: clubId } });
    if (!club || club.status !== ClubStatus.APPROVED) {
      throw new NotFoundException('Club introuvable');
    }
    const date = new Date(`${dateStr}T00:00:00Z`);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException('Date invalide (YYYY-MM-DD)');
    }
    await this.prisma.waitlistEntry.upsert({
      where: { userId_clubId_date: { userId, clubId, date } },
      create: { userId, clubId, date },
      update: {},
    });
    return { waitlisted: true };
  }

  async leave(userId: string, clubId: string, dateStr: string) {
    const date = new Date(`${dateStr}T00:00:00Z`);
    await this.prisma.waitlistEntry.deleteMany({
      where: { userId, clubId, date },
    });
    return { waitlisted: false };
  }

  /** Suis-je inscrit sur ce club/jour ? */
  async status(userId: string, clubId: string, dateStr: string) {
    const date = new Date(`${dateStr}T00:00:00Z`);
    const entry = await this.prisma.waitlistEntry.findFirst({
      where: { userId, clubId, date },
    });
    return { waitlisted: entry !== null };
  }

  /** Appelé à chaque annulation : alerte les inscrits du club/jour. */
  async notifyFreedSlot(clubId: string, startsAt: Date) {
    const date = new Date(
      Date.UTC(startsAt.getFullYear(), startsAt.getMonth(), startsAt.getDate()),
    );
    const entries = await this.prisma.waitlistEntry.findMany({
      where: { clubId, date },
      include: { club: { select: { name: true } } },
    });
    if (entries.length === 0) return;

    await this.prisma.waitlistEntry.deleteMany({
      where: { id: { in: entries.map((e) => e.id) } },
    });
    await this.notifications.notifyMany(
      entries.map((e) => e.userId),
      'BOOKING_REMINDER',
      'Un créneau s’est libéré ! ⚡',
      `${entries[0].club.name} : une réservation vient d’être annulée le ${startsAt.toLocaleDateString('fr-FR')} — réservez vite`,
      { clubId },
    );
  }
}
