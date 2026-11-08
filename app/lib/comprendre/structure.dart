import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/mots.dart';
import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';

/// Ce que le modèle lit mal : ce qui sort d'une seule ligne (ADR 0029). Une
/// matrice, une flèche, de doubles barres se voient sur les traits ; on les
/// découpe, et le modèle ne lit plus que des morceaux simples.
sealed class Structure {
  const new();
}

/// `det (a b ; c d) =` : ce qui précède, les cases, ce qui suit.
class StructureMatrice extends Structure {
  const new(this.tete, this.cases, this.queue, {this.exposant = const []});
  final List<Trait> tete;
  final List<List<List<Trait>>> cases;

  /// Écrit en haut, juste après : `⁻¹` pour l'inverse.
  final List<Trait> exposant;
  final List<Trait> queue;
}

/// `→` au-dessus de `AB`, et ce qui suit.
class StructureFleche extends Structure {
  const new(this.nom, this.queue);
  final List<Trait> nom;
  final List<Trait> queue;
}

/// `A(8;-1)` : le nom, le premier nombre, le second, et ce qui suit.
class StructurePoint extends Structure {
  const new(this.nom, this.premier, this.second, this.queue);
  final List<Trait> nom;
  final List<Trait> premier;
  final List<Trait> second;
  final List<Trait> queue;
}

/// `lim` au-dessus de `x → 0`, et ce qui suit à droite.
class StructureLimite extends Structure {
  const new(this.mot, this.variable, this.cible, this.queue);
  final List<Trait> mot;
  final List<Trait> variable;
  final List<Trait> cible;
  final List<Trait> queue;
}

/// Σ avec sa borne du haut, sa borne du bas, et ce qu'il somme à droite.
class StructureSomme extends Structure {
  const new(this.haut, this.bas, this.corps);
  final List<Trait> haut;
  final List<Trait> bas;
  final List<Trait> corps;
}

/// `‖…‖`, et ce qui suit.
class StructureNorme extends Structure {
  const new(this.dedans, this.queue);
  final List<Trait> dedans;
  final List<Trait> queue;
}

Rect _c(Trait t) => cadreDuGroupe([t]);

double _mediane(Iterable<double> v) {
  final l = v.toList()..sort();
  return l.isEmpty ? 0 : l[l.length ~/ 2];
}

/// Un moins, une barre : mesuré sur de vrais moins, jusqu'à la moitié.
bool _plat(Rect c) => c.height <= 0.5 * c.width;

/// La structure qui se voit sur ces traits, ou `null` : une ligne ordinaire.
Structure? trouverStructure(List<Trait> traits) {
  // Une touche involontaire du stylet n'est ni une ligne ni une case.
  final nets = traits.where((t) {
    final c = _c(t);
    return c.width >= 5 || c.height >= 5;
  }).toList();
  if (nets.length < 3) return null;
  return _norme(nets) ??
      _fleche(nets) ??
      _limite(nets) ??
      _somme(nets) ??
      _point(nets) ??
      _matrice(nets);
}

/// Un trait sans ventre : une barre. `((` et `))` ne sont pas `‖` (vu sur
/// le Pad 7 : `développer((2x-1)(x-4))` lu comme une norme).
bool _droit(Trait t, double hauteur) {
  final points = [for (final p in t.points) p.position];
  final (a, b) = (points.first, points.last);
  final corde = b - a;
  if (corde.distance == 0) return false;
  final ecart = points
      .map((p) => ((p - a).dx * corde.dy - (p - a).dy * corde.dx).abs())
      .reduce(math.max);
  return ecart / corde.distance <= 0.1 * hauteur;
}

/// Deux barres de chaque côté, plus hautes que ce qu'elles entourent.
StructureNorme? _norme(List<Trait> traits) {
  if (traits.length < 5) return null;
  final tries = traits.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  // Une flèche au-dessus ne compte pas : les barres se jugent aux lettres.
  final haut = _mediane(
    traits.map(_c).where((c) => !_plat(c)).map((c) => c.height),
  );
  bool barre(Trait t) {
    final c = _c(t);
    return c.height >= 0.8 * haut &&
        c.width <= 0.3 * c.height &&
        _droit(t, c.height);
  }

  if (!barre(tries[0]) || !barre(tries[1])) return null;
  final barres = [
    for (var i = 2; i < tries.length; i++)
      if (barre(tries[i])) i,
  ];
  // Les deux dernières barres qui se suivent ferment la norme.
  for (var k = 0; k + 1 < barres.length; k++) {
    if (barres[k + 1] != barres[k] + 1) continue;
    if (barres[k] <= 2) continue;
    final ecart = _c(tries[barres[k + 1]]).left - _c(tries[barres[k]]).right;
    if (ecart > 0.6 * haut) continue;
    return StructureNorme(
      tries.sublist(2, barres[k]),
      tries.sublist(barres[k + 1] + 1),
    );
  }
  return null;
}

/// Un long trait plat au-dessus de lettres, avec sa pointe à droite ou sans.
StructureFleche? _fleche(List<Trait> traits) {
  final tries = traits.toList()..sort((a, b) => _c(a).top.compareTo(_c(b).top));
  for (final fleche in tries) {
    final f = _c(fleche);
    if (f.height > 0.45 * f.width || f.width < 24) continue;
    var lettres = false;
    final dessous = <Trait>[];
    final pointes = <Trait>[];
    final queue = <Trait>[];
    for (final t in traits) {
      if (identical(t, fleche)) continue;
      final c = _c(t);
      // Une flèche coiffe souvent ses lettres de près, parfois les touche.
      final auDessus = c.center.dy < f.center.dy + 4;
      if (auDessus) {
        pointes.add(t);
      } else if (c.center.dx >= f.left - 8 && c.center.dx <= f.right + 8) {
        dessous.add(t);
        if (!_plat(c)) lettres = true;
      } else {
        queue.add(t);
      }
    }
    // Le trait du haut d'un `=` n'a qu'un trait plat dessous.
    if (!lettres) continue;
    // Rien au-dessus sauf la pointe, près du bout droit : sinon, une fraction.
    final pointeAuBout = pointes.every((p) {
      final c = _c(p);
      return c.center.dx >= f.left + 0.6 * f.width && c.width <= 0.6 * f.width;
    });
    if (!pointeAuBout) continue;
    final nom = cadreDuGroupe(dessous);
    if (nom.center.dy < f.bottom) continue;
    if (f.width < 0.6 * nom.width) continue;
    // Une fraction a sa barre au milieu : elle a de l'encre au-dessus. Ici, le
    // trait coiffe le nom.
    if (nom.left < f.left - 0.5 * f.width) continue;
    return StructureFleche(dessous, queue);
  }
  return null;
}

