'use client';

import { ReactNode } from 'react';

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
  PENDING: 'badge-amber',
  OPEN: 'badge-amber',
  SUSPENDED: 'badge-red',
  BANNED: 'badge-red',
  REJECTED: 'badge-red',
  DELETED: 'badge-gray',
  DISMISSED: 'badge-gray',
};

export function StatusBadge({ status }: { status: string }) {
  const cls = STATUS_STYLE[status] ?? 'badge-blue';
  return <span className={`badge ${cls}`}>{status}</span>;
}
