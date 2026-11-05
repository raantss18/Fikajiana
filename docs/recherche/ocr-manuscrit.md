# Reconnaissance manuscrite des maths, open source et hors ligne (étude du 2026-11-05)

> Limite : huggingface.co et arxiv.org bloqués par le réseau de la session de recherche ; chiffres marqués
> « extrait » = lus dans des extraits de recherche, à revérifier sur la page source.

## Comparatif

| Modèle | Licence code / poids | Taille | Précision publiée | Mobile |
|---|---|---|---|---|
| **Pix2Text-MFR** (TrOCR) | MIT / MIT, **provenance des poids non publiée** | ONNX 117,6 Mo | manuscrit : non vérifié | export ONNX existant |
| PP-FormulaNet_plus-S (PaddleOCR) | Apache-2.0 | 248 Mo | En-BLEU 88,71 (imprimé, pas manuscrit) | export ONNX documenté |
| TexTeller 3 | Apache-2.0 | 298 M paramètres, ONNX 1,25 Go | « SOTA CROHME » revendiqué, non vérifié | trop lourd |
| UniMERNet | Apache-2.0 / poids ? | 441 Mo – 1,3 Go | non vérifié | trop lourd |
| TAMER / ICAL / CoMER | **aucune licence** | ? | CROHME 14/16/19 ≈ 60–63 % ExpRate | inutilisables tant que non licenciés |
| PosFormer | BSD-2 « académique uniquement » | ? | ? | exclu |
| BTTR | MIT | pas de poids publiés | ? | à réentraîner |
| Texify, Surya, MixTeX | GPL/CC BY-SA, OpenRAIL-M restreinte, AGPL | ≈ 300 Mo | manuscrit partiel | déconseillé |

Encre (traits) : **aucun modèle à poids libres** trouvé. Jeu MathWriting (Google, 230 k manuscrits + 400 k
synthétiques) : **CC BY-NC-SA 4.0** ; CROHME 2023 : **CC BY-NC-SA 3.0** → clause non commerciale, incompatible
avec une diffusion libre des poids entraînés dessus (statut juridique flou).

Plugins Flutter : `flutter_onnxruntime` (MIT, v1.9.0, ORT Android 1.28.0, maintenu) ; `onnxruntime` (MIT, v1.4.1,
inactif depuis ≈ 2 ans).

## Décision proposée (ADR 0003)

1. **Moteur v1** : Pix2Text-MFR en ONNX quantifié int8 via `flutter_onnxruntime` ; l'encre est rastérisée sur
   l'appareil puis reconnue.
2. **Segmentation à nous** (géométrie des traits, en Dart) : lignes, accolade de système, crochets/parenthèses de
   matrice → chaque ligne/cellule reconnue séparément puis réassemblée.
3. **Classification** (calcul / équation / système / fonction / matrice) sur l'arbre obtenu, pas sur l'image.
4. **Correction toujours visible** : LaTeX rendu + alternatives (le meilleur modèle CROHME plafonne vers 60 %).
5. **Plus tard** : modèle d'encre maison, entraîné sur données libres (encre synthétique générée depuis du LaTeX
   avec nos polices + collecte volontaire CC0), sans MathWriting ni CROHME. Repli image : PP-FormulaNet_plus-S.

## Vérifié / Supposé / Reste à tester

- **Vérifié** (pages sources) : licences MathWriting, TexTeller (code), Pix2Text (dépôt), UniMERNet, PosFormer,
  BTTR, Texify, Surya, MixTeX, PaddleOCR ; ExpRate TAMER et ICAL ; plugins Flutter.
- **Vérifié** (API Hugging Face, 2026-11-05) : poids Pix2Text-MFR sous licence MIT, fichiers `encoder_model.onnx` + `decoder_model.onnx`.
- **Revérifié** : tailles et CER, voir `reverification.md` ; risque de provenance des poids Pix2Text-MFR.
- **Reste à tester** : qualité de Pix2Text-MFR sur notre encre rastérisée, systèmes et matrices, latence et mémoire
  sur appareil réel, taille APK.

## Sources

https://github.com/breezedeus/Pix2Text · https://huggingface.co/breezedeus/pix2text-mfr/tree/main ·
https://github.com/google-research/google-research/tree/master/mathwriting · https://arxiv.org/html/2404.10690v2 ·
https://zenodo.org/records/8428035 · https://github.com/OleehyO/TexTeller · https://github.com/opendatalab/UniMERNet ·
https://github.com/SJTU-DeepVisionLab/PosFormer · https://github.com/Green-Wood/CoMER · https://github.com/Green-Wood/BTTR ·
https://github.com/qingzhenduyu/ICAL · https://github.com/qingzhenduyu/TAMER · https://github.com/VikParuchuri/texify ·
https://github.com/datalab-to/surya · https://github.com/RQLuo/MixTeX-Latex-OCR ·
https://github.com/PaddlePaddle/PaddleOCR/blob/main/docs/version3.x/module_usage/formula_recognition.en.md ·
https://pub.dev/packages/flutter_onnxruntime · https://pub.dev/packages/onnxruntime
