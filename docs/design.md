# Design — Fikajiana

> Méthode : skills `design:design-system` (jetons → composants → motifs), `vgv-ai-flutter-plugin:material-theming`,
> `vgv-ai-flutter-plugin:accessibility`, `a11y-enforcer:contrast`. Maquettes dans Penpot (MPL-2.0).

- **Idée** : « la feuille du mathématicien » : papier calme (quadrillage 5 mm discret), encre brun-noir, résultats
  dans une couleur d'accent ; l'interface s'efface devant l'écriture.
- **Typographie** : texte en police libre (OFL) à choisir ; maths rendues KaTeX (polices KaTeX, MIT).
- **Couleur** : Material 3, rôles neutres dérivés de l'orange, rôles de couleur fixés ci-dessous ; clair et sombre (feuille ardoise) ; contrastes ≥ 4,5:1
  calculés et notés ici ; la couleur n'est jamais seule (icône ou texte avec).
- **Cibles** ≥ 48 dp ; outils géométrie ≥ 56 dp sur tablette.
- **Mouvement** : retours ≤ 200 ms ; aucune animation si l'appareil le demande.
- **Anti-défauts** : jamais de résultat sans montrer ce qui a été compris ; jamais d'action destructive sans annuler.

## Barre de qualité (reprise de zanakiantsa, academik, COMIMa)

- Chaque écran s'adapte : commandes en bas en portrait, à côté en paysage ; aucune orientation imposée (Android 16 l'ignore sur grand écran).
- Tester chaque écran sur largeur téléphone et tablette, sur chaque support ; WCAG 2.2 AA, cibles ≥ 48 dp.
- Pas de numéro de version dans l'interface, sauf dans Réglages → Mises à jour.
- Jamais d'action destructive sans annuler ; jamais de résultat sans montrer ce qui a été compris.

## Identité (ADR 0010, 2026-11-05)

- **Marque** : un π tracé à la main, à l'encre, sur une tache orange avec une tache et des gouttes bleu ciel et saumon.
  Sources : `design/marque/`, générées par `tool/generer_marque.py` ; même tracé dans `app/lib/ui/theme/marque.dart`.
- **Où** : icône, états vides. La feuille d'écriture reste calme : papier, encre, quadrillage discret.
- **Résultats** : couleur d'accent `tertiary`, toujours avec le texte du résultat, jamais la couleur seule.

| Jeton | Valeur | Usage |
|---|---|---|
| `orange` / `ciel` / `saumon` | `#F4A23C` / `#1E9FD8` / `#EC8A80` | marque et décor seulement, jamais pour du texte |
| `papier` / `encre` | `#FFFBF4` / `#2A1E18` | surface et texte, clair |
| `ardoise` / `craie` | `#1B1613` / `#F2E9E1` | surface et texte, sombre |
| `primary` | `#006A9A` / `#8BD0F5` | actions (clair / sombre) |
| `secondary` | `#A33F36` / `#FFB4AA` | second plan (clair / sombre) |
| `tertiary` | `#8A5000` / `#FFB866` | résultats (clair / sombre) |

## Supports d'écriture (ADR 0012)

Feuille blanche `#FFFFFF`, cahier à grands carreaux (Seyès, 8 mm, interlignes de 2 mm, marge rouge) et à petits carreaux (5 mm)
`#FFFEFA`, tableau noir `#22282B`. Longueurs sur la base nominale de 160 dp par pouce : pas exactes au millimètre sur tous les écrans.

| Rang | Papier | Contraste (feuille / cahier) | Tableau noir | Contraste |
|---|---|---|---|---|
| 1 | bleu `#0B3D91` | 10,04 / 9,95 | craie blanche `#F5F2E8` | 13,33 |
| 2 | noir `#1A1A1A` | 17,40 / 17,25 | craie jaune `#FFE27A` | 11,67 |
| 3 | rouge `#C62828` | 5,62 / 5,57 | craie bleue `#8FD3FF` | 9,19 |
| 4 | vert `#1B7A3D` | 5,39 / 5,34 | craie rose `#FFB3C1` | 8,87 |

Police : Nunito (OFL), `app/assets/polices/`.

## Contrastes mesurés (2026-11-05, `app/test/ui/theme_test.dart`, formule WCAG 2.2)

Seuils : texte 4,5:1, contour 3:1.

| Paire | Clair | Sombre |
|---|---|---|
| onSurface / surface | 15,69 | 14,96 |
| onSurfaceVariant / surface | 9,03 | 10,56 |
| primary / surface | 5,77 | 10,62 |
| secondary / surface | 6,13 | 10,56 |
| tertiary / surface | 6,31 | 10,51 |
| onPrimary / primary | 5,95 | 7,78 |
| onTertiary / tertiary | 6,51 | 7,71 |
| onPrimaryContainer / primaryContainer | 10,39 | 7,32 |
| onSecondaryContainer / secondaryContainer | 12,82 | 7,20 |
| onTertiaryContainer / tertiaryContainer | 13,30 | 7,19 |
| onError / error | 6,46 | 7,72 |
| outline / surface | 4,34 | 5,65 |

Source de la formule : https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio
