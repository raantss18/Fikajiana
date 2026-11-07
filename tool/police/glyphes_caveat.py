#!/usr/bin/env python3
"""Contours de Caveat (SIL OFL 1.1) pour l'écriture des résultats (ADR 0034).

Usage : python3 tool/police/glyphes_caveat.py <Caveat[wght].ttf> > app/lib/comprendre/glyphes_caveat.dart
Source : https://github.com/google/fonts/tree/main/ofl/caveat (graisse 400).
Unités : la hauteur des capitales vaut 1, la ligne de base est en y = 1.
"""
import sys

from fontTools.pens.recordingPen import RecordingPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

CARACTERES = (
    "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "+−=×·≤≥≈()[]{};:,.'|/<>!%"
)

police = TTFont(sys.argv[1])
if "fvar" in police:
    police = instantiateVariableFont(police, {"wght": 400})
cmap = police.getBestCmap()
glyphes = police.getGlyphSet()
echelle = 1 / police["OS/2"].sCapHeight


def n(v):
    return f"{v:.2f}".rstrip("0").rstrip(".") or "0"


def point(p):
    x, y = p
    return f"{n(x * echelle)} {n(1 - y * echelle)}"


print("// Produit par tool/police/glyphes_caveat.py : ne pas modifier à la main.")
print("// ignore_for_file: lines_longer_than_80_chars")
print("// Contours de Caveat, Copyright 2014 The Caveat Project Authors")
print("// (https://github.com/googlefonts/caveat), SIL Open Font License 1.1 :")
print("// voir app/assets/polices/OFL-Caveat.txt.")
print()
print("/// Pour chaque caractère : son avance et son contour (M, L, Q, Z).")
print("const Map<String, (double, String)> glyphesCaveat = {")
for c in CARACTERES:
    nom = cmap.get(ord(c))
    if nom is None:
        continue
    pen = RecordingPen()
    glyphes[nom].draw(pen)
    morceaux = []
    for op, pts in pen.value:
        if op == "moveTo":
            morceaux.append("M " + point(pts[0]))
        elif op == "lineTo":
            morceaux.append("L " + point(pts[0]))
        elif op == "qCurveTo":
            # Une suite de points de contrôle implicites, comme TrueType.
            *controles, fin = pts
            for i, ctrl in enumerate(controles):
                if i + 1 < len(controles):
                    nx = (ctrl[0] + controles[i + 1][0]) / 2
                    ny = (ctrl[1] + controles[i + 1][1]) / 2
                    morceaux.append(f"Q {point(ctrl)} {point((nx, ny))}")
                else:
                    morceaux.append(f"Q {point(ctrl)} {point(fin)}")
        elif op == "curveTo":
            a, b, fin = pts
            morceaux.append(f"C {point(a)} {point(b)} {point(fin)}")
        elif op in ("closePath", "endPath"):
            morceaux.append("Z")
    avance = police["hmtx"][nom][0] * echelle
    cle = f'"{c}"' if c == "'" else f"'{c}'"
    print(f"  {cle}: ({n(avance)}, '{' '.join(morceaux)}'),")
print("};")
