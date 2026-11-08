import 'dart:math' as math;
import 'dart:ui';

/// Reconnaît un signe isolé à partir de son tracé, sans modèle (ADR 0029).
///
/// Le modèle d'image lit des formules entières : seul, un chiffre le trompe.
/// Ici, on compare des nuages de points : la méthode $P de Vatavu, Anthony et
/// Wobbrock (ICMI 2012, https://depts.washington.edu/acelab/proj/dollar/pdollar.html),
/// réécrite ici. Les modèles sont dessinés pour Fikajiana, plus quelques formes
/// simplifiées relevées sur l'écriture d'Antsa.
const _points = 32;

typedef _Dessin = List<List<(double, double)>>;

const Map<String, List<_Dessin>> _chiffres = {
  '0': [
    [
      [
        (.5, 0),
        (.2, .1),
        (.1, .5),
        (.2, .9),
        (.5, 1),
        (.8, .9),
        (.9, .5),
        (.8, .1),
        (.5, 0),
      ],
    ],
    [
      [
        (.5, 0),
        (.3, .1),
        (.25, .5),
        (.3, .9),
        (.5, 1),
        (.7, .9),
        (.75, .5),
        (.7, .1),
        (.5, 0),
      ],
    ],
    [
      [
        (.5, 0),
        (.15, .15),
        (0, .5),
        (.15, .85),
        (.5, 1),
        (.85, .85),
        (1, .5),
        (.85, .15),
        (.5, 0),
      ],
    ],
    // Le `0` d'Antsa : commencé dedans, il se referme en dépassant (Pad 7).
    [
      [
        (0.23, 0.30),
        (0.04, 0.53),
        (0.03, 0.87),
        (0.18, 0.99),
        (0.42, 0.94),
        (0.69, 0.68),
        (0.85, 0.40),
        (0.83, 0.23),
        (0.64, 0.06),
        (0.36, 0.00),
        (0.13, 0.14),
        (0.02, 0.50),
        (0.04, 0.69),
      ],
    ],
  ],
  '1': [
    [
      [(0.00, 0.72), (0.33, 0.00), (0.33, 0.82), (0.38, 1.00), (0.44, 1.00)],
    ],
    [
      [(0.00, 0.89), (0.13, 0.42), (0.16, 0.00), (0.18, 0.66), (0.34, 0.97)],
    ],
    [
      [(.5, 0), (.5, 1)],
    ],
    [
      [(.15, .3), (.55, 0), (.55, 1)],
    ],
    [
      [(.1, .45), (.6, 0), (.6, 1)],
    ],
    // Le `1` d'Antsa sur téléphone : le trait monte de tout en bas, en
    // biais, puis redescend droit ; le modèle y lit `Λ`.
    [
      [(0, 1), (.5, .5), (.75, 0), (.73, .5), (.7, 1)],
    ],
    [
      [(0, 1), (.4, .5), (.6, 0), (.66, .5), (.75, 1)],
    ],
  ],
  '2': [
    // Large, la base longue (téléphone d'Antsa, dans une matrice).
    [
      [
        (0.05, 0.15),
        (0.2, 0.0),
        (0.4, 0.0),
        (0.5, 0.15),
        (0.45, 0.4),
        (0.2, 0.72),
        (0.0, 1.0),
        (1.0, 0.98),
      ],
    ],
    [
      [
        (0.16, 0.11),
        (0.27, 0.00),
        (0.35, 0.00),
        (0.54, 0.14),
        (0.57, 0.30),
        (0.22, 0.76),
        (0.00, 0.81),
        (0.00, 0.73),
        (0.11, 0.65),
        (0.30, 0.65),
        (0.70, 0.84),
        (1.00, 0.73),
      ],
    ],
    [
      [
        (0.11, 0.11),
        (0.25, 0.00),
        (0.47, 0.03),
        (0.58, 0.22),
        (0.58, 0.44),
        (0.50, 0.69),
        (0.31, 0.92),
        (0.14, 0.97),
        (0.00, 0.94),
        (0.94, 1.00),
      ],
    ],
    [
      [(.1, .25), (.3, .03), (.7, .03), (.9, .25), (.75, .5), (.1, 1), (.9, 1)],
    ],
    [
      [
        (.15, .2),
        (.5, 0),
        (.85, .2),
        (.7, .45),
        (.05, .95),
        (.3, .85),
        (1, .95),
      ],
    ],
  ],
  '3': [
    [
      [
        (0.00, 0.09),
        (0.28, 0.00),
        (0.37, 0.02),
        (0.44, 0.14),
        (0.42, 0.33),
        (0.19, 0.58),
        (0.40, 0.49),
        (0.51, 0.49),
        (0.63, 0.58),
        (0.63, 0.77),
        (0.51, 0.95),
        (0.14, 1.00),
      ],
    ],
    [
      [
        (0.19, 0.10),
        (0.29, 0.00),
        (0.40, 0.00),
        (0.55, 0.12),
        (0.55, 0.21),
        (0.19, 0.50),
        (0.29, 0.45),
        (0.71, 0.50),
        (0.86, 0.64),
        (0.86, 0.79),
        (0.62, 0.98),
        (0.00, 0.93),
        (0.02, 1.00),
      ],
    ],
    [
      [
        (.1, .1),
        (.5, 0),
        (.85, .15),
        (.75, .4),
        (.4, .5),
        (.8, .6),
        (.9, .8),
        (.6, 1),
        (.1, .9),
      ],
    ],
  ],
  '4': [
    [
      [(0.66, 0.55), (0.11, 0.51), (0.00, 0.55), (0.09, 0.57)],
      [(0.19, 0.02), (0.09, 0.66), (0.28, 0.57), (0.51, 0.36)],
      [(0.49, 0.13), (0.51, 1.00)],
    ],
    [
      [(.6, 0), (.05, .65), (.95, .65)],
      [(.7, .2), (.7, 1)],
    ],
    [
      [(.3, 0), (.1, .55), (.9, .55)],
      [(.75, .05), (.75, 1)],
    ],
    // Ouvert en haut, la hampe droite qui descend sous la barre (téléphone
    // d'Antsa) : le modèle y lit `1/1`.
    [
      [(0, 0), (.12, .68), (1, .68)],
      [(.72, .04), (.62, 1)],
    ],
  ],
  '5': [
    [
      [
        (0.67, 0.05),
        (0.19, 0.02),
        (0.31, 0.19),
        (0.24, 0.45),
        (0.31, 0.36),
        (0.45, 0.33),
        (0.74, 0.48),
        (0.81, 0.60),
        (0.21, 0.95),
        (0.00, 0.98),
      ],
    ],
    [
      [
        (0.33, 0.03),
        (0.08, 0.00),
        (0.00, 0.05),
        (0.03, 0.51),
        (0.05, 0.56),
        (0.15, 0.33),
        (0.26, 0.33),
        (0.54, 0.54),
        (0.54, 0.67),
        (0.23, 0.95),
        (0.10, 1.00),
        (0.10, 0.95),
      ],
    ],
    [
      [
        (0.66, 0.03),
        (0.24, 0.00),
        (0.11, 0.03),
        (0.11, 0.13),
        (0.21, 0.39),
        (0.18, 0.47),
        (0.37, 0.34),
        (0.55, 0.37),
        (0.66, 0.47),
        (0.71, 0.58),
        (0.68, 0.84),
        (0.58, 0.95),
        (0.39, 1.00),
        (0.00, 0.97),
      ],
    ],
    [
      [
        (.85, 0),
        (.2, 0),
        (.15, .45),
        (.6, .4),
        (.9, .65),
        (.7, .95),
        (.1, .95),
      ],
    ],
    [
      [(.2, 0), (.15, .45), (.6, .4), (.9, .65), (.7, .95), (.1, .95)],
      [(.2, 0), (.85, 0)],
    ],
  ],
  '6': [
    [
      [
        (.7, 0),
        (.25, .4),
        (.1, .75),
        (.4, 1),
        (.8, .85),
        (.75, .55),
        (.3, .55),
      ],
    ],
  ],
  '7': [
    [
      [(0.00, 0.10), (0.34, 0.00), (0.44, 0.05), (0.29, 0.98)],
      [(0.76, 0.51), (0.51, 0.51), (0.10, 0.66)],
    ],
    [
      [(.05, 0), (.95, 0), (.35, 1)],
    ],
    [
      [(.05, 0), (.95, 0), (.35, 1)],
      [(.2, .5), (.75, .5)],
    ],
  ],
  '8': [
    [
      [
        (0.14, 0.11),
        (0.11, 0.03),
        (0.05, 0.11),
        (0.05, 0.38),
        (0.14, 0.49),
        (0.38, 0.57),
        (0.43, 0.70),
        (0.41, 0.95),
        (0.24, 1.00),
        (0.00, 0.73),
        (0.54, 0.46),
        (0.65, 0.30),
        (0.62, 0.14),
        (0.35, 0.00),
        (0.08, 0.22),
      ],
    ],
    [
      [
        (.8, .15),
        (.5, 0),
        (.2, .15),
        (.3, .35),
        (.75, .65),
        (.8, .85),
        (.5, 1),
        (.2, .85),
        (.3, .65),
        (.75, .35),
        (.8, .15),
      ],
    ],
  ],
  '9': [
    [
      [(.85, .2), (.5, 0), (.15, .2), (.4, .45), (.85, .3), (.8, 1)],
    ],
  ],
};

