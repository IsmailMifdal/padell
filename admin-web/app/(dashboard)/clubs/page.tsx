'use client';

import { useCallback, useEffect, useState } from 'react';
import { ApiError, api } from '@/lib/api';
import { Racquet, DownloadSimple } from '@phosphor-icons/react';
import {
  Empty,
  ErrorState,
  PageHeader,
  StatusBadge,
  TableSkeleton,
  downloadCsv,
  useToast,
} from '@/components/ui';

const FILTERS = [
  { key: 'PENDING', label: 'En attente' },
  { key: 'APPROVED', label: 'Approuvés' },
  { key: 'REJECTED', label: 'Rejetés' },
  { key: 'SUSPENDED', label: 'Suspendus' },
  { key: '', label: 'Tous' },
];

export default function ClubsPage() {
  const [filter, setFilter] = useState('PENDING');
  const [clubs, setClubs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState<string | null>(null);
  const toast = useToast();

  const load = useCallback(() => {
    setLoading(true);
    setError('');
    api
      .listClubs(filter || undefined)
      .then(setClubs)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Erreur'))
      .finally(() => setLoading(false));
  }, [filter]);

  useEffect(load, [load]);

  async function act(
    id: string,
    fn: (id: string) => Promise<unknown>,
    successLabel: string,
  ) {
    setBusy(id);
    try {
      await fn(id);
      toast(successLabel);
      load();
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Action impossible', 'error');
    } finally {
      setBusy(null);
    }
  }

  return (
    <>
      <PageHeader
        title="Clubs"
        subtitle="Validation et gestion des clubs partenaires"
        actions={
          <button
            className="btn btn-sm"
            disabled={clubs.length === 0}
            onClick={() => {
              downloadCsv(
                `clubs-${filter || 'tous'}.csv`,
                clubs.map((c) => ({
                  Nom: c.name,
                  Ville: c.city,
                  Adresse: c.address ?? '',
                  Proprietaire: c.owner?.profile
                    ? `${c.owner.profile.firstName} ${c.owner.profile.lastName}`
                    : '',
                  Contact: c.owner?.email ?? c.owner?.phone ?? '',
                  Terrains: c._count?.courts ?? 0,
                  Statut: c.status,
                })),
              );
              toast(`${clubs.length} ligne(s) exportée(s)`);
            }}
          >
            <DownloadSimple size={14} />
            Exporter CSV
          </button>
        }
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
        <TableSkeleton rows={4} cols={6} />
      ) : clubs.length === 0 ? (
        <Empty icon={Racquet} label="Aucun club dans cette catégorie." />
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Club</th>
                <th>Ville</th>
                <th>Propriétaire</th>
                <th>Terrains</th>
                <th>Statut</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {clubs.map((c) => (
                <tr key={c.id}>
                  <td>
                    <div style={{ fontWeight: 600 }}>{c.name}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 12 }}>
                      {c.address}
                    </div>
                  </td>
                  <td>{c.city}</td>
                  <td>
                    {c.owner?.profile
                      ? `${c.owner.profile.firstName} ${c.owner.profile.lastName}`
                      : '—'}
                    <div style={{ color: 'var(--text-muted)', fontSize: 12 }}>
                      {c.owner?.email ?? c.owner?.phone}
                    </div>
                  </td>
                  <td>{c._count?.courts ?? 0}</td>
                  <td>
                    <StatusBadge status={c.status} />
                  </td>
                  <td>
                    <div className="btn-row" style={{ justifyContent: 'flex-end' }}>
                      {c.status !== 'APPROVED' && (
                        <button
                          className="btn btn-primary btn-sm"
                          disabled={busy === c.id}
                          onClick={() => act(c.id, api.approveClub, 'Club approuvé')}
                        >
                          Approuver
                        </button>
                      )}
                      {c.status === 'PENDING' && (
                        <button
                          className="btn btn-danger btn-sm"
                          disabled={busy === c.id}
                          onClick={() => act(c.id, api.rejectClub, 'Club rejeté')}
                        >
                          Rejeter
                        </button>
                      )}
                      {c.status === 'APPROVED' && (
                        <button
                          className="btn btn-danger btn-sm"
                          disabled={busy === c.id}
                          onClick={() => act(c.id, api.suspendClub, 'Club suspendu')}
                        >
                          Suspendre
                        </button>
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
