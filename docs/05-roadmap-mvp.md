# Roadmap & MVP — Application Padel

**Version :** 1.0 · Documents liés : [cahier des charges](01-cahier-des-charges.md) · [architecture](02-architecture-technique.md)

---

## 1. Découpage en versions

```
 MVP (V1)              V1.1                    V2
 3-4 mois              +2 mois                 +3-4 mois
─────────────────────────────────────────────────────────────►
 Réserver + matcher    Fidéliser + outiller    Monétiser + étendre
```

| | MVP (V1) | V1.1 | V2 |
|---|---|---|---|
| Auth | Email/tél + OTP, Google/Apple, rôles, suppression compte | — | Biométrie |
| Joueur | Profil + niveau auto-évalué, disponibilités, signalement | Niveau ELO auto, notation partenaires, stats, favoris | Premium joueur |
| Matching | Matchs ouverts, recherche, rejoindre, chat, désistement, paiement partagé | Suggestions personnalisées (score), saisie de score, matchs privés | Tournois |
| Réservation | Carte clubs, dispo temps réel, résa + CMI + sur place, QR, annulation/remboursement | Avis clubs, re-réservation 1 clic | Liste d'attente |
| Propriétaire | Club + terrains + tarifs, calendrier, résa manuelle, blocage, reversements | Stats, check-in QR, dashboard web | Promotions, multi-staff |
| Admin | Validation clubs, dashboard KPIs de base, gestion utilisateurs, modération, paramètres, audit log | Campagnes push, exports, rôles admin | — |
| Plateforme | FR, monitoring Sentry, backups | — | AR (RTL) + EN |

**Règle de discipline MVP :** tout ce qui n'empêche pas un joueur de *réserver un terrain* ou de *compléter un match* est reporté.

---

## 2. Planning MVP détaillé (16 semaines)

Hypothèse : 1 développeur full-stack expérimenté (ou 2 devs → diviser les durées par ~1,7).

| Sprint (2 sem.) | Backend | Mobile Flutter | Autres |
|---|---|---|---|
| **S1-S2 — Fondations** | Setup NestJS, PostgreSQL+PostGIS, Redis, Docker, CI/CD, module auth (JWT, OTP, social), RBAC | Setup Flutter, thème/design system, navigation, écrans auth complets | Maquettes UI (Figma), démarrage dossier CMI ⚠, création société si besoin |
| **S3-S4 — Clubs & profils** | Modules users, clubs, courts, pricing, opening_hours ; recherche géo PostGIS ; upload S3 présigné | Profil + questionnaire niveau, carte/liste clubs, fiche club | Onboarding des 1ers clubs pilotes (photos, tarifs) |
| **S5-S6 — Réservation** | Calcul de disponibilités à la volée, bookings + contrainte EXCLUDE, verrous Redis, annulation/politique | Grille des créneaux, tunnel de réservation, mes réservations | — |
| **S7-S8 — Paiement** | Intégration CMI (redirect + webhook), paiement sur place, QR codes, remboursements, payouts (calcul) | Webview paiement, confirmation + QR, gestion échecs | Tests CMI en environnement de test |
| **S9-S10 — Matching** | Module matches + match_players, paiement partagé, règles de désistement, jobs BullMQ (expiration, annulation H-2) | Création de match, recherche de matchs, rejoindre + payer sa part | — |
| **S11-S12 — Chat & notifs** | WebSocket chat, module notifications, FCM, emails Brevo, rappels cron | Chat de match, centre de notifications, préférences | — |
| **S13-S14 — Espace club & admin** | Endpoints owner (calendrier, manuel, blocage, reversements), endpoints admin | Mode club dans l'app (calendrier, résa manuelle, blocage) | Dashboard admin Next.js (validation clubs, KPIs, utilisateurs, modération) |
| **S15-S16 — Stabilisation** | Tests d'intégration (concurrence résa !), tests de charge k6, corrections | Tests E2E parcours critiques, polish UI, page stores | Beta fermée (TestFlight/Firebase App Distribution) avec 2-3 clubs et ~50 joueurs, textes légaux, soumission stores |

**⚠ Chemins critiques à démarrer dès la semaine 1 :**
1. **Dossier CMI** (4-8 semaines de délai bancaire) — sinon lancer le pilote avec YouCan Pay.
2. **Compte Apple Developer** (vérification d'entreprise parfois lente).
3. **Signature des clubs pilotes** (sans clubs, pas de contenu au lancement).

---

## 3. Estimation d'effort par module (MVP)

| Module | Complexité | Poids approximatif |
|---|---|---|
| Auth & sessions | Moyenne | 10 % |
| Clubs, terrains, tarifs, recherche géo | Moyenne | 15 % |
| Disponibilités + réservation + anti-concurrence | **Élevée** | 20 % |
| Paiement CMI + partagé + remboursements | **Élevée** | 15 % |
| Matching + désistements + jobs | **Élevée** | 15 % |
| Chat + notifications | Moyenne | 8 % |
| Espace propriétaire | Moyenne | 8 % |
| Dashboard admin | Moyenne | 7 % |
| Stabilisation, tests, stores | — | (transverse, S15-S16) |

Les trois modules « élevés » concentrent le risque : logique d'argent + concurrence. Y mettre les tests d'intégration en priorité.

---

## 4. Checklist de mise en production

**Légal & business**
- [ ] Société immatriculée, compte bancaire pro
- [ ] Contrat e-commerce CMI signé et testé en production
- [ ] CGU / CGV / politique de confidentialité rédigées (dans l'app + web)
- [ ] Déclaration CNDP (loi 09-08) pour le traitement des données personnelles
- [ ] Contrats clubs partenaires signés (commission, reversements, annulations)

**Technique**
- [ ] Environnement production isolé, secrets en variables d'environnement
- [ ] Backups PostgreSQL quotidiens + test de restauration effectué
- [ ] Sentry actif (API + Flutter), UptimeRobot configuré, alertes
- [ ] Rate limiting vérifié sur /auth/* ; test de charge réservation concurrente passé
- [ ] Webhook CMI vérifié (hash) et idempotent (double appel = pas de double confirmation)

**Stores**
- [ ] Compte Google Play + Apple Developer
- [ ] Fiches stores (captures, description FR), politique de confidentialité URL
- [ ] Apple Sign-In présent (exigence Apple), suppression de compte présente (exigence des deux stores)
- [ ] Beta testée (TestFlight / Firebase App Distribution) sur les parcours : inscription → réservation → annulation → match complet

**Lancement**
- [ ] 8-12 clubs pilotes actifs avec photos et tarifs à jour
- [ ] Staff des clubs formé (calendrier, résa manuelle, check-in)
- [ ] Plan de communication J0 (réseaux sociaux, affiches clubs, parrainage)

---

## 5. Après le MVP — critères de passage

| Passage | Critère |
|---|---|
| MVP → V1.1 | 500+ réservations cumulées, crash rate < 1 %, retours clubs collectés |
| V1.1 → V2 | Rétention M+1 > 30 %, 15+ clubs actifs, % matchs complétés > 60 % |
| Extension 2e ville | Playbook d'onboarding club rodé (< 1 semaine de la signature à la mise en ligne) |
