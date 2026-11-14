#!/usr/bin/env python3
"""Tourne les scènes de la vidéo de démonstration sur l'émulateur léger (ADR 0057), en tablette paysage.

Usage : tool/video/tourner.py <série adb> <dossier de sortie> [scène…]
Avant : émulateur lancé (tool/emulateur_leger.sh lancer), app installée en français, modèle de lecture téléchargé,
question des dons déjà répondue. L'écran est mis en 2560×1600 (1280×800 dp) puis remis à la fin.
Chaque scène donne <dossier>/<scène>.mp4 ; tool/video/monter.py les assemble avec les sous-titres.
Les coordonnées sont celles de cette taille d'écran : après un changement d'interface, revoir les constantes.
"""
import io
import pathlib
import subprocess
import sys
import time

from PIL import Image

serie, sortie = sys.argv[1], pathlib.Path(sys.argv[2])
choisies = sys.argv[3:]
sortie.mkdir(parents=True, exist_ok=True)
RACINE = pathlib.Path(__file__).resolve().parents[2]
PAQUET = "mg.fikajiana.app"

# Pixels, écran 2560×1600 à 320 dpi.
MENU = (2495, 200)
NOUVEAU = (2325, 225)
GUIDE = (2238, 480)
REGLAGES = (2260, 625)
TAPER = (195, 1535)
VALIDER = (1790, 700)
FEUILLE = (80, 200)
OUTILS_FIGURE = (2437, 1527)


def adb(*args, **kw):
    return subprocess.run(["adb", "-s", serie, *args], check=True, capture_output=True, **kw)


def shell(commande):
    return adb("shell", commande).stdout.decode()


def au_premier_plan():
    """Ne jamais toucher une autre app (règle du 2026-11-09)."""
    if PAQUET not in shell("dumpsys window | grep mCurrentFocus"):
        sys.exit("Fikajiana n'est pas au premier plan : rien n'est touché.")


def toucher(point, attente=1.5):
    au_premier_plan()
    shell(f"input tap {point[0]} {point[1]}")
    time.sleep(attente)


def glisser(x1, y1, x2, y2, ms=700, attente=1.2):
    au_premier_plan()
    shell(f"input swipe {x1} {y1} {x2} {y2} {ms}")
    time.sleep(attente)


def retour(attente=1.5):
    au_premier_plan()
    shell("input keyevent 4")
    time.sleep(attente)


def taper(texte, attente=3.0):
    toucher(TAPER, 1.8)
    shell(f"input text '{texte}'")
    time.sleep(1.2)
    toucher(VALIDER, attente)


def nouveau_document():
    toucher(FEUILLE, 1)
    toucher(MENU)
    toucher(NOUVEAU, 2.5)


def capture():
    return Image.open(io.BytesIO(adb("exec-out", "screencap", "-p").stdout)).convert("RGB")


def bouton_de_ligne(rang_depuis_le_bas=0):
    """Le bouton d'une ligne tapée : la petite flèche à la couleur des résultats, à droite de la ligne."""
    image = capture()
    px = image.load()
    points = [
        (x, y)
        for y in range(260, 1440, 2)
        for x in range(300, 2400, 2)
        if abs(px[x, y][0] - 138) < 16 and abs(px[x, y][1] - 80) < 16 and px[x, y][2] < 34
    ]
    # Une ligne = un paquet de points proches en hauteur.
    lignes = []
    for x, y in sorted(points, key=lambda p: p[1]):
        if lignes and y - lignes[-1][-1][1] < 60:
            lignes[-1].append((x, y))
        else:
            lignes.append([(x, y)])
    ligne = lignes[-1 - rang_depuis_le_bas]
    droite = max(p[0] for p in ligne)
    proches = [p for p in ligne if p[0] > droite - 40]
    return droite - 20, round(sum(p[1] for p in proches) / len(proches))


