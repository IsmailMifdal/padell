import {
  IsEnum,
  IsISO8601,
  IsInt,
  IsNumber,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { MatchVisibility } from '@prisma/client';

export class CreateMatchDto {
  @IsUUID()
  courtId: string;

  /** Début du créneau, heure locale du club */
  @IsISO8601()
  startsAt: string;

  @IsInt()
  @Min(30)
  @Max(240)
  durationMin: number;

  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(1)
  @Max(7)
  levelMin: number;

  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(1)
  @Max(7)
  levelMax: number;

  @IsOptional()
  @IsEnum(MatchVisibility)
  visibility?: MatchVisibility;
}
