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
  ],
  '2': [
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

/// Le chiffre que dessinent ces traits, ou `null` dans le doute.
String? reconnaitreChiffre(List<List<Offset>> traits) =>
    _trancher(_meilleur(traits, _modelesChiffres));

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
