'use client';

import {
  ReactNode,
  createContext,
  useCallback,
  useContext,
  useState,
} from 'react';
import { CheckCircle, WarningCircle, X } from '@phosphor-icons/react';

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

export function Empty({ label }: { label: string }) {
  return <div className="state">{label}</div>;
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
