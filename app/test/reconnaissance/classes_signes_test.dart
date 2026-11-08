import 'dart:io';

import 'package:fikajiana/reconnaissance/classes_signes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la table des classes suit collecte/classes.txt', () {
    final lignes = [
      for (final l in File('../collecte/classes.txt').readAsLinesSync())
        if (l.trim().isNotEmpty && !l.startsWith('#')) l.split('\t'),
    ];
    expect(classesSignes, [for (final l in lignes) (l[0], l[2])]);
    expect(idDeClasse(r'\times'), 'fois');
    expect(idDeClasse('-'), 'moins');
    expect(idDeClasse('§'), isNull);
  });
}
