import { SetMetadata } from '@nestjs/common';
import { Role } from '@prisma/client';

export const ROLES_KEY = 'roles';
/** Restreint un endpoint aux rôles donnés, ex: @Roles(Role.ADMIN). */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
