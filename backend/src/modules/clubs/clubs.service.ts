import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Club, ClubStatus, Prisma, Role } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { CreateClubDto, UpdateClubDto } from './dto/create-club.dto';
import { CreateCourtDto, UpdateCourtDto } from './dto/court.dto';
import { SetOpeningHoursDto } from './dto/opening-hours.dto';
import { CreatePricingRuleDto } from './dto/pricing-rule.dto';
import { SearchClubsQuery } from './dto/search-clubs.query';

const DEFAULT_RADIUS_KM = 15;
const DEFAULT_PAGE_SIZE = 20;

@Injectable()
export class ClubsService {
  constructor(private readonly prisma: PrismaService) {}

  // ------------------------------------------------------------- côté public

  async search(query: SearchClubsQuery) {
    const page = query.page ?? 1;
    const limit = query.limit ?? DEFAULT_PAGE_SIZE;
    const offset = (page - 1) * limit;

    // Recherche par rayon : SQL brut PostGIS (index GIST fonctionnel)
    if (query.lat !== undefined && query.lng !== undefined) {
      const radiusM = (query.radiusKm ?? DEFAULT_RADIUS_KM) * 1000;
      const rows = await this.prisma.$queryRaw<
        Array<Record<string, unknown> & { distance_m: number }>
      >`
        SELECT c.id, c.name, c.description, c.address, c.city, c.phone,
               c.latitude, c.longitude, c.amenities, c.rating_avg,
               c.payment_on_site_allowed,
               ST_Distance(
                 ST_SetSRID(ST_MakePoint(c.longitude::float8, c.latitude::float8), 4326)::geography,
                 ST_SetSRID(ST_MakePoint(${query.lng}::float8, ${query.lat}::float8), 4326)::geography
               ) AS distance_m
        FROM clubs c
        WHERE c.status = 'APPROVED'
          AND ST_DWithin(
                ST_SetSRID(ST_MakePoint(c.longitude::float8, c.latitude::float8), 4326)::geography,
                ST_SetSRID(ST_MakePoint(${query.lng}::float8, ${query.lat}::float8), 4326)::geography,
                ${radiusM}
              )
        ORDER BY distance_m ASC
        LIMIT ${limit} OFFSET ${offset}
      `;
      return {
        page,
        limit,
        items: rows.map((r) => ({ ...r, distance_m: Math.round(r.distance_m) })),
      };
    }

    // Recherche simple par ville / liste
    const where: Prisma.ClubWhereInput = {
      status: ClubStatus.APPROVED,
      ...(query.city
        ? { city: { equals: query.city, mode: Prisma.QueryMode.insensitive } }
        : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.club.findMany({
        where,
        select: {
          id: true,
          name: true,
          description: true,
          address: true,
          city: true,
          phone: true,
          latitude: true,
          longitude: true,
          amenities: true,
          ratingAvg: true,
          paymentOnSiteAllowed: true,
        },
        orderBy: { ratingAvg: { sort: 'desc', nulls: 'last' } },
        skip: offset,
        take: limit,
      }),
      this.prisma.club.count({ where }),
    ]);
    return { page, limit, total, items };
  }

  async findOnePublic(id: string) {
    const club = await this.prisma.club.findUnique({
      where: { id },
      include: {
        courts: {
          where: { active: true },
          include: { pricingRules: true },
        },
        openingHours: { orderBy: { dayOfWeek: 'asc' } },
      },
    });
    if (!club || club.status !== ClubStatus.APPROVED) {
      throw new NotFoundException('Club introuvable');
    }
    const { commissionRate, ...publicClub } = club;
    return publicClub;
  }

  // ------------------------------------------------------- côté propriétaire

  async create(user: AuthUser, dto: CreateClubDto) {
    const club = await this.prisma.$transaction(async (tx) => {
      const created = await tx.club.create({
        data: {
          ownerId: user.userId,
          name: dto.name,
          description: dto.description ?? null,
          address: dto.address,
          city: dto.city,
          phone: dto.phone ?? null,
          latitude: dto.latitude,
          longitude: dto.longitude,
          amenities: dto.amenities ?? [],
          cancellationPolicy:
            (dto.cancellationPolicy as Prisma.InputJsonValue) ?? Prisma.JsonNull,
          paymentOnSiteAllowed: dto.paymentOnSiteAllowed ?? true,
        },
      });
      // Le créateur devient OWNER (le club reste PENDING jusqu'à validation admin)
      if (!user.roles.includes(Role.OWNER)) {
        await tx.user.update({
          where: { id: user.userId },
          data: { roles: { push: Role.OWNER } },
        });
      }
      return created;
    });
    return club;
  }

