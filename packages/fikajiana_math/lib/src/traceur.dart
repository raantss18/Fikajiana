import 'dart:math' as math;

import 'package:fikajiana_math/src/evaluateur.dart';

/// Un point du tracé.
typedef PointTrace = ({double x, double y});

/// Fenêtre de tracé, en coordonnées mathématiques, et sa taille à l'écran.
class Fenetre {
  /// Crée une fenêtre.
  const new({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.largeurPixels,
    required this.hauteurPixels,
  });

  /// Bord gauche.
  final double xMin;

  /// Bord droit.
  final double xMax;

  /// Bord bas.
  final double yMin;

  /// Bord haut.
  final double yMax;

  /// Largeur à l'écran.
  final double largeurPixels;

  /// Hauteur à l'écran.
  final double hauteurPixels;

  /// Hauteur mathématique.
  double get hauteur => yMax - yMin;
}

const int _profondeurMax = 10;

/// Écart toléré à la corde, en pixels.
const double _tolerance = 0.5;

/// Échantillonne [f] sur la [fenetre] : plus de points là où la courbe tourne,
/// une coupure aux asymptotes et aux sauts, où relier les points serait faux.
List<List<PointTrace>> tracerFonction(FonctionReelle f, Fenetre fenetre) {
  final traceur = _Traceur(f, fenetre);
  final pas = (fenetre.largeurPixels / 8).ceil().clamp(16, 512);
  final largeur = (fenetre.xMax - fenetre.xMin) / pas;
  for (var i = 0; i < pas; i++) {
    traceur.segment(
      fenetre.xMin + i * largeur,
      fenetre.xMin + (i + 1) * largeur,
      0,
    );
  }
  return traceur.morceaux();
}

class _Traceur {
  new(this._f, this._fenetre);

  final FonctionReelle _f;
  final Fenetre _fenetre;
  final _morceaux = <List<PointTrace>>[];
  var _courant = <PointTrace>[];

  List<List<PointTrace>> morceaux() {
    _couper();
    return _morceaux;
  }

  void _couper() {
    if (_courant.length > 1) _morceaux.add(_courant);
    _courant = [];
  }

  void _ajouter(double x, double y) {
    if (_courant.isEmpty || _courant.last.x != x) {
      _courant.add((x: x, y: y));
    }
  }

  void segment(double a, double b, int profondeur) {
    final (ya, yb) = (_f(a), _f(b));
    final milieu = (a + b) / 2;
    final ym = _f(milieu);
    final definis = ya.isFinite && yb.isFinite && ym.isFinite;

    if (!definis) {
      // Le bord du domaine, comme 0 pour ln(x) : on s'en approche.
      if (profondeur >= _profondeurMax) {
        if (ya.isFinite) _ajouter(a, ya);
        _couper();
        if (yb.isFinite) _ajouter(b, yb);
        return;
      }
      if (!ya.isFinite && !yb.isFinite && !ym.isFinite) {
        _couper();
        return;
      }
      segment(a, milieu, profondeur + 1);
      segment(milieu, b, profondeur + 1);
      return;
    }

    final horsVue =
        _dehors(ya) &&
        _dehors(yb) &&
        _dehors(ym) &&
        (ya > _fenetre.yMax) == (yb > _fenetre.yMax);
    final echelle = _fenetre.hauteurPixels / _fenetre.hauteur;
    final ecart = (ym - (ya + yb) / 2).abs() * echelle;
    final raide = (yb - ya).abs() > _fenetre.hauteur / 4;
    if ((ecart > _tolerance || raide) &&
        !horsVue &&
        profondeur < _profondeurMax) {
      segment(a, milieu, profondeur + 1);
      segment(milieu, b, profondeur + 1);
      return;
    }

    _ajouter(a, ya);
    if (raide && _saut(a, b)) {
      _couper();
    }
    _ajouter(b, yb);
  }

  bool _dehors(double y) => y > _fenetre.yMax || y < _fenetre.yMin;

