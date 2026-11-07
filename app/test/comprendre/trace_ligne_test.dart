import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

List<Trait> _traits(String dossier, String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/$dossier/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

/// Le modèle : du bruit sur une ligne, mais un `2` seul se lit (comme sur
/// le téléphone, où seul le `4` ouvert devenait `1/1`).
class _Bruit extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async =>
      traits.length == 1 ? '2' : r'\varLambda';
}

void main() {
  group('une ligne lue sur son tracé, sans le modèle (ADR 0035)', () {
    test('1+1 du téléphone d’Antsa, dans ses deux formes', () {
      expect(lireAuTrace(_traits('telephone', 'un_plus_un')), '1+1');
      expect(lireAuTrace(_traits('telephone', 'un_plus_un_2')), '1+1');
    });

    test('30×8 du Pad 7', () {
      expect(lireAuTrace(_traits('pad7', 'trente_fois_8')), r'30\times8');
    });

    test("f'(x)= du Pad 7 : le f, l'apostrophe, le x en deux arcs", () {
      expect(lireAuTrace(_traits('pad7', 'derivee_f')), "f'(x)=");
    });

    test('ce qui doute va au modèle', () {
      expect(lireAuTrace(_traits('pad7', 'developper')), isNull);
      expect(lireAuTrace(_traits('telephone', 'limite')), isNull);
    });
  });

  group('matrice au carré du téléphone d’Antsa', () {
    test('le 4 ouvert et l’exposant 2 se lisent au tracé', () async {
      expect(
        await lireStructure(_Bruit(), _traits('telephone', 'matrice_carre')),
        r'\begin{pmatrix}3&-1\\2&4\end{pmatrix}^{2}=',
      );
    });
  });

  group('limite du téléphone d’Antsa', () {
    test('lim sous x → 0 de 1/x, mot et flèche au tracé', () async {
      expect(
        await lireStructure(_Limite(), _traits('telephone', 'limite')),
        r'\lim_{x \to 0} \frac{1}{x}',
      );
    });
  });
}

/// Ce que le modèle lit de chaque morceau sur l'ordinateur : `\lim` pour
/// le mot, `x` pour la variable, et la fraction.
class _Limite extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async {
    // Le mot et la variable sont à gauche de la flèche, la cible juste à sa
    // droite, la fraction plus loin.
    final gauche = cadreDuGroupe(traits).left;
    if (gauche > 600) return r'\frac{1}{x}';
    if (traits.length == 3) return r'\lim';
    return gauche < 300 ? 'x' : '0';
  }
}