/// Un Σ d'un trait : part en haut à droite, va à gauche, descend en zigzag
/// et finit en bas à droite ; au moins trois changements de sens.
bool _estSigma(Trait t, double hauteur) {
  final c = _c(t);
  // Avec ses bornes dessus et dessous, le Σ fait la moitié du bloc.
  if (c.height < 0.35 * hauteur || c.width < 0.35 * c.height) return false;
  final s = [for (final p in t.points) p.position];
  if (s.length < 4) return false;
  if (s.first.dx < c.center.dx || s.last.dx < c.center.dx) return false;
  if (s.first.dy > c.top + 0.35 * c.height ||
      s.last.dy < c.bottom - 0.35 * c.height) {
    return false;
  }
  var sens = 0;
  var changements = 0;
  for (var i = 1; i < s.length; i++) {
    final dx = s[i].dx - s[i - 1].dx;
    if (dx.abs() < 0.04 * c.width) continue;
    final nouveau = dx.sign.toInt();
    if (sens != 0 && nouveau != sens) changements++;
    sens = nouveau;
  }
  return changements >= 3;
}

/// `Σ` avec `5` dessus et `n = 0` dessous, puis ce qu'il somme (Pad 7
/// d'Antsa : le modèle lit `\sum^{\frac{t}{2}}` ou invente `n = 1`).
StructureSomme? _somme(List<Trait> traits) {
  final hauteur = cadreDuGroupe(traits).height;
  for (final sigma in traits) {
    if (!_estSigma(sigma, hauteur)) continue;
    final c = _c(sigma);
    final haut = <Trait>[];
    final bas = <Trait>[];
    final corps = <Trait>[];
    var autre = false;
    for (final t in traits) {
      if (identical(t, sigma)) continue;
      final ct = _c(t);
      final enColonne =
          ct.center.dx >= c.left - 0.3 * c.height &&
          ct.center.dx <= c.right + 0.3 * c.height;
      if (enColonne && ct.bottom <= c.top + 0.15 * c.height) {
        haut.add(t);
      } else if (enColonne && ct.top >= c.bottom - 0.15 * c.height) {
        bas.add(t);
      } else if (ct.left >= c.right - 0.1 * c.height) {
        corps.add(t);
      } else {
        autre = true;
      }
    }
    if (autre || bas.isEmpty || corps.isEmpty) continue;
    return StructureSomme(haut, bas, corps);
  }
  return null;
}

/// La pointe d'une flèche `→` : le trait revient sur lui-même au bout, ou un
/// petit trait se tient à son bout droit.
bool _fleches(Trait f, List<Trait> traits, double hauteur, List<Trait> pointe) {
  final c = _c(f);
  // Une hampe courte suffit : `x → 0` d'Antsa sous `lim` (Pad 7), 20 px.
  if (c.width < 12 || c.height > 0.5 * c.width) return false;
  final s = [for (final p in f.points) p.position];
  if (s.last.dx < c.right - 0.12 * c.width) return true;
  Trait? meilleure;
  var ecart = double.infinity;
  for (final t in traits) {
    if (identical(t, f)) continue;
    final ct = _c(t);
    if (math.max(ct.width, ct.height) > 0.6 * hauteur) continue;
    // La pointe tient le bout de la hampe et l'enjambe : le `m` de `lim`,
    // juste au-dessus, n'en est pas une (Pad 7, ADR 0046).
    if (ct.right < c.right - 0.3 * c.width ||
        ct.left > c.right + 0.2 * c.width + 2 ||
        ct.top > c.center.dy + 2 ||
        ct.bottom < c.center.dy - 2) {
      continue;
    }
    final d = (ct.centerLeft - c.centerRight).distance;
    if (d < ecart) (meilleure, ecart) = (t, d);
  }
  if (meilleure == null) return false;
  pointe.add(meilleure);
  return true;
}

/// `lim` écrit au-dessus de `x → 0` : le modèle lit `\lim_{\Im\infty}`
/// (téléphone d'Antsa). La flèche se voit au tracé, le mot au-dessus, la
/// variable à gauche, la cible à droite ; le reste suit, à droite du bloc.
StructureLimite? _limite(List<Trait> traits) {
  final hauteur = cadreDuGroupe(traits).height;
  for (final f in traits) {
    final pointe = <Trait>[];
    if (!_fleches(f, traits, hauteur, pointe)) continue;
    // La flèche, pointe comprise, donne l'échelle : une lettre fait environ
    // sa largeur.
    final c = cadreDuGroupe([f, ...pointe]);
    final echelle = c.width;
    final variable = <Trait>[];
    final cible = <Trait>[];
    for (final t in traits) {
      if (identical(t, f) || pointe.contains(t)) continue;
      final ct = _c(t);
      if ((ct.center.dy - c.center.dy).abs() > 0.5 * echelle) continue;
      if (ct.center.dx < c.left && ct.right > c.left - 1.2 * echelle) {
        variable.add(t);
      } else if (ct.center.dx > c.right && ct.left < c.right + 0.6 * echelle) {
        cible.add(t);
      }
    }
    if (variable.isEmpty || cible.isEmpty) continue;
    final bloc = cadreDuGroupe([...variable, f, ...cible]);
    final mot = <Trait>[];
    final queue = <Trait>[];
    var autre = false;
    for (final t in traits) {
      if (identical(t, f) ||
          pointe.contains(t) ||
          variable.contains(t) ||
          cible.contains(t)) {
        continue;
      }
      final ct = _c(t);
      if (ct.bottom <= c.top + 2 &&
          ct.center.dx >= bloc.left - 0.3 * echelle &&
          ct.center.dx <= bloc.right + 0.3 * echelle) {
        mot.add(t);
      } else if (ct.left >= bloc.right - 0.1 * echelle) {
        queue.add(t);
      } else {
        autre = true;
      }
    }
    if (autre || mot.length < 2 || queue.isEmpty) continue;
    final cm = cadreDuGroupe(mot);
    if (cm.width < 1.2 * cm.height) continue;
    return StructureLimite(mot, variable, cible, queue);
  }
  return null;
}

/// Une parenthèse : haute, étroite, le ventre d'un côté. `1` s'ouvre vers la
/// droite pour `(`, vers la gauche pour `)`.
int genreParenthese(Trait t, double hauteur) => _parenthese(t, hauteur);

