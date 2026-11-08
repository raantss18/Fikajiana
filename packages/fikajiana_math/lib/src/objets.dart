import 'package:fikajiana_math/src/analyse.dart';
import 'package:fikajiana_math/src/evaluateur.dart';

/// Un point ou un vecteur déclaré sur la feuille : `A(1;2)`, `\vec{AB}(1;3)`.
sealed class ObjetLu {
  const new(this.nom, this.x, this.y);

  /// `A`, `AB`, `u`.
  final String nom;

  /// Première coordonnée.
  final double x;

  /// Seconde coordonnée.
  final double y;
}

/// `A(1;2)`.
class PointLu extends ObjetLu {
  /// Crée le point.
  const new(super.nom, super.x, super.y);
}

/// `\vec{AB}(1;3)`, `\vec{u}(1;3)`, ou une colonne `\begin{pmatrix}1\\3\end{pmatrix}`.
class VecteurLu extends ObjetLu {
  /// Crée le vecteur.
  const new(super.nom, super.x, super.y);
}

/// Ce qu'une commande de la Feuille construit dans la Figure.
enum GenreCommande {
  /// `(AB)`, `droite(A;B)`.
  droite,

  /// `[AB]`, `segment(A;B)`.
  segment,

  /// `[AB)`, `demi-droite(A;B)`.
  demiDroite,

  /// `cercle(A;B)` : de centre A, passant par B.
  cercle,

  /// `cercle(A;2)` : de centre A, de rayon 2.
  cercleRayon,

  /// `milieu(A;B)`, `I=milieu(A;B)`.
  milieu,

  /// `mediatrice(A;B)`.
  mediatrice,

  /// `parallèle((AB);C)`, `parallèle(d;C)` : par C, parallèle à la droite.
  parallele,

  /// `perpendiculaire((AB);C)` : par C, perpendiculaire à la droite.
  perpendiculaire,

  /// `bissectrice(A;B;C)` : de l'angle en B.
  bissectrice,

  /// `tangente(C;A)` : au cercle C, passant par A.
  tangente,

  /// `symétrique(A;B)` par rapport au point B, `symétrique(A;(BC))` par
  /// rapport à la droite.
  symetrique,

  /// `projeté(A;(BC))` : projeté orthogonal de A sur la droite.
  projete,

  /// `I=intersection((AB);(CD))`.
  intersection,

  /// `triangle(A;B;C)`, `polygone(A;B;C;D)`.
  polygone,
}

/// Ce dont part une construction : un point, une droite `(AB)` ou un objet
/// déjà nommé dans la Figure (`d`, `\mathcal{C}`).
sealed class ArgumentGeo {
  const new();
}

/// Un point déclaré : `A`.
class ArgPoint extends ArgumentGeo {
  /// Crée l'argument.
  const new(this.nom);

  /// Son nom.
  final String nom;
}

/// Une droite, un segment ou une demi-droite par deux points : `(AB)`.
class ArgLigne extends ArgumentGeo {
  /// Crée l'argument.
  const new(this.genre, this.a, this.b);

  /// [GenreCommande.droite], [GenreCommande.segment] ou
  /// [GenreCommande.demiDroite].
  final GenreCommande genre;

  /// Le premier point.
  final String a;

  /// Le second point.
  final String b;
}

/// Un objet nommé de la Figure : `d`, `\mathcal{C}`.
class ArgNomme extends ArgumentGeo {
  /// Crée l'argument.
  const new(this.nom);

  /// Son nom.
  final String nom;
}

/// `cercle(A;2)`, `(AB)`, `[AB]`, `I=milieu(A;B)` : une construction écrite
/// sur la Feuille, à faire dans la Figure avec des points déjà déclarés.
class CommandeGeo {
  /// Crée la commande.
  const new(
    this.genre,
    this.points, {
    this.rayon,
    this.nom,
    this.arguments = const [],
  });

  /// Ce qu'elle construit.
  final GenreCommande genre;

  /// Les noms des points dont elle part, dans l'ordre, chacun une fois.
  final List<String> points;

  /// Le rayon d'un cercle de rayon donné.
  final double? rayon;

  /// Le nom donné au résultat : `I` dans `I=milieu(A;B)`.
  final String? nom;

  /// Dans l'ordre écrit, ce dont part une construction qui accepte autre
  /// chose que des points (`parallèle(d;C)`) ; vide pour les autres.
  final List<ArgumentGeo> arguments;

