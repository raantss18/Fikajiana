import 'dart:ui';

import 'package:fikajiana/encre/encre.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = PointEncre(0, 0, 1);
  const b = PointEncre(10, 20, 1);
  const loin = PointEncre(100, 100, 1);

  group('Encre', () {
    test('copier des traits : nouveaux identifiants, décalés, annulable', () {
      final encre = Encre()
        ..commencer(a)
        ..prolonger(b);
      final source = encre.traits.single;
      final copies = encre.copierTraits({source.id}, const Offset(5, 5));
      expect(encre.traits, hasLength(2));
      final copie = encre.traits.last;
      expect(copies, {source.id: copie.id});
      expect(copie.id, isNot(source.id));
      expect(copie.points.first.position, const Offset(5, 5));
      encre.annuler();
      expect(encre.traits.single, same(source));
    });

    test('déplacer des traits garde leur identifiant', () {
      final encre = Encre()
        ..commencer(a)
        ..prolonger(b);
      final id = encre.traits.single.id;
      encre.deplacerTraits({id}, const Offset(1, 2));
      expect(encre.traits.single.id, id);
      expect(encre.traits.single.points.last.position, const Offset(11, 22));
      encre
        ..deplacerTraits({id}, Offset.zero)
        ..annuler();
      expect(encre.traits.single.points.last.position, const Offset(10, 20));
    });

    test('annuler et refaire reviennent exactement au même état', () {
      final encre = Encre()
        ..commencer(a)
        ..prolonger(b);
      expect(encre.traits.single.points, [a, b]);

      encre.annuler();
      expect(encre.estVide, isTrue);

      encre.refaire();
      expect(encre.traits.single.points, [a, b]);
    });

    test('un nouveau trait vide la pile de rétablissement', () {
      final encre = Encre()
        ..commencer(a)
        ..annuler()
        ..commencer(b);
      expect(encre.peutRefaire, isFalse);
    });

    test('gommer ne retire que les traits touchés, et s’annule', () {
      final encre = Encre()
        ..commencer(a)
        ..commencer(loin)
        ..gommer(Offset.zero, 5);
      expect(encre.traits.single.points, [loin]);

      encre.annuler();
      expect(encre.traits.length, 2);
    });

    test('gommer dans le vide ne crée pas d’étape à annuler', () {
      final encre = Encre()
        ..commencer(a)
        ..annuler();
      final annulable = encre.peutAnnuler;
      encre.gommer(const Offset(500, 500), 5);
      expect(encre.peutAnnuler, annulable);
    });

    test('effacer s’annule', () {
      final encre = Encre()
        ..commencer(a)
        ..effacer();
      expect(encre.estVide, isTrue);
      encre.annuler();
      expect(encre.traits.single.points, [a]);
    });

    test('un trait garde son stylo en se prolongeant', () {
      final encre = Encre()
        ..commencer(a, stylo: 2)
        ..prolonger(b);
      expect(encre.traits.single.stylo, 2);
    });

    test('cadre', () {
      final encre = Encre();
      expect(encre.cadre, isNull);
      encre
        ..commencer(a)
        ..prolonger(b);
      expect(encre.cadre, const Rect.fromLTRB(0, 0, 10, 20));
    });

    test('un seul point donne un chemin visible', () {
      expect(cheminDuTrait([a]).getBounds().width, greaterThan(0));
    });

    test('aller-retour JSON', () {
      final encre = Encre()..commencer(b);
      final point = PointEncre.depuisJson(encre.versJson().single.single);
      expect(point.position, b.position);
    });
  });
}
