import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/mots.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les traits d'Antsa, relevés sur le Pad 7 le 2026-11-07.
List<Trait> _traits(String nom) {
  final json = jsonDecode(
    File('test/fixtures/pad7/$nom.json').readAsStringSync(),
  ) as List<dynamic>;
  return [
    for (final t in json) Trait.depuisDocument(t as Map<String, dynamic>),
  ];
}

void main() {
  group('un mot écrit devant sa parenthèse', () {
    // Vu sur le Pad 7 : le modèle lisait `\wp^{\pi a m^{2}} \O \pi (17)`.
    test('premier(17) : le mot se reconnaît, sans doute possible', () {
      final traits = _traits('premier_17');
      final ecrit = separerMot(traits)!;
      expect(ecrit.mot.length + ecrit.suite.length, traits.length);
      // La suite commence par la parenthèse : 1, 7 et ) avec elle.
      expect(
        cadreDuGroupe(ecrit.suite).left,
        greaterThan(cadreDuGroupe(ecrit.mot).right - 5),
      );
      final classes = classerMots(ecrit.mot);
      expect(classes.first.$1, 'premier');
      expect(motSur(classes), 'premier');
    });

    // Vu sur le Pad 7 : lu `\alpha \lim_{\log_1 \alpha_2}((2x-\pi)(x-4))`.
    test('développer((2x-1)(x-4)) : le mot cursif se reconnaît', () {
      final ecrit = separerMot(_traits('developper'))!;
      final classes = classerMots(ecrit.mot);
      expect(classes.first.$1, 'développer');
      expect(motSur(classes), 'développer');
      // Les deux parenthèses du produit restent dans la suite.
      expect(ecrit.suite.length, greaterThan(10));
      // Et `((…))` n'y est pas pris pour une norme `‖…‖`.
      expect(trouverStructure(ecrit.suite), isNull);
    });

    test('une ligne sans mot devant sa parenthèse n’en a pas', () {
      expect(separerMot(_traits('puissances_de_10')), isNull);
    });

    test('det devant une matrice n’est pas un mot à reconnaître', () {
      // `det` est trop court devant sa grande parenthèse : la matrice le lit.
      expect(separerMot(_traits('det_3x3_72')), isNull);
    });

    test('deux mots qui se ressemblent trop : pas de choix forcé', () {
      expect(motSur([('premier', 0.8), ('moyenne', 1.0)]), isNull);
      expect(motSur([('premier', 1.5), ('moyenne', 2.5)]), isNull);
      expect(motSur([('premier', 0.6), ('moyenne', 1.3)]), 'premier');
    });
  });
}
