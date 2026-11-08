import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';

/// Écart maximal entre deux traits d'une même expression, en pixels de page.
const double _ecartHorizontal = 70;
const double _ecartVertical = 45;
const double _marge = 8;
const double _hauteurMinimale = 40;

Rect _cadre(Trait trait) {
  final points = trait.points;
  var (g, h, d, b) = (
    points.first.x,
    points.first.y,
    points.first.x,
    points.first.y,
  );
  for (final p in points) {
    if (p.x < g) g = p.x;
    if (p.x > d) d = p.x;
    if (p.y < h) h = p.y;
    if (p.y > b) b = p.y;
  }
  return Rect.fromLTRB(g, h, d, b);
}

/// Regroupe les traits proches : chaque groupe est une expression à lire.
/// Les formes nettes sont des dessins : elles n'en font pas partie.
List<List<Trait>> grouperTraits(List<Trait> traits) {
  final ecrits = traits.where((t) => t.forme == null).toList();
  final cadres = ecrits.map(_cadre).toList();
  final parents = List<int>.generate(ecrits.length, (i) => i);
  int racine(int i) {
    var r = i;
    while (parents[r] != r) {
      r = parents[r];
    }
    return r;
  }

  for (var i = 0; i < ecrits.length; i++) {
    for (var j = 0; j < i; j++) {
      // Plus on écrit grand, plus les signes d'une expression s'écartent.
      final ecart = math.max(
        _ecartHorizontal,
        1.2 * math.max(cadres[i].height, cadres[j].height),
      );
      final proche = cadres[i]
          .inflate(ecart / 2)
          .overlaps(cadres[j].inflate(ecart / 2));
      final vertical =
          (cadres[i].top - cadres[j].bottom) <= _ecartVertical &&
          (cadres[j].top - cadres[i].bottom) <= _ecartVertical;
      if (proche && vertical) parents[racine(i)] = racine(j);
    }
  }
  final groupes = <int, List<Trait>>{};
  for (var i = 0; i < ecrits.length; i++) {
    (groupes[racine(i)] ??= []).add(ecrits[i]);
  }
  return [for (final g in groupes.values) ..._separerLignes(g)];
}

/// Deux lignes écrites serrées se touchent, par la queue d'un `g` par exemple :
/// le modèle les lirait comme une seule. On les sépare, sauf si un trait les
/// relie : parenthèse, accolade, barre de fraction.
List<List<Trait>> _separerLignes(List<Trait> groupe) {
  if (groupe.length < 6) return [groupe];
  final cadres = {for (final t in groupe) t: _cadre(t)};
  final largeurTotale = cadreDuGroupe(groupe).width;

  // Le cœur de chaque trait : sans la queue ni les jambages.
  final tries = groupe.toList()
    ..sort((a, b) => cadres[a]!.center.dy.compareTo(cadres[b]!.center.dy));
  final rangs = <List<Trait>>[];
  double? bas;
  for (final t in tries) {
    final c = cadres[t]!;
    final demi = math.max(0.3 * c.height, 5);
    if (bas == null || c.center.dy - demi > bas) {
      rangs.add([]);
      bas = c.center.dy + demi;
    } else {
      bas = math.max(bas, c.center.dy + demi);
    }
    rangs.last.add(t);
  }

  // Une vraie ligne : assez de signes, assez large ; un exposant n'en est pas.
  bool estLigne(List<Trait> rang) =>
      rang.length >= 3 && cadreDuGroupe(rang).width >= 0.3 * largeurTotale;
  final lignes = rangs.where(estLigne).toList();
  if (lignes.length < 2) return [groupe];

  double milieu(List<Trait> rang) => cadreDuGroupe(rang).center.dy;
  for (var i = 1; i < lignes.length; i++) {
    final (haut, dessous) = (milieu(lignes[i - 1]), milieu(lignes[i]));
    // Un trait qui traverse les deux lignes : parenthèse ou accolade.
    if (groupe.any((t) {
      final c = cadres[t]!;
      return c.top <= haut && c.bottom >= dessous;
    })) {
      return [groupe];
    }
    // Une barre entre les deux : c'est une fraction.
    final largeur = math.min(
      cadreDuGroupe(lignes[i - 1]).width,
      cadreDuGroupe(lignes[i]).width,
    );
    if (groupe.any((t) {
      final c = cadres[t]!;
      return c.center.dy > haut &&
          c.center.dy < dessous &&
          c.height <= 0.3 * c.width &&
          c.width >= 0.6 * largeur;
    })) {
      return [groupe];
    }
  }

  // Les petits rangs (exposants, tirets) vont à la ligne la plus proche.
  final sortie = [
    for (final l in lignes) <Trait>[...l],
  ];
  for (final rang in rangs.where((r) => !estLigne(r))) {
    final y = milieu(rang);
    var meilleure = 0;
    for (var i = 1; i < lignes.length; i++) {
      if ((milieu(lignes[i]) - y).abs() <
          (milieu(lignes[meilleure]) - y).abs()) {
        meilleure = i;
      }
    }
    sortie[meilleure].addAll(rang);
  }
  return sortie;
}

