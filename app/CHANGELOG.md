# Changelog

Une ligne par changement, en français et en anglais.

## [Non publié]

- Gribouiller sur ce qu'on a écrit l'efface, en douceur, et le calcul se refait quand on réécrit. Annuler reste à portée pendant quelques secondes. / Scribbling over your writing erases it gently, and the calculation runs again when you rewrite. Undo stays at hand for a few seconds.
- `1/3` écrit en ligne glisse vers une vraie fraction, avec vos propres traits. Annuler remet tout en place. / `1/3` written inline slides into a real fraction, with your own strokes. Undo puts everything back.
- Le résultat s'écrit trait par trait, comme une main rapide ; l'animation se coupe si l'appareil le demande. / The result writes itself stroke by stroke, like a quick hand; the animation stops if the device asks for it.
- Au doigt, le trait a maintenant des pleins et des déliés ; au stylet, ses bouts s'affinent. / With a finger, strokes now vary in width; with a stylus, their ends taper.

## [0.4.0] — 2026-11-06

### Message fr

La Géométrie s'explique toute seule : chaque outil a son nom et un dessin clair, et une barre dit quoi toucher. Ajoute polygones, arcs, ellipses, symétries, rotations, mesures, curseurs et lieux. Demande ce qui lie deux objets. Le Menu crée une nouvelle feuille, un graphe ou une figure, et l'Historique les garde tous.

### Message en

Geometry now explains itself: each tool has a name and a clear drawing, and a bar says what to tap. Add polygons, arcs, ellipses, reflections, rotations, measures, sliders and loci. Ask what links two objects. The Menu creates a new sheet, graph or figure, and History keeps them all.

### Changements

- Boîte à outils rangée par familles, chaque outil avec son nom et son dessin. / Toolbox sorted by family, each tool with its name and drawing.
- 40 outils : demi-droite, vecteur, tangente, arcs, polygones, coniques, cinq transformations, mesures, curseur, lieu, relation. / 40 tools: ray, vector, tangent, arcs, polygons, conics, five transformations, measures, slider, locus, relation.
- Un point touché sur un objet y reste ; sur un croisement, il devient l'intersection ; près de la grille, il s'y aimante. / A point tapped on an object stays on it; on a crossing, it becomes the intersection; near the grid, it snaps to it.
- Glisser construit, avec un aperçu ; un objet entier se déplace. / Dragging builds, with a preview; a whole object can be moved.
- Liste des objets avec équations et valeurs ; nom, couleur, pointillé, masquer, coordonnées. / Object list with equations and values; name, colour, dashes, hide, coordinates.
- Annuler et refaire ; grille et axes au choix. / Undo and redo; optional grid and axes.
- Menu : nouvelle feuille, nouveau graphe, nouvelle figure ; l'Historique les garde tous. / Menu: new sheet, new graph, new figure; History keeps them all.

## [0.3.0] — 2026-11-06

### Message fr

La Géométrie est là : pose des points, trace droites, cercles, milieux, médiatrices et intersections, puis déplace un point et toute la figure suit. L'Historique garde toutes tes feuilles : commence-en une nouvelle, reviens à une ancienne.

### Message en

Geometry is here: place points, draw lines, circles, midpoints, bisectors and intersections, then move a point and the whole figure follows. History keeps all your sheets: start a new one, go back to an old one.

### Changements

- Géométrie dynamique : point, segment, droite, cercle, milieu, médiatrice, bissectrice, parallèle, perpendiculaire, intersection. / Dynamic geometry: point, segment, line, circle, midpoint, perpendicular bisector, angle bisector, parallel, perpendicular, intersection.
- Déplacer un point recalcule tout ; une construction impossible disparaît, puis revient. / Moving a point recalculates everything; an impossible construction disappears, then comes back.
- Historique : plusieurs feuilles, gardées sur l'appareil ; ta feuille actuelle est reprise. / History: several sheets, kept on the device; your current sheet is carried over.

