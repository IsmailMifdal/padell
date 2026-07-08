import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { AvailabilityQuery } from './dto/availability.query';
import { AvailabilityService } from './availability.service';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { IsOptional, IsString, MaxLength } from 'class-validator';

class CancelBookingDto {
  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}

@Controller()
export class BookingsController {
  constructor(
    private readonly bookings: BookingsService,
    private readonly availability: AvailabilityService,
  ) {}

  /** Grille des créneaux disponibles d'un club pour un jour donné. */
  @Public()
  @Get('clubs/:id/availability')
  clubAvailability(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: AvailabilityQuery,
  ) {
    return this.availability.forClubDay(id, query.date);
  }

  @Post('bookings')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateBookingDto) {
    return this.bookings.create(user, dto);
  }

  @Get('bookings/mine')
  findMine(@CurrentUser() user: AuthUser) {
    return this.bookings.findMine(user);
  }

  @Get('bookings/:id')
  findOne(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.bookings.findOne(user, id);
  }

  @Post('bookings/:id/cancel')
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelBookingDto,
  ) {
    return this.bookings.cancel(user, id, dto.reason);
  }
}
