#!/usr/bin/env python3
"""Monte la vidéo de démonstration : cartons, scènes tournées par tourner.py, sous-titres français incrustés.

Usage : tool/video/monter.py <dossier des scènes> <sortie.mp4> [chapitres.json] [affiche.jpg]
Demande ffmpeg et Pillow. Sans voix ni musique (choix d'Antsa, 2026-11-14) : tout est écrit à l'écran.
Les textes sont ici : pour changer une phrase, la changer dans PLAN et relancer.
"""
import json
import pathlib
import subprocess
import sys
import textwrap

from PIL import Image, ImageDraw, ImageFont

scenes, sortie = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
chapitres = pathlib.Path(sys.argv[3]) if len(sys.argv) > 3 else None
affiche = pathlib.Path(sys.argv[4]) if len(sys.argv) > 4 else None
RACINE = pathlib.Path(__file__).resolve().parents[2]
POLICE = str(RACINE / "app/assets/polices/Nunito.ttf")
L, H = 1280, 800
# Sous l'écran, une bande pour le sous-titre : il ne cache rien de l'app.
BANDE = 120
HT = H + BANDE
PAPIER, ENCRE, BLEU, ORANGE = "#FFFBF4", "#2A1E18", "#006A9A", "#F4A23C"
travail = scenes / "montage"
travail.mkdir(exist_ok=True)


def police(taille, gras=False):
    f = ImageFont.truetype(POLICE, taille)
    try:
        f.set_variation_by_axes([800 if gras else 500])
    except OSError:
        pass
    return f


def carton(nom, titre, lignes, duree):
    """Un écran de texte, à la couleur du papier de l'app."""
    image = Image.new("RGB", (L, HT), PAPIER)
    d = ImageDraw.Draw(image)
    d.rectangle([0, 0, L, 14], fill=ORANGE)
    d.text((90, 110), titre, font=police(58, gras=True), fill=ENCRE)
    y = 230
    for ligne in lignes:
        for morceau in textwrap.wrap(ligne, 58) or [""]:
            d.text((90, y), morceau, font=police(34), fill=ENCRE)
            y += 50
        y += 18
    image.save(travail / f"{nom}.png")
    clip = travail / f"{nom}.mp4"
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-loop", "1", "-t", str(duree), "-i", str(travail / f"{nom}.png"),
         "-vf", "format=yuv420p", "-r", "30", "-c:v", "libx264", "-crf", "20", str(clip)],
        check=True,
    )
    return clip, duree


def bandeau(nom, texte):
    """Le sous-titre, dans la bande sous l'écran : texte clair sur fond sombre (contraste ≥ 7:1)."""
    image = Image.new("RGBA", (L, HT), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    d.rectangle([0, H, L, HT], fill=(27, 22, 19, 255))
    lignes = textwrap.wrap(texte, 80)[:2]
    y = H + (BANDE - 42 * len(lignes)) / 2 - 4
    for ligne in lignes:
        largeur = d.textlength(ligne, font=police(29, gras=True))
        d.text(((L - largeur) / 2, y), ligne, font=police(29, gras=True), fill="#FFFBF4")
        y += 42
    chemin = travail / f"{nom}-sous-titre.png"
    image.save(chemin)
    return chemin


def scene(nom, texte, vitesse=1.0, debut=0.0):
    """Une scène tournée, accélérée s'il le faut, avec son sous-titre."""
    source = scenes / f"{nom}.mp4"
    clip = travail / f"{nom}.mp4"
    # La dernière image vraie de la scène (tourner.py), tenue deux secondes et demie : l'enregistreur
    # n'écrit rien tant que l'écran ne change pas, et la fin d'une animation lui échappe.
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", str(debut), "-i", str(source),
         "-loop", "1", "-t", "2.5", "-i", str(scenes / f"{nom}-fin.png"), "-i", str(bandeau(nom, texte)),
         "-filter_complex",
         f"[0:v]setpts=PTS/{vitesse},scale={L}:{H},fps=30,setsar=1[a];[1:v]scale={L}:{H},fps=30,setsar=1[b];"
         f"[a][b]concat=n=2:v=1,pad={L}:{HT}:0:0[v];[v][2:v]overlay=0:0,format=yuv420p[s]",
         "-map", "[s]", "-an", "-c:v", "libx264", "-crf", "20", str(clip)],
        check=True,
    )
    duree = float(subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(clip)],
        check=True, capture_output=True,
    ).stdout)
    return clip, duree


