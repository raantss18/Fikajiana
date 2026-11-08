# Sources des données d'entraînement

Vérifié le 2026-11-08. Chaque source dit sa licence, d'où elle vient et si elle sert.

## Polices manuscrites (utilisées)

Téléchargées par `bash entrainement/recuperer_polices.sh` dans `entrainement/polices/` (hors Git),
depuis https://github.com/google/fonts au commit `86aced91de05cd4f96a06838124cca45be337b2b`,
avec le fichier `OFL.txt` de chacune ; empreintes SHA-256 dans `entrainement/polices.sha256`.
Licence de toutes : **SIL Open Font License 1.1** (https://openfontlicense.org/). L'OFL permet
d'utiliser la police pour produire des images ; les poids du modèle ne contiennent ni la police ni
ses contours, seulement ce qu'un réseau a appris d'images rendues avec elle.

| Police | Dossier google/fonts | Copyright (d'après `OFL.txt`) | Couvre |
|---|---|---|---|
| Caveat | `ofl/caveat` | 2014 The Caveat Project Authors (https://github.com/googlefonts/caveat) | latin, `≤ ≥ ≈ ± μ` |
| Patrick Hand | `ofl/patrickhand` | 2010-2012 Patrick Wagesreiter | latin, `π λ μ √ ∫ ∞` ; **police de test, jamais vue à l'entraînement** |
| Kalam | `ofl/kalam` | 2014 Indian Type Foundry | latin, `π √ ∫ ∞` |
| Klee One | `ofl/kleeone` | 2020 The Klee Project Authors (https://github.com/fontworks-fonts/Klee) | latin, grec, `∫ ∞ → ⇒ ⇔ ∈ Σ √` |
| Yomogi | `ofl/yomogi` | 2020 The Yomogi Project Authors (https://github.com/satsuyako/YomogiFont) | latin, grec, flèches et symboles |
| Zen Kurenaido | `ofl/zenkurenaido` | 2021 The Zen Kurenaido Project Authors (https://github.com/googlefonts/zen-kurenaido) | latin, grec, flèches et symboles |

Chaque classe de `collecte/classes.txt` est couverte par au moins trois de ces polices
(détail dans `sortie/rapport.md`, section « Couverture des polices »).

## Écriture réelle (utilisée)

- **Séances de collecte** (`donnees/ecriture/<personne>/*.json`, format `collecte/FORMAT.md`) :
  CC0 1.0 (choix d'Antsa, 2026-11-07, ADR 0038). Hors Git tant qu'Antsa ne les publie pas.
- **Fixtures de l'app** (`app/test/fixtures/pad7`, `app/test/fixtures/telephone`) : traits d'Antsa
  déjà dans le dépôt (GPL-3.0-or-later avec le reste du code). Signes isolés relevés à la main dans
  `entrainement/fixtures_signes.json` ; l'écriture liée est laissée de côté.

## Corpus écartés

| Corpus | Licence | Pourquoi écarté |
|---|---|---|
| MNIST | CC BY-SA 3.0 (d'après ADR 0038 ; la page d'origine http://yann.lecun.com/exdb/mnist/ n'a pas pu être relue, non vérifié) | Creative Commons : « no non-CC licenses have been designated as compatible with BY-SA 3.0 » ; seul BY-SA 4.0 l'est avec la GPLv3 (https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses). Des poids entraînés dessus ne pourraient pas, prudemment, être publiés sous GPL. |
| HASYv2 | ODbL 1.0 (https://zenodo.org/records/259444) | Des poids seraient au mieux une « Produced Work » (ODbL § 4.3, https://opendatacommons.org/licenses/odbl/1-0/), publiable avec une mention ; mais la provenance et le consentement des écritures d'origine ne sont pas décrits sur la page du jeu ni sur celle de l'article (https://arxiv.org/abs/1701.08380) : non vérifié, donc écarté pour l'instant. |
| MathWriting, CROHME | non commerciales | Refusées par l'ADR 0038. |