  /// Resserre l'intervalle sur sa plus forte pente : un écart qui reste grand
  /// est un vrai saut, pas une courbe raide.
  bool _saut(double debut, double fin) {
    var (a, b) = (debut, fin);
    var (ya, yb) = (_f(a), _f(b));
    for (var i = 0; i < 50; i++) {
      final m = (a + b) / 2;
      if (m == a || m == b) break;
      final ym = _f(m);
      if (!ym.isFinite) return true;
      if ((ym - ya).abs() > (yb - ym).abs()) {
        b = m;
        yb = ym;
      } else {
        a = m;
        ya = ym;
      }
    }
    return (yb - ya).abs() > _fenetre.hauteur / 100;
  }
}

/// Combien de fois une maille traversée par la courbe est encore coupée.
const int _finesseImplicite = 2;

/// Trace `f(x, y) = 0` : une grille de mailles de 8 pixels, affinée là où `f`
/// change de signe, puis le découpage des carrés marchants (marching squares).
///
/// Rend des segments à relier deux par deux. Là où `f` s'annule sans changer de
/// signe, comme `(x - y)² = 0`, rien n'est vu ; un pôle n'est pas pris pour la
/// courbe : `f` y reste grande au lieu de s'annuler.
List<List<PointTrace>> tracerImplicite(
  FonctionDeuxVariables f,
  Fenetre fenetre,
) {
  final nx = (fenetre.largeurPixels / 8).ceil().clamp(16, 160);
  final ny = (fenetre.hauteurPixels / 8).ceil().clamp(16, 160);
  final (dx, dy) = ((fenetre.xMax - fenetre.xMin) / nx, fenetre.hauteur / ny);
  final valeurs = [
    for (var j = 0; j <= ny; j++)
      [
        for (var i = 0; i <= nx; i++)
          f(fenetre.xMin + i * dx, fenetre.yMin + j * dy),
      ],
  ];
  final segments = <List<PointTrace>>[];
  final maille = _MailleImplicite(f, segments);
  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      final (x, y) = (fenetre.xMin + i * dx, fenetre.yMin + j * dy);
      maille.parcourir(
        x,
        y,
        x + dx,
        y + dy,
        valeurs[j][i],
        valeurs[j][i + 1],
        valeurs[j + 1][i],
        valeurs[j + 1][i + 1],
        0,
      );
    }
  }
  return segments;
}

class _MailleImplicite {
  const new(this._f, this._segments);

  final FonctionDeuxVariables _f;
  final List<List<PointTrace>> _segments;

  void parcourir(
    double x0,
    double y0,
    double x1,
    double y1,
    double f00,
    double f10,
    double f01,
    double f11,
    int profondeur,
  ) {
    final finies = f00.isFinite && f10.isFinite && f01.isFinite && f11.isFinite;
    final toutesNan =
        !f00.isFinite && !f10.isFinite && !f01.isFinite && !f11.isFinite;
    if (toutesNan) return;
    if (finies) {
      final signe = f00 >= 0;
      if ((f10 >= 0) == signe && (f01 >= 0) == signe && (f11 >= 0) == signe) {
        return;
      }
    }
    if (profondeur < _finesseImplicite) {
      final (xm, ym) = ((x0 + x1) / 2, (y0 + y1) / 2);
      final (bas, gauche, centre, droite, haut) = (
        _f(xm, y0),
        _f(x0, ym),
        _f(xm, ym),
        _f(x1, ym),
        _f(xm, y1),
      );
      final p = profondeur + 1;
      parcourir(x0, y0, xm, ym, f00, bas, gauche, centre, p);
      parcourir(xm, y0, x1, ym, bas, f10, centre, droite, p);
      parcourir(x0, ym, xm, y1, gauche, centre, f01, haut, p);
      parcourir(xm, ym, x1, y1, centre, droite, haut, f11, p);
      return;
    }
    if (!finies) return;
    // Les côtés traversés : bas, droite, haut, gauche.
    final bas = _croisement(x0, y0, x1, y0, f00, f10);
    final droite = _croisement(x1, y0, x1, y1, f10, f11);
    final haut = _croisement(x0, y1, x1, y1, f01, f11);
    final gauche = _croisement(x0, y0, x0, y1, f00, f01);
    final points = [?bas, ?droite, ?haut, ?gauche];
    if (points.length == 2) {
      _segments.add(points);
    } else if (points.length == 4) {
      // Deux passages dans la maille : le signe du centre dit lesquels relier.
      final centre = _f((x0 + x1) / 2, (y0 + y1) / 2);
      if ((centre >= 0) == (f00 >= 0)) {
        _segments
          ..add([bas!, droite!])
          ..add([haut!, gauche!]);
      } else {
        _segments
          ..add([bas!, gauche!])
          ..add([droite!, haut!]);
      }
    }
  }