int _parenthese(Trait t, double hauteur) {
  final s = [for (final p in t.points) p.position];
  if (s.length < 3) return 0;
  final c = _c(t);
  if (c.height < 0.5 * hauteur || c.width > 0.6 * c.height) return 0;
  // Le ventre, pas le milieu des points : un trait commencé lentement a
  // beaucoup de points en haut.
  if (c.left < math.min(s.first.dx, s.last.dx) - 0.1 * c.height) return 1;
  if (c.right > math.max(s.first.dx, s.last.dx) + 0.1 * c.height) return -1;
  // Sinon, mesuré à la corde des deux bouts : une grande parenthèse peu
  // bombée, écrite penchée, en est une (téléphone d'Antsa : 7 % de sa
  // hauteur).
  final (a, b) = (s.first, s.last);
  final corde = b - a;
  final longueur = corde.distance;
  // Une parenthèse descend : un `A` d'un seul trait a ses bouts côte à côte.
  if (corde.dy.abs() < 0.8 * c.height) return 0;
  // Écart signé à la corde, positif à droite quand on descend.
  final ecarts = [
    for (final p in s)
      ((p.dx - a.dx) * corde.dy - (p.dy - a.dy) * corde.dx) /
          longueur *
          corde.dy.sign,
  ];
  var k = 0;
  for (var i = 1; i < ecarts.length; i++) {
    if (ecarts[i].abs() > ecarts[k].abs()) k = i;
  }
  final ventre = ecarts[k];
  if (ventre.abs() < 0.05 * c.height) return 0;
  // Un arc : le ventre vers le milieu, et déjà là aux quarts. Un trait droit
  // qui tremble (le dos d'un `B`) n'en est pas un.
  final n = ecarts.length - 1;
  if (k < 0.25 * n || k > 0.75 * n) return 0;
  for (final q in [ecarts[n ~/ 4], ecarts[3 * n ~/ 4]]) {
    if (q * ventre.sign < 0.3 * ventre.abs()) return 0;
  }
  return ventre < 0 ? 1 : -1;
}

String _sansEspace(String s) => s.replaceAll(' ', '');

/// Un exposant court lu sur son tracé : `2`, `-1`, `12` ; `null` sinon.
String? _exposantAuTrace(List<Trait> exposant) {
  final moins = _signeMoins(exposant);
  final corps = [
    for (final t in exposant)
      if (!moins.contains(t)) t,
  ];
  final chiffres = [
    for (final g in _glyphes(corps)) classeurCourant.chiffre(g),
  ];
  if (chiffres.isEmpty || chiffres.contains(null)) return null;
  return '${moins.isEmpty ? '' : '-'}${chiffres.join()}';
}

/// `A(8;-1)` : une lettre, `(`, deux nombres séparés par `;` ou `,`, `)`.
/// Le modèle y lit `A(8i-1)` ou `β(5,0)` (Pad 7) : le `;` se voit au trait
/// qui descend sous les chiffres, et chaque nombre se lit comme une case.
StructurePoint? _point(List<Trait> traits) {
  final hauteur = cadreDuGroupe(traits).height;
  final tries = traits.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  final ouvrante = tries.where((t) => _parenthese(t, hauteur) == 1).firstOrNull;
  if (ouvrante == null) return null;
  final fermante = tries
      .where((t) => _parenthese(t, hauteur) == -1)
      .where((t) => _c(t).left > _c(ouvrante).right)
      // La dernière : un `5` a le ventre d'une `)` (Pad 7).
      .lastOrNull;
  if (fermante == null) return null;
  final (o, f) = (_c(ouvrante), _c(fermante));
  final nom = [
    for (final t in tries)
      if (_c(t).center.dx < o.left) t,
  ];
  // Un seul signe devant : une lettre, pas `f` de `f(2;3)` ni un mot.
  if (nom.isEmpty || _glyphes(nom).length != 1) return null;
  if (cadreDuGroupe(nom).height < 0.5 * o.height) return null;
  final dedans = [
    for (final t in tries)
      if (!identical(t, ouvrante) &&
          !identical(t, fermante) &&
          _c(t).center.dx > o.right &&
          _c(t).center.dx < f.left)
        t,
  ];
  final queue = [
    for (final t in tries)
      if (_c(t).center.dx > f.right) t,
  ];
  if (dedans.length < 2) return null;
  // Le séparateur : un signe étroit qui descend sous les chiffres.
  final bas = _mediane(
    dedans.map(_c).where((c) => !_plat(c)).map((c) => c.bottom),
  );
  final haut = _mediane(
    dedans.map(_c).where((c) => !_plat(c)).map((c) => c.height),
  );
  final glyphes = _glyphes(dedans);
  final separateurs = [
    for (var i = 1; i < glyphes.length - 1; i++)
      if (cadreDuGroupe(glyphes[i]).width <= 0.45 * haut &&
          cadreDuGroupe(glyphes[i]).bottom > bas + 0.2 * haut &&
          cadreDuGroupe(glyphes[i]).height <= 1.4 * haut)
        i,
  ];
  if (separateurs.length != 1) {
    return _pointParTraits(nom, dedans, queue, bas: bas, haut: haut);
  }
  final k = separateurs.single;
  // Le point d'un `;` écrit à part, juste au-dessus de sa queue : il va avec
  // elle, pas avec le nombre d'à côté (téléphone d'Antsa).
  final queueDuSigne = cadreDuGroupe(glyphes[k]);
  bool point(int i) {
    if (i < 0 || i >= glyphes.length || i == k) return false;
    final c = cadreDuGroupe(glyphes[i]);
    return math.max(c.width, c.height) <= 0.35 * haut &&
        c.bottom <= queueDuSigne.top + 0.2 * haut &&
        c.center.dx >= queueDuSigne.left - 0.4 * haut &&
        c.center.dx <= queueDuSigne.right + 0.4 * haut;
  }

  final avant = point(k - 1) ? k - 1 : k;
  final apres = point(k + 1) ? k + 2 : k + 1;
  return StructurePoint(
    nom,
    [for (final g in glyphes.take(avant)) ...g],
    [for (final g in glyphes.skip(apres)) ...g],
    queue,
  );
}

/// `C(2;7)` quand le `;` touche le `2` (Pad 7, ADR 0047) : les signes qui
/// se chevauchent ne se séparent plus, on cherche le `;` trait par trait.
/// Sa queue : étroite, elle descend sous les chiffres ; un petit trait tout
/// près d'elle en fait partie, son point est juste au-dessus.
StructurePoint? _pointParTraits(
  List<Trait> nom,
  List<Trait> dedans,
  List<Trait> queue, {
  required double bas,
  required double haut,
}) {
  final queues = [
    for (final t in dedans)
      if (!_plat(_c(t)) &&
          _c(t).width <= 0.45 * haut &&
          _c(t).bottom > bas + 0.2 * haut &&
          _c(t).height <= 1.4 * haut)
        t,
  ];
  if (queues.isEmpty) return null;
  final signe = cadreDuGroupe(queues);
  if (signe.width > 0.6 * haut) return null;
  final points = [
    for (final t in dedans)
      if (!queues.contains(t) &&
          math.max(_c(t).width, _c(t).height) <= 0.35 * haut &&
          _c(t).bottom <= signe.top + 0.2 * haut &&
          _c(t).center.dx >= signe.left - 0.4 * haut &&
          _c(t).center.dx <= signe.right + 0.4 * haut)
        t,
  ];
  final premier = <Trait>[];
  final second = <Trait>[];
  for (final t in dedans) {
    if (queues.contains(t) || points.contains(t)) continue;
    (_c(t).center.dx < signe.center.dx ? premier : second).add(t);
  }
  if (premier.isEmpty || second.isEmpty) return null;
  return StructurePoint(nom, premier, second, queue);
}

