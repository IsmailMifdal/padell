import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { Messaging, getMessaging } from 'firebase-admin/messaging';
import { PrismaService } from '../../infra/prisma/prisma.service';

/**
 * Envoi push via Firebase Cloud Messaging (firebase-admin).
 *
 * Configuration : FIREBASE_SERVICE_ACCOUNT_BASE64 = JSON du compte de
 * service Firebase encodé en base64 (Console Firebase → Paramètres →
 * Comptes de service → Générer une clé privée).
 * Sans configuration : repli log (dev).
 */
@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);
  private messaging: Messaging | null = null;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  onModuleInit() {
    const b64 = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_BASE64');
    if (!b64) {
      this.logger.log('FCM non configuré — les push seront loggés (dev)');
      return;
    }
    try {
      const serviceAccount = JSON.parse(
        Buffer.from(b64, 'base64').toString('utf8'),
      );
      const app = getApps().length
        ? getApps()[0]
        : initializeApp({ credential: cert(serviceAccount) });
      this.messaging = getMessaging(app);
      this.logger.log(`FCM initialisé (projet ${serviceAccount.project_id})`);
    } catch (e) {
      this.logger.error(
        `FIREBASE_SERVICE_ACCOUNT_BASE64 invalide : ${e instanceof Error ? e.message : e}`,
      );
    }
  }

  async send(
    tokens: string[],
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    if (tokens.length === 0) return;

    if (!this.messaging) {
      this.logger.log(
        `[DEV] Push → ${tokens.length} appareil(s) : "${title}" — ${body} ${JSON.stringify(data)}`,
      );
      return;
    }

    const res = await this.messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });

    // Nettoyage des tokens expirés/désinstallés
    const invalid: string[] = [];
    res.responses.forEach((r, i) => {
      const code = r.error?.code ?? '';
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        invalid.push(tokens[i]);
      }
    });
    if (invalid.length > 0) {
      await this.prisma.deviceToken.deleteMany({
        where: { token: { in: invalid } },
      });
      this.logger.log(`${invalid.length} token(s) FCM invalide(s) supprimé(s)`);
    }
    if (res.failureCount > 0) {
      this.logger.warn(
        `Push : ${res.successCount} envoyé(s), ${res.failureCount} échec(s)`,
      );
    }
  }
}
