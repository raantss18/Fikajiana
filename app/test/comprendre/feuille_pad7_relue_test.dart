import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:flutter_test/flutter_test.dart';

// Les feuilles d'Antsa sur le Pad 7, relues après la 1.0.7 : ce qui y était
// encore mal lu. Les traits viennent de ses feuilles, tels quels (CC0).

List<Trait> _charger(String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/pad7/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

void main() {
  test('A = : le A d’un seul trait n’est pas un h', () {
    expect(lireAuTrace(_charger('A_egal_un_trait')), 'A=');
  });
}
