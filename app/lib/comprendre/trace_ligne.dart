import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana_math/fikajiana_math.dart';

/// Une ligne lue sur son tracé seul, sans le modèle (ADR 0035, idée de
/// Mikajy) : chiffres, capitales, minuscules usuelles et `π`, `+ − = × ( )`,
/// exposants, `f'`, fractions, racines, virgule et point décimaux
/// (ADR 0037) ; `s o l r p q g h m w` et les noms de fonction `\sin`,
/// `\ln`… (ADR 0046). Quelques millisecondes au lieu de 300.
///
/// Rend `null` dès qu'un signe doute : le modèle lit alors la ligne entière.
/// Une erreur coûte plus qu'un détour par le modèle.
String? lireAuTrace(List<Trait> traits) => lireAuTraceDetaille(traits)?.latex;

/// Une ligne lue au tracé, et chacun de ses signes : ses traits et ce qu'on
/// y a lu, de gauche à droite (ADR 0041). `doute` : un signe au moins a été
/// tranché sans certitude (lecture indulgente, ADR 0050) ; `surs` sont les
/// signes lus sans doute, dans l'ordre.
typedef LectureTrace = ({
  String latex,
  List<(List<Trait>, String)> signes,
  bool doute,
  List<String> surs,
});

/// Les signes lus par la lecture en cours.
List<(List<Trait>, String)>? _lus;

/// La lecture en cours tranche les signes douteux au lieu de renoncer.
var _indulgent = false;

/// Les signes de la lecture en cours tranchés sans certitude.
Set<_Glyphe>? _douteux;

/// Comme [lireAuTrace], avec les signes lus : toucher l'un d'eux propose
/// d'autres lectures.
///
/// [indulgent] : un signe que seule sa hauteur départage (`0` ou `o`, `2`
/// ou `z`, `1` ou `l`) est tranché au plus probable au lieu de rendre
/// `null` ; la lecture rendue le dit alors (`doute`). Ce qui
/// ne se lit pas du tout (une structure, un signe inconnu) rend toujours
/// `null` (ADR 0050).
LectureTrace? lireAuTraceDetaille(
  List<Trait> traits, {
  bool indulgent = false,
}) {
  final avant = (_lus, _indulgent, _douteux);
  final lus = _lus = [];
  final douteux = _douteux = {};
  _indulgent = indulgent;
  try {
    final latex = _lireLigne(traits);
    if (latex == null) return null;
    lus.sort(
      (a, b) => cadreDuGroupe(a.$1).left.compareTo(cadreDuGroupe(b.$1).left),
    );
    final traitsDouteux = {for (final g in douteux) ...g.traits};
    return (
      latex: latex,
      signes: lus,
      doute: douteux.isNotEmpty,
      surs: [
        for (final (t, signe) in lus)
          if (!t.any(traitsDouteux.contains)) signe,
      ],
    );
  } finally {
    _lus = avant.$1;
    _indulgent = avant.$2;
    _douteux = avant.$3;
  }
}

/// En lecture indulgente, [g] prend [signe] et la ligne est marquée
/// douteuse ; sinon `false` : la lecture renonce.
bool _trancherSansCertitude(_Glyphe g, String? signe) {
  if (!_indulgent || signe == null) return false;
  g.signe = signe;
  _douteux?.add(g);
  return true;
}

/// Les signes d'une ligne, comme la lecture au tracé les découpe.
List<List<Trait>> signesDeLaLigne(List<Trait> traits) => [
  for (final (g, _) in _fondreArcs(
    _grouper([
      for (final t in traits)
        if (!_miette(t)) t,
    ]),
  ))
    g,
];

String? _lireLigne(List<Trait> traits) {
  final latex = _lire(traits, 2);
  if (latex == null) return null;
  // Rien qu'un signe : sans intérêt, et douteux.
  if (!RegExp('[0-9A-Za-z]').hasMatch(latex)) return null;
  try {
    analyserLatex(latex);
  } on ErreurLatex {
    return null;
  }
  return latex;
}

/// Lit [traits] : une fraction, une racine, sinon une ligne de signes
/// (au moins [minimum]).
String? _lire(List<Trait> traits, int minimum) {
  final nets = [
    for (final t in traits)
      if (!_miette(t)) t,
  ];
  if (nets.isEmpty) return null;
  final fraction = _fraction(traits);
  if (fraction != null) {
    final (gauche, haut, bas, droite) = fraction;
    final morceaux = [
      _lireOuVide(gauche),
      _lire(haut, 1),
      _lire(bas, 1),
      _lireOuVide(droite),
    ];
    if (morceaux.contains(null)) return null;
    return '${morceaux[0]}\\frac{${morceaux[1]}}{${morceaux[2]}}'
        '${morceaux[3]}';
  }
  final racine = _racine(traits);
  if (racine != null) {
    final (gauche, dedans, droite) = racine;
    final morceaux = [
      _lireOuVide(gauche),
      _lire(dedans, 1),
      _lireOuVide(droite),
    ];
    if (morceaux.contains(null)) return null;
    return '${morceaux[0]}\\sqrt{${morceaux[1]}}${morceaux[2]}';
  }
  return _ligne(nets, [
    for (final t in traits)
      if (_miette(t)) t,
  ], minimum);
}

String? _lireOuVide(List<Trait> traits) =>
    traits.every(_miette) ? '' : _lire(traits, 1);

/// Un point de stylet : moins de 5 sur 5.
bool _miette(Trait t) => _c(t).width < 5 && _c(t).height < 5;