  /// Les objets nommés dont elle part : ils doivent être dans la Figure.
  List<String> get objets => [
    for (final a in arguments)
      if (a case ArgNomme(:final nom)) nom,
  ];
}

final Map<String, GenreCommande> _motsCommandes = {
  'cercle': GenreCommande.cercle,
  'droite': GenreCommande.droite,
  'segment': GenreCommande.segment,
  'demidroite': GenreCommande.demiDroite,
  'demi-droite': GenreCommande.demiDroite,
  'milieu': GenreCommande.milieu,
  'mediatrice': GenreCommande.mediatrice,
  'médiatrice': GenreCommande.mediatrice,
};

/// Les commandes dont les arguments peuvent être des droites ou des noms,
/// écrites sans accent ni tiret.
const Map<String, GenreCommande> _motsConstructions = {
  'parallele': GenreCommande.parallele,
  'perpendiculaire': GenreCommande.perpendiculaire,
  'bissectrice': GenreCommande.bissectrice,
  'tangente': GenreCommande.tangente,
  'symetrique': GenreCommande.symetrique,
  'projete': GenreCommande.projete,
  'projeteorthogonal': GenreCommande.projete,
  'intersection': GenreCommande.intersection,
  'triangle': GenreCommande.polygone,
  'polygone': GenreCommande.polygone,
};

/// Les commandes de géométrie en toutes lettres, pour le Guide et la saisie.
List<String> get motsDeGeometrie => [
  ..._motsCommandes.keys.where((m) => !m.contains('-') && !m.contains('é')),
  ..._motsConstructions.keys,
];

/// Un nom de résultat : `I`, `d`, `d_1`, `A'`.
const _nomResultat = r"[A-Za-z](?:_\{?[0-9]+\}?|')?";

/// La construction que dit [latex], ou `null`.
CommandeGeo? lireCommande(String latex) {
  final s = latex
      .replaceAll(RegExp(r'\\(?:left|right)\b'), '')
      .replaceAllMapped(
        RegExp(
          r'\\(?:mathrm|text|operatorname|mathit|rm|mathcal|mathscr)\s*'
          r'\{([^{}]*)\}',
        ),
        (m) => m[1]!,
      )
      .replaceAll(r'\{', '{')
      .replaceAll(r'\}', '}')
      .replaceAll(RegExp(r"\\prime|\^\{?'\}?"), "'")
      .replaceAll(RegExp(r'\s'), '');
  // `(AB)`, `[AB]`, `[AB)`, `d=(AB)` : l'écriture du cours.
  final court = RegExp('^(?:($_nomResultat)=)?([(\\[])([A-Z])([A-Z])([)\\]])\$')
      .firstMatch(s);
  if (court != null) {
    final genre = _genreLigne(court[2]!, court[5]!);
    if (genre == null) return null;
    return CommandeGeo(genre, [court[3]!, court[4]!], nom: _nom(court[1]));
  }
  final general = RegExp('^(?:($_nomResultat)=)?([A-Za-zÀ-ÿ\\-]+)\\((.+)\\)\$')
      .firstMatch(s);
  if (general != null) {
    final mot = general[2]!
        .toLowerCase()
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll('-', '');
    final genre = _motsConstructions[mot];
    if (genre != null) {
      return _construction(genre, _separer(general[3]!), _nom(general[1]));
    }
  }
  final m = RegExp(
    '^(?:($_nomResultat)=)?([a-zéè\\-]+)\\(([A-Z])[;,|]?([A-Z]|[^)]+)\\)\$',
  ).firstMatch(s);
  if (m == null) return null;
  var genre = _motsCommandes[m[2]!.toLowerCase()];
  if (genre == null) return null;
  final premier = m[3]!;
  final second = m[4]!;
  final nom = _nom(m[1]);
  if (RegExp(r'^[A-Z]$').hasMatch(second)) {
    return CommandeGeo(genre, [premier, second], nom: nom);
  }
  // Un nombre après le centre : le rayon.
  if (genre != GenreCommande.cercle) return null;
  final rayon = _valeur(second.replaceFirst(RegExp('^[;,|]'), ''));
  if (rayon == null || rayon <= 0) return null;
  genre = GenreCommande.cercleRayon;
  return CommandeGeo(genre, [premier], rayon: rayon, nom: nom);
}

