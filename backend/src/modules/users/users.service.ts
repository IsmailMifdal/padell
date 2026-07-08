import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { UserStatus } from '@prisma/client';
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