/// Deux grands traits qui se font face, et des lignes de cases entre eux.
StructureMatrice? _matrice(List<Trait> traits) {
  final haut = cadreDuGroupe(traits).height;
  final grands = traits.where((t) {
    final c = _c(t);
    return c.height >= 0.6 * haut && c.width <= 0.5 * c.height;
  }).toList()..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  if (grands.length < 2) return null;
  final (g, d) = (grands.first, grands.last);
  final (cg, cd) = (_c(g), _c(d));
  final dedans = <Trait>[];
  final tete = <Trait>[];
  final queue = <Trait>[];
  for (final t in traits) {
    if (identical(t, g) || identical(t, d)) continue;
    final x = _c(t).center.dx;
    if (x < cg.center.dx) {
      tete.add(t);
    } else if (x > cd.center.dx) {
      queue.add(t);
    } else {
      dedans.add(t);
    }
  }
  if (dedans.length < 2) return null;

  // Les lignes : les cœurs des traits qui se chevauchent en hauteur.
  final parY = dedans.toList()
    ..sort((a, b) => _c(a).center.dy.compareTo(_c(b).center.dy));
  final lignes = <List<Trait>>[];
  double? bas;
  for (final t in parY) {
    final c = _c(t);
    final demi = math.max(0.35 * c.height, 4);
    if (bas == null || c.center.dy - demi > bas) {
      lignes.add([]);
      bas = c.center.dy + demi;
    } else {
      bas = math.max(bas, c.center.dy + demi);
    }
    lignes.last.add(t);
  }
  if (lignes.length < 2) return null;
  // Une ligne faite de traits plats n'est qu'un pied ou un tiret : `f(1)=`
  // au `1` à pied (téléphone d'Antsa) n'est pas une matrice (ADR 0047).
  if (lignes.any((l) => l.every((t) => _plat(_c(t))))) return null;

  final hauteur = _mediane(
    dedans.map(_c).where((c) => !_plat(c)).map((c) => c.height),
  );
  final decoupees = [for (final l in lignes) _colonnes(l, hauteur)];
  final comptes = decoupees.map((l) => l.length).toList()..sort();
  final colonnes = comptes[comptes.length ~/ 2];
  final cases = <List<List<Trait>>>[];
  for (final l in decoupees) {
    if (l.length < colonnes) return null;
    cases.add(_fondre(l, colonnes));
  }
  // `⁻¹` écrit haut après la parenthèse : un exposant, pas `- 1` (Pad 7).
  final haute =
      math.min(cg.top, cd.top) + 0.35 * math.max(cg.height, cd.height);
  final exposant = [
    for (final t in queue)
      if (_c(t).bottom < haute) t,
  ];
  return StructureMatrice(tete, cases, [
    for (final t in queue)
      if (!exposant.contains(t)) t,
  ], exposant: exposant);
}

/// Les cases d'une ligne : un écart net les sépare. Un signe moins, plat, va
/// toujours avec ce qui le suit.
List<List<Trait>> _colonnes(List<Trait> ligne, double hauteur) {
  final tries = ligne.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  final cases = <List<Trait>>[];
  for (final t in tries) {
    final c = _c(t);
    // Un moins commence une case : `-2 -8` fait deux cases, même serrées. La
    // barre d'un 7 ou d'un 4 tombe, elle, sur son chiffre.
    final surLeChiffre =
        cases.isNotEmpty && c.left < cadreDuGroupe(cases.last).right;
    final colle =
        cases.isNotEmpty &&
        (surLeChiffre ||
            (!_plat(c) &&
                !_plat(_c(cases.last.last)) &&
                c.left - cadreDuGroupe(cases.last).right < 0.45 * hauteur));
    final apresMoins =
        cases.isNotEmpty &&
        _plat(_c(cases.last.last)) &&
        c.left - _c(cases.last.last).right < 1.2 * hauteur;
    if (colle || apresMoins) {
      cases.last.add(t);
    } else {
      cases.add([t]);
    }
  }
  return cases;
}

/// Une ligne qui a trop de cases : on rapproche les plus proches.
List<List<Trait>> _fondre(List<List<Trait>> ligne, int colonnes) {
  final cases = ligne.toList();
  while (cases.length > colonnes) {
    var meilleur = 0;
    var ecart = double.infinity;
    for (var i = 0; i + 1 < cases.length; i++) {
      final e =
          cadreDuGroupe(cases[i + 1]).left - cadreDuGroupe(cases[i]).right;
      if (e < ecart) (meilleur, ecart) = (i, e);
    }
    cases
      ..[meilleur] = [...cases[meilleur], ...cases[meilleur + 1]]
      ..removeAt(meilleur + 1);
  }
  return cases;
}

/// `A =` devant une matrice : la lettre déclarée, sinon `null`. Le `=` se
/// voit au tracé (deux plats empilés en dernier) ; la lettre, lue par le
/// modèle ou reconnue à son tracé.
String? _declarationDeMatrice(String lu, List<Trait> tete) {
  final propre = lu.replaceAll(RegExp(r'[\s{}]'), '');
  final m = RegExp(r'^([A-Z])=$').firstMatch(propre);
  if (m != null) return m[1];
  if (tete.length < 3) return null;
  final glyphes = _glyphes(tete);
  if (glyphes.length != 2) return null;
  if (_signeSimple(glyphes.last) != '=') return null;
  final (lettre, ecart) = essayerCapitale(_dessin(glyphes.first));
  return ecart < 1.5 ? lettre : null;
}

/// `d e t`, `\alpha +`, `c t +`, `\det` : le nom écrit devant une matrice.
bool ressembleADet(String tete) {
  final t = tete.replaceAll(RegExp(r'\s'), '').replaceAll('+', '');
  if (t.isEmpty) return false;
  if (RegExp(r'\\(det|alpha|delta)').hasMatch(t)) return true;
  // `\tau l e t`, `\phi e^{\pi}` : des lettres seules, sans chiffre ni signe,
  // juste devant une matrice : on n'écrit guère que `det` ainsi.
  return RegExp(r'^[a-zA-Z\\^{}]{2,16}$').hasMatch(t);
}

/// Seuls, un `=` ou un `-` trompent le modèle : ils se voient sur les traits.
String? _signeSimple(List<Trait> traits) {
  final cadres = traits.map(_c).toList();
  if (!cadres.every(_plat)) return null;
  if (cadres.length == 1) return '-';
  if (cadres.length == 2) {
    final (a, b) = (cadres[0], cadres[1]);
    final recouvrement = math.min(a.right, b.right) - math.max(a.left, b.left);
    final empiles = (a.center.dy - b.center.dy).abs() > 4;
    if (empiles && recouvrement > 0.4 * math.min(a.width, b.width)) {
      return '=';
    }
  }
  return null;
}

