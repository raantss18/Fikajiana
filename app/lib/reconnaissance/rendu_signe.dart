import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Le rendu d'un signe pour le petit modèle, tel que le fixe le contrat v1
/// (`entrainement/CONTRAT.md`, ADR 0040) et le fait `entrainement/rendu.py` :
/// image 32×32 (part d'encre, 0 à 1) et cinq mesures du tracé.
///
/// En Dart pur, sans Skia : le même dessin que Pillow à l'entraînement
/// (segments épais et disques aux points, sans anticrénelage, sur une
/// toile 128×128, puis moyenne des blocs 4×4), réglé contre Pillow 13 :
/// mêmes disques, mêmes bouts tronqués. L'écart est mesuré par
/// `test/reconnaissance/rendu_signe_test.dart`.
const int tailleImage = 32;
const int _sur = 4;
const int _marge = 2;
const double _epaisseur = 2;
const double _coteMinimal = 0.15;
const int _pasQuadratique = 8;

/// Nombre de mesures du tracé, dans l'ordre du contrat.
const int nombreMesures = 5;

/// Le disque que Pillow dessine pour `ellipse` dans une boîte de 8 px.
const List<String> _disque = [
  '...###...',
  '.#######.',
  '.#######.',
  '#########',
  '#########',
  '#########',
  '.#######.',
  '.#######.',
  '...###...',
];

/// Les arrondis du trait épais de Pillow, vérifiés contre son dessin.
int _versHaut(double f) =>
    f >= 0 ? (f + 0.5).floor() : -(f.abs() + 0.5).floor();
int _versBas(double f) => f >= 0 ? (f - 0.5).ceil() : -(f.abs() - 0.5).ceil();

/// L'arrondi de Python : au pair le plus proche à mi-chemin.
int _arrondiPair(double x) {
  final f = x.floorToDouble();
  final reste = x - f;
  if (reste > 0.5) return f.toInt() + 1;
  if (reste < 0.5) return f.toInt();
  return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
}

/// La boîte des points : `(x0, y0, x1, y1)`.
(double, double, double, double) _boite(List<List<Offset>> traits) {
  var (x0, y0, x1, y1) = (
    double.infinity,
    double.infinity,
    double.negativeInfinity,
    double.negativeInfinity,
  );
  for (final t in traits) {
    for (final p in t) {
      x0 = math.min(x0, p.dx);
      y0 = math.min(y0, p.dy);
      x1 = math.max(x1, p.dx);
      y1 = math.max(y1, p.dy);
    }
  }
  return (x0, y0, x1, y1);
}

/// Le chemin de `cheminDuTrait`, aplati en segments comme `rendu.py`.
List<Offset> _chemin(List<Offset> points) {
  if (points.length == 1) return [points.first];
  final sortie = [points.first];
  var courant = points.first;
  for (var i = 1; i < points.length - 1; i++) {
    final a = points[i];
    final fin = (a + points[i + 1]) / 2;
    for (var j = 1; j <= _pasQuadratique; j++) {
      final t = j / _pasQuadratique;
      final u = 1 - t;
      sortie.add(courant * (u * u) + a * (2 * u * t) + fin * (t * t));
    }
    courant = fin;
  }
  sortie.add(points.last);
  return sortie;
}

