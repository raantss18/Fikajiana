<h1 align="center">Fikajiana</h1>

<p align="center"><b>On écrit des maths à la main, l'app calcule et répond à la main.</b><br>
Calcul exact et graphes, sur une feuille qui prend tout l'écran.<br>
Android, téléphone et tablette. <b>Libre</b>, sans compte, sans pub, et <b>hors ligne</b> une fois le modèle téléchargé.</p>

<p align="center">
  <a href="https://github.com/raantss18/Fikajiana/releases/latest/download/fikajiana-arm64-v8a.apk"><b>⬇️ Télécharger pour Android</b></a>
  ·
  <a href="https://github.com/raantss18/Fikajiana/releases/latest">Notes de la dernière version</a>
</p>

> **Langues / Languages :** **Français** · [English summary](#english)

<p align="center">
  <img src="docs/captures/feuille.png" width="300" alt="Une feuille : 2+3= écrit à la main, suivi de 5 ; x+3=4, avec x=1 écrit dessous.">
  <img src="docs/captures/graphe.png" width="300" alt="Le Graphe : les courbes de sin(x), 1/x et ln(x), numérotées, avec leur légende.">
</p>

## Ce qu'on peut faire

- **Écrire** au stylet ou au doigt, sur une feuille blanche, un cahier ou un tableau noir, avec des stylos de couleur et une gomme, sur une page sans bord.
- **Calculer** : écris `2+3=` et le résultat s'écrit à la main après le signe égal. Écris `x+3=4` et la solution s'écrit dessous. Fractions, racines, équations, systèmes, intégrales, limites, sommes, matrices.
- **Basculer** entre valeur exacte et approchée, degrés et radians.
- **Tracer** : écris `f(x)=x^2`, touche l'icône à côté, et la courbe s'affiche. Glisser, pincer, plusieurs courbes, un toucher lit les coordonnées d'un point.
- **Corriger** : touche un résultat pour voir ce qui a été lu et le changer, ou saisis au clavier.
- **Dessiner net** : maintiens le stylet à la fin d'un trait pour obtenir une ligne, un cercle, un triangle ou un rectangle.

Tout tient dans deux boutons, Menu et Outils. Le reste de l'écran est à toi.

## Installer

1. [**Télécharge l'APK**](https://github.com/raantss18/Fikajiana/releases/latest/download/fikajiana-arm64-v8a.apk) (Android 7 ou plus, 64 bits), ouvre-le et autorise l'installation si Android le demande.
2. Pour lire l'écriture : Menu → Réglages → « Télécharger le modèle » (117 Mo, une seule fois). Sans lui, la saisie au clavier marche quand même.
3. Les versions suivantes s'installent depuis l'app : Réglages → rechercher une mise à jour.

## À savoir

- **La lecture se trompe encore souvent** : 37 expressions justes sur 50 dans [un essai optimiste](docs/recherche/spike-ocr.md), avec une seule personne. La lecture ne s'affiche pas : si un résultat te surprend, touche-le.
- **Pas encore là** : géométrie, historique, courbes implicites et paramétrées, export en PDF ou PNG. L'avancement est dans [`docs/TODO.md`](docs/TODO.md).
- **Vie privée** : aucun compte, aucune pub, aucune télémétrie. L'encre ne quitte jamais l'appareil. Seuls le téléchargement du modèle et la recherche de mise à jour, à ta demande, utilisent le réseau.
- **Le modèle de lecture n'est pas dans l'application** : il vient de [la page de son auteur](https://huggingface.co/breezedeus/pix2text-mfr), sous licence MIT. L'origine de ses données d'entraînement n'est pas publiée ([ADR 0016](docs/adr/0016-modele-telecharge.md)).

## Pour les développeurs

Flutter (Dart), avec le moteur de calcul formel [Giac](https://xcas.univ-grenoble-alpes.fr/en.html) en C++ et la lecture par [Pix2Text-MFR](https://huggingface.co/breezedeus/pix2text-mfr) sur ONNX Runtime.

```bash
native/giac/construire.sh arm64-v8a   # le moteur, une fois
cd app && flutter pub get && flutter run
flutter analyze
```

| Je veux… | Lire |
| --- | --- |
| connaître les règles du projet | [`CLAUDE.md`](CLAUDE.md) |
| voir où on en est, et les erreurs déjà corrigées | [`docs/TODO.md`](docs/TODO.md) |
| comprendre un choix | [`docs/adr/`](docs/adr) · [`docs/recherche/`](docs/recherche) |
| comprendre la construction et le design | [`docs/architecture.md`](docs/architecture.md) · [`docs/design.md`](docs/design.md) |
| publier une version | [`docs/RELEASING.md`](docs/RELEASING.md) |
| voir ce qui a changé | [`app/CHANGELOG.md`](app/CHANGELOG.md) |

## Auteur et contact

**RANIRIAMANJAKA Antsa** — conception et développement

- E-mail : [antsa.raniriamanjaka@univ-antananarivo.mg](mailto:antsa.raniriamanjaka@univ-antananarivo.mg)
- GitHub : [github.com/raantss18](https://github.com/raantss18)

## Licences

Code sous [GPL-3.0-or-later](LICENSE) ; dépendances : [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).

---

## English

**Fikajiana** lets you write maths by hand: the app computes and answers by hand. Exact calculation and graphs on a full-screen sheet, for Android phones and tablets. Free software, no account, no ads, and offline once the model is downloaded.

- 📱 **[Download for Android](https://github.com/raantss18/Fikajiana/releases/latest/download/fikajiana-arm64-v8a.apk)** (Android 7 or later, 64-bit) · [latest release notes](https://github.com/raantss18/Fikajiana/releases/latest)
- To read handwriting: Menu → Settings → "Download the model" (117 MB, once). Keyboard entry works without it.
- **Recognition is still often wrong** (37 of 50 in [an optimistic test](docs/recherche/spike-ocr.md)): tap a result to see what was read and correct it.
- Not there yet: geometry, history, implicit and parametric curves, PDF or PNG export.
- **Author:** RANIRIAMANJAKA Antsa — [antsa.raniriamanjaka@univ-antananarivo.mg](mailto:antsa.raniriamanjaka@univ-antananarivo.mg). **License:** GPL-3.0-or-later.
