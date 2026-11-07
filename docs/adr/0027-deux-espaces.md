# ADR 0027 — Deux espaces : Feuille et Figure

- **Date** : 2026-11-07 · **Statut** : accepté (demande d'Antsa), remplace la « vue des mêmes lignes » de l'ADR 0024
- **Pourquoi** : trois écrans (Feuille, Graphe, Géométrie) se ressemblaient sans se parler : une droite du Graphe n'existait pas en Géométrie.
- **Décision** : Feuille pour écrire et calculer ; Figure pour les courbes et les constructions, dans le même repère. Un sélecteur nommé reste toujours visible. Historique et Réglages restent dans le Menu.
- **Lien** : sur la Feuille, Tracer et Placer mènent à la Figure ; une ligne déjà tracée dit « Voir dans la Figure ».
- **Figure** : l'écran de Géométrie reçoit les courbes dessous, la légende et le tableau de valeurs. Toucher une courbe sans outil lit son point.
- **Limites** : les constructions ne s'accrochent pas encore aux courbes (intersection d'une droite et d'une courbe) ; courbes et objets restent dans deux fichiers d'une même figure.
