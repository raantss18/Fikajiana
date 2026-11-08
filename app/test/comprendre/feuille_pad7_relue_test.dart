import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/mots.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// Les feuilles d'Antsa sur le Pad 7, relues après la 1.0.7 : ce qui y était
// encore mal lu. Les traits viennent de ses feuilles, tels quels (CC0).

List<Trait> _charger(String nom) => [
  for (final t in jsonDecode(
    File('test/fixtures/pad7/$nom.json').readAsStringSync(),
  ) as List<dynamic>)
    Trait.depuisDocument(t as Map<String, dynamic>),
];

/// Le modèle : une lecture par morceau, reconnu à ses traits.
class _Modele extends Lecteur {
  new(this.lectures);

  final Map<Set<int>, String> lectures;

  @override
  Future<String> lire(List<Trait> traits) async {
    final ids = {for (final t in traits) t.id};
    for (final MapEntry(:key, :value) in lectures.entries) {
      if (key.containsAll(ids)) return value;
    }
    return r'\underbrace{\cup}';
  }
}

class _Moteur implements Moteur {
  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      const ReponseGiac(exact: 'x', latex: 'x', approche: '');

  @override
  void interrompre() {}
}

/// Écrit [traits] comme Antsa, par paquets (une pause entre deux numéros de
/// traits qui ne se suivent pas), et rend les blocs de la feuille.
Future<List<BlocCalcul>> _ecrire(List<Trait> traits, Lecteur lecteur) async {
  final tries = traits.toList()..sort((a, b) => a.id.compareTo(b.id));
  final encre = Encre();
  final calcul = CalculFeuille(
    encre: encre,
    lecteur: lecteur,
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
  return calcul.blocs.toList();
}

Set<int> _ids(List<Trait> traits) => {for (final t in traits) t.id};

void main() {
  test('g(x) = puis x − 1/x écrit après une pause : une seule ligne', () async {
    // Feuille de 14 h 05 : `g(x) =` lu `y^{(x)}=` fermait la ligne, et la
    // suite faisait un autre calcul.
    final traits = _charger('g_egal_x_moins_1_sur_x');
    final tete = {
      for (final t in traits)
        if (t.id <= 3330) t.id,
    };
    final blocs = await _ecrire(
      traits,
      _Modele({
        tete: 'y^{(x)}=',
        {for (final t in traits) t.id}: r'g(x)=x-\frac{1}{x}',
      }),
    );
    expect(blocs, hasLength(1));
    expect(blocs.single.latex, r'g(x)=x-\frac{1}{x}');
  });

  test('A = : le A d’un seul trait n’est pas un h', () {
    expect(lireAuTrace(_charger('A_egal_un_trait')), 'A=');
  });

  test('résoudre( écrit à la main : le mot se reconnaît', () {
    final ecrit = separerMot(_charger('resoudre_f_egal_h'));
    expect(ecrit, isNotNull);
    final classes = classerMots(ecrit!.mot, lexique: motsDevantParenthese);
    expect(classes.first.$1, 'résoudre', reason: '$classes');
    expect(motSur(classes), 'résoudre', reason: '$classes');
  });

  test(
    'M devant une matrice 2×3 : jamais un det (feuille de 15 h 14)',
    () async {
      final traits = _charger('M_matrice_2x3');
      expect(trouverStructure(traits), isA<StructureMatrice>());
      // Le modèle lisait le M comme un mot quelconque, devenu `det` : `= −6`.
      final lu = await lireStructure(_Modele({_ids(traits): '1 3 5'}), traits);
      expect(lu, isNotNull);
      expect(lu, isNot(contains(r'\det')));
    },
  );

  test('tête de définition : g(x)=, u_{n+1}= ; pas f(1)= ni u_{3}=', () {
    bool tete(String latex) =>
        BlocCalcul(cle: 't', cadre: Rect.zero, latex: latex).teteDeDefinition;
    expect(tete('g(x)='), isTrue);
    expect(tete('y^{(x)}='), isTrue);
    expect(tete('u_{n+1}='), isTrue);
    expect(tete('u _ { n + 1 } ='), isTrue);
    expect(tete('f(1)='), isFalse);
    expect(tete('u_{3}='), isFalse);
    expect(tete("f'(x)="), isFalse);
  });
}
