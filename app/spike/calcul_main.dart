// Essai sur l'appareil : LaTeX → Giac → résultat, puis arrêt d'un calcul long.
// ignore_for_file: avoid_print
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';

const _essais = [
  '2+3=',
  r'\frac{1}{3}+\frac{1}{6}=',
  r'\sqrt{2}',
  r'\sqrt[3]{8}',
  '2^{10}',
  '1 0 + 2 5 =',
  '3,5+1',
  r'\sin(\pi)',
  r'\frac{d}{1}',
  'x^2=2',
  '2x+1=5',
  '2+2=5',
  '2+2=4',
  r'\int x\,dx',
  r'\int_{0}^{1}x^{2}\,dx',
  r'\int_{1}^{e}\frac{1}{x}\,dx',
  r'\int_{0}^{+\infty}e^{-t}\,dt',
  r'\lim_{x\to0}\frac{\sin(x)}{x}',
  r'\lim_{n\to+\infty}\frac{1}{n}',
  r'\sum_{k=1}^{10}k',
  r'\sum_{n=1}^{+\infty}\frac{1}{n^{2}}',
  r'\prod_{k=1}^{5}k',
  r'\begin{pmatrix}1&2\\3&4\end{pmatrix}',
  r'\begin{cases}x+y=1\\x-y=3\end{cases}',
  r'\left\{ \begin{matrix} 2 x + y = 5 \\ x - 3 y = 2 \end{matrix} \right.',
  'f(x)=x^{2}',
  'f(3)=',
  '1/0',
  r'\frac{1}{0}',
  '0/0',
];

Future<void> main() async {
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Essai du calcul'))),
    ),
  );
  final moteur = MoteurGiac(delai: const Duration(seconds: 5));
  for (final latex in _essais) {
    try {
      final analyse = analyserLatex(latex);
      final chrono = Stopwatch()..start();
      final r = await moteur.calculer(analyse.giac);
      print(
        'ESSAI ${chrono.elapsedMilliseconds}ms ${analyse.type.name} | '
        '$latex | '
        '${analyse.giac} | ${r.exact} | ${r.latex} | ${r.approche}',
      );
    } on ErreurLatex catch (e) {
      print('ESSAI refus | $latex | $e');
    }
  }
  for (final long in [
    'factorial(20000000)',
    'ifactor(2^1009-1)',
    'expand((x+y+z+t)^900)',
  ]) {
    final chrono = Stopwatch()..start();
    final r = await moteur.calculer(long);
    final texte = r.exact.length > 40
        ? '${r.exact.substring(0, 40)}…'
        : r.exact;
    print(
      'LONG ${chrono.elapsedMilliseconds}ms | $long | arrete=${r.arrete} | '
      '$texte | ${r.erreur}',
    );
  }
  final r = await moteur.calculer('1+1');
  print('APRES ${r.exact}');
  print('ESSAI FIN');
}