/// Une barre de fraction : un plat droit avec, dans sa largeur, de l'encre
/// dessus et dessous, et rien qui la traverse. La plus large d'abord.
(List<Trait>, List<Trait>, List<Trait>, List<Trait>)? _fraction(
  List<Trait> traits,
) {
  final barres = [
    for (final t in traits)
      if (_plat(_c(t)) && _droit(t)) t,
  ]..sort((a, b) => _c(b).width.compareTo(_c(a).width));
  for (final barre in barres) {
    final b = _c(barre);
    final gauche = <Trait>[];
    final haut = <Trait>[];
    final bas = <Trait>[];
    final droite = <Trait>[];
    var traverse = false;
    final jeu = math.max(2, 0.05 * b.width);
    for (final t in traits) {
      if (identical(t, barre)) continue;
      final c = _c(t);
      if (c.center.dx < b.left) {
        gauche.add(t);
      } else if (c.center.dx > b.right) {
        droite.add(t);
      } else if (c.bottom <= b.center.dy + jeu) {
        haut.add(t);
      } else if (c.top >= b.center.dy - jeu) {
        bas.add(t);
      } else {
        traverse = true;
      }
    }
    bool corps(List<Trait> l) => l.any((t) => !_miette(t) && !_plat(_c(t)));
    if (traverse || !corps(haut) || !corps(bas)) continue;
    final ch = cadreDuGroupe(haut);
    final cb = cadreDuGroupe(bas);
    final marge = 0.2 * b.width;
    if (ch.left < b.left - marge ||
        ch.right > b.right + marge ||
        cb.left < b.left - marge ||
        cb.right > b.right + marge) {
      continue;
    }
    if (b.top - ch.bottom > 1.2 * ch.height ||
        cb.top - b.bottom > 1.2 * cb.height) {
      continue;
    }
    return (gauche, haut, bas, droite);
  }
  return null;
}

/// Une racine : un trait qui descend, remonte tout en haut, puis file à
/// droite (ou cette barre en un second trait), et de l'encre dessous.
(List<Trait>, List<Trait>, List<Trait>)? _racine(List<Trait> traits) {
  for (final t in traits) {
    if (_miette(t)) continue;
    final points = [for (final p in t.points) p.position];
    var zone = _formeRacine(points);
    final signe = [t];
    if (zone == null) {
      // La barre à part, qui part du haut du crochet.
      for (final barre in traits) {
        if (identical(barre, t) || !_plat(_c(barre)) || !_droit(barre)) {
          continue;
        }
        final cb = _c(barre);
        final hc = _c(t).height;
        if ((cb.left - points.last.dx).abs() > 0.25 * hc ||
            (cb.center.dy - points.last.dy).abs() > 0.2 * hc) {
          continue;
        }
        zone = _formeRacine([
          ...points,
          for (final p in barre.points) p.position,
        ]);
        if (zone != null) {
          signe.add(barre);
          break;
        }
      }
    }
    if (zone == null) continue;
    final cadre = cadreDuGroupe(signe);
    final gauche = <Trait>[];
    final dedans = <Trait>[];
    final droite = <Trait>[];
    for (final autre in traits) {
      if (signe.any((s) => identical(s, autre))) continue;
      final c = _c(autre);
      if (c.right <= cadre.left + 0.1 * cadre.width) {
        gauche.add(autre);
      } else if (c.left >= zone.right - 0.05 * zone.width) {
        droite.add(autre);
      } else if (c.center.dx > zone.left &&
          c.center.dx < zone.right &&
          c.center.dy > zone.top &&
          c.center.dy < zone.bottom + 0.1 * zone.height &&
          c.right <= zone.right + 0.15 * zone.width) {
        dedans.add(autre);
      } else {
        return null;
      }
    }
    if (dedans.every(_miette)) return null;
    return (gauche, dedans, droite);
  }
  return null;
}

/// La zone sous la barre d'un `√` dessiné par [s], ou `null`.
Rect? _formeRacine(List<Offset> s) {
  if (s.length < 4) return null;
  final c = _cadreDe(s);
  if (c.width < 10 || c.height < 10) return null;
  var creux = 0;
  for (var i = 1; i < s.length; i++) {
    if (s[i].dy > s[creux].dy) creux = i;
  }
  // On part de la gauche, plus haut que le creux.
  if (s.first.dx > s[creux].dx ||
      s[creux].dy - s.first.dy < 0.15 * c.height ||
      s.first.dx - c.left > 0.35 * c.width) {
    return null;
  }
  // On remonte tout en haut…
  var sommet = -1;
  for (var i = creux + 1; i < s.length; i++) {
    if (s[i].dy < c.top + 0.15 * c.height) {
      sommet = i;
      break;
    }
  }
  if (sommet < 0 || s[creux].dx > s[sommet].dx + 0.1 * c.width) return null;
  // … puis la barre, plate, vers la droite.
  if (s.last.dx - s[sommet].dx < 0.4 * c.width) return null;
  for (var i = sommet; i < s.length; i++) {
    if (s[i].dy > c.top + 0.25 * c.height) return null;
  }
  return Rect.fromLTRB(s[sommet].dx, c.top, c.right, c.bottom);
}

Rect _cadreDe(List<Offset> s) => s
    .skip(1)
    .fold(s.first & Size.zero, (r, p) => r.expandToInclude(p & Size.zero));

/// Un signe de la ligne et ce qu'on en sait.
class _Glyphe {
  new(this.traits, {this.arcs = false, this.miette = false, this.mot = false})
    : cadre = cadreDuGroupe(traits);

  final List<Trait> traits;
  final Rect cadre;

  /// Deux arcs dos à dos : un `x` (Pad 7).
  final bool arcs;

  /// Un point de stylet entre deux signes.
  final bool miette;

  /// Un nom de fonction, `\sin` (ADR 0046).
  final bool mot;

  /// Le signe décidé, ou `null`.
  String? signe;

  /// Les signes possibles quand le tracé seul ne tranche pas.
  Map<String, double> candidats = const {};

  /// Petit : un point ou une virgule, peut-être.
  bool petit = false;

  /// En exposant.
  bool haut = false;

  List<List<Offset>> get dessin => [
    for (final t in traits) [for (final p in t.points) p.position],
  ];
}

enum _Genre { chiffre, lettre, operateur, ouvrante, fermante, neutre }

_Genre _genre(_Glyphe g) {
  final s = g.signe;
  if (s == null) {
    // `1` ou `I`, `0` ou `O` : un chiffre ou une capitale, deux signes hauts.
    return _Genre.neutre;
  }
  if (_operateur(s)) return _Genre.operateur;
  if (s == '(') return _Genre.ouvrante;
  if (s == ')') return _Genre.fermante;
  if (RegExp('^[0-9]').hasMatch(s)) return _Genre.chiffre;
  if (RegExp(r'^([A-Za-z]|\\pi)$').hasMatch(s)) return _Genre.lettre;
  return _Genre.neutre;
}

