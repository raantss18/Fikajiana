import 'package:fikajiana/graphe/courbes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estCourbeSeule', () {
    const courbes = [
      'x^2+y^2=9',
      'xy=1',
      r'(\cos(t),\sin(t))',
      r'x=\cos(t),y=\sin(t)',
      r'r=1+\cos(\theta)',
      r'(t,t^2), t \in [0,1]',
    ];
    for (final latex in courbes) {
      test('$latex se trace', () => expect(estCourbeSeule(latex), isTrue));
    }

    // Une seule inconnue : le résoudre reste ce qu'on attend. Une fonction
    // a déjà son bouton, sans changer de chemin.
    const calculs = [
      'y=2x+1',
      'x^2=2',
      '2y=4',
      'x=3',
      'r=2',
      'x^2',
      '2+3',
      '2+3=',
      'x^2+',
    ];
    for (final latex in calculs) {
      test('$latex ne se réduit pas à une courbe', () {
        expect(estCourbeSeule(latex), isFalse);
      });
    }
  });
}
