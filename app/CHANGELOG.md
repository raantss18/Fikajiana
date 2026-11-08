# Changelog

Une ligne par changement, en français et en anglais.

## [Non publié]

- `lim` écrite par morceaux (borne, puis dénominateur) reste un seul calcul ; le `=` haut n'est plus perdu ; `B(2;-25)` et `C(2;7)` se lisent justes. / A `lim` written in pieces (bound, then denominator) stays one calculation; a raised `=` is no longer lost; `B(2;-25)` and `C(2;7)` are read correctly.
- Sans attendre le modèle : `sin(x)`, `cos`, `tan`, `ln 2`, `log`, `exp`, `det` écrits à la main, et les minuscules `s o l r p q g h m w` ; `k = 1` sous un Σ se lit enfin. / Without waiting for the model: handwritten `sin(x)`, `cos`, `tan`, `ln 2`, `log`, `exp`, `det`, and the lowercase `s o l r p q g h m w`; `k = 1` under a Σ is finally read.

## [1.0.6] — 2026-11-08

### Message fr

À côté de chaque ligne, 👍 dit que la lecture est juste et 👎 ouvre sa correction. Si vous le voulez (la question est posée une fois, case non cochée), vos lignes jugées partent sans votre nom pour améliorer la reconnaissance ; vous changez d'avis à tout moment dans les Réglages. Chaque signe se lit dès qu'il est écrit, toucher un signe propose ses autres lectures, et le Guide écrit ses exemples à la main.

### Message en

Next to each line, 👍 says the reading is right and 👎 opens its correction. If you wish (asked once, box unticked), your judged lines are sent without your name to improve recognition; change your mind at any time in Settings. Each sign is read as soon as it is written, touching a sign offers its other readings, and the Guide writes its examples by hand.

### Changements

- `A =` écrit devant une matrice la déclare, au lieu d'en calculer le déterminant. / `A =` written before a matrix declares it, instead of computing its determinant.
- Les dons consentis vont vers la plateforme du projet (Cloudflare), réglable dans les Réglages. / Consented donations go to the project's platform (Cloudflare), adjustable in Settings.
- Le Guide écrit ses exemples à la main, trait par trait. Après chaque mise à jour, une fois le modèle là, un petit tour montre les gestes de base sur des exemples. / The Guide writes its examples by hand, stroke by stroke. After each update, once the model is there, a short tour shows the basics on small examples.
- 👍 et 👎 à côté de chaque ligne lue : 👍 dit que la lecture est juste, 👎 ouvre sa correction ; ces lignes jugées aident la lecture sur l'appareil. / 👍 and 👎 next to each read line: 👍 says the reading is right, 👎 opens its correction; these judged lines help reading on the device.
- « Aider à améliorer la reconnaissance » (demandé une fois, non par défaut) : vos lignes jugées partent, sans votre nom, vers la plateforme choisie, sur le Wi-Fi seulement si vous le voulez ; retrait possible à tout moment. / "Help improve recognition" (asked once, off by default): your judged lines are sent, without your name, to the chosen platform, on Wi-Fi only if you want; withdrawal possible at any time.

- Le petit modèle par signe, s'il est embarqué, lit un signe que le tracé seul ne reconnaît pas. / The small per-sign model, when bundled, reads a sign the strokes alone do not recognise.

- Chaque signe se lit dès qu'il est écrit : une ligne déjà comprise se lit plus vite à la pause. / Each sign is read as soon as it is written: a line already understood is read faster at the pause.
- Dans « Corriger », toucher un signe d'une ligne lue propose ses autres lectures ; le choix est retenu sur l'appareil. / In "Correct", touching a sign of a read line offers its other readings; the choice is remembered on the device.

## [1.0.5] — 2026-11-07

### Message fr

L'écriture se lit encore plus souvent sur son tracé, sans attendre le modèle : lettres minuscules, fractions, racines, nombres à virgule. Un « n » n'est plus jamais pris pour un 4, et une limite qui n'existe pas s'écrit « pas de limite ».

### Message en

Handwriting is read from its strokes even more often, without waiting for the model: lowercase letters, fractions, square roots, decimal numbers. An "n" is never taken for a 4 anymore, and a limit that does not exist is written "no limit".

