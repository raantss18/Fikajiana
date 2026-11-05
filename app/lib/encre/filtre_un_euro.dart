import 'dart:math' as math;
import 'dart:ui';

/// Filtre 1€ sur une valeur : lisse à vitesse lente, suit à vitesse rapide.
///
/// Casiez, Roussel et Vogel, CHI 2012 : https://gery.casiez.net/1euro/
class _FiltreScalaire {
  new(this.coupureMin, this.beta);

  final double coupureMin;
  final double beta;

  /// Valeur conseillée par les auteurs (`dcutoff`), à revérifier sur l'article.
  static const double _coupureDerivee = 1;

  double? _valeur;
  double _derivee = 0;

  static double _alpha(double coupure, double dt) {
    final tau = 1 / (2 * math.pi * coupure);
    return 1 / (1 + tau / dt);
  }

  double filtrer(double x, double dt) {
    final precedente = _valeur;
    if (precedente == null) {
      _valeur = x;
      return x;
    }
    final derivee = (x - precedente) / dt;
    final alphaDerivee = _alpha(_coupureDerivee, dt);
    _derivee = alphaDerivee * derivee + (1 - alphaDerivee) * _derivee;
    final coupure = coupureMin + beta * _derivee.abs();
    final alpha = _alpha(coupure, dt);
    final filtree = alpha * x + (1 - alpha) * precedente;
    _valeur = filtree;
    return filtree;
  }
}

/// Filtre 1€ sur une position, en pixels logiques et en millisecondes.
class FiltreUnEuro {
  /// À ajuster au stylet : `beta` d'abord nul, puis augmenté jusqu'à réduire le
  /// retard en mouvement rapide (méthode de la page du filtre).
  new({double coupureMin = 1.5, double beta = 0.02})
    : _x = _FiltreScalaire(coupureMin, beta),
      _y = _FiltreScalaire(coupureMin, beta);

  final _FiltreScalaire _x;
  final _FiltreScalaire _y;
  double? _dernierTemps;

  /// Sans écart de temps exploitable, on suppose 120 Hz.
  static const double _dtParDefaut = 1 / 120;

  Offset filtrer(Offset position, double? tempsMs) {
    final dernier = _dernierTemps;
    final dt = tempsMs != null && dernier != null && tempsMs > dernier
        ? (tempsMs - dernier) / 1000
        : _dtParDefaut;
    _dernierTemps = tempsMs ?? dernier;
    return Offset(_x.filtrer(position.dx, dt), _y.filtrer(position.dy, dt));
  }
}
