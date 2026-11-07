import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les traits d'Antsa sur le Pad 7, le 2026-11-07.
List<Trait> _traits(String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/pad7/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

/// Répond ce que Pix2Text a lu de ces mêmes traits sur l'ordinateur
/// (`models/rejouer_encre.py`), selon les traits demandés ; sinon du bruit.
class _Modele extends Lecteur {
  new(this.tous, this.reponses);
  final List<Trait> tous;
  final Map<List<int>, String> reponses;

  @override
  Future<String> lire(List<Trait> traits) async {
    final indices = [for (final t in traits) tous.indexOf(t)]..sort();
    for (final MapEntry(:key, :value) in reponses.entries) {
      if (key.length == indices.length && key.every(indices.contains)) {
        return value;
      }
    }
    return r'\overbrace { \varUpsilon }';
  }
}

void main() {
  group('lu sur le Pad 7, relu juste', () {
    test('A(8;-1), que le modèle lit A(8i-1)', () async {
      final traits = _traits('point_A');
      expect(trouverStructure(traits), isA<StructurePoint>());
      final lu = await lireStructure(_Modele(traits, const {}), traits);
      expect(lu, 'A(8;-1)');
    });

    test('B(5;8), que le modèle lit β(5,0)', () async {
      final traits = _traits('point_B');
      final lu = await lireStructure(_Modele(traits, const {}), traits);
      expect(lu, 'B(5;8)');
    });

    test('det(8 -1 ; 8 4) : le 8 hésitant ne fait plus tout échouer', () async {
      final traits = _traits('det_2x2_40');
      final modele = _Modele(traits, const {
        [0, 2, 3, 4]: r'\det',
        [6, 8]: '8',
        [6, 7, 8]: '8 - 1',
        [9, 10, 11]: '8 - 4',
        [13, 14]: '=',
      });
      final lu = await lireStructure(modele, traits);
      expect(lu, startsWith(r'\det \begin{pmatrix}8&-1\\8&4\end{pmatrix}'));
    });

    test('(1 8 ; -1 7)⁻¹ = : l’exposant n’est plus lu « - 1 »', () async {
      final traits = _traits('matrice_inverse');
      final modele = _Modele(traits, const {
        [9, 10]: '- 1',
        [1, 2]: '1 8',
        [3, 4, 5, 6, 7]: '- 1 7',
      });
      final lu = await lireStructure(modele, traits);
      expect(lu, r'\begin{pmatrix}1&8\\-1&7\end{pmatrix}^{-1}=');
      expect(analyserLatex(lu!).giac, '([[1,8],[(-1),7]])^((-1))');
    });

    test('e^x = 7 lu « e^x - 7 » : le = revient', () {
      final traits = _traits('e_x_egal_7');
      expect(signesPlats(traits), ['=']);
      expect(redresserEgal(traits, 'e ^ { x } - 7'), 'e ^ { x } = 7');
    });

    test('un vrai moins reste un moins', () {
      final traits = _traits('det_2x2_40');
      // Le moins de la case, puis le = final.
      expect(signesPlats(traits), ['-', '=']);
      expect(redresserEgal(_traits('trente_fois_8'), '3 0 - 8'), '3 0 - 8');
    });

    test('det lu « φe^{1/2} » sur le Pad : reste det', () async {
      final traits = _traits('det_2x2_40');
      final modele = _Modele(traits, const {
        [0, 2, 3, 4]: r'\phi e ^ { \frac { 1 } { 2 } }',
        [6, 7, 8]: '8 - 1',
        [9, 10, 11]: '8 - 4',
      });
      final lu = await lireStructure(modele, traits);
      expect(lu, startsWith(r'\det \begin{pmatrix}8&-1\\8&4'));
      // Un vrai facteur, lui, reste : 2·(…).
      expect(
        await lireStructure(
          _Modele(traits, const {
            [0, 2, 3, 4]: '2',
            [6, 7, 8]: '8 - 1',
            [9, 10, 11]: '8 - 4',
          }),
          traits,
        ),
        startsWith(r'2\begin{pmatrix}'),
      );
    });

    test('une matrice reste une matrice, pas un point', () {
      expect(trouverStructure(_traits('det_3x3_72')), isA<StructureMatrice>());
      expect(trouverStructure(_traits('det_2x2_40')), isA<StructureMatrice>());
    });
  });
}
