'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import { ApiError, api } from '@/lib/api';
import { Empty, ErrorState, Loading, PageHeader, StatusBadge } from '@/components/ui';

export default function UsersPage() {
  const [query, setQuery] = useState('');
  const [search, setSearch] = useState('');
  const [users, setUsers] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(() => {
    setLoading(true);
    setError('');
    api
      .listUsers(search || undefined)
      .then((r) => {
        setUsers(r.items);
        setTotal(r.total);
      })
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Erreur'))
      .finally(() => setLoading(false));
  }, [search]);

  useEffect(load, [load]);

  function onSearch(e: FormEvent) {
    e.preventDefault();
    setSearch(query.trim());
  }

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
        title="Utilisateurs"
        subtitle={`${total} compte${total > 1 ? 's' : ''}`}
      />

      <form className="toolbar" onSubmit={onSearch}>
        <input
          className="input"
          style={{ maxWidth: 320 }}
          placeholder="Rechercher (nom, email, téléphone)…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <button className="btn btn-primary">Rechercher</button>
        {search && (
          <button
            type="button"
            className="btn"
            onClick={() => {
              setQuery('');
              setSearch('');
            }}
          >
            Réinitialiser
          </button>
        )}
      </form>

      {error && <ErrorState message={error} />}
      {loading ? (
        <Loading />
      ) : users.length === 0 ? (
        <Empty label="Aucun utilisateur trouvé." />
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Nom</th>
                <th>Contact</th>
                <th>Niveau</th>
                <th>Rôles</th>
                <th>Statut</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id}>
                  <td style={{ fontWeight: 600 }}>
                    {u.profile
                      ? `${u.profile.firstName} ${u.profile.lastName}`
                      : '—'}
                  </td>
                  <td>
                    <div>{u.email ?? '—'}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 12 }}>
                      {u.phone ?? ''}
                    </div>
                  </td>
                  <td>{u.profile?.level ?? '—'}</td>
                  <td>
                    <span className="mono">{(u.roles ?? []).join(', ')}</span>
                  </td>
                  <td>
                    <StatusBadge status={u.status} />
                  </td>
                  <td>
                    <div className="btn-row" style={{ justifyContent: 'flex-end' }}>
                      {u.roles?.includes('ADMIN') ? (
                        <span style={{ color: 'var(--text-muted)', fontSize: 12 }}>
                          protégé
                        </span>
                      ) : u.status === 'ACTIVE' ? (
                        <>
                          <button
                            className="btn btn-sm"
                            disabled={busy === u.id}
                            onClick={() => act(u.id, api.suspendUser)}
                          >
                            Suspendre
                          </button>
                          <button
                            className="btn btn-danger btn-sm"
                            disabled={busy === u.id}
                            onClick={() => act(u.id, api.banUser)}
                          >
                            Bannir
                          </button>
                        </>
                      ) : (
                        <button
                          className="btn btn-primary btn-sm"
                          disabled={busy === u.id}
                          onClick={() => act(u.id, api.reactivateUser)}
                        >
                          Réactiver
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
