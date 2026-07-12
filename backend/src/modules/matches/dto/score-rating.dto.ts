import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

/** Saisie du score par l'organisateur après le match. */
export class SubmitScoreDto {
  /** Les 2 joueurs vainqueurs (parmi les 4 participants acceptés) */
  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(2)
  @IsUUID('4', { each: true })
  winnerIds: string[];

  /** Score affiché, ex : "6-4, 3-6, 7-5" */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  score?: string;
}

export class RateItemDto {
  @IsUUID()
  playerId: string;

  @IsInt()
  @Min(1)
  @Max(5)
  punctuality: number;

  @IsInt()
  @Min(1)
  @Max(5)
  fairplay: number;

  @IsInt()
  @Min(1)
  @Max(5)
  levelAccuracy: number;
}

/** Notation des partenaires (1 à 5 étoiles par critère). */
export class RatePlayersDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(3)
  @ValidateNested({ each: true })
  @Type(() => RateItemDto)
  items: RateItemDto[];
}
