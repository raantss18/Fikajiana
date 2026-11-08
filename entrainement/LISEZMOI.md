# Entraîner le modèle de signes

Un petit réseau lit un signe isolé (chiffre, lettre, opérateur) à partir de son image 32×32 et de
cinq mesures du tracé (ADR 0038, 0039). Tout se fait sur l'ordinateur, sans GPU, en une commande.

## Quand de nouvelles écritures arrivent

1. **Déposer** les fichiers exportés par l'app de collecte dans `donnees/ecriture/<personne>/`
   (à la racine du dépôt ; ce dossier est hors Git). Un fichier = une séance
   (`fikajiana-ecriture-<appareil>-<date>.json`, format `collecte/FORMAT.md`).
2. **Lancer**, depuis la racine du dépôt :

   ```bash
   uv run entrainement/entrainer.py
   ```

   Options : `--donnees donnees/ecriture` (dossier des séances), `--epoques 15`,
   `--sortie entrainement/sortie/`, `--par-classe 600` (signes synthétiques par classe).
   La première fois, uv installe PyTorch CPU et le script télécharge les polices
   (`entrainement/recuperer_polices.sh`). Compter de 30 à 45 min sur un ordinateur à 16 cœurs.
3. **Lire** `entrainement/sortie/rapport.md` : justesse sur les séances réelles jamais vues
   (globale, par signe, par appareil), confusions principales, temps d'inférence, part de chaque source.
   Les matrices complètes sont dans `confusions_reel.csv` et `confusions_police.csv`.
4. **Adopter** (décision d'Antsa) : si la justesse réelle atteint au moins celle de Pix2Text sur le
   même test (ADR 0038), copier `signes.onnx`, `signes_classes.txt` et `signes.json` à l'endroit
   choisi par l'app et noter l'empreinte SHA-256 de `signes.json`.

## Ce que fait la commande

- Lit toutes les séances (`rejete` ignoré, expressions laissées de côté pour l'instant) et les signes
  sûrs des fixtures de l'app (`fixtures_signes.json`, relevés à la main).
- Sépare **par séance entière** : environ 25 % des séances en test, 15 % en validation, jamais
  partagées avec l'entraînement ; au moins une séance réelle en test.
- Fabrique des signes synthétiques avec six polices manuscrites OFL (`SOURCES.md`) : squelette du
  glyphe, traits recollés aux croisements, penchée, rotation, ondulation, bouts raccourcis,
  épaisseur variable. Une police (Patrick Hand) n'est jamais vue à l'entraînement : elle sert de test.
- Rend chaque signe comme l'app (`rendu.py`, décrit dans `CONTRAT.md`) et entraîne le réseau
  (`modele.py`), garde la meilleure époque en validation, exporte `signes.onnx` (< 2 Mio).

## Tests

```bash
cd entrainement && uv run pytest
```

Lecture d'un fichier au format, rendu déterministe (empreinte figée), squelette d'une croix,
export ONNX rechargé dans onnxruntime avec les mêmes sorties que PyTorch.

## Ajouter un signe

Ajouter une ligne **à la fin** de `collecte/classes.txt` (jamais renuméroter), vérifier qu'au moins
une police le couvre (`rapport.md`, section « Couverture »), sinon l'ajouter à `VARIANTES` de
`synthese.py` ou attendre des écritures réelles. Le nombre de sorties change : l'app doit relire
`signes_classes.txt`.
