# ADR 0022 — Tracer depuis la Feuille, exporter en PNG et en PDF

- **Date** : 2026-11-07 · **Statut** : accepté, à essayer sur un appareil arm64 réel
- **Tracer** : une équation en x et y, `(x(t),y(t))` et `r=f(θ)` n'ont de sens que tracées : la Feuille propose Tracer et n'appelle pas Giac. `x^2=2`, `2y=4`, `x=3` et `r=2` restent des équations à résoudre. Limite : `x+y=3` ne se résout plus seule, seulement comme courbe.
- **Commande nommée** : le bouton dit « Tracer », avec un crayon à côté pour corriger une lecture fausse. Les Outils de la Feuille passent à une liste nommée (ADR 0019) ; seuls les stylos restent des pastilles, nommés pour le lecteur d'écran.
- **Export** : `RenderRepaintBoundary.toImage` (https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html), finesse ×3, côté limité à 4 096 pixels. Boutons exclus de l'image ; la légende du Graphe y est entière.
- **Feuille entière** : la page sans bord est photographiée par morceaux d'écran, à zoom 1, puis recollée, sous un voile. Dézoomer aurait réduit l'encre et non les formules.
- **PDF** : une page, l'image sur la largeur d'un A4, écrit en Dart avec `dart:io` (ISO 32000-1 : https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf). Aucune dépendance. Limites : image et non texte ; une très longue feuille n'est pas coupée en pages.
- **Enregistrer** : `ACTION_CREATE_DOCUMENT`, sans autorisation, l'emplacement est choisi par la personne (https://developer.android.com/training/data-storage/shared/documents-files). L'app n'envoie rien : un fichier ne quitte l'appareil que si la personne choisit un dossier en ligne (règle 5).
- **Écarté** : `pdf`, `share_plus` et `file_picker`, inutiles pour ce besoin (`CLAUDE.md`, « Léger »). Partager vers une autre app reste à faire si Antsa le demande.
- **Vérifié** : `qpdf --check` et `pdfinfo` sur les PDF sortis de l'émulateur ; Feuille plus large que l'écran, sans raccord visible.
