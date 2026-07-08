import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, randomBytes } from 'crypto';

/**
 * Intégration passerelle CMI (Centre Monétique Interbancaire, Maroc).
 * Modèle « 3D_PAY_HOSTING » : le mobile poste un formulaire vers la page CMI,
 * le serveur ne voit jamais la carte. Signature hashAlgorithm ver3 (SHA-512).
 * Voir docs/04-apis-integrations.md.
 */
@Injectable()
export class CmiService {
  private readonly logger = new Logger(CmiService.name);

  constructor(private readonly config: ConfigService) {}

  get gatewayUrl(): string {
    return (
      this.config.get<string>('CMI_GATEWAY_URL') ??
      'https://testpayment.cmi.co.ma/fim/est3Dgate'
    );
  }

  /** Champs du formulaire de paiement à poster par la webview mobile. */
  buildPaymentForm(params: {
    orderId: string;
    amountMad: number;
    email?: string | null;
    billToName: string;
  }): { gatewayUrl: string; fields: Record<string, string> } {
    const fields: Record<string, string> = {
      clientid: this.config.getOrThrow<string>('CMI_MERCHANT_ID'),
      storetype: '3D_PAY_HOSTING',
      trantype: 'PreAuth',
      currency: '504', // MAD
      amount: params.amountMad.toFixed(2),
      oid: params.orderId,
      okUrl: this.config.getOrThrow<string>('CMI_OK_URL'),
      failUrl: this.config.getOrThrow<string>('CMI_FAIL_URL'),
      callbackUrl: this.config.getOrThrow<string>('CMI_CALLBACK_URL'),
      lang: 'fr',
      hashAlgorithm: 'ver3',
      encoding: 'UTF-8',
      rnd: randomBytes(8).toString('hex'),
      BillToName: params.billToName,
      ...(params.email ? { email: params.email } : {}),
    };
    fields.HASH = this.computeHash(fields);
    return { gatewayUrl: this.gatewayUrl, fields };
  }

  /**
   * Vérifie la signature d'un callback CMI. Retourne false si absente/invalide.
   * L'algorithme ver3 : valeurs triées par nom de champ (insensible à la casse),
   * jointes par « | » (échappement de \ et |), suivies du store key, SHA-512 → base64.
   */
  verifyCallback(body: Record<string, string>): boolean {
    const received = body.HASH;
    if (!received) return false;
    const expected = this.computeHash(body);
    return expected === received;
  }

  isSuccess(body: Record<string, string>): boolean {
    return body.ProcReturnCode === '00';
  }

  private computeHash(fields: Record<string, string>): string {
    const storeKey = this.config.getOrThrow<string>('CMI_STORE_KEY');
    const escape = (v: string) => v.replace(/\\/g, '\\\\').replace(/\|/g, '\\|');

    const plaintext =
      Object.keys(fields)
        .filter((k) => !['hash', 'encoding'].includes(k.toLowerCase()))
        .sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()))
        .map((k) => escape(fields[k] ?? ''))
        .join('|') +
      '|' +
      escape(storeKey);

    return createHash('sha512').update(plaintext, 'utf8').digest('base64');
  }
}
