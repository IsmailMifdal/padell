# Business Model — Application Padel (Maroc)

**Version :** 1.0 · Documents liés : [cahier des charges](01-cahier-des-charges.md) · [roadmap](05-roadmap-mvp.md)

---

## 1. Le marché du padel au Maroc

- Le padel est le sport à la plus forte croissance au Maroc : les clubs se multiplient à Casablanca, Rabat, Marrakech, Tanger, Agadir depuis 2021.
- Prix moyen d'une location : **250 à 450 MAD / 90 min** selon la ville, le club et l'horaire (soit ~60-110 MAD par joueur).
- La réservation se fait aujourd'hui essentiellement par **téléphone ou WhatsApp** → friction forte, pas de visibilité sur les disponibilités, doubles réservations fréquentes.
- Problème n°1 des joueurs : **trouver un 4e joueur** de niveau compatible. C'est exactement ce qu'a résolu Playtomic en Europe (leader mondial, valorisé > 1 Md $) — le modèle est prouvé, le marché marocain est encore peu équipé.
- Hypothèse de départ (à valider en phase pilote) : une ville comme Casablanca compte plusieurs dizaines de clubs et des milliers de joueurs réguliers.

**Positionnement :** « Le Playtomic marocain » — adapté aux moyens de paiement locaux (CMI, paiement sur place), en français puis arabe, avec un accompagnement terrain des clubs.

---

## 2. Sources de revenus

### 2.1 Vue d'ensemble

| # | Source | Description | Quand |
|---|---|---|---|
| 1 | **Commission sur réservation** | % prélevé sur chaque réservation payée en ligne | MVP |
| 2 | **Abonnement club (SaaS)** | Forfait mensuel pour l'outil de gestion du club | MVP ou V1.1 |
| 3 | **Abonnement joueur Premium** | Fonctionnalités avancées pour les joueurs | V2 |
| 4 | **Publicité & partenariats** | Marques d'équipement (raquettes, textile), boissons | V2 |
| 5 | **Événements & tournois** | Commission sur les inscriptions aux tournois | V2 |

### 2.2 Détail

**1. Commission sur réservation (revenu principal)**
- **10 %** du montant de chaque réservation payée en ligne (négociable 8-15 % selon le volume du club).
- Exemple : terrain à 300 MAD → 30 MAD de commission, 270 MAD reversés au club.
- Paiement sur place : pas de commission au MVP (levier d'adoption), ou frais fixe de mise en relation (5 MAD) en V1.1.
- Reversements aux clubs : hebdomadaires ou bimensuels par virement.

**2. Abonnement club (SaaS)**

| Formule | Prix indicatif | Contenu |
|---|---|---|
| **Gratuit** | 0 MAD | Fiche club, réservations via l'app (avec commission), calendrier de base |
| **Pro** | 400-600 MAD/mois | Réservations manuelles illimitées, statistiques avancées, promotions, dashboard web, support prioritaire |
| **Pro+** | 900-1200 MAD/mois | Multi-staff, commission réduite (-2 pts), tournois, mise en avant dans la recherche |

> Stratégie de lancement : **Pro gratuit 3 mois** pour les clubs pilotes afin de construire l'offre de terrains (le contenu de l'app), puis conversion.

**3. Abonnement joueur Premium (V2)** — 30-50 MAD/mois
- Réservation prioritaire / accès anticipé aux créneaux premium
- Statistiques avancées et évolution détaillée du niveau
- Annulation flexible étendue
- Badge premium, pas de publicité

**4. Publicité & partenariats (V2)** — bannières marques d'équipement, offres sur balles/raquettes, sponsoring de classements mensuels.

**5. Tournois (V2)** — 10 % de commission sur les frais d'inscription des tournois organisés par les clubs via l'app.

---

## 3. Modèle économique cible (unit economics)

Hypothèses prudentes de la ville pilote (Casablanca), à horizon 12 mois :

| Indicateur | Hypothèse |
|---|---|
| Clubs actifs | 25 |
| Terrains moyens/club | 4 |
| Réservations via app / club / jour | 6 (sur ~25 créneaux/jour) |
| Panier moyen | 300 MAD |
| Part payée en ligne | 50 % |

**Calcul mensuel :**
- Réservations en ligne : 25 clubs × 6 résas × 30 j × 50 % = **2 250 réservations**
- GMV en ligne : 2 250 × 300 = **675 000 MAD**
- Commission 10 % = **67 500 MAD/mois**
- Abonnements Pro : 10 clubs × 500 = **5 000 MAD/mois**
- **Revenu total ≈ 72 500 MAD/mois** à M12 dans une seule ville

