import 'dart:math' as math;
import 'dart:ui';

import 'package:perfect_freehand/perfect_freehand.dart';

/// Écrit un résultat comme un trait de stylet, juste après le signe `=`.
///
/// Les tracés sont dessinés pour Fikajiana, dans un repère où la hauteur d'un
/// chiffre vaut 1. Rien n'est repris d'une police ni d'une autre application.
/// Ce qui n'est pas pris en charge rend `null` : une formule le remplace.

typedef _Trace = List<Offset>;

_Trace _l(List<double> xy) => [
  for (var i = 0; i + 1 < xy.length; i += 2) Offset(xy[i], xy[i + 1]),
];

_Trace _arc(
  double cx,
  double cy,
  double rx,
  double ry,
  double debut,
  double fin, {
  int n = 14,
}) => [
  for (var i = 0; i <= n; i++)
    Offset(
      cx + rx * math.cos(debut + (fin - debut) * i / n),
      cy + ry * math.sin(debut + (fin - debut) * i / n),
    ),
];

class _Glyphe {
  const new(this.largeur, this.traces);

  final double largeur;
  final List<_Trace> traces;
}

const double _pi = math.pi;

final Map<String, _Glyphe> _glyphes = {
  '0': _Glyphe(0.62, [_arc(0.31, 0.5, 0.27, 0.5, -_pi / 2, 3 * _pi / 2 + 0.2)]),
  '1': _Glyphe(0.42, [
    _l([0.06, 0.24, 0.28, 0, 0.28, 1]),
  ]),
  '2': _Glyphe(0.62, [
    [
      ..._arc(0.3, 0.27, 0.25, 0.26, -_pi, 0.35),
      ..._l([0.42, 0.56, 0.04, 0.99, 0.6, 0.97]),
    ],
  ]),
  '3': _Glyphe(0.6, [
    [
      ..._arc(0.28, 0.24, 0.24, 0.24, -2.8, 1.3),
      ..._arc(0.28, 0.72, 0.28, 0.28, -1.3, 2.8),
    ],
  ]),
  '4': _Glyphe(0.64, [
    _l([0.46, 1, 0.46, 0, 0.02, 0.66, 0.62, 0.66]),
  ]),
  '5': _Glyphe(0.6, [
    [
      ..._l([0.52, 0.02, 0.12, 0, 0.08, 0.44]),
      ..._arc(0.27, 0.68, 0.29, 0.32, -1.9, 2.8),
    ],
  ]),
  '6': _Glyphe(0.6, [
    [
      ..._l([0.48, 0, 0.26, 0.2, 0.08, 0.5]),
      ..._arc(0.3, 0.72, 0.25, 0.28, -_pi, _pi),
    ],
  ]),
  '7': _Glyphe(0.58, [
    _l([0.03, 0.02, 0.56, 0, 0.26, 1]),
  ]),
  '8': _Glyphe(0.58, [
    [
      ..._arc(0.29, 0.24, 0.21, 0.24, _pi / 2, 5 * _pi / 2),
      ..._arc(0.29, 0.74, 0.26, 0.26, -_pi / 2, 3 * _pi / 2),
    ],
  ]),
  '9': _Glyphe(0.58, [
    [
      ..._arc(0.28, 0.28, 0.24, 0.28, 0.2, 2 * _pi + 0.2),
      ..._l([0.52, 0.32, 0.46, 0.7, 0.34, 1]),
    ],
  ]),
  'x': _Glyphe(0.5, [
    _l([0.04, 0.42, 0.46, 1]),
    _l([0.46, 0.42, 0.04, 1]),
  ]),
  'y': _Glyphe(0.52, [
    _l([0.04, 0.42, 0.27, 0.86]),
    _l([0.48, 0.42, 0.16, 1.24]),
  ]),
  'z': _Glyphe(0.5, [
    _l([0.04, 0.42, 0.46, 0.42, 0.04, 1, 0.48, 1]),
  ]),
  't': _Glyphe(0.4, [
    [
      ..._l([0.2, 0.1, 0.2, 0.84]),
      ..._arc(0.32, 0.86, 0.12, 0.14, _pi, _pi / 4),
    ],
    _l([0.02, 0.42, 0.38, 0.42]),
  ]),
  'a': _Glyphe(0.54, [
    _arc(0.25, 0.71, 0.21, 0.29, 0, 2 * _pi),
    _l([0.46, 0.42, 0.48, 1]),
  ]),
  'b': _Glyphe(0.52, [
    _l([0.08, 0, 0.08, 1]),
    _arc(0.28, 0.71, 0.2, 0.29, -_pi, _pi),
  ]),
  'n': _Glyphe(0.54, [
    _l([0.06, 0.42, 0.06, 1]),
    [
      ..._arc(0.27, 0.62, 0.21, 0.2, -_pi, 0),
      ..._l([0.48, 1]),
    ],
  ]),
  'e': _Glyphe(0.5, [
    [
      ..._l([0.06, 0.7, 0.44, 0.68]),
      ..._arc(0.25, 0.71, 0.2, 0.29, -0.1, -2 * _pi + 0.8),
    ],
  ]),
  'i': _Glyphe(0.2, [
    _l([0.1, 0.42, 0.1, 1]),
    _l([0.1, 0.16, 0.1, 0.2]),
  ]),
  'k': _Glyphe(0.5, [
    _l([0.06, 0, 0.06, 1]),
    _l([0.44, 0.42, 0.06, 0.72, 0.46, 1]),
  ]),
  'c': _Glyphe(0.46, [_arc(0.26, 0.71, 0.22, 0.29, -0.7, -2 * _pi + 0.7)]),
  'd': _Glyphe(0.54, [
    _arc(0.25, 0.71, 0.21, 0.29, 0, 2 * _pi),
    _l([0.46, 0, 0.47, 1]),
  ]),
  'f': _Glyphe(0.4, [
    [
      ..._arc(0.28, 0.14, 0.12, 0.14, -0.2, -_pi),
      ..._l([0.16, 1]),
    ],
    _l([0.02, 0.44, 0.34, 0.44]),
  ]),
  'g': _Glyphe(0.52, [
    _arc(0.24, 0.7, 0.2, 0.28, 0, 2 * _pi),
    [
      ..._l([0.44, 0.42, 0.44, 1.02]),
      ..._arc(0.24, 1.04, 0.2, 0.2, 0, _pi),
    ],
  ]),
  'h': _Glyphe(0.54, [
    _l([0.06, 0, 0.06, 1]),
    [
      ..._arc(0.27, 0.62, 0.21, 0.2, -_pi, 0),
      ..._l([0.48, 1]),
    ],
  ]),
  'j': _Glyphe(0.24, [
    [
      ..._l([0.16, 0.42, 0.16, 1.04]),
      ..._arc(0.04, 1.04, 0.12, 0.2, 0, _pi * 0.8),
    ],
    _l([0.16, 0.16, 0.16, 0.2]),
  ]),
  'l': _Glyphe(0.2, [
    _l([0.1, 0, 0.1, 1]),
  ]),
  'm': _Glyphe(0.8, [
    _l([0.06, 0.42, 0.06, 1]),
    [
      ..._arc(0.24, 0.62, 0.18, 0.2, -_pi, 0),
      ..._l([0.42, 1]),
    ],
    [
      ..._arc(0.6, 0.62, 0.18, 0.2, -_pi, 0),
      ..._l([0.78, 1]),
    ],
  ]),
  'o': _Glyphe(0.5, [
    _arc(0.25, 0.71, 0.22, 0.29, -_pi / 2, 3 * _pi / 2 + 0.2),
  ]),
  'p': _Glyphe(0.52, [
    _l([0.08, 0.42, 0.08, 1.24]),
    _arc(0.28, 0.71, 0.2, 0.29, -_pi, _pi),
  ]),
  'q': _Glyphe(0.52, [
    _arc(0.24, 0.71, 0.2, 0.29, 0, 2 * _pi),
    _l([0.44, 0.42, 0.44, 1.24]),
  ]),
  'r': _Glyphe(0.38, [
    _l([0.06, 0.42, 0.06, 1]),
    _arc(0.24, 0.62, 0.18, 0.18, -_pi, -0.3),
  ]),
  's': _Glyphe(0.44, [
    [
      ..._arc(0.22, 0.56, 0.18, 0.14, -0.3, -_pi - 0.9),
      ..._arc(0.22, 0.85, 0.18, 0.15, -1.6, 3),
    ],
  ]),
  'u': _Glyphe(0.5, [
    [
      ..._l([0.05, 0.42, 0.05, 0.76]),
      ..._arc(0.25, 0.78, 0.2, 0.22, _pi, 0),
    ],
    _l([0.45, 0.42, 0.47, 1]),
  ]),
  'v': _Glyphe(0.48, [
    _l([0.03, 0.42, 0.24, 1, 0.45, 0.42]),
  ]),
  'w': _Glyphe(0.72, [
    _l([0.03, 0.42, 0.19, 1, 0.36, 0.56, 0.53, 1, 0.69, 0.42]),
  ]),
  'S': _Glyphe(0.56, [
    [
      ..._arc(0.28, 0.25, 0.23, 0.24, -0.4, -_pi - 1),
      ..._arc(0.28, 0.73, 0.25, 0.27, -1.7, 2.9),
    ],
  ]),
  // Les ensembles de nombres : barre doublée, comme au tableau.
  'R': _Glyphe(0.64, [
    _l([0.08, 0, 0.08, 1]),
    _l([0.2, 0, 0.2, 1]),
    _arc(0.26, 0.26, 0.28, 0.26, -_pi / 2, _pi / 2),
    _l([0.26, 0.52, 0.58, 1]),
  ]),
  'Z': _Glyphe(0.62, [
    _l([0.04, 0, 0.58, 0, 0.04, 1, 0.6, 1]),
    _l([0.44, 0, 0.0, 0.92]),
  ]),
  '∈': _Glyphe(0.5, [
    [..._arc(0.3, 0.71, 0.26, 0.28, -_pi / 2, -3 * _pi / 2)],
    _l([0.05, 0.71, 0.46, 0.71]),
  ]),
  '∅': _Glyphe(0.66, [
    _arc(0.33, 0.56, 0.26, 0.38, -_pi / 2, 3 * _pi / 2 + 0.2),
    _l([0.08, 1, 0.58, 0.1]),
  ]),
  'π': _Glyphe(0.6, [
    _l([0.02, 0.46, 0.2, 0.4, 0.58, 0.42]),
    _l([0.2, 0.42, 0.16, 1]),
    _l([0.44, 0.42, 0.44, 0.92, 0.56, 1]),
  ]),
  '∞': _Glyphe(0.9, [
    [
      ..._arc(0.25, 0.68, 0.2, 0.2, 0, 2 * _pi),
      ..._arc(0.65, 0.68, 0.2, 0.2, _pi, 3 * _pi),
    ],
  ]),
  '+': _Glyphe(0.62, [
    _l([0.04, 0.6, 0.58, 0.6]),
    _l([0.31, 0.33, 0.31, 0.87]),
  ]),
  '-': _Glyphe(0.5, [
    _l([0.04, 0.6, 0.46, 0.6]),
  ]),
  '=': _Glyphe(0.6, [
    _l([0.04, 0.48, 0.56, 0.48]),
    _l([0.04, 0.72, 0.56, 0.72]),
  ]),
  '<': _Glyphe(0.6, [
    _l([0.52, 0.36, 0.08, 0.6, 0.52, 0.84]),
  ]),
  '>': _Glyphe(0.6, [
    _l([0.08, 0.36, 0.52, 0.6, 0.08, 0.84]),
  ]),
  '≤': _Glyphe(0.6, [
    _l([0.52, 0.28, 0.08, 0.5, 0.52, 0.72]),
    _l([0.08, 0.88, 0.52, 0.88]),
  ]),
  '≥': _Glyphe(0.6, [
    _l([0.08, 0.28, 0.52, 0.5, 0.08, 0.72]),
    _l([0.08, 0.88, 0.52, 0.88]),
  ]),
  '.': _Glyphe(0.18, [
    _l([0.09, 0.96, 0.09, 0.99]),
  ]),
  ',': _Glyphe(0.2, [
    _l([0.12, 0.92, 0.1, 1, 0.04, 1.14]),
  ]),
  ';': _Glyphe(0.24, [
    _l([0.12, 0.5, 0.12, 0.53]),
    _l([0.14, 0.92, 0.12, 1, 0.06, 1.14]),
  ]),
  '⇔': _Glyphe(1.1, [
    _l([0.22, 0.48, 0.88, 0.48]),
    _l([0.22, 0.66, 0.88, 0.66]),
    _l([0.3, 0.36, 0.06, 0.57, 0.3, 0.78]),
    _l([0.8, 0.36, 1.04, 0.57, 0.8, 0.78]),
  ]),
  '(': _Glyphe(0.28, [_arc(0.42, 0.52, 0.34, 0.62, 2.3, 4)]),
  ')': _Glyphe(0.28, [_arc(-0.14, 0.52, 0.34, 0.62, -0.86, 0.84)]),
  '{': _Glyphe(0.32, [
    [
      ..._arc(0.28, 0.14, 0.12, 0.2, -_pi / 2, -_pi),
      ..._l([0.16, 0.4, 0.04, 0.52, 0.16, 0.64]),
      ..._arc(0.28, 0.9, 0.12, 0.2, _pi, _pi / 2),
    ],
  ]),
  '}': _Glyphe(0.32, [
    [
      ..._arc(0.04, 0.14, 0.12, 0.2, -_pi / 2, 0),
      ..._l([0.16, 0.4, 0.28, 0.52, 0.16, 0.64]),
      ..._arc(0.04, 0.9, 0.12, 0.2, 0, _pi / 2),
    ],
  ]),
  '·': _Glyphe(0.22, [
    _l([0.11, 0.58, 0.11, 0.61]),
  ]),
  // Capitales : les noms des points et des courbes (`A(1;2)`, `C : …`).
  'A': _Glyphe(0.66, [
    _l([0.04, 1, 0.33, 0, 0.62, 1]),
    _l([0.15, 0.64, 0.51, 0.64]),
  ]),
  'B': _Glyphe(0.58, [
    [
      ..._l([0.08, 1, 0.08, 0, 0.32, 0]),
      ..._arc(0.32, 0.24, 0.22, 0.24, -_pi / 2, _pi / 2),
      ..._l([0.08, 0.48, 0.34, 0.48]),
      ..._arc(0.34, 0.74, 0.24, 0.26, -_pi / 2, _pi / 2),
      ..._l([0.34, 1, 0.08, 1]),
    ],
  ]),
  'C': _Glyphe(0.6, [_arc(0.34, 0.5, 0.3, 0.5, -0.7, -2 * _pi + 0.7)]),
  'D': _Glyphe(0.62, [
    [
      ..._l([0.08, 0, 0.08, 1]),
      ..._arc(0.12, 0.5, 0.46, 0.5, _pi / 2, -_pi / 2),
    ],
  ]),
  'E': _Glyphe(0.54, [
    _l([0.5, 0, 0.08, 0, 0.08, 1, 0.5, 1]),
    _l([0.08, 0.5, 0.42, 0.5]),
  ]),
  'F': _Glyphe(0.5, [
    _l([0.48, 0, 0.08, 0, 0.08, 1]),
    _l([0.08, 0.48, 0.4, 0.48]),
  ]),
  'G': _Glyphe(0.64, [
    [
      ..._arc(0.34, 0.5, 0.3, 0.5, -0.7, -2 * _pi + 0.5),
      ..._l([0.6, 0.6, 0.38, 0.6]),
    ],
  ]),
  'H': _Glyphe(0.64, [
    _l([0.08, 0, 0.08, 1]),
    _l([0.56, 0, 0.56, 1]),
    _l([0.08, 0.5, 0.56, 0.5]),
  ]),
  'I': _Glyphe(0.24, [
    _l([0.12, 0, 0.12, 1]),
  ]),
  'J': _Glyphe(0.46, [
    [
      ..._l([0.38, 0, 0.38, 0.74]),
      ..._arc(0.22, 0.74, 0.16, 0.26, 0, _pi),
    ],
  ]),
  'K': _Glyphe(0.58, [
    _l([0.08, 0, 0.08, 1]),
    _l([0.52, 0, 0.08, 0.56]),
    _l([0.22, 0.42, 0.54, 1]),
  ]),
  'L': _Glyphe(0.5, [
    _l([0.08, 0, 0.08, 1, 0.46, 1]),
  ]),
  'M': _Glyphe(0.78, [
    _l([0.06, 1, 0.1, 0, 0.39, 0.7, 0.68, 0, 0.72, 1]),
  ]),
  'N': _Glyphe(0.64, [
    _l([0.08, 1, 0.08, 0, 0.56, 1, 0.56, 0]),
  ]),
  'O': _Glyphe(0.7, [_arc(0.35, 0.5, 0.31, 0.5, 0, 2 * _pi, n: 24)]),
  'P': _Glyphe(0.56, [
    [
      ..._l([0.08, 1, 0.08, 0, 0.3, 0]),
      ..._arc(0.3, 0.26, 0.22, 0.26, -_pi / 2, _pi / 2),
      ..._l([0.3, 0.52, 0.08, 0.52]),
    ],
  ]),
  'Q': _Glyphe(0.72, [
    _arc(0.35, 0.5, 0.31, 0.5, 0, 2 * _pi, n: 24),
    _l([0.44, 0.74, 0.68, 1.04]),
  ]),
  'T': _Glyphe(0.58, [
    _l([0.04, 0, 0.54, 0]),
    _l([0.29, 0, 0.29, 1]),
  ]),
  'U': _Glyphe(0.62, [
    [
      ..._l([0.08, 0, 0.08, 0.7]),
      ..._arc(0.31, 0.7, 0.23, 0.3, _pi, 0),
      ..._l([0.54, 0.7, 0.54, 0]),
    ],
  ]),
  'V': _Glyphe(0.62, [
    _l([0.04, 0, 0.31, 1, 0.58, 0]),
  ]),
  'W': _Glyphe(0.86, [
    _l([0.04, 0, 0.22, 1, 0.43, 0.3, 0.64, 1, 0.82, 0]),
  ]),
  'X': _Glyphe(0.6, [
    _l([0.06, 0, 0.54, 1]),
    _l([0.54, 0, 0.06, 1]),
  ]),
  'Y': _Glyphe(0.6, [
    _l([0.04, 0, 0.3, 0.5, 0.56, 0]),
    _l([0.3, 0.5, 0.3, 1]),
  ]),
  ':': _Glyphe(0.22, [
    _l([0.11, 0.42, 0.11, 0.45]),
    _l([0.11, 0.94, 0.11, 0.97]),
  ]),
  '×': _Glyphe(0.5, [
    _l([0.08, 0.42, 0.42, 0.86]),
    _l([0.42, 0.42, 0.08, 0.86]),
  ]),
  '/': _Glyphe(0.4, [
    _l([0.36, 0, 0.04, 1.08]),
  ]),
  "'": _Glyphe(0.18, [
    _l([0.12, -0.02, 0.06, 0.24]),
  ]),
  '|': _Glyphe(0.22, [
    _l([0.11, -0.04, 0.11, 1.12]),
  ]),
};

