import 'dart:ui';

import 'package:fikajiana/encre/encre.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = PointEncre(0, 0, 1);
  const b = PointEncre(10, 20, 1);
  const loin = PointEncre(100, 100, 1);

  group('Encre', () {
    test('annuler et refaire reviennent exactement au même état', () {
      final encre = Encre()
        ..commencer(a)
        ..prolonger(b);
      expect(encre.traits.single, [a, b]);

      encre.annuler();
      expect(encre.estVide, isTrue);

      encre.refaire();
      expect(encre.traits.single, [a, b]);
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
      expect(encre.traits.single, [loin]);

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
      expect(encre.traits.single, [a]);
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
      expect(cheminDuTrait([a]).getBounds().isEmpty, isFalse);
    });

    test('aller-retour JSON', () {
      final encre = Encre()..commencer(b);
      final point = PointEncre.depuisJson(encre.versJson().single.single);
      expect(point.position, b.position);
    });
  });
}
