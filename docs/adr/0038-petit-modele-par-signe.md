# ADR 0038 — Un petit modèle par signe, entraîné sur l'écriture réelle

- **Date** : 2026-11-08 · **Statut** : accepté (décision d'Antsa : « on va entraîner un petit modèle performant »)
- **Contexte** : Pix2Text lit toute la ligne en image (276 ms médiane, 561 ms au pire sur le Pad 7, plus la pause) et se trompe sur la main d'Antsa (`1`→`Λ`, `4`→`1/1`, `9`→`g`). La lecture au tracé (ADR 0035, 0037) compare des formes dessinées, sans apprentissage. Mikajy lit vite avec un petit réseau par signe (~1,2 Mo, conv 3×3 ×2 + 2 couches denses, https://github.com/ARHeritiana/Mikajy). Les grands corpus manuscrits (MathWriting, CROHME) sont non commerciaux : refusés.
- **Décision** : un classeur de signes isolés (liste fixe `collecte/classes.txt`), petit réseau convolutif sur l'image du signe (32×32) et quelques mesures du tracé, exporté en ONNX (déjà embarqué), moins de 2 Mo. La structure (fractions, exposants, Σ, lim, matrices) reste géométrique. Pix2Text devient un secours.
- **Données** : écriture réelle donnée par les utilisateurs depuis Fikajiana (ADR 0042 ; d'abord une app dédiée, retirée), format `collecte/FORMAT.md`, CC0 ; signes tirés de polices OFL ; MNIST (CC BY-SA 3.0) et HASYv2 (ODbL) seulement si leur licence est confirmée compatible avec des poids GPL, notée dans `THIRD_PARTY_LICENSES.md`.
- **Entraînement** : une seule commande sur l'ordinateur, sans GPU (`entrainement/`, `uv run`), rapport de justesse par signe et par appareil, jeu de test jamais vu.
- **Apprentissage local** (comme Mikajy) : les corrections de la personne ajustent la lecture sur l'appareil, sans rien envoyer.
- **Reste** : mesurer sur le Pad 7 et le téléphone ; seuil d'adoption : au moins la justesse de Pix2Text sur le même test, et moins de 50 ms par ligne.