/// Un chiffre peut-être : décidé, ou dans une famille qui en a un.
bool _chiffreProbable(_Glyphe? g) =>
    g != null &&
    (_genre(g) == _Genre.chiffre ||
        (g.signe == null && g.candidats.keys.any(_chiffre)));

bool _chiffre(String s) => RegExp(r'^[0-9]$').hasMatch(s);

bool _minusculeSimple(String s) => RegExp(r'^[a-z]$').hasMatch(s);

/// Minuscules sans hampe ni jambage : leur hauteur est celle de la ligne
/// basse.
const _basses = {
  'a',
  'c',
  'e',
  'm',
  'n',
  'o',
  'r',
  's',
  'u',
  'v',
  'w',
  'x',
  'z',
  r'\pi',
};

/// Minuscules à jambage : elles descendent sous la ligne (ADR 0046). Le `y`
/// garde sa règle (sa hauteur ne dit rien).
const _jambages = {'g', 'p', 'q'};

String? _ligne(List<Trait> nets, List<Trait> miettes, int minimum) {
  // Une barre de fraction qu'on n'a pas su lire : au modèle.
  for (final t in nets) {
    final c = _c(t);
    if (!_plat(c)) continue;
    var dessus = false;
    var dessous = false;
    for (final autre in nets) {
      final a = _c(autre);
      if (identical(autre, t) ||
          a.center.dx < c.left ||
          a.center.dx > c.right) {
        continue;
      }
      if (a.bottom <= c.top + 2) dessus = true;
      if (a.top >= c.bottom - 2) dessous = true;
    }
    if (dessus && dessous) return null;
  }
  final glyphes = [
    for (final (g, arcs) in _fondreArcs(_grouper(nets))) _Glyphe(g, arcs: arcs),
  ];
  if (glyphes.length < minimum) return null;
  final hauteurs = [
    for (final g in glyphes)
      if (g.cadre.height > 0.5 * g.cadre.width) g.cadre.height,
  ]..sort();
  if (hauteurs.isEmpty) {
    // Que des plats : un `-` ou un `=` seul.
    if (glyphes.length != 1) return null;
    final g = glyphes.single;
    return _classer(g, g.cadre.width) ? g.signe : null;
  }
  final hauteur = hauteurs[hauteurs.length ~/ 2];
  // Une structure qu'on ne lit pas ici : au modèle.
  for (final g in glyphes) {
    if (g.cadre.height > 2.6 * hauteur) return null;
  }
  // Les points de stylet entre deux signes ; ailleurs, on les oublie.
  for (final m in miettes) {
    final c = _c(m);
    for (var i = 0; i + 1 < glyphes.length; i++) {
      if (glyphes[i].cadre.right <= c.center.dx &&
          c.center.dx <= glyphes[i + 1].cadre.left) {
        glyphes.insert(i + 1, _Glyphe([m], miette: true));
        break;
      }
    }
  }
  final mots = _mots(glyphes, miettes, hauteur);
  if (mots == null) return null;
  if (!identical(mots, glyphes)) {
    glyphes
      ..clear()
      ..addAll(mots);
  }
  for (final g in glyphes) {
    if (!_classer(g, hauteur)) return null;
  }
  if (!_niveaux(glyphes)) return null;
  if (!_trancher(glyphes)) return null;
  if (!_auNiveau(glyphes)) return null;
  // Une fonction a son argument : `\sin(x)`, `\ln 2`, pas `\sin=`.
  for (var i = 0; i < glyphes.length; i++) {
    if (!glyphes[i].mot) continue;
    final suite = i + 1 < glyphes.length ? glyphes[i + 1] : null;
    final genre = suite == null ? null : _genre(suite);
    if (suite == null ||
        suite.haut ||
        genre == _Genre.fermante ||
        (genre == _Genre.operateur && suite.signe != '-')) {
      return null;
    }
  }
  // Trois lettres de suite hors des noms de fonction (ADR 0046) : un mot
  // qu'on ne connaît pas, c'est au modèle.
  var suite = 0;
  for (var i = 0; i < glyphes.length; i++) {
    final lettre = _genre(glyphes[i]) == _Genre.lettre;
    final memeNiveau = i > 0 && glyphes[i - 1].haut == glyphes[i].haut;
    suite = lettre ? (memeNiveau ? suite + 1 : 1) : 0;
    if (suite >= 3) return null;
  }
  return _ecrire(glyphes);
}

