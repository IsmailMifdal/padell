import { PaymentsService } from './payments.service';

/**
 * Politique de remboursement à l'annulation : c'est de l'argent client —
 * 100 % si annulation avant le délai du club, sinon le pourcentage réduit.
 */
describe('PaymentsService — remboursement à l’annulation', () => {
  function makeService(booking: any, payment: any) {
    const paymentUpdates: any[] = [];
    const prisma = {
      booking: { findUnique: jest.fn().mockResolvedValue(booking) },
      payment: {
        findFirst: jest.fn().mockResolvedValue(payment),
        update: jest.fn().mockImplementation(({ data }: any) => {
          paymentUpdates.push(data);
          return Promise.resolve({});
        }),
      },
    } as any;
    const service = new PaymentsService(
      prisma,
      {} as any, // CmiService inutilisé ici
      { notify: jest.fn(), notifyMany: jest.fn() } as any,
      { send: jest.fn(), wrap: jest.fn() } as any,
    );
    return { service, paymentUpdates };
  }

  const hours = (h: number) => new Date(Date.now() + h * 3600_000);

  const makeBooking = (startsInHours: number, policy: unknown) => ({
    id: 'b1',
    startsAt: hours(startsInHours),
    court: { club: { cancellationPolicy: policy } },
  });

  const paidPayment = { id: 'p1', amountMad: 300, status: 'PAID' };

  it('annulation avant le délai libre → remboursement 100 %', async () => {
    const { service, paymentUpdates } = makeService(
      makeBooking(48, { freeUntilHours: 24, lateRefundPercent: 50 }),
      paidPayment,
    );
    await service.refundForCancelledBooking('b1');
    expect(paymentUpdates[0]).toEqual({
      status: 'REFUNDED',
      refundAmountMad: 300,
    });
  });

  it('annulation tardive → pourcentage réduit du club (50 %)', async () => {
    const { service, paymentUpdates } = makeService(
      makeBooking(2, { freeUntilHours: 24, lateRefundPercent: 50 }),
      paidPayment,
    );
    await service.refundForCancelledBooking('b1');
    expect(paymentUpdates[0]).toEqual({
      status: 'REFUNDED',
      refundAmountMad: 150,
    });
  });

  it('annulation tardive sans politique → défaut : aucun remboursement', async () => {
    const { service, paymentUpdates } = makeService(
      makeBooking(2, null),
      paidPayment,
    );
    await service.refundForCancelledBooking('b1');
    // 0 MAD remboursé : le paiement reste PAID (pas de faux statut REFUNDED)
    expect(paymentUpdates[0]).toEqual({ status: 'PAID', refundAmountMad: 0 });
  });

  it('sans paiement PAID (résa sur place ou impayée) → aucune écriture', async () => {
    const { service, paymentUpdates } = makeService(
      makeBooking(48, { freeUntilHours: 24 }),
      null,
    );
    await service.refundForCancelledBooking('b1');
    expect(paymentUpdates).toHaveLength(0);
  });
});
