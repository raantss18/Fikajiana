#!/usr/bin/env python3
"""Génère le logo et les icônes Android de Fikajiana depuis une seule définition.

Usage : python3 -I tool/generer_marque.py (demande rsvg-convert).
Dessin original (ADR 0010) : aucun élément repris d'une image existante.
"""

import pathlib
import subprocess

RACINE = pathlib.Path(__file__).resolve().parent.parent
MARQUE = RACINE / "design" / "marque"
RES = RACINE / "app" / "android" / "app" / "src" / "main" / "res"

PAPIER = "#FFFBF4"
ENCRE = "#2A1E18"
CIEL = "#1E9FD8"
ORANGE = "#F4A23C"
SAUMON = "#EC8A80"

# Repère de 108 unités : Android garde le disque central de 66 unités.
TACHE_ORANGE = (
    "M54 25 C63 21 74 28 77 37 C82 41 84 50 80 57 C84 66 77 76 67 77 "
    "C61 84 50 84 44 79 C35 82 26 75 27 65 C21 58 23 47 30 42 C30 33 44 24 54 25 Z"
)
TACHE_CIEL = (
    "M71 57 C76 54 83 57 84 63 C85 69 80 74 74 73 C69 72 66 67 67 63 C67 60 69 58 71 57 Z"
)
GOUTTES = [(CIEL, 27, 37, 3.2), (CIEL, 22, 49, 1.8), (SAUMON, 33, 79, 2.6), (SAUMON, 81, 37, 2.2), (CIEL, 62, 23, 1.6)]

# Le π, au trait : une barre levée, une jambe gauche courbe, une jambe droite qui repart.
PI_BARRE = "M31 45 C37 39 45 42 54 41 C61 40 70 41 77 37"
PI_GAUCHE = "M47 42 C47 52 45 63 37 72"
PI_DROITE = "M63 41 C62 51 61 60 63 67 C64 72 70 74 75 68"
TRAITS_PI = [PI_BARRE, PI_GAUCHE, PI_DROITE]
EPAISSEUR = 6.5


def svg_traits(couleur):
    return "".join(
        f'<path d="{d}" fill="none" stroke="{couleur}" stroke-width="{EPAISSEUR}" '
        'stroke-linecap="round" stroke-linejoin="round"/>'
        for d in TRAITS_PI
    )


def svg_taches():
    gouttes = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}"/>' for c, x, y, r in GOUTTES)
    return f'<path d="{TACHE_ORANGE}" fill="{ORANGE}"/><path d="{TACHE_CIEL}" fill="{CIEL}"/>{gouttes}'


def svg(contenu, fond=None):
    rect = f'<rect width="108" height="108" fill="{fond}"/>' if fond else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">{rect}{contenu}</svg>\n'


def cercle_xml(x, y, r):
    return f"M{x - r},{y} a{r},{r} 0 1,0 {2 * r},0 a{r},{r} 0 1,0 {-2 * r},0 Z"


def vecteur(chemins):
    corps = "\n".join(chemins)
    return (
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp" android:height="108dp"\n'
        '    android:viewportWidth="108" android:viewportHeight="108">\n'
        f"{corps}\n</vector>\n"
    )


def rempli(d, couleur):
    return f'    <path android:pathData="{d}" android:fillColor="{couleur}"/>'


def trait(d, couleur):
    return (
        f'    <path android:pathData="{d}" android:strokeColor="{couleur}" '
        f'android:strokeWidth="{EPAISSEUR}" android:strokeLineCap="round" android:strokeLineJoin="round"/>'
    )


def png(source, sortie, taille):
    sortie.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["rsvg-convert", "-w", str(taille), "-h", str(taille), "-o", str(sortie), str(source)], check=True)


def main():
    MARQUE.mkdir(parents=True, exist_ok=True)
    icone = MARQUE / "icone.svg"
    icone.write_text(svg(svg_taches() + svg_traits(ENCRE), fond=PAPIER))
    (MARQUE / "logo.svg").write_text(svg(svg_taches() + svg_traits(ENCRE)))
    (MARQUE / "pi.svg").write_text(svg(svg_traits(ENCRE)))

    avant = [rempli(TACHE_ORANGE, ORANGE), rempli(TACHE_CIEL, CIEL)]
    avant += [rempli(cercle_xml(x, y, r), c) for c, x, y, r in GOUTTES]
    avant += [trait(d, ENCRE) for d in TRAITS_PI]
    (RES / "drawable" / "ic_launcher_foreground.xml").write_text(vecteur(avant))
    (RES / "drawable" / "ic_launcher_monochrome.xml").write_text(vecteur([trait(d, "#FFFFFF") for d in TRAITS_PI]))
    (RES / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
        "</adaptive-icon>\n"
    )

    for dossier, taille in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        png(icone, RES / f"mipmap-{dossier}" / "ic_launcher.png", taille)
    png(icone, RES.parent / "ic_launcher-playstore.png", 512)


if __name__ == "__main__":
    main()