/// L'image du signe : 32×32 valeurs, rangées ligne par ligne.
///
/// [hauteurCase] : la hauteur `H` de la case de la ligne.
Float32List rendreSigne(List<List<Offset>> traits, double hauteurCase) {
  final image = Float32List(tailleImage * tailleImage);
  final pleins = [
    for (final t in traits)
      if (t.isNotEmpty) t,
  ];
  if (pleins.isEmpty) return image;
  final (x0, y0, x1, y1) = _boite(pleins);
  var cote = math.max(math.max(x1 - x0, y1 - y0), _coteMinimal * hauteurCase);
  if (cote <= 0) cote = 1;
  const n = tailleImage * _sur;
  final k = (tailleImage - 2 * _marge) * _sur / cote;
  final centre = Offset((x0 + x1) / 2, (y0 + y1) / 2);
  final toile = Uint8List(n * n);
  void allumer(int x, int y) {
    if (x >= 0 && x < n && y >= 0 && y < n) toile[y * n + x] = 1;
  }

  // Le disque de Pillow, `ellipse([x − 4, y − 4, x + 4, y + 4])` : ses
  // bords sont tronqués à l'entier, le dessin est toujours ce masque 9×9.
  void disque(Offset c) {
    final gx = c.dx.truncate() - 4;
    final hy = c.dy.truncate() - 4;
    for (var j = 0; j < _disque.length; j++) {
      for (var i = 0; i < _disque[j].length; i++) {
        if (_disque[j][i] == '#') allumer(gx + i, hy + j);
      }
    }
  }

  // Le trait épais de Pillow (`ImagingDrawWideLine`) : bouts tronqués à
  // l'entier, un quadrilatère rempli ligne par ligne.
  void segment(Offset a, Offset b) {
    final (x0, y0, x1, y1) = (
      a.dx.truncate(),
      a.dy.truncate(),
      b.dx.truncate(),
      b.dy.truncate(),
    );
    final (dx, dy) = (x1 - x0, y1 - y0);
    if (dx == 0 && dy == 0) {
      allumer(x0, y0);
      return;
    }
    final grand = math.sqrt(dx * dx + dy * dy);
    const petit = (_epaisseur * _sur - 1) / 2;
    final rMax = _versHaut(petit) / grand;
    final rMin = _versBas(petit) / grand;
    final dxMin = _versBas(rMin * dy);
    final dxMax = _versBas(rMax * dy);
    final dyMin = _versBas(rMin * dx);
    final dyMax = _versBas(rMax * dx);
    final v = [
      (x0 - dxMin, y0 + dyMax),
      (x1 - dxMin, y1 + dyMax),
      (x1 + dxMax, y1 - dyMin),
      (x0 + dxMax, y0 - dyMin),
    ];
    final hauts = [for (final (_, y) in v) y];
    for (var y = hauts.reduce(math.min); y <= hauts.reduce(math.max); y++) {
      final xs = <double>[];
      for (var i = 0; i < 4; i++) {
        final (ax, ay) = v[i];
        final (bx, by) = v[(i + 1) % 4];
        if (ay == by) {
          if (ay == y) xs.addAll([ax.toDouble(), bx.toDouble()]);
          continue;
        }
        if (y >= math.min(ay, by) && y <= math.max(ay, by)) {
          xs.add(ax + (y - ay) * (bx - ax) / (by - ay));
        }
      }
      if (xs.isEmpty) continue;
      final debut = _arrondiPair(xs.reduce(math.min));
      final fin = _arrondiPair(xs.reduce(math.max));
      for (var x = debut; x <= fin; x++) {
        allumer(x, y);
      }
    }
  }

  for (final t in pleins) {
    final pts = [
      for (final p in _chemin(t)) (p - centre) * k + const Offset(n / 2, n / 2),
    ];
    for (var i = 1; i < pts.length; i++) {
      segment(pts[i - 1], pts[i]);
    }
    pts.forEach(disque);
  }
  for (var y = 0; y < tailleImage; y++) {
    for (var x = 0; x < tailleImage; x++) {
      var somme = 0;
      for (var j = 0; j < _sur; j++) {
        for (var i = 0; i < _sur; i++) {
          somme += toile[(y * _sur + j) * n + x * _sur + i];
        }
      }
      image[y * tailleImage + x] = somme / (_sur * _sur);
    }
  }
  return image;
}

/// Les cinq mesures du tracé : rapport, traits, hauteur, largeur, centre.
///
/// [caseLigne] : la case de la ligne ; seuls son haut et sa hauteur servent.
Float32List mesurerSigne(List<List<Offset>> traits, Rect caseLigne) {
  final pleins = [
    for (final t in traits)
      if (t.isNotEmpty) t,
  ];
  final (x0, y0, x1, y1) = _boite(pleins);
  final (w, h) = (x1 - x0, y1 - y0);
  final grand = math.max(caseLigne.height, 1e-6);
  double borne(double v, double a, double b) => math.min(math.max(v, a), b);
  return Float32List.fromList([
    borne(math.log((w + 0.02 * grand) / (h + 0.02 * grand)), -3, 3),
    math.min(pleins.length, 4) / 4,
    borne(h / grand, 0, 2),
    borne(w / grand, 0, 3),
    borne(((y0 + y1) / 2 - caseLigne.top) / grand, -0.5, 1.5),
  ]);
}

/// La hauteur médiane des signes d'une ligne.
double hauteurMediane(List<List<List<Offset>>> signes) {
  final hauteurs = [
    for (final s in signes)
      if (s.any((t) => t.isNotEmpty))
        math.max(1e-6, _boite(s).$4 - _boite(s).$2),
  ]..sort();
  if (hauteurs.isEmpty) return 1;
  final m = hauteurs.length ~/ 2;
  return hauteurs.length.isOdd
      ? hauteurs[m]
      : (hauteurs[m - 1] + hauteurs[m]) / 2;
}

/// La case d'un signe (contrat v1) : la boîte des traits de la ligne qui le
/// recouvrent verticalement, sans ceux plus hauts que 2,5 fois la hauteur
/// [mediane] des signes (grandes parenthèses, barres de matrice).
Rect caseDuSigne(
  List<List<Offset>> signe,
  List<List<Offset>> traitsDeLaLigne,
  double mediane,
) {
  final (_, haut, _, bas) = _boite(signe);
  final ligne = [...signe];
  for (final t in traitsDeLaLigne) {
    if (t.isEmpty) continue;
    final (_, th, _, tb) = _boite([t]);
    if (tb - th <= 2.5 * mediane && tb >= haut && th <= bas) ligne.add(t);
  }
  final (gx, lh, dx, lb) = _boite(ligne);
  return Rect.fromLTWH(gx, lh, dx - gx, math.max(lb - lh, 1e-6));
}
