// Enregistre les réponses du vrai Giac aux calculs des étapes, pour les tests
// (`test/fixtures/giac/etapes.json`). Giac compilé pour l'ordinateur :
//   LD_LIBRARY_PATH=<dossier de libfikajiana_giac.so> \
//     dart run tool/enregistrer_giac.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/copie.dart';
import 'package:fikajiana/comprendre/etapes.dart';
import 'package:fikajiana/comprendre/etapes_derivee.dart';
import 'package:fikajiana/comprendre/etapes_systeme.dart';
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

const inequations = [
  '2x+3<7',
  r'-3x+1\geq 4',
  r'x+4\leq 0',
  '5-2x>x+11',
  'x^{2}-5x+6>0',
  r'x^{2}-5x+6\leq 0',
  r'x^{2}\geq 4',
  '-x^{2}+x+2>0',
  'x^{2}-2x+1>0',
  r'x^{2}-2x+1\leq 0',
  'x^{2}+x+1<0',
  r'x^{2}+x+1\geq 0',
  'x^{3}>8',
];

/// Des dérivées écrites `\frac{d}{dx}(…)` : une par forme.
const derivees = [
  'x^{3}',
  r'\sin(x)',
  '3x^{2}-5x+2',
  r'5\sin(x)',
  '-x^{2}',
  r'x^{2}\sin(x)',
  'xe^{x}',
  r'\frac{x+1}{x-1}',
  r'\frac{e^{x}}{x}',
  r'\frac{1}{x^{2}+1}',
  '(x^{2}+1)^{3}',
  r'\sqrt{x^{2}+1}',
  r'\sin(2x+1)',
  r'\cos(x^{2})',
  'e^{-x^{2}}',
  r'\ln(x^{2}+1)',
  r'\cos(x)^{2}',
  r'\tan(x^{2})',
];

/// Des systèmes : substitution, combinaison, une ligne à une inconnue,
/// et deux sans étapes (déterminant nul, non linéaire).
const systemes = [
  ['2x+y=5', 'x-y=1'],
  ['3x+2y=12', '5x-3y=1'],
  ['2x=6', 'x+3y=9'],
  ['4x+6y=10', '6x-4y=2'],
  ['2x+3y=7', '2x-y=-1'],
  [r'\frac{x}{2}+y=3', 'x-y=0'],
  ['x+y=3', '2x+2y=6'],
  ['x^{2}+y=1', 'x-y=0'],
];

/// Des démarches d'élève : justes, ou avec une faute à une ligne connue.
const copies = [
  ['2x+3=7', '2x=4', 'x=2'],
  ['2x+3=7', '2x=10', 'x=5'],
  ['3x-5=x+1', '2x=6', 'x=3'],
  ['x^{2}-5x+6=0', '(x-2)(x-3)=0'],
  ['x^{2}=4', 'x=2'],
  ['2(x+1)+3', '2x+2+3', '2x+5'],
  ['2(x+1)+3', '2x+1+3', '2x+4'],
  ['(x+1)^{2}', 'x^{2}+2x+1'],
  ['(x+1)^{2}', 'x^{2}+1'],
  [r'\frac{x}{2}=3', 'x=6'],
  [r'\sin(x)=0', 'x=0'],
];

LigneCopie ligneCopie(String latex) {
  final a = analyserLatex(latex);
  final x = a.inconnues.singleOrNull;
  return a.membres != null && x != null
      ? LigneCopie.equation(latex, a.membres!.$1, a.membres!.$2, x)
      : LigneCopie(latex, a.giac);
}

Future<void> main() async {
  final moteur = _Enregistreur();
  final copie = _Enregistreur();
  for (final lignes in copies) {
    final v = await verifierCopie(copie, lignes.map(ligneCopie).toList());
    print('$lignes -> ${v.map((e) => e.name).toList()}');
  }
  File('test/fixtures/giac/copie.json').writeAsStringSync(
    '${const JsonEncoder.withIndent(' ').convert(copie.reponses)}\n',
  );
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
  for (final latex in inequations) {
    final a = analyserLatex(latex);
    final i = lireInequation(a.giac, a.inconnues.single);
    print('== $latex  ($i)');
    if (i == null) continue;
    final etapes = await etapesInequation(
      moteur,
      ecrit: latex,
      gauche: i.gauche,
      sens: i.sens,
      droite: i.droite,
      x: i.x,
    );
    for (final e in etapes ?? const <Etape>[]) {
      print('   $e');
    }
    if (etapes == null) print('   (pas d’étapes)');
  }
  for (final latex in derivees) {
    final a = analyserLatex('\\frac{d}{dx}\\left($latex\\right)=');
    final d = lireDerivee(a.giac);
    print('== $latex  (${a.giac})');
    if (d == null) continue;
    final etapes = await etapesDerivee(moteur, corps: d.corps, x: d.x);
    for (final e in etapes ?? const <Etape>[]) {
      print('   $e');
    }
    if (etapes == null) print('   (pas d’étapes)');
  }
  for (final [l1, l2] in systemes) {
    final latex = '\\begin{cases}$l1\\\\$l2\\end{cases}';
    final s = lireSysteme(analyserLatex(latex).giac);
    print('== $l1 ; $l2  ($s)');
    if (s == null) continue;
    final etapes = await etapesSysteme(
      moteur,
      ecrit: latex,
      equations: s.equations,
      x: s.x,
      y: s.y,
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
