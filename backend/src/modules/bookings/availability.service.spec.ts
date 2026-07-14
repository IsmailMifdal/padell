import { NotFoundException } from '@nestjs/common';
import { AvailabilityService } from './availability.service';

/**
 * Calcul des créneaux à la volée (docs/02 §4.2) : grille tarifaire moins
 * les réservations actives, bornée par les horaires d'ouverture.
 */
describe('AvailabilityService', () => {
  // Jour de test : demain (aucun créneau filtré par « déjà passé »)
  const tomorrow = new Date(Date.now() + 24 * 3600_000);
  const dateStr = [
    tomorrow.getFullYear(),
    String(tomorrow.getMonth() + 1).padStart(2, '0'),
    String(tomorrow.getDate()).padStart(2, '0'),
  ].join('-');
  const isoDay = tomorrow.getDay() === 0 ? 7 : tomorrow.getDay();

  function makeService({
    openingHours = [{ dayOfWeek: isoDay, openMin: 480, closeMin: 1380 }], // 8h-23h
    rules = [
      {
        dayOfWeek: isoDay,
        startMin: 480,
        endMin: 1380,
        durationMin: 90,
        priceMad: 300,
      },
    ],
    bookings = [] as any[],
    status = 'APPROVED',
  } = {}) {
    const prisma = {
      club: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'club1',
          status,
          openingHours,
          courts: [{ id: 'court1', name: 'Court 1', pricingRules: rules }],
        }),
      },
      booking: { findMany: jest.fn().mockResolvedValue(bookings) },
    } as any;
    return new AvailabilityService(prisma);
  }

  it('génère la grille 8h→23h par pas de 90 min (10 créneaux)', async () => {
    const service = makeService();
    const { slots } = await service.forClubDay('club1', dateStr);
    expect(slots).toHaveLength(10); // (1380-480)/90 = 10
    expect(slots[0].startsAt.getHours()).toBe(8);
    expect(slots[0].priceMad).toBe(300);
    expect(slots[slots.length - 1].startsAt.getHours()).toBe(21); // 21h30 max ? non : 21h30 dépasse — dernier départ 21h30-90=...
  });

  it('exclut les créneaux chevauchant une réservation active', async () => {
    const d = tomorrow;
    const booked = {
      courtId: 'court1',
      startsAt: new Date(d.getFullYear(), d.getMonth(), d.getDate(), 9, 30),
      endsAt: new Date(d.getFullYear(), d.getMonth(), d.getDate(), 11, 0),
    };
    const service = makeService({ bookings: [booked] });
    const { slots } = await service.forClubDay('club1', dateStr);
    expect(slots).toHaveLength(9);
    // le créneau 9h30-11h a disparu, les voisins restent
    const hours = slots.map((s) => s.startsAt.getHours() * 60 + s.startsAt.getMinutes());
    expect(hours).not.toContain(9 * 60 + 30);
    expect(hours).toContain(8 * 60);
    expect(hours).toContain(11 * 60);
  });

  it('jour fermé (aucun horaire) → aucune disponibilité', async () => {
    const service = makeService({ openingHours: [] });
    const { slots } = await service.forClubDay('club1', dateStr);
    expect(slots).toHaveLength(0);
  });

  it('la grille est bornée par les horaires d’ouverture, pas par la règle', async () => {
    // Règle 8h-23h mais club ouvert seulement 10h-13h
    const service = makeService({
      openingHours: [{ dayOfWeek: isoDay, openMin: 600, closeMin: 780 }],
    });
    const { slots } = await service.forClubDay('club1', dateStr);
    expect(slots).toHaveLength(2); // 10h et 11h30
    expect(slots[0].startsAt.getHours()).toBe(10);
  });

  it('club non approuvé → 404 (invisible au public)', async () => {
    const service = makeService({ status: 'PENDING' });
    await expect(service.forClubDay('club1', dateStr)).rejects.toThrow(
      NotFoundException,
    );
  });
});
