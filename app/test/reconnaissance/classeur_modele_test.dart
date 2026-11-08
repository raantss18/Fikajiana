import 'dart:ui';

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_appris.dart';
import 'package:fikajiana/reconnaissance/classeur_onnx.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/reconnaissance/rendu_signe.dart';
import 'package:flutter_test/flutter_test.dart';

/// Des gabarits qui doutent toujours, ou tranchent toujours.
class _Gabarits extends ClasseurSignes {
  new(this.verdict);
  final String? verdict;

  @override
  Future<Classement> classer(
    List<Trait> signe, {
    required Rect caseLigne,
    int combien = 3,
  }) async => [if (verdict case final v?) (v, 1.0)];

  @override
  Map<String, double>? signe(
    List<Trait> signe, {
    required double hauteurLigne,
  }) => verdict == null ? null : {verdict!: 0.5};

  @override
  String? chiffre(List<Trait> signe) => verdict;

  @override
  String? capitale(List<Trait> signe) => verdict;
}

/// Un modèle qui répond toujours la même chose.
class _Modele extends _Gabarits {
  new(this.reponse) : super(null);
  final Classement reponse;
  int appels = 0;

  @override
  Future<Classement> classer(
    List<Trait> signe, {
    required Rect caseLigne,
    int combien = 3,
  }) async {
    appels++;
    return reponse;
  }
}

List<Trait> _signe() {
  final t = Trait(const PointEncre(0, 0, 0.5));
  for (var i = 1; i < 10; i++) {
    t.points.add(PointEncre(0, i * 4.0, 0.5));
  }
  return [t];
}

const _case = Rect.fromLTWH(0, 0, 100, 40);

void main() {
  group('le modèle par signe passe après les gabarits (ADR 0041)', () {
    test('gabarits sûrs : leur verdict, quoi que dise le modèle', () async {
      final c = ClasseurAppris(base: _Gabarits('1'))
        ..modele = _Modele(const [('7', 0.99), ('1', 0.01)]);
      final s = _signe();
      await c.preparer(s, caseLigne: _case);
      expect(c.signe(s, hauteurLigne: 40), {'1': 0.5});
      expect(c.chiffre(s), '1');
    });

    test('gabarits dans le doute, modèle sûr : le modèle', () async {
      final modele = _Modele(const [('7', 0.97), ('1', 0.02)]);
      final c = ClasseurAppris(base: _Gabarits(null))..modele = modele;
      final s = _signe();
      expect(c.signe(s, hauteurLigne: 40), isNull);
      await c.preparer(s, caseLigne: _case);
      await c.preparer(s, caseLigne: _case);
      expect(modele.appels, 1);
      expect(c.signe(s, hauteurLigne: 40), {'7': closeTo(0.03, 1e-9)});
      expect(c.chiffre(s), '7');
      expect(c.capitale(s), isNull);
      expect(c.signesModele, 1);
    });

    test('modèle hésitant, ou classe hors du tracé : le doute', () async {
      for (final reponse in const [
        [('7', 0.6), ('1', 0.4)],
        [(r'\int', 0.99), ('1', 0.01)],
      ]) {
        final c = ClasseurAppris(base: _Gabarits(null))
          ..modele = _Modele(reponse);
        final s = _signe();
        await c.preparer(s, caseLigne: _case);
        expect(c.signe(s, hauteurLigne: 40), isNull);
      }
    });

    test('sans modèle, rien ne change', () async {
      final c = ClasseurAppris(base: _Gabarits(null));
      final s = _signe();
      await c.preparer(s, caseLigne: _case);
      expect(c.signe(s, hauteurLigne: 40), isNull);
      expect(c.signesModele, 0);
    });

    test('les classes que le tracé sait écrire', () {
      for (final s in ['4', 'x', 'B', '+', '-', '=', '(', ')', "'"]) {
        expect(ClasseurAppris.classesLues.hasMatch(s), isTrue, reason: s);
      }
      expect(ClasseurAppris.classesLues.hasMatch(r'\pi'), isTrue);
      expect(ClasseurAppris.classesLues.hasMatch(r'\times'), isTrue);
      expect(ClasseurAppris.classesLues.hasMatch(r'\int'), isFalse);
      expect(ClasseurAppris.classesLues.hasMatch(','), isFalse);
    });
  });

  test('entrées du modèle : 32×32 et cinq mesures ; softmax', () {
    final (image, mesures) = entreesDuSigne(_signe(), _case);
    expect(image, hasLength(tailleImage * tailleImage));
    expect(mesures, hasLength(nombreMesures));
    expect(image.any((v) => v > 0), isTrue);
    final p = softmax([1, 2, 3]);
    expect(p.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-12));
    expect(p[2], greaterThan(p[1]));
  });

  test('sans modèle embarqué, ClasseurOnnx.charger rend null', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await ClasseurOnnx.charger(), isNull);
  });
}
