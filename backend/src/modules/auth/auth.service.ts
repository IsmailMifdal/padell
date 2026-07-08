import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { OtpPurpose, User, UserStatus } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'crypto';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { SendOtpDto, VerifyOtpDto } from './dto/otp.dto';
import { SocialLoginDto, SocialProvider } from './dto/social-login.dto';
import { JwtPayload } from './jwt.strategy';
import { OtpService } from './otp.service';
import { SocialTokenService } from './social-token.service';

const BCRYPT_ROUNDS = 12;
const MAX_FAILED_LOGINS = 5;
const LOCKOUT_MINUTES = 15;

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AuthResult extends AuthTokens {
  user: {
    id: string;
    email: string | null;
    phone: string | null;
    roles: User['roles'];
    firstName: string;
    lastName: string;
  };
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly otp: OtpService,
    private readonly socialTokens: SocialTokenService,
  ) {}

  // ---------------------------------------------------------------- register

  async register(dto: RegisterDto, deviceInfo?: string): Promise<AuthResult> {
    if (!dto.email && !dto.phone) {
      throw new BadRequestException('Email ou téléphone requis');
    }

    if (dto.email) {
      const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
      if (existing) throw new ConflictException('Un compte existe déjà avec cet email');
    }
    if (dto.phone) {
      const existing = await this.prisma.user.findUnique({ where: { phone: dto.phone } });
      if (existing) throw new ConflictException('Un compte existe déjà avec ce numéro');
      // Le numéro doit avoir été vérifié par OTP avant l'inscription
      const verified = await this.otp.wasRecentlyVerified(dto.phone, OtpPurpose.REGISTER);
      if (!verified) {
        throw new ForbiddenException(
          'Numéro non vérifié : demandez et validez un code OTP (usage REGISTER) avant de créer le compte',
        );
      }
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email ?? null,
        phone: dto.phone ?? null,
        passwordHash,
        profile: {
          create: {
            firstName: dto.firstName,
            lastName: dto.lastName,
            city: dto.city ?? null,
          },
        },
      },
    });

    return this.buildAuthResult(user, dto.firstName, dto.lastName, deviceInfo);
  }

  // ------------------------------------------------------------------- login

  async login(dto: LoginDto): Promise<AuthResult> {
    const isEmail = dto.identifier.includes('@');
    const user = await this.prisma.user.findUnique({
      where: isEmail ? { email: dto.identifier } : { phone: dto.identifier },
      include: { profile: true },
    });

    // Message volontairement identique que le compte existe ou non
    const invalidCredentials = new UnauthorizedException('Identifiants incorrects');
    if (!user || !user.passwordHash) throw invalidCredentials;

    this.assertUsable(user);
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      throw new ForbiddenException(
        'Compte temporairement verrouillé suite à trop de tentatives, réessayez plus tard',
      );
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      const attempts = user.failedLoginAttempts + 1;
      await this.prisma.user.update({
        where: { id: user.id },
        data: {
          failedLoginAttempts: attempts,
          lockedUntil:
            attempts >= MAX_FAILED_LOGINS
              ? new Date(Date.now() + LOCKOUT_MINUTES * 60 * 1000)
              : null,
        },
      });
      throw invalidCredentials;
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { failedLoginAttempts: 0, lockedUntil: null, lastLoginAt: new Date() },
    });

    return this.buildAuthResult(
      user,
      user.profile?.firstName ?? '',
      user.profile?.lastName ?? '',
      dto.deviceInfo,
    );
  }

  // --------------------------------------------------------------------- otp

  async sendOtp(dto: SendOtpDto): Promise<{ sent: boolean }> {
    if (dto.purpose === OtpPurpose.LOGIN || dto.purpose === OtpPurpose.RESET_PASSWORD) {
      const user = await this.prisma.user.findUnique({ where: { phone: dto.phone } });
      if (!user) {
        // Ne pas révéler l'existence du compte : on répond "envoyé" sans envoyer
        return { sent: true };
      }
    }
    await this.otp.send(dto.phone, dto.purpose);
    return { sent: true };
  }

  /**
   * Vérifie le code. Pour LOGIN, retourne directement des tokens ;
   * pour REGISTER, le numéro est marqué vérifié (fenêtre de 10 min pour s'inscrire).
   */
  async verifyOtp(dto: VerifyOtpDto): Promise<AuthResult | { verified: boolean }> {
    await this.otp.verify(dto.phone, dto.purpose, dto.code);

    if (dto.purpose !== OtpPurpose.LOGIN) return { verified: true };

    const user = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
      include: { profile: true },
    });
    if (!user) throw new UnauthorizedException('Aucun compte associé à ce numéro');
    this.assertUsable(user);

    await this.prisma.user.update({
      where: { id: user.id },
      data: { failedLoginAttempts: 0, lockedUntil: null, lastLoginAt: new Date() },
    });

    return this.buildAuthResult(
      user,
      user.profile?.firstName ?? '',
      user.profile?.lastName ?? '',
    );
  }

  // ------------------------------------------------------------------ social

  /**
   * Connexion Google / Apple : vérifie l'id_token, rattache ou crée le compte.
   * Rattachement par providerId d'abord, puis par email vérifié.
   */
  async socialLogin(dto: SocialLoginDto): Promise<AuthResult> {
    const identity = await this.socialTokens.verify(dto.provider, dto.idToken);
    const providerField = dto.provider === SocialProvider.GOOGLE ? 'googleId' : 'appleId';

    let user = await this.prisma.user.findUnique({
      where: { [providerField]: identity.providerId } as any,
      include: { profile: true },
    });

    // Rattachement à un compte email existant (email vérifié par le provider)
    if (!user && identity.email && identity.emailVerified) {
      const byEmail = await this.prisma.user.findUnique({
        where: { email: identity.email },
        include: { profile: true },
      });
      if (byEmail) {
        user = await this.prisma.user.update({
          where: { id: byEmail.id },
          data: { [providerField]: identity.providerId },
          include: { profile: true },
        });
      }
    }

    if (!user) {
      const firstName = dto.firstName ?? identity.firstName ?? 'Joueur';
      const lastName = dto.lastName ?? identity.lastName ?? 'Padel';
      user = await this.prisma.user.create({
        data: {
          email: identity.emailVerified ? identity.email : null,
          [providerField]: identity.providerId,
          profile: { create: { firstName, lastName } },
        },
        include: { profile: true },
      });
    }

    this.assertUsable(user);
    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    return this.buildAuthResult(
      user,
      user.profile?.firstName ?? '',
      user.profile?.lastName ?? '',
      dto.deviceInfo,
    );
  }

  // ---------------------------------------------------------- reset password

  async resetPassword(dto: ResetPasswordDto): Promise<{ reset: boolean }> {
    await this.otp.verify(dto.phone, OtpPurpose.RESET_PASSWORD, dto.code);

    const user = await this.prisma.user.findUnique({ where: { phone: dto.phone } });
    if (!user) throw new UnauthorizedException('Aucun compte associé à ce numéro');
    this.assertUsable(user);

    const passwordHash = await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: { passwordHash, failedLoginAttempts: 0, lockedUntil: null },
      }),
      // Sécurité : toutes les sessions existantes sont invalidées
      this.prisma.refreshToken.updateMany({
        where: { userId: user.id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
    return { reset: true };
  }

  // ----------------------------------------------------------------- refresh

  async refresh(refreshToken: string): Promise<AuthTokens> {
    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });

    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Session expirée, reconnectez-vous');
    }
    this.assertUsable(stored.user);

    // Rotation : l'ancien token est révoqué, un nouveau est émis
    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });
    return this.issueTokens(stored.user, stored.deviceInfo ?? undefined);
  }

  async logout(refreshToken: string): Promise<void> {
    const tokenHash = this.hashToken(refreshToken);
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  // ----------------------------------------------------------------- interne

  private assertUsable(user: User): void {
    if (user.status === UserStatus.ACTIVE) return;
    if (user.status === UserStatus.DELETED) {
      throw new UnauthorizedException('Identifiants incorrects');
    }
    throw new ForbiddenException('Compte suspendu, contactez le support');
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private async issueTokens(user: User, deviceInfo?: string): Promise<AuthTokens> {
    const payload: JwtPayload = { sub: user.id, roles: user.roles };
    const accessToken = await this.jwt.signAsync(payload);

    const refreshToken = randomBytes(48).toString('hex');
    const ttlDays = Number(this.config.get('REFRESH_TOKEN_TTL_DAYS') ?? 30);
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: this.hashToken(refreshToken),
        deviceInfo: deviceInfo ?? null,
        expiresAt: new Date(Date.now() + ttlDays * 24 * 60 * 60 * 1000),
      },
    });

    return { accessToken, refreshToken };
  }

  private async buildAuthResult(
    user: User,
    firstName: string,
    lastName: string,
    deviceInfo?: string,
  ): Promise<AuthResult> {
    const tokens = await this.issueTokens(user, deviceInfo);
    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
        roles: user.roles,
        firstName,
        lastName,
      },
    };
  }
}
