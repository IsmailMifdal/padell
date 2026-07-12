import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateMatchDto } from './dto/create-match.dto';
import { RatePlayersDto, SubmitScoreDto } from './dto/score-rating.dto';
import { SearchMatchesQuery } from './dto/search-matches.query';
import { MatchesService } from './matches.service';

@Controller('matches')
export class MatchesController {
  constructor(private readonly matches: MatchesService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateMatchDto) {
    return this.matches.create(user, dto);
  }

  @Get()
  search(@Query() query: SearchMatchesQuery) {
    return this.matches.search(query);
  }

  @Get('mine')
  findMine(@CurrentUser() user: AuthUser) {
    return this.matches.findMine(user);
  }

  /** Suggestions « Pour toi » triées par score de compatibilité. */
  @Get('suggestions')
  suggestions(
    @CurrentUser() user: AuthUser,
    @Query('lat') lat: string,
    @Query('lng') lng: string,
  ) {
    return this.matches.suggestions(user, Number(lat), Number(lng));
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.matches.findOne(id);
  }

  @Post(':id/join')
  join(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.matches.join(user, id);
  }

  @Post(':id/players/:playerId/accept')
  accept(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
  ) {
    return this.matches.respondToRequest(user, id, playerId, true);
  }

  @Post(':id/players/:playerId/decline')
  decline(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('playerId', ParseUUIDPipe) playerId: string,
  ) {
    return this.matches.respondToRequest(user, id, playerId, false);
  }

  @Post(':id/withdraw')
  withdraw(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.matches.withdraw(user, id);
  }

  @Post(':id/cancel')
  cancel(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.matches.cancel(user, id);
  }

  @Post(':id/score')
  submitScore(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SubmitScoreDto,
  ) {
    return this.matches.submitScore(user, id, dto);
  }

  @Post(':id/rate')
  ratePlayers(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RatePlayersDto,
  ) {
    return this.matches.ratePlayers(user, id, dto);
  }

  @Get(':id/my-ratings')
  myRatings(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.matches.myRatings(user, id);
  }
}
