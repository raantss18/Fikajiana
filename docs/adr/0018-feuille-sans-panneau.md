# 0018 — Feuille sans panneau, outils repliés, modes de calcul

- **Date** : 2026-11-06 · **Statut** : accepté (retour d'Antsa sur le Poco)
- **Lecture** : la transcription ne s'affiche plus en permanence, elle dérangeait. **Toucher le résultat** ouvre ce qui a été lu, pour vérifier et corriger :
  risque assumé : une erreur de lecture se voit moins. Ce qui ne se lit pas montre un petit `?`. Modifie l'ADR 0003.
- **Résultat** : écrit à la main après un `=`. Sous une équation ou un système, les solutions : `x = 1`, jamais `x+3=4 = {1}`, qui est faux. Solutions trigonométriques complètes (`all_trig_sol`). Sans `=`, rien.
- **Modes** : deux petits boutons dans les outils : `=` ou `≈`, `RAD` ou `DEG` (mode d'angle de Giac), gardés d'une fois sur l'autre. Une valeur que Giac rend telle quelle, comme `ln(5)`, se montre approchée.
- **Espace** : la feuille occupe tout l'écran, sans barre ni rail, sous les barres du système. Un bouton Menu (écrans, réglages) et un bouton Outils à la couleur du stylo. Le retour ← reste distinct : Feuille, dans le menu, ramène à l'accueil.
