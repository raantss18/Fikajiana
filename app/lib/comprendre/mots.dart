import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/encre/encre.dart';

/// Les mots de commande écrits à la main : `développer(…)`, `premier(17)`.
///
/// Le modèle ne lit que des formules : en cursive, `premier` devient
/// `\wp^{\pi a m^{2}}` (Pad 7). Le mot se reconnaît alors à sa silhouette,
/// dans une liste courte : hampes (d, l), jambages (p, g), points et accents,
/// et sa longueur (ADR 0031).
class MotEcrit {
  const new(this.mot, this.suite);

  /// Les traits du mot, avant sa parenthèse.
  final List<Trait> mot;

  /// La parenthèse et ce qu'elle contient.
  final List<Trait> suite;
}

/// Les commandes qu'on écrit à la main, telles qu'elles s'affichent.
const motsDeCommande = [
  'développer',
  'factoriser',
  'simplifier',
  'décomposer',
  'premier',
  'moyenne',
  'médiane',
  'variance',
  'écart-type',
  'arrondi',
  'pgcd',
  'ppcm',
  'discriminant',
  'tangente',
];

Rect _c(List<Offset> s) => s
    .skip(1)
    .fold(s.first & Size.zero, (r, p) => r.expandToInclude(p & Size.zero));

List<Offset> _points(Trait t) => [for (final p in t.points) p.position];

/// Un mot devant une grande parenthèse ouvrante ; `null` s'il n'y en a pas,
/// ou si ce qui la précède est trop court pour être un mot (`f(`, `ln(`).
MotEcrit? separerMot(List<Trait> traits) {
  if (traits.length < 3) return null;
  final hauteur = cadreDuGroupe(traits).height;
  final parentheses = <(double, Trait)>[];
  for (final t in traits) {
    final s = _points(t);
    if (s.length < 3) continue;
    final c = _c(s);
    if (c.height < 0.5 * hauteur || c.width > 0.6 * c.height) continue;
    // Elle s'ouvre vers la droite : son milieu est à gauche de ses bouts.
    final bouts = math.min(s.first.dx, s.last.dx);
    if (s[s.length ~/ 2].dx < bouts - 0.1 * c.height) {
      parentheses.add((c.left, t));
    }
  }
  parentheses.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (gauche, parenthese) in parentheses) {
    final mot = [
      for (final t in traits)
        if (cadreDuGroupe([t]).center.dx < gauche) t,
    ];
    if (mot.isEmpty) continue;
    final largeur = cadreDuGroupe(mot).width;
    if (largeur < 1.5 * cadreDuGroupe([parenthese]).height) continue;
    return MotEcrit(mot, [
      for (final t in traits)
        if (!mot.contains(t)) t,
    ]);
  }
  return null;
}

/// Un repère de la silhouette : `A` hampe, `D` jambage, `.` point ou accent,
/// à sa place dans la largeur du mot, de 0 à 1.
typedef _Repere = (String, double);

List<Offset> _reechantillonner(List<Offset> s, double pas) {
  final sortie = [s.first];
  for (var i = 1; i < s.length; i++) {
    final (a, b) = (s[i - 1], s[i]);
    final n = math.max(1, ((b - a).distance / pas).floor());
    for (var k = 1; k <= n; k++) {
      sortie.add(Offset.lerp(a, b, k / n)!);
    }
  }
  return sortie;
}

/// Les repères observés, et la largeur du mot en hauteurs de `x`.
(List<_Repere>, double) _silhouette(List<Trait> mot) {
  final cadre = cadreDuGroupe(mot);
  final pas = math.max(cadre.height / 60, 0.5);
  final traces = [for (final t in mot) _reechantillonner(_points(t), pas)];
  final ys = [
    for (final s in traces)
      for (final p in s) p.dy,
  ]..sort();
  double quantile(double f) => ys[(f * (ys.length - 1)).round()];
  // La bande des lettres basses (a, e, m) : le gros de l'encre.
  final (haut, bas) = (quantile(0.25), quantile(0.75));
  final x = math.max(bas - haut, 1);
  double place(double dx) => (dx - cadre.left) / math.max(cadre.width, 1);

  final reperes = <_Repere>[];
  for (final s in traces) {
    final c = _c(s);
    if (math.max(c.width, c.height) < 1.4 * x && c.bottom < haut + 0.3 * x) {
      reperes.add(('.', place(c.center.dx)));
      continue;
    }
    for (final (genre, dehors) in [
      ('A', (Offset p) => p.dy < haut - 0.9 * x),
      ('D', (Offset p) => p.dy > bas + 0.9 * x),
    ]) {
      final suite = <double>[];
      void fermer() {
        if (suite.length > 2) {
          reperes.add((
            genre,
            place(suite.reduce((a, b) => a + b) / suite.length),
          ));
        }
        suite.clear();
      }

      for (final p in s) {
        if (dehors(p)) {
          suite.add(p.dx);
        } else {
          fermer();
        }
      }
      fermer();
    }
  }
  reperes.sort((a, b) => a.$2.compareTo(b.$2));
  final fondus = <_Repere>[];
  for (final r in reperes) {
    final dernier = fondus.lastOrNull;
    if (dernier != null && dernier.$1 == r.$1 && (r.$2 - dernier.$2) < 0.06) {
      continue;
    }
    fondus.add(r);
  }
  return (fondus, cadre.width / x);
}