/// Une boîte de traits : `y` croît vers le bas, 0 sur la ligne d'écriture.
class _Boite {
  const new(this.largeur, this.haut, this.bas, this.traces);

  final double largeur;

  /// Hauteur au-dessus de la ligne (positive).
  final double haut;

  /// Profondeur sous la ligne (positive).
  final double bas;

  final List<_Trace> traces;
}

_Boite _deplacer(_Boite b, Offset d, [double echelle = 1]) =>
    _Boite(b.largeur * echelle, b.haut * echelle, b.bas * echelle, [
      for (final t in b.traces) [for (final p in t) p * echelle + d],
    ]);

_Boite _rangee(List<_Boite> boites) {
  var x = 0.0;
  var haut = 0.0;
  var bas = 0.0;
  final traces = <_Trace>[];
  for (final b in boites) {
    traces.addAll(_deplacer(b, Offset(x, 0)).traces);
    x += b.largeur + 0.12;
    haut = math.max(haut, b.haut);
    bas = math.max(bas, b.bas);
  }
  return _Boite(boites.isEmpty ? 0 : x - 0.12, haut, bas, traces);
}

class _NonPrisEnCharge implements Exception {
  const new();
}

/// Lit le LaTeX de Giac : uniquement ce qu'on sait écrire à la main.
class _Compositeur {
  new(this._s);