const Map<String, List<_Dessin>> _lettres = {
  'A': [
    [
      [(0.46, 0.00), (0.29, 0.21), (0.00, 0.92)],
      [(0.50, 0.58), (0.10, 0.56)],
      [(0.40, 0.17), (0.48, 0.37), (0.50, 0.92), (0.56, 1.00)],
    ],
    [
      [(0, 1), (.5, 0), (1, 1)],
      [(.2, .6), (.8, .6)],
    ],
  ],
  'B': [
    [
      [
        (0.29, 0.23),
        (0.31, 0.69),
        (0.29, 0.12),
        (0.35, 0.02),
        (0.48, 0.00),
        (0.69, 0.13),
        (0.50, 0.54),
        (0.62, 0.48),
        (0.85, 0.52),
        (0.98, 0.63),
        (1.00, 0.81),
        (0.79, 0.92),
        (0.15, 0.88),
        (0.00, 0.85),
        (0.02, 0.81),
      ],
    ],
    [
      [(.1, 0), (.1, 1)],
      [(.1, 0), (.7, .05), (.8, .25), (.1, .48), (.85, .6), (.85, .9), (.1, 1)],
    ],
  ],
  'C': [
    [
      [(.9, .15), (.5, 0), (.1, .25), (.1, .75), (.5, 1), (.9, .85)],
    ],
  ],
  'D': [
    [
      [(.1, 0), (.1, 1)],
      [(.1, 0), (.7, .1), (.95, .5), (.7, .9), (.1, 1)],
    ],
  ],
  'E': [
    [
      [(.9, 0), (.1, 0), (.1, 1), (.9, 1)],
      [(.1, .5), (.7, .5)],
    ],
  ],
  'F': [
    [
      [(.9, 0), (.1, 0), (.1, 1)],
      [(.1, .5), (.7, .5)],
    ],
  ],
  'G': [
    [
      [
        (.9, .15),
        (.5, 0),
        (.1, .25),
        (.1, .75),
        (.5, 1),
        (.9, .8),
        (.9, .55),
        (.55, .55),
      ],
    ],
  ],
  'H': [
    [
      [(.1, 0), (.1, 1)],
      [(.9, 0), (.9, 1)],
      [(.1, .5), (.9, .5)],
    ],
  ],
  'I': [
    [
      [(.5, 0), (.5, 1)],
    ],
  ],
  'J': [
    [
      [(.8, 0), (.8, .8), (.5, 1), (.2, .8)],
    ],
  ],
  'K': [
    [
      [(.1, 0), (.1, 1)],
      [(.85, 0), (.1, .55), (.9, 1)],
    ],
  ],
  'L': [
    [
      [(.1, 0), (.1, 1), (.9, 1)],
    ],
  ],
  'M': [
    [
      [(.05, 1), (.1, 0), (.5, .7), (.9, 0), (.95, 1)],
    ],
  ],
  'N': [
    [
      [(.1, 1), (.1, 0), (.9, 1), (.9, 0)],
    ],
  ],
  'O': [
    [
      [(.5, 0), (.1, .25), (.1, .75), (.5, 1), (.9, .75), (.9, .25), (.5, 0)],
    ],
  ],
  'P': [
    [
      [(.1, 0), (.1, 1)],
      [(.1, 0), (.8, .1), (.8, .4), (.1, .5)],
    ],
  ],
  'Q': [
    [
      [(.5, 0), (.1, .25), (.1, .75), (.5, 1), (.9, .75), (.9, .25), (.5, 0)],
      [(.6, .7), (1, 1)],
    ],
  ],
  'R': [
    [
      [(.1, 0), (.1, 1)],
      [(.1, 0), (.8, .1), (.8, .4), (.1, .5), (.9, 1)],
    ],
  ],
  'S': [
    [
      [(.9, .1), (.5, 0), (.1, .2), (.5, .5), (.9, .8), (.5, 1), (.1, .9)],
    ],
  ],
  'T': [
    [
      [(0, 0), (1, 0)],
      [(.5, 0), (.5, 1)],
    ],
  ],
  'U': [
    [
      [(.1, 0), (.1, .75), (.5, 1), (.9, .75), (.9, 0)],
    ],
  ],
  'V': [
    [
      [(.05, 0), (.5, 1), (.95, 0)],
    ],
  ],
  'W': [
    [
      [(0, 0), (.25, 1), (.5, .3), (.75, 1), (1, 0)],
    ],
  ],
  'X': [
    [
      [(.05, 0), (.95, 1)],
      [(.95, 0), (.05, 1)],
    ],
  ],
  'Y': [
    [
      [(.05, 0), (.5, .5), (.95, 0)],
      [(.5, .5), (.5, 1)],
    ],
  ],
  'Z': [
    [
      [(.05, 0), (.95, 0), (.05, 1), (.95, 1)],
    ],
  ],
};

