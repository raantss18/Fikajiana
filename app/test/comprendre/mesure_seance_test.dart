// Mesure de la lecture au tracé sur une séance réelle (format
// `collecte/FORMAT.md`), hors Git : lancée seulement avec
// `--dart-define=SEANCE=/chemin/vers/seance.json`.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:flutter_test/flutter_test.dart';

const _seance = String.fromEnvironment('SEANCE');

List<Trait> _traitsSeance(List<dynamic> traits) => [
  for (final t in traits)
    Trait.depuisDocument({
      'points': [
        for (final p in t as List<dynamic>)
          [(p as List<dynamic>)[0], p[1], p[3]],
      ],
    }),
];

void main() {
  test('mesure : séance réelle, signe par signe', () {
    final json =
        jsonDecode(File(_seance).readAsStringSync()) as Map<String, dynamic>;
    var justes = 0;
    var familles = 0;
    var doutes = 0;
    var faux = 0;
    final lignes = <String>[];
    for (final e
        in (json['echantillons'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      if (e['type'] != 'signe' || e['rejete'] == true) continue;
      final attendu = e['attendu'] as String;
      final traits = _traitsSeance(e['traits'] as List<dynamic>);
      final lu = reconnaitreSigne(dessinDe(traits));
      final premiers = classerSignesDebug(dessinDe(traits))
          .take(3)
          .map((c) => '${c.$1}:${c.$2.toStringAsFixed(2)}');
      String verdict;
      if (lu == null) {
        doutes++;
        verdict = 'doute';
      } else if (lu.length == 1 && lu.containsKey(attendu)) {
        justes++;
        verdict = 'juste';
      } else if (lu.containsKey(attendu)) {
        familles++;
        verdict = 'famille ${lu.keys.join('/')}';
      } else {
        faux++;
        verdict = 'FAUX ${lu.keys.join('/')}';
      }
      lignes.add(
        'SIGNE $attendu (${traits.length} traits) : $verdict  '
        '[${premiers.join(' ')}]',
      );
    }
    lignes
      ..sort()
      ..forEach(print);
    print(
      'SEANCE justes $justes, familles $familles, doutes $doutes, '
      'faux $faux',
    );
  }, skip: _seance.isEmpty ? 'sans --dart-define=SEANCE' : null);

  test('mesure : fixtures lues au tracé', () {
    for (final dossier in ['pad7', 'telephone']) {
      final fichiers = Directory('test/fixtures/$dossier').listSync().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in fichiers) {
        final traits = [
          for (final t
              in jsonDecode(File(f.path).readAsStringSync()) as List<dynamic>)
            Trait.depuisDocument(t as Map<String, dynamic>),
        ];
        final nom = f.uri.pathSegments.last;
        print('LIGNE $dossier/$nom : ${lireAuTrace(traits) ?? 'au modèle'}');
      }
    }
  }, skip: _seance.isEmpty ? 'sans --dart-define=SEANCE' : null);
}
