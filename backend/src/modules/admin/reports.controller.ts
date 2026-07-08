import { Body, Controller, Post } from '@nestjs/common';
import { ReportTargetType } from '@prisma/client';
import { IsEnum, IsNotEmpty, IsString, IsUUID, MaxLength } from 'class-validator';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../infra/prisma/prisma.service';

class CreateReportDto {
  @IsEnum(ReportTargetType)
  targetType: ReportTargetType;

  @IsUUID()
  targetId: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  reason: string;
}

/** Signalement d'un utilisateur ou d'un club par un joueur. */
@Controller('reports')
export class ReportsController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateReportDto) {
    return this.prisma.report.create({
      data: {
        reporterId: user.userId,
        targetType: dto.targetType,
        targetId: dto.targetId,
        reason: dto.reason,
      },
    });
  }
}