/// Ce que le tracé seul dit de [g] ; `false` s'il ne ressemble à rien.
bool _classer(_Glyphe g, double hauteur) {
  if (g.mot) return true;
  final c = g.cadre;
  if (g.miette || math.max(c.width, c.height) < 0.25 * hauteur) {
    g.petit = true;
    return true;
  }
  // Un signe que la personne a corrigé, ou qu'elle écrit toujours ainsi
  // (ADR 0041).
  final impose = classeurCourant.impose(g.traits);
  if (impose != null) {
    g.signe = impose;
    return true;
  }
  if (g.arcs) {
    g.signe = 'x';
    return true;
  }
  final traits = g.traits;
  if (traits.length == 1) {
    final t = traits.single;
    if (_plat(c) && _presqueDroit(t)) {
      g.signe = '-';
      return true;
    }
    // Un  seul : une fraction en ligne, que le modèle sait lire.
    if (_diagonale(t) == 1) return false;
    // Un signe très net d'abord : le `f` d'Antsa, le `5` du Pad 7 ont
    // l'allure d'une parenthèse.
    final net = classeurCourant.signe(g.traits, hauteurLigne: hauteur);
    if (net != null &&
        net.values.reduce(math.min) < 0.7 &&
        !net.containsKey('1')) {
      _poser(g, net);
      return true;
    }
    switch (_simple(t) ? genreParenthese(t, hauteur) : 0) {
      case 1:
        g.signe = '(';
        return true;
      case -1:
        g.signe = ')';
        return true;
    }
    // Petit et seul : une virgule peut-être, à voir avec ses voisins.
    if (c.height < 0.7 * hauteur && c.width < 0.5 * hauteur) g.petit = true;
  }
  if (traits.length == 2) {
    final (a, b) = (_c(traits[0]), _c(traits[1]));
    // `=` : deux plats l'un sur l'autre, même un peu courbes (Pad 7).
    if (_plat(a) && _plat(b)) {
      final commun = math.min(a.right, b.right) - math.max(a.left, b.left);
      final ecart = (a.center.dy - b.center.dy).abs();
      if (commun >= 0.5 * math.min(a.width, b.width) &&
          ecart >= 2 &&
          ecart <= math.max(a.width, b.width)) {
        g.signe = '=';
        return true;
      }
    }
    // `+` : un plat et un debout qui se croisent vers leurs milieux. Plus
    // haut, c'est un `t`.
    final (plat, debout) = _plat(a) && _debout(b)
        ? (a, b)
        : _plat(b) && _debout(a)
        ? (b, a)
        : (null, null);
    if (plat != null &&
        debout != null &&
        _droit(traits[0]) &&
        _droit(traits[1])) {
      final croise =
          debout.center.dx > plat.left + 0.2 * plat.width &&
          debout.center.dx < plat.right - 0.2 * plat.width &&
          plat.center.dy > debout.top + 0.33 * debout.height &&
          plat.center.dy < debout.bottom - 0.33 * debout.height &&
          debout.height < 1.6 * plat.width;
      if (croise) {
        g.signe = '+';
        return true;
      }
    }
    // `×` ou `x` : deux diagonales de même taille qui se croisent par leurs
    // milieux. Le contexte tranche.
    final (d1, d2) = (_diagonale(traits[0]), _diagonale(traits[1]));
    if (d1 * d2 == -1 &&
        a.overlaps(b) &&
        a.height < 2 * b.height &&
        b.height < 2 * a.height &&
        (a.center - b.center).distance < 0.3 * math.max(a.width, b.width)) {
      g.candidats = const {'x': 0, r'\times': 0};
      return true;
    }
  }
  final lu = classeurCourant.signe(g.traits, hauteurLigne: hauteur);
  if (lu == null) {
    // Un trait droit et debout : `1`, `I` ou `l` (un `l` cursif, un `r`
    // l'approchent), ou le `'` de `f'`, que la suite tranche.
    if (traits.length == 1 && _droit(traits.single) && _debout(c)) {
      g.candidats = const {'1': 0, 'I': 0};
      return true;
    }
    // Indulgente : le gabarit le plus proche, marqué douteux.
    if (!g.petit &&
        _trancherSansCertitude(g, signeLePlusProche(dessinDe(g.traits)))) {
      return true;
    }
    return g.petit;
  }
  _poser(g, lu);
  return true;
}

void _poser(_Glyphe g, Map<String, double> lu) {
  if (lu.length == 1) {
    g.signe = lu.keys.single;
  } else {
    g.candidats = {...lu, if (lu.containsKey('x')) r'\times': 0};
  }
}

/// Les exposants, comparés au signe de base qui les précède : plus haut
/// que sa moitié, et dépassant son sommet. `f'` : un petit trait droit en
/// haut à droite d'un `f`.
bool _niveaux(List<_Glyphe> glyphes) {
  _Glyphe? base;
  var ouvert = false;
  for (var i = 0; i < glyphes.length; i++) {
    final g = glyphes[i];
    final c = g.cadre;
    if (g.petit && g.signe == null && g.candidats.isEmpty) {
      g.haut = ouvert;
      continue;
    }
    if (g.mot) {
      g.haut = false;
      ouvert = false;
      base = null;
      continue;
    }
    final op = g.signe != null && _operateur(g.signe!);
    if (base == null) {
      g.haut = false;
      ouvert = false;
      base = op || g.signe == '(' ? null : g;
      continue;
    }
    final b = base.cadre;
    // Petit et bas : une virgule, un point, pas une base d'exposant.
    if (g.petit && c.top > b.top + 0.5 * b.height) {
      g.haut = false;
      ouvert = false;
      continue;
    }
    final courtEtDroit =
        g.traits.length == 1 &&
        _presqueDroit(g.traits.single) &&
        c.height < 0.5 * b.height;
    if (courtEtDroit &&
        c.bottom < b.top + 0.45 * b.height &&
        c.left >= b.right - 0.2 * b.width) {
      if (base.signe != 'f') return false;
      g
        ..signe = "'"
        ..candidats = const {}
        ..haut = false;
      ouvert = false;
      continue;
    }
    bool haut;
    if (op) {
      final enHaut = c.bottom < b.top + 0.3 * b.height;
      final suivant = i + 1 < glyphes.length ? glyphes[i + 1].cadre : null;
      // `2^{-1}` : un moins en haut, suivi d'un signe en haut.
      haut =
          enHaut &&
          (ouvert ||
              (g.signe == '-' &&
                  suivant != null &&
                  suivant.bottom < b.top + 0.45 * b.height));
    } else {
      haut =
          c.bottom < b.top + 0.45 * b.height && c.top < b.top - 0.15 * b.height;
    }
    if (haut && courtEtDroit) return false;
    g.haut = haut;
    ouvert = haut;
    if (!haut) base = op || g.signe == '(' ? null : g;
  }
  return true;
}

/// Les voisins de même niveau.
(_Glyphe?, _Glyphe?) _voisins(List<_Glyphe> glyphes, int i) {
  final g = glyphes[i];
  final avant = i > 0 && glyphes[i - 1].haut == g.haut ? glyphes[i - 1] : null;
  final apres = i + 1 < glyphes.length && glyphes[i + 1].haut == g.haut
      ? glyphes[i + 1]
      : null;
  return (avant, apres);
}

