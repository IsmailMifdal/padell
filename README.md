# 🎾 Padel App — Matching & Réservation (Maroc)

Application mobile de matching entre joueurs de padel et de réservation de terrains.

| Dossier | Contenu |
|---|---|
| [docs/](docs/README.md) | Cahier des charges, architecture, business model, APIs, roadmap |
| [backend/](backend/) | API NestJS + PostgreSQL (PostGIS) + Redis — **MVP backend complet** |
| [admin-web/](admin-web/) | Dashboard admin **Next.js** — login, KPIs, validation clubs, utilisateurs, modération, audit |
| [mobile/](mobile/) | App **Flutter** (Riverpod, go_router, dio) — auth, recherche de clubs, réservation, mes résas |

## Démarrage rapide (backend)

```bash
cd backend
npm install
cp .env.example .env          # adapter les secrets
docker compose up -d          # PostgreSQL (PostGIS) + Redis
npx prisma migrate deploy     # crée les tables
npm run start:dev             # API sur http://localhost:3000/v1
```

## État d'avancement (roadmap MVP — docs/05)

| Sprint | Périmètre | État |
|---|---|---|
| S1-S2 | Auth (JWT, OTP SMS, Google/Apple, refresh rotatif, RBAC), profils, CI | ✅ Backend |
| S3-S4 | Clubs, terrains, tarifs, horaires, recherche géo PostGIS, dispos joueur | ✅ Backend |
| S5-S6 | Disponibilités à la volée, réservations (verrou Redis + contrainte `EXCLUDE`), annulation | ✅ Backend |
| S7-S8 | Paiement CMI (formulaire signé + webhook idempotent), sur place, QR, remboursements, payouts | ✅ Backend |
| S9-S10 | Matchs ouverts, rejoindre/accepter, paiement partagé, désistements, annulation auto H-2 | ✅ Backend |
| S11-S12 | Chat WebSocket (`/chat`), notifications + rappels H-2, device tokens FCM | ✅ Backend |
| S13-S14 | Espace club (calendrier, résa manuelle, blocage, check-in QR) + admin (KPIs, validation, modération, audit) | ✅ Backend |
| — | Dashboard admin Next.js (login, KPIs, clubs, utilisateurs, signalements, audit) | ✅ Web |
| — | App mobile Flutter (auth, clubs, créneaux, réservation, mes résas + QR) | ✅ Mobile |
| — | Prod : vrai fournisseur SMS, firebase-admin (push), upload S3, Sentry, tests charge k6 | ⬜ À faire |

## Démarrage du dashboard admin

```bash
cd admin-web
npm install
cp .env.example .env.local     # NEXT_PUBLIC_API_URL → URL de l'API
npm run dev                    # dashboard sur http://localhost:3002
```

> Connexion avec un compte dont le rôle inclut `ADMIN` (les autres comptes sont refusés).

## Démarrage de l'app mobile (Flutter)

```bash
cd mobile
flutter pub get
flutter run                    # émulateur Android : API sur 10.0.2.2:3001
# ou cibler une autre API :
flutter run --dart-define=API_URL=http://10.0.2.2:3001/v1
```

Architecture (docs/02) : **Riverpod** (état), **go_router** (navigation + garde d'auth),
**dio** (HTTP avec intercepteur JWT + refresh automatique), **flutter_secure_storage**
(tokens). Écrans : onboarding/connexion, inscription, connexion par SMS (OTP),
liste des clubs, fiche club + créneaux, tunnel de réservation, mes réservations (avec QR).

## Aperçu de l'API (préfixe `/v1`)

- `POST /auth/register · login · otp/send · otp/verify · social · password/reset · refresh · logout`
- `GET/PATCH/DELETE /users/me` · `PUT /users/me/availabilities`
- `GET /clubs?lat&lng&radiusKm` · `GET /clubs/:id` · `GET /clubs/:id/availability?date=`
- `POST /clubs` + terrains, horaires, tarifs (propriétaire)
- `POST /bookings` · `GET /bookings/mine` · `POST /bookings/:id/cancel`
- `POST /payments/bookings/:id/session` · `POST /payments/matches/:id/session` · `POST /payments/cmi/callback` (webhook)
- `POST /matches` · `GET /matches` · `join / accept / decline / withdraw / cancel` · `GET /matches/:id/messages`
- WebSocket `io('/chat', { auth: { token } })` : `join { matchId }`, `message { matchId, body }`
- `GET /notifications` · `PUT /notifications/device`
- `/owner/clubs/:id/*` : calendar, bookings/manual, bookings/block, checkin, payouts
- `/admin/*` : kpis, clubs (approve/reject/suspend), users, reports, audit-log
