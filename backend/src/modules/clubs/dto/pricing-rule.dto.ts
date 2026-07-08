import { IsInt, IsNumber, Max, Min } from 'class-validator';

export class CreatePricingRuleDto {
  /** ISO : 1 = lundi ... 7 = dimanche */
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek: number;

  /** Minutes depuis minuit */
  @IsInt()
  @Min(0)
  @Max(1440)
  startMin: number;

  @IsInt()
  @Min(0)
  @Max(1440)
  endMin: number;

  /** Durée d'un créneau en minutes (60, 90, 120...) */
  @IsInt()
  @Min(30)
  @Max(240)
  durationMin: number;

  /** Prix total du créneau en MAD */
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  priceMad: number;
}
