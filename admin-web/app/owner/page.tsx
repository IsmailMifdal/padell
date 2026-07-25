'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { CaretRight, Racquet } from '@phosphor-icons/react';
import { ApiError, ownerApi } from '@/lib/api';
import { Empty, ErrorState, PageHeader, StatusBadge } from '@/components/ui';

export default function OwnerOverviewPage() {
  const router = useRouter();
  const [clubs, setClubs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    ownerApi
      .myClubs()
      .then(setClubs)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Erreur'))
      .finally(() => setLoading(false));
  }, []);

  return (
    <>
      <PageHeader
        title="Mes clubs"
        subtitle="Gérez vos terrains, réservations, horaires et tarifs"
      />

      {error && <ErrorState message={error} />}
      {loading ? (
        <div style={{ display: 'grid', gap: 12 }}>
          {Array.from({ length: 2 }).map((_, i) => (
            <div className="card card-pad" key={i} style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
              <div className="skeleton-block" style={{ height: 44, width: 44, borderRadius: 12 }} />
              <div style={{ flex: 1 }}>
                <div className="skeleton-block" style={{ height: 14, width: '40%', marginBottom: 8 }} />
                <div className="skeleton-block" style={{ height: 12, width: '25%' }} />
              </div>
            </div>
          ))}
        </div>
      ) : clubs.length === 0 ? (
        <Empty icon={Racquet} label="Aucun club — ajoutez votre club depuis l'application mobile." />
      ) : (
        <div style={{ display: 'grid', gap: 12 }}>
          {clubs.map((c) => (
            <div
              key={c.id}
              className="card card-pad card-hover"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 14,
                cursor: 'pointer',
              }}
              onClick={() => router.push(`/owner/clubs/${c.id}`)}
            >
              <div
                style={{
                  height: 44,
                  width: 44,
                  borderRadius: 12,
                  background: 'var(--accent-soft)',
                  color: 'var(--accent-hover)',
                  display: 'grid',
                  placeItems: 'center',
                  flex: '0 0 auto',
                }}
              >
                <Racquet size={22} weight="fill" />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700 }}>{c.name}</div>
                <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>
                  {c.city} · {c.courts?.length ?? 0} terrain(s)
                </div>
              </div>
              <StatusBadge status={c.status} />
              <CaretRight size={16} color="var(--text-muted)" />
            </div>
          ))}
        </div>
      )}
    </>
  );
}
