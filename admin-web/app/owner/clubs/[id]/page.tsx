'use client';

import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  CalendarPlus,
  Prohibit,
  QrCode,
  ArrowLeft,
  Trash,
  CalendarX,
  Tag,
  CalendarCheck,
  Wallet,
  XCircle,
  HandCoins,
  Icon,
} from '@phosphor-icons/react';
import { ApiError, ownerApi } from '@/lib/api';
import {
  Empty,
  ErrorState,
  Loading,
  Modal,
  PageHeader,
  StatusBadge,
  TableSkeleton,
  useToast,
} from '@/components/ui';

const DAY_NAMES = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

function pad(n: number) {
  return String(n).padStart(2, '0');
}
function toDateStr(d: Date) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
function minToHHMM(min: number) {
  return `${pad(Math.floor(min / 60))}:${pad(min % 60)}`;
}
function hhmmToMin(hhmm: string) {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + (m || 0);
}
function money(n: number) {
  return new Intl.NumberFormat('fr-MA').format(n) + ' MAD';
}

export default function OwnerClubPage() {
  const params = useParams();
  const router = useRouter();
  const clubId = params.id as string;
  const toast = useToast();

  const [club, setClub] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [tab, setTab] = useState<'calendar' | 'config'>('calendar');

  const loadClub = useCallback(() => {
    setLoading(true);
    ownerApi
      .myClubs()
      .then((list) => {
        const found = list.find((c) => c.id === clubId);
        if (!found) throw new ApiError(404, 'Club introuvable');
        setClub(found);
      })
      .catch((e) => setError(e instanceof ApiError ? e.message : 'Erreur'))
      .finally(() => setLoading(false));
  }, [clubId]);

  useEffect(loadClub, [loadClub]);

  if (loading) return <Loading />;
  if (error) return <ErrorState message={error} />;
  if (!club) return null;

  return (
    <>
      <button
        className="btn btn-sm"
        style={{ marginBottom: 14 }}
        onClick={() => router.push('/owner')}
      >
        <ArrowLeft size={14} />
        Mes clubs
      </button>
      <PageHeader
        title={club.name}
        subtitle={`${club.city} · ${club.courts?.length ?? 0} terrain(s)`}
        actions={<StatusBadge status={club.status} />}
      />

      <div className="tabs" style={{ marginBottom: 20 }}>
        <button
          className={`tab ${tab === 'calendar' ? 'active' : ''}`}
          onClick={() => setTab('calendar')}
        >
          Calendrier
        </button>
        <button
          className={`tab ${tab === 'config' ? 'active' : ''}`}
          onClick={() => setTab('config')}
        >
          Configuration
        </button>
      </div>

      {tab === 'calendar' ? (
        <CalendarTab club={club} toast={toast} />
      ) : (
        <ConfigTab club={club} toast={toast} onChanged={loadClub} />
      )}
    </>
  );
}

// -------------------------------------------------------------- calendrier

