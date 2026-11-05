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

## Contrastes mesurés (2026-11-05, `app/test/ui/theme_test.dart`, formule WCAG 2.2)

Graine `#1B2A4A`, `ColorScheme.fromSeed`. Seuils : texte 4,5:1, contour 3:1.

| Paire | Clair | Sombre |
|---|---|---|
| onSurface / surface | 16,32 | 14,39 |
| onSurfaceVariant / surface | 8,92 | 10,92 |
| primary / surface | 6,16 | 10,90 |
| tertiary / surface | 6,12 | 10,87 |
| onPrimary / primary | 6,49 | 7,69 |
| onSecondaryContainer / secondaryContainer | 7,26 | 7,26 |
| onError / error | 6,46 | 7,72 |
| outline / surface | 4,24 | 5,85 |

Source de la formule : https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio
