'use client';

import { useCallback, useEffect, useState } from 'react';
import { ApiError, api } from '@/lib/api';
import { Empty, ErrorState, Loading, PageHeader, StatusBadge } from '@/components/ui';

const FILTERS = [
  { key: 'OPEN', label: 'Ouverts' },
  { key: 'RESOLVED', label: 'Résolus' },
  { key: 'DISMISSED', label: 'Rejetés' },
];

export default function ReportsPage() {
  const [filter, setFilter] = useState('OPEN');
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(() => {
    setLoading(true);
    setError('');
    api
      .listReports(filter)
      .then(setReports)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Erreur'))
      .finally(() => setLoading(false));
  }, [filter]);

  useEffect(load, [load]);

  async function act(id: string, fn: (id: string) => Promise<unknown>) {
    setBusy(id);
    try {
      await fn(id);
      load();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Action impossible');
    } finally {
      setBusy(null);
    }
  }

  return (
    <>
      <PageHeader
        title="Signalements"
        subtitle="Modération des utilisateurs et clubs signalés"
      />

      <div className="toolbar">
        <div className="tabs">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              className={`tab ${filter === f.key ? 'active' : ''}`}
              onClick={() => setFilter(f.key)}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {error && <ErrorState message={error} />}
      {loading ? (
        <Loading />
      ) : reports.length === 0 ? (
        <Empty label="Aucun signalement." />
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Cible</th>
                <th>Motif</th>
                <th>Signalé par</th>
                <th>Date</th>
                <th>Statut</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {reports.map((r) => (
                <tr key={r.id}>
                  <td>
                    <span className={`badge badge-blue`}>{r.targetType}</span>
                    <div className="mono" style={{ marginTop: 4 }}>
                      {r.targetId.slice(0, 8)}…
                    </div>
                  </td>
                  <td style={{ maxWidth: 340 }}>{r.reason}</td>
                  <td>
                    {r.reporter?.profile
                      ? `${r.reporter.profile.firstName} ${r.reporter.profile.lastName}`
                      : '—'}
                  </td>
                  <td style={{ color: 'var(--text-muted)' }}>
                    {new Date(r.createdAt).toLocaleDateString('fr-FR')}
                  </td>
                  <td>
                    <StatusBadge status={r.status} />
                  </td>
                  <td>
                    <div className="btn-row" style={{ justifyContent: 'flex-end' }}>
                      {r.status === 'OPEN' && (
                        <>
                          <button
                            className="btn btn-primary btn-sm"
                            disabled={busy === r.id}
                            onClick={() => act(r.id, api.resolveReport)}
                          >
                            Résoudre
                          </button>
                          <button
                            className="btn btn-sm"
                            disabled={busy === r.id}
                            onClick={() => act(r.id, api.dismissReport)}
                          >
                            Rejeter
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
