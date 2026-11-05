# TODO — Fikajiana

> Une seule liste, tenue à jour à chaque tâche. Statuts : ✅ fait · 🔄 en cours · ⏳ à faire · ❓ décision d'Antsa.
> Une tâche n'est ✅ qu'après tests + essai sur émulateur téléphone **et** tablette (`CLAUDE.md`).

## 0. Erreurs signalées

Aucune pour l'instant.

## Étape 0 — Cadrage ✅

- ✅ Dépôt vidé du projet Unity ; `CLAUDE.md`, `docs/vision.md`, `LICENSE` (GPL-3.0-or-later)
- ✅ Dépôt renommé `raantss18/Fikajiana` (2026-11-05) ; PR #1 fusionnée dans `main`
- ✅ Langues : français et anglais (ADR 0007)
- ✅ Appareils : Xiaomi Pad 7 + stylet, Poco F8 Pro (ADR 0008)

## Étape 1 — Recherche et choix ✅ (à confirmer par mesure)

- ✅ `docs/recherche/ocr-manuscrit.md`, `docs/recherche/moteurs.md`
- ✅ ADR 0001 licence · 0002 Flutter · 0003 OCR (proposé) · 0004 Giac (proposé) · 0005 graphe/géométrie maison · 0006 CI + émulateur
- ✅ `docs/architecture.md`, `docs/design.md` (orientation)
- ⏳ Revérifier les points « extrait » quand huggingface.co / arxiv.org / gnu.org sont accessibles

## Étape 2 — Spikes de risque (avant toute interface)

- ⏳ T1 OCR : Pix2Text-MFR ONNX int8 sur 50 expressions manuscrites maison (taux exact, latence, mémoire, Mo)
- ⏳ T2 Giac : compilation NDK arm64 + x86_64, appel FFI `diff(sin(x)^2,x)` → LaTeX ; taille de la .so
- ⏳ T3 Segmentation : système à accolade et matrice 2×2 découpés correctement sur 20 essais
- 🔄 Squelette `app/` + `packages/fikajiana_math/` : fr/en, thème M3 clair/sombre, navigation ← ≠ Accueil (ADR 0009) ;
  analyse et tests verts, essai sur émulateur (`docs/captures/squelette.png`). PR ouverte, à valider par Antsa.
  Reste : essai sur appareils réels (non branchés), icône d'application propre (celle du gabarit est encore là).
- 🔄 CI GitHub Actions (`.github/workflows/ci.yml`, `tool/essai_emulateur.sh`) : analyse, tests, APK release arm64 +
  x86_64, émulateurs téléphone et tablette, captures en artefact. Script essayé en local ; exécution verte sur GitHub à obtenir.

## Étape 3 — Tranche verticale « écrire un calcul » ⏳

- ⏳ Feuille d'écriture → reconnaissance → LaTeX affiché → résultat exact Giac → valeur approchée

## Étape 4 — Élargir ⏳

- ⏳ Équations et systèmes · fonctions + graphe · dérivées, limites, intégrales, suites · polynômes · matrices
- ⏳ Géométrie dynamique (outils de construction + formes dessinées reconnues)
- ⏳ Design system complet, accessibilité (TalkBack), clair/sombre, téléphone/tablette
- ⏳ Publication : GitHub Releases signées, puis F-Droid (Giac, GMP, MPFR compilés depuis les sources)
