import 'dart:ui';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Antsa : ce qui est lu s'écrit au propre, à la place de l'encre.
  test('au propre : même début, dans la largeur de l’écriture', () {
    const ecriture = Rect.fromLTWH(100, 200, 300, 60);
    for (final latex in [
      'C : x^{2}+y^{3}=0',
      'A(8;-1)',
      r'3 0 \times 8 =',
      r'\det\begin{pmatrix}8&-1\\8&4\end{pmatrix}=',
    ]) {
      final propre = ecrireALaPlace(latex, ecriture);
      expect(propre, isNotNull, reason: latex);
      expect(propre!.cadre.left, closeTo(100, 8), reason: latex);
      expect(propre.cadre.right, lessThanOrEqualTo(ecriture.right + 8));
    }
    expect(ecrireALaPlace(r'\overrightarrow{AB}', ecriture), isNull);
  });

  // Antsa : la matrice inverse s'imprimait toute petite (Pad 7).
  test('une matrice de Giac s’écrit à la main', () {
    const inverse =
        r'\left(\begin{array}{cc}'
        '\n'
        r'\frac{7}{15} & \frac{-8}{15} \\'
        '\n'
        r'\frac{1}{15} & \frac{1}{15}\end{array}\right)';
    final ligne = ecrireResultat('7', const Rect.fromLTWH(0, 0, 40, 40));
    final matrice = ecrireResultat(inverse, const Rect.fromLTWH(0, 0, 40, 40));
    expect(matrice, isNotNull);
    expect(matrice!.contours.length, greaterThan(10));
    expect(matrice.cadre.height, greaterThan(ligne!.cadre.height));
  });

  const ecriture = Rect.fromLTWH(100, 200, 300, 60);

  EcritureResultat? ecrit(BlocCalcul b) =>
      b.ecriture(approcheVoulue: false, virgule: false);

  test('une inéquation s’écrit à la main', () {
    for (final texte in ['x>2', '-2<x<2', r'x\leq -1', r'x\geq 1']) {
      expect(ecrireResultat(texte, ecriture), isNotNull, reason: texte);
    }
  });

  test('le signe de la racine laisse de la place au nombre', () {
    final seul = ecrireResultat('2', ecriture)!.cadre;
    final racine = ecrireResultat(r'\sqrt{2}', ecriture)!.cadre;
    // Serré, `√29` se lisait `(29` sur le Pad 7.
    expect(racine.width - seul.width, greaterThan(0.4 * seul.height));
  });

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
      r'\ln\left(5\right)',
      r'\sin(x)+\cos(x)',
      r'\tan(1)',
      r'\exp(x)',
      'abcdefghijklmnopqrstuvwxyz',
      'x=1',
      r'x=-\sqrt{2}\,\mathrm{ou}\,x=\sqrt{2}',
      r'x=2\,\mathrm{et}\,y=\mathrm{-1}',
      r'S=\emptyset',
      r'S=\mathbb{R}',
      r'x=n\cdot \pi,\,n \in \mathbb{Z}',
      r'\left(\begin{array}{cc}1&2\\3&4\end{array}\right)',
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
      // Une matrice sans fin : pas d'à-peu-près.
      r'\left(\begin{array}{cc}1&2\\3&4',
      'Ω',
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

    test('écrit après un =, ou sous une équation', () {
      expect(ecrit(bloc('2+3=', resultat: '5')), isNotNull);
      expect(ecrit(bloc('2+3', resultat: '5')), isNull);
      final equation = bloc('x^2=4', resultat: '2')
        ..type = TypeExpression.equation;
      expect(ecrit(equation)!.cadre.top, greaterThan(ecriture.bottom));
    });

    test('jamais sans résultat', () {
      expect(ecrit(bloc('2+3=')), isNull);
      expect(
        ecrit(bloc('2+3=', resultat: '5')..etat = EtatBloc.calcul),
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
      expect(ecrit(saisie), isNull);
    });

    test('un résultat corrigé est réécrit', () {
      final b = bloc('2+3=', resultat: '5');
      final avant = ecrit(b);
      b.resultat = '6';
      expect(identical(ecrit(b), avant), isFalse);
    });
  });

  test('une matrice s’écrit plus haut que la ligne, lisible', () {
    const ligne = Rect.fromLTWH(0, 0, 0, 36);
    final matrice = ecrireResultat(
      r'A=\begin{pmatrix}1&2\\3&4\end{pmatrix}',
      ligne,
    )!;
    expect(matrice.cadre.height, greaterThan(1.2 * 36));
  });
}
