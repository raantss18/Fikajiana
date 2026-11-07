# Changelog

Une ligne par changement, en français et en anglais.

## [Non publié]

- Une fois le stylet utilisé, la main ne fait plus que déplacer la page, et ne bouge plus la feuille pendant l'écriture. Un réglage permet d'écrire aussi au doigt. / Once the stylus has been used, your hand only moves the page, and no longer shifts the sheet while you write. A setting lets you write with a finger too.

## [0.7.1] — 2026-11-07

### Message fr

Fini le petit ? et le petit cercle : une lueur passe sous ton écriture pendant la lecture, et un trait ondulé montre ce qui reste à vérifier. Touche-le pour voir ce qui a été lu, puis corriger ou effacer.

### Message en

No more small ? or spinner: a glow passes under your writing while it is read, and a wavy underline shows what needs checking. Tap it to see what was read, then correct or erase it.

### Changements

- Quand une écriture reste à vérifier, un trait ondulé remplace le petit `?` : touchez-le pour voir ce qui a été lu, corriger ou effacer. La lecture se voit par une lueur sous l'écriture, plus par un cercle. / When writing needs checking, a wavy underline replaces the small `?`: tap it to see what was read, correct or erase it. Reading now shows as a glow under your writing, not a spinner.

## [0.7.0] — 2026-11-07

### Message fr

Écris `x^2+y^2=9` ou `(\cos(t),\sin(t))` sur la feuille et touche Tracer. Enregistre ta feuille, ton graphe ou ta figure en image ou en PDF, à l'endroit de ton choix. Les Outils de la Feuille portent maintenant leur nom.

### Message en

Write `x^2+y^2=9` or `(\cos(t),\sin(t))` on the sheet and tap Plot. Save your sheet, graph or figure as an image or a PDF, wherever you choose. The sheet's Tools now show their names.

### Changements

- Une équation en x et y, une courbe paramétrée ou polaire se trace depuis la Feuille, avec un bouton nommé Tracer et un crayon pour corriger la lecture. / An equation in x and y, a parametric or polar curve can be plotted from the sheet, with a named Plot button and a pencil to correct the reading.
- Exporter en PNG ou en PDF : la Feuille entière, même plus grande que l'écran, le Graphe avec toute sa légende, la Figure. / Export as PNG or PDF: the whole sheet, even larger than the screen, the graph with its full legend, the figure.
- Les Outils de la Feuille sont une liste de commandes nommées. / The sheet's Tools are a list of named commands.

## [0.6.1] — 2026-11-07

### Message fr

La rature marche enfin comme on la fait au stylet : un zigzag rapide efface du premier coup, même sur toute une expression ou en partant du résultat. Et la racine se lit mieux dans les résultats : √29 ne ressemble plus à (29.

### Message en

Scribbling now works the way you really do it with a stylus: a quick zigzag erases the first time, even across a whole expression or starting on the result. Roots are easier to read in results too: √29 no longer looks like (29.

### Changements

- On peut commencer un trait sur un résultat ou sur un `?` : il s'écrit ou rature, et toucher le résultat ouvre toujours sa correction. / You can start a stroke on a result or a `?`: it writes or scribbles out, and tapping the result still opens its correction.
- La rature au stylet est mieux reconnue : un zigzag naturel efface du premier coup, même rapide ou sur toute une expression. / Scribbling with a stylus is recognised better: a natural zigzag erases the first time, even a quick one or across a whole expression.
- Le signe de la racine laisse de la place au nombre : `√29` ne se confond plus avec `(29`. / The root sign leaves room for the number: `√29` no longer looks like `(29`.

## [0.6.0] — 2026-11-06

### Message fr

L'écriture prend vie : gribouille sur ce que tu as écrit et cela s'efface en douceur, 1/3 glisse vers une vraie fraction avec tes propres traits, et le résultat s'écrit sous tes yeux. Au doigt, le trait a maintenant des pleins et des déliés.

### Message en

Writing comes alive: scribble over what you wrote and it gently erases, 1/3 slides into a real fraction with your own strokes, and the result writes itself before your eyes. With a finger, strokes now vary in width.

### Changements

- Gribouiller sur ce qu'on a écrit l'efface, en douceur, et le calcul se refait quand on réécrit. Annuler reste à portée pendant quelques secondes. / Scribbling over your writing erases it gently, and the calculation runs again when you rewrite. Undo stays at hand for a few seconds.
- `1/3` écrit en ligne glisse vers une vraie fraction, avec vos propres traits. Annuler remet tout en place. / `1/3` written inline slides into a real fraction, with your own strokes. Undo puts everything back.
- Le résultat s'écrit trait par trait, comme une main rapide ; l'animation se coupe si l'appareil le demande. / The result writes itself stroke by stroke, like a quick hand; the animation stops if the device asks for it.
- Au doigt, le trait a maintenant des pleins et des déliés ; au stylet, ses bouts s'affinent. / With a finger, strokes now vary in width; with a stylus, their ends taper.

## [0.5.0] — 2026-11-06

### Message fr

Le Graphe trace bien plus que des fonctions : un cercle avec x^2+y^2=9, une courbe paramétrée avec (cos(t), sin(t)), une cardioïde avec r=1+cos(θ). Le tableau de valeurs lit tes fonctions, et les Outils du Graphe disent enfin leur nom.

### Message en

The Graph now plots much more than functions: a circle with x^2+y^2=9, a parametric curve with (cos(t), sin(t)), a cardioid with r=1+cos(θ). The table of values reads your functions, and the Graph's Tools now say their names.

### Changements

- Courbes implicites : `x^2+y^2=4`, `y^2=x`, `x=3`. / Implicit curves: `x^2+y^2=4`, `y^2=x`, `x=3`.
- Courbes paramétrées : `(\cos(t),\sin(t))` ou `x=…,y=…`, avec un domaine facultatif `, t \in [a,b]`. / Parametric curves: `(\cos(t),\sin(t))` or `x=…,y=…`, with an optional range `, t \in [a,b]`.
- Courbes polaires : `r=1+\cos(\theta)`. / Polar curves: `r=1+\cos(\theta)`.
- Tableau de valeurs des fonctions : début et pas au choix. / Table of values for functions: choose the start and the step.
- Un toucher lit aussi un point sur ces courbes. / A tap also reads a point on these curves.
- Outils du Graphe : une liste de commandes nommées. / Graph Tools: a list of named commands.

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