  final String _s;
  var _i = 0;

  bool get _fini => _i >= _s.length;

  void _espaces() {
    while (!_fini && _s[_i].trim().isEmpty) {
      _i++;
    }
  }

  _Boite composer() {
    final b = _suite(null);
    _espaces();
    if (!_fini) throw const _NonPrisEnCharge();
    return b;
  }

  _Boite _suite(String? fermeture) {
    final boites = <_Boite>[];
    while (true) {
      _espaces();
      if (_fini) {
        if (fermeture != null) throw const _NonPrisEnCharge();
        return _rangee(boites);
      }
      final c = _s[_i];
      if (c == fermeture) {
        _i++;
        return _rangee(boites);
      }
      if (c == '^') {
        _i++;
        if (boites.isEmpty) throw const _NonPrisEnCharge();
        final exposant = _deplacer(_groupe(), Offset.zero, 0.62);
        final base = boites.removeLast();
        final hauteur = base.haut * 0.62 + exposant.bas;
        boites.add(
          _Boite(
            base.largeur + 0.05 + exposant.largeur,
            math.max(base.haut, hauteur + exposant.haut),
            base.bas,
            [
              ...base.traces,
              ..._deplacer(
                exposant,
                Offset(base.largeur + 0.05, -hauteur),
              ).traces,
            ],
          ),
        );
      } else {
        boites.add(_element());
      }
    }
  }

