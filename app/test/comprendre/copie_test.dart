import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/copie.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les réponses du vrai Giac, enregistrées par `tool/enregistrer_giac.dart`.
class _GiacEnregistre implements Moteur {
  new({this.muet = false});

  /// Giac ne répond pas : calcul arrêté.
  final bool muet;
  final Map<String, dynamic> _reponses = jsonDecode(
    File('test/fixtures/giac/copie.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async {
    if (muet) {
      return const ReponseGiac(
        exact: '',
        latex: '',
        approche: '',
        arrete: true,
      );
    }
    final r = _reponses[entree] as Map<String, dynamic>?;
    if (r == null) fail('calcul non enregistré : $entree');
    return ReponseGiac(
      exact: r['exact'] as String,
      latex: r['latex'] as String,
      approche: r['approche'] as String,
      erreur: r['erreur'] as String?,
    );
  }

  @override
  void interrompre() {}
}

LigneCopie _ligne(String latex) {
  final a = analyserLatex(latex);
  final x = a.inconnues.singleOrNull;
  return a.membres != null && x != null
      ? LigneCopie.equation(latex, a.membres!.$1, a.membres!.$2, x)
      : LigneCopie(latex, a.giac);
}

Future<List<String>> _verdicts(List<String> lignes, {bool muet = false}) async {
  final v = await verifierCopie(
    _GiacEnregistre(muet: muet),
    lignes.map(_ligne).toList(),
  );
  return v.map((e) => e.name).toList();
}

void main() {
  // Références : démarches résolues à la main ; la faute est connue.
  test('une démarche juste : chaque ligne cochée', () async {
    expect(await _verdicts(['2x+3=7', '2x=4', 'x=2']), [
      'depart',
      'juste',
      'juste',
    ]);
    expect(await _verdicts(['3x-5=x+1', '2x=6', 'x=3']), [
      'depart',
      'juste',
      'juste',
    ]);
    expect(await _verdicts(['x^{2}-5x+6=0', '(x-2)(x-3)=0']), [
      'depart',
      'juste',
    ]);
    expect(await _verdicts([r'\frac{x}{2}=3', 'x=6']), ['depart', 'juste']);
  });

  test('la faute est montrée là où elle est, pas après', () async {
    // 7 − 3 = 4, pas 10 ; la suite (x = 5) suit bien de la ligne fausse.
    expect(await _verdicts(['2x+3=7', '2x=10', 'x=5']), [
      'depart',
      'fausse',
      'juste',
    ]);
  });

  test('une solution oubliée est une faute', () async {
    expect(await _verdicts(['x^{2}=4', 'x=2']), ['depart', 'fausse']);
    expect(await _verdicts([r'\sin(x)=0', 'x=0']), ['depart', 'fausse']);
  });

  test('expressions : développer et réduire', () async {
    expect(await _verdicts(['2(x+1)+3', '2x+2+3', '2x+5']), [
      'depart',
      'juste',
      'juste',
    ]);
    expect(await _verdicts(['2(x+1)+3', '2x+1+3', '2x+4']), [
      'depart',
      'fausse',
      'juste',
    ]);
    expect(await _verdicts(['(x+1)^{2}', 'x^{2}+1']), ['depart', 'fausse']);
    expect(await _verdicts(['(x+1)^{2}', 'x^{2}+2x+1']), ['depart', 'juste']);
  });

  test('jamais « faux » sans preuve : Giac muet, ou sortes mêlées', () async {
    expect(await _verdicts(['2x+3=7', '2x=4'], muet: true), [
      'depart',
      'inconnue',
    ]);
    expect(await _verdicts(['2x+3=7', '2x+5']), ['depart', 'inconnue']);
  });
}
