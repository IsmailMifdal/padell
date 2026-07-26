'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  MagnifyingGlass,
  Bell,
  Sun,
  Moon,
  SidebarSimple,
  Racquet,
  UsersThree,
  Flag,
  ChartBar,
  Scroll,
} from '@phosphor-icons/react';
import { AdminUser, api, isAdmin } from '@/lib/api';

const THEME_KEY = 'padel_admin_theme';

// --------------------------------------------------------------- thème

export function useTheme() {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');

  useEffect(() => {
    // Le script inline de layout.tsx a déjà posé l'attribut : on le lit
    // plutôt que de recalculer, pour rester synchronisé.
    const current = document.documentElement.dataset.theme;
    setTheme(current === 'dark' ? 'dark' : 'light');
  }, []);

  const toggle = useCallback(() => {
    setTheme((prev) => {
      const next = prev === 'dark' ? 'light' : 'dark';
      document.documentElement.dataset.theme = next;
      try {
        localStorage.setItem(THEME_KEY, next);
      } catch {
        // stockage indisponible (navigation privée) : le thème reste
        // appliqué pour la session en cours, simplement non mémorisé
      }
      return next;
    });
  }, []);

  return { theme, toggle };
}

export function ThemeToggle() {
  const { theme, toggle } = useTheme();
  return (
    <button
      className="icon-btn"
      onClick={toggle}
      title={theme === 'dark' ? 'Passer en clair' : 'Passer en sombre'}
      aria-label={theme === 'dark' ? 'Passer en mode clair' : 'Passer en mode sombre'}
    >
      {theme === 'dark' ? <Sun size={17} /> : <Moon size={17} />}
    </button>
  );
}

// ------------------------------------------------------------- topbar

export function Topbar({
  user,
  onToggleSidebar,
  onOpenSearch,
  alerts = 0,
}: {
  user: AdminUser | null;
  onToggleSidebar: () => void;
  onOpenSearch: () => void;
  alerts?: number;
}) {
  return (
    <div className="topbar">
      <button className="icon-btn" onClick={onToggleSidebar} aria-label="Replier le menu">
        <SidebarSimple size={18} />
      </button>

      <button className="search-trigger" onClick={onOpenSearch}>
        <MagnifyingGlass size={15} />
        <span style={{ flex: 1, textAlign: 'left' }}>Rechercher un club, un utilisateur…</span>
        <kbd>Ctrl K</kbd>
      </button>

      <div style={{ flex: 1 }} />

      <div style={{ position: 'relative' }}>
        <button className="icon-btn" aria-label={`${alerts} élément(s) à traiter`} title="À traiter">
          <Bell size={17} />
        </button>
        {alerts > 0 && <span className="dot-badge" />}
      </div>

      <ThemeToggle />

      <div className="avatar" title={user?.email ?? ''}>
        {user?.firstName?.[0]?.toUpperCase() ?? '?'}
      </div>
    </div>
  );
}

// ------------------------------------------------ palette de commandes ⌘K

interface Hit {
  id: string;
  label: string;
  sub: string;
  href: string;
  kind: 'Utilisateur' | 'Club' | 'Navigation';
}

const NAV_HITS: Hit[] = [
  { id: 'n1', label: 'Tableau de bord', sub: 'Vue d’ensemble', href: '/', kind: 'Navigation' },
  { id: 'n2', label: 'Clubs', sub: 'Validation des clubs', href: '/clubs', kind: 'Navigation' },
  { id: 'n3', label: 'Utilisateurs', sub: 'Comptes', href: '/users', kind: 'Navigation' },
  { id: 'n4', label: 'Signalements', sub: 'Modération', href: '/reports', kind: 'Navigation' },
  { id: 'n5', label: "Journal d'audit", sub: 'Traçabilité', href: '/audit', kind: 'Navigation' },
];

