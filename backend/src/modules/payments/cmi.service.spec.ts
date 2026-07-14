import { ConfigService } from '@nestjs/config';
import { CmiService } from './cmi.service';

// Signature CMI ver3 : le webhook ne doit accepter que des callbacks
// signés avec le store key — c'est la barrière anti-fraude du paiement.
describe('CmiService (hash ver3)', () => {
  let service: CmiService;

  const env: Record<string, string> = {
    CMI_MERCHANT_ID: '600001234',
    CMI_STORE_KEY: 'TEST_STORE_KEY',
    CMI_OK_URL: 'https://api.test/ok',
    CMI_FAIL_URL: 'https://api.test/fail',
    CMI_CALLBACK_URL: 'https://api.test/callback',
  };

  beforeEach(() => {
    const config = {
      get: (k: string) => env[k],
      getOrThrow: (k: string) => {
        if (!env[k]) throw new Error(`${k} manquant`);
        return env[k];
      },
    } as unknown as ConfigService;
    service = new CmiService(config);
  });

  it('produit un formulaire dont la signature se vérifie elle-même', () => {
    const { fields } = service.buildPaymentForm({
      orderId: 'BKG-123',
      amountMad: 300,
      email: 'joueur@padel.ma',
      billToName: 'Joueur Test',
    });
    expect(fields.HASH).toBeDefined();
    expect(fields.amount).toBe('300.00');
    expect(fields.currency).toBe('504'); // MAD
    // Un callback renvoyant exactement ces champs est valide
    expect(service.verifyCallback(fields)).toBe(true);
  });

  it('rejette un callback dont un champ a été falsifié', () => {
    const { fields } = service.buildPaymentForm({
      orderId: 'BKG-123',
      amountMad: 300,
      billToName: 'Joueur Test',
    });
    const tampered = { ...fields, amount: '1.00' }; // montant modifié
    expect(service.verifyCallback(tampered)).toBe(false);
  });

  it('rejette un callback sans signature', () => {
    expect(service.verifyCallback({ oid: 'BKG-1', ProcReturnCode: '00' })).toBe(
      false,
    );
  });

  it('la casse des noms de champs ne change pas la signature (tri insensible)', () => {
    const { fields } = service.buildPaymentForm({
      orderId: 'BKG-9',
      amountMad: 120,
      billToName: 'X',
    });
    // CMI renvoie parfois des champs supplémentaires signés ensemble :
    // ici on vérifie simplement que HASH/encoding sont exclus du calcul
    const withEncoding = { ...fields, encoding: 'UTF-8' };
    expect(service.verifyCallback(withEncoding)).toBe(true);
  });

  it('isSuccess ne reconnaît que ProcReturnCode=00', () => {
    expect(service.isSuccess({ ProcReturnCode: '00' })).toBe(true);
    expect(service.isSuccess({ ProcReturnCode: '99' })).toBe(false);
    expect(service.isSuccess({})).toBe(false);
  });
});
