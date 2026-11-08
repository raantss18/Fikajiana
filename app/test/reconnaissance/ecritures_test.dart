import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/classeur_appris.dart';
import 'package:fikajiana/reconnaissance/ecritures.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

List<dynamic> _document(String nom) =>
    jsonDecode(File('test/fixtures/pad7/$nom.json').readAsStringSync())
        as List<dynamic>;

class _Lecteur extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async => r'\varLambda';

  @override
  Future<List<String>> lirePlusieurs(List<Trait> traits) async => const [];
}

class _Moteur implements Moteur {
  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      const ReponseGiac(exact: '240', latex: '240', approche: '240.0');

  @override
  void interrompre() {}
}

Future<void> _attendre([int ms = 200]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late Encre encre;
  late Ecritures ecritures;

  CalculFeuille feuille({
    Duration attente = const Duration(milliseconds: 300),
    bool aider = true,
  }) {
    final c = CalculFeuille(
      encre: encre,
      lecteur: _Lecteur(),
      moteur: _Moteur(),
      pause: Duration.zero,
      attenteJuste: attente,
      classeur: ClasseurAppris(ecritures: ecritures),
      aider: () => aider,
    );
    addTearDown(c.dispose);
    return c;
  }

  List<(String, String, Origine)> contenu() => [
    for (final e in ecritures.liste) (e.type, e.attendu, e.origine),
  ];

  setUp(() {
    encre = Encre()..chargerDocument(_document('trente_fois_8'));
    ecritures = Ecritures();
  });

  group('collecte pendant l’usage (ADR 0042)', () {
    test(
      'une ligne lue, laissée sans correction : juste, et ses signes',
      () async {
        final calcul = feuille()..encreChangee();
        await _attendre();
        expect(calcul.blocs.single.latex, r'30\times8');
        expect(ecritures.liste, isEmpty);
        await _attendre(400);
        expect(contenu(), [
          ('expression', r'30\times8', Origine.juste),
          ('signe', '3', Origine.juste),
          ('signe', '0', Origine.juste),
          ('signe', r'\times', Origine.juste),
          ('signe', '8', Origine.juste),
        ]);
      },
    );

    test(
      'la feuille change : ce qui attendait est gardé tout de suite',
      () async {
        final calcul = feuille(attente: const Duration(minutes: 10))
          ..encreChangee();
        await _attendre();
        expect(ecritures.liste, isEmpty);
        calcul.validerLesJustes();
        expect(ecritures.liste, hasLength(5));
      },
    );

    test('un signe corrigé : jamais la lecture fausse comme juste', () async {
      final calcul = feuille()..encreChangee();
      await _attendre();
      final bloc = calcul.blocs.single;
      final (huit, _) = bloc.signesLus.last;
      await calcul.corrigerSigne(bloc, huit, '3');
      await _attendre(700);
      expect(calcul.blocs.single.latex, r'30\times3');
      expect(contenu(), [
        ('signe', '3', Origine.correction),
        ('expression', r'30\times3', Origine.juste),
        ('signe', '3', Origine.juste),
        ('signe', '0', Origine.juste),
        ('signe', r'\times', Origine.juste),
      ]);
    });

    test('une ligne corrigée après coup remplace sa lecture juste', () async {
      final calcul = feuille()..encreChangee();
      await _attendre(700);
      expect(ecritures.liste, hasLength(5));
      await calcul.corriger(calcul.blocs.single, r'30\times9');
      await _attendre();
      expect(contenu(), [('expression', r'30\times9', Origine.correction)]);
    });

    test('« Aider » coupé : rien de gardé, sauf les signes corrigés', () async {
      final calcul = feuille(aider: false)..encreChangee();
      await _attendre(700);
      expect(ecritures.liste, isEmpty);
      await calcul.corriger(calcul.blocs.single, r'30\times9');
      expect(ecritures.liste, isEmpty);
    });

    test('une ligne effacée avant le délai n’est pas gardée', () async {
      final calcul = feuille()..encreChangee();
      await _attendre();
      encre.chargerDocument(const []);
      calcul.encreChangee();
      await _attendre(700);
      expect(ecritures.liste, isEmpty);
    });
  });

  group('le magasin', () {
    test('plafond : les plus anciens partent', () async {
      final petit = Ecritures(plafond: 60000);
      final traits = Encre()..chargerDocument(_document('trente_fois_8'));
      for (var i = 0; i < 20; i++) {
        await petit.corrigerLigne(
          traits.traits.toList(),
          'ligne $i',
          const Rect.fromLTWH(0, 0, 100, 40),
        );
        // Une autre ligne à chaque fois : même traits, autre clé.
        traits.chargerDocument(_document(i.isEven ? 'e_x_egal_7' : 'AB_egal'));
      }
      expect(petit.octets, lessThanOrEqualTo(60000));
      expect(petit.liste.length, lessThan(20));
      expect(petit.liste.last.attendu, 'ligne 19');
    });

    test('reste sur l’appareil, se recharge, s’efface', () async {
      final dossier = Directory.systemTemp.createTempSync('ecritures');
      addTearDown(() => dossier.deleteSync(recursive: true));
      final fichier = File('${dossier.path}/ecritures/ecritures.jsonl');
      final a = Ecritures(fichier: fichier);
      final traits = encre.traits.toList();
      const c = Rect.fromLTWH(0, 0, 100, 40);
      await a.ligneJuste(traits, r'30\times8', c, const []);
      await a.corrigerLigne(traits, r'30\times9', c);
      final b = Ecritures(fichier: fichier);
      await b.charger();
      expect(b.liste.map((e) => e.attendu), [r'30\times9']);
      expect(b.octets, a.octets);
      await b.toutEffacer();
      expect(fichier.existsSync(), isFalse);
    });

    test(
      'exporte au format de collecte/FORMAT.md, un fichier par outil',
      () async {
        final traits = encre.traits.toList();
        const c = Rect.fromLTWH(10, 20, 300, 40);
        await ecritures.ligneJuste(traits, r'30\times8', c, [
          (traits.take(1).toList(), '3', c),
          (traits.skip(1).take(1).toList(), '§', c),
        ]);
        final doigt = Trait(const PointEncre(5, 5, 0.3, tempsMs: 1000));
        for (var i = 1; i < 8; i++) {
          doigt.points.add(PointEncre(5, 5 + i * 3, 0.3, tempsMs: 1000.0 + i));
        }
        await ecritures.corrigerSigne([doigt], '1', caseLigne: c);
        final fichiers = ecritures.exporter(
          modele: '2410CRP4CG',
          ecranDp: const Size(1280, 800),
          densite: 2.75,
          auteur: 'Antsa',
          maintenant: DateTime(2026, 11, 8, 9, 30),
        );
        expect(fichiers.keys, [
          'fikajiana-ecriture-2410CRP4CG-20261108-093000.json',
          'fikajiana-ecriture-2410CRP4CG-20261108-093000-doigt.json',
        ]);
        final stylet =
            jsonDecode(fichiers.values.first) as Map<String, dynamic>;
        expect(stylet.keys, [
          'format',
          'licence',
          'auteur',
          'appareil',
          'outil',
          'debut',
          'echantillons',
        ]);
        expect(stylet['format'], 1);
        expect(stylet['licence'], 'CC0-1.0');
        expect(stylet['auteur'], 'Antsa');
        expect(stylet['outil'], 'stylet');
        final ech = (stylet['echantillons'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        // Le `§` n'est pas une classe de collecte/classes.txt : laissé.
        expect([for (final e in ech) e['type']], ['expression', 'signe']);
        expect(ech.first.containsKey('classe'), isFalse);
        expect(ech.first['attendu'], r'30\times8');
        expect(ech.last['classe'], '3');
        expect(ech.last.keys, [
          'id',
          'type',
          'classe',
          'attendu',
          'traits',
          'case',
          'rejete',
        ]);
        expect(ech.first['case'], [10, 20, 300, 40]);
        final doigts = jsonDecode(fichiers.values.last) as Map<String, dynamic>;
        expect(doigts['outil'], 'doigt');
        final s =
            (doigts['echantillons'] as List<dynamic>).single
                as Map<String, dynamic>;
        final points = ((s['traits'] as List<dynamic>).single as List<dynamic>)
            .cast<List<dynamic>>();
        expect(points.first, [5, 5, 0, 1]);
        expect(points.last[2], 7);
      },
    );
  });
}
