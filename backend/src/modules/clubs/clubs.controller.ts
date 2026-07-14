import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { ClubsService } from './clubs.service';
import { CreateClubDto, UpdateClubDto } from './dto/create-club.dto';
import { CreateCourtDto, UpdateCourtDto } from './dto/court.dto';
import { SetOpeningHoursDto } from './dto/opening-hours.dto';
import { CreatePricingRuleDto } from './dto/pricing-rule.dto';
import { SearchClubsQuery } from './dto/search-clubs.query';
import { IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

class CreateReviewDto {
  @IsUUID()
  bookingId: string;

  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;

  @IsOptional()
  @IsString()
  @MaxLength(600)
  comment?: string;
}

@Controller('clubs')
export class ClubsController {
  constructor(private readonly clubs: ClubsService) {}

  // Public : recherche et fiche club
  @Public()
  @Get()
  search(@Query() query: SearchClubsQuery) {
    return this.clubs.search(query);
  }

  @Get('mine')
  findMine(@CurrentUser() user: AuthUser) {
    return this.clubs.findMine(user);
  }

  @Public()
  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.clubs.findOnePublic(id);
  }

  @Public()
  @Get(':id/reviews')
  listReviews(@Param('id', ParseUUIDPipe) id: string) {
    return this.clubs.listReviews(id);
  }

  @Post(':id/reviews')
  addReview(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateReviewDto,
  ) {
    return this.clubs.addReview(user, id, dto.bookingId, dto.rating, dto.comment);
  }

  // Propriétaire
  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateClubDto) {
    return this.clubs.create(user, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateClubDto,
  ) {
    return this.clubs.update(user, id, dto);
  }

  @Post(':id/courts')
  addCourt(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateCourtDto,
  ) {
    return this.clubs.addCourt(user, id, dto);
  }

  @Patch(':id/courts/:courtId')
  updateCourt(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('courtId', ParseUUIDPipe) courtId: string,
    @Body() dto: UpdateCourtDto,
  ) {
    return this.clubs.updateCourt(user, id, courtId, dto);
  }

  @Put(':id/opening-hours')
  setOpeningHours(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SetOpeningHoursDto,
  ) {
    return this.clubs.setOpeningHours(user, id, dto);
  }

  @Post(':id/courts/:courtId/pricing')
  addPricingRule(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('courtId', ParseUUIDPipe) courtId: string,
    @Body() dto: CreatePricingRuleDto,
  ) {
    return this.clubs.addPricingRule(user, id, courtId, dto);
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete(':id/pricing/:ruleId')
  deletePricingRule(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('ruleId', ParseUUIDPipe) ruleId: string,
  ) {
    return this.clubs.deletePricingRule(user, id, ruleId);
  }
}