/// Les minuscules usuelles et `π` (ADR 0037). Le `e` et le `f` d'Antsa sont
/// relevés sur ses traits du Pad 7 (`e_x_egal_7`, `derivee_f`).
const Map<String, List<_Dessin>> _minuscules = {
  'a': [
    [
      [
        (.85, .2),
        (.5, 0),
        (.1, .3),
        (.05, .7),
        (.35, 1),
        (.7, .85),
        (.85, .4),
        (.88, 0),
        (.88, .8),
        (1, 1),
      ],
    ],
    [
      [(.85, .2), (.5, 0), (.1, .3), (.05, .7), (.35, 1), (.7, .85), (.85, .4)],
      [(.88, 0), (.88, 1)],
    ],
  ],
  'b': [
    [
      [
        (.1, 0),
        (.1, 1),
        (.1, .7),
        (.35, .45),
        (.6, .5),
        (.65, .8),
        (.4, 1),
        (.1, .95),
      ],
    ],
    [
      [(.1, 0), (.1, 1)],
      [(.1, .65), (.35, .45), (.6, .55), (.62, .85), (.35, 1), (.1, .9)],
    ],
  ],
  'c': [
    [
      [
        (.9, .15),
        (.55, 0),
        (.15, .2),
        (0, .55),
        (.2, .9),
        (.55, 1),
        (.95, .85),
      ],
    ],
    [
      [(.36, 0), (.16, .25), (.01, .66), (.15, .88), (.48, .88), (1, .82)],
    ],
  ],
  'd': [
    [
      [
        (.6, .55),
        (.35, .45),
        (.1, .6),
        (.05, .85),
        (.3, 1),
        (.55, .9),
        (.65, 0),
        (.65, 1),
      ],
    ],
    [
      [(.6, .55), (.35, .45), (.1, .6), (.05, .85), (.3, 1), (.6, .85)],
      [(.65, 0), (.65, 1)],
    ],
  ],
  'e': [
    [
      [
        (.1, .55),
        (.85, .5),
        (.85, .25),
        (.5, 0),
        (.15, .2),
        (.05, .6),
        (.35, 1),
        (.9, .85),
      ],
    ],
    // Le `e` d'Antsa, couché (Pad 7).
    [
      [
        (0.00, 0.57),
        (0.12, 0.53),
        (0.26, 0.46),
        (0.40, 0.37),
        (0.52, 0.29),
        (0.62, 0.16),
        (0.59, 0.09),
        (0.50, 0.02),
        (0.38, 0.00),
        (0.26, 0.05),
        (0.19, 0.16),
        (0.15, 0.30),
        (0.17, 0.44),
        (0.26, 0.56),
        (0.43, 0.63),
        (0.64, 0.63),
        (0.85, 0.58),
        (1.00, 0.53),
      ],
    ],
  ],
  'f': [
    // Le `f` d'Antsa : la hampe, une boucle en bas, la barre (Pad 7).
    [
      [
        (0.11, 0.44),
        (0.15, 0.39),
        (0.29, 0.20),
        (0.34, 0.05),
        (0.34, 0.00),
        (0.30, 0.09),
        (0.26, 0.34),
        (0.26, 0.64),
        (0.25, 0.86),
        (0.23, 0.99),
        (0.13, 0.83),
        (0.03, 0.68),
        (0.00, 0.65),
        (0.12, 0.62),
        (0.35, 0.54),
        (0.52, 0.48),
      ],
    ],
    [
      [(.55, .08), (.4, 0), (.25, .1), (.22, .4), (.22, 1)],
      [(0, .38), (.5, .38)],
    ],
  ],
  'k': [
    [
      [(.1, 0), (.1, 1)],
      [(.6, .4), (.1, .72), (.65, 1)],
    ],
    [
      [(.1, 0), (.1, 1), (.1, .7), (.5, .4), (.6, .5), (.15, .72), (.65, 1)],
    ],
  ],
  'n': [
    [
      [
        (.05, .05),
        (.1, 1),
        (.12, .35),
        (.4, 0),
        (.75, .1),
        (.85, .5),
        (.85, 1),
      ],
    ],
    [
      [(.1, 0), (.1, 1)],
      [(.1, .35), (.4, 0), (.75, .1), (.85, .5), (.85, 1)],
    ],
  ],
  't': [
    [
      [(.35, 0), (.35, .85), (.5, 1), (.7, .9)],
      [(.05, .3), (.7, .3)],
    ],
    [
      [(.35, 0), (.35, 1)],
      [(.05, .3), (.7, .3)],
    ],
  ],
  'u': [
    [
      [(.05, 0), (.05, .7), (.3, 1), (.65, .95), (.85, .6), (.85, 0), (.85, 1)],
    ],
    [
      [
        (.05, 0),
        (.05, .7),
        (.3, 1),
        (.65, .95),
        (.85, .6),
        (.85, 0),
        (.85, .85),
        (1, 1),
      ],
    ],
  ],
  'v': [
    [
      [(0, 0), (.45, 1), (.9, 0)],
    ],
    [
      [(0, .05), (.12, 0), (.3, .5), (.45, 1), (.7, .4), (.95, .05)],
    ],
  ],
  // Deux arcs dos à dos (Antsa, Pad 7), ou deux diagonales.
  'x': [
    [
      [(0, 0), (.3, .15), (.42, .5), (.3, .85), (0, 1)],
      [(1, 0), (.6, .15), (.5, .5), (.6, .85), (1, 1)],
    ],
    [
      [(0, 0), (1, 1)],
      [(1, 0), (0, 1)],
    ],
  ],
  'y': [
    [
      [(0, 0), (.4, .5)],
      [(.8, 0), (.15, 1)],
    ],
    [
      [
        (0, 0),
        (0, .3),
        (.3, .5),
        (.6, .3),
        (.6, 0),
        (.6, .8),
        (.4, 1),
        (.05, .9),
      ],
    ],
  ],
  'z': [
    [
      [(0, 0), (.9, 0), (0, .95), (.9, .95)],
    ],
    [
      [(.05, .1), (.3, 0), (.9, .05), (.05, .95), (.5, .9), (.95, 1)],
    ],
  ],
  r'\pi': [
    [
      [(0, .12), (1, .05)],
      [(.3, .1), (.25, .85)],
      [(.7, .08), (.75, .85)],
    ],
    [
      [(0, .15), (.25, .05), (1, .05)],
      [(.3, .08), (.22, .85)],
      [(.7, .06), (.72, .75), (.9, .85)],
    ],
  ],
};

