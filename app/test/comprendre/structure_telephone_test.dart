import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les traits d'Antsa sur son téléphone (2026-11-07), relevés sur ses
/// captures : un `1` qui monte de tout en bas puis redescend, des
/// parenthèses longues et peu bombées, un `;` au point détaché.
List<Trait> _traits(String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/telephone/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

/// Le modèle y lit `\varLambda` partout (Pix2Text sur l'ordinateur, mêmes
/// traits) : la lecture doit venir du tracé.
class _Modele extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async => r'\varLambda';
}

void main() {
  test('A(1;-1), que le modèle lit λ(1/i-Λ)', () async {
    expect(
      await lireStructure(_Modele(), _traits('point_A_1_moins_1')),
      'A(1;-1)',
    );
  });

  test('A(3;-1), que le modèle lit A(3i-1)', () async {
    expect(
      await lireStructure(_Modele(), _traits('point_A_3_moins_1')),
      'A(3;-1)',
    );
  });

  test('1+1 n’est pas une structure : le Λ se redresse ailleurs', () async {
    expect(await lireStructure(_Modele(), _traits('un_plus_un')), isNull);
  });
}
