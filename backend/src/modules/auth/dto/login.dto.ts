import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class LoginDto {
  /** Email ou numéro de téléphone */
  @IsString()
  @IsNotEmpty()
  identifier: string;

  @IsString()
  @IsNotEmpty()
  password: string;

  @IsOptional()
  @IsString()
  deviceInfo?: string;
}