/// Des signes que le tracé seul ne sépare pas : le contexte tranche
/// (`2x` contre `xz`, `30×8` contre `2x`).
const List<Set<String>> famillesDeSignes = [
  {'1', 'I'},
  {'0', 'O'},
  {'2', 'z', 'Z'},
  {'5', 'S'},
  {'c', 'C'},
  {'k', 'K'},
  {'u', 'U'},
  {'v', 'V'},
  {'x', 'X'},
  {'y', 'Y'},
];

Set<String> _famille(String s) =>
    famillesDeSignes.firstWhere((f) => f.contains(s), orElse: () => {s});

bool _estChiffre(String s) => s.length == 1 && '0123456789'.contains(s);

bool _estMinuscule(String s) => s == r'\pi' || RegExp(r'^[a-z]$').hasMatch(s);

/// Des leurres : des minuscules qu'on ne lit pas au tracé, mais qui
/// ressemblent à un chiffre. Un `n` cursif à deux bosses passait pour un `4`
/// (Pad 7) ; si un leurre est le plus proche, on doute.
const Map<String, List<_Dessin>> _leurres = {
  'm': [
    [
      [
        (.05, .05),
        (.08, 1),
        (.1, .35),
        (.25, 0),
        (.4, .1),
        (.45, 1),
        (.47, .35),
        (.65, 0),
        (.85, .1),
        (.9, 1),
      ],
    ],
  ],
  // Le `n` cursif : une attaque qui monte, puis deux bosses.
  'n': [
    [
      [
        (0, 1),
        (.12, .1),
        (.2, 0),
        (.25, 1),
        (.3, .4),
        (.55, 0),
        (.75, .15),
        (.8, .9),
        (1, 1),
      ],
    ],
  ],
  'h': [
    [
      [(.15, 0), (.15, 1), (.17, .55), (.4, .4), (.65, .5), (.7, 1)],
    ],
  ],
  'g': [
    [
      [
        (.7, .15),
        (.4, 0),
        (.1, .15),
        (.1, .4),
        (.4, .5),
        (.7, .35),
        (.72, 0),
        (.72, .8),
        (.5, 1),
        (.15, .9),
      ],
    ],
  ],
  'q': [
    [
      [
        (.7, .15),
        (.4, 0),
        (.1, .15),
        (.1, .4),
        (.4, .5),
        (.7, .35),
        (.72, 0),
        (.72, 1),
        (.85, .9),
      ],
    ],
  ],
};

