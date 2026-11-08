import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

// Les feuilles d'Antsa du 8 novembre (Pad 7, stylet, 1.0.5), relues
// (ADR 0047) : les traits viennent de ses feuilles, tels quels.

List<Trait> _charger(String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/pad7/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

/// Le modèle : une lecture par morceau, reconnu à ses traits.
class _Modele extends Lecteur {
  new(this.lectures, {this.sinon = r'\varLambda'});

  /// Ce qu'il lit d'un morceau dont tous les traits sont dans la clé.
  final Map<Set<int>, String> lectures;

  @override
  Future<String> lire(List<Trait> traits) async {
    final ids = {for (final t in traits) t.id};
    for (final MapEntry(:key, :value) in lectures.entries) {
      if (key.containsAll(ids)) return value;
    }
    return sinon;
  }

  /// Ce qu'il lit du reste.
  final String sinon;
}

class _Moteur implements Moteur {
  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      const ReponseGiac(exact: '5', latex: '5', approche: '5.0');

  @override
  void interrompre() {}
}

/// Écrit [traits] comme Antsa, par paquets (une pause entre deux numéros de
/// traits qui ne se suivent pas), et rend les blocs de la feuille. Avec
/// [relire], « Relire la feuille » passe ensuite.
Future<List<BlocCalcul>> _ecrire(
  List<Trait> traits, {
  bool relire = false,
  String sinon = r'\varLambda',
}) async {
  final tries = traits.toList()..sort((a, b) => a.id.compareTo(b.id));
  final encre = Encre();
  final calcul = CalculFeuille(
    encre: encre,
    lecteur: _Modele(const {}, sinon: sinon),
    moteur: _Moteur(),
    pause: Duration.zero,
  );
  addTearDown(calcul.dispose);
  final docs = <Map<String, dynamic>>[];
  for (var i = 0; i < tries.length; i++) {
    docs.add(tries[i].versDocument());
    if (i + 1 < tries.length && tries[i + 1].id - tries[i].id == 1) continue;
    encre.chargerDocument(docs);
    calcul.encreChangee();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  if (relire) {
    calcul.relireTout();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return calcul.blocs.toList();
}

Set<int> _ids(List<Trait> traits) => {for (final t in traits) t.id};

void main() {
  group('lim écrit au-dessus de x → a, une fraction à droite', () {
    for (final nom in [
      'lim_inverse_carre',
      'lim_exp_sur_2x',
      'lim_3x_sur_exp',
    ]) {
      test('$nom : la flèche courte et sa pointe se voient', () {
        expect(trouverStructure(_charger(nom)), isA<StructureLimite>());
      });

      test('$nom : un seul calcul, écrit par morceaux', () async {
        // Vu sur le Pad 7 : la ligne `x → 0 … 2x`, le dénominateur écrit
        // après la barre, `lim` écrit avant la fraction faisaient d'autres
        // blocs, soulignés.
        expect(await _ecrire(_charger(nom)), hasLength(1));
      });
    }

    test('le `=` haut, au niveau de la barre, n’est pas perdu', () async {
      final traits = _charger('lim_inverse_carre');
      expect(finitParEgal(traits), isTrue);
      final s = trouverStructure(traits)! as StructureLimite;
      final lu = await lireStructure(
        _Modele({
          _ids(s.mot): 'lim',
          _ids(s.variable): 'x',
          _ids(s.cible): '3',
          // Le modèle oublie le `=` (Pad 7) : il revient au tracé.
          _ids(s.queue): r'\frac{1}{(x-3)^{2}}',
        }),
        traits,
      );
      expect(lu, r'\lim_{x \to 3} \frac{1}{(x-3)^{2}}=');
    });

    test('sans `=` à droite, rien n’est ajouté', () {
      final traits = _charger('lim_inverse_carre');
      final sansEgal = [
        for (final t in traits)
          if (t.id != 2415 && t.id != 2416) t,
      ];
      expect(finitParEgal(sansEgal), isFalse);
      expect(redresserEgal(sansEgal, 'x'), 'x');
    });
  });

  test('p(x) écrit sous un produit de matrices : deux calculs', () async {
    expect(await _ecrire(_charger('produit_matrices_et_p')), hasLength(2));
  });

  test('Relire la feuille : la lim reste hors du produit de matrices '
      'écrit dessous', () async {
    final lim = _charger('lim_3x_sur_exp');
    final produit = _charger('produit_matrices_et_p');
    // Les deux seuls, puis la feuille entière d'Antsa (9 h 43).
    final toute = _charger('feuille_8nov_0943');
    for (final traits in [
      [...lim, ...produit],
      toute,
    ]) {
      // Rien n'est compris : tout cherche un bloc à rejoindre.
      final blocs = await _ecrire(
        traits,
        relire: true,
        sinon: r'\underbrace{\cup}',
      );
      final idsLim = _ids(lim);
      for (final b in blocs) {
        // Un bloc est tout entier de la lim, ou tout entier hors d'elle.
        final dedans = b.traits.where(idsLim.contains).length;
        expect(
          dedans == 0 || dedans == b.traits.length,
          isTrue,
          reason: '${b.traits}',
        );
      }
    }
  });

  group('les points de la figure', () {
    test('C(2;7) : le `;` collé au 2, un petit trait dessous', () async {
      final traits = _charger('point_C_2_7');
      expect(trouverStructure(traits), isA<StructurePoint>());
      expect(await lireStructure(_Modele(const {}), traits), 'C(2;7)');
    });

    test('B(2;-25) : le moins se voit, même si le modèle l’oublie', () async {
      final traits = _charger('point_B_moins_25');
      final s = trouverStructure(traits)! as StructurePoint;
      final lu = await lireStructure(_Modele({_ids(s.second): '2 5'}), traits);
      expect(lu, 'B(2;-25)');
    });

    test('D(8;-3) : le 8 lu au tracé, pas 5', () async {
      final traits = _charger('point_D_8_moins_3');
      final s = trouverStructure(traits)! as StructurePoint;
      final lu = await lireStructure(_Modele({_ids(s.second): '- 3'}), traits);
      expect(lu, 'D(8;-3)');
    });
  });
}
