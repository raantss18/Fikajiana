# 0012 — Supports d'écriture, stylos et gomme

- **Date** : 2026-11-05 · **Statut** : accepté (Antsa)
- **Décision** : quatre supports dans les réglages : feuille blanche, cahier à grands carreaux, cahier à petits carreaux, tableau noir.
  **Le support décide du thème** : tableau noir en sombre, les autres en clair ; le mode clair/sombre de l'appareil ne s'applique plus.
- **Stylos** : quatre couleurs par support. Un trait garde son rang, pas sa couleur : il reste lisible quand le support change.
  Le modèle reçoit toujours du noir sur blanc. Stylo choisi signalé aussi par une coche et un anneau, pas par la couleur seule.
- **Gomme** : dans la barre d'outils à côté de la feuille, en plus du bouton du stylet.
- **Écriture et reconnaissance** : l'écriture reste telle quelle, la formule s'affichera à côté. Rien n'est remplacé sans l'utilisateur.
- **Conséquence** : `tool/essai_appareil.sh` bascule encore le mode de l'appareil, sans effet sur l'app ; essais des supports par les réglages.