  _Boite _groupe() {
    _espaces();
    if (_fini) throw const _NonPrisEnCharge();
    if (_s[_i] == '{') {
      _i++;
      return _suite('}');
    }
    return _element();
  }

  _Boite _lettre(String c) {
    final g = _glyphes[c];
    if (g == null) throw const _NonPrisEnCharge();
    return _Boite(
      g.largeur,
      'acegmnopqrsuvwxyz∈<>≤≥'.contains(c) ? 0.58 : 1,
      'gjpqy,;'.contains(c) ? 0.24 : 0,
      [
        for (final t in g.traces) [for (final p in t) p - const Offset(0, 1)],
      ],
    );
  }

  _Boite _element() {
    final c = _s[_i];
    if (c == r'\') return _commande();
    if (c == '{') {
      _i++;
      return _suite('}');
    }
    _i++;
    return _lettre(c);
  }

  _Boite _commande() {
    final debut = ++_i;
    if (!_fini && !RegExp('[a-zA-Z]').hasMatch(_s[_i])) {
      final signe = _s[_i++];
      return signe == '{' || signe == '}'
          ? _lettre(signe)
          : signe == ','
          ? const _Boite(0.1, 0, 0, [])
          : throw const _NonPrisEnCharge();
    }
    while (!_fini && RegExp('[a-zA-Z]').hasMatch(_s[_i])) {
      _i++;
    }
    final nom = _s.substring(debut, _i);
    return switch (nom) {
      'sin' || 'cos' || 'tan' || 'ln' || 'log' || 'exp' => _mot(nom),
      'mathrm' || 'operatorname' || 'mathbb' || 'text' => _groupe(),
      'iff' || 'Leftrightarrow' => _lettre('⇔'),
      'quad' || 'qquad' => const _Boite(0.8, 0, 0, []),
      'in' => _lettre('∈'),
      'leq' => _lettre('≤'),
      'geq' => _lettre('≥'),
      'emptyset' => _lettre('∅'),
      'frac' => _fraction(),
      'begin' => _matrice(),
      'sqrt' => _racine(),
      'pi' => _lettre('π'),
      'infty' => _lettre('∞'),
      'cdot' => _lettre('·'),
      'times' => _lettre('×'),
      'prime' => _lettre("'"),
      'det' => _mot('det'),
      'left' || 'right' => const _Boite(0, 0, 0, []),
      _ => throw const _NonPrisEnCharge(),
    };
  }

  /// Le nom d'une fonction : ses lettres, l'une après l'autre.
  _Boite _mot(String nom) =>
      _rangee([for (final c in nom.split('')) _lettre(c)]);

  _Boite _fraction() {
    final numerateur = _deplacer(_groupe(), Offset.zero, 0.8);
    final denominateur = _deplacer(_groupe(), Offset.zero, 0.8);
    final largeur = math.max(numerateur.largeur, denominateur.largeur) + 0.2;
    const barre = -0.42;
    return _Boite(
      largeur,
      -barre + 0.14 + numerateur.haut + numerateur.bas,
      barre + 0.14 + denominateur.haut + denominateur.bas,
      [
        _l([0, barre, largeur, barre - 0.015]),
        ..._deplacer(
          numerateur,
          Offset(
            (largeur - numerateur.largeur) / 2,
            barre - 0.14 - numerateur.bas,
          ),
        ).traces,
        ..._deplacer(
          denominateur,
          Offset(
            (largeur - denominateur.largeur) / 2,
            barre + 0.14 + denominateur.haut,
          ),
        ).traces,
      ],
    );
  }

  /// `\begin{pmatrix}a&b\\c&d\end{pmatrix}` : ses cases écrites à la main,
  /// entre deux grandes parenthèses tracées (Antsa : pas de matrice imprimée).
  _Boite _matrice() {
    const debut = '{pmatrix}';
    if (!_s.startsWith(debut, _i)) throw const _NonPrisEnCharge();
    _i += debut.length;
    const fin = r'\end{pmatrix}';
    final bout = _s.indexOf(fin, _i);
    if (bout < 0) throw const _NonPrisEnCharge();
    final lignes = [
      for (final l in _s.substring(_i, bout).split(r'\\'))
        if (l.trim().isNotEmpty)
          [for (final c in l.split('&')) _Compositeur(c.trim()).composer()],
    ];
    _i = bout + fin.length;
    if (lignes.isEmpty) throw const _NonPrisEnCharge();
    final colonnes = lignes.map((l) => l.length).reduce(math.max);
    final largeurs = [
      for (var j = 0; j < colonnes; j++)
        lignes.map((l) => j < l.length ? l[j].largeur : 0.0).reduce(math.max),
    ];
    const ecart = 0.5;
    const interligne = 0.3;
    final hauts = [
      for (final l in lignes) l.map((c) => c.haut).reduce(math.max),
    ];
    final bas = [for (final l in lignes) l.map((c) => c.bas).reduce(math.max)];
    final hauteur =
        [for (var i = 0; i < lignes.length; i++) hauts[i] + bas[i]]
            .reduce((a, b) => a + b) +
        interligne * (lignes.length - 1);
    // Centrée sur la barre de fraction, comme une fraction.
    final dessus = -0.42 - hauteur / 2;
    const bord = 0.42;
    final traces = <_Trace>[];
    var y = dessus;
    for (var i = 0; i < lignes.length; i++) {
      var x = bord;
      for (var j = 0; j < lignes[i].length; j++) {
        final c = lignes[i][j];
        traces.addAll(
          _deplacer(
            c,
            Offset(x + (largeurs[j] - c.largeur) / 2, y + hauts[i]),
          ).traces,
        );
        x += largeurs[j] + ecart;
      }
      y += hauts[i] + bas[i] + interligne;
    }
    final largeur =
        bord * 2 + largeurs.reduce((a, b) => a + b) + ecart * (colonnes - 1);
    final (h, b) = (dessus - 0.1, dessus + hauteur + 0.1);
    _Trace parenthese(double x, double sens) => [
      for (var k = 0; k <= 12; k++)
        Offset(
          x - sens * 0.22 * math.sin(math.pi * k / 12),
          h + (b - h) * k / 12,
        ),
    ];
    return _Boite(largeur, -h, b, [
      parenthese(0.26, 1),
      parenthese(largeur - 0.26, -1),
      ...traces,
    ]);
  }

  /// Le signe prend de la place : serré, il se confond avec les chiffres et
  /// `√29` se lit `(29` (vu sur le Pad 7).
  _Boite _racine() {
    final corps = _groupe();
    final dessus = -corps.haut - 0.22;
    const gauche = 0.54;
    final droite = gauche + corps.largeur + 0.08;
    return _Boite(droite, -dessus, corps.bas, [
      _l([0, -0.3, 0.12, -0.38, 0.26, corps.bas, 0.44, dessus, droite, dessus]),
      ..._deplacer(corps, const Offset(gauche, 0)).traces,
    ]);
  }
}

/// Le résultat écrit : ses contours, prêts à remplir, en coordonnées de page.
class EcritureResultat {
  const new(
    this.contours,
    this.cadre, {
    this.traces = const [],
    this.taille = 4,
  });

