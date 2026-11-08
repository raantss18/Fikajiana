# ADR 0053 — Pas d'interpréteur Python

- **Date** : 2026-11-09 · **Statut** : accepté
- **Contexte** : la NumWorks embarque MicroPython 1.17 (<https://www.numworks.com/fr/graphique/manuel/python/>). L'étude `docs/recherche/couverture-calcul.md` (§ 4) a relevé les poids : MicroPython « 256k of code space » (<https://micropython.org/>), CPython officiel pour Android arm64, archive de 21 432 357 octets (<https://www.python.org/ftp/python/3.14.4/>).
- **Décision** (Antsa, 2026-11-09 : « on ne va pas faire du python ») : Fikajiana n'embarque aucun interpréteur Python. Tout le calcul passe par Giac, déjà embarqué.
- **Conséquence** : ne pas le reproposer ; les fonctions de la NumWorks qui passent par Python ne sont pas reprises.