/// Les leurres seuls : `n` est aussi une vraie minuscule, lue.
const Set<String> _leurresSeuls = {'m', 'h', 'g', 'q'};

final List<(String, List<Offset>)> _modelesMinuscules = [
  ..._preparer(_minuscules),
  ..._preparer(_leurres),
];

/// Une minuscule doit être plus nette qu'un chiffre ou une capitale : elle
/// vient d'arriver, et ses formes varient davantage.
const double _seuilMinuscule = 1.3;

/// Sur la seule voie du tracé, un chiffre aussi doit être net : au-delà de
/// 1,5, un `n` cursif passait pour un `4` ; un `2` étroit, à 0,13 près,
/// pour un `8`.
const double _seuilTrace = 1.5;
const double _ecartTrace = 0.2;

/// Ce que coûte, sur la voie du tracé, chaque trait de plus ou de moins que
/// le modèle.
const double _penaliteTrait = 0.3;

final List<(String, List<Offset>, int)> _modelesTrace = [
  for (final dessins in [_chiffres, _lettres, _minuscules, _leurres])
    for (final MapEntry(key: signe, value: variantes) in dessins.entries)
      for (final dessin in variantes)
        (
          signe,
          _normaliser(
            _reechantillonner([
              for (final t in dessin) [for (final (x, y) in t) Offset(x, y)],
            ]),
          ),
          dessin.length,
        ),
];
const double _ecartMinuscule = 0.2;

