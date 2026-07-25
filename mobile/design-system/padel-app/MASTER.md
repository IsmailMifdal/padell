# Padel App — Design System (Source de vérité)

> Généré initialement par `ui-ux-pro-max --design-system`, puis **corrigé à la
> main** : la suggestion générique de l'outil (marketplace noir+or) ne
> correspondait pas à l'identité déjà construite et validée sur ce projet.
> Ce fichier documente le système **réellement implémenté**, audité contre
> la checklist qualité du plugin (`references/pro-rules.md`).

## Palette (`lib/core/palette.dart`)

| Rôle | Valeur | Usage |
|---|---|---|
| Primary | `#0DA271` | CTA, icônes actives, accents |
| Primary dark | `#076B4B` | Texte sur fond clair, icônes foncées |
| Hero gradient | `#11B67E → #056243` | En-têtes, boutons majeurs, hero login |
| Background | `#F3F6F4` (clair) / `#0B1512` (sombre) | Fond d'écran |
| Ink (texte) | `#0B1712` | Texte principal |
| Slate (texte secondaire) | `#64716A` | Sous-titres, métadonnées |
| Danger / Amber / Info | `#E5484D` / `#F59E0B` / `#2E7DF6` | États |

**Contraste vérifié (WCAG)** : blanc sur dégradé émeraude foncé = **7.41:1**
(seuil 4.5:1) ; texte secondaire (`slate`) sur fond sombre = **3.64:1**
(seuil 3:1). Les deux passent sans modification.

## Typographie
Plus Jakarta Sans (Google Fonts), échelle resserrée : titres `w800` avec
letter-spacing négatif, corps `w400-w600`.

## Style
Dégradés de marque + cartes à ombre douce (`SoftCard`, effet d'appui au
tap) + verre dépoli sur les en-têtes (`GradientHeader`) — pas de
Liquid Glass complet (coût perf/accessibilité trop élevé pour du mobile,
cf. style catalogue "Liquid Glass" : ⚠ Moderate-Poor perf, ⚠ text contrast).

## Composants clés
- `GradientButton` — CTA majeurs, ombre colorée, état loading
- `SoftCard` — cartes avec `AnimatedScale` (0.98) au press
- `GradientHeader` — en-tête dégradé + zone intégrée (recherche/filtres)
- `SkeletonList` — chargement (effet pulse) au lieu du spinner

## Audit qualité (2026-07-19, checklist `pro-rules.md`)
- ✅ Cibles tactiles ≥44×44 : 3 violations trouvées et corrigées (cœur
  favori, cloche notifications, suppression règle tarifaire)
- ✅ Retour haptique ajouté (`core/haptics.dart`) sur les confirmations
  clés (réserver, rejoindre/accepter/refuser un match, favoris) — jamais
  sur chaque tap
- ✅ Icônes de navigation = Material Icons (pas d'emoji structurel) ;
  emojis conservés uniquement en usage décoratif (hero, avatars, états vides)
- ✅ Contraste clair/sombre vérifié (voir ci-dessus)
- ✅ `go_router` (routes déclaratives) + `Form`/`GlobalKey` déjà en place
  (conforme aux guidelines stack Flutter du plugin)

## Pages
Pas d'override par page pour l'instant — le Master s'applique partout.
