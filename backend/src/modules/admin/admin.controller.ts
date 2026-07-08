import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ClubStatus, ReportStatus, Role, UserStatus } from '@prisma/client';
import { IsEnum, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';
import { Roles } from '../../common/decorators/roles.decorator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { AdminService } from './admin.service';

class ListClubsQuery {
  @IsOptional()
  @IsEnum(ClubStatus)
  status?: ClubStatus;
}

class ListReportsQuery {
  @IsOptional()
  @IsEnum(ReportStatus)
  status?: ReportStatus;
}

@Roles(Role.ADMIN)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('kpis')
  kpis() {
    return this.admin.kpis();
  }

  // Clubs : validation / rejet / suspension
  @Get('clubs')
  listClubs(@Query() query: ListClubsQuery) {
    return this.admin.listClubs(query.status);
  }

  @Post('clubs/:id/approve')
  approveClub(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.admin.setClubStatus(user.userId, id, ClubStatus.APPROVED);
  }

  @Post('clubs/:id/reject')
  rejectClub(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.admin.setClubStatus(user.userId, id, ClubStatus.REJECTED);
  }

  @Post('clubs/:id/suspend')
  suspendClub(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.admin.setClubStatus(user.userId, id, ClubStatus.SUSPENDED);
  }

  // Utilisateurs
  @Get('users')
  listUsers(
    @Query('q') q?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.admin.listUsers(q, Number(page) || 1, Math.min(Number(limit) || 50, 100));
  }

  @Post('users/:id/suspend')
  suspendUser(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.admin.setUserStatus(user.userId, id, UserStatus.SUSPENDED);
  }

  @Post('users/:id/ban')
  banUser(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.admin.setUserStatus(user.userId, id, UserStatus.BANNED);
  }

  @Post('users/:id/reactivate')
  reactivateUser(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.admin.setUserStatus(user.userId, id, UserStatus.ACTIVE);
  }

  // Modération
  @Get('reports')
  listReports(@Query() query: ListReportsQuery) {
    return this.admin.listReports(query.status);
  }

  @Post('reports/:id/resolve')
  resolveReport(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.admin.handleReport(user.userId, id, true);
  }

  @Post('reports/:id/dismiss')
  dismissReport(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.admin.handleReport(user.userId, id, false);
  }

  @Get('audit-log')
  auditLog(@Query('page') page?: string) {
    return this.admin.auditLog(Number(page) || 1);
  }
}