/// Lit [traits] par morceaux, si une structure s'y voit ; sinon `null`. Un
/// morceau illisible rend `null` : le modèle lira alors le tout.
Future<String?> lireStructure(Lecteur lecteur, List<Trait> traits) async {
  final structure = trouverStructure(traits);
  if (structure == null) return null;

  Future<String> morceau(List<Trait> t) async => t.isEmpty
      ? ''
      : (_signeSimple(t) ?? await _lireMorceau(lecteur, t)).trim();

  switch (structure) {
    case StructureNorme(:final dedans, :final queue):
      final interieur = await morceau(dedans);
      if (interieur.isEmpty) return null;
      return '\\|$interieur\\|${await morceau(queue)}';
    case StructurePoint(
      :final nom,
      :final premier,
      :final second,
      :final queue,
    ):
      final (lettre, ecart) = essayerCapitale(_dessin(nom));
      final lu = ecart < 1.5
          ? lettre
          : _lettreLue(await lecteur.lireCourt(nom));
      if (lu == null) return null;
      final nombres = await _lireLigne(lecteur, [premier, second]);
      if (nombres == null) return null;
      return '$lu(${nombres.join(';')})${await morceau(queue)}';
    case StructureLimite(
      :final mot,
      :final variable,
      :final cible,
      :final queue,
    ):
      final luMot = await lecteur.lire(mot);
      if (!luMot.contains('lim') &&
          motSur(
                classerMots(mot, lexique: const ['lim', 'sin', 'cos', 'ln']),
                seuil: 2,
              ) !=
              'lim') {
        return null;
      }
      final lettre =
          _lettreMinuscule(await lecteur.lireCourt(variable)) ??
          (_estX(variable) ? 'x' : null);
      if (lettre == null) return null;
      final vers =
          _exposantAuTrace(cible) ??
          _cibleDeLimite(await lecteur.lireCourt(cible));
      if (vers == null) return null;
      final lu = await morceau(queue);
      if (lu.isEmpty) return null;
      final corps = redresserEgal(queue, lu);
      return '\\lim_{$lettre \\to $vers} $corps';
    case StructureSomme(:final haut, :final bas, :final corps):
      final somme = await morceau(corps);
      if (somme.isEmpty) return null;
      // L'indice : la seule minuscule du corps, plus sûre que la lecture de
      // la borne (`n` lu `x` ou `4`).
      final lettres = RegExp(r'(?<![\\a-zA-Z])[a-z](?![a-zA-Z])')
          .allMatches(somme.replaceAll(RegExp(r'\\[a-zA-Z]+'), ' '))
          .map((m) => m[0]!)
          .toSet();
      // La borne du bas, coupée à son `=` : `k = 1`, même serrés (ADR 0046).
      final borne = _borneDuBas(bas);
      final glyphesBas = _glyphes(bas);
      final traitsIndice = borne?.indice ?? glyphesBas.first;
      final indice = lettres.length == 1
          ? lettres.single
          : _indiceAuTrace(traitsIndice) ??
                _lettreMinuscule(await lecteur.lireCourt(traitsIndice));
      if (indice == null) return null;
      // Les chiffres après le `=`, au tracé ; le modèle sinon.
      final debut =
          (borne != null
              ? borne.debut
              : _bornesAuTrace(glyphesBas.skip(1).toList())) ??
          _borneDuModele(await lecteur.lireCourt(bas));
      if (debut == null) return null;
      final fin = haut.isEmpty
          ? null
          : _exposantAuTrace(haut) ??
                _borneDuModele(await lecteur.lireCourt(haut));
      if (haut.isNotEmpty && fin == null) return null;
      final dessus = fin == null ? '' : '^{$fin}';
      return '\\sum_{$indice=$debut}$dessus $somme';
    case StructureFleche(:final nom, :final queue):
      final lettres = [
        for (final g in _glyphes(nom)) classeurCourant.capitale(g),
      ];
      final parTrace = lettres.contains(null) ? null : lettres.join();
      // Une seule lettre sous une flèche : un vecteur `u`, en minuscule.
      final lu = parTrace != null && parTrace.length <= 2
          ? (parTrace.length == 1 ? parTrace.toLowerCase() : parTrace)
          : (await morceau(nom)).replaceAll(RegExp(r'\s'), '');
      if (!RegExp(r'^[A-Za-z]{1,2}$').hasMatch(lu)) return null;
      return '\\overrightarrow{$lu}${await morceau(queue)}';
    case StructureMatrice(
      :final tete,
      :final cases,
      :final queue,
      :final exposant,
    ):
      final lignes = <String>[];
      for (final ligne in cases) {
        final valeurs = await _lireLigne(lecteur, ligne);
        if (valeurs == null) return null;
        lignes.add(valeurs.join('&'));
      }
      final matrice = '\\begin{pmatrix}${lignes.join(r'\\')}\\end{pmatrix}';
      // Le nom devant : jamais une structure, le `e` de `det` a une barre.
      final avant = tete.isEmpty ? '' : (await lecteur.lire(tete)).trim();
      // `²` seul, le modèle y lit `Σ` (téléphone d'Antsa) : le tracé d'abord.
      final expo = exposant.isEmpty
          ? null
          : _exposantAuTrace(exposant) ?? _sansEspace(await morceau(exposant));
      final puissance = expo == null ? '' : '^{$expo}';
      final apres = '$puissance${await morceau(queue)}';
      // Devant une matrice, seul un nombre ou une lettre multiplie ; un mot
      // mal lu, `φe^{1/2}` (Pad 7), est le `det` écrit à la main.
      final facteur = RegExp(
        r'^\s*[-+]?\s*(\d[\d\s.,]*|[a-zA-Z])?\s*(\\cdot|\\times)?\s*$',
      ).hasMatch(avant);
      // `A =` devant : une matrice déclarée, jamais un `det` (Pad 7 d'Antsa :
      // `A = (3×3)` donnait `= −1`). Une capitale seule, lue au tracé si le
      // modèle hésite (`A=`, `\Lambda=`, `\alpha=`).
      final declaration = _declarationDeMatrice(avant, tete);
      if (declaration != null) return '$declaration=$matrice$apres';
      final nom = ressembleADet(avant) || !facteur ? r'\det ' : avant;
      return '$nom$matrice$apres';
  }
}

