// Enregistre les réponses du vrai Giac aux calculs des étapes, pour les tests
// (`test/fixtures/giac/etapes.json`). Giac compilé pour l'ordinateur :
//   LD_LIBRARY_PATH=<dossier de libfikajiana_giac.so> \
//     dart run tool/enregistrer_giac.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/etapes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';

class _Enregistreur implements Moteur {
  final reponses = <String, Map<String, String>>{};
  final _giac = MoteurGiac();

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async {
    final r = await _giac.calculer(entree, degres: degres);
    reponses[entree] = {
      'exact': r.exact,
      'latex': r.latex,
      'approche': r.approche,
      if (r.erreur != null) 'erreur': r.erreur!,
    };
    return r;
  }

  @override
  void interrompre() {}
}

const equations = [
  '2x+3=7',
  '3x-5=x+1',
  'x+4=0',
  r'\frac{x}{2}=3',
  'x^{2}-5x+6=0',
  '2x^{2}-3x-5=0',
  'x^{2}-2x+1=0',
  'x^{2}+x+1=0',
  'x^{2}=2',
  'x^{2}+3x=4x+12',
  'x^{3}=8',
  'ax+b=0',
  r'\sin(x)=0',
];

Future<void> main() async {
  final moteur = _Enregistreur();
  for (final latex in equations) {
    final a = analyserLatex(latex);
    final x = a.inconnues.singleOrNull;
    print('== $latex  (${a.type.name}, $x, ${a.membres})');
    if (a.membres == null || x == null) continue;
    final etapes = await etapesEquation(
      moteur,
      ecrit: latex,
      gauche: a.membres!.$1,
      droite: a.membres!.$2,
      x: x,
    );
    for (final e in etapes ?? const <Etape>[]) {
      print('   $e');
    }
    if (etapes == null) print('   (pas d’étapes)');
  }
  File('test/fixtures/giac/etapes.json').writeAsStringSync(
    '${const JsonEncoder.withIndent(' ').convert(moteur.reponses)}\n',
  );
  exit(0);
}
