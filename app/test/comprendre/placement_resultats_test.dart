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
          'A^{-1}=',
          resultat: _matrice3,
          type: 'matrice',
        ),
        ligne(
          'b',
          const Rect.fromLTRB(20, 150, 110, 190),
          '7^{9}=',
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
            '7^{9}=',
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
              '2 & 1'
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
    const barre = Rect.fromLTRB(60, 20, 80, 70);
    const neuf = Rect.fromLTRB(20, 30, 50, 70);
    const egal1 = Rect.fromLTRB(110, 40, 140, 52);
    const sept = Rect.fromLTRB(40, 82, 64, 112);
    const suite = Rect.fromLTRB(70, 76, 140, 112);
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
      2 => '7^{9}=',
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

  group('le bouton de chaque ligne (ADR 0051)', () {
    // Un bouton de 48 dp, à la vue de départ (zoom 1).
    const taille = Size(48, 48);

    Map<BlocCalcul, Rect> places({double gauche = 0}) => calcul.placesJugement(
      taille: taille,
      approcheVoulue: false,
      virgule: true,
      gauche: gauche,
    );

    /// Les boutons ne couvrent ni l'encre, ni un résultat, ni d'autres
    /// boutons, et gardent leurs 48 dp.
    void libres(Map<BlocCalcul, Rect> places) {
      final poses = resultats();
      for (final MapEntry(key: bloc, value: zone) in places.entries) {
        expect(zone.height, greaterThanOrEqualTo(48));
        for (final autre in calcul.blocs) {
          expect(
            zone.overlaps(autre.cadre),
            isFalse,
            reason: '👍 de ${bloc.latex} ($zone) sur ${autre.latex}',
          );
          final r = poses[autre];
          if (r != null) {
            expect(
              zone.overlaps(r),
              isFalse,
              reason: '👍 de ${bloc.latex} sur le résultat de ${autre.latex}',
            );
          }
        }
        for (final MapEntry(key: b, value: z) in places.entries) {
          if (identical(b, bloc)) continue;
          expect(zone.overlaps(z), isFalse, reason: '👍 sur 👍');
        }
      }
    }

    test('les bornes d’une limite au bord gauche : pas de boutons sur '
        'l’encre d’une autre ligne', () {
      // Téléphone en paysage : `lim` puis `x → 3` lu à part, collés au bord
      // gauche ; dessous, une autre ligne. Avant : posés dessous sans
      // regarder, sur les bornes.
      calcul.chargerDocument([
        ligne(
          'lim',
          const Rect.fromLTRB(10, 100, 200, 150),
          r'\lim\frac{1}{x-3}=',
          resultat: r'\infty',
        ),
        ligne(
          'borne',
          const Rect.fromLTRB(10, 152, 90, 180),
          r'x\to3',
          etat: 'nonCompris',
        ),
        ligne(
          'apres',
          const Rect.fromLTRB(10, 240, 200, 280),
          '2+3=',
          resultat: '5',
        ),
      ]);
      final p = places();
      libres(p);
      expect(p, isNotEmpty);
    });

    test('deux lignes côte à côte : les boutons de droite ne vont pas sur '
        'la ligne de gauche', () {
      calcul.chargerDocument([
        ligne(
          'a',
          const Rect.fromLTRB(200, 100, 300, 140),
          '2+3=',
          resultat: '5',
        ),
        ligne(
          'b',
          const Rect.fromLTRB(400, 100, 500, 140),
          '4+4=',
          resultat: '8',
        ),
      ]);
      final p = places();
      libres(p);
      expect(p, hasLength(2));
    });

    test('un résultat passé dessous : les boutons vont à côté de lui', () {
      // Téléphone en portrait : la ligne touche le bord, `=33` dessous ; à
      // gauche, rien ; dessous, le résultat ; dessus, une autre ligne.
      calcul
        ..bordDroit = 400
        ..chargerDocument([
          ligne(
            'haut',
            const Rect.fromLTRB(16, 20, 390, 100),
            '2+3=',
            etat: 'nonCompris',
          ),
          ligne(
            'long',
            const Rect.fromLTRB(16, 104, 396, 144),
            '5+4+3+5+4+3+5+4=',
            resultat: '33',
          ),
        ]);
      final long = calcul.blocs.last;
      expect(resultats()[long]!.top, greaterThan(long.cadre.bottom));
      final p = places();
      libres(p);
      expect(p.keys.map((b) => b.cle), contains('long'));
    });

    test('lignes serrées sur un téléphone : un bouton chacune, jamais l’un '
        'sur l’autre ni sur l’encre (téléphone d’Antsa, 2026-11-08)', () {
      // « solve factor derive limit plot » passait sur les lignes dessous,
      // puis les pouces des lignes voisines se chevauchaient.
      calcul
        ..bordDroit = 364
        ..chargerDocument([
          ligne('a', const Rect.fromLTRB(20, 100, 300, 140), 'x^{2}-5x+6'),
          ligne('b', const Rect.fromLTRB(20, 144, 300, 184), 'x^{2}-1'),
          ligne(
            'c',
            const Rect.fromLTRB(20, 188, 300, 228),
            'y=2x+1',
            type: 'fonction',
          ),
          ligne(
            'd',
            const Rect.fromLTRB(20, 232, 300, 272),
            '2+3=',
            resultat: '5',
          ),
        ]);
      final p = places();
      libres(p);
      expect(p, hasLength(4));
      for (final zone in p.values) {
        expect(zone.width, 48);
        expect(zone.left, greaterThanOrEqualTo(0));
        expect(zone.right, lessThanOrEqualTo(364));
      }
    });

    test('sans place tout près, plus bas : chaque ligne a son bouton', () {
      // Une ligne entourée d'encre de tous côtés.
      calcul
        ..bordDroit = 400
        ..chargerDocument([
          ligne(
            'centre',
            const Rect.fromLTRB(120, 100, 280, 140),
            'x+1',
            etat: 'nonCompris',
          ),
          ligne('haut', const Rect.fromLTRB(0, 0, 400, 96), 'a'),
          ligne('bas', const Rect.fromLTRB(0, 144, 400, 300), 'b'),
          ligne('gauche', const Rect.fromLTRB(0, 98, 116, 142), 'c'),
          ligne('droite', const Rect.fromLTRB(284, 98, 400, 142), 'd'),
        ]);
      final p = places();
      libres(p);
      expect(p.keys.map((b) => b.cle), contains('centre'));
    });
  });

  test('téléphone en portrait : une ligne écrite après le réglage du bord '
      'garde son résultat dans l’écran', () async {
    // Le bord ne se donnait qu'aux lignes déjà là : `8×9−7×13 =` écrite
    // ensuite montrait `=-` puis sortait de l'écran.
    calcul.bordDroit = 384;
    trait(const Rect.fromLTRB(16, 100, 370, 140));
    lecteur.selon = (_) => r'8\times9-7\times13=';
    moteur.reponse = (_) =>
        const ReponseGiac(exact: '-19', latex: '-19', approche: '');
    calcul.encreChangee();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calcul.blocs.single.resultat, '-19');
    sansChevauchement();
  });
}
