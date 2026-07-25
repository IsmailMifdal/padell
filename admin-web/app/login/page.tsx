'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ChartBar, Racquet, ShieldCheck } from '@phosphor-icons/react';
import { ApiError, landingFor, login } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const data = await login(identifier, password);
      router.push(landingFor(data.user));
    } catch (err) {
      setError(
        err instanceof ApiError ? err.message : 'Connexion impossible',
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-wrap">
      <div className="login-hero">
        <div
          className="login-hero-glow"
          style={{ height: 220, width: 220, right: -60, top: -50 }}
        />
        <div
          className="login-hero-glow"
          style={{ height: 120, width: 120, right: 60, bottom: 40, background: 'rgba(198,246,141,0.18)' }}
        />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, position: 'relative' }}>
          <div
            style={{
              height: 40,
              width: 40,
              borderRadius: 12,
              background: 'rgba(255,255,255,0.16)',
              display: 'grid',
              placeItems: 'center',
              fontSize: 20,
            }}
          >
            🎾
          </div>
          <span style={{ fontWeight: 800, fontSize: 17, letterSpacing: 3 }}>PADEL</span>
        </div>

        <div style={{ position: 'relative' }}>
          <div className="login-hero-title">
            Pilotez votre
            <br />
            plateforme padel.
          </div>
          <div className="login-hero-sub">
            Modération des clubs, gestion des utilisateurs et supervision
            des réservations — ou l&apos;espace propriétaire pour gérer
            vos terrains au quotidien.
          </div>
        </div>

        <div className="login-hero-badges" style={{ position: 'relative' }}>
          <span className="login-hero-badge">
            <ShieldCheck size={14} weight="fill" />
            Admin
          </span>
          <span className="login-hero-badge">
            <Racquet size={14} weight="fill" />
            Propriétaire
          </span>
          <span className="login-hero-badge">
            <ChartBar size={14} weight="fill" />
            Statistiques
          </span>
        </div>
      </div>

      <div className="login-form-side">
        <form className="login-card" onSubmit={onSubmit}>
          <div className="login-brand">Connexion</div>
          <div className="login-sub">Accédez à votre espace</div>

          {error && <div className="alert alert-error">{error}</div>}

          <div className="field">
            <label htmlFor="id">Email</label>
            <input
              id="id"
              className="input"
              type="email"
              autoComplete="username"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              placeholder="vous@padel.ma"
              required
            />
          </div>

          <div className="field">
            <label htmlFor="pw">Mot de passe</label>
            <input
              id="pw"
              className="input"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <button
            className="btn btn-primary"
            style={{ width: '100%', justifyContent: 'center', height: 44 }}
            disabled={loading}
          >
            {loading ? 'Connexion…' : 'Se connecter'}
          </button>
        </form>
      </div>
    </div>
  );
}
