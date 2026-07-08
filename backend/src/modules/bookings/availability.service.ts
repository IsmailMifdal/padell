import { Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, ClubStatus } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';

export interface Slot {
  courtId: string;
  courtName: string;
  startsAt: Date;
  endsAt: Date;
  durationMin: number;
  priceMad: number;
}

/**
 * Les créneaux ne sont pas pré-générés : ils sont dérivés à la volée de
 * opening_hours + pricing_rules, moins les bookings actifs (cf. docs/02 §4.2).
 * Toutes les heures sont en heure locale du club.
 */
@Injectable()
export class AvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  async forClubDay(clubId: string, dateStr: string): Promise<{ date: string; slots: Slot[] }> {
    const club = await this.prisma.club.findUnique({
      where: { id: clubId },
      include: {
        openingHours: true,
        courts: { where: { active: true }, include: { pricingRules: true } },
      },
    });
    if (!club || club.status !== ClubStatus.APPROVED) {
      throw new NotFoundException('Club introuvable');
    }

    const [y, m, d] = dateStr.split('-').map(Number);
    const dayStart = new Date(y, m - 1, d);
    const isoDay = dayStart.getDay() === 0 ? 7 : dayStart.getDay();

    const opening = club.openingHours.find((h) => h.dayOfWeek === isoDay);
    if (!opening) return { date: dateStr, slots: [] };

    // Réservations actives du jour pour tous les terrains du club
    const dayEnd = new Date(y, m - 1, d + 1);
    const bookings = await this.prisma.booking.findMany({
      where: {
        court: { clubId },
        status: { in: [BookingStatus.PENDING_PAYMENT, BookingStatus.CONFIRMED] },
        startsAt: { lt: dayEnd },
        endsAt: { gt: dayStart },
      },
      select: { courtId: true, startsAt: true, endsAt: true },
    });

    const now = new Date();
    const slots: Slot[] = [];

    for (const court of club.courts) {
      const rules = court.pricingRules.filter((r) => r.dayOfWeek === isoDay);
      for (const rule of rules) {
        const windowStart = Math.max(rule.startMin, opening.openMin);
        const windowEnd = Math.min(rule.endMin, opening.closeMin);
        for (
          let start = windowStart;
          start + rule.durationMin <= windowEnd;
          start += rule.durationMin
        ) {
          const startsAt = new Date(y, m - 1, d, 0, start);
          const endsAt = new Date(y, m - 1, d, 0, start + rule.durationMin);
          if (startsAt <= now) continue;

          const taken = bookings.some(
            (b) => b.courtId === court.id && b.startsAt < endsAt && b.endsAt > startsAt,
          );
          if (taken) continue;

          slots.push({
            courtId: court.id,
            courtName: court.name,
            startsAt,
            endsAt,
            durationMin: rule.durationMin,
            priceMad: Number(rule.priceMad),
          });
        }
      }
    }

    slots.sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());
    return { date: dateStr, slots };
  }
}
