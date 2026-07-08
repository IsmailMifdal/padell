import { Type } from 'class-transformer';
import { IsArray, IsInt, Max, Min, ValidateNested } from 'class-validator';

export class OpeningHourItemDto {
  /** ISO : 1 = lundi ... 7 = dimanche */
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek: number;

  /** Minutes depuis minuit (540 = 09:00) */
  @IsInt()
  @Min(0)
  @Max(1440)
  openMin: number;

  @IsInt()
  @Min(0)
  @Max(1440)
  closeMin: number;
}

/** Remplace l'intégralité des horaires du club (PUT). */
export class SetOpeningHoursDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => OpeningHourItemDto)
  hours: OpeningHourItemDto[];
}
