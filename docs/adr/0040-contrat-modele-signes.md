# ADR 0040 — Contrat du modèle de signes et données d'entraînement

- **Date** : 2026-11-08 · **Statut** : accepté (suite de l'ADR 0038)
- **Contexte** : l'entraînement (`entrainement/`) et l'app doivent voir exactement la même image d'un signe ; sans écriture collectée, il faut des données de départ libres.
- **Décision** : image 32×32 rendue comme `cheminDuTrait`, à 4× sans anticrénelage puis moyennée, trait de 2 px, côté minimal 0,15 H ; 5 mesures du tracé (rapport, traits, hauteur, largeur, centre) ; ONNX `image`/`mesures` → `logits`, < 2 Mio. Détail : `entrainement/CONTRAT.md`, code : `entrainement/rendu.py`.
- **Données** : six polices manuscrites OFL (squelette → traits → déformations), signes sûrs des fixtures, séances de collecte. MNIST (CC BY-SA 3.0, non compatible GPLv3) et HASYv2 (provenance non vérifiée) écartés : `entrainement/SOURCES.md`.
- **Test** : une police jamais vue (Patrick Hand) et des séances réelles entières jamais vues.
- **Poids** : `entrainement/sortie/` hors Git ; la version adoptée sera décidée plus tard (seuil de l'ADR 0038).
- **Reste** : vérifier l'égalité du rendu Skia / Pillow ; justesse sur la main d'Antsa.
