import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { ChatService } from './chat.service';

@Controller('matches/:matchId/messages')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  /** Historique du chat d'un match (participants uniquement). */
  @Get()
  history(
    @CurrentUser() user: AuthUser,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ) {
    return this.chat.history(user.userId, matchId);
  }
}
