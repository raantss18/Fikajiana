import 'dart:convert';
import 'dart:io';

import 'dart:ui';

import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/comprendre/etapes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les réponses du vrai Giac (commit de l'app), enregistrées par
/// `tool/enregistrer_giac.dart` : un calcul inconnu fait échouer le test.
class _GiacEnregistre implements Moteur {
  final Map<String, dynamic> _reponses = jsonDecode(
    File('test/fixtures/giac/etapes.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async {
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

Future<List<String>?> _etapes(String latex) async {
  final a = analyserLatex(latex);
  final etapes = await etapesEquation(
    _GiacEnregistre(),
    ecrit: latex,
    gauche: a.membres!.$1,
    droite: a.membres!.$2,
    x: a.inconnues.single,
  );
  return etapes?.map((e) => e.toString()).toList();
}

void main() {
  // Valeurs de référence : résolues à la main, et égales à ce que rend
  // `solve` de Giac (banc « équations »).
  test('premier degré : tout à gauche, isoler, diviser', () async {
    expect(await _etapes('2x+3=7'), [
      'depart : 2x+3=7',
      'toutAGauche : 2x-4=0',
      'isoler : 2x=4',
      r'diviser : x=\frac{4}{2}',
      'conclusion : x=2',
    ]);
    expect((await _etapes('3x-5=x+1'))!.last, 'conclusion : x=3');
    expect((await _etapes(r'\frac{x}{2}=3'))!.last, 'conclusion : x=6');
  });

  test('coefficient 1 : pas de division, pas de ligne répétée', () async {
    expect(await _etapes('x+4=0'), [
      'depart : x+4=0',
      'isoler : x=-4',
      'conclusion : x=-4',
    ]);
  });

  test('second degré, Δ > 0 : a, b, c, discriminant, deux solutions', () async {
    expect(await _etapes('2x^{2}-3x-5=0'), [
      'depart : 2x^{2}-3x-5=0',
      r'coefficients : a=2,\ b=-3,\ c=-5',
      r'discriminant : \Delta=b^{2}-4ac=\left(-3\right)^{2}-4\times 2\times \left(-5\right)=49',
      r'deuxSolutions : \Delta>0',
      r'premiere : x_{1}=\frac{-b-\sqrt{\Delta}}{2a}=-1',
      r'seconde : x_{2}=\frac{-b+\sqrt{\Delta}}{2a}=\frac{5}{2}',
      r'conclusion : x=-1\ \text{ou}\ x=\frac{5}{2}',
    ]);
    expect(
      (await _etapes('x^{2}=2'))!.last,
      r'conclusion : x=-\sqrt{2}\ \text{ou}\ x=\sqrt{2}',
    );
  });

  test('second degré à réduire d’abord', () async {
    final e = (await _etapes('x^{2}+3x=4x+12'))!;
    expect(e[1], 'toutAGauche : x^{2}-x-12=0');
    expect(e.last, r'conclusion : x=-3\ \text{ou}\ x=4');
  });

  test('Δ = 0 : une solution ; Δ < 0 : aucune solution réelle', () async {
    final double_ = (await _etapes('x^{2}-2x+1=0'))!;
    expect(
      double_[double_.length - 2],
      r'solutionDouble : x_{0}=\frac{-b}{2a}=1',
    );
    expect(double_.last, 'conclusion : x=1');
    final aucune = (await _etapes('x^{2}+x+1=0'))!;
    expect(aucune.last, r'aucuneSolution : \Delta<0');
    expect(aucune[aucune.length - 2], contains('=-3'));
  });

  test('chaque ligne s’écrit à la main, comme au tableau', () async {
    for (final equation in [
      '2x+3=7',
      r'\frac{x}{2}=3',
      '2x^{2}-3x-5=0',
      'x^{2}=2',
      'x^{2}-2x+1=0',
      'x^{2}+x+1=0',
    ]) {
      final a = analyserLatex(equation);
      final etapes = await etapesEquation(
        _GiacEnregistre(),
        ecrit: equation,
        gauche: a.membres!.$1,
        droite: a.membres!.$2,
        x: a.inconnues.single,
      );
      for (final e in etapes!) {
        expect(
          ecrireResultat(e.latex, const Rect.fromLTWH(0, 0, 40, 40)),
          isNotNull,
          reason: e.toString(),
        );
      }
    }
  });

  test('pas d’étapes plutôt que des étapes fausses', () async {
    expect(await _etapes('x^{3}=8'), isNull);
    expect(await _etapes('ax+b=0'), isNull);
    expect(await _etapes(r'\sin(x)=0'), isNull);
  });
}
