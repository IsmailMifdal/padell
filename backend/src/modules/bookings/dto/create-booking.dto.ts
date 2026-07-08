import { IsEnum, IsISO8601, IsInt, IsUUID, Max, Min } from 'class-validator';
import { PaymentMode } from '@prisma/client';

export class CreateBookingDto {
  @IsUUID()
  courtId: string;

  /** Début du créneau, heure locale du club, ex : "2026-07-10T18:00:00" */
  @IsISO8601()
  startsAt: string;

  @IsInt()
  @Min(30)
  @Max(240)
  durationMin: number;

  @IsEnum(PaymentMode)
  paymentMode: PaymentMode;
}
