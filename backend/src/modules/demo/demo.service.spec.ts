import { NotFoundException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { DemoService } from './demo.service';

/** Mode démo : le remplissage ne touche que des comptes joueurs vides, et seulement si DEMO_MODE=true. */
describe('DemoService', () => {
  function make(demoMode: string | undefined, counts = { bookings: 0, matches: 0 }) {
    const prisma = {
      booking: { count: jest.fn().mockResolvedValue(counts.bookings) },
      matchPlayer: { count: jest.fn().mockResolvedValue(counts.matches) },
    };
    const config = { get: jest.fn().mockReturnValue(demoMode) };
    const service = new DemoService(prisma as any, config as any);
    const seedUser = jest.spyOn(service, 'seedUser').mockResolvedValue();
    return { service, prisma, seedUser };
  }

  it('ne fait rien hors mode démo', async () => {
    const { service, prisma, seedUser } = make(undefined);
    await service.seedIfEmpty({ id: 'u1', roles: [Role.PLAYER] });
    expect(service.enabled).toBe(false);
    expect(prisma.booking.count).not.toHaveBeenCalled();
    expect(seedUser).not.toHaveBeenCalled();
  });

  it('ne remplit jamais un compte administrateur', async () => {
    const { service, seedUser } = make('true');
    await service.seedIfEmpty({ id: 'admin', roles: [Role.PLAYER, Role.ADMIN] });
    expect(seedUser).not.toHaveBeenCalled();
  });

  it('remplit un compte joueur vide', async () => {
    const { service, seedUser } = make('true');
    await service.seedIfEmpty({ id: 'u1', roles: [Role.PLAYER] });
    expect(seedUser).toHaveBeenCalledWith('u1');
  });

  it("ne touche pas un compte qui a déjà de l'activité", async () => {
    const { service, seedUser } = make('true', { bookings: 2, matches: 0 });
    await service.seedIfEmpty({ id: 'u1', roles: [Role.PLAYER] });
    expect(seedUser).not.toHaveBeenCalled();
  });

  it('ne fait jamais échouer la connexion si le remplissage plante', async () => {
    const { service, seedUser } = make('true');
    seedUser.mockRejectedValue(new Error('boom'));
    await expect(service.seedIfEmpty({ id: 'u1', roles: [Role.PLAYER] })).resolves.toBeUndefined();
  });

  it('POST /auth/demo est introuvable hors mode démo', async () => {
    const { AuthService } = await import('../auth/auth.service');
    const { service } = make(undefined);
    const auth = new AuthService({} as any, {} as any, {} as any, {} as any, {} as any, service);
    await expect(auth.demoLogin()).rejects.toBeInstanceOf(NotFoundException);
  });
});
