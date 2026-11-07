# Un meilleur modèle pour le manuscrit ? (2026-11-07)

Résumé : le prétraitement est conforme, et aucun modèle libre aux poids de provenance claire ne bat nettement l'actuel. Le levier le moins cher est de lire plusieurs hypothèses (beam search) et de choisir par plausibilité et par contexte de la feuille.

## Prétraitement mesuré

50 expressions du spike, modèle int8, sur PC, score automatique. Sur 50 lignes, 36 justes donne 58–83 % (Wilson 95 %) : ces écarts sont fragiles.

| Rendu | Justes /50 |
|---|---|
| Actuel (étiré, trait 1/70) | 36 |
| Carré complété, 1/70 | 29 |
| Trait constant étiré 1 / 2 / 3 / 4 / 5 px | 17 / 31 / 35 / 35 / 28 |
| Trait constant carré 3 px | 37 |
| Vote sur 4 rendus | 38 |
| Beam 5 : vérité dans le top 1 / 3 / 5 | 36 / 41 / 43 (45 après relecture) |

Le code suit `preprocessor_config` (384×384, normalisation 0,5) : https://huggingface.co/breezedeus/pix2text-mfr-1.5/raw/main/preprocessor_config.json . Le décodage est glouton et sans cache ; la pression et l'ordre des traits sont ignorés.

## Candidats

| Modèle | Licence code / poids | Données | Score manuscrit publié | Taille | Source |
|---|---|---|---|---|---|
| Pix2Text-MFR (actuel) | MIT / MIT | non publiées | non publié | 117,6 Mo, int8 33 Mo | https://huggingface.co/breezedeus/pix2text-mfr |
| TexTeller | Apache / Apache affiché | sources non nommées | non publié | 1,25 Go | https://huggingface.co/OleehyO/TexTeller |
| UniMERNet-T | Apache / Apache | CROHME, HME100K cités | BLEU 0,883 | 430 Mo | https://arxiv.org/html/2404.15254v2 |
| PP-FormulaNet_plus-S | Apache / Apache | imprimé | aucun | 257 Mo | https://github.com/PaddlePaddle/PaddleOCR/blob/main/docs/version3.x/module_usage/formula_recognition.en.md |
| TAMER, ICAL, CoMER | aucune licence | CROHME, HME100K | TAMER : ExpRate 60–62 | non vérifié | https://github.com/qingzhenduyu/TAMER |
| PosFormer | BSD « académique » | CROHME | non vérifié | non vérifié | https://github.com/SJTU-DeepVisionLab/PosFormer |
| Seshat (traits) | GPL-3 | non déclarées | non vérifié | BLSTM 2,4 Mo ×2, C++ | https://github.com/falvaro/seshat |
| CTC Transformer (traits) | code Apache, pas de poids | MathWriting (NC-SA) | CER 5,49 contre 7,17 pour l'image | à entraîner | https://arxiv.org/html/2404.10690v2 |

## Recommandation, par gain et risque

1. Constituer un corpus de traits réels (200 lignes, réglage et test séparés), avec les erreurs relevées.
2. Corriger le score automatique : il refuse à tort `f^{\prime}` et une matrice juste.
3. Beam k=3 avec cache, choix par plausibilité et contexte, alternatives proposées. Beam 5 sans cache : environ 770 ms sur le Pad, estimation à vérifier (budget 500 ms).
4. Essai sur PC seulement de TexTeller, UniMERNet-T et PP-FormulaNet_plus-S : un candidat doit gagner au moins 10 points sur le test.
5. Si le plafond reste insuffisant : modèle de traits maison, grand chantier avec son ADR.

## Vérifié / Supposé / Reste à tester

- **Vérifié** : lecture du code ; les mesures ci-dessus, sur PC ; licences et tailles aux sources citées.
- **Supposé** : les 770 ms ; la simulation PIL représente Skia ; le choix par plausibilité approchera le plafond.
- **Reste à tester** : aucun classeur de plausibilité n'existe encore ; l'appareil ; d'autres mains. Les mêmes 50 expressions ont servi partout, donc ces résultats sont optimistes.

## Choix d'Antsa (2026-11-07)

Plusieurs lectures d'abord ; poids non commerciaux refusés ; corpus public en CC0 ; moins de 500 ms pour une expression courte, jusqu'à 1 s pour une longue.
