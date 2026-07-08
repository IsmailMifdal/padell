'use client';

import { useCallback, useEffect, useState } from 'react';
import { ApiError, api } from '@/lib/api';
import { Empty, ErrorState, Loading, PageHeader } from '@/components/ui';

export default function AuditPage() {
  const [page, setPage] = useState(1);
  const [logs, setLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(() => {
    setLoading(true);
    setError('');
    api
      .auditLog(page)
      .then(setLogs)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Erreur'))
      .finally(() => setLoading(false));
  }, [page]);

  useEffect(load, [load]);

  return (
    <>
      <PageHeader
        title="Journal d'audit"
        subtitle="Traçabilité des actions d'administration"
      />

      {error && <ErrorState message={error} />}
      {loading ? (
        <Loading />
      ) : logs.length === 0 ? (
        <Empty label="Aucune entrée." />
      ) : (
        <>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Action</th>
                  <th>Cible</th>
                  <th>Détails</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((l) => (
                  <tr key={l.id}>
                    <td style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {new Date(l.createdAt).toLocaleString('fr-FR')}
                    </td>
                    <td>
                      <span className="badge badge-blue">{l.action}</span>
                    </td>
                    <td>
                      {l.targetType}
                      <div className="mono">{l.targetId.slice(0, 8)}…</div>
                    </td>
                    <td className="mono" style={{ color: 'var(--text-muted)' }}>
                      {l.payload ? JSON.stringify(l.payload) : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="toolbar" style={{ marginTop: 16, justifyContent: 'flex-end' }}>
            <button
              className="btn btn-sm"
              disabled={page === 1}
              onClick={() => setPage((p) => Math.max(1, p - 1))}
            >
              ← Précédent
            </button>
            <span style={{ alignSelf: 'center', color: 'var(--text-muted)' }}>
              Page {page}
            </span>
            <button
              className="btn btn-sm"
              disabled={logs.length < 50}
              onClick={() => setPage((p) => p + 1)}
            >
              Suivant →
            </button>
          </div>
        </>
      )}
    </>
  );
}