Rect cadreDuGroupe(List<Trait> groupe) =>
    groupe.map(_cadre).reduce((a, b) => a.expandToInclude(b));

/// Ce nouveau [groupe] modifie-t-il un bloc déjà lu ?
///
/// Oui s'il le touche. Oui aussi s'il le continue sur la même ligne, juste à sa
/// droite, tant que le bloc n'est pas [ferme] par un `=`. Sinon c'est un autre
/// calcul : le résultat du bloc reste en place.
bool prolonge(Rect bloc, Rect groupe, {required bool ferme}) {
  final zone = bloc.inflate(_marge);
  if (zone.overlaps(groupe)) {
    // La queue d'un `g` qui descend ne fait pas de la ligne d'en dessous une
    // suite : il faut que le nouveau groupe soit surtout dans le bloc.
    final commun = zone.intersect(groupe);
    if (commun.height >= 0.5 * groupe.height) return true;
    if (groupe.center.dy <= zone.bottom) return true;
  }
  if (ferme) return false;
  final milieu = groupe.center.dy;
  final memeLigne = milieu >= bloc.top && milieu <= bloc.bottom;
  final hauteur = bloc.height < _hauteurMinimale
      ? _hauteurMinimale
      : bloc.height;
  final ecart = groupe.left - bloc.right;
  return memeLigne && ecart >= 0 && ecart <= 1.5 * hauteur;
}

/// Ce [groupe] commence le bloc, juste à sa gauche sur la même ligne :
/// `lim` et la fraction qui le suit, écrits sans pause, se lisent par
/// groupes et la fraction, plus haute, passe la première (Pad 7, ADR 0047).
bool precede(Rect bloc, Rect groupe) {
  final milieu = groupe.center.dy;
  final hauteur = math.max(bloc.height, _hauteurMinimale);
  final ecart = bloc.left - groupe.right;
  return milieu >= bloc.top &&
      milieu <= bloc.bottom &&
      ecart >= 0 &&
      ecart <= 1.5 * hauteur;
}

/// Une barre de fraction et son dénominateur, écrits sous un calcul déjà lu :
/// `1 - 1/(-2)` puis, dessous, `—` et `4` (téléphone d'Antsa). Ils le
/// prolongent : la barre est longue, juste sous le bloc, et tout le reste du
/// groupe, s'il y en a, est sous elle.
bool estDenominateur(Rect bloc, List<Trait> groupe) {
  final cadres = groupe.map(_cadre).toList();
  final barre = cadres.reduce((a, b) => a.top <= b.top ? a : b);
  final hauteur = math.max(bloc.height, _hauteurMinimale);
  if (barre.height > 0.25 * barre.width) return false;
  if (barre.width < 0.5 * bloc.width) return false;
  final commun =
      math.min(barre.right, bloc.right) - math.max(barre.left, bloc.left);
  if (commun < 0.5 * barre.width) return false;
  if (barre.top < bloc.bottom - 0.4 * hauteur ||
      barre.top > bloc.bottom + 0.6 * hauteur) {
    return false;
  }
  final reste = [
    for (final c in cadres)
      if (!identical(c, barre)) c,
  ];
  // La barre seule, le dénominateur viendra : elle rejoint déjà le calcul.
  return reste.every(
    (c) =>
        c.center.dy > barre.bottom &&
        c.overlaps(Rect.fromLTRB(barre.left, barre.top, barre.right, c.bottom)),
  );
}

