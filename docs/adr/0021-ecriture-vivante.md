# ADR 0021 — Écriture vivante : rature, fractions redressées, résultat animé

- **Date** : 2026-11-06 · **Statut** : accepté (choix d'Antsa), seuils à régler au vrai stylet
- **Rature** : au moins 4 retours sur un axe et 3,2 fois plus de chemin que de place (ou 3 et 4 fois) **et** des traits couverts pour moitié. Sans rien dessous, c'est de l'écriture. Géométrie seule, sans modèle. Annuler la défait d'un coup.
- **Résultat raturé** : efface tout le calcul, car un résultat seul reviendrait au calcul suivant.
- **Fraction** : `1/3` lu **et** un trait droit montant trouvé : les traits de la personne se déplacent. Annuler remet tout. Si les signes ne correspondent pas à la lecture, rien ne bouge. Revient sur « pas de correction automatique » d'ADR 0013, pour ce seul cas.
- **Animations** : 340 ms pour une rature ou un déplacement, 260 à 1000 ms pour écrire un résultat. Coupées si l'appareil le demande. Un résultat déjà présent à l'ouverture ne se réécrit pas.
- **Trait** : au doigt, épaisseur simulée d'après la vitesse (`simulatePressure` de `perfect_freehand`) ; au stylet, sa pression. Bouts affinés.
- **Limite** : `(x+1)/2` ne se redresse pas ; seule une fraction d'un nombre ou d'une lettre sur un nombre ou une lettre.
- **À vérifier** : seuils de rature et rendu au vrai stylet et au doigt ; fréquence réelle de `1/3` lu avec une barre par le modèle.
