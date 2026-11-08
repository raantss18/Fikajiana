# ADR 0054 — Arithmétique écrite comme au tableau

- **Date** : 2026-11-09 · **Statut** : accepté (vague 2 de `docs/recherche/couverture-calcul.md`)
- **Décision** : `division(a;b)` rend q et r avec a = bq + r et 0 ≤ r < b (q = ⌊a/b⌋, comme au lycée : −17 = 5×(−4) + 3) ; `quotient(a;b)`, `reste(a;b)` (Giac `iquo`, `irem`) ; `bezout(a;b)` rend u, v et d = pgcd (Giac `iegcd`) ; `a ≡ b [n]`, `(mod n)`, `\pmod{n}` dit vrai ou faux (`irem(a−b,n)==0`) ; `A_n^k` vaut `perm(n,k)`.
- **Écriture à la main** : `reste`, `division`, `bezout` s'ajoutent aux mots reconnus à leur silhouette ; `quotient` non : trop proche de `premier` (écart 0,46 contre 0,71, `mots_test`), il reste au clavier et lu par le modèle. `≡`, `(mod n)` et `\binom` (colonne entre parenthèses) s'écrivent à la main.
- **Écarté pour l'instant** : résoudre une congruence à inconnue (`3x ≡ 2 [7]`) : refusée avec un message, à faire.
- **Vérifié** : banc de la feuille contre SymPy (`docs/TODO.md`).
