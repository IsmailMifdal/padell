# État des intégrations externes

**Principe :** chaque service est codé avec un **repli développement automatique** — sans clé dans `.env`, l'API démarre normalement et le service loggue au lieu d'envoyer. Pour passer en production, il suffit de créer les comptes ci-dessous et de coller les clés.

| # | Service | Code | Compte à créer | Clés (`backend/.env` sauf mention) |
|---|---|---|---|---|
| 1 | **CMI** — paiement | ✅ Intégré (formulaire ver3 + webhook idempotent + simulation dev) | Contrat e-commerce via votre banque → compte marchand CMI (⏱ 4-8 semaines, à lancer tôt). Pilote possible avec YouCan Pay | `CMI_MERCHANT_ID`, `CMI_STORE_KEY`, `CMI_GATEWAY_URL`, `CMI_OK_URL`, `CMI_FAIL_URL`, `CMI_CALLBACK_URL` |
| 2 | **Twilio** — SMS OTP | ✅ Intégré (`sms.service.ts`, API REST) | [console.twilio.com](https://console.twilio.com) → acheter un numéro ou Sender ID. Comparer avec agrégateur marocain au volume | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM` |
| 3 | **Firebase FCM** — push | ✅ Intégré (`push.service.ts`, firebase-admin + purge des tokens morts) | [console.firebase.google.com](https://console.firebase.google.com) → projet unique Android+iOS → Paramètres → Comptes de service → *Générer une clé privée* | `FIREBASE_SERVICE_ACCOUNT_BASE64` (le JSON encodé : `base64 -w0 service-account.json`) |
| 4 | **Brevo** — emails | ✅ Intégré (`email.service.ts`, envoi sur réservation/match confirmés) | [app.brevo.com](https://app.brevo.com) → SMTP & API → clé API (gratuit 300 emails/j) | `BREVO_API_KEY`, `EMAIL_FROM`, `EMAIL_FROM_NAME` |
| 5 | **S3 / Cloudflare R2** — médias | ✅ Intégré (`media/` : URL présignée, upload avatar dans l'app) | Bucket S3 (AWS) ou R2 (Cloudflare, gratuit 10 Go) + jeton d'accès | `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_REGION`, `S3_ENDPOINT` (R2/MinIO), `S3_PUBLIC_URL` |
| 6 | **Sentry** — erreurs | ✅ Intégré (API + Flutter, inactif sans DSN) | [sentry.io](https://sentry.io) → 2 projets (Node, Flutter) | API : `SENTRY_DSN` · App : `--dart-define=SENTRY_DSN=...` |
| 7 | **Google / Apple Sign-In** | ✅ Intégré (backend JWKS + boutons app conditionnels) | Google Cloud Console → OAuth client Web + Android + iOS. Apple Developer (99 $/an) → Sign in with Apple (obligatoire iOS) | Backend : `GOOGLE_CLIENT_ID`, `APPLE_CLIENT_ID` · App : `--dart-define=GOOGLE_WEB_CLIENT_ID=...` |
| 8 | Google Maps | ✅ **Non nécessaire** — remplacé par flutter_map/OpenStreetMap (carte) + PostGIS (distances), gratuits | — | — |
| 9 | Firebase Analytics | 📄 À brancher après création du projet Firebase (mêmes fichiers de config que FCM : `google-services.json` / `GoogleService-Info.plist` dans `mobile/android|ios`) | Même projet Firebase que FCM | Fichiers de config mobiles |
| 10 | UptimeRobot — uptime | 📄 Config web uniquement, zéro code | [uptimerobot.com](https://uptimerobot.com) → monitor HTTP sur `https://api.votredomaine.ma/v1/health` (mot-clé `ok`) | — |

## Vérifier chaque intégration

- **SMS** : `POST /v1/auth/otp/send` → le SMS arrive (ou code dans les logs si non configuré).
- **Push** : enregistrer un token via `PUT /v1/notifications/device` puis déclencher une réservation → notification sur l'appareil (ou log).
- **Email** : payer une réservation (ou simuler en dev) → email « Réservation confirmée » (ou log `[DEV] Email → ...`).
- **Médias** : `POST /v1/media/presign {"kind":"avatar","contentType":"image/jpeg"}` → `{uploadUrl, publicUrl}` (503 explicite si S3 non configuré) ; dans l'app : Profil → Mon profil de jeu → photo.
- **Sentry** : lever une exception volontaire → l'événement apparaît dans le projet Sentry.
- **Google Sign-In** : builder l'app avec `--dart-define=GOOGLE_WEB_CLIENT_ID=...` → le bouton apparaît sur l'écran de connexion.
- **CMI** : en dev, bouton « Payer maintenant (simulation dev) » ; en production, la simulation renvoie 403 et seul le webhook CMI signé confirme.