  final List<Path> contours;
  final Rect cadre;

  /// Le chemin de la plume, trait par trait, pour le voir s'écrire.
  final List<List<PointVector>> traces;
  final double taille;

  /// Ce qui est déjà écrit quand on en est à [avancee], de 0 à 1 : les traits
  /// finis, puis le début du trait en cours.
  List<Path> ecrit(double avancee) {
    if (avancee >= 1 || traces.length != contours.length) return contours;
    final total = traces.fold(0, (s, t) => s + t.length);
    var reste = (avancee.clamp(0.0, 1.0) * total).round();
    final faits = <Path>[];
    for (var k = 0; k < traces.length && reste > 0; k++) {
      if (reste >= traces[k].length) {
        faits.add(contours[k]);
        reste -= traces[k].length;
      } else {
        final partiel = _contour(
          traces[k].sublist(0, reste),
          taille,
          fini: false,
        );
        if (partiel != null) faits.add(partiel);
        reste = 0;
      }
    }
    return faits;
  }
}

Path? _contour(List<PointVector> points, double taille, {bool fini = true}) {
  final contour = getStroke(
    points,
    options: StrokeOptions(
      size: taille,
      thinning: 0.45,
      smoothing: 0.6,
      streamline: 0.3,
      simulatePressure: false,
      isComplete: fini,
    ),
  );
  if (contour.isEmpty) return null;
  final chemin = Path()..moveTo(contour.first.dx, contour.first.dy);
  for (var i = 1; i < contour.length - 1; i++) {
    final (a, b) = (contour[i], contour[i + 1]);
    chemin.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }
  return chemin..close();
}

/// Des points rapprochés : le lissage du trait raccourcit sinon les droites.
_Trace _densifier(_Trace trace) {
  final dense = <Offset>[trace.first];
  for (var i = 1; i < trace.length; i++) {
    final (a, b) = (trace[i - 1], trace[i]);
    final n = math.max(1, ((b - a).distance / 0.06).ceil());
    for (var k = 1; k <= n; k++) {
      dense.add(Offset.lerp(a, b, k / n)!);
    }
  }
  return dense;
}

const double _hauteurMin = 22;
const double _hauteurMax = 90;

/// [latex] écrit au propre à la place de [ecriture] : même début, même
/// hauteur, jamais plus large (la ligne d'à côté reste libre). `null` si la
/// main ne sait pas l'écrire.
EcritureResultat? ecrireALaPlace(String latex, Rect ecriture) {
  final _Boite boite;
  try {
    boite = _Compositeur(_matricesSimples(latex)).composer();
  } on _NonPrisEnCharge {
    return null;
  }
  if (boite.traces.isEmpty || boite.largeur <= 0) return null;
  final total = boite.haut + boite.bas;
  final echelle = math.min(
    ecriture.height * 0.85 / total,
    ecriture.width / boite.largeur,
  );
  final origine = Offset(
    ecriture.left,
    ecriture.center.dy + (boite.haut - boite.bas) / 2 * echelle,
  );
  return _tracer(boite, echelle, origine);
}

/// Giac écrit une matrice `\left(\begin{array}{cc}…\end{array}\right)`.
String _matricesSimples(String latex) => latex
    .replaceAll(
      RegExp(r'\\left\(\s*\\begin\{array\}\{[a-z]*\}'),
      r'\begin{pmatrix}',
    )
    .replaceAll(RegExp(r'\\end\{array\}\s*\\right\)'), r'\end{pmatrix}')
    .replaceAll('\n', ' ');

/// Compose [latex] à droite de [ecriture], ou [dessous], à la taille de
/// l'écriture. Rend `null` si ce résultat ne sait pas s'écrire à la main.
EcritureResultat? ecrireResultat(
  String latex,
  Rect ecriture, {
  bool dessous = false,
  double? hauteurLigne,
}) {
  final _Boite boite;
  try {
    boite = _Compositeur(_matricesSimples(latex)).composer();
  } on _NonPrisEnCharge {
    return null;
  }
  if (boite.traces.isEmpty) return null;

  final total = boite.haut + boite.bas;
  // Le résultat occupe environ 80 % de la hauteur de ce qu'on a écrit.
  // Sous une équation sur plusieurs lignes, la hauteur d'une seule ligne.
  // Une fraction redressée double la hauteur, pas la taille de l'écriture.
  final hauteur = hauteurLigne ?? ecriture.height;
  final reference = dessous ? math.min(hauteur, 70) : hauteur;
  final echelle = ((reference * 0.8) / total).clamp(
    _hauteurMin / total,
    _hauteurMax,
  );
  final origine = dessous
      ? Offset(ecriture.left, ecriture.bottom + (0.3 + boite.haut) * echelle)
      : Offset(
          ecriture.right + 0.3 * echelle,
          ecriture.center.dy + (boite.haut - boite.bas) / 2 * echelle,
        );

  return _tracer(boite, echelle, origine);
}

EcritureResultat? _tracer(_Boite boite, double echelle, Offset origine) {
  final contours = <Path>[];
  final traces = <List<PointVector>>[];
  final taille = math.max(3.2, echelle * 0.075);
  for (var k = 0; k < boite.traces.length; k++) {
    if (boite.traces[k].length < 2) continue;
    final points = _densifier(boite.traces[k]);
    final vecteurs = <PointVector>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i] * echelle + origine;
      // Variation discrète et stable : pas deux signes tout à fait pareils.
      final bruit = math.sin(k * 2.1 + i * 0.7) * 0.012 * echelle;
      final pression = 0.5 + 0.2 * math.sin(i / points.length * _pi);
      vecteurs.add(PointVector(p.dx + bruit, p.dy - bruit, pression));
    }
    final chemin = _contour(vecteurs, taille);
    if (chemin == null) continue;
    contours.add(chemin);
    traces.add(vecteurs);
  }
  if (contours.isEmpty) return null;
  final cadre = contours
      .map((c) => c.getBounds())
      .reduce((a, b) => a.expandToInclude(b));
  return EcritureResultat(contours, cadre, traces: traces, taille: taille);
}
