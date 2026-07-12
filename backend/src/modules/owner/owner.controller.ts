import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { IsOptional, IsString, MaxLength, Matches } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { ClubsService } from '../clubs/clubs.service';
import { PaymentsService } from '../payments/payments.service';
import {
  BlockSlotDto,
  CalendarQuery,
  CheckinDto,
  ComputePayoutDto,
  ManualBookingDto,
} from './dto/owner.dto';
import { OwnerService } from './owner.service';

class OwnerCancelDto {
  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}

/** Espace propriétaire : gestion opérationnelle d'un club. */
@Controller('owner/clubs/:clubId')
export class OwnerController {
  constructor(
    private readonly owner: OwnerService,
    private readonly clubs: ClubsService,
    private readonly payments: PaymentsService,
  ) {}

  @Get('calendar')
  calendar(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Query() query: CalendarQuery,
  ) {
    return this.owner.calendar(user, clubId, query);
  }

  @Post('bookings/manual')
  createManualBooking(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Body() dto: ManualBookingDto,
  ) {
    return this.owner.createManualBooking(user, clubId, dto);
  }

  @Post('bookings/block')
  blockSlot(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Body() dto: BlockSlotDto,
  ) {
    return this.owner.blockSlot(user, clubId, dto);
  }

  @Post('bookings/:bookingId/cancel')
  cancelBooking(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
    @Body() dto: OwnerCancelDto,
  ) {
    return this.owner.cancelBooking(user, clubId, bookingId, dto.reason);
  }

  @Post('checkin')
  checkin(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Body() dto: CheckinDto,
  ) {
    return this.owner.checkin(user, clubId, dto);
  }

  /** Statistiques d'exploitation (remplissage, revenus, heures pleines). */
  @Get('stats')
  stats(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Query('days') days?: string,
  ) {
    return this.owner.stats(user, clubId, Math.min(Number(days) || 30, 365));
  }

  @Get('payouts')
  async listPayouts(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
  ) {
    await this.clubs.assertOwnership(user, clubId);
    return this.payments.listPayouts(clubId);
  }

  @Post('payouts/compute')
  async computePayout(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
    @Body() dto: ComputePayoutDto,
  ) {
    await this.clubs.assertOwnership(user, clubId);
    return this.payments.computePayout(
      clubId,
      new Date(`${dto.periodStart}T00:00:00`),
      new Date(`${dto.periodEnd}T00:00:00`),
    );
  }
}
