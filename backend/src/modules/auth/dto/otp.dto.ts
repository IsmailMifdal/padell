import { IsEnum, IsNotEmpty, IsPhoneNumber, IsString, Length } from 'class-validator';
import { OtpPurpose } from '@prisma/client';

export class SendOtpDto {
  @IsPhoneNumber('MA', { message: 'Numéro de téléphone marocain invalide' })
  phone: string;

  @IsEnum(OtpPurpose)
  purpose: OtpPurpose;
}

export class VerifyOtpDto {
  @IsPhoneNumber('MA', { message: 'Numéro de téléphone marocain invalide' })
  phone: string;

  @IsEnum(OtpPurpose)
  purpose: OtpPurpose;

  @IsString()
  @IsNotEmpty()
  @Length(6, 6)
  code: string;
}
