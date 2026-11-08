# Licences des dépendances

| Composant | Licence | Usage | Source |
|---|---|---|---|
| Flutter SDK (dont `flutter_localizations`) | BSD-3-Clause | application | https://github.com/flutter/flutter/blob/stable/LICENSE |
| `flutter_onnxruntime` 1.9 | MIT | exécution ONNX | https://pub.dev/packages/flutter_onnxruntime/license |
| ONNX Runtime 1.28 (Android) | MIT (non revérifié) | exécution ONNX | https://github.com/microsoft/onnxruntime |
| `flutter_math_fork` | Apache-2.0 | rendu LaTeX | https://pub.dev/packages/flutter_math_fork/license |
| `path_provider` | BSD-3-Clause | dossier de l'app | https://pub.dev/packages/path_provider/license |
| `shared_preferences` | BSD-3-Clause | réglages sur l'appareil | https://pub.dev/packages/shared_preferences/license |
| Nunito | SIL OFL 1.1 (`app/assets/polices/OFL-Nunito.txt`) | police de texte | https://github.com/googlefonts/nunito |
| Caveat (contours aplatis dans `app/lib/comprendre/glyphes_caveat.dart`) | SIL OFL 1.1 (`app/assets/polices/OFL-Caveat.txt`) | écriture des résultats | https://github.com/google/fonts/tree/main/ofl/caveat |
| `perfect_freehand` | MIT | rendu du trait | https://pub.dev/packages/perfect_freehand/license |
| `intl` | BSD-3-Clause | formats et traductions | https://pub.dev/packages/intl/license |
| `ffi` | BSD-3-Clause | appel de Giac | https://pub.dev/packages/ffi/license |
| Giac (en-têtes GPL v3 ou ultérieure, licence globale à confirmer) | GPL-3.0-or-later | calcul formel, compilé depuis les sources | https://github.com/geogebra/giac |
| GMP 6.3.0 | LGPL-3.0-or-later ou GPL-2.0-or-later (non revérifié) | grands nombres | https://gmplib.org/ |
| MPFR 4.2.1 | LGPL-3.0-or-later (non revérifié) | flottants | https://www.mpfr.org/ |
| `very_good_analysis`, `test`, `flutter_test` | MIT, BSD-3-Clause | développement seulement, non distribués | https://pub.dev/packages/very_good_analysis/license · https://pub.dev/packages/test/license |

Le code initial de `app/` et `packages/fikajiana_math/` provient des gabarits de Very Good CLI
(https://github.com/VeryGoodOpenSource/very_good_cli). Leur licence n'a pas été vérifiée : à confirmer.

## Entraînement du modèle de signes (`entrainement/`, hors application)

Outils sur l'ordinateur, non distribués avec l'app ; seuls les poids produits (`signes.onnx`) le seraient.

| Composant | Licence | Usage | Source |
|---|---|---|---|
| PyTorch (CPU) | BSD-3-Clause | entraînement | https://github.com/pytorch/pytorch/blob/main/LICENSE |
| ONNX, ONNX Runtime (Python) | Apache-2.0, MIT | export, vérification | https://github.com/onnx/onnx · https://github.com/microsoft/onnxruntime |
| NumPy, Pillow, scikit-image, fontTools | BSD-3-Clause, MIT-CMU, BSD-3-Clause, MIT | rendu et squelette | https://numpy.org/doc/stable/license.html · https://github.com/python-pillow/Pillow/blob/main/LICENSE · https://github.com/scikit-image/scikit-image/blob/main/LICENSE.txt · https://github.com/fonttools/fonttools/blob/main/LICENSE |
| Polices Caveat, Patrick Hand, Kalam, Klee One, Yomogi, Zen Kurenaido | SIL OFL 1.1 | signes synthétiques (images rendues, polices non distribuées) | `entrainement/SOURCES.md` |
| MNIST, HASYv2 | CC BY-SA 3.0, ODbL 1.0 | **non utilisés** (voir `entrainement/SOURCES.md`) | — |

## Plateforme des dons (`plateforme/`, côté serveur, hors application)

Installés sur le serveur qui reçoit les dons (ADR 0042) ; rien n'est copié dans le dépôt ni dans l'app.

| Composant | Licence | Usage | Source |
|---|---|---|---|
| Waitress | ZPL 2.1 | serveur HTTP (WSGI) | https://pypi.org/project/waitress/ |
| boto3 (facultatif) | Apache-2.0 | stockage compatible S3 | https://github.com/boto/boto3/blob/develop/LICENSE |
| Caddy (image `caddy:2.10`) | Apache-2.0 | HTTPS devant le récepteur | https://github.com/caddyserver/caddy/blob/master/LICENSE |
