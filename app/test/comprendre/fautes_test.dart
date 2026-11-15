import 'dart:convert';
import 'dart:io';

import 'dart:ui';

import 'package:fikajiana/comprendre/copie.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/comprendre/fautes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les réponses du vrai Giac, enregistrées par `tool/enregistrer_giac.dart`.
class _GiacEnregistre implements Moteur {
  final Map<String, dynamic> _reponses = jsonDecode(
    File('test/fixtures/giac/fautes.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async {
    final r = _reponses[entree] as Map<String, dynamic>?;
    if (r == null) fail('calcul non enregistré : $entree');
    return ReponseGiac(
      exact: r['exact'] as String,
      latex: r['latex'] as String,
      approche: r['approche'] as String,
      erreur: r['erreur'] as String?,
    );
  }

  @override
  void interrompre() {}
}

LigneCopie _ligne(String latex) {
  final a = analyserLatex(latex);
  final x = a.inconnues.singleOrNull;
  return a.membres != null && x != null
      ? LigneCopie.equation(latex, a.membres!.$1, a.membres!.$2, x)
      : LigneCopie(latex, a.giac);
}

Future<PisteFaute?> _piste(String avant, String ici) async {
  final moteur = _GiacEnregistre();
  final lignes = [_ligne(avant), _ligne(ici)];
  final v = await verifierCopie(moteur, lignes);
  expect(v.last, VerdictLigne.fausse, reason: '$avant -> $ici');
  return (await pistesCopie(moteur, lignes, v)).last;
}

void main() {
  // Chaque copie fautive est écrite à la main avec la faute nommée ; la
  // ligne juste est calculée sans l'app (développement, division).
  test('chaque faute du catalogue est reconnue, avec la ligne juste', () async {
    final attendues = {
      ('(x+1)^{2}', 'x^{2}+1'): (
        Faute.doubleProduit,
        r'\left(x+1\right)^{2}=x^{2}+2x+1',
      ),
      ('(x-3)^{2}', 'x^{2}-9'): (
        Faute.doubleProduit,
        r'\left(x-3\right)^{2}=x^{2}-6x+9',
      ),
      ('2(x+1)+3', '2x+1+3'): (Faute.distribution, r'2\left(x+1\right)=2x+2'),
      ('3(x+1)=12', '3x+1=12'): (Faute.distribution, r'3\left(x+1\right)=3x+3'),
      ('5-(x+2)', '5-x+2'): (Faute.signeParenthese, r'-\left(x+2\right)=-x-2'),
      ('2x+3=7', '2x=10'): (Faute.deplacementSansSigne, '2x=4'),
      ('2x=6', 'x=4'): (Faute.soustraireAuLieuDeDiviser, r'x=\frac{6}{2}=3'),
      ('2x=6', 'x=12'): (Faute.multiplierAuLieuDeDiviser, r'x=\frac{6}{2}=3'),
      ('4x=2', 'x=2'): (Faute.divisionALEnvers, r'x=\frac{2}{4}=\frac{1}{2}'),
      ('x+3=1', 'x=2'): (Faute.signeDeLaSolution, 'x=-2'),
    };
    for (final MapEntry(key: (avant, ici), value: (faute, juste))
        in attendues.entries) {
      final p = await _piste(avant, ici);
      expect(p?.faute, faute, reason: '$avant -> $ici');
      expect(p?.correction, juste, reason: '$avant -> $ici');
      expect(
        ecrireResultat(juste, const Rect.fromLTWH(0, 0, 40, 40)),
        isNotNull,
        reason: juste,
      );
    }
  });

  test('deux passages en un : la faute du premier est retrouvée', () async {
    // 2x + 3 = 7, puis directement x = 5 : le +3 est passé sans changer de
    // signe (2x = 10), puis la division est juste.
    expect((await _piste('2x+3=7', 'x=5'))?.faute, Faute.deplacementSansSigne);
  });

  test('hors catalogue : pas de piste plutôt qu’une piste inventée', () async {
    expect(await _piste('5=x-2', '5+2=x+2'), isNull);
    expect(await _piste('(x+1)^{2}', 'x^{2}+3x+1'), isNull);
  });
}
