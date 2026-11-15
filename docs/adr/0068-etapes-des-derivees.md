# 0068 — Étapes des dérivées

Date : 2026-11-15 · Statut : accepté (Antsa : « Oui, les dérivées »)

**Décision.** Sur `f'(x)=` (sous une fonction définie) ou `\frac{d}{dx}(…)`, « étapes » montre :
la fonction ; la forme reconnue par Giac (`sommet`, `feuille`) ; u et v, puis u' et v' ; la formule du
cours (somme, nombre × u, produit, quotient, 1/u, uⁿ, √u, sin u, cos u, eᵘ, ln u) ; la formule
remplie ; le résultat de Giac, sous sa forme la plus courte entre `normal` et `factor`. Les dérivées
usuelles (xⁿ, sin x, eˣ…) tiennent en une ligne.

**Limites assumées.** Une seule formule par calcul : u' et v' sont donnés par Giac, sans leur propre
détail. Rien pour tan, les exposants qui dépendent de x, la dérivée seconde ou `f'(2)`.

**Vérifié.** 18 formes calculées par le vrai Giac (réponses enregistrées), conclusions égales aux
dérivées faites à la main avec les formules du cours ;
https://eduscol.education.gouv.fr/document/24553/download
