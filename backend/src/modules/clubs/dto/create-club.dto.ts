import { PartialType } from '@nestjs/mapped-types';
import {
  IsArray,
  IsBoolean,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateClubDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  address: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  city: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;

  /** Équipements : ["parking", "douches", "cafeteria", ...] */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  amenities?: string[];

  /** Politique d'annulation, ex : { "freeUntilHours": 24, "refundPercent": 100 } */
  @IsOptional()
  @IsObject()
  cancellationPolicy?: Record<string, unknown>;

  @IsOptional()
  @IsBoolean()
  paymentOnSiteAllowed?: boolean;
}

export class UpdateClubDto extends PartialType(CreateClubDto) {}
