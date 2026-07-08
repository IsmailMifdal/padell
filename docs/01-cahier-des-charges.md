# Cahier des Charges — Application Mobile Padel (Matching & Réservation)

**Version :** 1.0 · **Date :** 08/07/2026 · **Marché cible :** Maroc

---

## 1. Présentation du projet

### 1.1 Contexte
Le padel connaît une croissance explosive au Maroc (Casablanca, Rabat, Marrakech, Tanger…). Les joueurs rencontrent deux problèmes majeurs :
1. **Trouver des partenaires** de niveau similaire pour compléter un match (le padel se joue à 4).
2. **Réserver un terrain** : aujourd'hui la réservation se fait par téléphone ou WhatsApp, sans visibilité sur les disponibilités.

Les clubs, de leur côté, gèrent leurs plannings manuellement (cahier, Excel, WhatsApp) et n'ont pas d'outil de gestion ni de canal d'acquisition de nouveaux clients.

### 1.2 Objectif
Créer une application mobile (iOS + Android) qui :
- Met en relation les joueurs de padel selon leur **niveau, position, disponibilité et localisation**.
- Permet la **réservation en ligne** de terrains avec paiement intégré.
- Offre aux **clubs** un outil de gestion de planning et de revenus.
- Offre à l'**admin** un tableau de bord de monitoring complet de la plateforme.

### 1.3 Cibles
| Cible | Description |
|---|---|
| Joueur | 18-55 ans, urbain, smartphone, joue 1 à 4 fois/semaine |
| Club / Propriétaire | Complexes sportifs disposant de 1 à 10+ terrains de padel |
| Admin | Équipe interne de la plateforme (support, finance, modération) |

### 1.4 Périmètre technique (validé)
- **Mobile :** Flutter (un codebase iOS + Android)
- **Backend :** Node.js / NestJS + PostgreSQL + Redis
- **Langues :** Français (V1), Arabe et Anglais (V2)
- **Devise :** MAD
- **Paiement :** CMI (cartes marocaines) + paiement sur place

---

