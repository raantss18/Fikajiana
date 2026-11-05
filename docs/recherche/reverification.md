# Revérification sur les pages sources (2026-11-05)

> Résumé : un risque nouveau et trois corrections. La provenance des poids de Pix2Text-MFR n'est pas publiée, ce qui
> empêche de tenir aujourd'hui la règle « aucune donnée NC dans les poids distribués ».

## Risque nouveau : provenance des poids de Pix2Text-MFR

- La fiche du modèle indique la licence MIT et un entraînement sur « a dataset of mathematical formula images », sans le nommer [1].
- L'auteur a écrit en 2024 que le modèle gratuit a été entraîné sur environ 2 M de données et que seules les versions
  payantes contiennent des images envoyées par les utilisateurs [2].
- La question précise (CROHME, UniMER-1M, im2latex-100K ?) a été posée le 2026-10-17 dans un ticket encore sans réponse [3].
- **Conséquence** : la licence MIT des poids est vérifiée, leur provenance ne l'est pas. Les mesures du spike T1 restent
  possibles, mais toute diffusion publique de ces poids attend une réponse de l'auteur ou un modèle maison (ADR 0003).

## Corrections

| Point | Noté avant | Page source |
|---|---|---|
| Licence du code de GeoGebra | GPL-3+ | **EUPL v1.2** ; installateurs et services non commerciaux, marques réservées [4] |
| F-Droid | exige la compilation depuis les sources | les bibliothèques viennent des sources ou de dépôts de confiance ; rien sur les modèles ML [5] |
| Widget Previewer de Flutter | expérimental | stable depuis Flutter 3.47 [6] |
| Pix2Text-MFR | une seule version | une version `pix2text-mfr-1.5` existe aussi, MIT, 119,5 Mo : à comparer en T1 [7] |

## Confirmé

| Point | Résultat |
|---|---|
| Pix2Text-MFR, taille | `encoder_model.onnx` 87,50 Mo + `decoder_model.onnx` 30,11 Mo = 117,6 Mo [1] |
| Dépôt Pix2Text, licence | fichier `LICENSE` MIT [8] |
| TexTeller | Apache-2.0, 298,1 M de paramètres, ONNX de 343,6 Mo + 908,7 Mo [9] |
| MathWriting | 230 k manuscrits + 400 k synthétiques [10] ; **données** CC BY-NC-SA 4.0 [11] (le CC BY 4.0 d'arXiv vise l'article) |
| MathWriting, CER de référence (test) | OCR 7,17 %, CTC Transformer 5,49 %, PaLI 5,95 % [12] |
| CROHME 2023 | CC BY-NC-SA 3.0 [13] |
| Giac | GPL3, licence commerciale possible, moteur natif de la HP Prime, choisi par GeoGebra en 2013 [14] |
| Licences compatibles GPLv3 | Apache-2.0, Expat, BSD modifiée, LGPL v3 ; NonCommercial non libre [15] |
| PariDroid | GPLv3+, sur F-Droid [16] (la page ne parle que de PariDroid, pas de PARI/GP en GPL-2+) |

## Vérifié / Supposé / Reste à tester

- **Vérifié** : tous les points des tableaux, sur les pages citées, par l'API Hugging Face ou par l'API GitHub.
- **Supposé** : les poids gratuits ne contiennent pas de données NC. Rien ne le prouve ni ne l'infirme.
- **Reste à vérifier** : Maxima sur Android [17][18], non rouvert ; réponse au ticket [3].

## Sources

[1] https://huggingface.co/breezedeus/pix2text-mfr [2] https://github.com/breezedeus/Pix2Text/issues/89
[3] https://github.com/breezedeus/Pix2Text/issues/209 [4] https://www.geogebra.org/license
[5] https://f-droid.org/docs/Inclusion_Policy/ [6] https://docs.flutter.dev/tools/widget-previewer
[7] https://huggingface.co/breezedeus/pix2text-mfr-1.5 [8] https://github.com/breezedeus/Pix2Text/blob/main/LICENSE
[9] https://huggingface.co/OleehyO/TexTeller [10] https://arxiv.org/abs/2404.10690
[11] https://github.com/google-research/google-research/tree/master/mathwriting [12] https://arxiv.org/html/2404.10690v2
[13] https://zenodo.org/records/8428035 [14] https://xcas.univ-grenoble-alpes.fr/en.html
[15] https://www.gnu.org/licenses/license-list.html [16] https://pari.math.u-bordeaux.fr/paridroid/
[17] https://github.com/YasuakiHonda/Maxima-on-Android-AS [18] https://sourceforge.net/projects/maxima-on-android/
