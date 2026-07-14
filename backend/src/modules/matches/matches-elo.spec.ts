import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { MatchesService } from './matches.service';

/**
 * ELO adapté padel (docs/02 §5.4) : c'est le moteur de progression des
 * niveaux — testé via submitScore (validations) et applyElo (math).
 */
describe('MatchesService — score & ELO', () => {
  const W1 = 'w1', W2 = 'w2', L1 = 'l1', L2 = 'l2';

  function makeProfiles(overrides: Record<string, Partial<{ elo: number; played: number }>> = {}) {
    return [W1, W2, L1, L2].map((id) => ({
      userId: id,
      eloRating: overrides[id]?.elo ?? 1000,
      matchesPlayed: overrides[id]?.played ?? 0,
      level: 2.0,
    }));
  }

  function makeService(profiles: any[]) {
    const updates: Record<string, any> = {};
    const prisma = {
      match: {
        findUnique: jest.fn(),
        update: jest.fn().mockResolvedValue({}),
      },
      playerProfile: {
        findMany: jest.fn().mockResolvedValue(profiles),
        update: jest.fn().mockImplementation(({ where, data }: any) => {
          updates[where.userId] = data;
          return Promise.resolve({});
        }),
      },
    } as any;
    const notifications = { notify: jest.fn(), notifyMany: jest.fn() } as any;
    const service = new MatchesService(prisma, {} as any, {} as any, notifications);
    return { service, prisma, updates };
  }

  const baseMatch = {
    id: 'm1',
    creatorId: W1,
    status: 'CONFIRMED',
    startsAt: new Date(Date.now() - 2 * 3600_000), // commencé il y a 2 h
    players: [W1, W2, L1, L2].map((id) => ({ playerId: id })),
  };

  it('victoire à ratings égaux : +16 / -16 (K=32, attendu 0.5)', async () => {
    const { service, prisma, updates } = makeService(makeProfiles());
    prisma.match.findUnique.mockResolvedValue(baseMatch);

    await service.submitScore({ userId: W1, roles: [] } as any, 'm1', {
      winnerIds: [W1, W2],
      score: '6-4, 6-3',
    });

    expect(updates[W1].eloRating).toBe(1016);
    expect(updates[W2].eloRating).toBe(1016);
    expect(updates[L1].eloRating).toBe(984);
    expect(updates[L2].eloRating).toBe(984);
    // niveau projeté : (1016-600)/200 = 2.08 → 2.1
    expect(updates[W1].level).toBe(2.1);
    expect(updates[L1].level).toBe(1.9);
    expect(updates[W1].matchesPlayed).toEqual({ increment: 1 });
    // le match est marqué joué avec les vainqueurs
    expect(prisma.match.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: 'PLAYED',
          score: { winnerIds: [W1, W2], score: '6-4, 6-3' },
        }),
      }),
    );
  });

  it('battre plus fort que soi rapporte plus que battre plus faible', async () => {
    // Équipe gagnante à 1000 contre équipe à 1400
    const strong = makeService(
      makeProfiles({ [L1]: { elo: 1400 }, [L2]: { elo: 1400 } }),
    );
    strong.prisma.match.findUnique.mockResolvedValue(baseMatch);
    await strong.service.submitScore({ userId: W1, roles: [] } as any, 'm1', {
      winnerIds: [W1, W2],
    });
    const gainVsStrong = strong.updates[W1].eloRating - 1000;

    const weak = makeService(
      makeProfiles({ [L1]: { elo: 600 }, [L2]: { elo: 600 } }),
    );
    weak.prisma.match.findUnique.mockResolvedValue(baseMatch);
    await weak.service.submitScore({ userId: W1, roles: [] } as any, 'm1', {
      winnerIds: [W1, W2],
    });
    const gainVsWeak = weak.updates[W1].eloRating - 1000;

    expect(gainVsStrong).toBeGreaterThan(gainVsWeak);
    expect(gainVsStrong).toBeGreaterThan(16); // outsider récompensé
    expect(gainVsWeak).toBeGreaterThanOrEqual(1); // gagner rapporte toujours
  });

  it('K réduit à 16 après 30 matchs (rating stabilisé)', async () => {
    const { service, prisma, updates } = makeService(
      makeProfiles({ [W1]: { played: 35 } }),
    );
    prisma.match.findUnique.mockResolvedValue(baseMatch);
    await service.submitScore({ userId: W1, roles: [] } as any, 'm1', {
      winnerIds: [W1, W2],
    });
    expect(updates[W1].eloRating).toBe(1008); // K=16 → +8
    expect(updates[W2].eloRating).toBe(1016); // K=32 → +16
  });

  it('le niveau est borné à [1, 7] même aux extrêmes', async () => {
    const { service, prisma, updates } = makeService(
      makeProfiles({
        [W1]: { elo: 2100 }, // déjà au-dessus du plafond niveau 7
        [L1]: { elo: 700 },
        [L2]: { elo: 700 },
      }),
    );
    prisma.match.findUnique.mockResolvedValue(baseMatch);
    await service.submitScore({ userId: W1, roles: [] } as any, 'm1', {
      winnerIds: [W1, W2],
    });
    expect(updates[W1].level).toBe(7);
    expect(updates[L1].level).toBeGreaterThanOrEqual(1);
  });

  // ------------------------------------------------------------ validations

  it('refuse la saisie par un joueur qui n’est pas l’organisateur', async () => {
    const { service, prisma } = makeService(makeProfiles());
    prisma.match.findUnique.mockResolvedValue(baseMatch);
    await expect(
      service.submitScore({ userId: L1, roles: [] } as any, 'm1', {
        winnerIds: [W1, W2],
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('refuse la saisie avant le début du match', async () => {
    const { service, prisma } = makeService(makeProfiles());
    prisma.match.findUnique.mockResolvedValue({
      ...baseMatch,
      startsAt: new Date(Date.now() + 3600_000),
    });
    await expect(
      service.submitScore({ userId: W1, roles: [] } as any, 'm1', {
        winnerIds: [W1, W2],
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('refuse des vainqueurs hors du match ou en double', async () => {
    const { service, prisma } = makeService(makeProfiles());
    prisma.match.findUnique.mockResolvedValue(baseMatch);
    await expect(
      service.submitScore({ userId: W1, roles: [] } as any, 'm1', {
        winnerIds: [W1, 'intrus'],
      }),
    ).rejects.toThrow(BadRequestException);
    await expect(
      service.submitScore({ userId: W1, roles: [] } as any, 'm1', {
        winnerIds: [W1, W1],
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('refuse un double enregistrement de score (match déjà PLAYED)', async () => {
    const { service, prisma } = makeService(makeProfiles());
    prisma.match.findUnique.mockResolvedValue({ ...baseMatch, status: 'PLAYED' });
    await expect(
      service.submitScore({ userId: W1, roles: [] } as any, 'm1', {
        winnerIds: [W1, W2],
      }),
    ).rejects.toThrow(BadRequestException);
  });
});
