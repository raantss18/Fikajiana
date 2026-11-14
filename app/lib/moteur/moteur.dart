import 'dart:async';

import 'package:fikajiana/moteur/giac.dart';

/// Ce qu'il faut du moteur de calcul : remplaçable dans les tests.
abstract class Moteur {
  Future<ReponseGiac> calculer(String entree, {bool degres = false});
  void interrompre();
}

/// Le calcul lui-même : Giac dans l'app, un faux dans les tests.
typedef CalculGiac = Future<ReponseGiac> Function(String entree, {bool degres});

/// Une entrée dont le résultat ne tiendrait ni sur la feuille ni en mémoire :
/// refusée avant Giac, que GMP ne sait pas arrêter (audit 2026-11-14, H1).
///
/// Rend le message d'erreur, ou `null` si l'entrée peut être calculée.
String? entreeDemesuree(String entree) {
  if (entree.length > longueurEntreeMax) return 'trop long';
  for (final m in RegExp(r'factorial\((\d+)\)|(\d+)!').allMatches(entree)) {
    final n = BigInt.parse(m[1] ?? m[2]!);
    if (n > BigInt.from(factorielleMax)) return 'trop grand';
  }
  // Un exposant entier écrit en toutes lettres : 9^999999, 2^(10^9).
  for (final m in RegExp(r'\^\(?(\d{6,})').allMatches(entree)) {
    if (BigInt.parse(m[1]!) > BigInt.from(exposantMax)) return 'trop grand';
  }
  return null;
}

/// Bornes de [entreeDemesuree] ; la colle C applique la même à la factorielle.
const factorielleMax = 2000;
const exposantMax = 200000;
const longueurEntreeMax = 20000;

/// Giac, un calcul à la fois, arrêté s'il dépasse [delai].
///
/// Si Giac ne s'arrête pas (un calcul de GMP ne teste pas le drapeau), le
/// calcul est rendu « arrêté » après [sursis] et le moteur reste occupé :
/// les calculs suivants sont refusés tout de suite au lieu d'attendre sans
/// fin, jusqu'à ce que Giac revienne. Jamais deux calculs à la fois : le
/// contexte Giac est unique.
class MoteurGiac implements Moteur {
  new({
    this.delai = const Duration(seconds: 15),
    this.sursis = const Duration(seconds: 5),
    CalculGiac? calcul,
    void Function()? arret,
  }) : _calcul = calcul ?? calculerGiac,
       _arret = arret ?? interrompreGiac;

  final Duration delai;
  final Duration sursis;
  final CalculGiac _calcul;
  final void Function() _arret;
  Future<void> _file = Future.value();
  bool _coince = false;

  /// Giac n'est pas revenu d'un calcul arrêté : rien d'autre ne peut tourner.
  bool get occupe => _coince;

  static const _occupe = ReponseGiac(
    exact: '',
    latex: '',
    approche: '',
    erreur: 'moteur occupé',
  );
  static const _arrete = ReponseGiac(
    exact: '',
    latex: '',
    approche: '',
    arrete: true,
  );

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) {
    if (entreeDemesuree(entree) case final message?) {
      return Future.value(
        ReponseGiac(exact: '', latex: '', approche: '', erreur: message),
      );
    }
    if (_coince) return Future.value(_occupe);
    final resultat = _file.then((_) => _executer(entree, degres));
    _file = resultat.then((_) {}, onError: (_) {});
    return resultat;
  }

  Future<ReponseGiac> _executer(String entree, bool degres) async {
    if (_coince) return _occupe;
    final minuteur = Timer(delai, interrompre);
    final calcul = _calcul(entree, degres: degres);
    try {
      return await calcul.timeout(
        delai + sursis,
        onTimeout: () {
          _coince = true;
          // Le moteur se libère quand Giac revient enfin, quoi qu'il rende.
          unawaited(
            calcul.then(
              (_) => _coince = false,
              onError: (_) => _coince = false,
            ),
          );
          return _arrete;
        },
      );
    } finally {
      minuteur.cancel();
    }
  }

  @override
  void interrompre() => _arret();
}
