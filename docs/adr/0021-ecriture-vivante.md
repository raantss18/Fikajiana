# ADR 0021 — Écriture vivante : rature, fractions redressées, résultat animé

- **Date** : 2026-11-06 · **Statut** : accepté (choix d'Antsa), seuils relevés au vrai stylet sur le Pad 7 (0.6.1)
- **Rature** : sur un axe, 8 retours et 1,7 fois plus de chemin que de place, ou 6 et 2,2, ou 4 et 3,2, ou 3 et 4 ; **et** des traits couverts à 35 %. Une rature hésitante (4 retours et 2) compte seulement si elle couvre 70 % d'un trait : on n'écrit pas sur ce qu'on vient d'écrire. Sans rien dessous, c'est de l'écriture. Géométrie seule, sans modèle. Annuler la défait d'un coup.
- **Résultat raturé** : efface tout le calcul, car un résultat seul reviendrait au calcul suivant.
- **Fraction** : `1/3` lu **et** un trait droit montant trouvé : les traits de la personne se déplacent. Annuler remet tout. Si les signes ne correspondent pas à la lecture, rien ne bouge. Revient sur « pas de correction automatique » d'ADR 0013, pour ce seul cas.
- **Animations** : 340 ms pour une rature ou un déplacement, 260 à 1000 ms pour écrire un résultat. Coupées si l'appareil le demande. Un résultat déjà présent à l'ouverture ne se réécrit pas.
- **Trait** : au doigt, épaisseur simulée d'après la vitesse (`simulatePressure` de `perfect_freehand`) ; au stylet, sa pression. Bouts affinés.
- **Limite** : `(x+1)/2` ne se redresse pas ; seule une fraction d'un nombre ou d'une lettre sur un nombre ou une lettre.
- **Mesure** (Pad 7, Antsa, 2026-11-07) : ratures à 6-9 retours et rapport 1,9 à 3,5 ; écriture à 5 retours au plus (`m`). 3 ratures sur 5 manquées en 0.6.0, 3 sur 10 au premier réglage.
- **À vérifier** : seuils de rature au doigt, autres mains ; fréquence réelle de `1/3` lu avec une barre par le modèle.
