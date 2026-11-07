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
  bool derniersDegres = false;

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async {
    derniersDegres = degres;
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

  group('les fonctions de la feuille', () {
    test('une définition ne va pas à Giac', () async {
      await calcul.saisir('y=2x+1', Offset.zero);
      await calcul.saisir('f(x)=x^2', Offset.zero);
      expect(moteur.entrees, isEmpty);
      expect(calcul.blocs.every((b) => b.seTrace), isTrue);
    });
  });

  group('ce qui ne fait que se tracer', () {
    test('x^2+y^2=9 ne va pas à Giac', () async {
      await calcul.saisir('x^2+y^2=9', Offset.zero);
      expect(moteur.entrees, isEmpty);
      expect(calcul.blocs.single.seTrace, isTrue);
    });
  });

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

  group('un résultat ne s’efface pas', () {
    test('un nouveau calcul juste en dessous laisse le premier', () async {
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      final premier = calcul.blocs.single;
      expect(premier.resultat, '5');

      // Assez près pour que l'ancienne règle fusionne les deux.
      _trait(encre, 0, 30);
      calcul.encreChangee();
      await _attendre();
      expect(calcul.blocs, hasLength(2));
      expect(identical(calcul.blocs.first, premier), isTrue);
      expect(premier.resultat, '5');
      expect(lecteur.lectures, 2);
    });

    test('un calcul à droite d’un = ne le touche pas', () async {
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      _trait(encre, 60, 0);
      calcul.encreChangee();
      await _attendre();
      expect(calcul.blocs, hasLength(2));
    });

    test('un trait qui touche le bloc le fait relire', () async {
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      _trait(encre, 5, 2);
      calcul.encreChangee();
      await _attendre();
      expect(calcul.blocs, hasLength(1));
      expect(lecteur.lectures, 2);
    });

    test('sans =, le trait suivant sur la ligne continue le calcul', () async {
      lecteur.reponse = '2+3';
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      lecteur.reponse = '2+3=';
      _trait(encre, 40, 0);
      calcul.encreChangee();
      await _attendre();
      expect(calcul.blocs, hasLength(1));
      expect(calcul.blocs.single.finitParEgal, isTrue);
    });

    test('un trait prolongé après la pause est relu', () async {
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      encre.prolonger(const PointEncre(40, 0, 0.1));
      calcul.encreChangee();
      await _attendre();
      expect(lecteur.lectures, 2);
    });

    test('gommer un calcul laisse les autres', () async {
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      _trait(encre, 0, 400);
      calcul.encreChangee();
      await _attendre();
      expect(calcul.blocs, hasLength(2));
      encre.gommer(const Offset(0, 400), 5);
      calcul.encreChangee();
      await _attendre();
      expect(calcul.blocs.single.resultat, '5');
    });
  });

  group('équation', () {
    setUp(() {
      lecteur.reponse = 'x^2=2';
      moteur.reponse = const ReponseGiac(
        exact: 'list[-√2,√2]',
        latex: r'\{-\sqrt{2},\sqrt{2}\}',
        approche: 'list[-1.41421356237,1.41421356237]',
      );
    });

    test('la solution s’écrit sous l’équation, sans faux =', () async {
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      final bloc = calcul.blocs.single;
      expect(
        bloc.texte(approcheVoulue: false, virgule: true),
        r'x=-\sqrt{2}\,\mathrm{ou}\,x=\sqrt{2}',
      );
      final ecrit = bloc.ecriture(approcheVoulue: false, virgule: true);
      expect(ecrit, isNotNull);
      expect(ecrit!.cadre.top, greaterThan(bloc.cadre.bottom));
    });

    test('valeurs approchées, avec la virgule française', () async {
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      expect(
        calcul.blocs.single.texte(approcheVoulue: true, virgule: true),
        r'x=-1{,}4142136\,\mathrm{ou}\,x=1{,}4142136',
      );
    });

    test('les inconnues survivent à la sauvegarde', () async {
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      final relu = BlocCalcul.depuisJson(calcul.blocs.single.versJson());
      expect(relu.inconnues, ['x']);
    });
  });

  group('modes', () {
    test('exact ou approché, sans recalculer', () async {
      moteur.reponse = const ReponseGiac(
        exact: '1/3',
        latex: r'\frac{1}{3}',
        approche: '0.333333333333',
      );
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      final bloc = calcul.blocs.single;
      expect(bloc.texte(approcheVoulue: false, virgule: false), r'\frac{1}{3}');
      expect(bloc.texte(approcheVoulue: true, virgule: false), '0.33333333');
      expect(bloc.texte(approcheVoulue: true, virgule: true), '0{,}33333333');
      expect(moteur.entrees, hasLength(1));
    });

    test('ce que Giac rend tel quel se montre approché', () async {
      lecteur.reponse = r'\ln(5)=';
      moteur.reponse = const ReponseGiac(
        exact: 'ln(5)',
        latex: r'\ln\left(5\right)',
        approche: '1.60943791243',
      );
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      final bloc = calcul.blocs.single;
      expect(bloc.inchange, isTrue);
      expect(bloc.texte(approcheVoulue: false, virgule: false), '1.6094379');
    });

    test('changer de mode d’angle recalcule', () async {
      var degres = false;
      final avec = CalculFeuille(
        encre: encre,
        lecteur: lecteur,
        moteur: moteur,
        pause: Duration.zero,
        degres: () => degres,
      );
      await avec.saisir(r'\sin(30)=', Offset.zero);
      expect(moteur.derniersDegres, isFalse);
      degres = true;
      await avec.recalculer();
      expect(moteur.derniersDegres, isTrue);
      avec.dispose();
    });

    test('abréger un approché', () {
      expect(abregerApproche('1.60943791243'), '1.6094379');
      expect(abregerApproche('0.5'), '0.5');
      expect(abregerApproche('2.0'), '2');
      expect(abregerApproche('1e+20'), '1e+20');
    });

    test('une expression sans = n’affiche rien', () async {
      lecteur.reponse = '2+3';
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      expect(calcul.blocs.single.montreResultat, isFalse);
    });
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
    test('une feuille de la 0.1.0 garde ses traits et ses résultats', () {
      final bloc = BlocCalcul.depuisJson({
        'cle': '1,2,3',
        'g': 0,
        'h': 0,
        'd': 10,
        'b': 10,
        'latex': '2+3=',
        'etat': 'fait',
        'type': 'calcul',
        'resultat': '5',
      });
      expect(bloc.traits, {1, 2, 3});
      expect(bloc.resultat, '5');
      expect(bloc.estSaisie, isFalse);
    });

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

  group('la feuille retient ce qui est défini', () {
    Future<BlocCalcul> taper(String latex, double y) async {
      await calcul.saisir(latex, Offset(0, y));
      return calcul.blocs.last;
    }

    test("f'(x) calcule la dérivée de la ligne au-dessus", () async {
      await taper('f(x)=x+5', 0);
      await taper(r'f^{\prime}(x)', 100);
      expect(moteur.entrees.last, 'diff(x+5,x)');
      expect(calcul.blocs.last.demandeResultat, isTrue);
    });

    test('f(x)=0 se résout, et donne une solution', () async {
      await taper('f(x)=x+5', 0);
      final b = await taper('f(x)=0', 100);
      expect(moteur.entrees.last, 'solve((x+5)=0,x)');
      expect(b.type, TypeExpression.equation);
    });

    test('une définition plus bas ne compte pas', () async {
      await taper('f(x)=x+5', 500);
      final b = await taper('f(x)=0', 100);
      expect(b.type, TypeExpression.fonction);
    });

    test('changer la définition recalcule la ligne dessous', () async {
      final def = await taper('f(x)=x+5', 0);
      await taper('f(2)', 100);
      moteur.entrees.clear();
      await calcul.corriger(def, 'f(x)=x+7');
      await _attendre();
      expect(moteur.entrees, contains('((2)+7)'));
    });

    test('un point ne va pas à Giac', () async {
      moteur.entrees.clear();
      final b = await taper('A(1;2)', 0);
      expect(b.objet, isA<PointLu>());
      expect(b.etat, EtatBloc.fait);
      expect(moteur.entrees, isEmpty);
    });
  });

  test('un résultat ne s’écrit pas sur la ligne d’en dessous', () async {
    void barre(double y) {
      encre.commencer(PointEncre(0, y, 0.1));
      for (var i = 1; i <= 5; i++) {
        encre.prolonger(PointEncre(i * 10.0, y + i * 10.0, 0.1));
      }
      encre.terminer();
    }

    barre(0);
    lecteur.reponse = 'x+1=2';
    calcul.encreChangee();
    await _attendre();
    final haut = calcul.blocs.single;
    expect(haut.dessousLibre, isTrue);
    barre(97);
    lecteur.reponse = 'y+1=2';
    calcul.encreChangee();
    await _attendre();
    expect(calcul.blocs, hasLength(2));
    expect(haut.dessousLibre, isFalse);
  });
}