### Changements

- Une limite qui n'existe pas s'écrit « pas de limite » au lieu d'une erreur. / A limit that does not exist is written "no limit" instead of an error.
- La lecture au tracé lit aussi les minuscules usuelles (x, y, n, t, e, f…), π, `f'`, les fractions, les racines et les nombres à virgule ; dans le doute, le modèle lit toujours la ligne. / Stroke reading now also reads common lowercase letters (x, y, n, t, e, f…), π, `f'`, fractions, square roots and decimal numbers; when in doubt, the model still reads the line.

## [1.0.4] — 2026-11-07

### Message fr

Un Guide, dans le Menu, montre tout ce que l'app sait faire, avec une recherche et un bouton « Essayer ». Une somme Σ ou une limite écrites avec leurs bornes se lisent en entier et se calculent, et un « 9 » pris pour un « g » redevient un 9.

### Message en

A Guide, in the Menu, shows everything the app can do, with a search and a "Try" button. A Σ sum or a limit written with their bounds are read in full and computed, and a "9" taken for a "g" becomes a 9 again.

### Changements

- Un Guide, dans le Menu, présente tout ce que l'app sait faire, avec une recherche ; « Essayer » pose l'exemple sur la Feuille ou ouvre la Figure avec l'outil. / A Guide, in the Menu, shows everything the app can do, with a search; “Try” puts the example on the Sheet or opens the Figure with the tool.
- Une somme Σ écrite avec ses bornes (`5` dessus, `n = 0` dessous) se lit et se calcule. / A Σ sum written with its bounds (`5` above, `n = 0` below) is read and computed.
- « Relire la feuille » regroupe ce qui n'avait rien donné, sans toucher aux lignes corrigées. / "Read the sheet again" regroups what gave nothing, leaving corrected lines alone.
- Un `9` lu `g` redevient `9` s'il n'y a pas de fonction g. / A `9` read as `g` becomes `9` again when there is no function g.
- Les bornes d'une limite ou d'une somme (`x → 0` sous `lim`, `n = 0` et `5` autour d'un Σ) vont avec leur signe. / The bounds of a limit or a sum (`x → 0` under `lim`, `n = 0` and `5` around a Σ) go with their sign.
## [1.0.3] — 2026-11-07

### Message fr

La lecture est plus rapide : une ligne simple se lit sur son tracé, sans le modèle, et vos « 1 » et « 4 » sont reconnus. Une limite écrite « lim » au-dessus de « x → 0 » se comprend. « Le doigt écrit » se règle dans le panneau des stylos de la Feuille, et l'outil Main levée de la Figure trace au doigt comme au stylet.

### Message en

Reading is faster: a simple line is read from its strokes, without the model, and your "1" and "4" are recognised. A limit written "lim" above "x → 0" is understood. "Finger writes" is set in the Sheet's pen panel, and the Figure's Freehand tool draws with a finger as with a stylus.

### Changements

- Une ligne simple se lit sur son tracé, en quelques millisecondes, sans le modèle : `1+1`, `30×8=`, les cases et l'exposant d'une matrice. / A simple line is read from its strokes, in milliseconds, without the model: `1+1`, `30×8=`, matrix cells and exponent.
- `lim` écrit au-dessus de `x → 0` se comprend. / `lim` written above `x → 0` is understood.
- « Le doigt écrit » se règle dans le panneau Fond de la Feuille ; dans la Figure, l'outil Main levée trace au doigt comme au stylet. / "Finger writes" is set in the Sheet's Background panel; in the Figure, the Freehand tool draws with a finger as with a stylus.
## [1.0.2] — 2026-11-07

### Message fr

L'écriture se lit mieux sur téléphone : un « 1 » qui monte de tout en bas, les grandes parenthèses d'un point comme A(1;-1), et une barre de fraction ajoutée sous un calcul. Une lecture douteuse ne remplace plus votre écriture.

### Message en

Handwriting is read better on phones: a "1" that starts from the very bottom, the tall parentheses of a point such as A(1;-1), and a fraction bar added under a calculation. A doubtful reading no longer replaces your handwriting.

### Changements

- Mieux lu à la main : un `1` qui monte de tout en bas, les grandes parenthèses peu bombées, un `;` au point détaché ; une barre et un dénominateur ajoutés sous un calcul le prolongent. / Better read by hand: a `1` that starts from the very bottom, tall flat parentheses, a `;` with a detached dot; a bar and a denominator added under a calculation extend it.
- Une lecture douteuse ne remplace plus l'écriture au propre. / A doubtful reading no longer replaces the handwriting with a neat version.
## [1.0.1] — 2026-11-07

### Message fr

Les résultats s'écrivent dans une plus belle écriture manuscrite, et une valeur approchée se marque « ≈ ». Le résultat arrive plus vite dès qu'on trace le « = ». Une matrice se déclare sur la Feuille (`A=[1,2;3,4]`), puis `det(A)`, `A^-1` et `AX=B` se calculent dans les lignes suivantes.

### Message en

Results are written in a nicer handwriting, and an approximate value is marked "≈". The result comes faster as soon as the "=" is drawn. A matrix can be declared on the Sheet (`A=[1,2;3,4]`), then `det(A)`, `A^-1` and `AX=B` are computed on the next lines.

### Changements

- Les résultats s'écrivent dans une écriture manuscrite plus belle (police Caveat, SIL OFL). / Results are written in a nicer handwriting (Caveat font, SIL OFL).
- Une valeur approchée s'écrit avec `≈`, et le résultat arrive plus vite dès qu'on trace le `=`. / An approximate value is written with `≈`, and the result comes faster as soon as the `=` is drawn.
- `B=[5;6]` déclare B sans rien placer dans la Figure, et les matrices s'écrivent à la taille de la ligne. / `B=[5;6]` declares B without placing anything in the Figure, and matrices are written at line size.
- Une matrice se déclare sur la Feuille (`A=[1,2;3,4]` ou à la main), puis `det(A)`, `A^{-1}`, `AB`, et `AX=B` donne X. / A matrix can be declared on the Sheet (`A=[1,2;3,4]` or by hand), then `det(A)`, `A^{-1}`, `AB`, and `AX=B` gives X.

## [1.0.0] — 2026-11-07

### Message fr

Fikajiana 1.0 : chaque feuille a maintenant sa propre Figure, et une nouvelle feuille part d'une Figure vide. L'écriture se lit mieux : points `A(8;-1)`, déterminants, inverse d'une matrice, `e^x = 7`, et des mots comme « plot » ou « longueur ». Ce qui est lu s'écrit au propre, les lignes tapées aussi ; dans la Figure, un trait au stylet devient un segment, un rond un cercle, un triangle se redresse et ses sommets se nomment. La page s'arrête en haut et à gauche, comme un cahier.

### Message en

Fikajiana 1.0: each sheet now has its own Figure, and a new sheet starts with an empty Figure. Handwriting is read better: points `A(8;-1)`, determinants, matrix inverses, `e^x = 7`, and words such as "plot" or "longueur". What is read is written neatly, typed lines too; in the Figure, a stylus stroke becomes a segment, a round shape a circle, a triangle straightens and its vertices are named. The page stops at the top and on the left, like a notebook.

### Changements

- Barre épurée : Feuille et Figure en dessins en haut à gauche, Menu en haut à droite, liste des objets en bas à gauche de la Figure. / Cleaner bar: Sheet and Figure as drawings at the top left, Menu at the top right, object list at the bottom left of the Figure.

- Un document, c'est une feuille et sa Figure : nouvelle feuille, nouvelle Figure ; l'Historique n'a plus qu'une liste. Les figures d'avant rejoignent la feuille dont elles viennent. / A document is a sheet and its Figure: new sheet, new Figure; the History has a single list. Earlier figures join the sheet they came from.
- Mieux lus à la main : `A(8;-1)` et `B(5;8)`, `det` d'une matrice 2×2, `(…)^{-1}`, `e^x = 7` (le `=` n'est plus pris pour un `-`). `30×8` donne `= 240`. / Better read by hand: `A(8;-1)` and `B(5;8)`, `det` of a 2×2 matrix, `(…)^{-1}`, `e^x = 7` (the `=` is no longer taken for a `-`). `30×8` gives `= 240`.
- `⇒ plot` à côté d'une ligne propose de la tracer ; un mot comme « longueur » reste une note, sans être signalé. / `⇒ plot` next to a line offers to plot it; a word such as "longueur" stays a note, without being flagged.
- Tracer, Placer et Corriger s'écrivent à la main sur la Feuille, et les matrices aussi. / Plot, Place and Correct are handwritten on the Sheet, and so are matrices.
- Une seule création, « Nouveau document » : la feuille et sa Figure ensemble. `∫f(x)dx` se simplifie : `x³+x`, pas `3x³/3+x`. `plot(f(x))` écrit à la main se trace. / A single creation entry, "New document": the sheet and its Figure together. `∫f(x)dx` is simplified: `x³+x`, not `3x³/3+x`. Handwritten `plot(f(x))` can be plotted.
- Dans la Figure, un bouton discret nommé « 4 objets » ouvre la liste de tout ce qu'elle contient, courbes comprises ; la légende flottante ne gêne plus la vue (elle reste dans l'image exportée). / In the Figure, a discreet button named "4 objects" opens the list of everything it holds, curves included; the floating legend no longer blocks the view (it stays in the exported image).
- `AB =` écrit à la main donne la distance entre les points A et B de la feuille, même quand le modèle lit mal les deux lettres. / Handwritten `AB =` gives the distance between points A and B of the sheet, even when the model misreads the two letters.
- Une ligne tapée au clavier s'écrit à la main sur la Feuille, comme le reste : la question à l'encre de la feuille, la réponse en résultat. / A line typed on the keyboard is handwritten on the Sheet like everything else: the question in the sheet's ink, the answer as a result.
- Ce qui est lu s'écrit au propre à la place de votre encre (réglage « Mettre au propre »). / What is read is written neatly in place of your ink ("Write neatly" setting).
- Dans la Figure, au stylet : un trait devient un segment, un rond un cercle, un tracé fermé un triangle ou un quadrilatère ; les sommets sont nommés tout seuls. / In the Figure, with the stylus: a stroke becomes a segment, a round shape a circle, a closed path a triangle or quadrilateral; vertices are named automatically.
- `C : x^2+y^3=0` sur la Feuille est la courbe C de la Figure ; un nom déjà pris devient C₁. / `C : x^2+y^3=0` on the Sheet is curve C in the Figure; a name already taken becomes C₁.
- La page s'arrête en haut ; l'export PNG et PDF part de son coin. / The page stops at the top; PNG and PDF export start from its corner.