  PointTrace? _croisement(
    double xa,
    double ya,
    double xb,
    double yb,
    double fa,
    double fb,
  ) {
    if ((fa >= 0) == (fb >= 0)) return null;
    final t = fa / (fa - fb);
    final (x, y) = (xa + t * (xb - xa), ya + t * (yb - ya));
    final ici = _f(x, y);
    // Un vrai zéro y laisse presque rien ; un pôle y reste grand.
    if (!ici.isFinite || ici.abs() > 0.5 * math.max(fa.abs(), fb.abs())) {
      return null;
    }
    return (x: x, y: y);
  }
}

/// Trace une courbe paramétrée pour `t` de [debut] à [fin] : plus de points là
/// où elle tourne, une coupure là où elle n'existe pas ou saute.
List<List<PointTrace>> tracerParametree(
  FonctionReelle fx,
  FonctionReelle fy,
  double debut,
  double fin,
  Fenetre fenetre,
) {
  final traceur = _TraceurParametre(fx, fy, fenetre);
  const pas = 256;
  for (var i = 0; i < pas; i++) {
    traceur.segment(
      debut + (fin - debut) * i / pas,
      debut + (fin - debut) * (i + 1) / pas,
      0,
    );
  }
  return traceur.morceaux();
}

class _TraceurParametre {
  new(this._fx, this._fy, this._fenetre);

  final FonctionReelle _fx;
  final FonctionReelle _fy;
  final Fenetre _fenetre;
  final _morceaux = <List<PointTrace>>[];
  var _courant = <PointTrace>[];

  static const int _profondeur = 8;

  double get _echelle => _fenetre.hauteurPixels / _fenetre.hauteur;

  List<List<PointTrace>> morceaux() {
    _couper();
    return _morceaux;
  }

  void _couper() {
    if (_courant.length > 1) _morceaux.add(_courant);
    _courant = [];
  }

  void _ajouter(PointTrace p) {
    if (_courant.isEmpty || _courant.last != p) _courant.add(p);
  }

  bool _dehors(PointTrace p) {
    final marge = _fenetre.hauteur;
    return p.x < _fenetre.xMin - marge ||
        p.x > _fenetre.xMax + marge ||
        p.y < _fenetre.yMin - marge ||
        p.y > _fenetre.yMax + marge;
  }

  void segment(double a, double b, int profondeur) {
    final (pa, pb) = ((x: _fx(a), y: _fy(a)), (x: _fx(b), y: _fy(b)));
    final m = (a + b) / 2;
    final pm = (x: _fx(m), y: _fy(m));
    bool finie(PointTrace p) => p.x.isFinite && p.y.isFinite;
    if (!finie(pa) || !finie(pb) || !finie(pm)) {
      if (profondeur < _profondeur && (finie(pa) || finie(pb) || finie(pm))) {
        segment(a, m, profondeur + 1);
        segment(m, b, profondeur + 1);
        return;
      }
      if (finie(pa)) _ajouter(pa);
      _couper();
      if (finie(pb)) _ajouter(pb);
      return;
    }
    if (_dehors(pa) && _dehors(pb) && _dehors(pm)) {
      _couper();
      return;
    }
    final ecart = math.sqrt(
      math.pow(pm.x - (pa.x + pb.x) / 2, 2) +
          math.pow(pm.y - (pa.y + pb.y) / 2, 2),
    );
    final corde = math.sqrt(
      math.pow(pb.x - pa.x, 2) + math.pow(pb.y - pa.y, 2),
    );
    if ((ecart * _echelle > _tolerance || corde * _echelle > 24) &&
        profondeur < _profondeur) {
      segment(a, m, profondeur + 1);
      segment(m, b, profondeur + 1);
      return;
    }
    _ajouter(pa);
    // Encore long au plus fin : c'est un saut, pas une courbe.
    if (corde * _echelle > 48) _couper();
    _ajouter(pb);
  }
}
