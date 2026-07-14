import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Emails transactionnels via Brevo (ex-Sendinblue), API REST en fetch natif.
 *
 * Configuration : BREVO_API_KEY (+ EMAIL_FROM, EMAIL_FROM_NAME optionnels).
 * Sans clé : repli log (dev). Les échecs sont loggés sans bloquer le flux
 * appelant (l'email est un canal secondaire, la notification in-app prime).
 */
@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);

  constructor(private readonly config: ConfigService) {}

  async send(to: string, subject: string, html: string): Promise<void> {
    const apiKey = this.config.get<string>('BREVO_API_KEY');
    if (!apiKey) {
      this.logger.log(`[DEV] Email → ${to} : "${subject}"`);
      return;
    }

    try {
      const res = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
          'api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          sender: {
            email: this.config.get('EMAIL_FROM') ?? 'no-reply@padel.ma',
            name: this.config.get('EMAIL_FROM_NAME') ?? 'Padel',
          },
          to: [{ email: to }],
          subject,
          htmlContent: html,
        }),
      });
      if (!res.ok) {
        this.logger.error(`Brevo ${res.status} : ${await res.text()}`);
      }
    } catch (e) {
      this.logger.error(
        `Envoi email impossible : ${e instanceof Error ? e.message : e}`,
      );
    }
  }

  /** Gabarit simple aux couleurs de l'app. */
  wrap(title: string, lines: string[]): string {
    return `
      <div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto">
        <div style="background:linear-gradient(135deg,#10B981,#047857);border-radius:12px;padding:24px;color:#fff">
          <h2 style="margin:0">🎾 ${title}</h2>
        </div>
        <div style="padding:20px 8px;color:#1a1d21;line-height:1.6">
          ${lines.map((l) => `<p style="margin:0 0 10px">${l}</p>`).join('')}
        </div>
        <p style="color:#6b7280;font-size:12px">Padel — réservation & matching de padel au Maroc</p>
      </div>`;
  }
}