/// `I`, `d_{1}` écrit `d_1`.
String? _nom(String? brut) => brut?.replaceAll(RegExp('[{}]'), '');

GenreCommande? _genreLigne(String ouvre, String ferme) =>
    switch ((ouvre, ferme)) {
      ('(', ')') => GenreCommande.droite,
      ('[', ']') => GenreCommande.segment,
      ('[', ')') => GenreCommande.demiDroite,
      _ => null,
    };

/// Les arguments séparés par `;` (ou `,` à défaut), hors des parenthèses.
List<String> _separer(String texte) {
  List<String> couper(String separateurs) {
    final morceaux = <String>[];
    var profondeur = 0;
    var debut = 0;
    for (var i = 0; i < texte.length; i++) {
      final c = texte[i];
      if (c == '(' || c == '[' || c == '{') profondeur++;
      if (c == ')' || c == ']' || c == '}') profondeur--;
      if (profondeur == 0 && separateurs.contains(c)) {
        morceaux.add(texte.substring(debut, i));
        debut = i + 1;
      }
    }
    return morceaux..add(texte.substring(debut));
  }

  final morceaux = couper(';|');
  return morceaux.length > 1 ? morceaux : couper(',');
}

final _argPoint = RegExp(r"^[A-Z](?:_\{?[0-9]+\}?|')?$");
final _argNomme = RegExp(r"^[A-Za-z](?:_\{?[0-9]+\}?|')?$");
final _argLigne = RegExp(r'^([(\[])([A-Z])([A-Z])([)\]])$');

/// Un point (`A`), une droite (`(AB)`), un nom (`d`), ou `null`.
ArgumentGeo? _argument(String texte, {bool pointPossible = true}) {
  final ligne = _argLigne.firstMatch(texte);
  if (ligne != null) {
    final genre = _genreLigne(ligne[1]!, ligne[4]!);
    return genre == null ? null : ArgLigne(genre, ligne[2]!, ligne[3]!);
  }
  final nom = texte.replaceAll(RegExp('[{}]'), '');
  if (pointPossible && _argPoint.hasMatch(texte)) return ArgPoint(nom);
  if (_argNomme.hasMatch(texte)) return ArgNomme(nom);
  return null;
}

CommandeGeo? _construction(
  GenreCommande genre,
  List<String> textes,
  String? nom,
) {
  ArgPoint? point(String t) =>
      _argPoint.hasMatch(t) ? ArgPoint(t.replaceAll(RegExp('[{}]'), '')) : null;
  // Une droite : `(AB)`, ou un nom qui n'est pas celui d'un point.
  ArgumentGeo? ligne(String t) => _argument(t, pointPossible: false);

  final List<ArgumentGeo?> arguments;
  switch (genre) {
    case GenreCommande.parallele ||
        GenreCommande.perpendiculaire ||
        GenreCommande.projete:
      if (textes.length != 2) return null;
      // `parallèle((AB);C)` comme `parallèle(C;(AB))` : le point est celui
      // qui en a la forme, la droite l'autre.
      final (t0, t1) = (textes[0], textes[1]);
      final pointDabord = genre == GenreCommande.projete
          ? point(t0) != null
          : _argLigne.hasMatch(t1) || (point(t0) != null && point(t1) == null);
      arguments = pointDabord ? [ligne(t1), point(t0)] : [ligne(t0), point(t1)];
    case GenreCommande.bissectrice:
      if (textes.length != 3) return null;
      arguments = textes.map(point).toList();
    case GenreCommande.tangente:
      // `tangente(f;2)` reste la tangente à une courbe : un nombre, pas un
      // point.
      if (textes.length != 2) return null;
      arguments = [ligne(textes[0]), point(textes[1])];
    case GenreCommande.symetrique:
      if (textes.length != 2) return null;
      final centre = point(textes[1]);
      // Une minuscule seule est une droite nommée : `symétrique(A;d)`.
      arguments = [point(textes[0]), centre ?? ligne(textes[1])];
    case GenreCommande.intersection:
      if (textes.length != 2) return null;
      arguments = [ligne(textes[0]), ligne(textes[1])];
    case GenreCommande.polygone:
      // `triangle(ABC)` : les sommets collés.
      final sommets =
          textes.length == 1 && RegExp(r'^[A-Z]{3,}$').hasMatch(textes.single)
          ? textes.single.split('')
          : textes;
      if (sommets.length < 3 || sommets.toSet().length != sommets.length) {
        return null;
      }
      arguments = sommets.map(point).toList();
    case _:
      return null;
  }
  if (arguments.contains(null)) return null;
  final args = arguments.cast<ArgumentGeo>();
  final points = <String>[];
  for (final a in args) {
    switch (a) {
      case ArgPoint(:final nom):
        points.add(nom);
      case ArgLigne(:final a, :final b):
        points.addAll([a, b]);
      case ArgNomme():
        break;
    }
  }
  return CommandeGeo(genre, points.toSet().toList(), nom: nom, arguments: args);
}

