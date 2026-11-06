import 'dart:math' as math;

/// L'expression n'est pas évaluable numériquement.
class ErreurEvaluation implements Exception {
  /// Crée l'erreur.
  const new(this.message);

  /// Détail, pour le débogage.
  final String message;

  @override
  String toString() => 'ErreurEvaluation: $message';
}

/// Une fonction réelle : `NaN` là où elle n'est pas définie.
typedef FonctionReelle = double Function(double);

/// Compile une entrée Giac d'une [variable] en fonction Dart.
///
/// Un tracé demande des milliers de points : appeler Giac pour chacun serait
/// trop lent. Lève [ErreurEvaluation] pour ce qui sort des fonctions usuelles.
FonctionReelle compilerFonction(
  String giac, {
  String variable = 'x',
  bool degres = false,
}) {
  return _Lecteur(giac, variable, degres ? math.pi / 180 : 1).expression();
}

/// Une fonction réelle de deux variables : `NaN` là où elle n'est pas définie.
typedef FonctionDeuxVariables = double Function(double, double);

/// Compile une entrée Giac en `x` et `y`, pour une courbe implicite.
FonctionDeuxVariables compilerFonctionXY(String giac, {bool degres = false}) {
  final y = _Case();
  final f = _Lecteur(
    giac,
    'x',
    degres ? math.pi / 180 : 1,
    autre: y,
  ).expression();
  return (a, b) {
    y.valeur = b;
    return f(a);
  };
}

/// La valeur de `y` pendant une évaluation.
class _Case {
  double valeur = 0;
}

class _Lecteur {
  new(this._s, this._variable, this._angle, {this._autre});

  final _Case? _autre;

  final String _s;
  final String _variable;
  final double _angle;
  var _i = 0;

  FonctionReelle expression() {
    final f = _somme();
    _espaces();
    if (_i < _s.length) throw ErreurEvaluation('reste : ${_s.substring(_i)}');
    return f;
  }

  void _espaces() {
    while (_i < _s.length && _s[_i] == ' ') {
      _i++;
    }
  }

  bool _prendre(String c) {
    _espaces();
    if (_i < _s.length && _s[_i] == c) {
      _i++;
      return true;
    }
    return false;
  }

  FonctionReelle _somme() {
    var f = _produit();
    while (true) {
      final g = f;
      if (_prendre('+')) {
        final d = _produit();
        f = (x) => g(x) + d(x);
      } else if (_prendre('-')) {
        final d = _produit();
        f = (x) => g(x) - d(x);
      } else {
        return f;
      }
    }
  }

  FonctionReelle _produit() {
    var f = _unaire();
    while (true) {
      final g = f;
      if (_prendre('*')) {
        final d = _unaire();
        f = (x) => g(x) * d(x);
      } else if (_prendre('/')) {
        final d = _unaire();
        f = (x) => g(x) / d(x);
      } else {
        return f;
      }
    }
  }

  FonctionReelle _unaire() {
    if (_prendre('-')) {
      final f = _unaire();
      return (x) => -f(x);
    }
    if (_prendre('+')) return _unaire();
    return _puissance();
  }

  FonctionReelle _puissance() {
    final base = _atome();
    if (!_prendre('^')) return base;
    final exposant = _unaire();
    return (x) => math.pow(base(x), exposant(x)).toDouble();
  }

  FonctionReelle _atome() {
    _espaces();
    if (_i >= _s.length) throw const ErreurEvaluation('fin inattendue');
    if (_prendre('(')) {
      final f = _somme();
      if (!_prendre(')')) throw const ErreurEvaluation('parenthèse');
      return f;
    }
    final debut = _i;
    if (RegExp('[0-9.]').hasMatch(_s[_i])) {
      while (_i < _s.length && RegExp('[0-9.]').hasMatch(_s[_i])) {
        _i++;
      }
      final valeur = double.tryParse(_s.substring(debut, _i));
      if (valeur == null) throw const ErreurEvaluation('nombre');
      return (_) => valeur;
    }
    while (_i < _s.length && RegExp('[a-zA-Z0-9_]').hasMatch(_s[_i])) {
      _i++;
    }
    final nom = _s.substring(debut, _i);
    if (nom.isEmpty) throw ErreurEvaluation('signe : ${_s[_i]}');
    if (_prendre('(')) {
      final argument = _somme();
      if (!_prendre(')')) throw const ErreurEvaluation('parenthèse');
      return _appel(nom, argument);
    }
    if (nom == _variable) return (x) => x;
    final autre = _autre;
    if (nom == 'y' && autre != null) return (_) => autre.valeur;
    return switch (nom) {
      'pi' => (_) => math.pi,
      'e' => (_) => math.e,
      _ => throw ErreurEvaluation('symbole : $nom'),
    };
  }

  FonctionReelle _appel(String nom, FonctionReelle f) {
    final a = _angle;
    return switch (nom) {
      'sin' => (x) => math.sin(a * f(x)),
      'cos' => (x) => math.cos(a * f(x)),
      'tan' => (x) => math.tan(a * f(x)),
      'cot' => (x) => 1 / math.tan(a * f(x)),
      'asin' => (x) => math.asin(f(x)) / a,
      'acos' => (x) => math.acos(f(x)) / a,
      'atan' => (x) => math.atan(f(x)) / a,
      'sinh' => (x) {
        final v = f(x);
        return (math.exp(v) - math.exp(-v)) / 2;
      },
      'cosh' => (x) {
        final v = f(x);
        return (math.exp(v) + math.exp(-v)) / 2;
      },
      'tanh' => (x) {
        final v = f(x);
        final (p, m) = (math.exp(v), math.exp(-v));
        // Au-delà, exp déborde : tanh vaut ±1.
        return p.isInfinite
            ? 1.0
            : m.isInfinite
            ? -1.0
            : (p - m) / (p + m);
      },
      'ln' => (x) => math.log(f(x)),
      'log10' => (x) => math.log(f(x)) / math.ln10,
      'exp' => (x) => math.exp(f(x)),
      'sqrt' => (x) => math.sqrt(f(x)),
      'abs' => (x) => f(x).abs(),
      _ => throw ErreurEvaluation('fonction : $nom'),
    };
  }
}
