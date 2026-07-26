'use client';

import {
  ReactNode,
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
} from 'react';
import { CheckCircle, Icon, Tray, WarningCircle, X } from '@phosphor-icons/react';

// ---------------------------------------------------------------- toasts

interface ToastItem {
  id: number;
  message: string;
  kind: 'success' | 'error';
}

const ToastContext = createContext<(message: string, kind?: 'success' | 'error') => void>(
  () => {},
);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);

  const push = useCallback((message: string, kind: 'success' | 'error' = 'success') => {
    const id = Date.now() + Math.random();
    setItems((prev) => [...prev, { id, message, kind }]);
    setTimeout(() => setItems((prev) => prev.filter((t) => t.id !== id)), 3200);
  }, []);

  return (
    <ToastContext.Provider value={push}>
      {children}
      <div className="toast-stack">
        {items.map((t) => (
          <div key={t.id} className={`toast toast-${t.kind}`}>
            {t.kind === 'success' ? (
              <CheckCircle size={18} weight="fill" />
            ) : (
              <WarningCircle size={18} weight="fill" />
            )}
            {t.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

/** `const toast = useToast(); toast('Club approuvé')` */
export function useToast() {
  return useContext(ToastContext);
}

// ----------------------------------------------------------------- modal

export function Modal({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-panel" onClick={(e) => e.stopPropagation()}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <div className="modal-title">{title}</div>
          <button
            className="btn btn-sm"
            style={{ border: 'none', padding: 4 }}
            onClick={onClose}
            aria-label="Fermer"
          >
            <X size={16} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

// ----------------------------------------------------------------- drawer

/** Panneau latéral de détail (fiche utilisateur / club). */
export function Drawer({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="drawer-overlay" onClick={onClose}>
      <div className="drawer-panel" onClick={(e) => e.stopPropagation()}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
          <div style={{ fontSize: 17, fontWeight: 800, letterSpacing: '-0.2px' }}>{title}</div>
          <button className="btn btn-sm" style={{ border: 'none', padding: 4 }} onClick={onClose} aria-label="Fermer">
            <X size={16} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

/** Ligne libellé / valeur d'une fiche de détail. */
export function Field({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div style={{ padding: '10px 0', borderBottom: '1px solid var(--border)' }}>
      <div style={{ color: 'var(--text-muted)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.03em' }}>
        {label}
      </div>
      <div style={{ marginTop: 3, fontSize: 14 }}>{value ?? '—'}</div>
    </div>
  );
}

// -------------------------------------------------------------- export CSV

/**
 * Télécharge un tableau au format CSV.
 * Le BOM UTF-8 est indispensable pour qu'Excel n'abîme pas les accents.
 */
export function downloadCsv(filename: string, rows: Record<string, unknown>[]) {
  if (!rows.length) return;
  const headers = Object.keys(rows[0]);
  const escape = (v: unknown) => {
    const s = v === null || v === undefined ? '' : String(v);
    // Guillemets doublés + encadrement dès qu'un séparateur est présent
    return /[";\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const csv = [
    headers.join(';'),
    ...rows.map((r) => headers.map((h) => escape(r[h])).join(';')),
  ].join('\r\n');

  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function Loading({ label = 'Chargement…' }: { label?: string }) {
  return (
    <div className="state">
      <div className="spinner" />
      {label}
    </div>
  );
}

export function ErrorState({ message }: { message: string }) {
  return <div className="alert alert-error">{message}</div>;
}

export function Empty({ label, icon: IconCmp = Tray }: { label: string; icon?: Icon }) {
  return (
    <div className="state">
      <IconCmp size={30} style={{ marginBottom: 8, opacity: 0.5 }} />
      <div>{label}</div>
    </div>
  );
}

/** Lignes de tableau en chargement (remplace le spinner générique). */
export function TableSkeleton({ rows = 5, cols = 5 }: { rows?: number; cols?: number }) {
  return (
    <div className="table-wrap">
      {Array.from({ length: rows }).map((_, i) => (
        <div className="skeleton-row" key={i}>
          {Array.from({ length: cols }).map((_, j) => (
            <div
              key={j}
              className="skeleton-block"
              style={{ height: 14, flex: j === 0 ? 2 : 1 }}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

/** Cartes KPI en chargement. */
export function KpiSkeleton({ count = 4 }: { count?: number }) {
  return (
    <div className="kpi-grid">
      {Array.from({ length: count }).map((_, i) => (
        <div className="kpi" key={i}>
          <div className="skeleton-block" style={{ height: 12, width: '60%', marginBottom: 12 }} />
          <div className="skeleton-block" style={{ height: 24, width: '40%' }} />
        </div>
      ))}
    </div>
  );
}

export function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="page-header">
      <div>
        <div className="page-title">{title}</div>
        {subtitle && <div className="page-subtitle">{subtitle}</div>}
      </div>
      {actions}
    </div>
  );
}

const STATUS_STYLE: Record<string, string> = {
  APPROVED: 'badge-green',
  ACTIVE: 'badge-green',
  RESOLVED: 'badge-green',
  CONFIRMED: 'badge-green',
  PENDING: 'badge-amber',
  OPEN: 'badge-amber',
  PENDING_PAYMENT: 'badge-amber',
  SUSPENDED: 'badge-red',
  BANNED: 'badge-red',
  REJECTED: 'badge-red',
  CANCELLED: 'badge-red',
  DELETED: 'badge-gray',
  DISMISSED: 'badge-gray',
  BLOCKED: 'badge-gray',
  COMPLETED: 'badge-blue',
};

export function StatusBadge({ status }: { status: string }) {
  const cls = STATUS_STYLE[status] ?? 'badge-blue';
  return <span className={`badge ${cls}`}>{status}</span>;
}
