// Le banc tourne sur un appareil et écrit dans le journal.
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_appris.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:flutter/widgets.dart';

import 'fixtures_lecture.dart';

/// Combien de fois chaque ligne se lit : on garde la médiane.
const _tours = 7;

/// Budget de l'ADR 0038 : une ligne simple en moins de 50 ms.
const _budgetMs = 50.0;

double _mediane(List<double> v) => (v..sort())[v.length ~/ 2];

double _ms(Stopwatch s) => s.elapsedMicroseconds / 1000;

/// Le temps de lecture au tracé de chaque écriture réelle des tests, avant
/// (gabarits à chaque lecture) et après (signes classés dès qu'ils sont
/// finis, ADR 0039). Usage : `tool/banc/lancer.sh android-arm64
/// banc/banc_lecture.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var simples = 0;
  var dansLeBudget = 0;
  final apres = <double>[];
  for (final (nom, json) in fixturesLecture) {
    final traits = [
      for (final t in jsonDecode(json) as List<dynamic>)
        Trait.depuisDocument(t as Map<String, dynamic>),
    ];
    final avant = <double>[];
    final signes = <double>[];
    final relue = <double>[];
    String? lu;
    for (var i = 0; i < _tours; i++) {
      final chrono = Stopwatch()..start();
      lu = avecClasseur(const ClasseurGabarits(), () => lireAuTrace(traits));
      avant.add(_ms(chrono));
      // Pendant l'écriture : chaque signe, dès qu'il est fini.
      final classeur = ClasseurAppris();
      chrono
        ..reset()
        ..start();
      for (final ligne in grouperTraits(traits)) {
        final hauteur = cadreDuGroupe(ligne).height;
        for (final s in signesDeLaLigne(ligne)) {
          await classeur.preparer(s, hauteurLigne: hauteur);
        }
      }
      signes.add(_ms(chrono));
      // À la pause : la ligne, ses signes déjà connus.
      chrono
        ..reset()
        ..start();
      final encore = avecClasseur(classeur, () => lireAuTrace(traits));
      relue.add(_ms(chrono));
      if (encore != lu) print('BANC ECART $nom : $lu puis $encore');
    }
    final (a, s, r) = (_mediane(avant), _mediane(signes), _mediane(relue));
    if (lu != null) {
      simples++;
      apres.add(r);
      if (r < _budgetMs) dansLeBudget++;
    }
    print(
      'BANC LECTURE $nom : avant ${a.toStringAsFixed(1)} ms, '
      'après ${r.toStringAsFixed(1)} ms '
      '(signes pendant l’écriture ${s.toStringAsFixed(1)} ms) '
      '→ ${lu ?? 'au modèle'}',
    );
  }
  final pire = apres.isEmpty ? 0 : apres.reduce((x, y) => x > y ? x : y);
  print(
    'BANC LECTURE pire ligne simple : ${pire.toStringAsFixed(1)} ms '
    '(budget ${_budgetMs.round()} ms)',
  );
  print('BANC FIN : $dansLeBudget/$simples');
}
