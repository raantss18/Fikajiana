import 'dart:ui';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un résultat ne recouvre jamais l'encre ni le résultat d'une autre ligne
/// (Pad 7 d'Antsa, 2026-11-08 : `= 81/2` écrit sur `7⁹ = 40353607`, une
/// matrice 3×3 posée sous sa ligne touchant la suivante).
class _Lecteur extends Lecteur {
  String? Function(List<Trait> traits)? selon;

  @override
  Future<String> lire(List<Trait> traits) async => selon?.call(traits) ?? '';

  @override
  Future<List<String>> lirePlusieurs(List<Trait> traits) async => [
    await lire(traits),
  ];
}

class _Moteur implements Moteur {
  ReponseGiac Function(String entree) reponse = (_) =>
      const ReponseGiac(exact: '5', latex: '5', approche: '5.0');

  @override
  Future<ReponseGiac> calculer(String entree, {bool degres = false}) async =>
      reponse(entree);

  @override
  void interrompre() {}
}

const _matrice3 = r'\begin{pmatrix}1&2&3\\4&5&6\\7&8&10\end{pmatrix}';

void main() {
  late Encre encre;
  late _Lecteur lecteur;
  late _Moteur moteur;
  late CalculFeuille calcul;

  setUp(() {
    encre = Encre();
    lecteur = _Lecteur();
    moteur = _Moteur();
    calcul = CalculFeuille(
      encre: encre,
      lecteur: lecteur,
      moteur: moteur,
      pause: Duration.zero,
    );
  });

  tearDown(() => calcul.dispose());

  /// Un trait qui remplit [zone], de son coin haut gauche au coin bas droit.
  int trait(Rect zone) {
    encre.commencer(PointEncre(zone.left, zone.top, 0.1));
    for (var i = 1; i <= 5; i++) {
      encre.prolonger(
        PointEncre(
          zone.left + zone.width * i / 5,
          zone.top + zone.height * i / 5,
          0.1,
        ),
      );
    }
    encre.terminer();
    return encre.traits.last.id;
  }

  /// Une ligne déjà lue et calculée, comme dans un document enregistré.
  Map<String, dynamic> ligne(
    String cle,
    Rect zone,
    String latex, {
    String? resultat,
    String type = 'calcul',
    List<String> inconnues = const [],
    String etat = 'fait',
    String? inconnueMatrice,
  }) => {
    'cle': cle,
    'traits': [trait(zone)],
    'g': zone.left,
    'h': zone.top,
    'd': zone.right,
    'b': zone.bottom,
    'latex': latex,
    'etat': etat,
    'type': type,
    'inconnues': inconnues,
    'resultat': resultat,
    'im': ?inconnueMatrice,
  };

  /// Chaque résultat posé, avec sa ligne.
  Map<BlocCalcul, Rect> resultats() => {
    for (final b in calcul.blocs)
      if (b.ecriture(approcheVoulue: false, virgule: true) case final e?)
        b: e.cadre,
  };

  /// Aucun résultat ne touche l'encre ni le résultat d'une autre ligne, ni
  /// sa propre écriture, ni ne sort de la page.
  void sansChevauchement() {
    final poses = resultats();
    expect(poses, isNotEmpty);
    for (final MapEntry(key: bloc, value: zone) in poses.entries) {
      expect(
        zone.right,
        lessThanOrEqualTo(calcul.bordDroit),
        reason: '${bloc.latex} ($zone) sort de la page',
      );
      expect(
        zone.deflate(0.5).overlaps(bloc.cadre),
        isFalse,
        reason: '${bloc.latex} : sur sa propre écriture',
      );
      for (final autre in calcul.blocs) {
        if (identical(autre, bloc)) continue;
        expect(
          zone.overlaps(autre.cadre),
          isFalse,
          reason: '${bloc.latex} ($zone) sur ${autre.latex} (${autre.cadre})',
        );
        final sienne = poses[autre];
        if (sienne == null) continue;
        expect(
          zone.overlaps(sienne),
          isFalse,
          reason: '${bloc.latex} ($zone) sur le résultat de ${autre.latex}',
        );
      }
    }
  }

  group('placement sur des cadres donnés', () {
    test('deux résultats côte à côte ne se recouvrent pas', () {
      // Une matrice 3×3 à droite d'une ligne courte descend devant la
      // ligne d'en dessous : le résultat de celle-ci l'évite.
      calcul.chargerDocument([
        ligne(
          'a',
          const Rect.fromLTRB(20, 100, 120, 140),
          r'A^{-1}=',
          resultat: _matrice3,
          type: 'matrice',
        ),
        ligne(
          'b',
          const Rect.fromLTRB(20, 150, 110, 190),
          r'7^{9}=',
          resultat: '40353607',
        ),
      ]);
      sansChevauchement();
    });

    test('à l’ouverture, chaque résultat connaît ses voisins', () {
      // Le résultat de `9²/2` posé dessous (bord de page) ne descend pas
      // sur la ligne suivante : le placement attendait un premier
      // changement pour connaître les voisins.
      calcul
        ..bordDroit = 180
        ..chargerDocument([
          ligne(
            'a',
            const Rect.fromLTRB(20, 20, 150, 100),
            r'\frac{9^{2}}{2}=',
            resultat: r'\frac{81}{2}',
          ),
          ligne(
            'b',
            const Rect.fromLTRB(20, 140, 150, 180),
            r'7^{9}=',
            resultat: '40353607',
          ),
        ]);
      sansChevauchement();
    });

    test('une matrice 3×3 sous sa ligne ne touche pas la suivante', () {
      // `AX=B` : la solution va dessous ; la page s'arrête à droite.
      calcul
        ..bordDroit = 200
        ..chargerDocument([
          ligne(
            'a',
            const Rect.fromLTRB(20, 20, 180, 60),
            'AX=B',
            resultat: _matrice3,
            type: 'matrice',
            inconnueMatrice: 'X',
          ),
          ligne(
            'b',
            const Rect.fromLTRB(20, 125, 180, 165),
            '2+3=',
            resultat: '5',
          ),
        ]);
      final a = calcul.blocs.first;
      final zone = resultats()[a]!;
      expect(zone.top, greaterThan(a.cadre.bottom));
      sansChevauchement();
    });

    test('la place à droite libre : la matrice y va', () {
      calcul.chargerDocument([
        ligne(
          'a',
          const Rect.fromLTRB(20, 20, 180, 60),
          'AX=B',
          resultat: _matrice3,
          type: 'matrice',
          inconnueMatrice: 'X',
        ),
        ligne(
          'b',
          const Rect.fromLTRB(20, 80, 180, 120),
          '2+3=',
          resultat: '5',
        ),
      ]);
      final a = calcul.blocs.first;
      expect(resultats()[a]!.left, greaterThan(a.cadre.right));
      sansChevauchement();
    });

    test('une fraction haute sous sa ligne ne touche pas la suivante', () {
      calcul
        ..bordDroit = 175
        ..chargerDocument([
          ligne(
            'a',
            const Rect.fromLTRB(20, 20, 170, 100),
            r'\frac{1}{4}+\frac{1}{12}=',
            resultat: r'\frac{1}{3}',
          ),
          ligne(
            'b',
            const Rect.fromLTRB(20, 160, 170, 200),
            '2+3=',
            resultat: '5',
          ),
        ]);
      sansChevauchement();
    });

    test('un système à accolade et la ligne juste dessous', () {
      calcul.chargerDocument([
        ligne(
          'a',
          const Rect.fromLTRB(20, 20, 200, 110),
          r'\begin{cases}x+y=3\\x-y=1\end{cases}',
          resultat:
              r'\left(\begin{array}{cc}'
              '\n'
              r'2 & 1'
              '\n'
              r'\end{array}\right)',
          type: 'systeme',
          inconnues: const ['x', 'y'],
        ),
        ligne(
          'b',
          const Rect.fromLTRB(20, 125, 200, 165),
          '2+3=',
          resultat: '5',
        ),
      ]);
      sansChevauchement();
    });
  });

  test('feuille entière : relire la feuille ne pose rien sur une autre '
      'ligne', () async {
    // `9²/2 =` écrit en ligne : la barre `/` est un grand trait. Dessous,
    // `7⁹ =`, dont le `7` a été lu à part et n'a rien donné.
    final barre = const Rect.fromLTRB(60, 20, 80, 70);
    final neuf = const Rect.fromLTRB(20, 30, 50, 70);
    final egal1 = const Rect.fromLTRB(110, 40, 140, 52);
    final sept = const Rect.fromLTRB(40, 82, 64, 112);
    final suite = const Rect.fromLTRB(70, 76, 140, 112);
    calcul.chargerDocument([
      {
        ...ligne('a', neuf, r'\frac{9^{2}}{2}=', resultat: r'\frac{81}{2}'),
        'traits': [encre.traits.last.id, trait(barre), trait(egal1)],
        'd': egal1.right,
        'h': barre.top,
      },
      ligne('b', suite, '^{9}=', resultat: '9'),
      ligne('c', sept, '7', etat: 'nonCompris'),
    ]);
    final idSept = calcul.blocs.last.traits.single;
    lecteur.selon = (traits) => switch (traits.length) {
      3 => r'\frac{9^{2}}{2}=',
      2 => r'7^{9}=',
      _ => '',
    };
    moteur.reponse = (entree) => entree.contains('9')
        ? const ReponseGiac(exact: '81/2', latex: r'\frac{81}{2}', approche: '')
        : const ReponseGiac(exact: '5', latex: '5', approche: '');
    calcul.relireTout();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Le `7` rejoint sa ligne, pas la barre de la ligne du dessus.
    final haut = calcul.blocs.firstWhere((b) => b.traits.length == 3);
    expect(haut.traits, isNot(contains(idSept)));
    expect(
      calcul.blocs.any(
        (b) => b.traits.contains(idSept) && b.traits.length == 2,
      ),
      isTrue,
    );
    sansChevauchement();
  });
}
