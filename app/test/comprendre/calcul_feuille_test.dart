import 'dart:convert';
import 'dart:io';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/comprendre/stockage_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_test/flutter_test.dart';

class _Lecteur extends Lecteur {
  new(this.reponse);
  String reponse;
  bool absent = false;
  int lectures = 0;

  /// Une réponse selon les traits lus, comme le modèle sur le Pad 7.
  String? Function(List<Trait> traits)? selon;

  @override
  Future<String> lire(List<Trait> traits) async {
    lectures++;
    if (absent) throw const ModeleAbsent();
    return selon?.call(traits) ?? reponse;
  }

  /// Ce que répond la recherche en faisceau.
  List<String> plusieurs = const [];
  int doutes = 0;

  @override
  Future<List<String>> lirePlusieurs(List<Trait> traits) async {
    doutes++;
    return plusieurs.isEmpty ? [selon?.call(traits) ?? reponse] : plusieurs;
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

    // Antsa : « rajoute = si l'utilisateur a oublié ». Un calcul de nombres
    // donne sa valeur ; une expression en x, rien : on ne sait ce qu'on veut.
    test('2+3 sans = donne « = 5 » ; x+3 sans = n’affiche rien', () async {
      lecteur.reponse = '2+3';
      _trait(encre, 0, 0);
      calcul.encreChangee();
      await _attendre();
      expect(calcul.blocs.single.montreResultat, isTrue);
      expect(calcul.blocs.single.egalAjoute, isTrue);
      lecteur.reponse = 'x+3';
      calcul.relire(calcul.blocs.single);
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

  group('le = oublié', () {
    void barre(double x, double y) {
      encre.commencer(PointEncre(x, y, 0.1));
      for (var i = 1; i <= 5; i++) {
        encre.prolonger(PointEncre(x + i * 10.0, y + i * 10.0, 0.1));
      }
      encre.terminer();
    }

    const det = r'\det\begin{pmatrix}1&2\\3&4\end{pmatrix}';

    Future<BlocCalcul> lire(String latex, double x, double y) async {
      barre(x, y);
      lecteur.reponse = latex;
      calcul.encreChangee();
      await _attendre();
      return calcul.blocs.last;
    }

    EcritureResultat? ecrit(BlocCalcul b) =>
        b.ecriture(approcheVoulue: false, virgule: true);

    test('det sans = : l’app écrit « = 5 » à droite', () async {
      final b = await lire(det, 0, 0);
      expect(b.egalAjoute, isTrue);
      final e = ecrit(b)!;
      expect(e.cadre.left, greaterThan(b.cadre.right));
      final avecEgal = e.contours.length;
      calcul.dispose();
      encre = Encre();
      calcul = CalculFeuille(
        encre: encre,
        lecteur: lecteur,
        moteur: moteur,
        pause: Duration.zero,
      );
      final simple = await lire('2+3=', 0, 0);
      expect(simple.egalAjoute, isFalse);
      // Les deux traits du « = ».
      expect(ecrit(simple)!.contours.length, avecEgal - 2);
    });

    test('une équation garde sa solution dessous, sans =', () async {
      moteur.reponse = const ReponseGiac(
        exact: '[1]',
        latex: '1',
        approche: '[1.0]',
      );
      final b = await lire('x+1=2', 0, 0);
      expect(b.egalAjoute, isFalse);
      expect(ecrit(b)!.cadre.top, greaterThan(b.cadre.bottom));
    });

    test('la place à droite est prise : le résultat va dessous', () async {
      final b = await lire(det, 0, 0);
      await lire('7', 80, 40);
      expect(calcul.blocs, hasLength(2));
      final e = ecrit(b)!;
      expect(calcul.blocs.last.cadre.overlaps(e.cadre), isFalse);
      expect(e.cadre.top, greaterThan(b.cadre.bottom));
    });
  });

  group('un mot écrit à la main', () {
    List<Trait> charger(String nom) => [
      for (final t in jsonDecode(
        File('test/fixtures/pad7/$nom.json').readAsStringSync(),
      ) as List<dynamic>)
        Trait.depuisDocument(t as Map<String, dynamic>),
    ];

    Future<BlocCalcul> ecrire(
      String nom,
      String toutLu,
      String suiteLue,
    ) async {
      final traits = charger(nom);
      lecteur
        ..reponse = toutLu
        // Lue seule, la parenthèse et son contenu se lisent bien.
        ..selon = (lus) => lus.length < traits.length ? suiteLue : null;
      encre.chargerDocument([for (final t in traits) t.versDocument()]);
      calcul.encreChangee();
      await _attendre();
      return calcul.blocs.single;
    }

    // Vu sur le Pad 7, avec ces traits et cette lecture du modèle.
    test('premier(17) : reconnu, calculé, et montré à vérifier', () async {
      moteur.reponse = const ReponseGiac(
        exact: 'true',
        latex: 'true',
        approche: 'true',
      );
      final b = await ecrire(
        'premier_17',
        r'\wp ^ { \pi a m ^ { 2 } } \O \pi ( 1 7 )',
        '( 1 7 )',
      );
      expect(b.latex, r'\text{premier}( 1 7 )');
      expect(moteur.entrees.last, 'isprime(17)');
      expect(b.verite, isTrue);
      expect(b.lueParMorceaux, isTrue);
      expect(b.autresLectures, isNotEmpty);
      // « = vrai » s'écrit à la main, à droite (Antsa : l'égal manquait).
      final ecrit = b.ecriture(approcheVoulue: false, virgule: true)!;
      expect(ecrit.cadre.left, greaterThan(b.cadre.right));
      // Un résultat ne sort pas de l'écran : il passe dessous.
      calcul.bordDroit = b.cadre.right + 20;
      final dessous = b.ecriture(approcheVoulue: false, virgule: true)!;
      expect(dessous.cadre.top, greaterThan(b.cadre.bottom));
    });

    test('développer((2x-1)(x-4)) : reconnu et développé', () async {
      moteur.reponse = const ReponseGiac(
        exact: r'2\cdot x^{2}-9\cdot x+4',
        latex: r'2\cdot x^{2}-9\cdot x+4',
        approche: '2*x^2-9*x+4',
      );
      final b = await ecrire(
        'developper',
        r'\alpha \lim _ { \log _ { 1 } \alpha _ { 2 } } ( ( 2 x - \pi ) ( x - 4 ) )',
        '( ( 2 x - 1 ) ( x - 4 ) )',
      );
      expect(b.etat, EtatBloc.fait);
      // `2\cdot x^2` de Giac s'écrit `2x^2`.
      expect(
        b.texte(approcheVoulue: false, virgule: true),
        isNot(contains(r'\cdot')),
      );
      // `((` et `))` ne sont pas les barres d'une norme.
      expect(b.latex, isNot(contains(r'\|')));
      expect(moteur.entrees.last, startsWith('expand('));
      expect(b.egalAjoute, isTrue);
    });
  });

  group('la feuille d’Antsa du 7 novembre, relue juste', () {
    List<Trait> charger(String nom) => [
      for (final t in jsonDecode(
        File('test/fixtures/pad7/$nom.json').readAsStringSync(),
      ) as List<dynamic>)
        Trait.depuisDocument(t as Map<String, dynamic>),
    ];

    /// Ajoute les traits d'une ligne, avec ce que le modèle en a lu.
    Future<BlocCalcul> ecrire(String nom, String lu) async {
      final traits = charger(nom);
      final ids = {for (final t in traits) t.id};
      final avant = lecteur.selon;
      lecteur.selon = (lus) =>
          lus.every((t) => ids.contains(t.id)) ? lu : avant?.call(lus);
      encre.chargerDocument([
        for (final t in encre.traits) t.versDocument(),
        for (final t in traits) t.versDocument(),
      ]);
      calcul.encreChangee();
      await _attendre();
      return calcul.blocs.firstWhere((b) => b.traits.contains(traits.first.id));
    }

    test('30×8 sans = : « = 240 » s’écrit', () async {
      moteur.reponse = const ReponseGiac(
        exact: '240',
        latex: '240',
        approche: '240.0',
      );
      final b = await ecrire('trente_fois_8', r'3 0 \times 8');
      expect(b.montreResultat, isTrue);
      expect(b.egalAjoute, isTrue);
    });

    test('A(8;-1) et B(5;8) se lisent, puis AB est leur distance', () async {
      final a = await ecrire('point_A', 'A ( 8 i - 1 )');
      final b = await ecrire('point_B', r'\beta ( 5 , 0 )');
      expect(a.latex, 'A(8;-1)');
      expect(b.latex, 'B(5;8)');
      final ab = await ecrire('AB_egal', 'A B =');
      expect(ab.etat, EtatBloc.fait);
      // √((5-8)² + (8+1)²) = √90, pas A·B.
      expect(moteur.entrees.last, contains('sqrt'));
    });

    test('e^x = 7 lu « e^x - 7 » : se résout', () async {
      final b = await ecrire('e_x_egal_7', 'e ^ { x } - 7');
      expect(b.latex, contains('='));
      expect(b.estResolution, isTrue);
    });

    test('« longueur » à côté : une note, pas une erreur', () async {
      final b = await ecrire('longueur', r'\log _ { \theta _ { 0 } } \tan');
      expect(b.note, 'longueur');
      expect(b.etat, EtatBloc.fait);
    });

    test('« ⇒ plot » à côté de f’(x) = : la dérivée se trace', () async {
      await calcul.saisir('f(x)=x^2-2x+7', const Offset(0, -2000));
      moteur.reponse = const ReponseGiac(
        exact: r'2\cdot x-2',
        latex: r'2\cdot x-2',
        approche: '2*x-2',
      );
      await ecrire('derivee_f', "f'( x ) =");
      final plot = await ecrire('fleche_plot', r'\ni p ^ { 1 0 + }');
      expect(plot.latex, startsWith('y=2'));
      expect(plot.seTrace, isTrue);
    });
  });

  // Demande d'Antsa : déclarer A, puis det(A), A^{-1}, AX=B plus bas.
  group('une matrice déclarée sur la feuille', () {
    Future<BlocCalcul> taper(String latex, double y) async {
      await calcul.saisir(latex, Offset(0, y));
      return calcul.blocs.last;
    }

    test('det(A), A^{-1} et AX=B se servent de A et B', () async {
      await taper(r'A=\begin{pmatrix}1&2\\3&4\end{pmatrix}', 0);
      await taper(r'B=\begin{pmatrix}5\\6\end{pmatrix}', 100);
      await taper(r'\det(A)', 200);
      expect(moteur.entrees.last, 'det(([[1,2],[3,4]]))');
      await taper('A^{-1}', 300);
      expect(moteur.entrees.last, '(([[1,2],[3,4]]))^((-1))');
      moteur.reponse = const ReponseGiac(
        exact: r'\left(\begin{array}{c}-4 \\ \frac{9}{2}\end{array}\right)',
        latex: '',
        approche: '',
      );
      final x = await taper('AX=B', 400);
      expect(moteur.entrees.last, 'inv([[1,2],[3,4]])*([[5],[6]])');
      expect(x.inconnueMatrice, 'X');
      expect(x.estResolution, isTrue);
      expect(x.texte(approcheVoulue: false, virgule: true), startsWith('X='));
      // Et X sert ensuite.
      await taper('X^{2}', 500);
      expect(moteur.entrees.last, contains('inv([[1,2],[3,4]])'));
    });
  });

  group('une lecture douteuse en demande d’autres', () {
    Future<BlocCalcul> ecrire() async {
      _trait(encre, 0, 0);
      encre.terminer();
      calcul.encreChangee();
      await _attendre();
      return calcul.blocs.single;
    }

    test('une lecture sensée ne coûte rien de plus', () async {
      lecteur.reponse = 'x+1=2';
      await ecrire();
      expect(lecteur.doutes, 0);
    });

    test('la plus sensée est gardée, les autres sont proposées', () async {
      lecteur
        ..reponse = r'\begin{matrix}x=1\\x=\end{matrix}'
        ..plusieurs = ['x+1=2', 'x+4=2'];
      final b = await ecrire();
      expect(lecteur.doutes, 1);
      expect(b.latex, 'x+1=2');
      expect(b.autresLectures, ['x+4=2']);
    });
  });

  test('cercle(A;2) sous A se place, sans Giac', () async {
    await calcul.saisir('A(1;2)', Offset.zero);
    moteur.entrees.clear();
    await calcul.saisir('cercle(A;2)', const Offset(0, 100));
    final b = calcul.blocs.last;
    expect(b.etat, EtatBloc.fait);
    expect(b.commande?.genre, GenreCommande.cercleRayon);
    expect(b.aPlacer.single, isA<PointLu>());
    expect(moteur.entrees, isEmpty);
  });

  test('une commande sans ses points ne se devine pas', () async {
    await calcul.saisir('(AB)', Offset.zero);
    expect(calcul.blocs.last.etat, EtatBloc.nonCompris);
  });
}
