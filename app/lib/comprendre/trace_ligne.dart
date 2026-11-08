import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana_math/fikajiana_math.dart';

/// Une ligne lue sur son tracé seul, sans le modèle (ADR 0035, idée de
/// Mikajy) : chiffres, capitales, minuscules usuelles et `π`, `+ − = × ( )`,
/// exposants, `f'`, fractions, racines, virgule et point décimaux
/// (ADR 0037). Quelques millisecondes au lieu de 300.
///
/// Rend `null` dès qu'un signe doute : le modèle lit alors la ligne entière.
/// Une erreur coûte plus qu'un détour par le modèle.
String? lireAuTrace(List<Trait> traits) => lireAuTraceDetaille(traits)?.latex;

/// Une ligne lue au tracé, et chacun de ses signes : ses traits et ce qu'on
/// y a lu, de gauche à droite (ADR 0040).
typedef LectureTrace = ({String latex, List<(List<Trait>, String)> signes});

/// Les signes lus par la lecture en cours.
List<(List<Trait>, String)>? _lus;

/// Comme [lireAuTrace], avec les signes lus : toucher l'un d'eux propose
/// d'autres lectures.
LectureTrace? lireAuTraceDetaille(List<Trait> traits) {
  final avant = _lus;
  final lus = _lus = [];
  try {
    final latex = _lireLigne(traits);
    if (latex == null) return null;
    lus.sort(
      (a, b) => cadreDuGroupe(a.$1).left.compareTo(cadreDuGroupe(b.$1).left),
    );
    return (latex: latex, signes: lus);
  } finally {
    _lus = avant;
  }
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
  new(this.traits, {this.arcs = false, this.miette = false})
    : cadre = cadreDuGroupe(traits);

  final List<Trait> traits;
  final Rect cadre;

  /// Deux arcs dos à dos : un `x` (Pad 7).
  final bool arcs;

  /// Un point de stylet entre deux signes.
  final bool miette;

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
const _basses = {'a', 'c', 'e', 'n', 'u', 'v', 'x', 'z', r'\pi'};

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
  for (final g in glyphes) {
    if (!_classer(g, hauteur)) return null;
  }
  if (!_niveaux(glyphes)) return null;
  if (!_trancher(glyphes)) return null;
  if (!_auNiveau(glyphes)) return null;
  // `det`, `sin`, un mot : trois lettres de suite, c'est au modèle.
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
  final c = g.cadre;
  if (g.miette || math.max(c.width, c.height) < 0.25 * hauteur) {
    g.petit = true;
    return true;
  }
  // Un signe que la personne a corrigé, ou qu'elle écrit toujours ainsi
  // (ADR 0040).
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
  if (lu == null) return g.petit;
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
                      {'b', 'd', 'f', 'k', 't'}.contains(g.signe))) ||
              (g.signe == null &&
                  g.candidats.keys.any(_chiffre) &&
                  !g.candidats.keys.any(_minusculeSimple))))
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
    } else {
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
      if (basse == null) return false;
      final rapport = g.cadre.height / basse.cadre.height;
      final minuscule = g.candidats.keys.where(_minusculeSimple).firstOrNull;
      if (rapport >= 1.25) {
        g.signe = chiffre;
      } else if (rapport <= 1.15 && minuscule != null) {
        g.signe = minuscule;
      } else {
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

/// Un signe qui tombe sous la ligne (le bas d'un `;`, un indice) : au
/// modèle. Seuls `y`, `f`, la virgule et les parenthèses y descendent.
bool _auNiveau(List<_Glyphe> glyphes) {
  final pieds = <double>[];
  final tailles = <double>[];
  for (final g in glyphes) {
    final genre = _genre(g);
    if (g.haut || (genre != _Genre.chiffre && genre != _Genre.lettre)) {
      continue;
    }
    if (g.signe == 'y' || g.signe == 'f') continue;
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
    if (g.signe == 'y' || g.signe == 'f') continue;
    if (g.cadre.center.dy > ligne - 0.1 * taille) return false;
    if (g.cadre.bottom > ligne + 0.25 * taille) return false;
  }
  return true;
}

String _ecrire(List<_Glyphe> glyphes) {
  final sortie = StringBuffer();
  var exposant = false;
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
        RegExp('^[A-Za-z]').hasMatch(signe)) {
      sortie.write(' ');
    }
    sortie.write(signe);
  }
  if (exposant) sortie.write('}');
  return sortie.toString();
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
      if (c.left > cg.right) continue;
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
          (g.length == 1 && _plat(cg) && c.left < cg.right)) {
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
