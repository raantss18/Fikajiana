import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/rendu_signe.dart';

/// Les classes possibles d'un signe, de la plus probable à la moins, avec
/// leur probabilité (de 0 à 1). Une classe s'écrit en LaTeX, comme la
/// lecture au tracé l'écrit : `4`, `x`, `\times`, `-`, `\pi`.
typedef Classement = List<(String classe, double proba)>;

/// Ce qui dit quel signe dessinent quelques traits (ADR 0041).
///
/// [classer] prend son temps (un modèle, en fond) ; les trois autres
/// répondent sur-le-champ, avec les règles de doute de la lecture au tracé :
/// `null` quand le signe n'est pas sûr.
abstract class ClasseurSignes {
  const new();

  /// Les meilleures classes de [signe], au plus [combien]. [caseLigne] :
  /// la case de sa ligne ([caseDansLaLigne]), dont le modèle mesure le
  /// signe (contrat v1, ADR 0040).
  Future<Classement> classer(
    List<Trait> signe, {
    required Rect caseLigne,
    int combien = 3,
  });

  /// Le signe, ou plusieurs qu'on ne sait pas séparer (`2`, `z`, `Z`) avec
  /// leur distance (0 = parfait) ; `null` dans le doute. Voir
  /// [reconnaitreSigne].
  Map<String, double>? signe(List<Trait> signe, {required double hauteurLigne});

  /// Le chiffre, ou `null` dans le doute ([reconnaitreChiffre]).
  String? chiffre(List<Trait> signe);

  /// La capitale, ou `null` dans le doute ([reconnaitreCapitale]).
  String? capitale(List<Trait> signe);

  /// Un signe que la personne a déjà corrigé, ou qu'elle écrit toujours
  /// ainsi : il passe avant toute règle du tracé.
  String? impose(List<Trait> signe) => null;
}

/// Les gabarits $P de `signes.dart`, tels quels (ADR 0035, 0037).
class ClasseurGabarits extends ClasseurSignes {
  const new();

  /// La douceur du passage des distances aux probabilités : une distance
  /// de 0,15 de plus divise la probabilité par e.
  static const double _temperature = 0.15;

  @override
  Future<Classement> classer(
    List<Trait> signe, {
    required Rect caseLigne,
    int combien = 3,
  }) async => classerParGabarits(signe, combien: combien);

  @override
  Map<String, double>? signe(
    List<Trait> signe, {
    required double hauteurLigne,
  }) => reconnaitreSigne(dessinDe(signe));

  @override
  String? chiffre(List<Trait> signe) => reconnaitreChiffre(dessinDe(signe));

  @override
  String? capitale(List<Trait> signe) => reconnaitreCapitale(dessinDe(signe));

  /// Sur-le-champ : les distances des gabarits, rendues probabilités.
  static Classement classerParGabarits(List<Trait> signe, {int combien = 3}) {
    final distances = classerSignesDebug(dessinDe(signe));
    if (distances.isEmpty) return const [];
    final d0 = distances.first.$2;
    final poids = [
      for (final (_, d) in distances) math.exp(-(d - d0) / _temperature),
    ];
    final total = poids.fold<double>(0, (s, p) => s + p);
    return [
      for (var i = 0; i < math.min(combien, distances.length); i++)
        (distances[i].$1, poids[i] / total),
    ];
  }
}

/// Les points bruts des traits, comme les gabarits les comparent.
List<List<Offset>> dessinDe(List<Trait> traits) => [
  for (final t in traits) [for (final p in t.points) p.position],
];

/// La clé d'un signe : ses traits, et assez de leur forme pour qu'un même
/// numéro dans une autre feuille ne s'y confonde pas.
String cleDuSigne(List<Trait> traits) {
  final parts = [
    for (final t in traits)
      [
        t.id,
        t.points.length,
        t.points.first.x.round(),
        t.points.first.y.round(),
        t.points.last.x.round(),
        t.points.last.y.round(),
      ].join(','),
  ]..sort();
  return parts.join('|');
}

/// La case de [signe] parmi les [signes] de sa ligne (contrat v1).
Rect caseDansLaLigne(List<Trait> signe, List<List<Trait>> signes) =>
    caseDuSigne(dessinDe(signe), [
      for (final s in signes) ...dessinDe(s),
    ], hauteurMediane([for (final s in signes) dessinDe(s)]));

const _cleZone = #fikajianaClasseurSignes;

/// Le classeur de la lecture en cours ; les gabarits hors d'une lecture.
ClasseurSignes get classeurCourant =>
    Zone.current[_cleZone] as ClasseurSignes? ?? const ClasseurGabarits();

/// Lit avec [classeur] : la lecture au tracé et les structures le
/// demandent à [classeurCourant], même après un `await`.
R avecClasseur<R>(ClasseurSignes classeur, R Function() lecture) =>
    runZoned(lecture, zoneValues: {_cleZone: classeur});
