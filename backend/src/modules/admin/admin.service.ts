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

  // ---------------------------------------------------------------- overview

  /**
   * Vue d'ensemble du tableau de bord : KPI comparés à la période précédente,
   * série journalière, top clubs, activité récente et file d'actions à traiter.
   * Un seul aller-retour réseau pour toute la page d'accueil.
   */
  async overview(days = 30) {
    const now = new Date();
    const dayMs = 24 * 3600 * 1000;
    const start = new Date(now.getTime() - days * dayMs);
    // Période immédiatement précédente, de même longueur (base des deltas)
    const prevStart = new Date(start.getTime() - days * dayMs);

    const [
      payments,
      prevPayments,
      bookings,
      prevBookings,
      signups,
      prevSignups,
      matches,
      prevMatches,
      totalUsers,
      clubsByStatus,
      pendingClubs,
      openReports,
      recentClubs,
      recentUsers,
    ] = await this.prisma.$transaction([
      this.prisma.payment.findMany({
        where: { status: PaymentStatus.PAID, createdAt: { gte: start } },
        select: { amountMad: true, commissionMad: true, createdAt: true },
      }),
      this.prisma.payment.aggregate({
        where: {
          status: PaymentStatus.PAID,
          createdAt: { gte: prevStart, lt: start },
        },
        _sum: { amountMad: true, commissionMad: true },
      }),
      this.prisma.booking.findMany({
        where: {
          createdAt: { gte: start },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
        },
        select: {
          createdAt: true,
          priceMad: true,
          court: { select: { club: { select: { id: true, name: true, city: true } } } },
        },
      }),
      this.prisma.booking.count({
        where: {
          createdAt: { gte: prevStart, lt: start },
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
        },
      }),
      this.prisma.user.findMany({
        where: { createdAt: { gte: start } },
        select: { createdAt: true },
      }),
      this.prisma.user.count({ where: { createdAt: { gte: prevStart, lt: start } } }),
      this.prisma.match.count({
        where: { status: MatchStatus.CONFIRMED, createdAt: { gte: start } },
      }),
      this.prisma.match.count({
        where: {
          status: MatchStatus.CONFIRMED,
          createdAt: { gte: prevStart, lt: start },
        },
      }),
      this.prisma.user.count({ where: { status: { not: UserStatus.DELETED } } }),
      this.prisma.club.groupBy({ by: ['status'], _count: true, orderBy: { status: 'asc' } }),
      this.prisma.club.findMany({
        where: { status: ClubStatus.PENDING },
        select: {
          id: true,
          name: true,
          city: true,
          createdAt: true,
          owner: { select: { email: true, phone: true } },
        },
        orderBy: { createdAt: 'asc' },
        take: 5,
      }),
      this.prisma.report.findMany({
        where: { status: ReportStatus.OPEN },
        select: { id: true, reason: true, targetType: true, createdAt: true },
        orderBy: { createdAt: 'asc' },
        take: 5,
      }),
      this.prisma.club.findMany({
        select: { id: true, name: true, city: true, createdAt: true },
        orderBy: { createdAt: 'desc' },
        take: 6,
      }),
      this.prisma.user.findMany({
        select: {
          id: true,
          createdAt: true,
          profile: { select: { firstName: true, lastName: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: 6,
      }),
    ]);

    // ---- Série journalière (un point par jour, trous remplis à zéro) -------
    const key = (d: Date) => d.toISOString().slice(0, 10);
    const buckets = new Map<string, { revenueMad: number; bookings: number; signups: number }>();
    for (let i = days - 1; i >= 0; i--) {
      buckets.set(key(new Date(now.getTime() - i * dayMs)), {
        revenueMad: 0,
        bookings: 0,
        signups: 0,
      });
    }
    for (const p of payments) {
      const b = buckets.get(key(p.createdAt));
      if (b) b.revenueMad += Number(p.amountMad);
    }
    for (const b of bookings) {
      const slot = buckets.get(key(b.createdAt));
      if (slot) slot.bookings += 1;
    }
    for (const u of signups) {
      const slot = buckets.get(key(u.createdAt));
      if (slot) slot.signups += 1;
    }
    const series = [...buckets.entries()].map(([date, v]) => ({
      date,
      revenueMad: Math.round(v.revenueMad * 100) / 100,
      bookings: v.bookings,
      signups: v.signups,
    }));

    // ---- Top clubs sur la période (chiffre d'affaires des réservations) ----
    const byClub = new Map<
      string,
      { id: string; name: string; city: string; revenueMad: number; bookings: number }
    >();
    for (const b of bookings) {
      const club = b.court?.club;
      if (!club) continue;
      const entry = byClub.get(club.id) ?? {
        id: club.id,
        name: club.name,
        city: club.city,
        revenueMad: 0,
        bookings: 0,
      };
      entry.revenueMad += Number(b.priceMad);
      entry.bookings += 1;
      byClub.set(club.id, entry);
    }
    const topClubs = [...byClub.values()]
      .map((c) => ({ ...c, revenueMad: Math.round(c.revenueMad * 100) / 100 }))
      .sort((a, b) => b.revenueMad - a.revenueMad)
      .slice(0, 5);

    // ---- Activité récente (flux fusionné, le plus récent d'abord) ----------
    const activity = [
      ...recentUsers.map((u) => ({
        type: 'USER' as const,
        at: u.createdAt,
        label: u.profile ? `${u.profile.firstName} ${u.profile.lastName}` : 'Nouveau compte',
        sub: 'Inscription',
      })),
      ...recentClubs.map((c) => ({
        type: 'CLUB' as const,
        at: c.createdAt,
        label: c.name,
        sub: `Club ajouté · ${c.city}`,
      })),
    ]
      .sort((a, b) => b.at.getTime() - a.at.getTime())
      .slice(0, 8);

    const revenue = payments.reduce((s, p) => s + Number(p.amountMad), 0);
    const commission = payments.reduce((s, p) => s + Number(p.commissionMad), 0);
    const round2 = (n: number) => Math.round(n * 100) / 100;
    /** Variation en % vs période précédente ; null si pas de base de comparaison. */
    const delta = (current: number, previous: number): number | null =>
      previous === 0 ? null : Math.round(((current - previous) / previous) * 1000) / 10;

    const prevRevenue = Number(prevPayments._sum.amountMad ?? 0);
    const prevCommission = Number(prevPayments._sum.commissionMad ?? 0);

    return {
      days,
      kpis: {
        revenueMad: {
          value: round2(revenue),
          previous: round2(prevRevenue),
          deltaPct: delta(revenue, prevRevenue),
        },
        commissionMad: {
          value: round2(commission),
          previous: round2(prevCommission),
          deltaPct: delta(commission, prevCommission),
        },
        bookings: {
          value: bookings.length,
          previous: prevBookings,
          deltaPct: delta(bookings.length, prevBookings),
        },
        signups: {
          value: signups.length,
          previous: prevSignups,
          deltaPct: delta(signups.length, prevSignups),
        },
        matches: {
          value: matches,
          previous: prevMatches,
          deltaPct: delta(matches, prevMatches),
        },
      },
      totals: {
        users: totalUsers,
        clubs: Object.fromEntries(clubsByStatus.map((c) => [c.status, c._count])),
      },
      series,
      topClubs,
      activity,
      queue: { pendingClubs, openReports },
    };
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
