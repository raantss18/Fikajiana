#!/usr/bin/env python3
"""Écrit la fiche de téléchargement d'une version, tirée de app/CHANGELOG.md.

Usage : tool/notes_release.py <CHANGELOG> <version> <nom de l'APK> <octets>
"""
import re
import sys

depot = "https://github.com/raantss18/Fikajiana"
changelog, version, apk, octets = sys.argv[1:]
texte = open(changelog, encoding="utf-8").read()
section = re.search(rf"^## \[{re.escape(version)}\].*?(?=^## \[|\Z)", texte, re.M | re.S)
if not section:
    sys.exit(f"Version {version} absente du CHANGELOG")
corps = section.group(0)


def bloc(titre):
    trouve = re.search(rf"^### {titre}\n+(.*?)(?=^### |\Z)", corps, re.M | re.S)
    return trouve.group(1).strip() if trouve else ""


fr, en = [], []
for ligne in bloc("Changements").splitlines():
    if " / " in ligne:
        a, b = ligne.split(" / ", 1)
        fr.append(a)
        en.append("- " + b)
mo = round(int(octets) / 1_000_000)

print(f"""# Fikajiana {version}

**On écrit des maths à la main, l'app calcule et répond à la main.** Android, libre, sans compte et hors ligne.

## ⬇️ Télécharger

| Fichier | Pour qui | Taille |
|---|---|---|
| [**{apk}**]({depot}/releases/download/app-v{version}/{apk}) | 📱 **Android 7 ou plus, 64 bits** (téléphones et tablettes) : ouvre le fichier, autorise l'installation si Android le demande | {mo} Mo |
| [SHA256SUMS.txt]({depot}/releases/download/app-v{version}/SHA256SUMS.txt) | 🔒 Empreintes pour vérifier le fichier | |

> **Déjà installée ?** Réglages → rechercher une mise à jour : ta feuille et le modèle de lecture sont gardés.
> **Première installation ?** Pour lire l'écriture : Réglages → « Télécharger le modèle » (117 Mo, une seule fois). Sans lui, la saisie au clavier marche quand même.

## ✨ Nouveautés

{bloc("Message fr")}

{chr(10).join(fr)}

## ✨ What's new

{bloc("Message en")}

{chr(10).join(en)}

## ⚠️ À savoir

- **La lecture se trompe encore souvent** ([37 expressions sur 50 dans un essai optimiste]({depot}/blob/main/docs/recherche/spike-ocr.md)). Si un résultat te surprend, touche-le : tu verras ce qui a été lu, et tu pourras corriger.
- Ce que fait l'app et ce qu'elle ne fait pas encore : [le README]({depot}#readme).
- L'APK ne contient pas le modèle de lecture : il vient de [la page de son auteur](https://huggingface.co/breezedeus/pix2text-mfr), licence MIT ; l'origine de ses données d'entraînement n'est pas publiée. Rien de ce que tu écris ne quitte l'appareil.

## 🔒 Vérifier le fichier

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

## 👤 Auteur et contact

**RANIRIAMANJAKA Antsa** — conception et développement · [antsa.raniriamanjaka@univ-antananarivo.mg](mailto:antsa.raniriamanjaka@univ-antananarivo.mg) · [github.com/raantss18](https://github.com/raantss18)

Logiciel libre sous GPL-3.0-or-later. Le moteur de calcul est [Giac](https://xcas.univ-grenoble-alpes.fr/en.html) ; il se compile par `native/giac/construire.sh`.""")
