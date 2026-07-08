'use client';

import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Link from 'next/link';
import { AdminUser, clearSession, getToken, getUser } from '@/lib/api';

const NAV = [
  { href: '/', label: 'Tableau de bord', icon: '📊' },
  { href: '/clubs', label: 'Clubs', icon: '🏟️' },
  { href: '/users', label: 'Utilisateurs', icon: '👥' },
  { href: '/reports', label: 'Signalements', icon: '🚩' },
  { href: '/audit', label: "Journal d'audit", icon: '📜' },
];

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<AdminUser | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    setUser(getUser());
    setReady(true);
  }, [router]);

  function logout() {
    clearSession();
    router.replace('/login');
  }

  if (!ready) return null;

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">🎾 Padel Admin</div>
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
            >
              <span className="icon">{item.icon}</span>
              {item.label}
            </Link>
          );
        })}
        <div className="sidebar-footer">
          <div style={{ padding: '4px 10px', fontSize: 12 }}>
            <div style={{ fontWeight: 600 }}>
              {user ? `${user.firstName} ${user.lastName}` : ''}
            </div>
            <div style={{ color: 'var(--text-muted)' }}>{user?.email}</div>
          </div>
          <button
            className="btn btn-sm"
            style={{ width: '100%', marginTop: 8, justifyContent: 'center' }}
            onClick={logout}
          >
            Déconnexion
          </button>
        </div>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