final _colonne = RegExp(
  r'\\begin\{(?:pmatrix|bmatrix|matrix|array)\}(?:\{[a-z|]*\})?'
  r'(.*?)\\\\(.*?)(?:\\\\)?\\end\{(?:pmatrix|bmatrix|matrix|array)\}',
  dotAll: true,
);
final _vecteurLatex = RegExp(
  r'^\\(?:vec|overrightarrow|overline|mathbf)\{?([A-Za-z]{1,2})\}?=?\((.+)\)$',
);
final _vecteurTape = RegExp(r'^([A-Z]{2})=?\((.+)\)$');
final _vecteurNomme = RegExp(r'^([a-z])=?\((.+;.+)\)$');
final _point = RegExp(r"^([A-Z](?:_\{?[0-9a-z]\}?|')?)=?\((.+)\)$");

/// Le point ou le vecteur que dit [latex], ou `null`.
ObjetLu? lireObjet(String latex) {
  var s = latex
      .replaceAll(r'\left', '')
      .replaceAll(r'\right', '')
      .replaceAll(r'\,', '')
      .replaceAllMapped(
        RegExp(r'\\(?:mathrm|mathit|rm)\s*\{([^{}]*)\}'),
        (m) => m[1]!,
      )
      .replaceAll(RegExp(r'\s'), '');
  // `\\binom{1}{3}` : une colonne lue comme un coefficient binomial.
  s = s.replaceAllMapped(
    RegExp(r'\\binom\{([^{}]*)\}\{([^{}]*)\}'),
    (m) => '(${m[1]};${m[2]})',
  );
  // `B=[5;6]` au clavier : une matrice déclarée pour `AX=B`, pas un
  // vecteur à placer (vu sur le Pad 7).
  if (RegExp(r'^[A-Z]=\\begin\{[pb]?matrix\}').hasMatch(s)) return null;
  // Une colonne : le vecteur s'écrit debout.
  final colonne = _colonne.firstMatch(s);
  final enColonne = colonne != null;
  if (colonne != null) {
    s = s
        .replaceRange(
          colonne.start,
          colonne.end,
          '(${colonne[1]};${colonne[2]})',
        )
        .replaceAll('((', '(')
        .replaceAll('))', ')');
  }
  for (final motif in [_vecteurLatex, _vecteurTape, _vecteurNomme]) {
    final m = motif.firstMatch(s);
    if (m == null) continue;
    final c = _coordonnees(m[2]!);
    if (c == null) return null;
    return VecteurLu(m[1]!, c.$1, c.$2);
  }
  // `A` puis une colonne : c'est un point écrit debout, on le lit pareil.
  final m = _point.firstMatch(s);
  if (m == null) return null;
  final c = _coordonnees(m[2]!);
  if (c == null) return null;
  return enColonne ? VecteurLu(m[1]!, c.$1, c.$2) : PointLu(m[1]!, c.$1, c.$2);
}

/// `1;2`, `1|2`, `1,5;2`, ou `1,2` quand il n'y a qu'une virgule.
(double, double)? _coordonnees(String texte) {
  var morceaux = texte.split(RegExp('[;|]'));
  if (morceaux.length != 2) morceaux = texte.split(',');
  if (morceaux.length != 2) return null;
  final x = _valeur(morceaux[0]);
  final y = _valeur(morceaux[1]);
  return x == null || y == null ? null : (x, y);
}

double? _valeur(String latex) {
  try {
    final analyse = analyserLatex(latex);
    if (analyse.type != TypeExpression.calcul) return null;
    final v = compilerFonction(analyse.giac, variable: '_')(0);
    return v.isFinite ? v : null;
  } on ErreurLatex {
    return null;
  } on ErreurEvaluation {
    return null;
  }
}
