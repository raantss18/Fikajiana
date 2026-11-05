# 0003 — Reconnaissance manuscrite hors ligne

- **Date** : 2026-11-05 · **Statut** : proposé (à valider par mesure, `docs/recherche/ocr-manuscrit.md`)
- **Décision** : v1 = **Pix2Text-MFR** (MIT) en ONNX int8 via `flutter_onnxruntime` (MIT) ; encre rastérisée sur
  l'appareil ; **segmentation maison** (lignes, accolade de système, matrices) avant reconnaissance ; repli
  PP-FormulaNet_plus-S (Apache-2.0).
- **Exclus** : ML Kit, MyScript (non libres) ; TAMER/ICAL/CoMER (sans licence) ; poids entraînés sur MathWriting
  ou CROHME (CC BY-NC-SA).
- **Plus tard** : modèle d'encre maison sur données libres (synthétiques + collecte CC0).
- **Risque** : provenance des poids Pix2Text-MFR non publiée (`docs/recherche/reverification.md`) : pas de diffusion
  publique de ces poids tant qu'elle n'est pas établie ou qu'un modèle maison ne les remplace pas.
- **Toujours** : ce qui est compris est affiché (LaTeX rendu) et corrigeable.
