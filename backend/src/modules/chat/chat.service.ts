import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { MatchPlayerStatus } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  /** Seuls les participants acceptés (et le créateur) accèdent au chat. */
  async assertParticipant(userId: string, matchId: string): Promise<void> {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      select: { creatorId: true },
    });
    if (!match) throw new NotFoundException('Match introuvable');
    if (match.creatorId === userId) return;

    const membership = await this.prisma.matchPlayer.findUnique({
      where: { matchId_playerId: { matchId, playerId: userId } },
    });
    if (!membership || membership.status !== MatchPlayerStatus.ACCEPTED) {
      throw new ForbiddenException("Vous ne participez pas à ce match");
    }
  }

  async history(userId: string, matchId: string) {
    await this.assertParticipant(userId, matchId);
    return this.prisma.chatMessage.findMany({
      where: { matchId },
      include: {
        sender: {
          select: {
            id: true,
            profile: { select: { firstName: true, lastName: true, avatarUrl: true } },
          },
        },
      },
      orderBy: { sentAt: 'asc' },
      take: 200,
    });
  }

  async saveMessage(userId: string, matchId: string, body: string) {
    await this.assertParticipant(userId, matchId);
    return this.prisma.chatMessage.create({
      data: { matchId, senderId: userId, body },
      include: {
        sender: {
          select: {
            id: true,
            profile: { select: { firstName: true, lastName: true, avatarUrl: true } },
          },
        },
      },
    });
  }
}
