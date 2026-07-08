# APIs & Intégrations — Application Padel

**Version :** 1.0 · Documents liés : [architecture](02-architecture-technique.md) · [cahier des charges](01-cahier-des-charges.md)

Ce document couvre : **(A)** les API externes à intégrer et **(B)** la conception de l'API interne (REST) consommée par l'app Flutter et le dashboard admin.

---

## A. API externes

### A.1 Tableau récapitulatif

| Besoin | Service recommandé | Alternative | Coût indicatif | Priorité |
|---|---|---|---|---|
| Paiement en ligne (Maroc) | **CMI** (Centre Monétique Interbancaire) | YouCan Pay, PayZone | ~1,5-2,5 %/transaction + frais dossier | MVP |
| Cartes & géolocalisation | **Google Maps Platform** | Mapbox, OpenStreetMap | Crédit gratuit 200 $/mois puis à l'usage | MVP |
| Notifications push | **Firebase Cloud Messaging (FCM)** | OneSignal | Gratuit | MVP |
| SMS OTP | **Twilio Verify** ou fournisseur local (Infobip, SMSCloud Maroc) | Vonage | ~0,3-0,5 MAD/SMS | MVP |
| Auth sociale | **Google Sign-In + Apple Sign-In** | — | Gratuit (Apple Dev 99 $/an) | MVP |
| Emails transactionnels | **Brevo** (ex-Sendinblue) | SendGrid, Resend | Gratuit jusqu'à 300 emails/j | MVP |
| Stockage médias | **AWS S3** (ou Cloudflare R2) | Cloudinary | Quelques $/mois | MVP |
| Crash & erreurs | **Sentry** (Flutter + NestJS) | Crashlytics | Gratuit (plan dev) | MVP |
| Analytics produit | **Firebase Analytics** | Mixpanel, PostHog | Gratuit | MVP |
| Uptime | **UptimeRobot** | BetterStack | Gratuit | MVP |

### A.2 Détails d'intégration

**1. CMI (paiement)**
- Pré-requis : société immatriculée + compte bancaire pro + contrat e-commerce avec votre banque → obtention du compte marchand CMI. **Démarrer la démarche tôt (4-8 semaines).**
- Intégration : redirection vers la page de paiement hébergée CMI (le client saisit sa carte chez CMI, jamais chez vous → pas de certification PCI-DSS lourde).
- Flux : `POST` formulaire signé (clé store + hash) → paiement → **callback serveur** (webhook `okUrl`/`failUrl` + confirmation server-to-server) → vérification du hash → mise à jour `payments.status`.
- Remboursements : via le back-office CMI (manuel au MVP, tracé dans `payments.refund_amount_mad`).
- Alternative plus rapide à mettre en place au départ : **YouCan Pay** (onboarding simple, API moderne, webhooks) — bon choix pour le pilote si le dossier CMI traîne.

**2. Google Maps Platform**
- Produits utilisés : **Maps SDK** (carte des clubs dans Flutter), **Geocoding** (adresse club → coordonnées à la création), **Distance Matrix** (tri des clubs/matchs par distance — remplaçable par un calcul PostGIS gratuit côté serveur, recommandé pour économiser le quota).
- Optimisation coût : calcul des distances en SQL PostGIS (`ST_DWithin`, `ST_Distance`) plutôt que Distance Matrix ; Maps SDK mobile est gratuit.

**3. Firebase Cloud Messaging**
- Un seul projet Firebase pour Android + iOS (APNs derrière).
- Le backend envoie via `firebase-admin` (module `notifications`).
- Types de push : voir NTF-01 à NTF-06 du cahier des charges ; `data payload` avec deep link (`match/{id}`, `booking/{id}`).

**4. SMS OTP**
- Twilio Verify gère génération/expiration/anti-abus. Un agrégateur local est souvent moins cher au volume vers les numéros marocains — à comparer au moment du lancement.
- Réduction du volume : proposer Google/Apple Sign-In en premier ; OTP uniquement pour l'inscription par téléphone et les actions sensibles.

