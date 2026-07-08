# Architecture Technique — Application Padel

**Version :** 1.0 · Basée sur le [cahier des charges](01-cahier-des-charges.md)

---

## 1. Vue d'ensemble

```
┌────────────────────┐        ┌────────────────────┐
│   App Mobile       │        │  Dashboard Web     │
│   Flutter          │        │  Admin (+ Club V1.1)│
│  (Joueur / Club)   │        │  React ou Next.js  │
└─────────┬──────────┘        └─────────┬──────────┘
          │  HTTPS (REST + WebSocket)   │
          ▼                             ▼
┌─────────────────────────────────────────────────┐
│                 API Gateway / Nginx              │
└─────────────────────────┬───────────────────────┘
                          ▼
┌─────────────────────────────────────────────────┐
│              Backend NestJS (monolithe modulaire)│
│  ┌────────┐ ┌───────┐ ┌────────┐ ┌───────────┐  │
│  │  Auth  │ │ Users │ │ Clubs  │ │ Bookings  │  │
│  ├────────┤ ├───────┤ ├────────┤ ├───────────┤  │
│  │Matching│ │ Chat  │ │Payments│ │Notif/Admin│  │
│  └────────┘ └───────┘ └────────┘ └───────────┘  │
└──────┬──────────────┬──────────────┬────────────┘
       ▼              ▼              ▼
┌────────────┐ ┌────────────┐ ┌─────────────────────┐
│ PostgreSQL │ │   Redis    │ │  Services externes  │
│ (+ PostGIS)│ │cache/locks/│ │ CMI · FCM · Maps ·  │
│            │ │  queues    │ │ SMS · S3 · Sentry   │
└────────────┘ └────────────┘ └─────────────────────┘
```

**Choix clé : monolithe modulaire NestJS** (pas de microservices au départ). Chaque module NestJS est isolé et pourra être extrait en service séparé plus tard si la charge l'exige. C'est le meilleur rapport simplicité/évolutivité pour une équipe réduite.

---

## 2. Application mobile Flutter

### 2.1 Stack
| Sujet | Choix | Pourquoi |
|---|---|---|
| Gestion d'état | **Riverpod** | Simple, testable, standard actuel |
| Navigation | go_router | Deep links (ouvrir un match depuis une notif) |
| HTTP | dio + retrofit | Interceptors pour JWT/refresh token |
| Temps réel | socket_io_client | Chat et mises à jour de matchs |
| Cartes | google_maps_flutter | Recherche de clubs |
| Notifications | firebase_messaging | Push FCM |
| Stockage sécurisé | flutter_secure_storage | Tokens |
| Cache local | drift (SQLite) | Réservations hors ligne |
| i18n | flutter_localizations + intl | FR puis AR (RTL)/EN |

### 2.2 Structure (Clean Architecture allégée)

```
lib/
├── core/                  # thème, constantes, erreurs, interceptors dio
├── features/
│   ├── auth/              # data / domain / presentation
│   ├── profile/
│   ├── matching/          # matchs ouverts, suggestions, chat
│   ├── booking/           # recherche clubs, créneaux, paiement
│   ├── owner/             # calendrier, terrains, stats (mode club)
│   └── notifications/
├── shared/                # widgets communs, modèles partagés
└── main.dart
```

- **Un seul binaire** pour joueur et propriétaire : l'interface bascule selon le rôle du compte (un propriétaire voit un onglet "Mon club" en plus).
- Chaque feature suit `data` (API + modèles) → `domain` (entités + use cases) → `presentation` (écrans + providers Riverpod).

### 2.3 Écrans principaux (MVP)

| Zone | Écrans |
|---|---|
| Auth | Onboarding, inscription, OTP, connexion, mot de passe oublié, questionnaire de niveau |
| Joueur | Accueil (matchs suggérés + prochaines résas), recherche de matchs, détail match + chat, création de match, profil, notation post-match |
| Réservation | Carte/liste des clubs, fiche club, grille des créneaux, tunnel de paiement, confirmation QR, mes réservations |
| Club | Calendrier, détail réservation + check-in, terrains & tarifs, réservation manuelle, blocage créneau, stats, reversements |
| Commun | Notifications, paramètres, édition profil |

---

## 3. Backend NestJS

### 3.1 Modules

```
src/
├── modules/
│   ├── auth/          # JWT, OTP, social login, refresh rotation, RBAC guards
│   ├── users/         # profils joueurs, niveaux, disponibilités, favoris
│   ├── clubs/         # clubs, terrains, tarifs, horaires, avis
│   ├── bookings/      # créneaux, réservations, annulations, QR codes
│   ├── matching/      # matchs ouverts, participants, suggestions, scores/ELO
│   ├── chat/          # WebSocket gateway, messages de match
│   ├── payments/      # CMI, paiements partagés, remboursements, payouts
│   ├── notifications/ # FCM, emails, préférences, campagnes
│   ├── admin/         # KPIs, validation clubs, modération, paramètres, audit log
│   └── reports/       # signalements
├── common/            # guards, interceptors, filters, DTO de pagination
└── infra/             # prisma/typeorm, redis, s3, config
```

