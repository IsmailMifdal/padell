'use client';

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import {
  CalendarCheck,
  Wallet,
  Trophy,
  UserPlus,
  Racquet,
  Flag,
  Clock,
  CaretRight,
} from '@phosphor-icons/react';
import { ApiError, Overview, api } from '@/lib/api';
import { ErrorState, KpiSkeleton, PageHeader, useToast } from '@/components/ui';
import { Delta, LineChart, Sparkline, StatTile } from '@/components/viz';

const PERIODS = [
  { days: 7, label: '7 jours' },
  { days: 30, label: '30 jours' },
  { days: 90, label: '90 jours' },
];

/** Mesures traçables — jamais deux échelles sur un même graphique : on bascule. */
const MEASURES = [
  { key: 'revenueMad' as const, label: 'Revenus', unit: 'MAD' },
  { key: 'bookings' as const, label: 'Réservations', unit: '' },
  { key: 'signups' as const, label: 'Inscriptions', unit: '' },
];

const money = (n: number) => `${new Intl.NumberFormat('fr-MA').format(Math.round(n))} MAD`;
const num = (n: number) => new Intl.NumberFormat('fr-MA').format(n);

export default function DashboardPage() {
  const [days, setDays] = useState(30);
  const [measure, setMeasure] = useState<(typeof MEASURES)[number]['key']>('revenueMad');
  const [data, setData] = useState<Overview | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [refetching, setRefetching] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const toast = useToast();

  const load = useCallback(
    (opts?: { silent?: boolean }) => {
      // Au changement de période on garde le rendu précédent en retrait :
      // pas de squelette qui clignote, pas de saut de mise en page.
      if (opts?.silent) setRefetching(true);
      else setLoading(true);
      setError('');
      api
        .overview(days)
        .then(setData)
        .catch((e) => setError(e instanceof ApiError ? e.message : 'Erreur'))
        .finally(() => {
          setLoading(false);
          setRefetching(false);
        });
    },
    [days],
  );

  useEffect(() => {
    load({ silent: !!data });
    // `data` volontairement hors dépendances : sinon chaque chargement
    // relancerait le suivant en boucle.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [days]);

  async function actOnClub(id: string, fn: (id: string) => Promise<unknown>, label: string) {
    setBusy(id);
    try {
      await fn(id);
      toast(label);
      load({ silent: true });
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Action impossible', 'error');
    } finally {
      setBusy(null);
    }
  }

  const measureMeta = MEASURES.find((m) => m.key === measure)!;
  const points = (data?.series ?? []).map((s) => ({ date: s.date, value: s[measure] }));
  const pendingCount = data?.queue.pendingClubs.length ?? 0;
  const reportCount = data?.queue.openReports.length ?? 0;

  return (
    <>
      <PageHeader
        title="Tableau de bord"
        subtitle="Vue d'ensemble de la plateforme"
      />

      {/* Une seule barre de filtres, au-dessus de tout ce qu'elle cadre */}
      <div className="toolbar">
        <div className="tabs">
          {PERIODS.map((p) => (
            <button
              key={p.days}
              className={`tab ${days === p.days ? 'active' : ''}`}
              onClick={() => setDays(p.days)}
            >
              {p.label}
            </button>
          ))}
        </div>
        {refetching && <span style={{ color: 'var(--text-muted)', fontSize: 12 }}>Mise à jour…</span>}
      </div>

      {error && <ErrorState message={error} />}
      {loading && !data && <KpiSkeleton count={4} />}

      {data && (
        <div className={`bento ${refetching ? 'is-refetching' : ''}`}>
          {/* Nombre-héros : un seul par vue */}
          <div className="kpi span-1">
            <div className="kpi-label">Revenus · {days} j</div>
            <div className="hero-figure" style={{ marginTop: 8 }}>
              {new Intl.NumberFormat('fr-MA', { notation: 'compact' }).format(data.kpis.revenueMad.value)}
            </div>
            <div style={{ color: 'var(--text-muted)', fontSize: 12, marginBottom: 8 }}>MAD encaissés</div>
            <Delta pct={data.kpis.revenueMad.deltaPct} suffix="" />
            <div style={{ marginTop: 10 }}>
              <Sparkline data={data.series.map((s) => s.revenueMad)} width={140} height={30} />
            </div>
          </div>

          {/* Le graphique : la carte large du bento */}
          <div className="viz-card span-3">
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                gap: 12,
                flexWrap: 'wrap',
                marginBottom: 4,
              }}
            >
              <div>
                <div style={{ fontWeight: 700, fontSize: 15 }}>{measureMeta.label}</div>
                <div style={{ color: 'var(--text-muted)', fontSize: 12 }}>
                  Évolution jour par jour sur {days} jours
                </div>
              </div>
              <div className="tabs">
                {MEASURES.map((m) => (
                  <button
                    key={m.key}
                    className={`tab ${measure === m.key ? 'active' : ''}`}
                    onClick={() => setMeasure(m.key)}
                  >
                    {m.label}
                  </button>
                ))}
              </div>
            </div>
            <LineChart points={points} unit={measureMeta.unit} height={250} />
          </div>

          {/* Rangée de tuiles */}
          <StatTile
            label="Réservations"
            value={num(data.kpis.bookings.value)}
            deltaPct={data.kpis.bookings.deltaPct}
            trend={data.series.map((s) => s.bookings)}
          />
          <StatTile
            label="Inscriptions"
            value={num(data.kpis.signups.value)}
            deltaPct={data.kpis.signups.deltaPct}
            trend={data.series.map((s) => s.signups)}
          />
          <StatTile
            label="Matchs confirmés"
            value={num(data.kpis.matches.value)}
            deltaPct={data.kpis.matches.deltaPct}
          />
          <StatTile
            label="Commission"
            value={money(data.kpis.commissionMad.value)}
            deltaPct={data.kpis.commissionMad.deltaPct}
          />

          {/* File d'actions : traitable sans quitter l'accueil */}
          <div className="card card-pad span-2">
            <div className="section-title">
              <Flag size={16} weight="fill" color="var(--warning)" />
              À traiter
              {pendingCount + reportCount > 0 && (
                <span className="badge badge-amber">{pendingCount + reportCount}</span>
              )}
            </div>

            {pendingCount === 0 && reportCount === 0 && (
              <div style={{ color: 'var(--text-muted)', fontSize: 13, padding: '12px 0' }}>
                Rien en attente — tout est à jour.
              </div>
            )}

            {data.queue.pendingClubs.map((c) => (
              <div className="queue-item" key={c.id}>
                <div className="feed-dot">
                  <Racquet size={14} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {c.name}
                  </div>
                  <div style={{ color: 'var(--text-muted)', fontSize: 12 }}>
                    {c.city} · club en attente
                  </div>
                </div>
                <div className="btn-row">
                  <button
                    className="btn btn-primary btn-sm"
                    disabled={busy === c.id}
                    onClick={() => actOnClub(c.id, api.approveClub, 'Club approuvé')}
                  >
                    Approuver
                  </button>
                  <button
                    className="btn btn-danger btn-sm"
                    disabled={busy === c.id}
                    onClick={() => actOnClub(c.id, api.rejectClub, 'Club rejeté')}
                  >
                    Rejeter
                  </button>
                </div>
              </div>
            ))}

            {data.queue.openReports.map((r) => (
              <div className="queue-item" key={r.id}>
                <div className="feed-dot">
                  <Flag size={14} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {r.reason}
                  </div>
                  <div style={{ color: 'var(--text-muted)', fontSize: 12 }}>
                    Signalement · {r.targetType}
                  </div>
                </div>
                <Link href="/reports" className="btn btn-sm">
                  Traiter
                </Link>
              </div>
            ))}
          </div>

          {/* Top clubs */}
          <div className="card card-pad span-2">
            <div className="section-title">
              <Trophy size={16} weight="fill" color="var(--accent)" />
              Top clubs · {days} j
            </div>
            {data.topClubs.length === 0 ? (
              <div style={{ color: 'var(--text-muted)', fontSize: 13, padding: '12px 0' }}>
                Aucune réservation sur la période.
              </div>
            ) : (
              data.topClubs.map((c, i) => {
                const max = data.topClubs[0].revenueMad || 1;
                return (
                  <div key={c.id} style={{ padding: '9px 0' }}>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
                      <span style={{ color: 'var(--text-muted)', fontSize: 12, width: 14 }}>{i + 1}</span>
                      <span style={{ fontWeight: 600, flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {c.name}
                      </span>
                      <span style={{ fontSize: 13, fontVariantNumeric: 'tabular-nums' }}>{money(c.revenueMad)}</span>
                    </div>
                    {/* Piste de jauge : pas de bordure, la couleur porte la magnitude */}
                    <div style={{ height: 6, background: 'var(--surface-2)', borderRadius: 999, marginTop: 6, marginLeft: 22 }}>
                      <div
                        style={{
                          height: '100%',
                          width: `${Math.max((c.revenueMad / max) * 100, 2)}%`,
                          background: 'var(--viz-series)',
                          borderRadius: 999,
                        }}
                      />
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Activité récente */}
          <div className="card card-pad span-4">
            <div className="section-title">
              <Clock size={16} weight="fill" color="var(--text-muted)" />
              Activité récente
            </div>
            {data.activity.length === 0 ? (
              <div style={{ color: 'var(--text-muted)', fontSize: 13, padding: '12px 0' }}>
                Aucune activité récente.
              </div>
            ) : (
              data.activity.map((a, i) => (
                <div className="feed-item" key={`${a.type}-${i}`}>
                  <div className="feed-dot">
                    {a.type === 'USER' ? <UserPlus size={14} /> : <Racquet size={14} />}
                  </div>
                  <span style={{ fontWeight: 600 }}>{a.label}</span>
                  <span style={{ color: 'var(--text-muted)' }}>{a.sub}</span>
                  <span style={{ marginLeft: 'auto', color: 'var(--text-muted)', fontSize: 12 }}>
                    {new Date(a.at).toLocaleDateString('fr-FR', {
                      day: 'numeric',
                      month: 'short',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </span>
                </div>
              ))
            )}
          </div>

          {/* Répartition des clubs */}
          <div className="card card-pad span-4">
            <div className="section-title">
              <CalendarCheck size={16} weight="fill" color="var(--text-muted)" />
              Clubs par statut
            </div>
            <div style={{ display: 'flex', gap: 20, flexWrap: 'wrap' }}>
              {['PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED'].map((s) => (
                <Link
                  key={s}
                  href={`/clubs`}
                  style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 0' }}
                >
                  <span style={{ fontSize: 22, fontWeight: 800 }}>{data.totals.clubs[s] ?? 0}</span>
                  <span style={{ color: 'var(--text-muted)', fontSize: 12 }}>{s}</span>
                  <CaretRight size={13} color="var(--text-muted)" />
                </Link>
              ))}
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 0' }}>
                <Wallet size={16} color="var(--text-muted)" />
                <span style={{ fontSize: 22, fontWeight: 800 }}>{num(data.totals.users)}</span>
                <span style={{ color: 'var(--text-muted)', fontSize: 12 }}>comptes au total</span>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