/// Une capitale lue par le modèle : `β` est un `B` mal lu.
/// `k = 1` : l'indice et la valeur de part et d'autre du `=` (deux plats
/// l'un sur l'autre). Couper au `=` plutôt que par signes qui se
/// chevauchent : un `=` serré contre le `k` s'y collait, et un `k` en deux
/// traits se coupait en deux (`L=1-L`, Pad 7). `null` sans `=` net ;
/// `debut` est `null` si la valeur ne se lit pas au tracé.
({List<Trait> indice, String? debut})? _borneDuBas(List<Trait> bas) {
  final hauteur = cadreDuGroupe(bas).height;
  final plats = [
    for (final t in bas)
      if (_plat(_c(t)) && _c(t).height <= 0.3 * hauteur) t,
  ];
  List<Trait>? egal;
  for (var i = 0; i < plats.length && egal == null; i++) {
    for (var j = i + 1; j < plats.length; j++) {
      final (a, b) = (_c(plats[i]), _c(plats[j]));
      final commun = math.min(a.right, b.right) - math.max(a.left, b.left);
      final ecart = (a.center.dy - b.center.dy).abs();
      if (commun > 0.5 * math.min(a.width, b.width) &&
          ecart > 2 &&
          ecart < 1.2 * math.max(a.width, b.width)) {
        egal = [plats[i], plats[j]];
        break;
      }
    }
  }
  if (egal == null) return null;
  final milieu = cadreDuGroupe(egal).center.dx;
  final indice = <Trait>[];
  final valeur = <Trait>[];
  for (final t in bas) {
    if (egal.contains(t)) continue;
    (_c(t).center.dx < milieu ? indice : valeur).add(t);
  }
  if (indice.isEmpty || valeur.isEmpty) return null;
  final moins = _signeMoins(valeur);
  final chiffres = [
    for (final g in _glyphes([
      for (final t in valeur)
        if (!moins.contains(t)) t,
    ]))
      classeurCourant.chiffre(g),
  ];
  final debut = chiffres.isEmpty || chiffres.contains(null)
      ? null
      : '${moins.isEmpty ? '' : '-'}${chiffres.join()}';
  return (indice: indice, debut: debut);
}

/// L'indice d'une somme lu au tracé : une seule minuscule, sûre.
String? _indiceAuTrace(List<Trait> traits) {
  final lu = classeurCourant.signe(
    traits,
    hauteurLigne: cadreDuGroupe(traits).height,
  );
  if (lu == null) return null;
  final minuscules = lu.keys.where((s) => RegExp(r'^[a-z]$').hasMatch(s));
  // `l` et `1`, `o` et `0` : un indice ne s'écrit pas ainsi.
  if (minuscules.length != 1 || lu.keys.any(_estChiffreSeul)) return null;
  return minuscules.single;
}

bool _estChiffreSeul(String s) => RegExp(r'^[0-9]$').hasMatch(s);

/// Après le `=` d'une borne : les chiffres, lus au tracé ; `null` sinon.
String? _bornesAuTrace(List<List<Trait>> glyphes) {
  // Le `=` (deux plats) ou `:` écrit vite, puis les chiffres.
  final chiffres = <String>[];
  var apresEgal = false;
  for (final g in glyphes) {
    final c = cadreDuGroupe(g);
    if (!apresEgal) {
      if (g.every((t) => _plat(_c(t))) || c.width < 0.3 * c.height) {
        apresEgal = true;
      }
      continue;
    }
    final lu = classeurCourant.chiffre(g);
    if (lu == null) return null;
    chiffres.add(lu);
  }
  return apresEgal && chiffres.isNotEmpty ? chiffres.join() : null;
}

/// `n=0`, `k = 1`, `5`, `\infty` lus par le modèle : la valeur seule.
String? _borneDuModele(String lu) {
  final propre = lu.replaceAll(RegExp(r'[\s{}]'), '');
  final m = RegExp(r'^(?:[a-z]=)?([+-]?\d+|\\infty|[+-]\\infty)$')
      .firstMatch(propre);
  return m?[1];
}

/// La variable d'une limite : une minuscule, `x` le plus souvent.
String? _lettreMinuscule(String lu) {
  final propre = lu.replaceAll(RegExp(r'[\s{}]'), '');
  if (RegExp(r'^[a-z]$').hasMatch(propre)) return propre;
  const proches = {r'\chi': 'x', r'\times': 'x', 'X': 'x', r'\gamma': 'y'};
  return proches[propre];
}

/// Deux traits qui se croisent ou se font face, de même taille : un `x`.
bool _estX(List<Trait> traits) {
  if (traits.length != 2) return false;
  final (a, b) = (_c(traits[0]), _c(traits[1]));
  final taille = math.max(a.width, b.width);
  return (a.center - b.center).distance < 0.5 * taille &&
      a.height > 0.5 * a.width &&
      b.height > 0.5 * b.width;
}

/// `0`, `+\infty`, `-\infty`, `0^+` : ce vers quoi tend la variable.
String? _cibleDeLimite(String lu) {
  final propre = lu.replaceAll(RegExp(r'[\s{}]'), '');
  if (RegExp(r'^[+-]?(\d+|\\infty)(\^[+-])?$').hasMatch(propre)) return propre;
  const proches = {
    r'\sim': r'\infty',
    r'\propto': r'\infty',
    'O': '0',
    'o': '0',
  };
  return proches[propre];
}

String? _lettreLue(String lu) {
  const proches = {r'\beta': 'B', r'\alpha': 'A', r'\Delta': 'A'};
  final propre = lu.replaceAll(RegExp(r'[\s{}]'), '');
  final proche = proches[propre];
  if (proche != null) return proche;
  return RegExp(r'^[A-Z]$').hasMatch(propre) ? propre : null;
}

Future<String> _lireMorceau(Lecteur lecteur, List<Trait> traits) async =>
    await lireStructure(lecteur, traits) ?? await lecteur.lire(traits);

/// Les traits du moins d'une case : plats, et à gauche de tout le reste.
List<Trait> _signeMoins(List<Trait> kase) {
  final corps = kase.where((t) => !_plat(_c(t))).toList();
  if (corps.isEmpty) return const [];
  final debut = cadreDuGroupe(corps).left;
  return [
    for (final t in kase)
      if (_plat(_c(t)) && _c(t).right <= debut + 0.3 * _c(t).width) t,
  ];
}

/// Combien de signes dans une case : les corps qui ne se chevauchent pas.
int _signes(List<Trait> corps) {
  final tries = corps.map(_c).toList()
    ..sort((a, b) => a.left.compareTo(b.left));
  var n = 0;
  var droite = double.negativeInfinity;
  for (final c in tries) {
    if (_plat(c)) continue;
    if (c.left > droite + 3) n++;
    droite = math.max(droite, c.right);
  }
  return n;
}

/// Les signes d'un morceau : les traits qui se chevauchent en largeur.
/// Les signes d'une ligne, de gauche à droite : des traits qui se
/// chevauchent en largeur font un seul signe.
List<List<Trait>> glyphesDe(List<Trait> traits) => _glyphes(traits);

