import { Matches } from 'class-validator';

export class AvailabilityQuery {
  /** Jour demandé au format YYYY-MM-DD (heure locale du club) */
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'Format de date attendu : YYYY-MM-DD' })
  date: string;
}
