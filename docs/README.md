# 🎾 Projet Padel App — Documentation

Application mobile de **matching entre joueurs de padel** et de **réservation de terrains** pour le marché **marocain**.

## Le projet en une phrase

Les joueurs trouvent des partenaires de leur niveau et réservent un terrain en 3 clics avec paiement partagé ; les clubs gèrent tout leur planning et gagnent de nouveaux clients ; la plateforme prend une commission sur chaque réservation.

## Choix structurants (validés)

| Sujet | Décision |
|---|---|
| Mobile | **Flutter** (un codebase iOS + Android) |
| Backend | **NestJS + PostgreSQL (PostGIS) + Redis** |
| Paiement | **CMI** (cartes marocaines) + paiement sur place — alternative pilote : YouCan Pay |
| Rôles | Joueur · Propriétaire de club · Admin (dashboard web) |
| Business model principal | Commission ~10 % sur les réservations en ligne + abonnement SaaS clubs |
| Langue | FR au lancement, AR/EN en V2 |

## Les documents

| Document | Contenu |
|---|---|
| [01-cahier-des-charges.md](01-cahier-des-charges.md) | Toutes les fonctionnalités par module (Auth, Joueur, Matching, Réservation, Propriétaire, Admin, Notifications) avec priorités MoSCoW, règles de gestion et exigences non fonctionnelles |
| [02-architecture-technique.md](02-architecture-technique.md) | Architecture globale, structure Flutter et NestJS, schéma complet de la base de données, flux critiques (anti-double réservation, paiement partagé), algorithme de matching, infrastructure et tests |
| [03-business-model.md](03-business-model.md) | Marché marocain, 5 sources de revenus, grille tarifaire MAD, coûts, unit economics, stratégie de lancement ville pilote, KPIs, risques |
| [04-apis-integrations.md](04-apis-integrations.md) | API externes (CMI, Google Maps, FCM, SMS OTP, S3…) avec coûts et alternatives + conception complète de l'API REST interne (endpoints par module, exemples JSON, WebSocket) |
| [05-roadmap-mvp.md](05-roadmap-mvp.md) | Périmètre MVP vs V1.1 vs V2, planning 16 semaines sprint par sprint, estimation d'effort, checklist de mise en production |

## Prochaines étapes recommandées

1. **Immédiat** : lancer le dossier CMI auprès de votre banque (délai 4-8 semaines) et le compte Apple Developer.
2. **Semaine 1** : maquettes UI (Figma) des écrans clés + démarchage des premiers clubs pilotes à Casablanca.
3. **Développement** : suivre le planning de [05-roadmap-mvp.md](05-roadmap-mvp.md) — fondations & auth d'abord.