def choisir_dans_la_liste(bouton, rang, combien, attente):
    """Ouvre la liste du bouton de ligne et touche son entrée [rang] sur [combien].

    La liste s'ouvre où elle a la place : on la trouve en comparant l'écran avant et après.
    """
    from PIL import ImageChops

    avant = capture()
    toucher(bouton, 2.5)
    boite = ImageChops.difference(avant, capture()).point(lambda v: 255 if v > 24 else 0).getbbox()
    if boite is None:
        sys.exit("La liste de la ligne ne s'est pas ouverte.")
    gauche, haut, droite, bas = boite
    toucher(((gauche + droite) // 2, round(haut + (rang + 0.5) * (bas - haut) / combien)), attente)


class Film:
    """Enregistre l'écran pendant [duree] secondes au plus.

    screenrecord s'arrête seul (--time-limit) : arrêté par un signal, il perdait les dernières secondes.
    Il n'écrit une image que quand l'écran change : la dernière image vraie est gardée à part
    (<scène>-fin.png) et monter.py la tient deux secondes.
    """

    def __init__(self, nom, duree):
        self.nom, self.duree = nom, duree

    def __enter__(self):
        shell("rm -f /sdcard/scene.mp4")
        self.proc = subprocess.Popen(
            ["adb", "-s", serie, "shell",
             f"screenrecord --size 1280x800 --bit-rate 8000000 --time-limit {self.duree} /sdcard/scene.mp4"]
        )
        self.debut = time.time()
        time.sleep(1.5)
        return self

    def __exit__(self, *_):
        capture().resize((1280, 800)).save(sortie / f"{self.nom}-fin.png")
        self.proc.wait(timeout=self.duree + 30)
        time.sleep(1.5)
        adb("pull", "/sdcard/scene.mp4", str(sortie / f"{self.nom}.mp4"))
        print("scène", self.nom, round(time.time() - self.debut), "s", flush=True)


def scene_accueil():
    nouveau_document()
    toucher(MENU)
    with Film("accueil", 26):
        toucher(NOUVEAU, 22)  # les exemples de l'accueil s'écrivent


def scene_manuscrit():
    nouveau_document()
    with Film("manuscrit", 110):
        subprocess.run(
            [str(RACINE / "tool/video/rejouer_stylet.py"), serie, "2", "150", "120", "1",
             "pad7/e_x_egal_7", "pad7/lim_exp_sur_2x", "pad7/det_2x2_40"],
            check=True,
        )
        time.sleep(22)


def scene_etapes():
    nouveau_document()
    with Film("etapes", 62):
        taper("2x^2-3x-5=0", 3.5)
        # corriger, étapes : « étapes » est la seconde ; les sept lignes s'écrivent.
        choisir_dans_la_liste(bouton_de_ligne(), 1, 2, 40)
    retour()


def scene_copie():
    nouveau_document()
    with Film("copie", 52):
        for ligne in ("2x+3=7", "2x=10", "x=5"):
            taper(ligne, 2.5)
        # corriger, étapes, vérifier.
        choisir_dans_la_liste(bouton_de_ligne(1), 2, 3, 18)
    retour()


def scene_courbe():
    nouveau_document()
    with Film("courbe", 24):
        taper("f(x)=x^2-3", 5)  # « Tracer » ouvre la Figure
        toucher(OUTILS_FIGURE, 4)
    retour()
    toucher(FEUILLE, 1.5)


def scene_guide():
    toucher(FEUILLE, 1)
    toucher(MENU)
    with Film("guide", 34):
        toucher(GUIDE, 3)
        for _ in range(7):
            glisser(1280, 1300, 1280, 500, 900, 1.6)
    retour()


def scene_reglages():
    toucher(FEUILLE, 1)
    toucher(MENU)
    with Film("reglages", 46):
        toucher(REGLAGES, 3)
        toucher((325, 1232), 2)  # tableau noir
        toucher((325, 895), 2)  # feuille blanche
        glisser(1280, 1400, 1280, 420, 900, 2)
        # « Rechercher une mise à jour du modèle »
        toucher((420, 880), 5)
        for _ in range(4):
            glisser(1280, 1400, 1280, 500, 900, 1.8)
        time.sleep(2)
    retour()


SCENES = {
    "accueil": scene_accueil,
    "manuscrit": scene_manuscrit,
    "etapes": scene_etapes,
    "copie": scene_copie,
    "courbe": scene_courbe,
    "guide": scene_guide,
    "reglages": scene_reglages,
}

shell("wm size 2560x1600")
time.sleep(3)
try:
    shell(f"am start -n {PAQUET}/.MainActivity")
    time.sleep(6)
    for nom in choisies or SCENES:
        SCENES[nom]()
finally:
    shell("pkill -INT screenrecord || true")
    shell("wm size reset")
