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
