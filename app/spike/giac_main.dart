// Spike T2 : mesure l'appel FFI à Giac sur l'appareil (docs/recherche/spike-giac.md).
// ignore_for_file: avoid_print
import 'package:fikajiana/moteur/giac.dart';
import 'package:flutter/material.dart';

const _essais = [
  'diff(sin(x)^2,x)',
  'latex(diff(sin(x)^2,x))',
  'integrate(1/(x^2+1),x)',
  'limit(sin(x)/x,x,0)',
  'solve(x^2-2=0,x)',
  'factor(x^4-1)',
  'det([[1,2],[3,4]])',
  'sum(1/k^2,k,1,inf)',
  '2^200',
  '1/3+1/6',
  'evalf(pi,30)',
  '1/0',
  '2+',
];

Future<void> main() async {
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Spike Giac'))),
    ),
  );
  for (final entree in _essais) {
    final chrono = Stopwatch()..start();
    final sortie = await evaluerGiac(entree);
    print('SPIKE ${chrono.elapsedMilliseconds} ms | $entree | $sortie');
  }
  print('SPIKE FIN');
}