/// Les signes que le tracé ne départage pas, au contexte : virgules et
/// points entre deux chiffres, `2` ou `z`, `x` ou `×`, `c` ou `C`.
bool _trancher(List<_Glyphe> glyphes) {
  // Virgules et points décimaux.
  for (var i = 0; i < glyphes.length; i++) {
    final g = glyphes[i];
    if (!g.petit) continue;
    final (avant, apres) = _voisins(glyphes, i);
    final c = g.cadre;
    String? decimal;
    if (_chiffreProbable(avant) && _chiffreProbable(apres)) {
      final (a, b) = (avant!.cadre, apres!.cadre);
      final h = (a.height + b.height) / 2;
      final sommet = (a.top + b.top) / 2;
      final pied = (a.bottom + b.bottom) / 2;
      final entre =
          c.left >= a.right - 0.15 * h && c.right <= b.left + 0.15 * h;
      if (entre &&
          math.max(c.width, c.height) < 0.3 * h &&
          c.center.dy > sommet + 0.65 * h) {
        decimal = '.';
      } else if (entre &&
          g.traits.length == 1 &&
          c.height < 0.7 * h &&
          c.width < 0.5 * h &&
          c.top > sommet + 0.5 * h &&
          c.bottom > pied + 0.05 * h) {
        decimal = '{,}';
      }
    }
    if (decimal != null) {
      g
        ..signe = decimal
        ..candidats = const {};
    } else if (g.signe == null && g.candidats.isEmpty) {
      // Un point ailleurs : `2·3`, un `i` ? On doute, sauf la miette
      // perdue loin des chiffres.
      if (!g.miette || _chiffreProbable(avant) && _chiffreProbable(apres)) {
        return false;
      }
      g.signe = '';
    }
  }
  // Les signes hauts de la ligne : chiffres, capitales, `b d f k t`. Pas
  // un `2` qui pourrait être un `z`.
  final hauts = [
    for (final g in glyphes)
      if (!g.haut &&
          ((g.signe != null &&
                  (_genre(g) == _Genre.chiffre ||
                      RegExp(r'^[A-Z]$').hasMatch(g.signe!) ||
                      {'b', 'd', 'f', 'h', 'k', 't'}.contains(g.signe))) ||
              (g.signe == null &&
                  g.candidats.keys.any(_chiffre) &&
                  !g.candidats.keys.any(_basses.contains))))
        g.cadre.height,
  ]..sort();
  final reference = hauts.isEmpty ? null : hauts[hauts.length ~/ 2];
  // `x` ou `×` : `×` entre deux nombres.
  for (var i = 0; i < glyphes.length; i++) {
    final g = glyphes[i];
    if (g.signe != null || !g.candidats.containsKey(r'\times')) continue;
    final (avant, apres) = _voisins(glyphes, i);
    final fois =
        avant != null &&
        apres != null &&
        (_chiffreProbable(avant) || _genre(avant) == _Genre.fermante) &&
        (_chiffreProbable(apres) || _genre(apres) == _Genre.ouvrante);
    if (fois) {
      g.signe = r'\times';
    } else {
      g.candidats = {...g.candidats}..remove(r'\times');
    }
  }
  if (!_jambage(glyphes)) return false;
  // `5` ou `s`, `0` ou `o` : à la hauteur des signes hauts de la ligne, s'il
  // y en a (ADR 0046).
  if (reference != null) {
    for (var i = 0; i < glyphes.length; i++) {
      final g = glyphes[i];
      if (g.signe != null || g.haut) continue;
      final basse = g.candidats.keys.where(_basses.contains).firstOrNull;
      if (basse == null || !g.candidats.keys.any(_chiffre)) continue;
      // À côté d'un chiffre, un chiffre : `30`, même un `0` petit.
      final (avant, apres) = _voisins(glyphes, i);
      if ([avant, apres].any(_chiffreProbable)) {
        continue;
      }
      final rapport = g.cadre.height / reference;
      if (rapport <= 0.75) {
        g.signe = basse;
      } else if (rapport >= 0.9) {
        g.candidats = {
          for (final MapEntry(:key, :value) in g.candidats.entries)
            if (!_minusculeSimple(key)) key: value,
        };
      } else if (!_trancherSansCertitude(
        g,
        g.candidats.keys.where(_chiffre).firstOrNull,
      )) {
        return false;
      }
    }
  }
  // Minuscule ou capitale, à la hauteur des signes hauts de la ligne.
  for (final g in glyphes) {
    if (g.signe != null || g.candidats.keys.any(_chiffre)) continue;
    final minuscule = g.candidats.keys.where(_minusculeSimple).firstOrNull;
    final capitale = g.candidats.keys
        .where((s) => RegExp('^[A-Z]').hasMatch(s))
        .firstOrNull;
    if (minuscule == null) return false;
    if (reference == null || g.haut || minuscule == 'y') {
      // Le `y` descend sous la ligne : sa hauteur ne dit rien.
      g.signe = minuscule;
      continue;
    }
    final rapport = g.cadre.height / reference;
    if (rapport <= 0.75) {
      g.signe = minuscule;
    } else if (rapport >= 0.9 && capitale != null) {
      g.signe = capitale;
    } else if (!_trancherSansCertitude(g, minuscule)) {
      return false;
    }
  }
  // Chiffre ou lettre : `2x` (le `2` plus haut que le `x`) contre `xz`.
  // D'abord à côté d'une lettre décidée, de proche en proche ; sans
  // lettre voisine, un chiffre. Un `1` ne fait pas d'un `I` voisin un `1`.
  for (var change = true; change;) {
    change = false;
    for (var i = 0; i < glyphes.length; i++) {
      final g = glyphes[i];
      if (g.signe != null) continue;
      final chiffre = g.candidats.keys.where(_chiffre).firstOrNull;
      if (chiffre == null) continue;
      final (avant, apres) = _voisins(glyphes, i);
      final lettres = [
        for (final v in [avant, apres])
          if (v != null && _genre(v) == _Genre.lettre) v,
      ];
      if (lettres.isEmpty) continue;
      change = true;
      final chiffres = [
        avant,
        apres,
      ].any((v) => v != null && _genre(v) == _Genre.chiffre);
      if (chiffres) {
        g.signe = chiffre;
        continue;
      }
      final basse = lettres.where((v) => _basses.contains(v.signe)).firstOrNull;
      if (basse == null) {
        if (_trancherSansCertitude(g, chiffre)) continue;
        return false;
      }
      final rapport = g.cadre.height / basse.cadre.height;
      // Une minuscule basse seulement : un `l` est aussi haut qu'un `1`.
      final minuscule = g.candidats.keys.where(_basses.contains).firstOrNull;
      if (rapport >= 1.25) {
        g.signe = chiffre;
      } else if (rapport <= 1.15 && minuscule != null) {
        g.signe = minuscule;
      } else if (!_trancherSansCertitude(g, chiffre)) {
        return false;
      }
    }
  }
  for (final g in glyphes) {
    if (g.signe != null) continue;
    final chiffre = g.candidats.keys.where(_chiffre).firstOrNull;
    if (chiffre != null) g.signe = chiffre;
  }
  return glyphes.every((g) => g.signe != null);
}

