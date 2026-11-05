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

## Feuille de route (étude : `docs/recherche/ambition.md`, ADR 0011)

> Chaque ligne se fait sur le Pad 7, mesure à l'appui. Pas de promesse « comme Mathematica » ni « comme MyScript » : voir l'étude.

### A. Moteur de calcul

- ⏳ Essayer `timeout N` et `ctrl_c` sur un calcul long (Pad 7) ; sinon Giac dans un service `:calcul`, tué au délai
- ⏳ Façade du moteur : `undef`, `infinity`, `list[...]`, guillemets de `latex()`, un seul appel à la fois, reprise de l'état
- ⏳ Banc de tests croisé avec SymPy : dérivées, primitives, limites, séries, polynômes, matrices, équations, systèmes, EDO
- ⏳ Liste publique et honnête de ce que l'app sait faire ou non ; combler les manques seulement par règles ciblées
- ❌ Écarté : SageMath, Maxima (lourds), Symbolica (licence), calcul formel sur GPU (aucune preuve d'intérêt)

### B. Encre et correction

- ⏳ Spike latence au stylet, caméra rapide sur Pad 7 : `Listener`, paquet `stylet`, `LowLatencyCanvasView` en vue native. Aucun objectif chiffré avant
- ⏳ Mesurer la perte de points (Flutter ne lit pas l'historique des `MotionEvent`)
- ⏳ Rendu du trait : filtre 1€ et `perfect_freehand`, pression ; les points bruts restent pour la reconnaissance
- ⏳ Formes au maintien du stylet : ligne, cercle, rectangle, triangle ($1 et moindres carrés), annulable
- ⏳ Gestes : rature et barré pour effacer ; ajustement des courbes au levé (Schneider, licence à vérifier ou réécriture)
- ❌ Écarté : correction automatique de l'écriture en continu (aucun des produits étudiés ne la documente, et elle gênerait la reconnaissance)

### C. Reconnaissance

- ⏳ Nouvel essai au trait fin sur d'autres expressions, pour un chiffre sans biais (37/50 est optimiste)
- ⏳ Alternatives proposées à la correction ; corriger à la main un symbole mal lu
- ⏳ Reconnaissance en continu à la pause ; rendu `flutter_math_fork` à la place ou à côté de l'écriture
- ❓ Provenance des poids Pix2Text : réponse de l'auteur (ticket n° 209) ou modèle maison sur encre synthétique et collecte CC0

### D. Visuel

- ❓ Trois supports au choix dans les réglages : feuille blanche, tableau noir, cahier
- ⏳ Choix de la couleur du stylo, gomme à portée de main
- ❓ Police de texte libre
- ⏳ Écran « Réglages » ; composants ; accessibilité (TalkBack) ; essais téléphone et tablette

### E. Graphique et géométrie

- ⏳ Traceur Dart : échantillonnage adaptatif, quadtree et marching squares, mesure du budget d'image sur le Pad 7
- ⏳ Fiabilité des implicites : intervalles façon Tupper, à comparer à `graphest` (MIT)
- ⏳ `FragmentProgram` en option pour aperçus et fonds denses, avec repli CPU ; pas de `flutter_gpu` tant qu'il est en préversion
- ⏳ Géométrie dynamique (outils de construction + formes dessinées reconnues)

### F. Publication

- ⏳ Clé de signature ; GitHub Releases signées, puis F-Droid (Giac, GMP, MPFR compilés depuis les sources)
- ⏳ Essai sur le Poco F8 Pro (rapport `0.1.0-essai.2` attendu)