**5. Auth sociale**
- Google Sign-In (package `google_sign_in`) + Apple Sign-In (`sign_in_with_apple`, **obligatoire** sur iOS dès qu'un login social existe).
- Le backend vérifie l'`id_token` auprès de Google/Apple puis émet ses propres JWT.

**6. Stockage médias (S3/R2)**
- Upload direct depuis l'app via **URL présignée** (le backend génère l'URL, l'app upload directement → pas de charge serveur).
- Redimensionnement des images (avatars 256px, photos clubs 1280px) via job BullMQ ou Cloudinary si budget.

---

## B. API interne (REST)

### B.1 Conventions

- Base : `https://api.votredomaine.ma/v1`
- Auth : `Authorization: Bearer <access_token>` ; refresh via `/auth/refresh`.
- Format : JSON ; erreurs normalisées :
```json
{ "statusCode": 409, "error": "SLOT_ALREADY_BOOKED", "message": "Ce créneau vient d'être réservé." }
```
- Pagination : `?page=1&limit=20` → `{ "data": [...], "meta": { "total", "page", "pages" } }`
- Dates : ISO 8601 UTC (`2026-07-08T18:00:00Z`) ; montants en centimes MAD (`30000` = 300,00 MAD).
- Versionnement : préfixe `/v1` ; changements cassants → `/v2`.

### B.2 Endpoints par module

**Auth (`/auth`)**
```
POST   /auth/register              # email ou téléphone + profil de base
POST   /auth/otp/send              # { phone, purpose }
POST   /auth/otp/verify            # { phone, code }
POST   /auth/login                 # → { accessToken, refreshToken, user }
POST   /auth/social                # { provider: google|apple, idToken }
POST   /auth/refresh               # rotation du refresh token
POST   /auth/logout                # révoque le refresh token courant
POST   /auth/password/forgot ·  POST /auth/password/reset
DELETE /auth/account               # suppression de compte (AUTH-09)
```

**Joueurs (`/players`)**
```
GET    /players/me                 # profil complet + stats
PATCH  /players/me                 # édition profil, niveau initial, position
PUT    /players/me/availabilities  # créneaux récurrents
GET    /players/:id                # profil public
POST   /players/:id/favorite  ·  DELETE /players/:id/favorite
POST   /reports                    # { targetType, targetId, reason }
```

**Clubs & recherche (`/clubs`)**
```
GET    /clubs?lat=&lng=&radius=&date=&indoor=&sort=   # recherche géo + filtres
GET    /clubs/:id                  # fiche complète (terrains, équipements, avis)
GET    /clubs/:id/availability?date=2026-07-12&duration=90
       # → grille des créneaux libres par terrain, calculée à la volée
GET    /clubs/:id/reviews  ·  POST /clubs/:id/reviews   # (résa honorée requise)
```

**Réservations (`/bookings`)**
```
POST   /bookings                   # { courtId, startsAt, duration, paymentMode }
                                   # → verrou 10 min + { booking, paymentUrl? }
GET    /bookings/me?status=upcoming|past
GET    /bookings/:id               # détail + QR code
POST   /bookings/:id/cancel        # applique la politique du club, remboursement
```

**Matching (`/matches`)**
```
POST   /matches                    # créer un match ouvert (créneau + niveaux + places)
GET    /matches?lat=&lng=&date=&level=  # recherche de matchs ouverts
GET    /matches/suggestions        # top 10 personnalisé (MTC-04)
GET    /matches/:id                # détail : joueurs, places, prix/joueur
POST   /matches/:id/join           # demande à rejoindre → paiement de la part
POST   /matches/:id/requests/:playerId/accept | /decline
POST   /matches/:id/withdraw       # désistement (règles MTC-07)
POST   /matches/:id/score          # saisie du score (MTC-08)
POST   /matches/:id/ratings        # notation des partenaires (PLY-06)
GET    /matches/:id/messages  ·  WS /chat (room = match:{id})
```

**Paiements (`/payments`)**
```
POST   /payments/cmi/callback      # webhook CMI (public, vérif hash signé)
GET    /payments/me                # historique du joueur
```

**Espace propriétaire (`/owner`)** — rôle `owner`, ressources filtrées par propriété
```
POST   /owner/clubs                # demande de création (→ validation admin)
PATCH  /owner/clubs/:id            # infos, photos, politique d'annulation
POST   /owner/clubs/:id/courts  ·  PATCH /owner/courts/:id
PUT    /owner/courts/:id/pricing   # règles tarifaires (jour/heure/durée)
PUT    /owner/clubs/:id/hours      # horaires d'ouverture
GET    /owner/clubs/:id/calendar?from=&to=    # toutes résas (app/manuel/bloqué)
POST   /owner/clubs/:id/bookings/manual       # réservation manuelle (OWN-06)
POST   /owner/clubs/:id/blocks                # blocage de créneaux (OWN-05)
POST   /owner/bookings/:id/checkin            # scan QR (OWN-07)
GET    /owner/clubs/:id/stats?period=         # occupation, revenus (OWN-08)
GET    /owner/clubs/:id/payouts               # reversements (OWN-09)
```

**Admin (`/admin`)** — rôle `admin`, toutes les actions écrites dans `admin_audit_log`
```
GET    /admin/dashboard            # KPIs (ADM-01)
GET    /admin/clubs?status=pending
POST   /admin/clubs/:id/approve | /reject     # { reason }
GET    /admin/users?query=  ·  POST /admin/users/:id/suspend | /ban | /restore
GET    /admin/reports?status=open  ·  POST /admin/reports/:id/resolve
GET    /admin/payments  ·  GET /admin/payouts  ·  POST /admin/payouts/:id/mark-paid
PATCH  /admin/settings             # commission par défaut, délais (ADM-06)
POST   /admin/campaigns/push       # campagne ciblée (ADM-07)
GET    /admin/audit-log
```

**Notifications (`/notifications`)**
```
GET    /notifications/me  ·  POST /notifications/:id/read
PUT    /notifications/preferences  # préférences par catégorie (NTF-07)
POST   /devices                    # enregistrement du token FCM
```

### B.3 Exemple de flux complet — réservation payée en ligne

```
1. GET  /clubs/42/availability?date=2026-07-12&duration=90
   → { "courts": [ { "courtId": 7, "slots": [ { "startsAt": "...T18:00:00Z", "priceMad": 30000 } ] } ] }

2. POST /bookings  { "courtId": 7, "startsAt": "...T18:00:00Z", "duration": 90, "paymentMode": "online" }
   → 201 { "booking": { "id": "bkg_123", "status": "pending_payment", "expiresAt": "+10min" },
           "payment": { "provider": "cmi", "redirectUrl": "https://payment.cmi.co.ma/..." } }
   (409 SLOT_ALREADY_BOOKED si concurrence)

3. L'app ouvre redirectUrl dans une webview → paiement CMI

4. CMI → POST /payments/cmi/callback (hash vérifié)
   → booking "confirmed", QR généré, push NTF-01, email

5. GET /bookings/bkg_123 → { "status": "confirmed", "qrCode": "data:image/png;base64,..." }
```

### B.4 WebSocket (temps réel)

| Canal | Événements |
|---|---|
| `match:{id}` | `message.new`, `player.joined`, `player.withdrawn`, `match.confirmed`, `match.cancelled` |
| `user:{id}` | `notification.new`, `booking.updated` |

Auth WebSocket : JWT passé à la connexion (`handshake.auth.token`), rooms rejointes après vérification d'appartenance au match.