/// Ce que dessinent ces traits : un signe, ou plusieurs qu'on ne sait pas
/// séparer au tracé (`2`, `z`, `Z`), avec leur distance ; `null` dans le
/// doute. Le chiffre d'abord, comme [reconnaitreChiffre] : une capitale ne
/// le détrône pas, une minuscule nettement plus proche le rend douteux.
Map<String, double>? reconnaitreSigne(List<List<Offset>> traits) {
  if (_quatreOuvert(traits)) return const {'4': 0};
  final nuage = _normaliser(_reechantillonner(traits));
  final d = <String, double>{};
  for (final (s, modele, n) in _modelesTrace) {
    // Le nuage oublie les levers de stylo : un `t` (hampe et barre)
    // ressemble à un `1`. Un modèle d'un autre nombre de traits paie.
    final penalite = _penaliteTrait * (n - traits.length).abs();
    d[s] = math.min(
      d[s] ?? double.infinity,
      _distance(nuage, modele) + penalite,
    );
  }
  Map<String, double> famille(String s) => {
    for (final f in _famille(s))
      if (d.containsKey(f)) f: d[f]!,
  };
  double meilleurHors(Set<String> exclus, bool Function(String) pris) {
    var m = double.infinity;
    for (final MapEntry(:key, :value) in d.entries) {
      if (!exclus.contains(key) && pris(key)) m = math.min(m, value);
    }
    return m;
  }

  String? meilleur(bool Function(String) pris) {
    String? s;
    for (final MapEntry(:key, :value) in d.entries) {
      if (pris(key) && (s == null || value < d[s]!)) s = key;
    }
    return s;
  }

  final chiffre = meilleur(_estChiffre)!;
  final dc = d[chiffre]!;
  if (dc <= _seuilTrace &&
      meilleurHors(_famille(chiffre), _estChiffre) - dc >= _ecartTrace) {
    // Un leurre plus proche : on doute.
    final leurre = meilleurHors(_famille(chiffre), _leurresSeuls.contains);
    if (leurre < dc) return null;
    // Une minuscule tout près (`d` et `1`) : on doute aussi ; nettement
    // plus proche, elle seule peut l'emporter.
    final minuscule = meilleurHors(_famille(chiffre), _estMinuscule);
    if (minuscule >= dc + _ecartTrace / 2) return famille(chiffre);
    if (minuscule > dc - _ecartTrace / 2) return null;
  }
  final lettre = meilleur((s) => !_estChiffre(s))!;
  final dl = d[lettre]!;
  if (_leurresSeuls.contains(lettre)) return null;
  if (_estMinuscule(lettre)) {
    // Contre tout le reste, chiffres compris.
    return dl <= _seuilMinuscule &&
            meilleurHors(_famille(lettre), (_) => true) - dl >= _ecartMinuscule
        ? famille(lettre)
        : null;
  }
  return dl <= _seuil &&
          meilleurHors(_famille(lettre), (s) => !_estChiffre(s)) - dl >= _ecart
      ? famille(lettre)
      : null;
}

