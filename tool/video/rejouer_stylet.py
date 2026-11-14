#!/usr/bin/env python3
"""Rejoue au stylet simulé des lignes vraiment écrites (app/test/fixtures/…), pour la vidéo de démonstration.

Usage : tool/video/rejouer_stylet.py <série adb> <densité px/dp> <x dp> <y dp> <échelle> fixture [fixture…]
Une fixture est un chemin sous app/test/fixtures/, sans .json (pad7/trente_fois_8). Les lignes s'empilent.
Les gestes d'une ligne partent dans un seul script lancé sur l'appareil : un `input` par point, mais sans
aller-retour adb entre deux points (plus régulier à l'écran).
"""
import json
import pathlib
import subprocess
import sys
import time

RACINE = pathlib.Path(__file__).resolve().parents[2] / "app/test/fixtures"
serie, densite = sys.argv[1], float(sys.argv[2])
x0, y, k = float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
POINTS_PAR_TRAIT = 60  # assez pour garder la forme des longs traits (limite, matrice)

for nom in sys.argv[6:]:
    traits = json.loads((RACINE / f"{nom}.json").read_text())
    points = [p for t in traits for p in t["points"]]
    gauche = min(p[0] for p in points)
    haut = min(p[1] for p in points)
    hauteur = max(p[1] for p in points) - haut
    lignes = []
    for t in traits:
        p = t["points"]
        pas = max(1, len(p) // POINTS_PAR_TRAIT)
        choisis = p[::pas] + [p[-1]]
        px = lambda q: round((x0 + (q[0] - gauche) * k) * densite)
        py = lambda q: round((y + (q[1] - haut) * k) * densite)
        lignes.append(f"input stylus motionevent DOWN {px(choisis[0])} {py(choisis[0])}")
        lignes += [f"input stylus motionevent MOVE {px(q)} {py(q)}" for q in choisis[1:]]
        lignes.append(f"input stylus motionevent UP {px(choisis[-1])} {py(choisis[-1])}")
    subprocess.run(["adb", "-s", serie, "shell", "\n".join(lignes)], check=True)
    print(nom, "écrit à y =", round(y), flush=True)
    time.sleep(1.5)
    y += hauteur * k + 60
