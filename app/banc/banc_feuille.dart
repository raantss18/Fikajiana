// Un banc : il écrit dans le journal, rien d'autre.
// ignore_for_file: avoid_print

// Banc de la feuille : des problèmes en plusieurs étapes (matrices, suites,
// fonctions), ligne après ligne sur une même feuille, avec le vrai Giac, et
// le temps de chaque étape. Les lignes sont celles qu'une lecture juste
// donnerait ; l'écriture à la main se mesure à part (banc_lecture).
//
// Lancer sur un appareil : tool/banc/lancer.sh android-arm64
// banc/banc_feuille.dart. Les valeurs attendues viennent de SymPy
// (tool/banc/references_feuille.py) ; ce banc écrit ce que rend la feuille,
// la comparaison se fait sur l'ordinateur.

import 'dart:convert';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter/widgets.dart';

/// Rien n'est écrit à la main ici.
class _SansLecture extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async => '';
}

/// Chaque problème : ses lignes, de haut en bas.
const List<(String, List<String>)> problemes = [
  (
    'matrices 2×2',
    [
      r'A=\begin{pmatrix}2&1\\1&3\end{pmatrix}',
      r'B=\begin{pmatrix}1&-1\\0&2\end{pmatrix}',
      'AB=',
      'BA=',
      r'\det(A)=',
      'A^{-1}=',
      'AX=B',
      'A^{2}-5A=',
      r'\det(AB)=',
    ],
  ),
  (
    'matrices 3×3',
    [
      r'C=\begin{pmatrix}1&2&0\\0&1&3\\2&0&1\end{pmatrix}',
      r'\det(C)=',
      'C^{-1}=',
      'C^{2}=',
      r'D=\begin{pmatrix}1\\2\\3\end{pmatrix}',
      'CD=',
      'CX=D',
    ],
  ),
  (
    'suite arithmétique',
    [
      'u_{n}=2n+3',
      'u_{10}=',
      r'\sum_{n=0}^{10}u_{n}=',
      r'\lim_{n\to+\infty}\frac{u_{n}}{n}=',
    ],
  ),
  (
    'suite géométrique',
    [
      r'v_{n}=3\times2^{n}',
      'v_{5}=',
      r'\sum_{k=0}^{5}3\times2^{k}=',
      r'\lim_{n\to+\infty}\frac{2n+1}{n+3}=',
    ],
  ),
  ('suite récurrente', ['w_{0}=2', 'w_{n+1}=3w_{n}-4', 'w_{3}=']),
  (
    'fonction polynôme',
    [
      'f(x)=x^{3}-3x^{2}+2',
      "f'(x)=",
      "f'(x)=0",
      'f(2)=',
      'f(0)=',
      r'\int_{0}^{2}f(x)dx=',
      r'\lim_{x\to+\infty}f(x)=',
      'f(x)=0',
      'g(x)=f(x)+x',
      "g'(1)=",
    ],
  ),
  (
    'fonction exponentielle',
    [
      'h(x)=xe^{-x}',
      "h'(x)=",
      "h'(x)=0",
      'h(1)=',
      r'\lim_{x\to+\infty}h(x)=',
      r'\int_{0}^{1}h(x)dx=',
    ],
  ),
  (
    'fonction logarithme',
    [r'k(x)=\ln(x)-x', "k'(x)=", "k'(x)=0", 'k(1)=', r'\lim_{x\to0^{+}}k(x)='],
  ),
  (
    'feuille d’Antsa, 15 h 14',
    [
      r'y ^ { 1 } - 3 y = \cos \left( x \right)',
      "y'+y=0",
      "y''+y=0",
      "y''+4y=x",
      r"y''+y=\cos(x)",
      "y''-3y'+2y=e^{x}",
      "y'=2y",
      "y'(t)=t",
      r'\left\{ \begin{matrix} x = \cos t \\ y = t \sin ( t ) \end{matrix} \right.',
      r'\begin{cases}x=t+1\\y=t^{2}-1\end{cases}',
      'u_{0}=2',
      'u_{n+1}=3u_{n}-1',
      'u_{4}=',
      r'\text{résoudre}(x^{2}-4=0)',
    ],
  ),
  // Vague 1 (docs/recherche/couverture-calcul.md) : lois de probabilité.
  (
    'lois de probabilité',
    [
      r'X\sim B(10;0{,}3)',
      'P(X=3)=',
      r'P(X\le3)=',
      r'P(2\le X<5)=',
      'P(X>8)=',
      'E(X)=',
      'V(X)=',
      r'\sigma(X)=',
      r'P(X\le k)\ge0{,}95',
      r'Z\sim\mathcal{P}(3)',
      'P(Z=0)=',
      r'P(Z\ge2)=',
      r'P(Z\le k)\ge0{,}9',
      r'T\sim\mathcal{G}(0{,}2)',
      r'P(T\le3)=',
      'E(T)=',
      r'P(T\le k)\ge0{,}5',
      r'Y\sim\mathcal{N}(100;15^{2})',
      r'P(Y\le115)=',
      r'P(85\le Y\le115)=',
      'P(Y>130)=',
      r'P(Y\le t)=0{,}975',
      r'P(Y\ge t)=0{,}05',
      r'D\sim\mathcal{E}(0{,}5)',
      r'P(D\le2)=',
      'V(D)=',
      r'P(D\le t)=0{,}5',
      r'U\sim\mathcal{U}(0;10)',
      r'P(2\le U\le5)=',
      r'P(U\le t)=0{,}3',
    ],
  ),
  // Vague 2 : arithmétique et dénombrement.
  (
    'arithmétique',
    [
      r'\text{division}(17;5)',
      r'\text{division}(-17;5)',
      r'\text{quotient}(47;6)=',
      r'\text{reste}(47;6)=',
      r'\text{reste}(-17;5)=',
      r'\text{bezout}(12;18)',
      r'\text{bezout}(240;46)',
      r'17\equiv2[5]',
      r'17\equiv3[5]',
      r'2^{10}\equiv1\pmod{11}',
      'A_{5}^{2}=',
      r'\binom{10}{3}=',
      '6!=',
    ],
  ),
  // Vague 7 : supérieur (ADR 0059).
  (
    'supérieur',
    [
      r'\text{DL}(e^{x};0;4)=',
      r'\text{DL}(\ln(1+x);0;3)=',
      r'\text{laplace}(e^{2t})=',
      r'\text{invlaplace}(\frac{1}{s-2})=',
      r'\text{rang}\begin{pmatrix}1&2&3\\4&5&6\\7&8&9\end{pmatrix}=',
      r'\text{tr}\begin{pmatrix}1&2\\3&4\end{pmatrix}=',
      r'\text{noyau}\begin{pmatrix}1&2&3\\4&5&6\\7&8&9\end{pmatrix}=',
      r'\text{valeurspropres}\begin{pmatrix}2&1\\1&2\end{pmatrix}=',
      r'\text{polycar}\begin{pmatrix}2&1\\1&2\end{pmatrix}=',
      r'\text{diagonaliser}\begin{pmatrix}2&1\\1&2\end{pmatrix}',
    ],
  ),
  // Vague 6 : nombres complexes (ADR 0058).
  (
    'complexes',
    [
      r'\text{formeexp}(1+i)=',
      r'\text{formeexp}(-1-i\sqrt{3})=',
      r'\text{formetrigo}(\sqrt{3}-i)=',
      r'\text{formeexp}(\frac{1+i\sqrt{3}}{1-i})=',
      r'\text{racines}(3;8i)',
      r'\text{racines}(4;-16)',
      'z^{2}-2z+5=0',
      'z^{2}+4=0',
      '(1+i)z=3+i',
      'z^{3}=-8',
    ],
  ),
  // Vague 3 : statistiques à deux variables.
  (
    'statistiques à deux variables',
    [
      r'\text{ajustement}([1;2;3;4;5];[2;4;5;4;5])',
      r'\text{ajustement}([1;2;3;4];[2{,}7;7{,}4;20{,}1;54{,}6];exp)',
      r'\text{ajustement}([1;2;3;4];[0;0{,}7;1{,}1;1{,}4];ln)',
      r'\text{ajustement}([1;2;3;4];[3;12;27;48];puissance)',
      r'\text{ajustement}([1;2;3;4];[1;4;9;17];2)',
      r'\text{correlation}([1;2;3;4;5];[2;4;5;4;5])=',
      r'\text{covariance}([1;2;3];[2;4;7])=',
      r'\text{quartiles}(3;1;7;5;9;2)',
      r'\text{quartiles}(12;5;8;3;9;14;7)',
    ],
  ),
  // Vague 4 : tableau de valeurs.
  (
    'tableau de valeurs',
    [
      'f(x)=x^{2}-1',
      r'\text{tableau}(f;0;3;1)',
      r'\text{tableau}(\frac{1}{x};1;4)=',
      r'\text{tableau}(x^{3};-1;1;0{,}5)',
    ],
  ),
  // Vague 5 : inéquations (bornes des solutions).
  (
    'inéquations',
    [
      'x+1<3',
      r'x^{2}\ge 4',
      '2x-3>x+1',
      '|x-1|<2',
      r'\text{résoudre}\left(x^{2}-5x+6\le 0\right)',
      r'\ln\left(x\right)>1',
    ],
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final moteur = MoteurGiac();
  var total = Duration.zero;
  for (final (nom, lignes) in problemes) {
    // Une feuille par problème : les noms (f, A…) ne se mélangent pas.
    final calcul = CalculFeuille(
      encre: Encre(),
      lecteur: _SansLecture(),
      moteur: moteur,
      pause: Duration.zero,
    );
    var y = 0.0;
    for (final latex in lignes) {
      y += 60;
      final chrono = Stopwatch()..start();
      await calcul.saisir(latex, Offset(0, y));
      chrono.stop();
      total += chrono.elapsed;
      final bloc = calcul.blocs.lastWhere((b) => b.cadre.top == y);
      final mesure = {
        'p': nom,
        'l': latex,
        'ms': chrono.elapsedMilliseconds,
        'etat': bloc.etat.name,
        'type': bloc.type?.name,
        'r': bloc.resultat,
        'a': bloc.approche,
        'v': bloc.verite,
        't': bloc.texte(approcheVoulue: false, virgule: true),
        'courbe': bloc.courbeSeule,
      };
      print('BANC ${jsonEncode(mesure)}');
    }
    calcul.dispose();
  }
  print('BANC FIN ${total.inMilliseconds} ms');
}
