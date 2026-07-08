import { Injectable, Logger } from '@nestjs/common';

/**
 * Envoi push FCM. En développement (pas de FIREBASE_SERVICE_ACCOUNT), les
 * notifications sont simplement loggées. En production, brancher firebase-admin :
 * admin.messaging().sendEachForMulticast({ tokens, notification, data }).
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  async send(
    tokens: string[],
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    if (tokens.length === 0) return;
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      // TODO: intégration firebase-admin (compte de service en variable d'env)
      this.logger.warn('FIREBASE_SERVICE_ACCOUNT défini mais firebase-admin non branché');
      return;
    }
    this.logger.log(
      `[DEV] Push → ${tokens.length} appareil(s) : "${title}" — ${body} ${JSON.stringify(data)}`,
    );
  }
}
