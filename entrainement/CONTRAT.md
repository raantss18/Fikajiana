# Contrat du modèle de signes (version 1)

Ce que `entrainement/entrainer.py` produit et ce que l'app doit faire pour s'en servir (ADR 0038).
La référence exécutable est `entrainement/rendu.py` ; ce fichier la décrit. Toute modification
passe par une nouvelle version (champ `version` de `signes.json`) et un ADR.

## Fichiers (dans `entrainement/sortie/`)

| Fichier | Contenu |
|---|---|
| `signes.onnx` | Réseau ONNX (opset 17), < 2 Mio, float32, sans quantification. |
| `signes_classes.txt` | Un `id` de `collecte/classes.txt` par ligne ; ligne i = sortie i. |
| `signes.json` | Ce contrat en machine : tailles, mesures, empreinte SHA-256, commit. |
| `rapport.md` | Justesse, confusions, temps d'inférence, part de chaque source. |

## Entrées et sortie

- `image` : float32 `[N, 1, 32, 32]` (N ≥ 1 : on peut passer tous les signes d'une ligne d'un coup).
- `mesures` : float32 `[N, 5]`.
- `logits` : float32 `[N, C]`, C = nombre de lignes de `signes_classes.txt` (109 aujourd'hui).
  Probabilités = softmax(logits). Un seuil de rejet reste à régler sur données réelles.

## Le signe et sa case

- Un **signe** = les traits que la segmentation de l'app attribue à un même symbole, points `(x, y)`
  en dp, y vers le bas (la pression et le temps ne servent pas).
- Sa **case** = `(left, top, width, height)` de la ligne d'écriture : la boîte des traits qui
  recouvrent verticalement le signe, sans ceux plus hauts que 2,5 fois la hauteur médiane des
  signes de la ligne (grandes parenthèses, barres de matrice). Seuls `top` et `H = height` servent.
  C'est la règle appliquée aux fixtures (`donnees.lire_fixtures`) ; à la collecte, c'est la case
  demandée. ⚠ Supposé : l'écart entre ces deux définitions est couvert par une variation de la case
  à l'entraînement (hauteur × e^N(0; 0,15)) ; à vérifier sur données réelles.

## Image 32×32

1. Boîte du signe : `x0, x1, y0, y1` = min/max des points de tous ses traits ; `w = x1 − x0`, `h = y1 − y0`.
2. Côté `S = max(w, h, 0.15 × H)` (proportions gardées ; un point n'est pas agrandi au-delà de 0,15 H).
3. Toile **128×128** blanche (fond 0), **sans anticrénelage** (`Paint.isAntiAlias = false`).
   Échelle `k = (32 − 2 × 2) × 4 / S = 112 / S` ; centre de la boîte au centre de la toile :
   `X = (x − (x0 + x1)/2) × k + 64`, `Y = (y − (y0 + y1)/2) × k + 64`.
4. Chaque trait suit `cheminDuTrait` (app/lib/encre/encre.dart) : `moveTo(p0)`, puis pour
   `i = 1 … n−2` `quadraticBezierTo(p_i, milieu(p_i, p_i+1))`, puis `lineTo(p_n−1)` ;
   un trait d'un seul point est un disque.
5. Trait **plein (encre = 1), épaisseur 8 px** sur la toile, `StrokeCap.round`, `StrokeJoin.round`.
6. **Moyenne de chaque bloc 4×4** → 32×32. Valeur = part d'encre (0 fond, 1 encre).
   Aucune autre normalisation. Tenseur rangé ligne par ligne (index `y × 32 + x`).

Dans Flutter : `Canvas.scale(k)` puis dessin avec `strokeWidth = 8 / k`, ou transformer les points
et dessiner avec `strokeWidth = 8` ; lire le canal rouge de `toByteData()` puis `encre = 1 − rouge/255`
si l'on dessine en noir sur blanc. ⚠ Reste à tester : l'écart entre la rastérisation de Skia et
celle de Pillow (`rendu.py`) ; à mesurer avec les fixtures avant d'adopter le modèle.

## Mesures (K = 5, dans cet ordre)

| # | Nom | Formule |
|---|---|---|
| 0 | `rapport` | `clamp(ln((w + 0,02 H) / (h + 0,02 H)), −3, 3)` |
| 1 | `traits` | `min(nombre de traits, 4) / 4` |
| 2 | `hauteur` | `clamp(h / H, 0, 2)` |
| 3 | `largeur` | `clamp(w / H, 0, 3)` |
| 4 | `centre` | `clamp(((y0 + y1)/2 − top) / H, −0,5, 1,5)` |

## Vérifié / Supposé / Reste à tester

- **Vérifié** : le modèle exporté se recharge dans onnxruntime et rend les mêmes logits que PyTorch
  (`entrainement/tests/test_export.py`) ; le rendu est déterministe (`test_rendu.py`).
- **Supposé** : la définition de la case dans l'app ; l'égalité pixel à pixel Skia / Pillow.
- **Reste à tester** : justesse sur l'écriture d'Antsa (aucune séance de collecte encore), temps sur le Pad 7.
