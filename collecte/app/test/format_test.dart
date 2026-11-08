import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:collecte/catalogue.dart';
import 'package:collecte/seance.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';

import 'verifier_format.dart';

void main() {
  final reference = jsonDecode(
    File('test/reference_seance.json').readAsStringSync(),
  ) as Map<String, Object?>;

  test('la référence respecte collecte/FORMAT.md', () {
    expect(erreursFormat(reference), isEmpty);
  });

  test('une séance s’écrit exactement comme la référence', () {
    final s =
        Seance(
            nom: 'essai.json',
            mode: 'signes',
            auteur: 'Antsa',
            modele: '2410CRP4CG',
            largeurDp: 1280,
            hauteurDp: 800,
            densite: 2.75,
            outil: 'stylet',
            debut: '2026-11-08T09:30:00+03:00',
            demandes: const [
              Demande.signe('4', '4'),
              Demande.expression(r'\frac{1}{x+2}'),
            ],
          )
          ..ajouter(
            id: '00000000000000000000000000000001',
            traits: [
              [
                (x: 100.5, y: 200.249, t: 0, p: 0.5),
                (x: 110, y: 220, t: 16.4, p: 0.6251),
              ],
              [(x: 130, y: 190, t: 300, p: 1)],
            ],
            cadre: const Rect.fromLTWH(16, 180, 1248, 400),
            rejete: false,
          )
          ..ajouter(
            id: '00000000000000000000000000000002',
            traits: [
              [(x: 50, y: 60, t: 0, p: 1 / 3)],
            ],
            cadre: const Rect.fromLTWH(16, 180, 1248, 400),
            rejete: true,
          );
    // Passer par le texte : c'est le fichier écrit qui compte.
    final ecrit = jsonDecode(jsonEncode(s.versFichier()));
    expect(ecrit, reference);
    expect(s.position, 1, reason: 'un raté redemande le même');
  });

  test('l’état garde la séance et ce qui reste', () {
    final s = Seance.nouvelle(
      mode: 'signes',
      auteur: 'Antsa',
      modele: 'Xiaomi Pad 7',
      ecran: const Size(1280.4, 800),
      densite: 2.75,
      outil: 'doigt',
      maintenant: DateTime(2026, 11, 8, 9, 30, 5),
      demandes: const [Demande.signe('a', 'a'), Demande.signe('b', 'b')],
    );
    expect(s.nom, 'fikajiana-ecriture-Xiaomi-Pad-7-20261108-093005.json');
    expect(s.largeurDp, 1280);
    final relu = Seance.etat(
      jsonDecode(jsonEncode(s.versEtat())) as Map<String, Object?>,
    );
    expect(jsonEncode(relu.versEtat()), jsonEncode(s.versEtat()));
  });

  test('la date porte son décalage horaire', () {
    expect(
      isoLocal(DateTime(2026, 11, 8, 9, 30)),
      matches(RegExp(r'^2026-11-08T09:30:00[+-]\d\d:\d\d$')),
    );
    expect(nouvelId(), matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  group('catalogue', () {
    final classes = File('assets/classes.txt').readAsStringSync();
    final expressions = File('assets/expressions.txt').readAsStringSync();

    test('les assets sont les fichiers de collecte/, pas des copies', () {
      expect(classes, File('../classes.txt').readAsStringSync());
      expect(expressions, File('../expressions.txt').readAsStringSync());
    });

    test('classes.txt : ids uniques, trois colonnes', () {
      final signes = Catalogue.lireClasses(classes);
      expect(signes.length, greaterThan(100));
      expect(signes.map((s) => s.id).toSet().length, signes.length);
      expect(signes.first.precision, 'chiffre');
      final noms = {for (final s in signes) s.id: s.precision};
      expect(noms['par_d'], 'parenthèse fermante');
      expect(noms['x'], 'lettre minuscule');
      expect(noms['X'], 'lettre majuscule');
      expect(noms.values.where((n) => n.contains('_')), isEmpty);
    });

    test('60 expressions, toutes lisibles en LaTeX', () {
      final liste = Catalogue.lireExpressions(expressions);
      expect(liste, hasLength(60));
      expect(liste.toSet(), hasLength(60));
      for (final e in liste) {
        expect(
          () => TexParser(e, const TexParserSettings()).parse(),
          returnsNormally,
          reason: e,
        );
      }
    });
  });
}