List<List<Trait>> _glyphes(List<Trait> traits) {
  final tries = traits.toList()
    ..sort((a, b) => _c(a).left.compareTo(_c(b).left));
  final groupes = <List<Trait>>[];
  for (final t in tries) {
    if (groupes.isNotEmpty &&
        // Deux lettres écrites serrées se touchent presque : il faut qu'elles
        // se chevauchent vraiment pour faire un seul signe ; ou le bras d'un
        // `k` qui touche sa hampe (ADR 0046).
        (_c(t).left <= cadreDuGroupe(groupes.last).right ||
            accrocheAUneHampe(t, groupes.last))) {
      groupes.last.add(t);
    } else {
      groupes.add([t]);
    }
  }
  return groupes;
}

List<List<Offset>> _dessin(List<Trait> g) => [
  for (final t in g) [for (final p in t.points) p.position],
];

/// Une ligne de matrice. Seul, un chiffre trompe le modèle (`1` lu `Λ`) :
/// on le reconnaît sur son tracé, et les moins se voient. Si un signe résiste,
/// le modèle lit la ligne entière, sans les moins.
Future<List<String>?> _lireLigne(
  Lecteur lecteur,
  List<List<Trait>> ligne,
) async {
  final moins = [for (final kase in ligne) _signeMoins(kase)];
  final corps = [
    for (var i = 0; i < ligne.length; i++)
      [
        for (final t in ligne[i])
          if (!moins[i].contains(t)) t,
      ],
  ];
  final parTrace = <String?>[];
  for (var i = 0; i < corps.length; i++) {
    final chiffres = [
      for (final g in _glyphes(corps[i])) classeurCourant.chiffre(g),
    ];
    parTrace.add(
      chiffres.isEmpty || chiffres.contains(null)
          ? null
          : '${moins[i].isEmpty ? '' : '-'}${chiffres.join()}',
    );
  }
  if (!parTrace.contains(null)) return parTrace.cast<String>();

  final attendus = [for (final c in corps) _signes(c)];
  final total = attendus.fold(0, (s, n) => s + n);
  List<String> signesDe(String lu) =>
      RegExp('[0-9a-zA-Z]')
          .allMatches(lu.replaceAll(RegExp(r'\\[a-zA-Z]+'), ' '))
          .map((m) => m[0]!)
          .toList();
  var signes = signesDe(await lecteur.lire([for (final c in corps) ...c]));
  // Sans ses moins, `8 1` peut se lire `8` (Pad 7) ; avec eux, `8 - 1`.
  if (signes.length != total && moins.any((m) => m.isNotEmpty)) {
    signes = signesDe(await lecteur.lire([for (final k in ligne) ...k]));
  }
  if (signes.length == total) {
    final valeurs = <String>[];
    var k = 0;
    for (var i = 0; i < ligne.length; i++) {
      final v = signes.sublist(k, k + attendus[i]).join();
      k += attendus[i];
      valeurs.add(moins[i].isEmpty ? v : '-$v');
    }
    return valeurs;
  }
  // Le tracé hésite, mais reste proche pour chaque signe : mieux qu'une
  // case lue seule, que le modèle ne sait pas lire (`8` lu `\overbrace`).
  final proches = <String>[];
  for (var i = 0; i < corps.length; i++) {
    final essais = [
      for (final g in _glyphes(corps[i])) essayerChiffre(_dessin(g)),
    ];
    if (essais.isEmpty || essais.any((e) => e.$2 > 1.3)) break;
    proches.add(
      '${moins[i].isEmpty ? '' : '-'}${essais.map((e) => e.$1).join()}',
    );
  }
  if (proches.length == corps.length) return proches;
  // Sinon, case par case : le tracé quand il est sûr (le `4` ouvert
  // d'Antsa, que le modèle lit `1/1`), le modèle sur une image large sinon.
  final valeurs = <String>[];
  for (var i = 0; i < ligne.length; i++) {
    final sure = parTrace[i];
    if (sure != null) {
      valeurs.add(sure);
      continue;
    }
    var v = _case(await lecteur.lireCourt(ligne[i]));
    // `- 2 5` lu `2 5` : le moins se voit au tracé, les chiffres se collent
    // (`B(2;-25)` lu `B(2;2 5)`, Pad 7, ADR 0047).
    v = v
        .replaceAllMapped(RegExp(r'(\d)\s+(?=\d)'), (m) => m[1]!)
        .replaceFirst(RegExp(r'^-\s+'), '-');
    if (moins[i].isNotEmpty && !v.startsWith('-')) v = '-$v';
    if (!_caseLisible(v)) return null;
    valeurs.add(v);
  }
  return valeurs;
}

/// Un nombre, une lettre, une courte expression : pas le bruit d'une case mal
/// lue, `\overbrace { \alpha }` ou `\frac { 5 } { - }`.
bool _caseLisible(String v) {
  if (v.isEmpty || v.contains(r'\overbrace') || v.contains(r'\vphantom')) {
    return false;
  }
  try {
    analyserLatex(v);
    return true;
  } on ErreurLatex {
    return false;
  }
}

/// Une case lue seule : `- 5`, `4`, parfois avec un habillage inutile.
String _case(String lu) =>
    lu.replaceAll(RegExp(r'\\(left|right)\b'), '').trim();

/// La lecture la plus fiable : par structure si elle se voit.
Future<String> lireAuMieux(Lecteur lecteur, List<Trait> traits) async {
  final structuree = await lireStructure(lecteur, traits);
  if (structuree != null && plausibilite(structuree) > -50) return structuree;
  return await lecteur.lire(traits);
}

/// Les signes plats d'une ligne, de gauche à droite : `=` (deux traits
/// plats l'un sur l'autre) ou `-`. Une barre de fraction, avec de l'encre
/// dessus et dessous, n'en est pas un.
List<String> signesPlats(List<Trait> traits) {
  final cadres = traits.map(_c).toList();
  // La barre d'un `t` ou d'un `7` est plate, mais croise un autre trait.
  // Et un signe est fin : un mot cursif, `longueur`, est plat mais épais.
  final ligne = cadreDuGroupe(traits).height;
  final debout = cadres.where((c) => !_plat(c)).toList();
  final plats = [
    for (final c in cadres)
      if (_plat(c) &&
          c.width >= 6 &&
          c.height <= 0.25 * ligne &&
          !debout.any(c.deflate(1).overlaps))
        c,
  ]..sort((a, b) => a.left.compareTo(b.left));
  bool barre(Rect p) {
    bool dessus(Rect c) =>
        c.center.dx > p.left && c.center.dx < p.right && c.bottom < p.top;
    bool dessous(Rect c) =>
        c.center.dx > p.left && c.center.dx < p.right && c.top > p.bottom;
    final autres = cadres.where((c) => !identical(c, p)).toList();
    return autres.any(dessus) && autres.any(dessous);
  }

  final signes = <String>[];
  final pris = <Rect>{};
  for (final p in plats) {
    if (pris.contains(p) || barre(p)) continue;
    final jumeau = plats
        .where((q) => !identical(q, p) && !pris.contains(q))
        .where((q) {
          final commun = math.min(p.right, q.right) - math.max(p.left, q.left);
          final ecart = (q.center.dy - p.center.dy).abs();
          return commun > 0.5 * math.min(p.width, q.width) &&
              ecart > 2 &&
              // Un `=` écrit vite a ses traits écartés (Pad 7, stylet).
              ecart < 1.2 * math.max(p.width, q.width);
        })
        .firstOrNull;
    if (jumeau != null) {
      pris.addAll([p, jumeau]);
      signes.add('=');
    } else {
      pris.add(p);
      signes.add('-');
    }
  }
  return signes;
}