# (chapitre ou None, fabrique du clip)
PLAN = [
    ("Fikajiana", lambda: carton("titre", "Fikajiana", [
        "Écris tes maths à la main. L'application calcule.",
        "Calculatrice, calcul formel, courbes et géométrie, pour téléphone et tablette Android.",
        "Libre, hors ligne, sans compte et sans publicité.",
    ], 6)),
    ("Installer", lambda: carton("installer", "Installer", [
        "1. Sur le site ou sur GitHub, touche « Télécharger pour Android ».",
        "2. Ouvre le fichier fikajiana-arm64-v8a.apk depuis tes téléchargements.",
        "3. Android demande une autorisation, une seule fois : accepte, puis « Installer ».",
        "4. Ouvre Fikajiana. Dans les Réglages, télécharge le modèle de lecture (117 Mo), une seule fois.",
    ], 11)),
    (None, lambda: scene("accueil", "À l'ouverture, la feuille montre ce qu'elle sait faire : les exemples s'écrivent tout seuls.")),
    ("Écrire à la main", lambda: scene(
        "manuscrit",
        "Écris au stylet ou au doigt. Chaque ligne est lue sur l'appareil, et la réponse s'écrit à côté : "
        "équation, limite, déterminant.", vitesse=2.2)),
    ("Étapes de résolution", lambda: scene(
        "etapes",
        "Le bouton de la ligne propose « étapes » : la résolution s'écrit ligne par ligne, comme au tableau.",
        vitesse=1.3)),
    ("Vérifier ma copie", lambda: scene(
        "copie",
        "Écris ta démarche, puis « vérifier » : l'application montre la ligne où est l'erreur, "
        "sans donner la réponse.", vitesse=1.5)),
    ("Courbes et géométrie", lambda: scene(
        "courbe", "Une fonction se trace d'un toucher. La Figure a aussi ses outils de géométrie.")),
    ("Le Guide", lambda: scene(
        "guide",
        "Le Guide liste tout ce que Fikajiana sait faire : fractions, dérivées, intégrales, matrices, "
        "suites, probabilités, nombres complexes…", vitesse=1.4)),
    ("Réglages et mises à jour", lambda: scene(
        "reglages",
        "Dans les Réglages : le papier, le modèle de lecture et sa mise à jour, les nouvelles versions. "
        "Tout se fait à ta demande.", vitesse=1.3)),
    (None, lambda: carton("fin", "À toi d'écrire", [
        "Télécharger : github.com/raantss18/Fikajiana",
        "Fikajiana est libre : le code est ouvert, rien n'est suivi.",
        "Conçue par Antsa Malala RANIRIAMANJAKA.",
    ], 7)),
]

clips, reperes, t = [], [], 0.0
for chapitre, fabrique in PLAN:
    clip, duree = fabrique()
    if chapitre:
        reperes.append({"t": round(t, 1), "titre": chapitre})
    clips.append(clip)
    t += duree

liste = travail / "liste.txt"
liste.write_text("".join(f"file '{c.resolve()}'\n" for c in clips))
subprocess.run(
    ["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(liste), "-c:v", "libx264", "-crf", "23",
     "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", str(sortie)],
    check=True,
)
if chapitres:
    chapitres.write_text(json.dumps(reperes, ensure_ascii=False, indent=2) + "\n")
if affiche:
    Image.open(travail / "titre.png").save(affiche, quality=88)
print(f"{sortie} : {t:.0f} s, {sortie.stat().st_size / 1e6:.1f} Mo, {len(reperes)} chapitres")