  async findMine(user: AuthUser) {
    return this.prisma.club.findMany({
      where: { ownerId: user.userId },
      include: {
        courts: { include: { pricingRules: true } },
        openingHours: { orderBy: { dayOfWeek: 'asc' } },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async update(user: AuthUser, clubId: string, dto: UpdateClubDto) {
    await this.assertOwnership(user, clubId);
    const { cancellationPolicy, amenities, ...rest } = dto;
    return this.prisma.club.update({
      where: { id: clubId },
      data: {
        ...rest,
        ...(amenities !== undefined ? { amenities } : {}),
        ...(cancellationPolicy !== undefined
          ? { cancellationPolicy: cancellationPolicy as Prisma.InputJsonValue }
          : {}),
      },
    });
  }

  // ------------------------------------------------------------------ courts

  async addCourt(user: AuthUser, clubId: string, dto: CreateCourtDto) {
    await this.assertOwnership(user, clubId);
    return this.prisma.court.create({
      data: {
        clubId,
        name: dto.name,
        type: dto.type,
        photos: dto.photos ?? [],
      },
    });
  }

  async updateCourt(user: AuthUser, clubId: string, courtId: string, dto: UpdateCourtDto) {
    await this.assertOwnership(user, clubId);
    const court = await this.prisma.court.findFirst({ where: { id: courtId, clubId } });
    if (!court) throw new NotFoundException('Terrain introuvable');
    const { photos, ...rest } = dto;
    return this.prisma.court.update({
      where: { id: courtId },
      data: { ...rest, ...(photos !== undefined ? { photos } : {}) },
    });
  }

  // -------------------------------------------------------- horaires & tarifs

  async setOpeningHours(user: AuthUser, clubId: string, dto: SetOpeningHoursDto) {
    await this.assertOwnership(user, clubId);
    for (const h of dto.hours) {
      if (h.closeMin <= h.openMin) {
        throw new BadRequestException(
          `Jour ${h.dayOfWeek} : l'heure de fermeture doit être après l'ouverture`,
        );
      }
    }
    const days = dto.hours.map((h) => h.dayOfWeek);
    if (new Set(days).size !== days.length) {
      throw new BadRequestException('Un seul horaire par jour de semaine');
    }

    await this.prisma.$transaction([
      this.prisma.openingHour.deleteMany({ where: { clubId } }),
      this.prisma.openingHour.createMany({
        data: dto.hours.map((h) => ({ clubId, ...h })),
      }),
    ]);
    return this.prisma.openingHour.findMany({
      where: { clubId },
      orderBy: { dayOfWeek: 'asc' },
    });
  }

  async addPricingRule(
    user: AuthUser,
    clubId: string,
    courtId: string,
    dto: CreatePricingRuleDto,
  ) {
    await this.assertOwnership(user, clubId);
    const court = await this.prisma.court.findFirst({ where: { id: courtId, clubId } });
    if (!court) throw new NotFoundException('Terrain introuvable');
    if (dto.endMin <= dto.startMin) {
      throw new BadRequestException("L'heure de fin doit être après le début");
    }

    // Refus des règles qui se chevauchent pour le même terrain/jour
    const overlap = await this.prisma.pricingRule.findFirst({
      where: {
        courtId,
        dayOfWeek: dto.dayOfWeek,
        startMin: { lt: dto.endMin },
        endMin: { gt: dto.startMin },
      },
    });
    if (overlap) {
      throw new BadRequestException(
        'Une règle tarifaire existe déjà sur cette plage horaire',
      );
    }

    return this.prisma.pricingRule.create({ data: { courtId, ...dto } });
  }

  async deletePricingRule(user: AuthUser, clubId: string, ruleId: string) {
    await this.assertOwnership(user, clubId);
    const rule = await this.prisma.pricingRule.findFirst({
      where: { id: ruleId, court: { clubId } },
    });
    if (!rule) throw new NotFoundException('Règle tarifaire introuvable');
    await this.prisma.pricingRule.delete({ where: { id: ruleId } });
  }

  // ----------------------------------------------------------------- interne

  /** Vérifie que l'utilisateur est propriétaire du club (ou admin). */
  async assertOwnership(user: AuthUser, clubId: string): Promise<Club> {
    const club = await this.prisma.club.findUnique({ where: { id: clubId } });
    if (!club) throw new NotFoundException('Club introuvable');
    if (club.ownerId !== user.userId && !user.roles.includes(Role.ADMIN)) {
      throw new ForbiddenException("Vous n'êtes pas propriétaire de ce club");
    }
    return club;
  }
}
