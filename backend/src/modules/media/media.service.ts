import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomBytes } from 'crypto';

const ALLOWED_TYPES: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

const KIND_PREFIX: Record<string, string> = {
  avatar: 'avatars',
  club_photo: 'clubs',
};

/**
 * Upload de médias par URL présignée : le backend signe, l'app upload
 * directement vers S3/R2 (aucune charge serveur, cf. docs/04 §A.2.6).
 *
 * Configuration : S3_BUCKET, S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY,
 * S3_REGION (défaut auto), S3_ENDPOINT (pour Cloudflare R2/MinIO),
 * S3_PUBLIC_URL (base des URLs publiques, ex CDN).
 */
@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);
  private client: S3Client | null = null;

  constructor(private readonly config: ConfigService) {
    const bucket = this.config.get<string>('S3_BUCKET');
    const accessKeyId = this.config.get<string>('S3_ACCESS_KEY_ID');
    const secretAccessKey = this.config.get<string>('S3_SECRET_ACCESS_KEY');
    if (bucket && accessKeyId && secretAccessKey) {
      this.client = new S3Client({
        region: this.config.get<string>('S3_REGION') ?? 'auto',
        endpoint: this.config.get<string>('S3_ENDPOINT') || undefined,
        credentials: { accessKeyId, secretAccessKey },
      });
      this.logger.log(`Stockage médias configuré (bucket ${bucket})`);
    } else {
      this.logger.log('S3_* non configuré — upload de médias indisponible (dev)');
    }
  }

  /** Génère une URL d'upload (PUT, 10 min) et l'URL publique du fichier. */
  async presign(kind: string, contentType: string, userId: string) {
    if (!this.client) {
      throw new ServiceUnavailableException(
        'Stockage médias non configuré (variables S3_* absentes)',
      );
    }
    const prefix = KIND_PREFIX[kind];
    if (!prefix) {
      throw new BadRequestException('kind : avatar | club_photo');
    }
    const ext = ALLOWED_TYPES[contentType];
    if (!ext) {
      throw new BadRequestException('Type accepté : image/jpeg, png ou webp');
    }

    const bucket = this.config.getOrThrow<string>('S3_BUCKET');
    const key = `${prefix}/${userId}/${Date.now()}-${randomBytes(6).toString('hex')}.${ext}`;

    const uploadUrl = await getSignedUrl(
      this.client,
      new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        ContentType: contentType,
      }),
      { expiresIn: 600 },
    );

    const publicBase =
      this.config.get<string>('S3_PUBLIC_URL') ??
      `https://${bucket}.s3.amazonaws.com`;

    return { uploadUrl, publicUrl: `${publicBase}/${key}`, key };
  }
}