## [0.2.0] — 2026-11-06

### Message fr

Le Graphe est là : écris une fonction, touche l'icône à côté d'elle, et sa courbe s'affiche, glissable et zoomable. Plusieurs courbes à la fois, coupées proprement aux asymptotes, et un toucher lit les coordonnées d'un point.

### Message en

The Graph is here: write a function, tap the icon next to it, and its curve appears, ready to pan and zoom. Several curves at once, cleanly cut at asymptotes, and a tap reads the coordinates of a point.

### Changements

- Tracer `f(x)=x^2`, `y=\sin(x)` ou une expression de `x`, depuis la feuille ou le Graphe. / Plot `f(x)=x^2`, `y=\sin(x)` or an expression in `x`, from the sheet or the Graph.
- Glisser, pincer, boutons de zoom ; plusieurs courbes numérotées ; lire un point en le touchant. / Pan, pinch, zoom buttons; several numbered curves; read a point by tapping it.
- `y=2x+1` est une fonction à tracer, plus une équation en `x`. / `y=2x+1` is a function to plot, no longer an equation in `x`.

## [0.1.1] — 2026-11-06

### Message fr

La feuille prend tout l'écran : tout se range dans deux boutons, Menu et Outils. Un nouveau calcul n'efface plus les réponses. La solution d'une équation s'écrit à la main dessous, et deux boutons basculent entre valeur exacte et approchée, degrés et radians. Toucher un résultat pour corriger ce qui a été lu.

### Message en

The sheet fills the screen: everything sits in two buttons, Menu and Tools. A new calculation no longer erases answers. The solution of an equation is handwritten below it, and two buttons switch between exact and approximate values, degrees and radians. Tap a result to correct what was read.

### Changements

- La feuille occupe tout l'écran ; tout se range dans deux boutons, Menu et Outils. / The sheet fills the screen; everything sits in two buttons, Menu and Tools.
- Une équation : la solution s'écrit à la main dessous, `x = 1`. / An equation: the solution is handwritten below it, `x = 1`.
- Un nouveau calcul n'efface plus les réponses précédentes. / A new calculation no longer erases earlier answers.
- Plus de panneau de lecture : toucher un résultat pour vérifier et corriger ce qui est lu. / No more reading panel: tap a result to check and correct what was read.
- Boutons exact ou approché, degrés ou radians ; `sin(π)` et `ln(5)` donnent un résultat. / Exact or approximate and degrees or radians toggles; `sin(π)` and `ln(5)` give a result.

## [0.1.0] — 2026-11-06

### Message fr

Première version d'essai : écris un calcul à la main, l'app le lit, le calcule et écrit le résultat après le signe égal. Vérifie ce qui est lu : la lecture se trompe encore souvent. Pour lire l'écriture, télécharge le modèle dans les réglages.

### Message en

First test version: write a calculation by hand, the app reads it, computes it and writes the result after the equals sign. Check what is read: recognition is still often wrong. To read handwriting, download the model in the settings.

### Changements

- Écrire sur une feuille blanche, un cahier ou un tableau noir, avec des stylos de couleur et une gomme. / Write on a blank sheet, a notebook or a blackboard, with coloured pens and an eraser.
- Trait à pression ; maintenir le stylet à la fin d'un trait le transforme en ligne, cercle, triangle ou rectangle. / Pressure-sensitive strokes; holding the stylus at the end of a stroke turns it into a line, circle, triangle or rectangle.
- Page sans bord : glisser et zoomer. / Borderless page: pan and zoom.
- Écrire `2+3=` : l'app lit, calcule et écrit le résultat à la main après le signe égal. / Write `2+3=`: the app reads, computes and handwrites the result after the equals sign.
- La feuille est gardée sur l'appareil ; saisie au clavier possible. / The sheet is kept on the device; keyboard entry is available.