/// Les bornes d'un grand signe : `x → 0` sous `lim`, `5` au-dessus d'un Σ et
/// `n = 0` dessous (Pad 7 d'Antsa : lues à part, soulignées, et la limite
/// jamais appliquée). Un groupe étroit, collé au-dessus ou au-dessous du
/// bloc, à la hauteur d'un de ses grands traits, va avec lui.
bool estBorne(Rect bloc, List<Trait> traitsDuBloc, List<Trait> groupe) {
  final g = cadreDuGroupe(groupe);
  final hauteur = math.max(bloc.height, _hauteurMinimale);
  // Quelques signes, pas une ligne : `x → 0` est plus large que `lim`.
  if (g.width > 2.5 * hauteur) return false;
  // Une borne ne finit pas par `=` : c'est une ligne de calcul, comme la
  // `lim` écrite au-dessus d'un produit de matrices (Pad 7 d'Antsa).
  if (finitParEgal(groupe)) return false;
  // Mesuré au grand trait lui-même (un Σ, le `l` de lim, un ∫), pas au bloc
  // entier : la fraction écrite à côté descend plus bas que le signe.
  for (final t in traitsDuBloc) {
    final c = _cadre(t);
    // Avec une fraction à côté, le bloc a deux étages : le `l` de `lim` n'en
    // fait que la moitié, mais reste plus grand que la borne (ADR 0047).
    if (c.height < 0.55 * hauteur &&
        (c.height < 0.4 * hauteur || c.height < 1.1 * g.height)) {
      continue;
    }
    if (c.right < g.left - 0.3 * hauteur || c.left > g.right + 0.3 * hauteur) {
      continue;
    }
    // Étroite au regard du grand trait lui-même : la hauteur du bloc, une
    // matrice l'agrandit, et une ligne entière y passait.
    if (g.width > 2.5 * c.height) continue;
    final dessus = g.bottom <= c.top + 0.15 * hauteur;
    final dessous = g.top >= c.bottom - 0.15 * hauteur;
    if (!dessus && !dessous) continue;
    final ecart = dessus ? c.top - g.bottom : g.top - c.bottom;
    // Collée à son signe : moins que sa propre hauteur. `p(x) = …` écrit sur
    // la ligne sous un produit de matrices n'en est pas une (ADR 0047).
    if (ecart <= 0.6 * hauteur && ecart <= math.max(0.8 * g.height, 12)) {
      return true;
    }
  }
  return false;
}

/// Ce qui s'écrit sous un calcul déjà lu, par morceaux : le dénominateur
/// sous sa barre (`e^x − 1` sous `3x − 1`), la borne sous `lim`, ou une
/// ligne qui porte les deux (`x → 0`, puis `2x` sous la barre ; Pad 7
/// d'Antsa, lues à part et soulignées). Chaque morceau du groupe, séparé
/// des autres par un blanc, est l'un ou l'autre (ADR 0047).
bool completeDessous(Rect bloc, List<Trait> traitsDuBloc, List<Trait> groupe) {
  final hauteur = math.max(bloc.height, _hauteurMinimale);
  final morceaux = _morceaux(groupe, 0.25 * hauteur);
  return morceaux.every(
    (m) =>
        estBorne(bloc, traitsDuBloc, m) ||
        _sousUneBarre(traitsDuBloc, m, hauteur),
  );
}

/// Les morceaux d'un groupe, de gauche à droite, séparés par plus de
/// [blanc].
List<List<Trait>> _morceaux(List<Trait> groupe, double blanc) {
  final tries = groupe.toList()
    ..sort((a, b) => _cadre(a).left.compareTo(_cadre(b).left));
  final morceaux = <List<Trait>>[];
  var droite = double.negativeInfinity;
  for (final t in tries) {
    final c = _cadre(t);
    if (morceaux.isEmpty || c.left > droite + blanc) morceaux.add([]);
    morceaux.last.add(t);
    droite = math.max(droite, c.right);
  }
  return morceaux;
}

/// Juste sous une barre de fraction du bloc, dans sa largeur, sans rien du
/// bloc entre elle et lui : un dénominateur écrit après coup.
bool _sousUneBarre(List<Trait> traitsDuBloc, List<Trait> morceau, double h) {
  final g = cadreDuGroupe(morceau);
  for (final barre in traitsDuBloc) {
    final c = _cadre(barre);
    if (c.height > 0.25 * c.width || c.width < 0.8 * g.width) continue;
    if (g.center.dx < c.left || g.center.dx > c.right) continue;
    if (g.top < c.bottom - 0.15 * h || g.top - c.bottom > 0.6 * h) continue;
    final entre = traitsDuBloc.any((t) {
      final ct = _cadre(t);
      return !identical(t, barre) &&
          ct.top >= c.bottom - 2 &&
          ct.bottom <= g.top + 2 &&
          ct.right > g.left &&
          ct.left < g.right;
    });
    if (!entre) return true;
  }
  return false;
}
