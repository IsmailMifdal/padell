import { PartialType } from '@nestjs/mapped-types';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { CourtType } from '@prisma/client';

export class CreateCourtDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  name: string;

  @IsOptional()
  @IsEnum(CourtType)
  type?: CourtType;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  photos?: string[];
}

export class UpdateCourtDto extends PartialType(CreateCourtDto) {
  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
