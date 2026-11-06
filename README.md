# Fikajiana

On écrit des maths à la main, l'app comprend, calcule et écrit le résultat après le signe égal.
Android (téléphone et tablette), **libre** (GPL-3.0-or-later), **hors ligne** une fois le modèle téléchargé.

**Version d'essai.** Ce qui marche aujourd'hui :

- Écrire au stylet ou au doigt sur une feuille blanche, un cahier ou un tableau noir, avec une gomme, sur une page sans bord.
- Calcul exact et valeur approchée par [Giac](https://xcas.univ-grenoble-alpes.fr/en.html) : fractions, racines, équations, systèmes, intégrales, limites, sommes.
- Correction de ce qui a été lu ; saisie au clavier.

Ce qui n'existe pas encore : graphes, géométrie, historique. La lecture de l'écriture se trompe encore souvent
(37 sur 50 dans [un essai optimiste](docs/recherche/spike-ocr.md)) : vérifie toujours ce qui est affiché.

## Installer

1. Télécharge `fikajiana-…-arm64-v8a.apk` depuis les [versions](https://github.com/raantss18/Fikajiana/releases) (appareils Android 64 bits, Android 7 ou plus).
2. Si une ancienne version d'essai signée autrement est installée, désinstalle-la d'abord.
3. Pour lire l'écriture : Réglages → « Télécharger le modèle » (117 Mo, une seule fois).

Le modèle de lecture n'est pas dans l'application : il vient de [la page de son auteur](https://huggingface.co/breezedeus/pix2text-mfr), sous licence MIT.
L'origine de ses données d'entraînement n'est pas publiée. Rien de ce que tu écris ne quitte l'appareil ; seuls le téléchargement du modèle et la recherche de mise à jour, à ta demande, utilisent le réseau.

## Pour les développeurs

- Avancement et priorités : [`docs/TODO.md`](docs/TODO.md) · Décisions : `docs/adr/` · Études : `docs/recherche/`
- Compiler le moteur : `native/giac/construire.sh arm64-v8a` · Essais : `tool/essai_local.sh` · Publier : [`docs/RELEASING.md`](docs/RELEASING.md)
