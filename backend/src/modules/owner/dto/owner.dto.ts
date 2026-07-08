import {
  IsISO8601,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CalendarQuery {
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'Format attendu : YYYY-MM-DD' })
  from: string;

  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'Format attendu : YYYY-MM-DD' })
  to: string;
}

/** Réservation téléphonique / au comptoir, saisie par le club. */
export class ManualBookingDto {
  @IsUUID()
  courtId: string;

  @IsISO8601()
  startsAt: string;

  @IsInt()
  @Min(30)
  @Max(240)
  durationMin: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  priceMad?: number;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  customerName?: string;
}

/** Blocage d'un créneau (maintenance, cours, événement privé). */
export class BlockSlotDto {
  @IsUUID()
  courtId: string;

  @IsISO8601()
  startsAt: string;

  @IsInt()
  @Min(30)
  @Max(1440)
  durationMin: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  reason?: string;
}

export class CheckinDto {
  @IsString()
  @IsNotEmpty()
  qrCode: string;
}

export class ComputePayoutDto {
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'Format attendu : YYYY-MM-DD' })
  periodStart: string;

  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'Format attendu : YYYY-MM-DD' })
  periodEnd: string;
}