## [0.9.1] — 2026-11-07

### Message fr

Les commandes écrites à la main se comprennent : `premier(17)`, `développer((2x-1)(x-4))`… et `premier(17) = vrai` s'écrit à la main. `74×10^{-4}+85×10^8` donne un nombre décimal, pas une fraction. La Feuille s'arrête à gauche comme un cahier, et ce qui a été lu ne se réécrit plus dessus.

### Message en

Handwritten commands are understood: `premier(17)`, `développer((2x-1)(x-4))`… and `premier(17) = true` is written by hand. `74×10^{-4}+85×10^8` gives a decimal number, not a fraction. The Sheet stops on the left like a notebook, and what was read is no longer rewritten on it.

### Changements

- La Feuille s'arrête à gauche, comme un cahier, et va loin à droite : trois écrans de large ; vers le bas, elle ne s'arrête pas. / The Sheet stops on the left, like a notebook, and goes far to the right: three screens wide; downwards it never ends.
- Les commandes écrites à la main se comprennent : `premier(17)`, `développer((2x-1)(x-4))`, `factoriser(…)`… Dans le doute, Fikajiana propose les mots proches au lieu de deviner. / Handwritten commands are understood: `premier(17)`, `développer((2x-1)(x-4))`, `factoriser(…)`… When unsure, Fikajiana offers the closest words instead of guessing.
- `74×10^{-4}+85×10^8` donne `8 500 000 000,0074`, pas une fraction ; `premier(17) = vrai` s'écrit à la main ; un résultat ne sort plus de l'écran, et ce qui a été lu ne se réécrit plus sur la feuille. / `74×10^{-4}+85×10^8` gives `8 500 000 000.0074`, not a fraction; `premier(17) = true` is handwritten; a result no longer runs off the screen, and what was read is no longer rewritten on the sheet.

