import 'dart:async';

import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:flutter_test/flutter_test.dart';

const _sept = ReponseGiac(exact: '7', latex: '7', approche: '7');

void main() {
  test('une entrée démesurée est refusée avant Giac (audit, H1)', () {
    expect(entreeDemesuree('factorial(9999999)'), 'trop grand');
    expect(entreeDemesuree('9999999!'), 'trop grand');
    expect(entreeDemesuree('9^999999'), 'trop grand');
    expect(entreeDemesuree('2^(1000000000)'), 'trop grand');
    expect(entreeDemesuree('1+' * 20000), 'trop long');
    // Le courant passe.
    expect(entreeDemesuree('factorial(20)'), isNull);
    expect(entreeDemesuree('2^100'), isNull);
    expect(entreeDemesuree('x^2+123456*x'), isNull);
    expect(entreeDemesuree('1000000^2'), isNull);
  });

  test('refusée sans appeler Giac', () async {
    var appels = 0;
    final moteur = MoteurGiac(
      calcul: (e, {degres = false}) async {
        appels++;
        return _sept;
      },
      arret: () {},
    );
    final r = await moteur.calculer('factorial(9999999)');
    expect(r.erreur, 'trop grand');
    expect(appels, 0);
  });

  test('Giac qui ne s’arrête pas : calcul rendu arrêté, moteur occupé, '
      'puis libre quand Giac revient', () async {
    final coince = Completer<ReponseGiac>();
    var arrets = 0;
    var appels = 0;
    final moteur = MoteurGiac(
      delai: const Duration(milliseconds: 20),
      sursis: const Duration(milliseconds: 20),
      calcul: (e, {degres = false}) {
        appels++;
        return e == 'long' ? coince.future : Future.value(_sept);
      },
      arret: () => arrets++,
    );
    final r = await moteur.calculer('long');
    expect(r.arrete, isTrue);
    expect(arrets, 1);
    expect(moteur.occupe, isTrue);
    // Rien d'autre ne tourne en parallèle : le contexte Giac est unique.
    final suivant = await moteur.calculer('3+4');
    expect(suivant.erreur, 'moteur occupé');
    expect(appels, 1);
    // Giac revient enfin : le moteur reprend.
    coince.complete(_sept);
    await Future<void>.delayed(Duration.zero);
    expect(moteur.occupe, isFalse);
    expect((await moteur.calculer('3+4')).exact, '7');
  });

  test('un calcul qui finit à temps n’est ni arrêté ni bloquant', () async {
    final moteur = MoteurGiac(
      delai: const Duration(milliseconds: 50),
      calcul: (e, {degres = false}) async => _sept,
      arret: () => fail('pas d’arrêt'),
    );
    expect((await moteur.calculer('3+4')).exact, '7');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(moteur.occupe, isFalse);
  });
}
