import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { OtpPurpose } from '@prisma/client';
import { createHash, randomInt } from 'crypto';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { SmsService } from './sms.service';

const OTP_TTL_MINUTES = 5;
const MAX_VERIFY_ATTEMPTS = 3;
const RESEND_COOLDOWN_SECONDS = 60;
const VERIFIED_WINDOW_MINUTES = 10;

@Injectable()
export class OtpService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sms: SmsService,
  ) {}

  private hash(code: string): string {
    return createHash('sha256').update(code).digest('hex');
  }

  async send(phone: string, purpose: OtpPurpose): Promise<void> {
    // Anti-spam : 60 s entre deux envois pour le même numéro/usage
    const recent = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        purpose,
        createdAt: { gt: new Date(Date.now() - RESEND_COOLDOWN_SECONDS * 1000) },
      },
    });
    if (recent) {
      throw new HttpException(
        `Veuillez attendre ${RESEND_COOLDOWN_SECONDS} secondes avant de redemander un code`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const code = randomInt(100000, 1000000).toString();
    await this.prisma.otpCode.create({
      data: {
        phone,
        purpose,
        codeHash: this.hash(code),
        expiresAt: new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000),
      },
    });
    await this.sms.sendOtp(phone, code);
  }

  async verify(phone: string, purpose: OtpPurpose, code: string): Promise<boolean> {
    const otp = await this.prisma.otpCode.findFirst({
      where: { phone, purpose, consumedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) {
      throw new BadRequestException('Code expiré ou introuvable, redemandez un code');
    }
    if (otp.attempts >= MAX_VERIFY_ATTEMPTS) {
      throw new BadRequestException('Trop de tentatives, redemandez un code');
    }

    if (otp.codeHash !== this.hash(code)) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Code incorrect');
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { consumedAt: new Date() },
    });
    return true;
  }

  /**
   * Vérifie qu'un code a été consommé récemment pour ce numéro/usage
   * (ex : inscription par téléphone après vérification OTP).
   */
  async wasRecentlyVerified(phone: string, purpose: OtpPurpose): Promise<boolean> {
    const otp = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        purpose,
        consumedAt: { gt: new Date(Date.now() - VERIFIED_WINDOW_MINUTES * 60 * 1000) },
      },
    });
    return otp !== null;
  }
}
