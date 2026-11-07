# ADR 0026 — Comprendre l'écriture réelle

- **Date** : 2026-11-07 · **Statut** : accepté
- **Constat** (lu sur le Pad 7) : `\frac{1}{4}(x)=e^x+2` pour `f(x)=e^x+2` ; `f^1(x)=` pour `f'(x)=` ; `g^((x))=0` pour `g(x)=0` ; `5 0^x` pour `5e^x` ; deux lignes dans une `matrix`.
- **Deuxième relevé** : `\alpha + \binom{2 5}{-1 -3} =` pour `det(…)=` ; `A(1/2)` pour `A(1;2)`.
- **Lignes** : on sépare les lignes avant de lire, sauf si un trait les relie (parenthèse, accolade, barre de fraction). Une queue de `g` ne fait plus d'une ligne la suite d'une autre.
- **Redressement** : `redresserLecture` corrige, après le modèle, ce qui n'aurait aucun sens en maths. Jamais ce qui en a un : `10^x`, `3(x)=9`, `9(x+1)=3` restent. Le texte corrigé reste visible et modifiable.
- **Limite** : ces règles viennent d'une seule main. Chaque nouvelle confusion relevée s'ajoute avec sa lecture réelle en test.
- **Résultat** : sous la ligne si c'est libre, sinon à droite.
- **Non retenu** : réentraîner le modèle : hors de portée pour l'instant.
