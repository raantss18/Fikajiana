# TODO — Fikajiana

> Une seule liste, tenue à jour à chaque tâche. Statuts : ✅ fait · 🔄 en cours · ⏳ à faire · ❓ décision d'Antsa.
> Une tâche n'est ✅ qu'après tests + essai sur émulateur téléphone **et** tablette (`CLAUDE.md`).

## 0. Erreurs signalées

- ✅ 2026-11-05 : « Fikajiana keeps stopping » sur téléphone (essai.1). Cause : `SMARTPTR64` de Giac tronque les étiquettes de
  pointeurs arm64. Corrigé par `correctifs/0002`. Protection : essai obligatoire sur arm64 réel, l'émulateur ne le voit pas.
- ✅ 2026-11-05 : écran d'essai `0×0 dp`, taille lue trop tôt en release, puis perdue à une réécriture. Corrigé en attendant une
  taille non nulle ; à reprendre si l'écran d'essai sert encore.
- ✅ 2026-11-05 : `tool/essai_local.sh` prenait le premier émulateur venu et a modifié `zanakiantsa_tab`. Cause corrigée :
  le script ne vise que l'AVD `fikajiana_resizable`, et `tool/essai_appareil.sh` laisse `adb` refuser s'il y a plusieurs appareils
  sans `ANDROID_SERIAL`.

## Étape 0 — Cadrage ✅

- ✅ Dépôt vidé du projet Unity ; `CLAUDE.md`, `docs/vision.md`, `LICENSE` (GPL-3.0-or-later)
- ✅ Dépôt renommé `raantss18/Fikajiana` (2026-11-05) ; PR #1 fusionnée dans `main`
- ✅ Langues : français et anglais (ADR 0007)
- ✅ Appareils : Xiaomi Pad 7 + stylet, Poco F8 Pro (ADR 0008)

## Étape 1 — Recherche et choix ✅ (à confirmer par mesure)

- ✅ `docs/recherche/ocr-manuscrit.md`, `docs/recherche/moteurs.md`
- ✅ ADR 0001 licence · 0002 Flutter · 0003 OCR (proposé) · 0004 Giac (proposé) · 0005 graphe/géométrie maison · 0006 CI + émulateur
- ✅ `docs/architecture.md`, `docs/design.md` (orientation)
- ✅ Points « extrait » revérifiés (`docs/recherche/reverification.md`), sauf Maxima
- ❓ Provenance des poids Pix2Text-MFR : pas de diffusion publique sans réponse de l'auteur ou modèle maison

## Étape 2 — Spikes de risque (avant toute interface)

- 🔄 T1 OCR (`docs/recherche/spike-ocr.md`) : 37/50 sur le Pad 7 après correction du trait (16/50 avant). Reste : nouvel essai sur d'autres expressions
- 🔄 T2 Giac (`docs/recherche/spike-giac.md`) : compilé pour arm64 + x86_64 (19,9 et 22,0 Mo), FFI réussi sur le Xiaomi Pad 7.
  Reste : essai sur le Poco F8 Pro, annulation d'un calcul long, signaler le dépassement de tampon à Giac
- ⏳ T3 Segmentation : système à accolade et matrice 2×2 découpés correctement sur 20 essais
- 🔄 Squelette `app/` + `packages/fikajiana_math/` : fr/en, thème M3 clair/sombre, navigation ← ≠ Accueil (ADR 0009) ;
  analyse et tests verts, essai sur émulateur (`docs/captures/squelette.png`), fusionné.
  Reste : essai sur appareils réels.
- 🔄 Constructions en local (`tool/essai_local.sh`, `tool/essai_appareil.sh`) et CI réduite à l'analyse et aux tests (ADR 0006).

## Étape 3 — Tranche verticale « écrire un calcul » ⏳

- ⏳ Feuille d'écriture → reconnaissance → LaTeX affiché → résultat exact Giac → valeur approchée

## Étape 4 — Élargir ⏳

- ⏳ Équations et systèmes · fonctions + graphe · dérivées, limites, intégrales, suites · polynômes · matrices
- ⏳ Géométrie dynamique (outils de construction + formes dessinées reconnues)
- 🔄 Identité : couleurs, π, icône, Nunito (ADR 0010, `docs/design.md`). Reste : composants
- 🔄 Supports au choix, stylos, gomme (ADR 0012) : essayés sur le Pad 7 au stylet simulé. Reste : vrai stylet, Poco
- ⏳ Accessibilité (TalkBack), clair/sombre, téléphone/tablette
- ⏳ Publication : GitHub Releases signées, puis F-Droid (Giac, GMP, MPFR compilés depuis les sources)
