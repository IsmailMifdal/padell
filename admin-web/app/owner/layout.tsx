'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { Racquet, SignOut } from '@phosphor-icons/react';
import { AdminUser, clearSession, getToken, getUser, isOwner } from '@/lib/api';

export default function OwnerLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const [user, setUser] = useState<AdminUser | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!getToken()) {
      router.replace('/login');
      return;
    }
    const u = getUser();
    if (!isOwner(u)) {
      router.replace('/login');
      return;
    }
    setUser(u);
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
        <Link href="/owner" className="brand">
          🎾 Espace propriétaire
        </Link>
        <Link href="/owner" className="nav-link active">
          <Racquet size={18} weight="fill" />
          Mes clubs
        </Link>
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
            <SignOut size={14} />
            Déconnexion
          </button>
        </div>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
