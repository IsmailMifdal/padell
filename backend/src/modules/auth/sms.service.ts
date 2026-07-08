import { Injectable, Logger } from '@nestjs/common';

/**
 * Fournisseur SMS. En développement, le code est simplement loggé.
 * En production, brancher ici Twilio Verify ou un agrégateur marocain
 * (voir docs/04-apis-integrations.md §A.2.4).
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  async sendOtp(phone: string, code: string): Promise<void> {
    if (process.env.NODE_ENV === 'production') {
      // TODO: intégration Twilio / agrégateur local
      throw new Error('Fournisseur SMS non configuré en production');
    }
    this.logger.log(`[DEV] OTP pour ${phone} : ${code}`);
  }
}