/// La largeur d'une lettre, en lettres moyennes.
const _largeurs = {
  'm': 1.5,
  'w': 1.4,
  'i': 0.5,
  'l': 0.5,
  't': 0.6,
  'r': 0.7,
  'e': 0.8,
  'é': 0.8,
  'c': 0.8,
  's': 0.8,
  'f': 0.7,
  'j': 0.5,
  '-': 0.6,
};

/// Ses repères. En minuscule : qu'on oublie souvent (barre du t, accent).
const _reperesDesLettres = {
  'b': 'A',
  'd': 'A',
  'h': 'A',
  'k': 'A',
  'l': 'A',
  't': 'a',
  'f': 'AD',
  'g': 'D',
  'j': '.D',
  'p': 'D',
  'q': 'D',
  'y': 'D',
  'z': 'd',
  'i': '.',
  'é': ',',
  'è': ',',
  'ê': ',',
};

(List<_Repere>, double) _attendu(String mot) {
  final largeurs = [for (final c in mot.split('')) _largeurs[c] ?? 1.0];
  final total = largeurs.reduce((a, b) => a + b);
  final reperes = <_Repere>[];
  var x = 0.0;
  for (var i = 0; i < mot.length; i++) {
    for (final r in (_reperesDesLettres[mot[i]] ?? '').split('')) {
      if (r.isNotEmpty) reperes.add((r, (x + largeurs[i] / 2) / total));
    }
    x += largeurs[i];
  }
  return (reperes, total);
}

/// Alignement des repères : un repère attendu manquant coûte, sauf s'il est
/// de ceux qu'on oublie ; un repère en trop coûte aussi.
double _ecart(List<_Repere> vus, List<_Repere> attendus) {
  final (n, m) = (vus.length, attendus.length);
  const infini = 1e9;
  final d = List.generate(n + 1, (_) => List.filled(m + 1, infini));
  d[0][0] = 0;
  double manque(String r) => 'ad.,'.contains(r) ? 0.15 : 0.6;
  bool pareil(String vu, String attendu) =>
      vu == attendu.toUpperCase() || (vu == '.' && attendu == ',');
  for (var i = 0; i <= n; i++) {
    for (var j = 0; j <= m; j++) {
      final ici = d[i][j];
      if (ici >= infini) continue;
      if (i < n) d[i + 1][j] = math.min(d[i + 1][j], ici + 0.7);
      if (j < m) {
        d[i][j + 1] = math.min(d[i][j + 1], ici + manque(attendus[j].$1));
      }
      if (i < n && j < m && pareil(vus[i].$1, attendus[j].$1)) {
        final cout = ici + 2 * (vus[i].$2 - attendus[j].$2).abs();
        d[i + 1][j + 1] = math.min(d[i + 1][j + 1], cout);
      }
    }
  }
  return d[n][m];
}

String _sansTiret(String mot) => mot.replaceAll('-', '');

/// Les commandes, de la plus ressemblante à la moins : nom et écart.
List<(String, double)> classerMots(List<Trait> mot) {
  final (vus, largeur) = _silhouette(mot);
  return [
    for (final nom in motsDeCommande)
      () {
        final (attendus, lettres) = _attendu(_sansTiret(nom));
        final ecart = _ecart(vus, attendus);
        // Une lettre moyenne fait environ 0,85 hauteur de x.
        return (nom, ecart + 0.08 * (largeur - 0.85 * lettres).abs());
      }(),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
}

/// Le mot, s'il ne fait pas de doute : assez ressemblant, et nettement plus
/// que le suivant. Sinon `null`, et la feuille propose les premiers.
String? motSur(List<(String, double)> classes) {
  if (classes.length < 2) return null;
  final (premier, second) = (classes[0], classes[1]);
  if (premier.$2 > 1.2 || second.$2 - premier.$2 < 0.4) return null;
  return premier.$1;
}
