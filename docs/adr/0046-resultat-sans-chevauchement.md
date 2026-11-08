# ADR 0046 — Un résultat ne recouvre jamais une autre ligne

- **Date** : 2026-11-08 · **Statut** : accepté · complète l'ADR 0030
- **Contexte** : Pad 7 d'Antsa, après « Relire la feuille » : `= 81/2` de `9²/2` écrit sur `7⁹ = 40353607` ; une matrice 3×3 posée sous sa ligne touche la suivante.
- **Obstacles** : l'encre des autres lignes **et** les résultats déjà posés. Les résultats se posent de haut en bas, puis de gauche à droite ; chacun évite ceux d'avant. Un écart de 3 dp est gardé.
- **Ordre des essais** : place voulue, autre côté ; puis chacun décalé le long de sa ligne (à droite : vers le haut ou le bas en touchant la hauteur de la ligne ; dessous : vers la droite, sans dépasser la fin de la ligne) ; puis le tout à 80 %, 65 %, 50 % de la taille, jamais sous la hauteur minimale d'écriture (22 dp).
- **Sans place libre** : là où il gêne le moins (surface recouverte la plus petite) : la page est trop pleine pour faire mieux.
- **Regroupement** : un groupe orphelin rejoint d'abord sa propre ligne (`prolonge`), puis seulement une barre de fraction ou un grand signe au-dessus (`estDenominateur`, `estBorne`).
- **Vérifié** : `test/comprendre/placement_resultats_test.dart` (7 cas, tous en échec avant la correction). **Reste** : essai au vrai stylet.
