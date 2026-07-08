import {
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { ClubsService } from '../clubs/clubs.service';
import { PaymentsService } from './payments.service';

@Controller('payments')
export class PaymentsController {
  constructor(
    private readonly payments: PaymentsService,
    private readonly clubs: ClubsService,
  ) {}

  /** Formulaire de paiement CMI d'une réservation (posté par la webview). */
  @Post('bookings/:id/session')
  createBookingSession(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payments.createBookingSession(user, id);
  }

  /** Formulaire de paiement CMI de la part d'un joueur dans un match. */
  @Post('matches/:id/session')
  createMatchSession(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.payments.createMatchSession(user, id);
  }

  /** Callback serveur CMI (signé, idempotent). Réponse en texte brut. */
  @Public()
  @HttpCode(HttpStatus.OK)
  @Header('Content-Type', 'text/plain')
  @Post('cmi/callback')
  cmiCallback(@Body() body: Record<string, string>) {
    return this.payments.handleCmiCallback(body);
  }

  @Get('mine')
  findMine(@CurrentUser() user: AuthUser) {
    return this.payments.findMine(user);
  }

  /** Reversements d'un club (propriétaire ou admin). */
  @Get('clubs/:clubId/payouts')
  async listPayouts(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
  ) {
    await this.clubs.assertOwnership(user, clubId);
    return this.payments.listPayouts(clubId);
  }
}
