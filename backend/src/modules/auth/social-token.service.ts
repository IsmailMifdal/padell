import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createRemoteJWKSet, jwtVerify, JWTPayload } from 'jose';
import { SocialProvider } from './dto/social-login.dto';

export interface SocialIdentity {
  providerId: string;
  email: string | null;
  emailVerified: boolean;
  firstName?: string;
  lastName?: string;
}

const GOOGLE_JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/oauth2/v3/certs'),
);
const APPLE_JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

/** Vérifie les id_tokens Google / Apple (signature JWKS + issuer + audience). */
@Injectable()
export class SocialTokenService {
  constructor(private readonly config: ConfigService) {}

  async verify(provider: SocialProvider, idToken: string): Promise<SocialIdentity> {
    try {
      const payload =
        provider === SocialProvider.GOOGLE
          ? await this.verifyGoogle(idToken)
          : await this.verifyApple(idToken);

      if (!payload.sub) throw new Error('sub manquant');
      return {
        providerId: payload.sub,
        email: typeof payload.email === 'string' ? payload.email : null,
        emailVerified:
          payload.email_verified === true || payload.email_verified === 'true',
        firstName: typeof payload.given_name === 'string' ? payload.given_name : undefined,
        lastName: typeof payload.family_name === 'string' ? payload.family_name : undefined,
      };
    } catch {
      throw new UnauthorizedException(`Jeton ${provider} invalide ou expiré`);
    }
  }

  private async verifyGoogle(idToken: string): Promise<JWTPayload> {
    const { payload } = await jwtVerify(idToken, GOOGLE_JWKS, {
      issuer: ['https://accounts.google.com', 'accounts.google.com'],
      audience: this.config.getOrThrow<string>('GOOGLE_CLIENT_ID'),
    });
    return payload;
  }

  private async verifyApple(idToken: string): Promise<JWTPayload> {
    const { payload } = await jwtVerify(idToken, APPLE_JWKS, {
      issuer: 'https://appleid.apple.com',
      audience: this.config.getOrThrow<string>('APPLE_CLIENT_ID'),
    });
    return payload;
  }
}
