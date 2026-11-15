# 0067 — Étapes des inéquations

Date : 2026-11-15 · Statut : accepté

**Contexte.** Les étapes (ADR 0061) ne couvraient que les équations. Une inéquation est la
même démarche, avec deux pièges que les élèves font : le sens qui change quand on divise par
un négatif, et le signe du trinôme hors ou entre les racines.

**Décision.** `etapesInequation` (degré 1 et 2, coefficients numériques) : tout à gauche,
isoler, diviser (« le sens change » si a < 0), puis l'intervalle ; au degré 2, a, b, c, Δ, les
racines, « signe de a à l'extérieur des racines », l'ensemble S (∪, ∅, ℝ, {x₀}). Notation
française des intervalles (`]a ; +∞[`). Giac fait chaque calcul ; rien au-delà du degré 2, ni
pour un encadrement (`1 < x < 3`).

**Vérifié.** Les 12 ensembles des tests sont ceux que rend `solve` du vrai Giac (2026-11-15).
Source du programme : https://eduscol.education.gouv.fr/document/24553/download
