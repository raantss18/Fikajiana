import 'dart:async';

import 'package:fikajiana/moteur/giac.dart';

/// Ce qu'il faut du moteur de calcul : remplaçable dans les tests.
abstract class Moteur {
  Future<ReponseGiac> calculer(String entree);
  void interrompre();
}

/// Giac, un calcul à la fois, arrêté s'il dépasse [delai].
class MoteurGiac implements Moteur {
  new({this.delai = const Duration(seconds: 15)});

  final Duration delai;
  Future<void> _file = Future.value();

  @override
  Future<ReponseGiac> calculer(String entree) {
    final resultat = _file.then((_) => _executer(entree));
    _file = resultat.then((_) {}, onError: (_) {});
    return resultat;
  }

  Future<ReponseGiac> _executer(String entree) async {
    final minuteur = Timer(delai, interrompre);
    try {
      return await calculerGiac(entree);
    } finally {
      minuteur.cancel();
    }
  }

  @override
  void interrompre() => interrompreGiac();
}
