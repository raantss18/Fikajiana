import 'dart:async';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pix2Text : ce qu'il lit, quand on le laisse répondre.
class _Modele extends Lecteur {
  String reponse = '2+3=';

  /// Une réponse par lecture, dans l'ordre ; ensuite [reponse].
  final suivantes = <String>[];
  final lues = <int>[];
  Completer<void>? retenue;

  @override
  Future<String> lire(List<Trait> traits) async {
    lues.add(traits.first.id);
    final ici = suivantes.isEmpty ? reponse : suivantes.removeAt(0);
    await retenue?.future;
    return ici;
  }
}

class _Moteur implements Moteur {
  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      const ReponseGiac(exact: '5', latex: '5', approche: '5.0');

  @override
  void interrompre() {}
}

void _trait(Encre encre, double x, double y) {
  encre.commencer(PointEncre(x, y, 0.1));
  for (var i = 1; i < 6; i++) {
    encre.prolonger(PointEncre(x + i * 4, y, 0.1));
  }
  encre.terminer();
}

Future<void> _attendre(bool Function() fini) async {
  for (var i = 0; i < 200 && !fini(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Encre encre;
  late _Modele modele;
  late CalculFeuille calcul;
  // Le tracé lit `z+3=` en doutant de son premier signe.
  var trace = 'z+3=';

  setUp(() {
    trace = 'z+3=';
    encre = Encre();
    modele = _Modele();
    calcul = CalculFeuille(
      encre: encre,
      lecteur: modele,
      moteur: _Moteur(),
      pause: Duration.zero,
      calmeAvantConfirmation: Duration.zero,
      traceIndulgent: (traits) => (
        latex: trace,
        signes: const [],
        doute: true,
        surs: const ['+', '3', '='],
      ),
    );
  });

  tearDown(() => calcul.dispose());

  Future<BlocCalcul> ligne({double y = 0}) async {
    _trait(encre, 0, y);
    calcul.encreChangee();
    await _attendre(
      () => calcul.blocs.any(
        (b) => b.cadre.top >= y - 1 && b.etat == EtatBloc.fait,
      ),
    );
    return calcul.blocs.firstWhere((b) => b.cadre.top >= y - 1);
  }

  test('lue au tracé, affichée sans attendre le modèle, puis remplacée par '
      'une lecture plus plausible', () async {
    modele.retenue = Completer();
    final bloc = await ligne();
    // Montrée et calculée avant que le modèle réponde.
    expect(bloc.latex, 'z+3=');
    expect(bloc.etat, EtatBloc.fait);
    expect(bloc.aConfirmer, isTrue);
    modele.retenue!.complete();
    await _attendre(() => !bloc.aConfirmer);
    expect(bloc.latex, '2+3=');
    expect(bloc.aConfirmer, isFalse);
    expect(bloc.autresLectures, contains('z+3='));
  });

  test('confirmée : même lecture, la marque s’en va', () async {
    modele.reponse = 'z+3=';
    final bloc = await ligne();
    await _attendre(() => !bloc.aConfirmer);
    expect(bloc.latex, 'z+3=');
    expect(bloc.aConfirmer, isFalse);
  });

  test('jamais remplacée après une correction', () async {
    modele.retenue = Completer();
    final bloc = await ligne();
    await calcul.corriger(bloc, 'w+3=');
    modele.retenue!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.latex, 'w+3=');
    expect(bloc.aConfirmer, isFalse);
  });

  test('annulée si la ligne change pendant la lecture du modèle', () async {
    modele
      ..retenue = Completer()
      // La première réponse vaut pour l'ancienne ligne ; la seconde
      // confirme la nouvelle.
      ..suivantes.addAll(['2+3=', 'z+4=']);
    final bloc = await ligne();
    // Le modèle lit déjà cette ligne quand un trait la touche.
    await _attendre(() => modele.lues.isNotEmpty);
    trace = 'z+4=';
    _trait(encre, 8, 2);
    calcul.encreChangee();
    await _attendre(() => bloc.latex == 'z+4=');
    modele.retenue!.complete();
    await _attendre(() => modele.lues.length == 2 && !bloc.aConfirmer);
    // La réponse pour l'ancienne ligne n'a rien remplacé.
    expect(bloc.latex, 'z+4=');
  });

  test('une lecture qui contredit les signes sûrs ne remplace pas', () async {
    modele.reponse = '2-8=';
    final bloc = await ligne();
    await _attendre(() => !bloc.aConfirmer);
    expect(bloc.latex, 'z+3=');
    expect(bloc.autresLectures, contains('2-8='));
  });

  test('la plus récente d’abord, après une pause du stylet', () async {
    final lent = CalculFeuille(
      encre: encre,
      lecteur: modele,
      moteur: _Moteur(),
      pause: Duration.zero,
      calmeAvantConfirmation: const Duration(milliseconds: 400),
      traceIndulgent: (traits) => (
        latex: trace,
        signes: const [],
        doute: true,
        surs: const ['+', '3', '='],
      ),
    );
    addTearDown(lent.dispose);
    calcul.dispose();
    calcul = CalculFeuille(encre: Encre(), lecteur: modele, moteur: _Moteur());
    Future<BlocCalcul> ecrire(double y) async {
      _trait(encre, 0, y);
      lent.encreChangee();
      await _attendre(
        () => lent.blocs.any(
          (b) => b.cadre.top >= y - 1 && b.etat == EtatBloc.fait,
        ),
      );
      return lent.blocs.firstWhere((b) => b.cadre.top >= y - 1);
    }

    final a = await ecrire(0);
    final b = await ecrire(400);
    // Le stylet vient d'écrire : rien n'est encore relu.
    expect(modele.lues, isEmpty);
    await _attendre(() => !a.aConfirmer && !b.aConfirmer);
    expect(modele.lues, [b.traits.first, a.traits.first]);
  });

  test('accordeAuxSignesSurs', () {
    expect(accordeAuxSignesSurs(['+', '3', '='], '2+3='), isTrue);
    expect(accordeAuxSignesSurs(['+', '3', '='], '2-3='), isFalse);
    expect(accordeAuxSignesSurs([r'\times', '4'], r'3\times4'), isTrue);
  });

  test('la lecture indulgente n’invente rien de vide', () {
    expect(lireAuTraceDetaille(const [], indulgent: true), isNull);
  });
}
