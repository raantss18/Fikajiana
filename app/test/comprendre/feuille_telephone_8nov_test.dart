import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:flutter_test/flutter_test.dart';

// Le téléphone d'Antsa (1.0.6, stylet), 8 novembre (ADR 0047). Les traits
// sont recopiés d'après ses captures, pas relevés sur l'appareil : leur
// forme est juste, leur tracé fin ne l'est pas.

List<Trait> _charger(String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/telephone/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

void main() {
  test('f(1)= : un 1 à pied entre parenthèses n’est pas une matrice', () {
    final traits = _charger('f_de_1_egal');
    expect(trouverStructure(traits), isNot(isA<StructureMatrice>()));
  });

  test('f(1)= et e³−2e⁶= : le `=` oublié par le modèle revient', () {
    for (final (nom, lu) in [
      ('f_de_1_egal', 'f(1)'),
      ('e3_moins_2e6_egal', 'e^{3}-2e^{6}'),
    ]) {
      final traits = _charger(nom);
      expect(finitParEgal(traits), isTrue, reason: nom);
      expect(redresserEgal(traits, lu), '$lu=', reason: nom);
    }
  });

  test('lim au-dessus de x → 0, puis f(x) : la structure se voit', () {
    final traits = _charger('lim_f_de_x');
    final s = trouverStructure(traits);
    expect(s, isA<StructureLimite>());
    // `f(x)` est ce que la limite porte, rien d'autre.
    expect((s! as StructureLimite).queue, hasLength(6));
    expect(finitParEgal(traits), isFalse);
  });

  test('e³−2e⁶= : le `e` cursif lu `c` par le modèle redevient `e`', () {
    // Montage des signes réels d'Antsa (Pad 7, 8 novembre) : ses deux `e`
    // cursifs, ses `3`, `2`, `6`, `−`, `=` ; exposants petits et hauts.
    final traits = [
      for (final t in jsonDecode(
        File('test/fixtures/pad7/e3_moins_2e6_montage.json').readAsStringSync(),
      ) as List<dynamic>)
        Trait.depuisDocument(t as Map<String, dynamic>),
    ];
    expect(finitParEgal(traits), isTrue);
    expect(redresserLettres(traits, 'c^{3}-2e^{6}='), 'e^{3}-2e^{6}=');
    expect(redresserLettres(traits, 'c^{3}-2c^{6}='), 'e^{3}-2e^{6}=');
    // Un `\cos` ou un `c` dans un mot ne bouge pas.
    expect(redresserLettres(traits, r'\cos(3)'), r'\cos(3)');
  });

  test('sans `e` sûr au tracé, le `c` du modèle reste', () {
    final traits = _charger('e3_moins_2e6_egal');
    expect(redresserLettres(traits, 'c^{3}-2e^{6}='), 'c^{3}-2e^{6}=');
  });
}
