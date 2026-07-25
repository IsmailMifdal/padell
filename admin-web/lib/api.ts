// Client API du dashboard admin. Le token JWT (rôle ADMIN) est conservé
// côté navigateur ; toutes les requêtes /admin/* passent par ce wrapper.

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/v1';

const TOKEN_KEY = 'padel_admin_token';
const USER_KEY = 'padel_admin_user';

export interface AdminUser {
  id: string;
  email: string | null;
  firstName: string;
  lastName: string;
  roles: string[];
}

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function getUser(): AdminUser | null {
  if (typeof window === 'undefined') return null;
  const raw = localStorage.getItem(USER_KEY);
  return raw ? (JSON.parse(raw) as AdminUser) : null;
}

export function setSession(token: string, user: AdminUser): void {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function clearSession(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

async function request<T>(
  method: string,
  path: string,
  body?: unknown,
): Promise<T> {
  const token = getToken();
  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (res.status === 401) {
    clearSession();
    if (typeof window !== 'undefined') window.location.href = '/login';
    throw new ApiError(401, 'Session expirée');
  }

  const text = await res.text();
  const data = text ? JSON.parse(text) : null;

  if (!res.ok) {
    const msg =
      (data && (data.message || data.error)) || `Erreur ${res.status}`;
    throw new ApiError(res.status, Array.isArray(msg) ? msg.join(', ') : msg);
  }
  return data as T;
}

// ---------------------------------------------------------------- auth

export async function login(identifier: string, password: string) {
  const data = await request<{ accessToken: string; user: AdminUser }>(
    'POST',
    '/auth/login',
    { identifier, password },
  );
  if (!data.user.roles.includes('ADMIN') && !data.user.roles.includes('OWNER')) {
    throw new ApiError(
      403,
      "Ce compte n'a pas accès à cet espace (administrateur ou propriétaire de club)",
    );
  }
  setSession(data.accessToken, data.user);
  return data;
}

export function isAdmin(user: AdminUser | null): boolean {
  return !!user?.roles.includes('ADMIN');
}

export function isOwner(user: AdminUser | null): boolean {
  return !!user?.roles.includes('OWNER');
}

/** Espace de destination après connexion selon les rôles du compte. */
export function landingFor(user: AdminUser): '/' | '/owner' {
  return isAdmin(user) ? '/' : '/owner';
}

// ---------------------------------------------------------------- admin

export interface Kpis {
  users: { total: number; new30d: number };
  clubs: Record<string, number>;
  bookings30d: number;
  gmv30dMad: number;
  commission30dMad: number;
  matchesConfirmed30d: number;
  openReports: number;
}

export const api = {
  kpis: () => request<Kpis>('GET', '/admin/kpis'),

  listClubs: (status?: string) =>
    request<any[]>('GET', `/admin/clubs${status ? `?status=${status}` : ''}`),
  approveClub: (id: string) => request('POST', `/admin/clubs/${id}/approve`),
  rejectClub: (id: string) => request('POST', `/admin/clubs/${id}/reject`),
  suspendClub: (id: string) => request('POST', `/admin/clubs/${id}/suspend`),

  listUsers: (q?: string) =>
    request<{ items: any[]; total: number }>(
      'GET',
      `/admin/users${q ? `?q=${encodeURIComponent(q)}` : ''}`,
    ),
  suspendUser: (id: string) => request('POST', `/admin/users/${id}/suspend`),
  banUser: (id: string) => request('POST', `/admin/users/${id}/ban`),
  reactivateUser: (id: string) =>
    request('POST', `/admin/users/${id}/reactivate`),

  listReports: (status?: string) =>
    request<any[]>(
      'GET',
      `/admin/reports${status ? `?status=${status}` : ''}`,
    ),
  resolveReport: (id: string) => request('POST', `/admin/reports/${id}/resolve`),
  dismissReport: (id: string) => request('POST', `/admin/reports/${id}/dismiss`),

  auditLog: (page = 1) => request<any[]>('GET', `/admin/audit-log?page=${page}`),
};

// ------------------------------------------------------------------ owner

export const ownerApi = {
  myClubs: () => request<any[]>('GET', '/clubs/mine'),

  updateClub: (clubId: string, body: Record<string, unknown>) =>
    request('PATCH', `/clubs/${clubId}`, body),

  addCourt: (clubId: string, body: { name: string; type?: string }) =>
    request('POST', `/clubs/${clubId}/courts`, body),
  updateCourt: (
    clubId: string,
    courtId: string,
    body: { name?: string; type?: string; active?: boolean },
  ) => request('PATCH', `/clubs/${clubId}/courts/${courtId}`, body),

  setOpeningHours: (
    clubId: string,
    hours: { dayOfWeek: number; openMin: number; closeMin: number }[],
  ) => request('PUT', `/clubs/${clubId}/opening-hours`, { hours }),

  addPricingRule: (
    clubId: string,
    courtId: string,
    body: {
      dayOfWeek: number;
      startMin: number;
      endMin: number;
      durationMin: number;
      priceMad: number;
    },
  ) => request('POST', `/clubs/${clubId}/courts/${courtId}/pricing`, body),
  deletePricingRule: (clubId: string, ruleId: string) =>
    request('DELETE', `/clubs/${clubId}/pricing/${ruleId}`),

  calendar: (clubId: string, from: string, to: string) =>
    request<any[]>('GET', `/owner/clubs/${clubId}/calendar?from=${from}&to=${to}`),

  manualBooking: (
    clubId: string,
    body: {
      courtId: string;
      startsAt: string;
      durationMin: number;
      priceMad?: number;
      customerName?: string;
    },
  ) => request('POST', `/owner/clubs/${clubId}/bookings/manual`, body),

  blockSlot: (
    clubId: string,
    body: { courtId: string; startsAt: string; durationMin: number; reason?: string },
  ) => request('POST', `/owner/clubs/${clubId}/bookings/block`, body),

  cancelBooking: (clubId: string, bookingId: string, reason?: string) =>
    request('POST', `/owner/clubs/${clubId}/bookings/${bookingId}/cancel`, { reason }),

  checkin: (clubId: string, qrCode: string) =>
    request<any>('POST', `/owner/clubs/${clubId}/checkin`, { qrCode }),

  stats: (clubId: string, days = 30) =>
    request<any>('GET', `/owner/clubs/${clubId}/stats?days=${days}`),
};
