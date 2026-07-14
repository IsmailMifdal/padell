import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Envoi de SMS OTP via Twilio (API REST, fetch natif — aucune dépendance).
 *
 * Configuration requise (sinon repli : code loggé, utile en dev) :
 * - TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN
 * - TWILIO_FROM (numéro expéditeur ou Alphanumeric Sender ID)
 *
 * Au volume, comparer avec un agrégateur marocain (Infobip, SMSCloud) —
 * même contrat d'interface, seul ce service change.
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly config: ConfigService) {}

  private get credentials() {
    const sid = this.config.get<string>('TWILIO_ACCOUNT_SID');
    const token = this.config.get<string>('TWILIO_AUTH_TOKEN');
    const from = this.config.get<string>('TWILIO_FROM');
    return sid && token && from ? { sid, token, from } : null;
  }

  async sendOtp(phone: string, code: string): Promise<void> {
    const creds = this.credentials;
    if (!creds) {
      // Repli développement : le code apparaît dans les logs de l'API
      this.logger.log(`[DEV] OTP pour ${phone} : ${code}`);
      if (process.env.NODE_ENV === 'production') {
        this.logger.error(
          'TWILIO_* non configuré en production — SMS non envoyé',
        );
      }
      return;
    }

    const body = new URLSearchParams({
      To: phone,
      From: creds.from,
      Body: `Padel : votre code de vérification est ${code}. Il expire dans 5 minutes.`,
    });

    const res = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${creds.sid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          Authorization:
            'Basic ' +
            Buffer.from(`${creds.sid}:${creds.token}`).toString('base64'),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body,
      },
    );

    if (!res.ok) {
      const detail = await res.text();
      this.logger.error(`Échec envoi SMS Twilio (${res.status}) : ${detail}`);
      throw new Error('Envoi du SMS impossible, réessayez');
    }
    this.logger.log(`SMS OTP envoyé à ${phone} via Twilio`);
  }
}