## 2. Les 3 rôles et leurs parcours

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────┐
│   JOUEUR    │    │  PROPRIÉTAIRE    │    │    ADMIN    │
│  (app mobile)│    │ (app mobile +    │    │ (dashboard  │
│             │    │  dashboard web)  │    │    web)     │
└─────────────┘    └──────────────────┘    └─────────────┘
```

- **Joueur** : utilise l'app mobile.
- **Propriétaire** : utilise l'app mobile (mode "club") et idéalement un dashboard web pour la gestion du planning sur grand écran (V1.1).
- **Admin** : dashboard web uniquement.

---

## 3. Spécifications fonctionnelles

### 3.1 Module Authentification & Sessions (AUTH)

| ID | Fonctionnalité | Description | Priorité |
|---|---|---|---|
| AUTH-01 | Inscription joueur | Email + mot de passe OU numéro de téléphone (+212) avec OTP SMS | Must |
| AUTH-02 | Connexion sociale | Google Sign-In, Apple Sign-In (obligatoire pour publication iOS) | Must |
| AUTH-03 | Vérification OTP | Code SMS 6 chiffres, validité 5 min, max 3 tentatives, renvoi après 60 s | Must |
| AUTH-04 | Connexion | Email/téléphone + mot de passe ; retour JWT access token (15 min) + refresh token (30 j) | Must |
| AUTH-05 | Mot de passe oublié | Lien email OU code OTP SMS pour réinitialisation | Must |
| AUTH-06 | Gestion de session | Refresh token rotatif, déconnexion, déconnexion de tous les appareils | Must |
| AUTH-07 | Inscription propriétaire | Formulaire dédié : infos club, documents (registre de commerce), **soumis à validation admin** | Must |
| AUTH-08 | Rôles & permissions | RBAC : `player`, `owner`, `admin` — un compte peut être joueur ET propriétaire | Must |
| AUTH-09 | Suppression de compte | Suppression/anonymisation des données (exigence stores + loi 09-08) | Must |
| AUTH-10 | Biométrie | Déverrouillage Face ID / empreinte | Could (V2) |

**Règles de gestion :**
- Un propriétaire ne peut publier son club qu'après validation par l'admin (AUTH-07 → ADM-02).
- Blocage du compte après 5 échecs de connexion consécutifs (déblocage par OTP).
- Les tokens sont stockés dans le stockage sécurisé du téléphone (Keychain / Keystore).

### 3.2 Module Profil Joueur (PLY)

| ID | Fonctionnalité | Description | Priorité |
|---|---|---|---|
| PLY-01 | Profil | Photo, nom, ville, âge, sexe, main (droitier/gaucher), position préférée (gauche/droite du terrain) | Must |
| PLY-02 | Niveau initial | Auto-évaluation guidée par questionnaire → niveau de 1.0 à 7.0 (échelle type Playtomic) | Must |
| PLY-03 | Niveau calculé | Le niveau évolue automatiquement selon les résultats des matchs (algorithme type ELO) | Should |
| PLY-04 | Disponibilités | Créneaux récurrents préférés (ex. mardi soir, samedi matin) | Must |
| PLY-05 | Statistiques | Matchs joués, victoires/défaites, évolution du niveau, clubs fréquentés | Should |
| PLY-06 | Notation | Après chaque match, notation des partenaires : ponctualité, fair-play, niveau réel | Should |
| PLY-07 | Amis / Suivis | Ajouter des joueurs en favoris, inviter directement | Should |
| PLY-08 | Signalement | Signaler un joueur (absence, comportement) → traité par admin | Must |

### 3.3 Module Matching (MTC)

| ID | Fonctionnalité | Description | Priorité |
|---|---|---|---|
| MTC-01 | Créer un match ouvert | Un joueur crée un match : club, date/heure, niveau min-max accepté, places ouvertes (1 à 3), coût partagé | Must |
| MTC-02 | Rechercher un match | Liste + carte des matchs ouverts filtrés par : date, ville/rayon, niveau compatible, prix | Must |
| MTC-03 | Rejoindre un match | Demande à rejoindre → acceptation automatique (si niveau compatible) ou manuelle par le créateur | Must |
| MTC-04 | Suggestions | L'app propose des matchs/joueurs pertinents : score = compatibilité de niveau + distance + disponibilités communes + historique | Should |
| MTC-05 | Match complet → réservation | Quand les 4 joueurs sont confirmés, le créneau est réservé et le paiement partagé est déclenché | Must |
| MTC-06 | Chat de match | Conversation de groupe entre les 4 joueurs du match | Must |
| MTC-07 | Désistement | Un joueur peut se retirer jusqu'à X h avant ; sa place est remise en ligne, notification aux joueurs proches | Must |
| MTC-08 | Saisie du score | Après le match, saisie du score par un joueur + confirmation par un adversaire → met à jour les niveaux | Should |
| MTC-09 | Matchs privés | Match entre amis uniquement (non visible publiquement) | Should |
| MTC-10 | Tournois | Création et gestion de tournois par les clubs | Won't (V2) |

**Règles de gestion :**
- Compatibilité de niveau par défaut : ± 0.5 autour du niveau du créateur (modifiable).
- Un match ouvert non complété 2 h avant l'heure est annulé (ou maintenu si le créateur confirme en payant la part restante).
- Le désistement à moins de 12 h sans remplaçant peut entraîner le débit de la part du joueur (paramétrable).

### 3.4 Module Réservation (BKG)

| ID | Fonctionnalité | Description | Priorité |
|---|---|---|---|
| BKG-01 | Recherche de clubs | Carte (Google Maps) + liste, filtres : ville, distance, prix, indoor/outdoor, note, disponibilité | Must |
| BKG-02 | Fiche club | Photos, terrains, tarifs, horaires, équipements (vestiaires, parking, cafétéria), avis, localisation | Must |
| BKG-03 | Disponibilités temps réel | Grille des créneaux (60/90/120 min) par terrain et par jour | Must |
| BKG-04 | Réservation | Sélection créneau → verrouillage temporaire (10 min) → paiement → confirmation | Must |
| BKG-05 | Paiement en ligne | CMI (carte bancaire marocaine) ; paiement total ou **partagé entre les 4 joueurs** | Must |
| BKG-06 | Paiement sur place | Option "payer au club" (si le club l'autorise) — la réservation reste confirmée | Must |
| BKG-07 | Confirmation | Notification + email + **QR code** à présenter au club | Must |
| BKG-08 | Annulation | Selon la politique du club (ex. gratuite > 24 h, 50 % entre 24 h et 6 h, 100 % < 6 h) ; remboursement automatique | Must |
| BKG-09 | Mes réservations | Historique, réservations à venir, re-réserver en 1 clic | Must |
| BKG-10 | Avis club | Note (1-5) + commentaire après une réservation honorée uniquement | Should |
| BKG-11 | Liste d'attente | S'inscrire sur un créneau complet, notification si libération | Could (V2) |

**Règles de gestion :**
- **Anti-double réservation** : un créneau ne peut jamais être vendu deux fois (contrainte base de données + verrou Redis pendant le tunnel de paiement).
- Le paiement partagé : le créateur paie sa part à la création ; les autres paient en rejoignant ; si le match n'est pas complet, remboursement automatique.
- Commission plateforme prélevée sur chaque réservation payée en ligne (voir business model).

### 3.5 Module Propriétaire / Club (OWN)

| ID | Fonctionnalité | Description | Priorité |
|---|---|---|---|
| OWN-01 | Profil club | Nom, description, photos, adresse (géolocalisée), horaires d'ouverture, équipements, politique d'annulation | Must |
| OWN-02 | Gestion des terrains | CRUD terrains : nom, type (indoor/outdoor, panoramique), photos, durées de créneaux acceptées | Must |
| OWN-03 | Tarification | Prix par terrain, par durée, par plage horaire (heures pleines/creuses), tarifs week-end | Must |
| OWN-04 | Calendrier | Vue jour/semaine de toutes les réservations, code couleur (app / manuelle / bloquée) | Must |
| OWN-05 | Blocage de créneaux | Bloquer des créneaux (maintenance, cours, événement privé) | Must |
| OWN-06 | Réservation manuelle | Enregistrer une réservation prise par téléphone/WhatsApp (client hors app) pour garder le planning juste | Must |
| OWN-07 | Check-in | Scanner le QR code du joueur à l'arrivée | Should |
| OWN-08 | Statistiques | Taux d'occupation, revenus (jour/semaine/mois), heures les plus demandées, clients récurrents | Should |
| OWN-09 | Reversements | Suivi des paiements en ligne collectés par la plateforme et des reversements (payouts) après commission | Must |
| OWN-10 | Promotions | Créer des réductions sur heures creuses | Could (V2) |
| OWN-11 | Multi-utilisateurs | Comptes "staff" avec permissions limitées (réception) | Could (V2) |

### 3.6 Module Admin & Monitoring (ADM)

| ID | Fonctionnalité | Description | Priorité |
|---|---|---|---|
| ADM-01 | Dashboard KPIs | Utilisateurs actifs (DAU/MAU), inscriptions, réservations/jour, GMV, revenus de commission, taux d'annulation | Must |
| ADM-02 | Validation des clubs | File d'attente des demandes propriétaires : vérification documents → approuver/refuser avec motif | Must |
| ADM-03 | Gestion utilisateurs | Recherche, consultation, suspension temporaire, bannissement, réinitialisation | Must |
| ADM-04 | Modération | Traitement des signalements (joueurs, avis, clubs) avec actions et historique | Must |
| ADM-05 | Gestion financière | Vue des transactions, commissions, remboursements, déclenchement/suivi des reversements clubs | Must |
| ADM-06 | Paramètres plateforme | Taux de commission (global et par club), délais d'annulation par défaut, textes légaux | Must |
| ADM-07 | Notifications push globales | Envoyer des campagnes push ciblées (ville, niveau, inactifs…) | Should |
| ADM-08 | Monitoring technique | Santé de l'API (uptime, latence, erreurs), alertes (Sentry/Grafana), logs d'audit des actions admin | Must |
| ADM-09 | Rôles admin | Super-admin, support, finance (permissions distinctes) | Should |
| ADM-10 | Export | Export CSV/Excel des données (transactions, utilisateurs) | Should |

### 3.7 Module Notifications (NTF)

| ID | Fonctionnalité | Canal | Priorité |
|---|---|---|---|
| NTF-01 | Confirmation/annulation de réservation | Push + email | Must |
| NTF-02 | Match : joueur rejoint / se désiste / match complet | Push | Must |
| NTF-03 | Rappel de match (24 h et 2 h avant) | Push | Must |
| NTF-04 | Nouveau message de chat | Push | Must |
| NTF-05 | Suggestions de matchs compatibles | Push | Should |
| NTF-06 | Demande de saisie de score / notation | Push | Should |
| NTF-07 | Préférences de notification | Réglages par catégorie dans l'app | Must |

---

## 4. Exigences non fonctionnelles

| Catégorie | Exigence |
|---|---|
| **Performance** | Temps de réponse API < 300 ms (p95) ; affichage des disponibilités < 1 s ; app fluide 60 fps |
| **Disponibilité** | 99,5 % minimum ; les réservations sont la fonction critique |
| **Sécurité** | HTTPS partout, JWT signés, mots de passe hashés (bcrypt/argon2), rate limiting, aucune donnée carte stockée (redirection CMI), protection OWASP Top 10 |
| **Conformité** | Loi marocaine 09-08 (protection des données personnelles, déclaration CNDP) ; RGPD si extension Europe ; CGU/CGV et politique de confidentialité |
| **Scalabilité** | Architecture prête pour 100 000 utilisateurs et 500 clubs sans refonte |
| **Compatibilité** | iOS 14+, Android 8+ (API 26) ; support des petits écrans |
| **Langues** | FR au lancement ; architecture i18n prête pour AR (RTL) et EN |
| **Offline** | Consultation des réservations confirmées hors ligne (cache local) |
| **Accessibilité** | Tailles de police dynamiques, contrastes suffisants |

---

## 5. User stories principales (extraits)

**Joueur**
- En tant que joueur, je veux trouver un match ouvert à mon niveau près de chez moi ce soir, afin de jouer sans devoir organiser moi-même.
- En tant que joueur, je veux payer uniquement ma part (1/4) du terrain, afin de ne pas avancer l'argent des autres.
- En tant que joueur, je veux voir les disponibilités réelles des clubs, afin de réserver sans téléphoner.

**Propriétaire**
- En tant que propriétaire, je veux que mon planning app et mes réservations téléphoniques soient dans un seul calendrier, afin d'éviter les doubles réservations.
- En tant que propriétaire, je veux voir mon taux d'occupation et mes revenus, afin de piloter mon activité.

**Admin**
- En tant qu'admin, je veux valider les clubs avant leur publication, afin de garantir la qualité de l'offre.
- En tant qu'admin, je veux suivre GMV et commissions en temps réel, afin de piloter le business.

---

## 6. Périmètre MVP vs versions suivantes

| Version | Contenu |
|---|---|
| **MVP (V1)** | AUTH complet, profils joueurs, recherche clubs + réservation + paiement CMI/sur place, matchs ouverts + rejoindre + chat, calendrier propriétaire + réservations manuelles, admin : validation clubs + dashboard basique + gestion utilisateurs |
| **V1.1** | Niveau ELO auto, notation joueurs, statistiques clubs, dashboard web propriétaire, campagnes push admin |
| **V2** | Arabe/Anglais, tournois, promotions, liste d'attente, abonnement premium joueur, multi-staff club, biométrie |

Détail complet dans [05-roadmap-mvp.md](05-roadmap-mvp.md).

---

## 7. Documents liés

- [02-architecture-technique.md](02-architecture-technique.md) — architecture, base de données, algorithme de matching
- [03-business-model.md](03-business-model.md) — sources de revenus, tarifs, coûts
- [04-apis-integrations.md](04-apis-integrations.md) — API externes + conception de l'API interne
- [05-roadmap-mvp.md](05-roadmap-mvp.md) — phases et planning