/// Débogage : tous les signes et leur distance, du plus proche au plus loin.
List<(String, double)> classerSignesDebug(List<List<Offset>> traits) {
  final nuage = _normaliser(_reechantillonner(traits));
  final d = <String, double>{};
  for (final (s, modele, n) in _modelesTrace) {
    final penalite = _penaliteTrait * (n - traits.length).abs();
    d[s] = math.min(
      d[s] ?? double.infinity,
      _distance(nuage, modele) + penalite,
    );
  }
  return d.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));
}

List<Offset> _reechantillonner(List<List<Offset>> traits) {
  final tous = [for (final t in traits) t];
  var longueur = 0.0;
  for (final t in tous) {
    for (var i = 1; i < t.length; i++) {
      longueur += (t[i] - t[i - 1]).distance;
    }
  }
  if (longueur == 0) {
    return List.filled(_points, tous.first.first);
  }
  final pas = longueur / (_points - 1);
  final sortie = <Offset>[tous.first.first];
  var parcouru = 0.0;
  for (final t in tous) {
    var precedent = t.first;
    for (var i = 1; i < t.length; i++) {
      final courant = t[i];
      var d = (courant - precedent).distance;
      while (parcouru + d >= pas && d > 0) {
        final k = (pas - parcouru) / d;
        final q = precedent + (courant - precedent) * k;
        sortie.add(q);
        precedent = q;
        d = (courant - precedent).distance;
        parcouru = 0;
      }
      parcouru += d;
      precedent = courant;
    }
  }
  while (sortie.length < _points) {
    sortie.add(tous.last.last);
  }
  return sortie.sublist(0, _points);
}

/// Taille commune, centrée. Un trait presque droit garde sa forme : on
/// garde la même échelle sur les deux axes.
List<Offset> _normaliser(List<Offset> nuage) {
  var (g, h, d, b) = (
    double.infinity,
    double.infinity,
    double.negativeInfinity,
    double.negativeInfinity,
  );
  var (sx, sy) = (0.0, 0.0);
  for (final p in nuage) {
    g = math.min(g, p.dx);
    d = math.max(d, p.dx);
    h = math.min(h, p.dy);
    b = math.max(b, p.dy);
    sx += p.dx;
    sy += p.dy;
  }
  final echelle = math.max(math.max(d - g, b - h), 1e-6);
  final centre = Offset(sx / nuage.length, sy / nuage.length);
  return [for (final p in nuage) (p - centre) / echelle];
}

double _distanceNuages(List<Offset> a, List<Offset> b, int debut) {
  final pris = List.filled(_points, false);
  var somme = 0.0;
  var i = debut;
  var compte = 0;
  while (compte < _points) {
    var meilleur = -1;
    var minimum = double.infinity;
    for (var j = 0; j < _points; j++) {
      if (pris[j]) continue;
      final d = (a[i] - b[j]).distanceSquared;
      if (d < minimum) (minimum, meilleur) = (d, j);
    }
    pris[meilleur] = true;
    final poids = 1 - compte / _points;
    somme += poids * math.sqrt(minimum);
    i = (i + 1) % _points;
    compte++;
  }
  return somme;
}

double _distance(List<Offset> a, List<Offset> b) {
  final pas = math.max(1, math.sqrt(_points).floor());
  var minimum = double.infinity;
  for (var i = 0; i < _points; i += pas) {
    minimum = math.min(minimum, _distanceNuages(a, b, i));
    minimum = math.min(minimum, _distanceNuages(b, a, i));
  }
  return minimum;
}

List<(String, List<Offset>)> _preparer(Map<String, List<_Dessin>> dessins) => [
  for (final MapEntry(key: signe, value: variantes) in dessins.entries)
    for (final dessin in variantes)
      (
        signe,
        _normaliser(
          _reechantillonner([
            for (final t in dessin) [for (final (x, y) in t) Offset(x, y)],
          ]),
        ),
      ),
];

final List<(String, List<Offset>)> _modelesChiffres = _preparer(_chiffres);
final List<(String, List<Offset>)> _modelesLettres = _preparer(_lettres);

/// Le meilleur signe, sa distance, et celle du meilleur autre signe.
(String, double, double) _meilleur(
  List<List<Offset>> traits,
  List<(String, List<Offset>)> modeles,
) {
  final nuage = _normaliser(_reechantillonner(traits));
  final parSigne = <String, double>{};
  for (final (s, modele) in modeles) {
    final d = _distance(nuage, modele);
    parSigne[s] = math.min(parSigne[s] ?? double.infinity, d);
  }
  final tries = parSigne.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return (tries[0].key, tries[0].value, tries[1].value);
}

