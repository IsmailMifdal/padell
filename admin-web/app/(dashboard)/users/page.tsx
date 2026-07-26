'use client';

import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import {
  UsersThree,
  DownloadSimple,
  CaretLeft,
  CaretRight,
  ArrowsDownUp,
} from '@phosphor-icons/react';
import { ApiError, api } from '@/lib/api';
import {
  Drawer,
  Empty,
  ErrorState,
  Field,
  PageHeader,
  StatusBadge,
  TableSkeleton,
  downloadCsv,
  useToast,
} from '@/components/ui';

const PAGE_SIZE = 25;

type SortKey = 'name' | 'createdAt' | 'level' | 'status';

export default function UsersPage() {
  const [query, setQuery] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [users, setUsers] = useState<any[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState<string | null>(null);
  const [sort, setSort] = useState<{ key: SortKey; dir: 'asc' | 'desc' }>({
    key: 'createdAt',
    dir: 'desc',
  });
  const [selected, setSelected] = useState<any | null>(null);
  const toast = useToast();

  const load = useCallback(() => {
    setLoading(true);
    setError('');
    api
      .listUsers(search || undefined, page, PAGE_SIZE)
      .then((r) => {
        setUsers(r.items);
        setTotal(r.total);
      })
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Erreur'))
      .finally(() => setLoading(false));
  }, [search, page]);

  useEffect(load, [load]);

  function onSearch(e: FormEvent) {
    e.preventDefault();
    setPage(1); // une nouvelle recherche repart de la première page
    setSearch(query.trim());
  }

  function toggleSort(key: SortKey) {
    setSort((s) => (s.key === key ? { key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key, dir: 'asc' }));
  }

  // Tri appliqué à la page courante (l'API pagine, le tri affine l'affichage)
  const rows = useMemo(() => {
    const val = (u: any) => {
      switch (sort.key) {
        case 'name':
          return u.profile ? `${u.profile.firstName} ${u.profile.lastName}`.toLowerCase() : '';
        case 'level':
          return u.profile?.level ?? 0;
        case 'status':
          return u.status ?? '';
        default:
          return u.createdAt ?? '';
      }
    };
    return [...users].sort((a, b) => {
      const va = val(a);
      const vb = val(b);
      if (va === vb) return 0;
      return (va < vb ? -1 : 1) * (sort.dir === 'asc' ? 1 : -1);
    });
  }, [users, sort]);

  async function act(id: string, fn: (id: string) => Promise<unknown>, successLabel: string) {
    setBusy(id);
    try {
      await fn(id);
      toast(successLabel);
      setSelected(null);
      load();
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Action impossible', 'error');
    } finally {
      setBusy(null);
    }
  }

  function exportCsv() {
    downloadCsv(
      `utilisateurs-page-${page}.csv`,
      rows.map((u) => ({
        Nom: u.profile ? `${u.profile.firstName} ${u.profile.lastName}` : '',
        Email: u.email ?? '',
        Telephone: u.phone ?? '',
        Niveau: u.profile?.level ?? '',
        Roles: (u.roles ?? []).join(' '),
        Statut: u.status,
        Inscrit_le: u.createdAt ? new Date(u.createdAt).toLocaleDateString('fr-FR') : '',
      })),
    );
    toast(`${rows.length} ligne(s) exportée(s)`);
  }

  const lastPage = Math.max(Math.ceil(total / PAGE_SIZE), 1);

  return (
    <>
      <PageHeader
        title="Utilisateurs"
        subtitle={`${total} compte${total > 1 ? 's' : ''}`}
        actions={
          <button className="btn btn-sm" onClick={exportCsv} disabled={rows.length === 0}>
            <DownloadSimple size={14} />
            Exporter CSV
          </button>
        }
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
              setPage(1);
            }}
          >
            Réinitialiser
          </button>
        )}
      </form>

      {error && <ErrorState message={error} />}
      {loading ? (
        <TableSkeleton rows={6} cols={6} />
      ) : rows.length === 0 ? (
        <Empty icon={UsersThree} label="Aucun utilisateur trouvé." />
      ) : (
        <>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <Th label="Nom" k="name" sort={sort} onSort={toggleSort} />
                  <th>Contact</th>
                  <Th label="Niveau" k="level" sort={sort} onSort={toggleSort} />
                  <th>Rôles</th>
                  <Th label="Statut" k="status" sort={sort} onSort={toggleSort} />
                  <Th label="Inscrit" k="createdAt" sort={sort} onSort={toggleSort} />
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((u) => (
                  <tr key={u.id} style={{ cursor: 'pointer' }} onClick={() => setSelected(u)}>
                    <td style={{ fontWeight: 600 }}>
                      {u.profile ? `${u.profile.firstName} ${u.profile.lastName}` : '—'}
                    </td>
                    <td>
                      <div>{u.email ?? '—'}</div>
                      <div style={{ color: 'var(--text-muted)', fontSize: 12 }}>{u.phone ?? ''}</div>
                    </td>
                    <td style={{ fontVariantNumeric: 'tabular-nums' }}>{u.profile?.level ?? '—'}</td>
                    <td>
                      <span className="mono">{(u.roles ?? []).join(', ')}</span>
                    </td>
                    <td>
                      <StatusBadge status={u.status} />
                    </td>
                    <td style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {u.createdAt ? new Date(u.createdAt).toLocaleDateString('fr-FR') : '—'}
                    </td>
                    <td onClick={(e) => e.stopPropagation()}>
                      <div className="btn-row" style={{ justifyContent: 'flex-end' }}>
                        {u.roles?.includes('ADMIN') ? (
                          <span style={{ color: 'var(--text-muted)', fontSize: 12 }}>protégé</span>
                        ) : u.status === 'ACTIVE' ? (
                          <>
                            <button
                              className="btn btn-sm"
                              disabled={busy === u.id}
                              onClick={() => act(u.id, api.suspendUser, 'Compte suspendu')}
                            >
                              Suspendre
                            </button>
                            <button
                              className="btn btn-danger btn-sm"
                              disabled={busy === u.id}
                              onClick={() => act(u.id, api.banUser, 'Compte banni')}
                            >
                              Bannir
                            </button>
                          </>
                        ) : (
                          <button
                            className="btn btn-primary btn-sm"
                            disabled={busy === u.id}
                            onClick={() => act(u.id, api.reactivateUser, 'Compte réactivé')}
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

          <div className="toolbar" style={{ marginTop: 16, justifyContent: 'flex-end' }}>
            <span style={{ color: 'var(--text-muted)', fontSize: 12, marginRight: 'auto' }}>
              {(page - 1) * PAGE_SIZE + 1}–{Math.min(page * PAGE_SIZE, total)} sur {total}
            </span>
            <button className="btn btn-sm" disabled={page === 1} onClick={() => setPage((p) => p - 1)}>
              <CaretLeft size={13} />
              Précédent
            </button>
            <span style={{ alignSelf: 'center', fontSize: 12, color: 'var(--text-muted)' }}>
              Page {page} / {lastPage}
            </span>
            <button className="btn btn-sm" disabled={page >= lastPage} onClick={() => setPage((p) => p + 1)}>
              Suivant
              <CaretRight size={13} />
            </button>
          </div>
        </>
      )}

      {selected && (
        <Drawer
          title={
            selected.profile
              ? `${selected.profile.firstName} ${selected.profile.lastName}`
              : 'Utilisateur'
          }
          onClose={() => setSelected(null)}
        >
          <Field label="Statut" value={<StatusBadge status={selected.status} />} />
          <Field label="Email" value={selected.email} />
          <Field label="Téléphone" value={selected.phone} />
          <Field label="Niveau" value={selected.profile?.level ?? '—'} />
          <Field label="Rôles" value={<span className="mono">{(selected.roles ?? []).join(', ')}</span>} />
          <Field
            label="Inscrit le"
            value={selected.createdAt ? new Date(selected.createdAt).toLocaleString('fr-FR') : '—'}
          />
          <Field
            label="Dernière connexion"
            value={selected.lastLoginAt ? new Date(selected.lastLoginAt).toLocaleString('fr-FR') : 'Jamais'}
          />
          <Field label="Identifiant" value={<span className="mono">{selected.id}</span>} />

          {!selected.roles?.includes('ADMIN') && (
            <div className="btn-row" style={{ marginTop: 18 }}>
              {selected.status === 'ACTIVE' ? (
                <>
                  <button
                    className="btn btn-sm"
                    disabled={busy === selected.id}
                    onClick={() => act(selected.id, api.suspendUser, 'Compte suspendu')}
                  >
                    Suspendre
                  </button>
                  <button
                    className="btn btn-danger btn-sm"
                    disabled={busy === selected.id}
                    onClick={() => act(selected.id, api.banUser, 'Compte banni')}
                  >
                    Bannir
                  </button>
                </>
              ) : (
                <button
                  className="btn btn-primary btn-sm"
                  disabled={busy === selected.id}
                  onClick={() => act(selected.id, api.reactivateUser, 'Compte réactivé')}
                >
                  Réactiver
                </button>
              )}
            </div>
          )}
        </Drawer>
      )}
    </>
  );
}

function Th({
  label,
  k,
  sort,
  onSort,
}: {
  label: string;
  k: SortKey;
  sort: { key: SortKey; dir: 'asc' | 'desc' };
  onSort: (k: SortKey) => void;
}) {
  const active = sort.key === k;
  return (
    <th
      className="sortable"
      onClick={() => onSort(k)}
      aria-sort={active ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none'}
      style={active ? { color: 'var(--text)' } : undefined}
    >
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
        {label}
        <ArrowsDownUp size={11} opacity={active ? 1 : 0.4} />
      </span>
    </th>
  );
}
