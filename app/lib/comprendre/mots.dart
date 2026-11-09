import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana_math/fikajiana_math.dart';

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
  'tracer',
  'plot',
  'développer',
  'factoriser',
  'résoudre',
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
  // `quotient` : trop proche de `premier` à la silhouette (mots_test) ;
  // il reste au clavier, et lu par le modèle.
  'reste',
  'division',
  'bezout',
  // Vague 3 : `ajustement`, `quartiles`, `correlation`, `covariance` non :
  // ajoutés ici, ils recoupaient `g(x) =` d'une feuille d'Antsa
  // (feuille_pad7_relue_test). Ils restent au clavier (ADR 0055).
  'tableau',
];

/// Les mesures d'une figure, devant leurs points : `angle(E;F;D)` (ADR 0047).
const motsDeMesure = ['angle', 'aire', 'perimetre'];

/// Tous les mots qu'on écrit devant une parenthèse : calcul, construction,
/// mesure. `angle` en cursive n'était pas lu (téléphone d'Antsa, 1.0.6).
final List<String> motsDevantParenthese = {
  ...motsDeCommande,
  ...motsDeGeometrie,
  ...motsDeMesure,
}.toList();

/// Les mots écrits seuls à côté d'une ligne : un ordre (`⇒ plot`) ou une
/// note (`longueur`), jamais un calcul (Pad 7).
const motsSeuls = [
  'plot',
  'tracer',
  'trace',
  'longueur',
  'distance',
  'aire',
  'norme',
  'donc',
  'solution',
];

/// Les mots qui demandent de tracer la ligne d'à côté.
const motsTracer = {'plot', 'tracer', 'trace'};

/// Un mot seul, sans parenthèse, une flèche `⇒` devant ou non ; `null` si ce
/// n'est pas un mot de [motsSeuls] sans doute possible.
String? reconnaitreMotSeul(List<Trait> traits) {
  if (traits.isEmpty) return null;
  final cadre = cadreDuGroupe(traits);
  final tries = traits.toList()
    ..sort(
      (a, b) => cadreDuGroupe([a]).left.compareTo(cadreDuGroupe([b]).left),
    );
  // `⇒` devant : des traits bas et courts, avant la première lettre.
  final fleche = tries.takeWhile((t) {
    final c = cadreDuGroupe([t]);
    return c.height <= 0.55 * cadre.height &&
        c.bottom < cadre.bottom - 0.1 * cadre.height;
  }).toList();
  final reste = fleche.length >= 2
      ? [
          for (final t in tries)
            if (!fleche.contains(t)) t,
        ]
      : tries;
  if (reste.isEmpty) return null;
  final mot = cadreDuGroupe(reste);
  // Un mot est plus large que haut ; et sans `=` ni `-`, sinon
  // c'est un calcul mal lu, à ne pas cacher sous une note.
  if (mot.width < mot.height || signesPlats(reste).isNotEmpty) {
    return null;
  }
  return motSur(classerMots(reste, lexique: motsSeuls), seuil: 2, avance: 0.6);
}

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
    // Un point ou un accent : petit, tout au-dessus des lettres basses.
    // L'accent d'Antsa, sur `résoudre`, fait presque 2 hauteurs de x (Pad 7).
    if (math.max(c.width, c.height) < 2.2 * x && c.bottom < haut + 0.3 * x) {
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
List<(String, double)> classerMots(
  List<Trait> mot, {
  List<String> lexique = motsDeCommande,
}) {
  final (vus, largeur) = _silhouette(mot);
  return [
    for (final nom in lexique)
      () {
        final (attendus, lettres) = _attendu(_sansTiret(nom));
        final ecart = _ecart(vus, attendus);
        // Une lettre moyenne fait environ 0,85 hauteur de x. La cursive
        // d'Antsa est bien plus large (`résoudre` : 16 hauteurs de x pour
        // 6) : la largeur départage, sans peser plus que les repères.
        return (nom, ecart + 0.05 * (largeur - 0.85 * lettres).abs());
      }(),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
}

/// Le mot, s'il ne fait pas de doute : assez ressemblant, et nettement plus
/// que le suivant. Sinon `null`, et la feuille propose les premiers.
/// Un mot seul, court (`plot`), ressemble moins : on accepte plus loin, mais
/// avec une avance plus nette sur le suivant.
String? motSur(
  List<(String, double)> classes, {
  double seuil = 1.2,
  double avance = 0.4,
}) {
  if (classes.length < 2) return null;
  final (premier, second) = (classes[0], classes[1]);
  if (premier.$2 > seuil || second.$2 - premier.$2 < avance) return null;
  return premier.$1;
}
