// Test de charge k6 — pic de réservations concurrentes (docs/02 §8).
//
//   k6 run -e API=https://api.mondomaine.ma/v1 -e EMAIL=... -e PASSWORD=... \
//          -e COURT_ID=... -e STARTS_AT=2026-08-01T18:00:00 booking-concurrency.js
//
// Invariant vérifié : quel que soit le nombre de requêtes simultanées sur le
// même créneau, UNE SEULE réservation aboutit (verrou Redis + contrainte
// EXCLUDE PostgreSQL) — toutes les autres reçoivent 409.

import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';

const API = __ENV.API || 'http://localhost:3001/v1';
const successes = new Counter('booking_successes');
const conflicts = new Counter('booking_conflicts');

export const options = {
  scenarios: {
    // 30 joueurs cliquent « Réserver » sur le même créneau au même instant
    same_slot_burst: {
      executor: 'per-vu-iterations',
      vus: 30,
      iterations: 1,
      maxDuration: '30s',
    },
  },
  thresholds: {
    booking_successes: ['count==1'], // exactement une réservation créée
    http_req_failed: ['rate<0.05'],  // hors 409 attendus
  },
};

export function setup() {
  const login = http.post(
    `${API}/auth/login`,
    JSON.stringify({ identifier: __ENV.EMAIL, password: __ENV.PASSWORD }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(login, { 'login ok': (r) => r.status === 200 });
  return { token: login.json('accessToken') };
}

export default function (data) {
  const res = http.post(
    `${API}/bookings`,
    JSON.stringify({
      courtId: __ENV.COURT_ID,
      startsAt: __ENV.STARTS_AT,
      durationMin: 90,
      paymentMode: 'ON_SITE',
    }),
    {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${data.token}`,
      },
    },
  );
  if (res.status === 201) successes.add(1);
  else if (res.status === 409) conflicts.add(1);

  check(res, { '201 ou 409 (jamais de double résa)': (r) => r.status === 201 || r.status === 409 });
}
