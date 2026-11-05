import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/stockage_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

class _Lecteur implements Lecteur {
  new(this.reponse);
  String reponse;
  bool absent = false;
  int lectures = 0;

  @override
  Future<String> lire(List<Trait> traits) async {
    lectures++;
    if (absent) throw const ModeleAbsent();
    return reponse;
  }
}

class _Moteur implements Moteur {
  ReponseGiac reponse = const ReponseGiac(
    exact: '5',
    latex: '5',
    approche: '5.0',
  );
  final entrees = <String>[];

  @override
  Future<ReponseGiac> calculer(String entree) async {
    entrees.add(entree);
    return reponse;
  }

  @override
  void interrompre() {}
}

void _trait(Encre encre, double x, double y) {
  encre.commencer(PointEncre(x, y, 0.1));
  for (var i = 1; i < 6; i++) {
    encre.prolonger(PointEncre(x + i * 4, y, 0.1));
  }
}

Future<void> _attendre() async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  late Encre encre;
  late _Lecteur lecteur;
  late _Moteur moteur;
  late CalculFeuille calcul;

  setUp(() {
    encre = Encre();
    lecteur = _Lecteur('2+3=');
    moteur = _Moteur();
    calcul = CalculFeuille(
      encre: encre,
      lecteur: lecteur,
      moteur: moteur,
      pause: Duration.zero,
    );
  });

  tearDown(() => calcul.dispose());

  test('traits proches : une expression ; éloignés : deux', () {
    _trait(encre, 0, 0);
    _trait(encre, 30, 0);
    _trait(encre, 0, 800);
    expect(grouperTraits(encre.traits), hasLength(2));
  });

  test('une forme nette ne se lit pas', () {
    _trait(encre, 0, 0);
    for (var i = 0; i < 30; i++) {
      encre.prolonger(PointEncre(i * 10.0, 0, 0.1));
    }
    encre.formerDernierTrait();
    expect(grouperTraits(encre.traits), isEmpty);
  });

  test('à la pause : lecture, traduction, résultat', () async {
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    final bloc = calcul.blocs.single;
    expect(bloc.latex, '2+3=');
    expect(moteur.entrees, ['2+3']);
    expect(bloc.etat, EtatBloc.fait);
    expect(bloc.resultat, '5');
    expect(bloc.approche, isNull);
    expect(bloc.type, TypeExpression.calcul);
  });

  test('une valeur non décimale reçoit son approché', () async {
    moteur.reponse = const ReponseGiac(
      exact: '1/3',
      latex: r'\frac{1}{3}',
      approche: '0.333333333333',
    );
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    expect(calcul.blocs.single.approche, '0.333333333333');
  });

  test('une lecture déjà faite n’est pas refaite', () async {
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    calcul.encreChangee();
    await _attendre();
    expect(lecteur.lectures, 1);
  });

  test('ajouter un trait relit l’expression', () async {
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    _trait(encre, 30, 0);
    calcul.encreChangee();
    await _attendre();
    expect(calcul.blocs, hasLength(1));
    expect(lecteur.lectures, 2);
  });

  test('gommer l’écriture retire le résultat', () async {
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    encre.effacer();
    calcul.encreChangee();
    await _attendre();
    expect(calcul.blocs, isEmpty);
  });

  test('un LaTeX incompris n’appelle pas le moteur', () async {
    lecteur.reponse = r'\frac{1}';
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    expect(calcul.blocs.single.etat, EtatBloc.nonCompris);
    expect(moteur.entrees, isEmpty);
  });

  test('corriger recalcule depuis le texte corrigé', () async {
    lecteur.reponse = r'\frac{1}';
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    await calcul.corriger(calcul.blocs.single, '1+1');
    expect(moteur.entrees, ['1+1']);
    expect(calcul.blocs.single.etat, EtatBloc.fait);
  });

  test('undef n’est jamais montré comme un résultat', () async {
    moteur.reponse = const ReponseGiac(
      exact: 'undef',
      latex: 'undef',
      approche: '',
    );
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    expect(calcul.blocs.single.etat, EtatBloc.sansResultat);
    expect(calcul.blocs.single.resultat, isNull);
  });

  test('1/0 : infinity sans signe n’est pas un résultat', () async {
    moteur.reponse = const ReponseGiac(
      exact: 'infinity',
      latex: r'\infty',
      approche: '',
    );
    await calcul.saisir('1/0', Offset.zero);
    expect(calcul.blocs.single.etat, EtatBloc.sansResultat);
  });

  test('une limite peut valoir +infini', () async {
    moteur.reponse = const ReponseGiac(
      exact: '+infinity',
      latex: r'+\infty',
      approche: '',
    );
    await calcul.saisir('x', Offset.zero);
    expect(calcul.blocs.single.etat, EtatBloc.fait);
  });

  test('une égalité sans inconnue répond vrai ou faux', () async {
    moteur.reponse = const ReponseGiac(
      exact: 'false',
      latex: r'\mbox{false}',
      approche: '',
    );
    await calcul.saisir('2+2=5', Offset.zero);
    expect(calcul.blocs.single.verite, isFalse);
    expect(calcul.blocs.single.resultat, isNull);
  });

  test('un calcul arrêté le dit', () async {
    moteur.reponse = ReponseGiac.analyser('ARRET');
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    expect(calcul.blocs.single.etat, EtatBloc.arrete);
  });

  test('sans modèle : on le dit, et on relit quand il arrive', () async {
    lecteur.absent = true;
    _trait(encre, 0, 0);
    calcul.encreChangee();
    await _attendre();
    expect(calcul.modeleManquant, isTrue);

    lecteur.absent = false;
    calcul.modeleDisponible();
    await _attendre();
    expect(calcul.modeleManquant, isFalse);
    expect(calcul.blocs.single.etat, EtatBloc.fait);
  });

  test('la saisie au clavier marche sans modèle', () async {
    lecteur.absent = true;
    await calcul.saisir('2+3=', Offset.zero);
    expect(calcul.blocs.single.etat, EtatBloc.fait);
    expect(lecteur.lectures, 0);
  });

  group('sauvegarde', () {
    late Directory dossier;
    late File fichier;

    setUp(() {
      dossier = Directory.systemTemp.createTempSync('fikajiana');
      fichier = File('${dossier.path}/feuille.json');
    });

    tearDown(() => dossier.deleteSync(recursive: true));

    test(
      'traits, stylo, forme et résultats reviennent à l’identique',
      () async {
        encre.commencer(const PointEncre(1, 2, 0.1, tempsMs: 5), stylo: 2);
        for (var i = 1; i <= 30; i++) {
          encre.prolonger(PointEncre(i * 10.0, 2, 0.1, tempsMs: 5.0 + i));
        }
        encre.formerDernierTrait();
        _trait(encre, 0, 900);
        calcul.encreChangee();
        await _attendre();

        StockageFeuille(fichier)
          ..programmer(
            () => {
              'traits': encre.versDocument(),
              'blocs': calcul.versDocument(),
            },
          )
          ..enregistrer();

        final document = StockageFeuille(fichier).charger()!;
        final relu = Encre()
          ..chargerDocument(document['traits'] as List<dynamic>);
        expect(relu.traits, hasLength(2));
        expect(relu.traits.first.stylo, 2);
        expect(relu.traits.first.forme, isNotNull);
        expect(relu.traits.first.id, encre.traits.first.id);
        expect(
          relu.traits.first.points.length,
          encre.traits.first.points.length,
        );
        expect(relu.traits.first.contour.getBounds().isEmpty, isFalse);

        final calcul2 = CalculFeuille(
          encre: relu,
          lecteur: lecteur,
          moteur: moteur,
        )..chargerDocument(document['blocs'] as List<dynamic>);
        expect(calcul2.blocs.single.resultat, '5');
        calcul2.dispose();
      },
    );

    test('un fichier abîmé est mis de côté, pas écrasé', () {
      fichier.writeAsStringSync('{pas du json');
      expect(StockageFeuille(fichier).charger(), isNull);
      expect(File('${fichier.path}.illisible').existsSync(), isTrue);
    });

    test('un autre format n’est pas chargé', () {
      fichier.writeAsStringSync(jsonEncode({'format': 99}));
      expect(StockageFeuille(fichier).charger(), isNull);
    });

    test('pas de sauvegarde : pas de fichier, pas d’erreur', () {
      expect(StockageFeuille(fichier).charger(), isNull);
      StockageFeuille(fichier).enregistrer();
      expect(fichier.existsSync(), isFalse);
    });
  });
}
