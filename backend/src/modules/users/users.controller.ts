import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
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

  @HttpCode(HttpStatus.NO_CONTENT)
  @Delete('me')
  async deleteAccount(@CurrentUser() user: AuthUser) {
    await this.users.deleteAccount(user.userId);
  }
}
