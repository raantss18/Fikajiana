# 0069 — Étapes des systèmes

Date : 2026-11-15 · Statut : accepté (Antsa : « Continue la conception et l'innovation »)

**Décision.** Un système linéaire de deux équations à deux inconnues, à coefficients numériques et à
solution unique, a ses étapes : chaque ligne réduite en a·x + b·y = c (E₁, E₂) ; puis, dans cet
ordre de préférence, une ligne à une seule inconnue résolue d'abord, la **substitution** si une
inconnue a pour coefficient 1 ou −1, la **combinaison** sinon (multiplicateurs divisés par le PGCD :
3E₁ − 2E₂ plutôt que 6E₁ − 4E₂) ; on remonte à l'autre inconnue ; S = {(x ; y)}. Méthodes du
programme de seconde. Au clavier, `{2x+y=5 ; x-y=1}` s'écrit en accolade.

**Limites.** Rien pour un déterminant nul (aucune ou une infinité de solutions), un système non
linéaire ou de trois équations.

**Vérifié.** 8 systèmes passés au vrai Giac ; solutions égales aux formules de Cramer.
https://eduscol.education.gouv.fr/document/24553/download