function CalendarTab({ club, toast }: { club: any; toast: (m: string, k?: 'success' | 'error') => void }) {
  const [day, setDay] = useState(() => new Date());
  const [bookings, setBookings] = useState<any[]>([]);
  const [stats, setStats] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState<'manual' | 'block' | 'checkin' | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const dateStr = toDateStr(day);

  const load = useCallback(() => {
    setLoading(true);
    Promise.all([
      ownerApi.calendar(club.id, dateStr, dateStr),
      ownerApi.stats(club.id, 30),
    ])
      .then(([b, s]) => {
        setBookings(b);
        setStats(s);
      })
      .catch((e) => toast(e instanceof ApiError ? e.message : 'Erreur', 'error'))
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [club.id, dateStr]);

  useEffect(load, [load]);

  const days = useMemo(() => {
    const list: Date[] = [];
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    for (let i = 0; i < 10; i++) {
      const d = new Date(today);
      d.setDate(today.getDate() + i);
      list.push(d);
    }
    return list;
  }, []);

  async function cancel(bookingId: string) {
    if (!confirm('Annuler cette réservation ?')) return;
    setBusy(bookingId);
    try {
      await ownerApi.cancelBooking(club.id, bookingId);
      toast('Réservation annulée');
      load();
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Action impossible', 'error');
    } finally {
      setBusy(null);
    }
  }

  return (
    <>
      {stats && (
        <div className="kpi-grid">
          <Kpi icon={CalendarCheck} label="Réservations (30 j)" value={stats.totalBookings} />
          <Kpi icon={Wallet} label="Revenus (30 j)" value={money(stats.revenueMad)} />
          <Kpi icon={XCircle} label="Annulations (30 j)" value={stats.cancelledBookings} />
          <Kpi icon={HandCoins} label="Résas manuelles" value={`${stats.manualShare} %`} />
        </div>
      )}

      <div className="toolbar" style={{ justifyContent: 'space-between' }}>
        <div style={{ fontWeight: 700 }}>
          {day.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}
        </div>
        <div className="btn-row">
          <button className="btn btn-sm" onClick={() => setModal('manual')}>
            <CalendarPlus size={14} />
            Réservation manuelle
          </button>
          <button className="btn btn-sm" onClick={() => setModal('block')}>
            <Prohibit size={14} />
            Bloquer un créneau
          </button>
          <button className="btn btn-sm" onClick={() => setModal('checkin')}>
            <QrCode size={14} />
            Check-in
          </button>
        </div>
      </div>

      <div className="day-strip">
        {days.map((d) => {
          const active = toDateStr(d) === dateStr;
          return (
            <button
              key={d.toISOString()}
              className={`day-chip ${active ? 'active' : ''}`}
              onClick={() => setDay(d)}
            >
              <div>{d.toLocaleDateString('fr-FR', { weekday: 'short' }).toUpperCase()}</div>
              <div className="d">{d.getDate()}</div>
            </button>
          );
        })}
      </div>

      {loading ? (
        <TableSkeleton rows={3} cols={4} />
      ) : bookings.length === 0 ? (
        <Empty icon={CalendarX} label="Aucune réservation ce jour." />
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Horaire</th>
                <th>Terrain</th>
                <th>Client</th>
                <th>Statut</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {bookings.map((b: any) => {
                const isBlocked = b.source === 'BLOCKED';
                const start = new Date(b.startsAt);
                const end = new Date(b.endsAt);
                const customer = b.bookedBy?.profile
                  ? `${b.bookedBy.profile.firstName} ${b.bookedBy.profile.lastName}`
                  : b.note ?? (isBlocked ? 'Indisponible' : '—');
                return (
                  <tr key={b.id}>
                    <td>
                      {pad(start.getHours())}:{pad(start.getMinutes())} – {pad(end.getHours())}:{pad(end.getMinutes())}
                    </td>
                    <td>{b.court?.name}</td>
                    <td>{customer}</td>
                    <td>
                      <StatusBadge status={isBlocked ? 'BLOCKED' : b.status} />
                    </td>
                    <td>
                      {(b.status === 'CONFIRMED' || b.status === 'PENDING_PAYMENT') && (
                        <div className="btn-row" style={{ justifyContent: 'flex-end' }}>
                          <button
                            className="btn btn-danger btn-sm"
                            disabled={busy === b.id}
                            onClick={() => cancel(b.id)}
                          >
                            Annuler
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {modal === 'manual' && (
        <SlotModal
          title="Réservation manuelle"
          club={club}
          date={dateStr}
          askPrice
          askName
          onClose={() => setModal(null)}
          onSubmit={async (v) => {
            await ownerApi.manualBooking(club.id, {
              courtId: v.courtId,
              startsAt: `${dateStr}T${v.time}:00`,
              durationMin: v.durationMin,
              priceMad: v.price,
              customerName: v.name,
            });
            toast('Réservation ajoutée');
            setModal(null);
            load();
          }}
        />
      )}
      {modal === 'block' && (
        <SlotModal
          title="Bloquer un créneau"
          club={club}
          date={dateStr}
          askReason
          onClose={() => setModal(null)}
          onSubmit={async (v) => {
            await ownerApi.blockSlot(club.id, {
              courtId: v.courtId,
              startsAt: `${dateStr}T${v.time}:00`,
              durationMin: v.durationMin,
              reason: v.name,
            });
            toast('Créneau bloqué');
            setModal(null);
            load();
          }}
        />
      )}
      {modal === 'checkin' && (
        <CheckinModal
          club={club}
          toast={toast}
          onClose={() => setModal(null)}
          onDone={load}
        />
      )}
    </>
  );
}

function Kpi({
  icon: IconCmp,
  label,
  value,
}: {
  icon?: Icon;
  label: string;
  value: number | string;
}) {
  return (
    <div className="kpi">
      {IconCmp && (
        <div className="kpi-icon">
          <IconCmp size={17} weight="bold" />
        </div>
      )}
      <div className="kpi-label">{label}</div>
      <div className="kpi-value">{value}</div>
    </div>
  );
}

function SlotModal({
  title,
  club,
  date,
  askPrice,
  askName,
  askReason,
  onClose,
  onSubmit,
}: {
  title: string;
  club: any;
  date: string;
  askPrice?: boolean;
  askName?: boolean;
  askReason?: boolean;
  onClose: () => void;
  onSubmit: (v: {
    courtId: string;
    time: string;
    durationMin: number;
    price?: number;
    name?: string;
  }) => Promise<void>;
}) {
  const [courtId, setCourtId] = useState(club.courts?.[0]?.id ?? '');
  const [time, setTime] = useState('18:00');
  const [duration, setDuration] = useState(90);
  const [price, setPrice] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      await onSubmit({
        courtId,
        time,
        durationMin: duration,
        price: price ? Number(price) : undefined,
        name: name || undefined,
      });
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Action impossible');
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal title={title} onClose={onClose}>
      <form onSubmit={submit}>
        {error && <div className="alert alert-error">{error}</div>}
        <div className="field">
          <label>Terrain</label>
          <select className="input" value={courtId} onChange={(e) => setCourtId(e.target.value)}>
            {club.courts?.map((c: any) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label>Date</label>
          <input className="input" value={date} disabled />
        </div>
        <div className="field">
          <label>Heure de début</label>
          <input
            className="input"
            type="time"
            value={time}
            onChange={(e) => setTime(e.target.value)}
          />
        </div>
        <div className="field">
          <label>Durée</label>
          <select
            className="input"
            value={duration}
            onChange={(e) => setDuration(Number(e.target.value))}
          >
            {[60, 90, 120, 180].map((d) => (
              <option key={d} value={d}>
                {d} min
              </option>
            ))}
          </select>
        </div>
        {askPrice && (
          <div className="field">
            <label>Prix (MAD, optionnel)</label>
            <input
              className="input"
              type="number"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
            />
          </div>
        )}
        {(askName || askReason) && (
          <div className="field">
            <label>{askName ? 'Nom du client (optionnel)' : 'Motif'}</label>
            <input className="input" value={name} onChange={(e) => setName(e.target.value)} />
          </div>
        )}
        <button className="btn btn-primary" style={{ width: '100%' }} disabled={saving}>
          {saving ? 'Validation…' : 'Valider'}
        </button>
      </form>
    </Modal>
  );
}

function CheckinModal({
  club,
  toast,
  onClose,
  onDone,
}: {
  club: any;
  toast: (m: string, k?: 'success' | 'error') => void;
  onClose: () => void;
  onDone: () => void;
}) {
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      const r = await ownerApi.checkin(club.id, code.trim());
      toast(`Check-in validé — ${r.court?.name ?? ''}`);
      onDone();
      onClose();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Code invalide');
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal title="Check-in client" onClose={onClose}>
      <form onSubmit={submit}>
        {error && <div className="alert alert-error">{error}</div>}
        <div className="field">
          <label>Code QR du client</label>
          <input
            className="input"
            autoFocus
            value={code}
            onChange={(e) => setCode(e.target.value)}
            placeholder="Coller ou saisir le code"
          />
        </div>
        <button className="btn btn-primary" style={{ width: '100%' }} disabled={saving || !code.trim()}>
          {saving ? 'Validation…' : 'Valider'}
        </button>
      </form>
    </Modal>
  );
}

// ------------------------------------------------------------- configuration

function ConfigTab({
  club,
  toast,
  onChanged,
}: {
  club: any;
  toast: (m: string, k?: 'success' | 'error') => void;
  onChanged: () => void;
}) {
  return (
    <div style={{ display: 'grid', gap: 24 }}>
      <CourtsSection club={club} toast={toast} onChanged={onChanged} />
      <HoursSection club={club} toast={toast} onChanged={onChanged} />
      <PricingSection club={club} toast={toast} onChanged={onChanged} />
    </div>
  );
}

function CourtsSection({
  club,
  toast,
  onChanged,
}: {
  club: any;
  toast: (m: string, k?: 'success' | 'error') => void;
  onChanged: () => void;
}) {
  const [name, setName] = useState('');
  const [adding, setAdding] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);

  async function addCourt(e: FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    setAdding(true);
    try {
      await ownerApi.addCourt(club.id, { name: name.trim() });
      toast('Terrain ajouté');
      setName('');
      onChanged();
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Action impossible', 'error');
    } finally {
      setAdding(false);
    }
  }

  async function toggleActive(courtId: string, active: boolean) {
    setBusy(courtId);
    try {
      await ownerApi.updateCourt(club.id, courtId, { active });
      onChanged();
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Action impossible', 'error');
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="card card-pad">
      <div className="section-title">Terrains</div>
      {(club.courts ?? []).map((c: any) => (
        <div
          key={c.id}
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '8px 0',
            borderBottom: '1px solid var(--border)',
          }}
        >
          <div style={{ fontWeight: 600 }}>{c.name}</div>
          <label className="switch">
            <input
              type="checkbox"
              checked={c.active !== false}
              disabled={busy === c.id}
              onChange={(e) => toggleActive(c.id, e.target.checked)}
            />
            <span className="slider" />
          </label>
        </div>
      ))}
      <form onSubmit={addCourt} style={{ display: 'flex', gap: 8, marginTop: 14 }}>
        <input
          className="input"
          placeholder="Nom du nouveau terrain"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <button className="btn btn-primary" disabled={adding || !name.trim()}>
          Ajouter
        </button>
      </form>
    </div>
  );
}

function HoursSection({
  club,
  toast,
  onChanged,
}: {
  club: any;
  toast: (m: string, k?: 'success' | 'error') => void;
  onChanged: () => void;
}) {
  const existing = useMemo(() => {
    const map: Record<number, { openMin: number; closeMin: number }> = {};
    for (const h of club.openingHours ?? []) map[h.dayOfWeek] = h;
    return map;
  }, [club.openingHours]);

  const [hours, setHours] = useState(() =>
    Array.from({ length: 7 }, (_, i) => {
      const day = i + 1;
      const h = existing[day];
      return {
        dayOfWeek: day,
        open: h ? minToHHMM(h.openMin) : '09:00',
        close: h ? minToHHMM(h.closeMin) : '23:00',
        enabled: !!h,
      };
    }),
  );
  const [saving, setSaving] = useState(false);

  async function save() {
    setSaving(true);
    try {
      const payload = hours
        .filter((h) => h.enabled)
        .map((h) => ({
          dayOfWeek: h.dayOfWeek,
          openMin: hhmmToMin(h.open),
          closeMin: hhmmToMin(h.close),
        }));
      await ownerApi.setOpeningHours(club.id, payload);
      toast('Horaires enregistrés');
      onChanged();
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Action impossible', 'error');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="card card-pad">
      <div className="section-title">Horaires d&apos;ouverture</div>
      {hours.map((h, i) => (
        <div key={h.dayOfWeek} className="hour-row">
          <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontWeight: 600 }}>
            <input
              type="checkbox"
              checked={h.enabled}
              onChange={(e) => {
                const next = [...hours];
                next[i] = { ...h, enabled: e.target.checked };
                setHours(next);
              }}
            />
            {DAY_NAMES[i]}
          </label>
          <input
            className="input"
            type="time"
            disabled={!h.enabled}
            value={h.open}
            onChange={(e) => {
              const next = [...hours];
              next[i] = { ...h, open: e.target.value };
              setHours(next);
            }}
          />
          <input
            className="input"
            type="time"
            disabled={!h.enabled}
            value={h.close}
            onChange={(e) => {
              const next = [...hours];
              next[i] = { ...h, close: e.target.value };
              setHours(next);
            }}
          />
          <span />
        </div>
      ))}
      <button className="btn btn-primary" style={{ marginTop: 14 }} disabled={saving} onClick={save}>
        {saving ? 'Enregistrement…' : 'Enregistrer les horaires'}
      </button>
    </div>
  );
}

function PricingSection({
  club,
  toast,
  onChanged,
}: {
  club: any;
  toast: (m: string, k?: 'success' | 'error') => void;
  onChanged: () => void;
}) {
  const [courtId, setCourtId] = useState(club.courts?.[0]?.id ?? '');
  const court = club.courts?.find((c: any) => c.id === courtId);
  const [dayOfWeek, setDayOfWeek] = useState(1);
  const [start, setStart] = useState('09:00');
  const [end, setEnd] = useState('11:00');
  const [duration, setDuration] = useState(90);
  const [price, setPrice] = useState('');
  const [saving, setSaving] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);

  async function addRule(e: FormEvent) {
    e.preventDefault();
    if (!courtId || !price) return;
    setSaving(true);
    try {
      await ownerApi.addPricingRule(club.id, courtId, {
        dayOfWeek,
        startMin: hhmmToMin(start),
        endMin: hhmmToMin(end),
        durationMin: duration,
        priceMad: Number(price),
      });
      toast('Règle tarifaire ajoutée');
      setPrice('');
      onChanged();
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Action impossible', 'error');
    } finally {
      setSaving(false);
    }
  }

  async function deleteRule(ruleId: string) {
    setBusy(ruleId);
    try {
      await ownerApi.deletePricingRule(club.id, ruleId);
      toast('Règle supprimée');
      onChanged();
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'Action impossible', 'error');
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="card card-pad">
      <div className="section-title">Tarifs par terrain</div>
      <div className="field">
        <label>Terrain</label>
        <select className="input" value={courtId} onChange={(e) => setCourtId(e.target.value)}>
          {club.courts?.map((c: any) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </div>

      {(court?.pricingRules ?? []).length === 0 ? (
        <Empty icon={Tag} label="Aucune règle tarifaire pour ce terrain." />
      ) : (
        <div className="table-wrap" style={{ marginBottom: 16 }}>
          <table>
            <thead>
              <tr>
                <th>Jour</th>
                <th>Plage</th>
                <th>Durée</th>
                <th>Prix</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {court.pricingRules.map((r: any) => (
                <tr key={r.id}>
                  <td>{DAY_NAMES[r.dayOfWeek - 1]}</td>
                  <td>
                    {minToHHMM(r.startMin)} – {minToHHMM(r.endMin)}
                  </td>
                  <td>{r.durationMin} min</td>
                  <td>{money(Number(r.priceMad))}</td>
                  <td style={{ textAlign: 'right' }}>
                    <button
                      className="btn btn-sm"
                      style={{ border: 'none' }}
                      disabled={busy === r.id}
                      onClick={() => deleteRule(r.id)}
                    >
                      <Trash size={14} color="var(--danger)" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <form onSubmit={addRule} className="toolbar" style={{ marginBottom: 0 }}>
        <select
          className="input"
          style={{ maxWidth: 140 }}
          value={dayOfWeek}
          onChange={(e) => setDayOfWeek(Number(e.target.value))}
        >
          {DAY_NAMES.map((d, i) => (
            <option key={d} value={i + 1}>
              {d}
            </option>
          ))}
        </select>
        <input
          className="input"
          style={{ maxWidth: 110 }}
          type="time"
          value={start}
          onChange={(e) => setStart(e.target.value)}
        />
        <input
          className="input"
          style={{ maxWidth: 110 }}
          type="time"
          value={end}
          onChange={(e) => setEnd(e.target.value)}
        />
        <select
          className="input"
          style={{ maxWidth: 100 }}
          value={duration}
          onChange={(e) => setDuration(Number(e.target.value))}
        >
          {[60, 90, 120].map((d) => (
            <option key={d} value={d}>
              {d} min
            </option>
          ))}
        </select>
        <input
          className="input"
          style={{ maxWidth: 120 }}
          type="number"
          placeholder="Prix MAD"
          value={price}
          onChange={(e) => setPrice(e.target.value)}
        />
        <button className="btn btn-primary" disabled={saving || !price}>
          Ajouter
        </button>
      </form>
    </div>
  );
}
