import { IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export enum SocialProvider {
  GOOGLE = 'GOOGLE',
  APPLE = 'APPLE',
}

export class SocialLoginDto {
  @IsEnum(SocialProvider)
  provider: SocialProvider;

  /** Jeton d'identité (id_token) émis par Google ou Apple côté mobile */
  @IsString()
  @IsNotEmpty()
  idToken: string;

  // Apple ne transmet le nom qu'au premier sign-in, côté client uniquement
  @IsOptional()
  @IsString()
  @MaxLength(50)
  firstName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  lastName?: string;

  @IsOptional()
  @IsString()
  deviceInfo?: string;
}
