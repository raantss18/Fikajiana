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

  test('en anglais, « or » entre les deux solutions', () async {
    final a = analyserLatex('2x^{2}-3x-5=0');
    final etapes = await etapesEquation(
      _GiacEnregistre(),
      ecrit: '2x^{2}-3x-5=0',
      gauche: a.membres!.$1,
      droite: a.membres!.$2,
      x: 'x',
      ou: 'or',
    );
    expect(etapes!.last.latex, r'x=-1\ \text{or}\ x=\frac{5}{2}');
  });

  test('pas d’étapes plutôt que des étapes fausses', () async {
    expect(await _etapes('x^{3}=8'), isNull);
    expect(await _etapes('ax+b=0'), isNull);
    expect(await _etapes(r'\sin(x)=0'), isNull);
  });

  group('inéquations', () {
    Future<List<String>?> inequation(String latex) async {
      final a = analyserLatex(latex);
      final i = lireInequation(a.giac, a.inconnues.single);
      if (i == null) return null;
      final etapes = await etapesInequation(
        _GiacEnregistre(),
        ecrit: latex,
        gauche: i.gauche,
        sens: i.sens,
        droite: i.droite,
        x: i.x,
      );
      return etapes?.map((e) => e.toString()).toList();
    }

    // Valeurs de référence : chaque ensemble est celui que rend `solve` du
    // vrai Giac (`list[x<2,x>3]`…), vérifié le 2026-11-15.
    test('premier degré : isoler, diviser, l’intervalle', () async {
      expect(await inequation('2x+3<7'), [
        'departInequation : 2x+3<7',
        'toutAGauche : 2x-4<0',
        'isoler : 2x<4',
        r'diviser : x<\frac{4}{2}',
        r'conclusion : x<2,\ S=\left]-\infty;2\right[',
      ]);
      expect(
        (await inequation(r'x+4\leq 0'))!.last,
        r'conclusion : x\leq -4,\ S=\left]-\infty;-4\right]',
      );
    });

    test('diviser par un négatif change le sens', () async {
      final e = (await inequation(r'-3x+1\geq 4'))!;
      expect(e[3], r'diviserNegatif : x\leq \frac{3}{-3}');
      expect(e.last, r'conclusion : x\leq -1,\ S=\left]-\infty;-1\right]');
      expect(
        (await inequation('5-2x>x+11'))!.last,
        r'conclusion : x<-2,\ S=\left]-\infty;-2\right[',
      );
    });

    test('second degré : signe de a hors des racines', () async {
      expect(await inequation('x^{2}-5x+6>0'), [
        'departInequation : x^{2}-5x+6>0',
        r'coefficients : a=1,\ b=-5,\ c=6',
        r'discriminant : \Delta=b^{2}-4ac=\left(-5\right)^{2}-4\times 1\times 6=1',
        r'racines : x_{1}=\frac{-b-\sqrt{\Delta}}{2a}=2,\ x_{2}=\frac{-b+\sqrt{\Delta}}{2a}=3',
        'signeTrinome : a=1>0',
        r'conclusion : S=\left]-\infty;2\right[\cup \left]3;+\infty\right[',
      ]);
      final conclusions = {
        r'x^{2}-5x+6\leq 0': r'S=\left[2;3\right]',
        r'x^{2}\geq 4': r'S=\left]-\infty;-2\right]\cup \left[2;+\infty\right[',
        // a < 0 : les racines s'inversent, l'intervalle reste dans l'ordre.
        '-x^{2}+x+2>0': r'S=\left]-1;2\right[',
      };
      for (final MapEntry(:key, :value) in conclusions.entries) {
        expect(
          (await inequation(key))!.last,
          'conclusion : $value',
          reason: key,
        );
      }
    });

    test('Δ = 0 et Δ < 0', () async {
      final conclusions = {
        'x^{2}-2x+1>0': r'S=\left]-\infty;1\right[\cup \left]1;+\infty\right[',
        r'x^{2}-2x+1\leq 0': r'S=\left\{1\right\}',
        'x^{2}+x+1<0': r'S=\emptyset',
        r'x^{2}+x+1\geq 0': r'S=\mathbb{R}',
      };
      for (final MapEntry(:key, :value) in conclusions.entries) {
        expect(
          (await inequation(key))!.last,
          'conclusion : $value',
          reason: key,
        );
      }
    });

    test('chaque ligne s’écrit à la main', () async {
      for (final latex in [
        '2x+3<7',
        r'-3x+1\geq 4',
        'x^{2}-5x+6>0',
        r'x^{2}-2x+1\leq 0',
        'x^{2}+x+1<0',
        r'x^{2}+x+1\geq 0',
        '-x^{2}+x+2>0',
      ]) {
        for (final e in (await inequation(latex))!) {
          expect(
            ecrireResultat(
              e.split(' : ').skip(1).join(' : '),
              const Rect.fromLTWH(0, 0, 40, 40),
            ),
            isNotNull,
            reason: e,
          );
        }
      }
    });

    test('rien pour le degré 3 ni pour un encadrement', () async {
      expect(await inequation('x^{3}>8'), isNull);
      expect(lireInequation('solve(1<x<3,x)', 'x'), isNull);
      expect(lireInequation('solve(x^2=4,x)', 'x'), isNull);
      expect(lireInequation('solve(x<=2,x)', 'x')?.sens, Sens.inferieurOuEgal);
    });
  });
}