export function CommandPalette({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter();
  const [query, setQuery] = useState('');
  const [hits, setHits] = useState<Hit[]>([]);
  const [cursor, setCursor] = useState(0);
  const [loading, setLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (open) {
      setQuery('');
      setHits([]);
      setCursor(0);
      // Laisse le panneau se monter avant de donner le focus
      requestAnimationFrame(() => inputRef.current?.focus());
    }
  }, [open]);

  // Recherche distante débouncée : navigation filtrée localement,
  // utilisateurs et clubs interrogés côté API.
  useEffect(() => {
    if (!open) return;
    const q = query.trim();
    const navHits = NAV_HITS.filter((n) => n.label.toLowerCase().includes(q.toLowerCase()));
    if (q.length < 2) {
      setHits(navHits);
      setCursor(0);
      return;
    }
    setLoading(true);
    const timer = setTimeout(async () => {
      try {
        const [users, clubs] = await Promise.all([
          api.listUsers(q).catch(() => ({ items: [] as any[], total: 0 })),
          api.listClubs().catch(() => [] as any[]),
        ]);
        const userHits: Hit[] = (users.items ?? []).slice(0, 5).map((u: any) => ({
          id: `u-${u.id}`,
          label: u.profile ? `${u.profile.firstName} ${u.profile.lastName}` : (u.email ?? 'Compte'),
          sub: u.email ?? u.phone ?? '',
          href: `/users?q=${encodeURIComponent(q)}`,
          kind: 'Utilisateur' as const,
        }));
        const clubHits: Hit[] = (clubs as any[])
          .filter((c) => c.name?.toLowerCase().includes(q.toLowerCase()))
          .slice(0, 5)
          .map((c) => ({
            id: `c-${c.id}`,
            label: c.name,
            sub: `${c.city} · ${c.status}`,
            href: '/clubs',
            kind: 'Club' as const,
          }));
        setHits([...navHits, ...userHits, ...clubHits]);
        setCursor(0);
      } finally {
        setLoading(false);
      }
    }, 250);
    return () => clearTimeout(timer);
  }, [query, open]);

  const go = useCallback(
    (hit: Hit) => {
      onClose();
      router.push(hit.href);
    },
    [onClose, router],
  );

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setCursor((c) => Math.min(c + 1, hits.length - 1));
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        setCursor((c) => Math.max(c - 1, 0));
      }
      if (e.key === 'Enter' && hits[cursor]) {
        e.preventDefault();
        go(hits[cursor]);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, hits, cursor, onClose, go]);

  if (!open) return null;

  let lastKind = '';
  return (
    <div className="cmdk-overlay" onClick={onClose}>
      <div className="cmdk-panel" onClick={(e) => e.stopPropagation()}>
        <input
          ref={inputRef}
          className="cmdk-input"
          placeholder="Rechercher un club, un utilisateur, une page…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <div className="cmdk-list">
          {loading && <div className="cmdk-section">Recherche…</div>}
          {!loading && hits.length === 0 && <div className="cmdk-section">Aucun résultat</div>}
          {hits.map((h, i) => {
            const header = h.kind !== lastKind ? h.kind : null;
            lastKind = h.kind;
            return (
              <div key={h.id}>
                {header && <div className="cmdk-section">{header}</div>}
                <button
                  className="cmdk-item"
                  aria-selected={i === cursor}
                  onMouseEnter={() => setCursor(i)}
                  onClick={() => go(h)}
                >
                  <HitIcon kind={h.kind} />
                  <span style={{ flex: 1 }}>
                    <span style={{ fontWeight: 600 }}>{h.label}</span>
                    {h.sub && (
                      <span style={{ color: 'var(--text-muted)', marginLeft: 8, fontSize: 12 }}>{h.sub}</span>
                    )}
                  </span>
                </button>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function HitIcon({ kind }: { kind: Hit['kind'] }) {
  if (kind === 'Club') return <Racquet size={16} />;
  if (kind === 'Utilisateur') return <UsersThree size={16} />;
  return <ChartBar size={16} />;
}

/** Raccourci global ⌘K / Ctrl+K. */
export function useCommandPalette() {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setOpen((v) => !v);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);
  return { open, setOpen };
}

export const NAV_ICONS = { ChartBar, Racquet, UsersThree, Flag, Scroll, isAdmin };