/// `9` ou `g`, `p` ou `P` : le jambage descend sous la ligne des autres
/// signes. Une minuscule à jambage qui n'y descend pas, ou une ligne sans
/// autre signe pour la situer : on doute (ADR 0046).
bool _jambage(List<_Glyphe> glyphes) {
  bool aJambage(_Glyphe g) =>
      _jambages.contains(g.signe) ||
      (g.signe == null && g.candidats.keys.any(_jambages.contains));
  if (!glyphes.any(aJambage)) return true;
  final pieds = <double>[];
  final tailles = <double>[];
  for (final g in glyphes) {
    if (g.haut || g.petit || aJambage(g)) continue;
    final genre = _genre(g);
    final candidat =
        g.signe == null &&
        g.candidats.isNotEmpty &&
        !g.candidats.keys.any((s) => s == 'y' || s == 'Y');
    if (genre != _Genre.chiffre && genre != _Genre.lettre && !candidat) {
      continue;
    }
    if (g.signe == 'y' || g.signe == 'f') continue;
    pieds.add(g.cadre.bottom);
    tailles.add(g.cadre.height);
  }
  if (pieds.isEmpty) return false;
  pieds.sort();
  tailles.sort();
  final ligne = pieds[pieds.length ~/ 2];
  final taille = tailles[tailles.length ~/ 2];
  for (final g in glyphes) {
    if (g.haut || !aJambage(g)) continue;
    final descend = g.cadre.bottom > ligne + 0.25 * taille;
    if (g.signe != null) {
      if (!descend) return false;
      continue;
    }
    final jambage = g.candidats.keys.firstWhere(_jambages.contains);
    if (descend) {
      g
        ..signe = jambage
        ..candidats = const {};
    } else {
      g.candidats = {
        for (final MapEntry(:key, :value) in g.candidats.entries)
          if (!_jambages.contains(key)) key: value,
      };
      if (g.candidats.isEmpty) return false;
      if (g.candidats.length == 1) g.signe = g.candidats.keys.single;
    }
  }
  return true;
}

/// Un signe qui tombe sous la ligne (le bas d'un `;`, un indice) : au
/// modèle. Seuls `y`, `f`, `g`, `p`, `q`, la virgule et les parenthèses y
/// descendent.
bool _auNiveau(List<_Glyphe> glyphes) {
  final pieds = <double>[];
  final tailles = <double>[];
  for (final g in glyphes) {
    final genre = _genre(g);
    if (g.haut || (genre != _Genre.chiffre && genre != _Genre.lettre)) {
      continue;
    }
    if (g.signe == 'y' || g.signe == 'f' || _jambages.contains(g.signe)) {
      continue;
    }
    pieds.add(g.cadre.bottom);
    tailles.add(g.cadre.height);
  }
  if (pieds.length < 2) return true;
  pieds.sort();
  tailles.sort();
  final ligne = pieds[pieds.length ~/ 2];
  final taille = tailles.last;
  for (final g in glyphes) {
    final genre = _genre(g);
    if (g.haut || (genre != _Genre.chiffre && genre != _Genre.lettre)) {
      continue;
    }
    if (g.signe == 'y' || g.signe == 'f' || _jambages.contains(g.signe)) {
      continue;
    }
    if (g.cadre.center.dy > ligne - 0.1 * taille) return false;
    if (g.cadre.bottom > ligne + 0.25 * taille) return false;
  }
  return true;
}

String _ecrire(List<_Glyphe> glyphes) {
  final sortie = StringBuffer();
  var exposant = false;
  var apresMot = false;
  for (final g in glyphes) {
    if (g.haut && !exposant) {
      sortie.write('^{');
      exposant = true;
    } else if (!g.haut && exposant) {
      sortie.write('}');
      exposant = false;
    }
    final signe = g.signe!;
    if (!g.miette) _lus?.add((g.traits, signe));
    // `\pi x`, `\times x` : une commande ne se colle pas à une lettre.
    if (RegExp(r'\\[a-z]+$').hasMatch(sortie.toString()) &&
        RegExp(apresMot ? '^[A-Za-z0-9]' : '^[A-Za-z]').hasMatch(signe)) {
      sortie.write(' ');
    }
    sortie.write(signe);
    apresMot = g.mot;
  }
  if (exposant) sortie.write('}');
  return sortie.toString();
}

/// Les fonctions écrites en toutes lettres, lues au tracé (ADR 0046).
const Map<String, String> fonctionsEcrites = {
  'sin': r'\sin',
  'cos': r'\cos',
  'tan': r'\tan',
  'ln': r'\ln',
  'log': r'\log',
  'exp': r'\exp',
  'lim': r'\lim',
  'det': r'\det',
};

/// Au-delà, une lecture ne compte pas parmi les 3 meilleures d'un signe.
const double _seuilMot = 1.6;

/// Les lettres que [g] peut être dans un mot : ses 3 meilleures lectures,
/// comme Mikajy, et leurs jumelles (`1` pour `l`, `0` pour `o`, `5` pour
/// `s`). Avec un point au-dessus, seulement `i`.
Set<String> _lettresPossibles(_Glyphe g, {required bool point}) {
  final lettres = <String>{};
  final impose = classeurCourant.impose(g.traits);
  final classes = [
    ?impose,
    if (g.arcs) 'x',
    for (final (classe, d) in classerSignesDebug(g.dessin).take(3))
      if (d <= _seuilMot) classe,
  ];
  for (final classe in classes) {
    for (final s in famillesDeSignes.firstWhere(
      (f) => f.contains(classe),
      orElse: () => {classe},
    )) {
      if (_minusculeSimple(s)) lettres.add(s);
    }
    if (classe == r'\times') lettres.add('x');
  }
  if (point) {
    return lettres.contains('l') || lettres.contains('1') ? {'i'} : {};
  }
  // Un `i` sans son point : un `l`, ou rien.
  return lettres..remove('i');
}

