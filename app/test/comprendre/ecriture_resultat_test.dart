import 'dart:ui';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ecriture = Rect.fromLTWH(100, 200, 300, 60);

  group('sait écrire', () {
    for (final latex in [
      '0',
      '1234567890',
      '5',
      '-12',
      '4.5',
      r'\frac{1}{2}',
      r'\sqrt{2}',
      r'\frac{1}{6}\cdot \pi ^{2}',
      r'\frac{x^{2}}{2}',
      r'\{-\sqrt{2},\sqrt{2}\}',
      r'+\infty',
      'x+y',
      r'8^{\frac{1}{3}}',
      r'\left(x+1\right)',
    ]) {
      test(latex, () {
        final ecrit = ecrireResultat(latex, ecriture);
        expect(ecrit, isNotNull);
        expect(ecrit!.contours, isNotEmpty);
      });
    }
  });

  group('laisse à la carte ce qu’il ne sait pas écrire', () {
    for (final latex in [
      r'\mbox{false}',
      r'\left(\begin{array}{cc}1&2\\3&4\end{array}\right)',
      r'\sin(x)',
      'Q',
      r'\frac{1}{2',
      '',
    ]) {
      test('« $latex »', () {
        expect(ecrireResultat(latex, ecriture), isNull);
      });
    }
  });

  test('le résultat se place à droite de l’écriture, à sa hauteur', () {
    final cadre = ecrireResultat('5', ecriture)!.cadre;
    expect(cadre.left, greaterThan(ecriture.right));
    expect(cadre.top, greaterThan(ecriture.top - 30));
    expect(cadre.bottom, lessThan(ecriture.bottom + 30));
  });

  test('sa taille suit celle de l’écriture', () {
    final petit = ecrireResultat('5', const Rect.fromLTWH(0, 0, 80, 30))!.cadre;
    final grand = ecrireResultat('5', const Rect.fromLTWH(0, 0, 80, 90))!.cadre;
    expect(grand.height, greaterThan(petit.height * 2));
  });

  test('une fraction est plus haute qu’un chiffre', () {
    final chiffre = ecrireResultat('5', const Rect.fromLTWH(0, 0, 80, 10))!;
    final fraction = ecrireResultat(
      r'\frac{1}{2}',
      const Rect.fromLTWH(0, 0, 80, 10),
    )!;
    expect(fraction.contours.length, 3);
    expect(chiffre.contours.length, 1);
  });

  group('sur un bloc', () {
    BlocCalcul bloc(String latex, {String? resultat}) =>
        BlocCalcul(cle: '1', cadre: ecriture, latex: latex, etat: EtatBloc.fait)
          ..resultat = resultat;

    test('écrit seulement après un =', () {
      expect(bloc('2+3=', resultat: '5').ecriture, isNotNull);
      expect(bloc('2+3', resultat: '5').ecriture, isNull);
      expect(bloc('x^2=2', resultat: '5').ecriture, isNull);
    });

    test('jamais sans résultat', () {
      expect(bloc('2+3=').ecriture, isNull);
      expect(
        (bloc('2+3=', resultat: '5')..etat = EtatBloc.calcul).ecriture,
        isNull,
      );
    });

    test('une saisie au clavier reste sur la carte', () {
      final saisie = BlocCalcul(
        cle: 'saisie-1',
        cadre: ecriture,
        latex: '2+3=',
        etat: EtatBloc.fait,
      )..resultat = '5';
      expect(saisie.ecriture, isNull);
    });

    test('un résultat corrigé est réécrit', () {
      final b = bloc('2+3=', resultat: '5');
      final avant = b.ecriture;
      b.resultat = '6';
      expect(identical(b.ecriture, avant), isFalse);
    });
  });
}
