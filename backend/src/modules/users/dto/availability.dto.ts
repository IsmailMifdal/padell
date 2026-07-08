import { Type } from 'class-transformer';
import { IsArray, IsInt, Max, Min, ValidateNested } from 'class-validator';

export class AvailabilityItemDto {
  /** ISO : 1 = lundi ... 7 = dimanche */
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek: number;

  /** Minutes depuis minuit (1080 = 18:00) */
  @IsInt()
  @Min(0)
  @Max(1440)
  startMin: number;

  @IsInt()
  @Min(0)
  @Max(1440)
  endMin: number;
}

/** Remplace l'intégralité des disponibilités du joueur (PUT). */
export class SetAvailabilitiesDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AvailabilityItemDto)
  availabilities: AvailabilityItemDto[];
}
