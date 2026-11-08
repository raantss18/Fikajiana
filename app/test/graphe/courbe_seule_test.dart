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
      // Avec une accolade, comme Antsa les écrit (Pad 7), tels que le
      // modèle les lit.
      r'\left\{ \begin{matrix} x = \cos t \\ y = \tan ( t ) \end{matrix} \right.',
      r'\begin{cases}x=t+1\\y=t^{2}-1\end{cases}',
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
      // Un vrai système reste à résoudre.
      r'\begin{cases}x+y=3\\x-y=1\end{cases}',
      r'\left\{ \begin{matrix} x = t + 1 \\ y + 2 - 1 \end{matrix} \right.',
    ];
    for (final latex in calculs) {
      test('$latex ne se réduit pas à une courbe', () {
        expect(estCourbeSeule(latex), isFalse);
      });
    }
  });
}
