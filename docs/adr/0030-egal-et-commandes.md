# ADR 0030 — Le `=` oublié et les commandes en toutes lettres

- **Date** : 2026-11-07 · **Statut** : accepté
- **`=` oublié** : une ligne qui demande une valeur sans `=` (`f'(x)`, `det`, `moyenne(…)`) reçoit « = valeur » à droite, comme si on l'avait écrit. Une équation garde sa solution dessous, sans `=` (« x+3=4 = {1} » serait faux).
- **Place libre** : le résultat va à la place voulue ; s'il couvre une autre écriture, de l'autre côté (dessous ou à droite) ; si les deux sont prises, à la place voulue.
- **Commandes** : noms français ou anglais, accents et tirets ignorés, devant `(` : `développer`→`expand`, `factoriser`→`factor`, `simplifier`, `décomposer`→`ifactor`, `premier`→`isprime`, `moyenne`, `variance`, `écart-type` (population, division par n), `arrondi(x;n)`→`round`, `discriminant` (b²−4ac par `coeff`), `tangente(f;a)` (f définie plus haut). Commandes Giac : https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/doc/fr/cascmd_fr/
- **Médiane** : Giac rend la plus petite des deux valeurs centrales (banc, Pad 7 : 2 pour 1;2;3;4). On prend leur moyenne, convention usuelle : https://fr.wikipedia.org/wiki/M%C3%A9diane_(statistiques)
- **Listes** : `;` sépare ; sans `;`, la virgule sépare dans une liste statistique. `tangente(x)` reste la fonction tan.
- **Vérifié** : banc SymPy sur le Pad 7 (`tool/banc/references.py`, famille « commandes »). **Reste** : la variance d'échantillon (n−1) n'est pas proposée.
