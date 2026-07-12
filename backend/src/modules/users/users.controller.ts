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
  Put,
} from '@nestjs/common';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { SetAvailabilitiesDto } from './dto/availability.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  getMe(@CurrentUser() user: AuthUser) {
    return this.users.getMe(user.userId);
  }

  @Patch('me/profile')
  updateProfile(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.users.updateProfile(user.userId, dto);
  }

  @Get('me/availabilities')
  getAvailabilities(@CurrentUser() user: AuthUser) {
    return this.users.getAvailabilities(user.userId);
  }

  @Put('me/availabilities')
  setAvailabilities(@CurrentUser() user: AuthUser, @Body() dto: SetAvailabilitiesDto) {
    return this.users.setAvailabilities(user.userId, dto);
  }

  @Get('me/stats')
  stats(@CurrentUser() user: AuthUser) {
    return this.users.stats(user.userId);
  }

  @Get('me/favorites/clubs')
  listFavorites(@CurrentUser() user: AuthUser) {
    return this.users.listFavoriteClubs(user.userId);
  }

  @Put('me/favorites/clubs/:clubId')
  addFavorite(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
  ) {
    return this.users.addFavoriteClub(user.userId, clubId);
  }

  @Delete('me/favorites/clubs/:clubId')
  removeFavorite(
    @CurrentUser() user: AuthUser,
    @Param('clubId', ParseUUIDPipe) clubId: string,
  ) {
    return this.users.removeFavoriteClub(user.userId, clubId);
  }

  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete('me')
  async deleteAccount(@CurrentUser() user: AuthUser) {
    await this.users.deleteAccount(user.userId);
  }
}
