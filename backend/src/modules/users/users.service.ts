import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  BookingStatus,
  ClubStatus,
  MatchPlayerStatus,
  MatchStatus,
  UserStatus,
} from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { SetAvailabilitiesDto } from './dto/availability.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user || user.status === UserStatus.DELETED) {
      throw new NotFoundException('Utilisateur introuvable');
    }
    const { passwordHash, failedLoginAttempts, lockedUntil, ...safe } = user;
    return safe;
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const { birthdate, ...rest } = dto;
    const profile = await this.prisma.playerProfile.update({
      where: { userId },
      data: {
        ...rest,
        ...(birthdate !== undefined ? { birthdate: new Date(birthdate) } : {}),
      },
    });
    return profile;
  }

  async getAvailabilities(userId: string) {
    return this.prisma.availability.findMany({
      where: { playerId: userId },
      orderBy: [{ dayOfWeek: 'asc' }, { startMin: 'asc' }],
    });
  }

  async setAvailabilities(userId: string, dto: SetAvailabilitiesDto) {
    for (const a of dto.availabilities) {
      if (a.endMin <= a.startMin) {
        throw new BadRequestException(
          `Jour ${a.dayOfWeek} : l'heure de fin doit être après le début`,
        );
      }
    }
    await this.prisma.$transaction([
      this.prisma.availability.deleteMany({ where: { playerId: userId } }),
      this.prisma.availability.createMany({
        data: dto.availabilities.map((a) => ({ playerId: userId, ...a })),
      }),
    ]);
    return this.getAvailabilities(userId);
  }

  // ---------------------------------------------------------------- favoris

  async listFavoriteClubs(userId: string) {
    const favorites = await this.prisma.favoriteClub.findMany({
      where: { userId, club: { status: ClubStatus.APPROVED } },
      include: {
        club: {
          select: {
            id: true,
            name: true,
            city: true,
            address: true,
            latitude: true,
            longitude: true,
            ratingAvg: true,
            paymentOnSiteAllowed: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return favorites.map((f) => f.club);
  }

  async addFavoriteClub(userId: string, clubId: string) {
    const club = await this.prisma.club.findUnique({ where: { id: clubId } });
    if (!club || club.status !== ClubStatus.APPROVED) {
      throw new NotFoundException('Club introuvable');
    }
    await this.prisma.favoriteClub.upsert({
      where: { userId_clubId: { userId, clubId } },
      create: { userId, clubId },
      update: {},
    });
    return { favorite: true };
  }

  async removeFavoriteClub(userId: string, clubId: string) {
    await this.prisma.favoriteClub.deleteMany({ where: { userId, clubId } });
    return { favorite: false };
  }

  // ------------------------------------------------------------------ stats

  /** Historique et statistiques du joueur (matchs, victoires, notes reçues). */
  async stats(userId: string) {
    const profile = await this.prisma.playerProfile.findUnique({
      where: { userId },
    });

    const playedMatches = await this.prisma.match.findMany({
      where: {
        status: MatchStatus.PLAYED,
        players: {
          some: { playerId: userId, status: MatchPlayerStatus.ACCEPTED },
        },
      },
      select: { score: true },
    });
    const wins = playedMatches.filter((m) => {
      const winners = (m.score as { winnerIds?: string[] } | null)?.winnerIds;
      return Array.isArray(winners) && winners.includes(userId);
    }).length;

    const [bookingsCount, clubs, ratings] = await this.prisma.$transaction([
      this.prisma.booking.count({
        where: {
          bookedById: userId,
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
        },
      }),
      this.prisma.booking.findMany({
        where: {
          bookedById: userId,
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.COMPLETED] },
        },
        select: { court: { select: { clubId: true } } },
        distinct: ['courtId'],
      }),
      this.prisma.rating.aggregate({
        where: { ratedId: userId },
        _avg: { punctuality: true, fairplay: true, levelAccuracy: true },
        _count: true,
      }),
    ]);
    const distinctClubs = new Set(clubs.map((b) => b.court.clubId)).size;

    return {
      level: Number(profile?.level ?? 0),
      eloRating: profile?.eloRating ?? 1000,
      matchesPlayed: playedMatches.length,
      wins,
      losses: playedMatches.length - wins,
      bookingsCount,
      clubsVisited: distinctClubs,
      ratingsReceived: ratings._count,
      avgPunctuality: ratings._avg.punctuality,
      avgFairplay: ratings._avg.fairplay,
      avgLevelAccuracy: ratings._avg.levelAccuracy,
    };
  }

  /**
   * Suppression de compte (exigence Apple/Google) : anonymisation.
   * L'historique (réservations, matchs) reste cohérent via l'id conservé.
   */
  async deleteAccount(userId: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: {
          status: UserStatus.DELETED,
          email: null,
          phone: null,
          passwordHash: null,
        },
      }),
      this.prisma.playerProfile.update({
        where: { userId },
        data: { firstName: 'Utilisateur', lastName: 'Supprimé', avatarUrl: null },
      }),
    ]);
  }
}