## [0.9.0] — 2026-11-07

### Message fr

Écris `det` d'une matrice, `moyenne(2;4;9)`, `factoriser(x^2-1)` ou `tangente(f;2)` : Fikajiana calcule et ajoute le `=` si tu l'as oublié, sans écrire sur ta feuille. Les points, vecteurs, matrices et normes se lisent mieux à la main, et `cercle(A;2)` ou `(AB)` se construisent dans la Figure d'un toucher. Le choix du fond est sur la Feuille.

### Message en

Write `det` of a matrix, `moyenne(2;4;9)`, `factoriser(x^2-1)` or `tangente(f;2)`: Fikajiana calculates and adds the `=` if you forgot it, without writing over your sheet. Points, vectors, matrices and norms are read better by hand, and `cercle(A;2)` or `(AB)` are built in the Figure with one tap. The background choice is on the Sheet.

### Changements

- Le `=` oublié s'écrit tout seul : `f'(x)` ou `det(…)` donne « = … » à droite, et un résultat ne se pose plus sur une autre écriture. / A forgotten `=` is written for you: `f'(x)` or `det(…)` gives “= …” on the right, and a result no longer lands on other writing.
- Nouvelles commandes, à la main ou au clavier : `développer`, `factoriser`, `simplifier`, `décomposer`, `premier`, `moyenne`, `médiane`, `variance`, `écart-type`, `arrondi(x;n)`, `pgcd`, `discriminant`, `tangente(f;a)` et le produit scalaire de deux vecteurs. / New commands, handwritten or typed: expand, factor, simplify, prime factors, primality, mean, median, variance, standard deviation, rounding, gcd, discriminant, tangent `tangente(f;a)` and the dot product of two vectors.
- Construire depuis la Feuille : `cercle(A;2)`, `cercle(A;B)`, `(AB)`, `[AB]`, `[AB)`, `I=milieu(A;B)`, `médiatrice(A;B)` se placent dans la Figure d'un toucher. / Build from the sheet: `cercle(A;2)`, `cercle(A;B)`, `(AB)`, `[AB]`, `[AB)`, `I=milieu(A;B)`, `médiatrice(A;B)` are placed in the Figure with one tap.
- Les matrices, les flèches de vecteur et les normes se lisent à partir de vos traits, case par case : `det` d'une matrice 3×3 écrite à la main se calcule. / Matrices, vector arrows and norms are read from your strokes, cell by cell: the `det` of a handwritten 3×3 matrix is calculated.
- La feuille retient vos points et vos valeurs : après `A(1;2)` et `B(5;-4)`, le vecteur `AB`, sa norme et la distance `AB` se calculent ; `a=2` définit `a`. / The sheet remembers your points and values: after `A(1;2)` and `B(5;-4)`, the vector `AB`, its norm and the distance `AB` are calculated; `a=2` defines `a`.
- Relire une ligne depuis son panneau. / Read a line again from its panel.
- Le bouton Fond, sur la Feuille, change le papier, le cahier ou le tableau sans passer par les Réglages. / The Background button on the sheet changes the paper, notebook or blackboard without going to Settings.
- Toucher sous une ligne montre toujours ce qui a été lu, même si elle n'affiche rien. / Tapping under a line always shows what was read, even if it displays nothing.
- Quand une lecture étonne, Fikajiana en cherche d'autres, garde la plus sensée et propose les autres d'un toucher. / When a reading looks odd, Fikajiana looks for others, keeps the most sensible one and offers the rest with one tap.