/// Au-delà, le dessin ne ressemble à rien de connu.
const double _seuil = 1.8;

/// Sans cet écart avec le signe suivant, on préfère ne pas trancher.
const double _ecart = 0.12;

String? _trancher((String, double, double) m) {
  final (signe, distance, suivant) = m;
  return distance <= _seuil && suivant - distance >= _ecart ? signe : null;
}

/// Le chiffre que dessinent ces traits, ou `null` dans le doute : aussi
/// quand une minuscule ou un leurre (`n`, `m`, `g`…) est plus proche.
String? reconnaitreChiffre(List<List<Offset>> traits) {
  if (_quatreOuvert(traits)) return '4';
  final chiffre = _trancher(_meilleur(traits, _modelesChiffres));
  if (chiffre == null) return null;
  final nuage = _normaliser(_reechantillonner(traits));
  final famille = _famille(chiffre);
  var dc = double.infinity;
  for (final (s, m) in _modelesChiffres) {
    if (s == chiffre) dc = math.min(dc, _distance(nuage, m));
  }
  for (final (s, m) in _modelesMinuscules) {
    if (!famille.contains(s) && _distance(nuage, m) < dc) return null;
  }
  return chiffre;
}

/// Le `4` ouvert d'Antsa : un `L` (descend, puis part à droite) et une hampe
/// qui croise sa barre et descend dessous. Les nuages de points le confondent
/// avec un `1`.
bool _quatreOuvert(List<List<Offset>> traits) {
  if (traits.length != 2) return false;
  for (final (l, hampe) in [(traits[0], traits[1]), (traits[1], traits[0])]) {
    if (l.length < 3 || hampe.length < 2) continue;
    final cl = _cadre(l);
    final ch = _cadre(hampe);
    final hauteur = math.max(cl.height, ch.height);
    if (cl.height < 0.3 * hauteur || cl.width < 0.4 * hauteur) continue;
    // Le `L` : commence en haut à gauche, finit à droite, au bas de sa boîte.
    if ((l.first.dx - cl.left) > 0.3 * cl.width ||
        (l.first.dy - cl.top) > 0.3 * cl.height ||
        (cl.right - l.last.dx) > 0.2 * cl.width ||
        (cl.bottom - l.last.dy) > 0.3 * cl.height) {
      continue;
    }
    // La hampe : debout, à droite, elle croise la barre et descend dessous.
    if (ch.width > 0.4 * ch.height) continue;
    final x = ch.center.dx;
    if (x < cl.left + 0.4 * cl.width || x > cl.right + 0.1 * cl.width) continue;
    if (ch.top > cl.bottom - 0.2 * hauteur ||
        ch.bottom < cl.bottom + 0.1 * hauteur) {
      continue;
    }
    return true;
  }
  return false;
}

Rect _cadre(List<Offset> s) => s
    .skip(1)
    .fold(s.first & Size.zero, (r, p) => r.expandToInclude(p & Size.zero));

/// La lettre capitale que dessinent ces traits, ou `null` dans le doute.
String? reconnaitreCapitale(List<List<Offset>> traits) =>
    _trancher(_meilleur(traits, _modelesLettres));

/// Pour le banc : le meilleur chiffre et sa distance.
(String, double) essayerChiffre(List<List<Offset>> traits) {
  final (s, d, _) = _meilleur(traits, _modelesChiffres);
  return (s, d);
}

/// Pour le banc : la meilleure capitale et sa distance.
(String, double) essayerCapitale(List<List<Offset>> traits) {
  final (s, d, _) = _meilleur(traits, _modelesLettres);
  return (s, d);
}

/// Débogage : tous les chiffres et leur distance.
List<(String, double)> classerChiffresDebug(List<List<Offset>> traits) {
  final nuage = _normaliser(_reechantillonner(traits));
  final parSigne = <String, double>{};
  for (final (s, modele) in _modelesChiffres) {
    final d = _distance(nuage, modele);
    parSigne[s] = math.min(parSigne[s] ?? double.infinity, d);
  }
  return parSigne.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));
}

/// La distance de deux dessins, comme entre un signe et un gabarit : pour
/// comparer un signe aux exemples de la personne (ADR 0040).
double distanceDessins(List<List<Offset>> a, List<List<Offset>> b) =>
    _distance(
      _normaliser(_reechantillonner(a)),
      _normaliser(_reechantillonner(b)),
    ) +
    _penaliteTrait * (a.length - b.length).abs();