/// Remplace dans [glyphes] chaque nom de fonction ([fonctionsEcrites]) par
/// un seul signe. Un mot n'est pris que si chacune de ses lettres est parmi
/// les 3 meilleures lectures de son signe, et qu'aucun autre ne convient ;
/// `null` quand deux mots se disputent les mêmes signes.
List<_Glyphe>? _mots(
  List<_Glyphe> glyphes,
  List<Trait> miettes,
  double hauteur,
) {
  // Le point d'un `i` : petit, au-dessus d'un signe voisin.
  final points = <int, List<Trait>>{};
  final pointsDe = <int, List<int>>{};
  final pris = <int>{};
  bool dessus(Rect point, Rect c) =>
      point.center.dx >= c.left - 0.3 * hauteur &&
      point.center.dx <= c.right + 0.3 * hauteur &&
      point.bottom <= c.top + 0.1 * c.height &&
      c.top - point.bottom < 0.8 * hauteur;
  for (var i = 0; i < glyphes.length; i++) {
    final g = glyphes[i];
    if (math.max(g.cadre.width, g.cadre.height) > 0.4 * hauteur) continue;
    for (final j in [i - 1, i + 1]) {
      if (j < 0 || j >= glyphes.length || glyphes[j].miette) continue;
      if (dessus(g.cadre, glyphes[j].cadre)) {
        (points[j] ??= []).addAll(g.traits);
        (pointsDe[j] ??= []).add(i);
        pris.add(i);
        break;
      }
    }
  }
  final restes = [
    for (var i = 0; i < glyphes.length; i++)
      if (!pris.contains(i)) i,
  ];
  for (final m in miettes) {
    if (glyphes.any((g) => g.traits.any((t) => identical(t, m)))) continue;
    for (final j in restes) {
      if (!glyphes[j].miette && dessus(_c(m), glyphes[j].cadre)) {
        (points[j] ??= []).add(m);
        break;
      }
    }
  }
  final lettres = {
    for (final j in restes)
      if (!glyphes[j].miette)
        j: _lettresPossibles(glyphes[j], point: points.containsKey(j)),
  };
  final sortie = <_Glyphe>[];
  var trouve = false;
  for (var k = 0; k < restes.length; k++) {
    final debut = restes[k];
    final candidats = <String>[];
    for (final mot in fonctionsEcrites.keys) {
      if (k + mot.length > restes.length) continue;
      var ok = true;
      for (var n = 0; n < mot.length && ok; n++) {
        final j = restes[k + n];
        final possibles = lettres[j];
        ok = possibles != null && possibles.contains(mot[n]);
        // Des lettres serrées, de même taille.
        if (ok && n > 0) {
          final avant = glyphes[restes[k + n - 1]].cadre;
          final c = glyphes[j].cadre;
          ok =
              c.left - avant.right < 0.8 * hauteur &&
              c.height < 2.6 * hauteur &&
              (c.center.dy - avant.center.dy).abs() < 0.8 * hauteur;
        }
      }
      if (ok) candidats.add(mot);
    }
    if (candidats.length > 1) return null;
    // Un mot collé à une lettre de plus : un autre mot (`s` puis `ln`), au
    // modèle.
    if (candidats.isNotEmpty && k > 0) {
      final avant = restes[k - 1];
      final ecart = glyphes[debut].cadre.left - glyphes[avant].cadre.right;
      if ((lettres[avant]?.isNotEmpty ?? false) && ecart < 0.8 * hauteur) {
        return null;
      }
    }
    if (candidats.isEmpty) {
      // Le signe, et ses points s'il en a : ce n'était pas un `i` de mot.
      sortie.addAll([
        for (final i in [debut, ...?pointsDe[debut]]..sort()) glyphes[i],
      ]);
      continue;
    }
    final mot = candidats.single;
    final traits = [
      for (var n = 0; n < mot.length; n++) ...[
        ...glyphes[restes[k + n]].traits,
        ...?points[restes[k + n]],
      ],
    ];
    sortie.add(_Glyphe(traits, mot: true)..signe = fonctionsEcrites[mot]);
    trouve = true;
    k += mot.length - 1;
  }
  // Sans mot, les points restent ce qu'ils étaient.
  return trouve ? sortie : glyphes;
}

/// Les signes, de gauche à droite. Un plat ne rejoint un signe que s'il le
/// croise (`+`, `4`, `7`), le coiffe (`T`, `π`) ou double un autre plat
/// (`=`) : un `=` collé au `8` d'avant reste un `=`. Un trait qui ne
/// partage pas la hauteur d'un signe (l'exposant de `e^x`) ou une
/// parenthèse bien plus haute que lui restent à part.
List<List<Trait>> _grouper(List<Trait> traits) {
  final tries = traits.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  final groupes = <List<Trait>>[];
  for (final t in tries) {
    final c = _c(t);
    List<Trait>? hote;
    for (final g in groupes.reversed) {
      final cg = cadreDuGroupe(g);
      if (c.left > cg.right && !accrocheAUneHampe(t, g)) continue;
      if (_plat(c)) {
        final platsSeuls = g.every((x) => _plat(_c(x)));
        final commun = math.min(c.right, cg.right) - math.max(c.left, cg.left);
        if (platsSeuls && commun >= 0.5 * math.min(c.width, cg.width)) {
          hote = g;
        } else if (!platsSeuls &&
            ((c.center.dx > cg.left &&
                    c.center.dx < cg.right &&
                    c.center.dy > cg.top &&
                    c.center.dy < cg.bottom) ||
                (c.left < cg.right &&
                    (c.center.dy - cg.top).abs() < 0.2 * cg.height) ||
                // La barre d'un `A` qui part de sa jambe gauche.
                (c.left < cg.left + 0.6 * cg.width &&
                    c.center.dy > cg.top &&
                    c.center.dy < cg.bottom))) {
          hote = g;
        }
      } else if (c.left < cg.right - 0.1 * math.min(c.width, cg.width) ||
          (g.length == 1 && _plat(cg) && c.left < cg.right) ||
          accrocheAUneHampe(t, g)) {
        final commun = math.min(c.bottom, cg.bottom) - math.max(c.top, cg.top);
        // `x)` serrés (Pad 7) : la parenthèse fermante, bien plus haute,
        // reste à part.
        final parenthese =
            genreParenthese(t, c.height) == -1 && c.height >= 1.4 * cg.height;
        if (_plat(cg) ||
            (commun > 0.2 * math.min(c.height, cg.height) && !parenthese)) {
          hote = g;
        }
      }
      if (hote != null) break;
    }
    if (hote == null) {
      groupes.add([t]);
    } else {
      hote.add(t);
    }
  }
  return groupes;
}

