'use client';

import { useEffect, useState } from 'react';
import { ApiError, api, Kpis } from '@/lib/api';
import { ErrorState, Loading, PageHeader } from '@/components/ui';

function money(n: number) {
  return new Intl.NumberFormat('fr-MA').format(n) + ' MAD';
}

export default function DashboardPage() {
  const [kpis, setKpis] = useState<Kpis | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api
      .kpis()
      .then(setKpis)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Erreur'))
      .finally(() => setLoading(false));
  }, []);

  return (
    <>
      <PageHeader
        title="Tableau de bord"
        subtitle="Indicateurs des 30 derniers jours"
      />

      {loading && <Loading />}
      {error && <ErrorState message={error} />}

      {kpis && (
        <>
          <div className="kpi-grid">
            <Kpi
              label="Utilisateurs"
              value={kpis.users.total}
              sub={`+${kpis.users.new30d} sur 30 j`}
            />
            <Kpi
              label="Réservations (30 j)"
              value={kpis.bookings30d}
            />
            <Kpi label="Volume d'affaires (30 j)" value={money(kpis.gmv30dMad)} />
            <Kpi
              label="Commission (30 j)"
              value={money(kpis.commission30dMad)}
            />
            <Kpi
              label="Matchs confirmés (30 j)"
              value={kpis.matchesConfirmed30d}
            />
            <Kpi
              label="Signalements ouverts"
              value={kpis.openReports}
              alert={kpis.openReports > 0}
            />
          </div>

          <div className="card card-pad">
            <div className="kpi-label" style={{ marginBottom: 12 }}>
              Clubs par statut
            </div>
            <div className="kpi-grid" style={{ marginBottom: 0 }}>
              {['PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED'].map((s) => (
                <Kpi key={s} label={s} value={kpis.clubs[s] ?? 0} />
              ))}
            </div>
          </div>
        </>
      )}
    </>
  );
}

function Kpi({
  label,
  value,
  sub,
  alert,
}: {
  label: string;
  value: number | string;
  sub?: string;
  alert?: boolean;
}) {
  return (
    <div className="kpi">
      <div className="kpi-label">{label}</div>
      <div
        className="kpi-value"
        style={alert ? { color: 'var(--danger)' } : undefined}
      >
        {value}
      </div>
      {sub && <div className="kpi-sub">{sub}</div>}
    </div>
  );
}
