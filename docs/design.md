# Design — Fikajiana (orientation, à détailler en tranche T4)

> Méthode : skills `design:design-system` (jetons → composants → motifs), `vgv-ai-flutter-plugin:material-theming`,
> `vgv-ai-flutter-plugin:accessibility`, `a11y-enforcer:contrast`. Maquettes dans Penpot (MPL-2.0).

- **Idée** : « la feuille du mathématicien » : papier calme (quadrillage 5 mm discret), encre bleu nuit, résultats
  dans une couleur d'accent ; l'interface s'efface devant l'écriture.
- **Typographie** : texte en police libre (OFL) à choisir ; maths rendues KaTeX (polices KaTeX, MIT).
- **Couleur** : Material 3, schéma dérivé d'une graine ; clair et sombre (feuille ardoise) ; contrastes ≥ 4,5:1
  calculés et notés ici ; la couleur n'est jamais seule (icône ou texte avec).
- **Cibles** ≥ 48 dp ; outils géométrie ≥ 56 dp sur tablette.
- **Mouvement** : retours ≤ 200 ms ; aucune animation si l'appareil le demande.
- **Anti-défauts** : jamais de résultat sans montrer ce qui a été compris ; jamais d'action destructive sans annuler.
