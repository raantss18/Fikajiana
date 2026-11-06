import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/foundation.dart';

const double _uniteInitiale = 40;
const double _uniteMin = 1e-3;
const double _uniteMax = 1000000;

/// Le cadrage : où est l'origine à l'écran, et combien vaut une unité.
class VueGraphe extends ChangeNotifier {
  /// Décalage de l'origine par rapport au centre de l'écran, en pixels.
  Offset decalage = Offset.zero;

  /// Pixels par unité, les mêmes sur les deux axes : un cercle reste rond.
  double unite = _uniteInitiale;

  bool get estInitiale => decalage == Offset.zero && unite == _uniteInitiale;

  Offset versEcran(double x, double y, Size taille) => Offset(
    taille.width / 2 + decalage.dx + x * unite,
    taille.height / 2 + decalage.dy - y * unite,
  );

  ({double x, double y}) versMaths(Offset point, Size taille) => (
    x: (point.dx - taille.width / 2 - decalage.dx) / unite,
    y: -(point.dy - taille.height / 2 - decalage.dy) / unite,
  );

  Fenetre fenetre(Size taille) {
    final (coin, oppose) = (
      versMaths(Offset(0, taille.height), taille),
      versMaths(Offset(taille.width, 0), taille),
    );
    return Fenetre(
      xMin: coin.x,
      xMax: oppose.x,
      yMin: coin.y,
      yMax: oppose.y,
      largeurPixels: taille.width,
      hauteurPixels: taille.height,
    );
  }

  void glisser(Offset delta) {
    decalage += delta;
    notifyListeners();
  }

  /// Zoome en gardant [point] fixe à l'écran.
  void zoomer(double facteur, Offset point, Size taille) {
    final nouvelle = (unite * facteur).clamp(_uniteMin, _uniteMax);
    final effectif = nouvelle / unite;
    final centre = Offset(taille.width / 2, taille.height / 2);
    decalage = point - centre - (point - centre - decalage) * effectif;
    unite = nouvelle;
    notifyListeners();
  }

  void recentrer() {
    decalage = Offset.zero;
    unite = _uniteInitiale;
    notifyListeners();
  }
}

/// Pas de graduation en 1, 2 ou 5 × 10ⁿ, d'au moins [ecart] pixels.
double pasDeGraduation(double unite, {double ecart = 64}) {
  final minimum = ecart / unite;
  final puissance = math.pow(10, (math.log(minimum) / math.ln10).floor());
  for (final m in const [1, 2, 5]) {
    if (m * puissance >= minimum) return (m * puissance).toDouble();
  }
  return (10 * puissance).toDouble();
}

/// Une graduation lisible : pas de `0.30000000000000004`, virgule en français.
String texteGraduation(double valeur, double pas, {required bool virgule}) {
  final decimales = pas >= 1
      ? 0
      : (-(math.log(pas) / math.ln10).floor()).clamp(0, 12);
  final absolu = valeur.abs();
  var texte = absolu != 0 && (absolu >= 1e7 || absolu < 1e-4)
      ? valeur.toStringAsExponential(1)
      : valeur.toStringAsFixed(decimales);
  if (virgule) texte = texte.replaceAll('.', ',');
  return texte.replaceAll('-', '−');
}

/// Une coordonnée lue sur la courbe : 4 chiffres significatifs.
String texteValeur(double valeur, {required bool virgule}) {
  if (valeur.abs() < 1e-9) return '0';
  var texte = valeur.toStringAsPrecision(4);
  if (texte.contains('.') && !texte.contains('e')) {
    texte = texte
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  if (virgule) texte = texte.replaceAll('.', ',');
  return texte.replaceAll('-', '−');
}

/// La courbe la plus proche de [point], à moins de [rayon] pixels.
({int indice, double x, double y})? courbeProche(
  List<FonctionReelle> fonctions,
  Offset point,
  VueGraphe vue,
  Size taille, {
  double rayon = 32,
}) {
  ({int indice, double x, double y})? meilleure;
  var distance = rayon;
  final maths = vue.versMaths(point, taille);
  for (var i = 0; i < fonctions.length; i++) {
    final y = fonctions[i](maths.x);
    if (!y.isFinite) continue;
    final d = (vue.versEcran(maths.x, y, taille).dy - point.dy).abs();
    if (d <= distance) {
      distance = d;
      meilleure = (indice: i, x: maths.x, y: y);
    }
  }
  return meilleure;
}
