import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  BookingStatus,
  ClubStatus,
  MatchStatus,
  PaymentStatus,
  Prisma,
  ReportStatus,
  Role,
  UserStatus,
} from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  /** Toute action admin est tracée dans l'audit log. */
  private async audit(
    adminId: string,
    action: string,
    targetType: string,
    targetId: string,
    payload?: Record<string, unknown>,
  ) {
    await this.prisma.adminAuditLog.create({
      data: {
        adminId,
        action,
        targetType,
        targetId,
        payload: (payload as Prisma.InputJsonValue) ?? Prisma.JsonNull,
      },
    });
  }

  // -------------------------------------------------------------------- KPIs

  async kpis() {
    const since30d = new Date(Date.now() - 30 * 24 * 3600 * 1000);
    const [
      totalUsers,
      newUsers30d,
      clubsByStatus,
      bookings30d,
      gmv30d,
      matchesConfirmed30d,
      openReports,
    ] = await this.prisma.$transaction([
      this.prisma.user.count({ where: { status: { not: UserStatus.DELETED } } }),
      this.prisma.user.count({ where: { createdAt: { gte: since30d } } }),
      this.prisma.club.groupBy({
        by: ['status'],
        _count: true,
        orderBy: { status: 'asc' },
      }),
      this.prisma.booking.count({
        where: {
          createdAt: { gte: since30d },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
        },
      }),
      this.prisma.payment.aggregate({
        where: { status: PaymentStatus.PAID, createdAt: { gte: since30d } },
        _sum: { amountMad: true, commissionMad: true },
      }),
      this.prisma.match.count({
        where: { status: MatchStatus.CONFIRMED, createdAt: { gte: since30d } },
      }),
      this.prisma.report.count({ where: { status: ReportStatus.OPEN } }),
    ]);

    return {
      users: { total: totalUsers, new30d: newUsers30d },
      clubs: Object.fromEntries(clubsByStatus.map((c) => [c.status, c._count])),
      bookings30d,
      gmv30dMad: Number(gmv30d._sum.amountMad ?? 0),
      commission30dMad: Number(gmv30d._sum.commissionMad ?? 0),
      matchesConfirmed30d,
      openReports,
    };
  }

  // ------------------------------------------------------------------- clubs

  async listClubs(status?: ClubStatus) {
    return this.prisma.club.findMany({
      where: status ? { status } : {},
      include: {
        owner: {
          select: { id: true, email: true, phone: true, profile: { select: { firstName: true, lastName: true } } },
        },
        _count: { select: { courts: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async setClubStatus(adminId: string, clubId: string, status: ClubStatus) {
    const club = await this.prisma.club.findUnique({ where: { id: clubId } });
    if (!club) throw new NotFoundException('Club introuvable');
    const updated = await this.prisma.club.update({
      where: { id: clubId },
      data: { status },
    });
    await this.audit(adminId, `CLUB_${status}`, 'club', clubId, {
      previous: club.status,
    });
    return updated;
  }

  // ------------------------------------------------------------ utilisateurs

  async listUsers(query?: string, page = 1, limit = 50) {
    const where: Prisma.UserWhereInput = query
      ? {
          OR: [
            { email: { contains: query, mode: Prisma.QueryMode.insensitive } },
            { phone: { contains: query } },
            {
              profile: {
                OR: [
                  { firstName: { contains: query, mode: Prisma.QueryMode.insensitive } },
                  { lastName: { contains: query, mode: Prisma.QueryMode.insensitive } },
                ],
              },
            },
          ],
        }
      : {};
    const [items, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        select: {
          id: true,
          email: true,
          phone: true,
          roles: true,
          status: true,
          createdAt: true,
          lastLoginAt: true,
          profile: { select: { firstName: true, lastName: true, level: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.user.count({ where }),
    ]);
    return { page, limit, total, items };
  }

  async setUserStatus(adminId: string, userId: string, status: UserStatus) {
    if (status === UserStatus.DELETED) {
      throw new BadRequestException(
        'La suppression passe par le compte lui-même (DELETE /users/me)',
      );
    }
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('Utilisateur introuvable');
    if (user.roles.includes(Role.ADMIN)) {
      throw new BadRequestException('Impossible de modifier le statut d’un admin');
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { status },
    });
    if (status !== UserStatus.ACTIVE) {
      // Sessions invalidées pour un compte suspendu/banni
      await this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    await this.audit(adminId, `USER_${status}`, 'user', userId, {
      previous: user.status,
    });
    return { id: updated.id, status: updated.status };
  }

  // ------------------------------------------------------------- modération

  async listReports(status?: ReportStatus) {
    return this.prisma.report.findMany({
      where: { status: status ?? ReportStatus.OPEN },
      include: {
        reporter: {
          select: { id: true, profile: { select: { firstName: true, lastName: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async handleReport(adminId: string, reportId: string, resolve: boolean) {
    const report = await this.prisma.report.findUnique({ where: { id: reportId } });
    if (!report) throw new NotFoundException('Signalement introuvable');
    if (report.status !== ReportStatus.OPEN) {
      throw new BadRequestException('Signalement déjà traité');
    }
    const updated = await this.prisma.report.update({
      where: { id: reportId },
      data: {
        status: resolve ? ReportStatus.RESOLVED : ReportStatus.DISMISSED,
        handledById: adminId,
      },
    });
    await this.audit(
      adminId,
      resolve ? 'REPORT_RESOLVED' : 'REPORT_DISMISSED',
      'report',
      reportId,
    );
    return updated;
  }

  async auditLog(page = 1, limit = 50) {
    return this.prisma.adminAuditLog.findMany({
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
    });
  }
}
