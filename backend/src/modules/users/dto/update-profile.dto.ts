import {
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { CourtPosition, Gender, Handedness } from '@prisma/client';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  firstName?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  lastName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  /** URL publique de l'avatar (obtenue via POST /media/presign) */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatarUrl?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  @IsDateString()
  birthdate?: string;

  @IsOptional()
  @IsEnum(Handedness)
  handedness?: Handedness;

  @IsOptional()
  @IsEnum(CourtPosition)
  courtPosition?: CourtPosition;

  /** Niveau auto-évalué 1.0 - 7.0 (questionnaire) */
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 1 })
  @Min(1)
  @Max(7)
  level?: number;
}