/// Les traits finissent par un `=` : deux plats l'un sur l'autre, à droite
/// de tout le reste. Le modèle l'oublie quand il est haut, au niveau d'une
/// barre de fraction (`lim 1/(x−3)² =`, Pad 7, ADR 0047).
bool finitParEgal(List<Trait> traits) {
  final cadres = [for (final t in traits) _c(t)];
  for (var i = 0; i < cadres.length; i++) {
    for (var j = 0; j < cadres.length; j++) {
      if (i == j) continue;
      final (a, b) = (cadres[i], cadres[j]);
      if (!_plat(a) || !_plat(b) || a.width < 6 || b.width < 6) continue;
      if (a.center.dy >= b.center.dy) continue;
      final commun = math.min(a.right, b.right) - math.max(a.left, b.left);
      final ecart = b.center.dy - a.center.dy;
      if (commun < 0.5 * math.min(a.width, b.width) ||
          ecart < 2 ||
          ecart > 1.2 * math.max(a.width, b.width)) {
        continue;
      }
      // Rien plus à droite que son milieu : l'exposant d'à côté peut
      // passer dessous (`(x−3)² =`).
      final milieu = a.expandToInclude(b).center.dx;
      var dernier = true;
      for (var k = 0; k < cadres.length && dernier; k++) {
        if (k != i && k != j && cadres[k].center.dx >= milieu) dernier = false;
      }
      if (dernier) return true;
    }
  }
  return false;
}

/// `e^x = 7` lu `e^{x} - 7` (Pad 7) : le trait du dessus, arrondi, a échappé
/// au modèle. Si les traits montrent un `=` que la lecture n'a pas, et un
/// moins de trop à sa place, ce moins redevient `=`.
String redresserEgal(List<Trait> traits, String latex) {
  if (latex.contains('=')) return latex;
  if (finitParEgal(traits)) return '$latex=';
  final signes = signesPlats(traits);
  if (signes.where((s) => s == '=').length != 1) return latex;
  final moins = RegExp(r'(?<!\\)-').allMatches(latex).toList();
  final moinsTraces = signes.where((s) => s == '-').length;
  if (moins.length != moinsTraces + 1) return latex;
  final rang = signes.indexOf('=');
  final m = moins[rang];
  return latex.replaceRange(m.start, m.end, '=');
}

/// `2^{3}-2x^{6}=` pour `e³ − 2e⁶ =` (Pad 7) : le modèle lit mal le `e`
/// cursif d'Antsa (`c`, `2`, `x`), que son tracé reconnaît sans doute. Quand
/// le modèle et le tracé comptent autant de signes, chaque signe que le
/// tracé lit sûrement `e` (une seule lecture) remplace celui du modèle ; la
/// forme de la ligne (exposants, opérateurs) reste celle du modèle. Une
/// lecture qu'on ne sait pas aligner ne change pas. Seul le `e` : sur des
/// signes isolés, les autres lectures « sûres » des gabarits se trompent
/// encore trop (ADR 0041).
String redresserLettres(List<Trait> traits, String latex) {
  // Les signes du modèle, dans l'ordre : on n'aligne que des lignes
  // simples (ni fraction, ni racine, ni nom de fonction).
  final jetons = <(int, int)>[];
  for (var i = 0; i < latex.length; i++) {
    final car = latex[i];
    if (car == r'\') {
      final m = RegExp(r'\\([a-zA-Z]+)').matchAsPrefix(latex, i);
      if (m == null) return latex;
      final nom = m[1]!;
      if (nom == 'left' || nom == 'right') {
        i = m.end - 1;
        continue;
      }
      if (nom != 'times' && nom != 'cdot') return latex;
      jetons.add((i, m.end));
      i = m.end - 1;
      continue;
    }
    if (' {}^_'.contains(car)) continue;
    jetons.add((i, i + 1));
  }
  final signes = signesDeLaLigne(traits);
  if (signes.length != jetons.length || signes.isEmpty) return latex;
  final hauteurs = [for (final g in signes) cadreDuGroupe(g).height]..sort();
  final hauteur = hauteurs[hauteurs.length ~/ 2];
  final alnum = RegExp(r'^[0-9a-zA-Z]$');
  final sortie = StringBuffer();
  var depuis = 0;
  for (var k = 0; k < signes.length; k++) {
    final (debut, fin) = jetons[k];
    final lu = latex.substring(debut, fin);
    if (!alnum.hasMatch(lu)) continue;
    final impose = classeurCourant.impose(signes[k]);
    final trace =
        impose ??
        switch (classeurCourant.signe(signes[k], hauteurLigne: hauteur)) {
          final Map<String, double> m when m.length == 1 => m.keys.single,
          _ => null,
        };
    if (trace != 'e' || trace == lu) continue;
    sortie
      ..write(latex.substring(depuis, debut))
      ..write(trace);
    depuis = fin;
  }
  sortie.write(latex.substring(depuis));
  return sortie.toString();
}

/// `AB =` : deux capitales seules, que le modèle lit `λ·β` (Pad 7). Si les
/// deux se reconnaissent à leur tracé et sont des points de la feuille, c'est
/// leur nom, avec le `=` s'il y est ; sinon `null`.
String? lireNomDePoints(List<Trait> traits, Set<String> points) {
  if (points.length < 2) return null;
  final cadres = traits.map(_c).toList();
  final ligne = cadreDuGroupe(traits).height;
  final debout = cadres.where((c) => !_plat(c)).toList();
  // La barre du `A` reste au `A` : seuls les signes, libres, s'en vont.
  final plats = [
    for (final t in traits)
      if (_plat(_c(t)) &&
          _c(t).height <= 0.25 * ligne &&
          !debout.any(_c(t).deflate(1).overlaps))
        t,
  ];
  final lettres = [
    for (final t in traits)
      if (!plats.contains(t)) t,
  ];
  if (lettres.isEmpty || cadres.isEmpty) return null;
  final glyphes = _glyphes(lettres);
  if (glyphes.length != 2) return null;
  final noms = <String>[];
  for (final g in glyphes) {
    final (lettre, ecart) = essayerCapitale(_dessin(g));
    if (ecart > 1.6 || !points.contains(lettre)) return null;
    noms.add(lettre);
  }
  final egal = signesPlats(traits);
  if (egal.any((s) => s != '=')) return null;
  return '${noms.join()}${egal.isEmpty ? '' : '='}';
}
