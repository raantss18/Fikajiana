"""Rendu d'un signe en image 32×32 et mesures du tracé : le contrat avec l'app.

L'app (Dart) doit reproduire exactement cet algorithme ; `CONTRAT.md` le reprend.

Entrées
-------
- `traits` : liste de traits, chacun une liste de points (x, y) dans n'importe quelle unité
  (dp à l'écran), y vers le bas.
- `case` : (left, top, width, height), la case de référence dans la même unité. Dans l'app :
  la boîte de la ligne d'écriture où se trouve le signe ; à la collecte : la case demandée.
  Seule sa hauteur `H` et son haut `top` servent.

Image (ENTREE `image`, float32 [N, 1, 32, 32])
-----------------------------------------------
1. Boîte du signe : x0, x1, y0, y1 = min/max des points de tous les traits ; w = x1 − x0, h = y1 − y0.
2. Côté S = max(w, h, COTE_MINIMAL × H) : on garde les proportions ; un point ou un trait d'union
   n'est pas agrandi au-delà de 0,15 H (sinon un point devient un rond plein).
3. On dessine sur une toile blanche de 128×128 (SUR = 4 fois 32), sans anticrénelage,
   à l'échelle k = (32 − 2 × MARGE) × SUR / S, le centre de la boîte au centre de la toile :
   X = (x − (x0 + x1) / 2) × k + 64, Y = (y − (y0 + y1) / 2) × k + 64.
4. Chemin de chaque trait : celui de l'app (`cheminDuTrait`, app/lib/encre/encre.dart) :
   moveTo(p0) ; pour i = 1 … n − 2 : quadraticBezierTo(p_i, milieu(p_i, p_i+1)) ; lineTo(p_n−1).
   Un trait d'un seul point devient un disque.
5. Trait noir d'épaisseur EPAISSEUR_PX × SUR = 8 px sur la toile (2 px sur l'image finale,
   soit 1/16 du côté), bouts et jointures ronds.
6. Anticrénelage : moyenne de chaque bloc 4×4 → 32×32 ; valeur = part d'encre dans le pixel,
   0 = fond, 1 = encre. Aucune autre normalisation.

Mesures (ENTREE `mesures`, float32 [N, K], K = 5, dans cet ordre)
-----------------------------------------------------------------
0. `rapport` : ln((w + 0,02 H) / (h + 0,02 H)), borné à [−3, 3].
1. `traits` : min(nombre de traits, 4) / 4.
2. `hauteur` : h / H, borné à [0, 2].
3. `largeur` : w / H, borné à [0, 3].
4. `centre` : ((y0 + y1) / 2 − top) / H, borné à [−0,5, 1,5].
"""

from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageDraw

TAILLE = 32
SUR = 4
MARGE_PX = 2
EPAISSEUR_PX = 2.0
COTE_MINIMAL = 0.15
PAS_QUADRATIQUE = 8
MESURES = ("rapport", "traits", "hauteur", "largeur", "centre")
K = len(MESURES)


def _chemin(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    """Aplatit le chemin de `cheminDuTrait` en segments."""
    if len(points) == 1:
        return [points[0]]
    sortie = [points[0]]
    courant = points[0]
    for i in range(1, len(points) - 1):
        a, b = points[i], points[i + 1]
        fin = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        for j in range(1, PAS_QUADRATIQUE + 1):
            t = j / PAS_QUADRATIQUE
            u = 1 - t
            sortie.append(
                (
                    u * u * courant[0] + 2 * u * t * a[0] + t * t * fin[0],
                    u * u * courant[1] + 2 * u * t * a[1] + t * t * fin[1],
                )
            )
        courant = fin
    sortie.append(points[-1])
    return sortie


def boite(traits) -> tuple[float, float, float, float]:
    xs = [p[0] for t in traits for p in t]
    ys = [p[1] for t in traits for p in t]
    return min(xs), min(ys), max(xs), max(ys)


def rendre(traits, case, epaisseur: float = 1.0) -> np.ndarray:
    """Image float32 32×32 du signe (0 fond, 1 encre).

    `epaisseur` multiplie l'épaisseur du contrat : 1 dans l'app ; varié seulement à l'entraînement.
    """
    traits = [[(float(p[0]), float(p[1])) for p in t] for t in traits if len(t)]
    if not traits:
        return np.zeros((TAILLE, TAILLE), np.float32)
    x0, y0, x1, y1 = boite(traits)
    hauteur_ref = float(case[3])
    cote = max(x1 - x0, y1 - y0, COTE_MINIMAL * hauteur_ref)
    if cote <= 0:
        cote = 1.0
    n = TAILLE * SUR
    k = (TAILLE - 2 * MARGE_PX) * SUR / cote
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    largeur = EPAISSEUR_PX * SUR * epaisseur
    rayon = largeur / 2

    toile = Image.new("L", (n, n), 0)
    dessin = ImageDraw.Draw(toile)
    for t in traits:
        pts = [((x - cx) * k + n / 2, (y - cy) * k + n / 2) for x, y in _chemin(t)]
        for a, b in zip(pts, pts[1:]):
            dessin.line([a, b], fill=255, width=max(1, round(largeur)))
        for x, y in pts:
            dessin.ellipse([x - rayon, y - rayon, x + rayon, y + rayon], fill=255)
    tableau = np.asarray(toile, np.float32) / 255.0
    return tableau.reshape(TAILLE, SUR, TAILLE, SUR).mean(axis=(1, 3))


def mesurer(traits, case) -> np.ndarray:
    """Les K mesures du tracé, dans l'ordre de `MESURES`."""
    traits = [t for t in traits if len(t)]
    x0, y0, x1, y1 = boite(traits)
    w, h = x1 - x0, y1 - y0
    hauteur_ref = max(float(case[3]), 1e-6)
    haut = float(case[1])
    rapport = math.log((w + 0.02 * hauteur_ref) / (h + 0.02 * hauteur_ref))
    return np.array(
        [
            min(max(rapport, -3.0), 3.0),
            min(len(traits), 4) / 4,
            min(max(h / hauteur_ref, 0.0), 2.0),
            min(max(w / hauteur_ref, 0.0), 3.0),
            min(max(((y0 + y1) / 2 - haut) / hauteur_ref, -0.5), 1.5),
        ],
        np.float32,
    )
