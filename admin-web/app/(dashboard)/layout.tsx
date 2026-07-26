'use client';

import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Link from 'next/link';
import {
  ChartBar,
  Racquet,
  Users,
  Flag,
  Scroll,
  SignOut,
} from '@phosphor-icons/react';
import { AdminUser, clearSession, getToken, getUser, isAdmin } from '@/lib/api';
import { CommandPalette, Topbar, useCommandPalette } from '@/components/shell';

const NAV = [
  { href: '/', label: 'Tableau de bord', Icon: ChartBar },
  { href: '/clubs', label: 'Clubs', Icon: Racquet },
  { href: '/users', label: 'Utilisateurs', Icon: Users },
  { href: '/reports', label: 'Signalements', Icon: Flag },
  { href: '/audit', label: "Journal d'audit", Icon: Scroll },
];

const COLLAPSE_KEY = 'padel_admin_sidebar';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<AdminUser | null>(null);
  const [ready, setReady] = useState(false);
  const [collapsed, setCollapsed] = useState(false);
  const { open, setOpen } = useCommandPalette();

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    const u = getUser();
    if (!isAdmin(u)) {
      router.replace('/owner');
      return;
    }
    setUser(u);
    try {
      setCollapsed(localStorage.getItem(COLLAPSE_KEY) === '1');
    } catch {
      // stockage indisponible : on garde le menu déplié
    }
    setReady(true);
  }, [router]);

  function toggleSidebar() {
    setCollapsed((v) => {
      const next = !v;
      try {
        localStorage.setItem(COLLAPSE_KEY, next ? '1' : '0');
      } catch {
        // préférence non mémorisée, sans conséquence sur l'affichage
      }
      return next;
    });
  }

  function logout() {
    clearSession();
    router.replace('/login');
  }

  if (!ready) return null;

  return (
    <div className={`shell ${collapsed ? 'collapsed' : ''}`}>
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">🎾</span>
          <span>Padel Admin</span>
        </div>
        {NAV.map((item) => {
          const active =
            item.href === '/'
              ? pathname === '/'
              : pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`nav-link ${active ? 'active' : ''}`}
              title={collapsed ? item.label : undefined}
            >
              <item.Icon size={18} weight={active ? 'fill' : 'regular'} />
              <span className="nav-label">{item.label}</span>
            </Link>
          );
        })}
        <div className="sidebar-footer">
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 6px' }}>
            <div className="avatar">{user?.firstName?.[0]?.toUpperCase() ?? '?'}</div>
            <div className="user-meta" style={{ minWidth: 0 }}>
              <div style={{ fontWeight: 700, fontSize: 13, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {user ? `${user.firstName} ${user.lastName}` : ''}
              </div>
              <div style={{ color: 'var(--text-muted)', fontSize: 11, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {user?.email}
              </div>
            </div>
          </div>
          <button
            className="btn btn-sm"
            style={{ width: '100%', marginTop: 8, justifyContent: 'center' }}
            onClick={logout}
            title="Déconnexion"
          >
            <SignOut size={14} />
            <span className="nav-label">Déconnexion</span>
          </button>
        </div>
      </aside>

      <div style={{ minWidth: 0 }}>
        <Topbar
          user={user}
          onToggleSidebar={toggleSidebar}
          onOpenSearch={() => setOpen(true)}
        />
        <main className="main">{children}</main>
      </div>

      <CommandPalette open={open} onClose={() => setOpen(false)} />
    </div>
  );
}