## [0.8.0] — 2026-11-07

### Message fr

Le calcul formel est plus sûr et plus complet. Dérive avec `f'(2)` ou `\frac{d}{dx}`, résous `x^2<4`, calcule un déterminant, un pgcd, une limite à droite, le terme général d'une suite. Corrige aussi des résultats faux : une intégrale écrite `\int_0^1` sans accolades perdait ses bornes. Chaque famille de calcul est vérifiée face à un second logiciel. Au clavier, tape comme tu écris : `x²`, `sin 2x`, `racine de 2`.

### Message en

Symbolic calculation is safer and more complete. Differentiate with `f'(2)` or `\frac{d}{dx}`, solve `x^2<4`, compute a determinant, a gcd, a one-sided limit, the general term of a sequence. Also fixes wrong results: an integral written `\int_0^1` without braces lost its bounds. Every family of calculation is checked against a second program. On the keyboard, type as you write: `x²`, `sin 2x`, `sqrt 2`.

### Changements

- Suites : `u_{n+1}=2u_n+1` avec `u_0=0` donne le terme général. / Sequences: `u_{n+1}=2u_n+1` with `u_0=0` gives the general term.
- Corrige des résultats faux : bornes d'intégrale sans accolades, déterminant écrit entre barres, noms de fonctions lus comme des produits de lettres. Ce qui n'est pas compris est refusé. / Fixes wrong results: integral bounds without braces, determinants written between bars, function names read as products of letters. What is not understood is refused.
- Dérivées, inéquations, limites à droite et à gauche, pgcd, ppcm, modulo, combinaisons, partie entière, logarithme de base b, transposée, conjugué, argument, pourcentage. / Derivatives, inequalities, one-sided limits, gcd, lcm, modulo, combinations, floor and ceiling, base-b logarithm, transpose, conjugate, argument, percent.
- `y=2x+1` laisse `y` libre pour la suite. / `y=2x+1` leaves `y` free for later.
- La feuille retient ce que vous définissez : après `f(x)=x+5`, `f'(x)` donne la dérivée, `f(2)` la valeur, et `f(x)=0` se résout. / The sheet remembers what you define: after `f(x)=x+5`, `f'(x)` gives the derivative, `f(2)` the value, and `f(x)=0` is solved.
- Le déterminant se calcule : `det` devant une matrice, ou une matrice entre barres. / Determinants are calculated: `det` before a matrix, or a matrix between bars.
- `A(1;2)` et un vecteur `AB` ou `u` avec ses coordonnées se placent en Géométrie d'un toucher. / `A(1;2)` and a vector `AB` or `u` with its coordinates can be placed in Geometry with one tap.
- Au clavier, tapez comme vous écrivez : `x^2+3x-5=0`, `x²`, `sin 2x`, `racine de 2`, `3,5` ou du LaTeX. L'aperçu montre ce qui est compris, et le bouton dit ce qui va se passer : Calculer, Résoudre en x ou Tracer. / On the keyboard, type as you write: `x^2+3x-5=0`, `x²`, `sin 2x`, `sqrt 2`, `3,5` or LaTeX. The preview shows what is understood, and the button says what will happen: Calculate, Solve for x or Plot.
- `sin 2x` écrit à la main est maintenant `sin(2x)`, et une intégrale `∫_0^1` garde ses bornes. / Handwritten `sin 2x` now means `sin(2x)`, and an integral `∫_0^1` keeps its bounds.
- Deux lignes écrites serrées ne se lisent plus comme une seule, et un résultat ne s'écrit plus sur la ligne d'en dessous. / Two lines written close together are no longer read as one, and a result no longer lands on the line below.
- La lecture comprend mieux une écriture réelle : un `f` ou un `g` à la main, l'apostrophe de `f'`, un `(x)` écrit haut, le `e` de `e^x`. / Reading understands real handwriting better: a handwritten `f` or `g`, the prime in `f'`, a raised `(x)`, the `e` in `e^x`.
- Deux espaces, toujours en vue : Feuille pour écrire et calculer, Figure pour les courbes et la géométrie, réunies sur les mêmes axes. Tracer et Placer y mènent. / Two spaces, always in sight: Sheet to write and calculate, Figure for curves and geometry, together on the same axes. Plot and Place lead there.

## [0.7.2] — 2026-11-07

### Message fr

Au stylet, ta main peut se poser tranquillement : elle n'écrit plus rien et ne bouge plus la feuille. Pour faire défiler, glisse simplement un doigt. Si tu veux aussi écrire au doigt, un réglage le permet.

### Message en

With a stylus, your hand can rest on the screen: it no longer writes or shifts the sheet. To scroll, just slide a finger. A setting lets you write with a finger too.

### Changements

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
