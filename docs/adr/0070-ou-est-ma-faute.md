# 0070 — « Où est ma faute ? »

Date : 2026-11-15 · Statut : accepté (Antsa : « Trouve une idée innovante »)

**Contexte.** « Vérifier ma copie » (ADR 0062) dit où une démarche se trompe, pas pourquoi.

**Décision.** Pour chaque ligne fausse, Giac écrit la ligne qu'aurait donnée chaque faute d'un petit
catalogue : double produit oublié, facteur distribué au seul premier terme, moins devant une parenthèse
appliqué au seul premier terme, terme changé de côté sans changer de signe (les nombres vers la droite,
les termes en x vers la gauche), soustraire / multiplier / diviser à l'envers au lieu de diviser, solution
de mauvais signe. La piste n'est donnée que si l'une de ces lignes dit **exactement** la même chose que
celle de l'élève (mêmes solutions, ou différence nulle) ; sinon rien. La ligne juste reste cachée derrière
« Voir la ligne juste » : on cherche d'abord seul.

**Vérifié.** 13 copies passées au vrai Giac : 11 pistes justes, 2 copies hors catalogue sans piste.
Le choix des fautes du catalogue est un jugement d'enseignant, **non vérifié** par une étude.