---

## 4. Structure de coûts

### 4.1 Coûts de lancement (one-shot)

| Poste | Estimation |
|---|---|
| Développement MVP (3-4 mois, voir [roadmap](05-roadmap-mvp.md)) | Variable : ~0 si développé soi-même ; 150 000-400 000 MAD si équipe/agence |
| Identité visuelle + UI kit | 5 000-15 000 MAD |
| Création société + juridique (CGU, CGV, CNDP loi 09-08) | 10 000-20 000 MAD |
| Comptes stores (Google 25 $ + Apple 99 $/an) | ~1 300 MAD |
| Dossier CMI (e-commerce) | frais d'installation selon banque |

### 4.2 Coûts récurrents mensuels (MVP)

| Poste | Estimation/mois |
|---|---|
| Hébergement VPS (API + DB + Redis) | 200-400 MAD |
| Stockage S3/Cloudinary + emails (Brevo) | 100-200 MAD |
| SMS OTP (~0,3-0,5 MAD/SMS × volume) | 500-2 000 MAD |
| Google Maps API (au-delà du crédit gratuit 200 $/mois) | 0-1 000 MAD |
| Frais CMI (~1,5-2,5 % par transaction + frais fixes) | proportionnel au GMV |
| Sentry, outils, domaine | 200 MAD |
| Marketing digital (Instagram/TikTok padel, influenceurs locaux) | 5 000-20 000 MAD (variable) |
| Commercial terrain (démarchage clubs) | selon équipe |

**Point mort estimé :** ~10-12 clubs actifs avec paiement en ligne couvrent l'infrastructure et le marketing de base.

---

## 5. Stratégie de lancement

### Phase 1 — Ville pilote (M1-M6) : Casablanca
1. **Avant le lancement public** : signer 8-12 clubs partenaires (offre : Pro gratuit 3 mois + 0 % de commission le 1er mois). Sans offre de terrains, l'app est vide — les clubs d'abord.
2. Onboarding terrain : photos professionnelles des clubs, paramétrage des tarifs, formation du staff (15 min).
3. Lancement joueurs : communauté Instagram/TikTok padel, affiches + QR codes dans les clubs partenaires, parrainage (1 réservation offerte).
4. Objectif M6 : 15 clubs, 3 000 joueurs inscrits, 1 000 réservations/mois.

### Phase 2 — Consolidation (M6-M12)
- Activation du matching comme différenciateur n°1 (vs réservation simple).
- Conversion des clubs gratuits → Pro. Ajustement de la commission.
- Extension : Rabat, Marrakech.

### Phase 3 — Échelle (M12+)
- Toutes les grandes villes, version arabe, premium joueur, tournois.
- Levée de fonds éventuelle sur la base des métriques (GMV, rétention).

---

## 6. KPIs à suivre (dashboard admin — ADM-01)

| Catégorie | KPIs |
|---|---|
| Acquisition | Inscriptions/semaine, coût d'acquisition, taux de parrainage |
| Activation | % joueurs avec 1re réservation < 7 j, % profils complétés |
| Rétention | MAU/DAU, % joueurs actifs à M+1/M+3, fréquence de jeu |
| Revenus | GMV, commission, % paiement en ligne vs sur place, MRR abonnements |
| Offre | Clubs actifs, taux d'occupation moyen, délai de validation club |
| Matching | % de matchs ouverts complétés, délai moyen pour trouver un 4e joueur |
| Qualité | Taux d'annulation, taux de no-show, note moyenne clubs, signalements |

---

## 7. Risques & parades

| Risque | Parade |
|---|---|
| Les clubs contournent l'app (prennent le client en direct) | Valeur au-delà de la résa : gestion du planning complet (y c. manuel), stats, nouveaux clients apportés ; commission raisonnable |
| Faible adoption du paiement en ligne | Option paiement sur place dès le MVP ; le paiement partagé 4 joueurs incite au paiement en ligne |
| Concurrent international (Playtomic) entre au Maroc | Vitesse d'exécution, relation terrain avec les clubs, paiement local, prix adaptés |
| Volume SMS OTP coûteux | Privilégier login Google/Apple, OTP seulement à l'inscription téléphone |
| Saisonnalité (été, Ramadan) | Promotions heures creuses, tournois, créneaux nocturnes pendant le Ramadan |