/// Le bras d'un `k`, le ventre d'un `b` ou d'un `h` tracés à part : un
/// trait plus court qui touche, à droite, une hampe droite seule, sous son
/// premier tiers. Sans lui, `k = 1` se lisait en morceaux (ADR 0046). Un
/// exposant, plus haut, ou un signe voisin qui ne touche pas restent à part.
bool accrocheAUneHampe(Trait t, List<Trait> groupe) {
  if (groupe.length != 1) return false;
  final hampe = groupe.single;
  final h = _c(hampe);
  final c = _c(t);
  if (!_debout(h) || !_droit(hampe) || _plat(c)) return false;
  if (c.height > 0.75 * h.height ||
      c.left < h.left ||
      c.center.dy < h.top + 0.35 * h.height ||
      c.center.dy > h.bottom) {
    return false;
  }
  final tolerance = math.max(2, 0.08 * h.height);
  for (final p in t.points) {
    for (final q in hampe.points) {
      if ((p.position - q.position).distance <= tolerance) return true;
    }
  }
  return false;
}

/// Un `x` en deux arcs dos à dos, `ɔ` puis `c` (Antsa, Pad 7). Pas quand
/// la ligne a des parenthèses de leur taille : `(a)(b)` garde `)(`.
List<(List<Trait>, bool)> _fondreArcs(List<List<Trait>> groupes) {
  bool parenthese(List<Trait> g) =>
      g.length == 1 && genreParenthese(g.single, _c(g.single).height) != 0;
  final sortie = <(List<Trait>, bool)>[];
  for (var i = 0; i < groupes.length; i++) {
    if (i + 1 < groupes.length &&
        groupes[i].length == 1 &&
        groupes[i + 1].length == 1 &&
        _arc(groupes[i].single) == 1 &&
        _arc(groupes[i + 1].single) == -1) {
      final (a, b) = (_c(groupes[i].single), _c(groupes[i + 1].single));
      final haut = math.max(a.height, b.height);
      final commun = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
      final pareilles = [
        for (var j = 0; j < groupes.length; j++)
          if (j != i && j != i + 1 && parenthese(groupes[j]))
            cadreDuGroupe(groupes[j]).height,
      ].any((h) => h <= 1.3 * haut);
      if (a.height < 1.6 * b.height &&
          b.height < 1.6 * a.height &&
          commun >= 0.6 * math.min(a.height, b.height) &&
          b.left - a.right <= 0.5 * haut &&
          !pareilles) {
        sortie.add(([...groupes[i], ...groupes[i + 1]], true));
        i++;
        continue;
      }
    }
    sortie.add((groupes[i], false));
  }
  return sortie;
}

/// Un arc : `1` le ventre à droite (`ɔ`), `-1` à gauche (`c`), `0` sinon.
int _arc(Trait t) {
  final s = [for (final p in t.points) p.position];
  if (s.length < 3) return 0;
  final c = _c(t);
  if (c.height < 6 || c.width < 0.2 * c.height || c.width > 1.3 * c.height) {
    return 0;
  }
  final (a, b) = (s.first, s.last);
  if ((a.dy - b.dy).abs() < 0.5 * c.height) return 0;
  final (gauche, droite) = (math.min(a.dx, b.dx), math.max(a.dx, b.dx));
  if (c.right > droite + 0.25 * c.width && gauche - c.left < 0.35 * c.width) {
    return 1;
  }
  if (c.left < gauche - 0.25 * c.width && c.right - droite < 0.35 * c.width) {
    return -1;
  }
  return 0;
}

/// Un seul ventre : le trait va d'un côté puis revient, une fois. Un `3`
/// étroit a deux ventres du même côté, et n'est pas une `)`.
bool _simple(Trait t) {
  final s = [for (final p in t.points) p.position];
  final c = _c(t);
  final seuil = 0.15 * c.width;
  var tours = 0;
  var sens = 0;
  var repere = s.first.dx;
  for (final p in s) {
    final d = p.dx - repere;
    if (d.abs() < seuil) continue;
    final nouveau = d.sign.toInt();
    if (sens != 0 && nouveau != sens) tours++;
    sens = nouveau;
    repere = p.dx;
  }
  return tours <= 1;
}

bool _operateur(String s) => const {'+', '-', '=', r'\times'}.contains(s);

Rect _c(Trait t) => cadreDuGroupe([t]);

bool _plat(Rect c) => c.height <= 0.45 * c.width && c.width >= 6;

bool _debout(Rect c) => c.width <= 0.45 * c.height && c.height >= 6;

/// Un trait presque droit : ses points restent près de la corde.
bool _droit(Trait t, [double tolerance = 0.12]) {
  final s = [for (final p in t.points) p.position];
  if (s.length < 2) return true;
  final (a, b) = (s.first, s.last);
  final corde = b - a;
  final longueur = corde.distance;
  if (longueur < 4) return false;
  for (final p in s) {
    final d =
        ((p.dx - a.dx) * corde.dy - (p.dy - a.dy) * corde.dx).abs() / longueur;
    if (d > tolerance * longueur) return false;
  }
  return true;
}

/// Droit à peu près : un moins tiré vite s'arque un peu (Pad 7).
bool _presqueDroit(Trait t) => _droit(t, 0.3);

/// Une diagonale droite : montante (`/`) rend 1, descendante (`\`) -1, 0 sinon.
int _diagonale(Trait t) {
  if (!_droit(t)) return 0;
  final s = [for (final p in t.points) p.position];
  final corde = s.last - s.first;
  if (corde.dx.abs() < 4 || corde.dy.abs() < 4) return 0;
  final pente = corde.dy.abs() / corde.dx.abs();
  if (pente < 0.4 || pente > 2.5) return 0;
  return corde.dx.sign == corde.dy.sign ? -1 : 1;
}