- **ORM :** Prisma (ou TypeORM) avec migrations versionnées.
- **Validation :** DTO + class-validator sur chaque endpoint.
- **Files d'attente :** BullMQ (Redis) pour : envoi SMS/emails/push, rappels de match, expiration des verrous de créneaux, annulation des matchs incomplets, calcul ELO.
- **Tâches planifiées :** cron NestJS (rappels 24 h/2 h, génération des créneaux, relance des payouts).
- **WebSocket :** namespace `/chat` (messages) et `/live` (mise à jour temps réel des places d'un match et des créneaux).

### 3.2 Sécurité
- JWT access (15 min) + refresh token rotatif (30 j) stocké hashé en base — révocable.
- Guards RBAC : `@Roles('player' | 'owner' | 'admin')` + vérification de propriété des ressources (un owner ne voit que SES clubs).
- Rate limiting (Redis) : global + strict sur `/auth/*` (anti brute-force, anti spam OTP).
- Aucune donnée bancaire stockée : redirection vers la page de paiement CMI (le serveur ne voit jamais la carte).
- Audit log de toutes les actions admin et financières.
- Helmet, CORS restrictif, validation stricte des entrées, requêtes paramétrées (anti injection SQL).

---

## 4. Base de données PostgreSQL

Extension **PostGIS** pour la recherche géographique (clubs dans un rayon de X km).

### 4.1 Schéma principal

```
users            (id, email, phone, password_hash, role[], status,
                  created_at, last_login_at)
player_profiles  (user_id FK, first_name, last_name, avatar_url, city,
                  gender, birthdate, handedness, court_position,
                  level NUMERIC(2,1), level_confidence, elo_rating)
availabilities   (id, player_id FK, day_of_week, start_time, end_time)

clubs            (id, owner_id FK→users, name, description, address,
                  location GEOGRAPHY(Point), city, phone, amenities JSONB,
                  cancellation_policy JSONB, commission_rate,
                  status: pending|approved|rejected|suspended,
                  payment_on_site_allowed BOOL, rating_avg, created_at)
club_documents   (id, club_id FK, type, file_url, verified_at)
courts           (id, club_id FK, name, type: indoor|outdoor|panoramic,
                  photos JSONB, active BOOL)
opening_hours    (id, club_id FK, day_of_week, open_time, close_time)
pricing_rules    (id, court_id FK, day_of_week, start_time, end_time,
                  duration_min, price_mad)

bookings         (id, court_id FK, booked_by FK→users NULL, match_id FK NULL,
                  starts_at, ends_at, price_mad, status: pending_payment|
                  confirmed|cancelled|completed|no_show,
                  source: app|manual|blocked, payment_mode: online|on_site,
                  qr_code, cancellation_reason, created_at)
   ⚠ CONTRAINTE ANTI-DOUBLE-RÉSERVATION :
   EXCLUDE USING gist (court_id WITH =, tsrange(starts_at, ends_at) WITH &&)
   WHERE (status IN ('pending_payment','confirmed'))

matches          (id, creator_id FK, booking_id FK NULL, club_id FK,
                  starts_at, duration_min, level_min, level_max,
                  visibility: public|private, price_per_player_mad,
                  status: open|full|confirmed|played|cancelled,
                  score JSONB, created_at)
match_players    (id, match_id FK, player_id FK, team: 1|2 NULL,
                  status: requested|accepted|declined|withdrawn,
                  payment_id FK NULL, joined_at)
   UNIQUE (match_id, player_id)

payments         (id, user_id FK, booking_id FK NULL, match_id FK NULL,
                  amount_mad, commission_mad, method: cmi|on_site,
                  cmi_transaction_id, status: initiated|paid|failed|refunded,
                  refund_amount_mad, created_at)
payouts          (id, club_id FK, period_start, period_end, gross_mad,
                  commission_mad, net_mad, status: pending|paid, paid_at)

ratings          (id, match_id FK, rater_id FK, rated_id FK,
                  punctuality INT, fairplay INT, level_accuracy INT)
   UNIQUE (match_id, rater_id, rated_id)
club_reviews     (id, club_id FK, booking_id FK, user_id FK, rating INT,
                  comment, created_at)   UNIQUE (booking_id, user_id)

chat_messages    (id, match_id FK, sender_id FK, body, sent_at)
notifications    (id, user_id FK, type, title, body, data JSONB,
                  read_at, created_at)
reports          (id, reporter_id FK, target_type: user|club|review,
                  target_id, reason, status: open|resolved|dismissed,
                  handled_by FK NULL, created_at)
otp_codes        (id, phone, code_hash, purpose, expires_at, attempts)
refresh_tokens   (id, user_id FK, token_hash, device_info, expires_at,
                  revoked_at)
admin_audit_log  (id, admin_id FK, action, target_type, target_id,
                  payload JSONB, created_at)
app_settings     (key, value JSONB)   -- commission par défaut, délais, etc.
```

### 4.2 Points de conception importants
- **Les créneaux ne sont pas pré-générés en table** : les disponibilités sont calculées à la volée à partir de `opening_hours` + `pricing_rules` moins les `bookings` existants. Plus simple, pas de génération batch, pas de dérive.
- La contrainte `EXCLUDE` PostgreSQL garantit au niveau base qu'aucun chevauchement de réservation n'est possible, même en cas de bug applicatif ou de concurrence.
- `bookings.source = 'manual'` couvre les réservations téléphoniques du club ; `'blocked'` couvre maintenance/cours.
- `commission_rate` au niveau club permet de négocier des taux différents par club (ADM-06).

---

## 5. Flux critiques

### 5.1 Réservation avec paiement (anti-concurrence)

```
1. Le joueur choisit un créneau
2. POST /bookings → vérifie la dispo + pose un VERROU Redis
   SET lock:court:{id}:{start} NX EX 600  (10 min)
   + crée booking status=pending_payment
3. Redirection vers la page de paiement CMI (webview)
4. CMI → webhook serveur (callback signé) :
   - succès → booking=confirmed, génération QR, notifications
   - échec/timeout 10 min → booking=cancelled, verrou libéré (job BullMQ)
5. La contrainte EXCLUDE reste le filet de sécurité final
```

### 5.2 Match ouvert avec paiement partagé

```
1. Créateur crée le match (MTC-01) : créneau verrouillé + il paie sa part (1/4)
2. Le match apparaît dans la recherche ; les joueurs demandent à rejoindre
3. Chaque joueur accepté paie sa part → match_players.status=accepted
4. 4e joueur payé → match=confirmed, booking=confirmed, notif à tous
5. Si incomplet à H-2 : annulation automatique + remboursements (job BullMQ)
6. Désistement : place ré-ouverte + push aux joueurs compatibles proches
```

### 5.3 Algorithme de suggestion de matchs (MTC-04)

```
score(joueur, match) =
    0.40 × compatibilité_niveau   (1 - |niveau_joueur - niveau_moyen_match| / 2, borné à 0)
  + 0.25 × proximité              (1 - distance_km / rayon_max)
  + 0.20 × disponibilité          (créneau du match ∈ disponibilités déclarées ? 1 : 0.3)
  + 0.15 × affinité               (a déjà joué avec un des participants / favoris)
→ Top 10 des matchs open triés par score, recalculé à la demande
   (requête PostGIS + calcul en mémoire ; cache Redis 5 min)
```

### 5.4 Évolution du niveau (ELO adapté padel, V1.1)

- Chaque joueur a un `elo_rating` (départ selon niveau auto-évalué : niveau 3.0 → ~1200).
- Après un match avec score confirmé : gain/perte selon le résultat pondéré par l'écart de rating moyen des équipes (K=32, réduit à 16 après 30 matchs).
- Le niveau affiché (1.0-7.0) est une projection du rating ELO ; `level_confidence` augmente avec le nombre de matchs.

---

## 6. Dashboard web Admin

- **Stack :** Next.js + la même API NestJS (endpoints `/admin/*` protégés par rôle).
- Pages : Dashboard KPIs, Clubs en attente, Clubs, Utilisateurs, Réservations, Transactions & payouts, Signalements, Campagnes push, Paramètres, Logs d'audit.
- Graphiques : réservations/jour, GMV, MAU, top clubs.

---

## 7. Infrastructure & DevOps

| Sujet | Recommandation MVP | Évolution |
|---|---|---|
| Hébergement | 1 VPS (Hetzner/OVH/Contabo, 4-8 Go) avec Docker Compose : API, PostgreSQL, Redis, Nginx | Migration cloud managé (AWS/GCP) ou 2e nœud + load balancer |
| Conteneurs | Docker + docker-compose | Kubernetes seulement si vraie nécessité |
| CI/CD | GitHub Actions : lint + tests + build → déploiement auto sur staging, manuel sur prod | — |
| Environnements | `dev` (local) · `staging` · `production` | — |
| Backups | pg_dump quotidien → stockage objet (S3), rétention 30 j, test de restauration mensuel | Réplication PostgreSQL |
| Monitoring | Sentry (erreurs API + Flutter), UptimeRobot (uptime), logs structurés (pino) | Grafana + Prometheus |
| Stores | Compte Google Play (25 $ une fois) + Apple Developer (99 $/an) | — |
| Distribution beta | Firebase App Distribution / TestFlight | — |

---

## 8. Stratégie de tests

| Niveau | Outil | Cible |
|---|---|---|
| Unitaires backend | Jest | Logique métier : prix, annulation, ELO, matching |
| Intégration backend | Jest + Testcontainers (PostgreSQL) | Endpoints critiques, contrainte anti-chevauchement, webhooks CMI (mock) |
| Unitaires Flutter | flutter_test | Providers, mappers, validation de formulaires |
| E2E mobile | Patrol / integration_test | Parcours : inscription → réservation → annulation |
| Charge | k6 | Pic de réservations (samedi matin), verrous concurrents |
