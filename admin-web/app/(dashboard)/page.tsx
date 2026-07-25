'use client';

import { useEffect, useState } from 'react';
import {
  Users,
  CalendarCheck,
  Wallet,
  HandCoins,
  Trophy,
  Flag,
  Icon,
} from '@phosphor-icons/react';
import { ApiError, api, Kpis } from '@/lib/api';
import { ErrorState, KpiSkeleton, PageHeader } from '@/components/ui';

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

      {loading && <KpiSkeleton count={6} />}
      {error && <ErrorState message={error} />}

      {kpis && (
        <>
          <div className="kpi-grid">
            <Kpi
              icon={Users}
              label="Utilisateurs"
              value={kpis.users.total}
              sub={`+${kpis.users.new30d} sur 30 j`}
            />
            <Kpi
              icon={CalendarCheck}
              label="Réservations (30 j)"
              value={kpis.bookings30d}
            />
            <Kpi icon={Wallet} label="Volume d'affaires (30 j)" value={money(kpis.gmv30dMad)} />
            <Kpi
              icon={HandCoins}
              label="Commission (30 j)"
              value={money(kpis.commission30dMad)}
            />
            <Kpi
              icon={Trophy}
              label="Matchs confirmés (30 j)"
              value={kpis.matchesConfirmed30d}
            />
            <Kpi
              icon={Flag}
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
  icon: IconCmp,
  label,
  value,
  sub,
  alert,
}: {
  icon?: Icon;
  label: string;
  value: number | string;
  sub?: string;
  alert?: boolean;
}) {
  return (
    <div className="kpi">
      {IconCmp && (
        <div
          className="kpi-icon"
          style={alert ? { background: 'var(--danger-soft)', color: 'var(--danger)' } : undefined}
        >
          <IconCmp size={17} weight="bold" />
        </div>
      )}
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
