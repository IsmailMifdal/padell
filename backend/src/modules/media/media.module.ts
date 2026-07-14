import { Body, Controller, Module, Post } from '@nestjs/common';
import { IsIn, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { MediaService } from './media.service';

class PresignDto {
  @IsIn(['avatar', 'club_photo'])
  kind: string;

  @IsString()
  @IsIn(['image/jpeg', 'image/png', 'image/webp'])
  contentType: string;
}

@Controller('media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  /** URL présignée pour uploader une image directement vers S3/R2. */
  @Post('presign')
  presign(@CurrentUser() user: AuthUser, @Body() dto: PresignDto) {
    return this.media.presign(dto.kind, dto.contentType, user.userId);
  }
}

@Module({
  controllers: [MediaController],
  providers: [MediaService],
})
export class MediaModule {}
