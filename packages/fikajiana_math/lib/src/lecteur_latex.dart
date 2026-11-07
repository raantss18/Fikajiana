import 'package:fikajiana_math/src/analyse.dart';

/// Résultat brut de la lecture d'un LaTeX.
sealed class Lecture {
  const new();
}

/// Une expression, éventuellement suivie de `=` et d'une seconde expression.
class LectureExpression extends Lecture {
  /// Crée la lecture.
  const new(this.gauche, {required this.aEgal, this.droite, this.ordre});

  /// `<`, `<=`, `>` ou `>=` à la place de `=`.
  final String? ordre;

  /// Partie avant `=`.
  final Terme gauche;

  /// Vrai si le texte contient `=`.
  final bool aEgal;

  /// Partie après `=`, absente pour `2+3=`.
  final Terme? droite;
}

/// Un système de relations.
class LectureSysteme extends Lecture {
  /// Crée la lecture.
  const new(this.relations);

  /// Relations du système, déjà traduites.
  final List<Terme> relations;
}

/// Un morceau traduit pour Giac, avec ce qu'il faut savoir de lui.
class Terme {
  /// Crée un morceau.
  const new(
    this.giac, {
    this.symboles = const {},
    this.estMatrice = false,
    this.definitionDeFonction,
    this.fonctionDefinie = false,
    this.composantes,
  });

  /// Les coordonnées d'un vecteur, pour sa norme.
  final (String, String)? composantes;

  /// Texte Giac.
  final String giac;

  /// Variables libres.
  final Set<String> symboles;

  /// Vrai pour une matrice.
  final bool estMatrice;

  /// `f(x)` si ce morceau a la forme d'un début de définition.
  final String? definitionDeFonction;

  /// `f(x)` où `f` est déjà définie : déjà remplacée par son corps.
  final bool fonctionDefinie;
}

const _ignores = {
  ',',
  ';',
  ':',
  '!',
  ' ',
  'quad',
  'qquad',
  'left',
  'right',
  'big',
  'Big',
  'bigg',
  'Bigg',
  'bf',
  'mathbf',
  'rm',
  'mathrm',
  'displaystyle',
  'textstyle',
  'limits',
  'nolimits',
  'operatorname',
  'mathit',
  'boldsymbol',
};

const _fonctions = {
  'det': 'det',
  'sin': 'sin',
  'cos': 'cos',
  'tan': 'tan',
  'cot': 'cot',
  'arcsin': 'asin',
  'arccos': 'acos',
  'arctan': 'atan',
  'sinh': 'sinh',
  'cosh': 'cosh',
  'tanh': 'tanh',
  'ln': 'ln',
  'log': 'log10',
  'exp': 'exp',
};

/// Signes d'ordre, avec ce qu'ils valent pour Giac.
const _ordres = {
  '<': '<',
  '>': '>',
  '≤': '<=',
  '≥': '>=',
  'le': '<=',
  'leq': '<=',
  'leqslant': '<=',
  'ge': '>=',
  'geq': '>=',
  'geqslant': '>=',
  'lt': '<',
  'gt': '>',
};

/// Noms à deux arguments, séparés par une virgule ou un point-virgule.
const _fonctionsADeux = {
  'gcd': 'gcd',
  'pgcd': 'gcd',
  'lcm': 'lcm',
  'ppcm': 'lcm',
  'arrondi': 'round',
  'round': 'round',
};

/// Ce qu'on demande à Giac de faire d'une expression ; la réponse s'affiche
/// sans `=`.
const _transformations = {
  'developper': 'expand',
  'expand': 'expand',
  'factoriser': 'factor',
  'factor': 'factor',
  'simplifier': 'simplify',
  'simplify': 'simplify',
  'decomposer': 'ifactor',
  'ifactor': 'ifactor',
  'premier': 'isprime',
  'isprime': 'isprime',
};

/// Sur une liste de nombres : `moyenne(2;4;9)`. La variance est celle de la
/// population (division par n), comme au lycée.
const _statistiques = {
  'moyenne': 'mean',
  'mean': 'mean',
  'mediane': 'median',
  'median': 'median',
  'variance': 'variance',
  'ecarttype': 'stddev',
  'stddev': 'stddev',
};

/// Les commandes de calcul en toutes lettres, sans accent ni tiret.
final Set<String> nomsDeCalcul = {
  ..._transformations.keys,
  ..._statistiques.keys,
  ..._fonctionsADeux.keys,
  'discriminant',
  'tangente',
};

/// `Développer`, `écart-type` : le nom tel que le lecteur le connaît.
String normaliserNom(String nom) => nom
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâ]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll(RegExp(r'[\s_-]'), '');

/// Noms à un argument, hors de la liste des fonctions réelles.
const _autresFonctions = {'det': 'det', 'arg': 'arg', 'Re': 're', 'Im': 'im'};

/// Écrits lettre après lettre, ils ne valent un nom que devant `(` : `det`
/// peut aussi être le produit de trois lettres.
final List<String> _nomsDevantParenthese = [...nomsDeCalcul, 'arg', 'Re', 'Im']
  ..sort((a, b) => b.length - a.length);

/// Noms que l'écriture sans barre oblique peut donner, lettre après lettre.
const _nomsEnLettres = [
  'arcsin',
  'arccos',
  'arctan',
  'sinh',
  'cosh',
  'tanh',
  'sin',
  'cos',
  'tan',
  'exp',
  'log',
  'lim',
  'mod',
  'ln',
];

const _constantes = {'pi': 'pi', 'infty': 'inf'};
const _nomsDeFonctionsLibres = {'f', 'g', 'h'};
const _environnements = {'pmatrix', 'bmatrix', 'matrix', 'vmatrix', 'array'};

/// Grecques acceptées comme variables.
const _grecques = {
  'alpha',
  'beta',
  'gamma',
  'delta',
  'theta',
  'lambda',
  'mu',
  'omega',
  'phi',
};

enum _Genre { nombre, lettre, commande, symbole, fin }

class _Jeton {
  const new(this.genre, this.texte, {this.parties});

  final _Genre genre;
  final String texte;

  /// `12,18` est lu 12,18 ; dans `pgcd(12,18)`, ce sont deux nombres.
  final List<String>? parties;

  bool est(String s) => genre != _Genre.fin && texte == s;
  bool commande(String s) => genre == _Genre.commande && texte == s;
}

/// `\operatorname{sin}` et `\mathrm { l n }` valent le nom seul.
/// `f^{\prime}(x)`, ce que le modèle écrit pour `f'(x)`.
final _primes = RegExp(r"\^\s*\{?((?:\s*(?:\\prime|')\s*)+)\}?");

final _nomEnveloppe = RegExp(
  r'\\(?:operatorname\*?|mathrm|mathit|rm|text|textrm|textit)\s*\{([^{}]*)\}',
);

/// Un nom enveloppé reste un nom : jamais le produit de ses lettres. `\mathrm{dx}`
/// est une différentielle ; un nom inconnu sera refusé comme toute commande.
String _nomEnClair(String enveloppe) {
  final nom = enveloppe.replaceAll(RegExp(r'\s'), '');
  if (nomsDeCalcul.contains(normaliserNom(nom))) {
    return ' \\${normaliserNom(nom)} ';
  }
  if (nom.length <= 1) return ' $nom ';
  if (RegExp(r'^d[a-z]$').hasMatch(nom)) return ' d ${nom[1]} ';
  return ' \\$nom ';
}

/// Une liste de nombres sans `;` : ses virgules séparent, `moyenne(2,4,9)`.
final _listeStatistique = RegExp(
  '(moyenne|mean|m[ée]diane|median|variance|[ée]cart-?type|stddev)'
  r'(\}?\s*(?:\\left)?\s*\()([^();]*)\)',
);

List<_Jeton> _decouper(String texte) {
  final latex = texte
      // `1{,}5` : c'est ainsi que l'app écrit elle-même une virgule décimale.
      .replaceAll(RegExp(r'\{\s*,\s*\}'), ',')
      .replaceAllMapped(
        _listeStatistique,
        (m) => '${m[1]}${m[2]}${m[3]!.replaceAll(',', ';')})',
      )
      .replaceAllMapped(_nomEnveloppe, (m) => _nomEnClair(m[1]!))
      .replaceAllMapped(
        _primes,
        (m) => "'" * RegExp(r"\\prime|'").allMatches(m[1]!).length,
      )
      .replaceAll('°', r'^{\circ}');
  final jetons = <_Jeton>[];
  var i = 0;
  bool chiffre(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  bool lettre(String c) => RegExp('[a-zA-Z]').hasMatch(c);

  while (i < latex.length) {
    final c = latex[i];
    if (c.trim().isEmpty) {
      i++;
    } else if (c == r'\') {
      if (i + 1 >= latex.length) throw const ErreurLatex('barre finale');
      final suivant = latex[i + 1];
      if (lettre(suivant)) {
        var j = i + 1;
        while (j < latex.length && lettre(latex[j])) {
          j++;
        }
        final nom = latex.substring(i + 1, j);
        i = j;
        // \right. ne ferme rien.
        if (nom == 'right' || nom == 'left') {
          while (i < latex.length && latex[i].trim().isEmpty) {
            i++;
          }
          if (i < latex.length && latex[i] == '.') i++;
        }
        if (!_ignores.contains(nom)) {
          jetons.add(_Jeton(_Genre.commande, nom));
        }
      } else {
        i += 2;
        if (suivant == r'\') {
          jetons.add(const _Jeton(_Genre.symbole, r'\\'));
        } else if (suivant == '|') {
          jetons.add(const _Jeton(_Genre.symbole, r'\|'));
        } else if (suivant == '{' || suivant == '}') {
          jetons.add(_Jeton(_Genre.symbole, '\\$suivant'));
        } else if (suivant == '%') {
          jetons.add(const _Jeton(_Genre.symbole, '%'));
        } else if (!_ignores.contains(suivant)) {
          throw ErreurLatex('commande inconnue : \\$suivant');
        }
      }
    } else if (chiffre(c)) {
      // Les espaces ne comptent pas en LaTeX ; le lecteur écrit `1 0` pour 10.
      final nombre = StringBuffer(c);
      final parties = <String>[];
      var j = i + 1;
      while (true) {
        var k = j;
        while (k < latex.length && latex[k].trim().isEmpty) {
          k++;
        }
        if (k >= latex.length) break;
        if (chiffre(latex[k])) {
          nombre.write(latex[k]);
          j = k + 1;
        } else if (latex[k] == '.' || latex[k] == ',') {
          var m = k + 1;
          while (m < latex.length && latex[m].trim().isEmpty) {
            m++;
          }
          if (m >= latex.length || !chiffre(latex[m])) break;
          if (latex[k] == ',') {
            parties.add(nombre.toString().replaceAll('.', ''));
          }
          nombre
            ..write('.')
            ..write(latex[m]);
          j = m + 1;
        } else {
          break;
        }
      }
      jetons.add(
        _Jeton(
          _Genre.nombre,
          nombre.toString(),
          parties: parties.isEmpty ? null : parties,
        ),
      );
      i = j;
    } else if (lettre(c)) {
      jetons.add(_Jeton(_Genre.lettre, c));
      i++;
    } else {
      jetons.add(_Jeton(_Genre.symbole, c));
      i++;
    }
  }
  return _rassemblerNoms(jetons);
}

/// `s i n` écrit à la main vaut `\sin`.
List<_Jeton> _rassemblerNoms(List<_Jeton> jetons) {
  final sortie = <_Jeton>[];
  var i = 0;
  while (i < jetons.length) {
    bool suit(String nom) {
      if (i + nom.length > jetons.length) return false;
      for (var k = 0; k < nom.length; k++) {
        final j = jetons[i + k];
        if (j.genre != _Genre.lettre || j.texte != nom[k]) return false;
      }
      return true;
    }

    // Avant `exp` et `tan` : `expand(`, `tangente(`.
    var trouve = _nomsDevantParenthese
        .where(
          (nom) =>
              suit(nom) &&
              i + nom.length < jetons.length &&
              jetons[i + nom.length].est('('),
        )
        .firstOrNull;
    trouve ??= _nomsEnLettres.where(suit).firstOrNull;
    // `d e t` devant une matrice ou une parenthèse, sinon trois lettres.
    if (trouve == null && suit('det') && i + 3 < jetons.length) {
      final apres = jetons[i + 3];
      if (apres.est('(') || apres.commande('begin') || apres.commande('left')) {
        trouve = 'det';
      }
    }
    trouve ??= _nomsDevantParenthese
        .where(
          (nom) =>
              suit(nom) &&
              i + nom.length < jetons.length &&
              jetons[i + nom.length].est('('),
        )
        .firstOrNull;
    if (trouve != null) {
      sortie.add(_Jeton(_Genre.commande, trouve));
      i += trouve.length;
    } else {
      sortie.add(jetons[i]);
      i++;
    }
  }
  return sortie;
}

/// Lecteur à descente récursive d'un sous-ensemble du LaTeX mathématique.
class LecteurLatex {
  /// Prépare la lecture de [latex].
  new(
    String latex, {
    this.degres = false,
    this.definitions = const {},
    this.points = const {},
    this.vecteurs = const {},
    this.valeurs = const {},
  }) : _jetons = _decouper(latex);

  /// Les fonctions déjà définies sur la feuille.
  final Map<String, DefinitionFonction> definitions;

  /// Les points déclarés sur la feuille : `A(1;2)`.
  final Map<String, (double, double)> points;

  /// Les vecteurs déclarés sur la feuille : `\vec{u}(1;3)`.
  final Map<String, (double, double)> vecteurs;

  /// Les valeurs définies sur la feuille : `a=2`.
  final Map<String, String> valeurs;

  /// Une écriture qui demande une réponse sans `=` : `f'(x)`, `det(…)`.
  bool demandeResultat = false;

  /// Les angles sont en degrés.
  final bool degres;

  final List<_Jeton> _jetons;
  var _i = 0;

  /// Niveau d'intégrale en cours : `d x` y ferme le corps.
  var _integrales = 0;

  /// Variables liées (intégrales, sommes, limites), absentes du résultat.
  final List<String> _liees = [];

  /// Le nom de la suite, si le texte contient un terme comme `u_{n+1}`.
  String? suite;

  /// Dans la cible d'une limite : `0^+` et `0+` y disent un côté.
  var _dansCible = false;

  /// Le `+` ou le `-` final de `x \to 0+`.
  bool get _signeDeCote =>
      _dansCible &&
      (_courant.est('+') || _courant.est('-')) &&
      _voir(1).est('}');

  /// `^+`, `^{-}` en fin de cible de limite.
  bool get _exposantDeCote {
    if (!_dansCible || !_courant.est('^')) return false;
    bool signe(_Jeton j) => j.est('+') || j.est('-');
    return (signe(_voir(1)) && _voir(2).est('}')) ||
        (_voir(1).est('{') && signe(_voir(2)) && _voir(3).est('}'));
  }

  static const _fin = _Jeton(_Genre.fin, '');

  _Jeton get _courant => _i < _jetons.length ? _jetons[_i] : _fin;
  _Jeton _voir(int n) => _i + n < _jetons.length ? _jetons[_i + n] : _fin;

  void _attendre(String s) {
    if (!_courant.est(s)) {
      throw ErreurLatex('attendu « $s », lu « ${_courant.texte} »');
    }
    _i++;
  }

  bool _prendre(String s) {
    if (_courant.est(s)) {
      _i++;
      return true;
    }
    return false;
  }

  /// Lit tout le texte.
  Lecture lire() {
    if (_jetons.isEmpty) throw const ErreurLatex('texte vide');
    final systeme = _essayerSysteme();
    if (systeme != null) return systeme;

    final gauche = _somme();
    final ordre = _ordres[_courant.texte];
    if (ordre != null && _courant.genre != _Genre.nombre) {
      _i++;
      final droite = _somme();
      _verifierFin();
      return LectureExpression(
        gauche,
        aEgal: true,
        droite: droite,
        ordre: ordre,
      );
    }
    if (_prendre('=')) {
      if (_courant.genre == _Genre.fin) {
        return LectureExpression(gauche, aEgal: true);
      }
      final droite = _somme();
      _verifierFin();
      return LectureExpression(gauche, aEgal: true, droite: droite);
    }
    _verifierFin();
    return LectureExpression(gauche, aEgal: false);
  }

  void _verifierFin() {
    if (_courant.genre != _Genre.fin) {
      throw ErreurLatex('reste non lu : « ${_courant.texte} »');
    }
  }

  /// `\begin{cases}`, ou `\{` suivi d'un tableau.
  Lecture? _essayerSysteme() {
    final accolade = _courant.est(r'\{');
    final debut = accolade ? 1 : 0;
    if (!_voir(debut).commande('begin')) return null;
    final nom = _nomEnvironnement(debut);
    if (nom != 'cases' && !(accolade && _environnements.contains(nom))) {
      return null;
    }
    _i += debut;
    final lignes = _environnement();
    _prendre(r'\}');
    _verifierFin();
    final relations = <Terme>[];
    for (final ligne in lignes) {
      if (ligne.length != 1) throw const ErreurLatex('ligne de système');
      relations.add(ligne.single);
    }
    if (relations.isEmpty) throw const ErreurLatex('système vide');
    return LectureSysteme(relations);
  }

  String _nomEnvironnement(int decalage) {
    final buffer = StringBuffer();
    for (var k = decalage + 2; _voir(k).genre != _Genre.fin; k++) {
      if (_voir(k).est('}')) break;
      buffer.write(_voir(k).texte);
    }
    return buffer.toString();
  }

  /// Lit `\begin{nom} … \end{nom}`, cellule par cellule.
  List<List<Terme>> _environnement() {
    _i++;
    _attendre('{');
    final nom = StringBuffer();
    while (!_courant.est('}')) {
      if (_courant.genre == _Genre.fin) throw const ErreurLatex(r'\begin');
      nom.write(_courant.texte);
      _i++;
    }
    _i++;
    if (nom.toString() == 'array' && _courant.est('{')) {
      while (!_courant.est('}')) {
        if (_courant.genre == _Genre.fin) throw const ErreurLatex('array');
        _i++;
      }
      _i++;
    }
    final lignes = <List<Terme>>[];
    var ligne = <Terme>[];
    while (!_courant.commande('end')) {
      if (_courant.genre == _Genre.fin) throw const ErreurLatex(r'\end absent');
      if (_prendre(r'\\')) {
        if (ligne.isNotEmpty) lignes.add(ligne);
        ligne = [];
      } else if (!_prendre('&')) {
        ligne.add(_celluleOuRelation());
      }
    }
    _i++;
    _attendre('{');
    while (!_prendre('}')) {
      if (_courant.genre == _Genre.fin) throw const ErreurLatex(r'\end');
      _i++;
    }
    if (ligne.isNotEmpty) lignes.add(ligne);
    return lignes;
  }

  Terme _celluleOuRelation() {
    final gauche = _somme();
    if (!_prendre('=')) return gauche;
    final droite = _somme();
    return Terme(
      '${gauche.giac}=${droite.giac}',
      symboles: {...gauche.symboles, ...droite.symboles},
    );
  }

  Terme _somme() {
    var gauche = _produit();
    while ((_courant.est('+') || _courant.est('-')) && !_signeDeCote) {
      final signe = _courant.texte;
      _i++;
      final droite = _produit();
      gauche = _fusion('${gauche.giac}$signe${droite.giac}', [gauche, droite]);
    }
    return gauche;
  }

  Terme _fusion(String giac, List<Terme> termes) =>
      Terme(giac, symboles: {for (final t in termes) ...t.symboles});

  bool get _debutDeDifferentielle =>
      _integrales > 0 &&
      (_courant.est('d') || _courant.commande('mathrm')) &&
      _voir(1).genre == _Genre.lettre;

  bool get _peutSuivre {
    if (_debutDeDifferentielle) return false;
    final j = _courant;
    return switch (j.genre) {
      _Genre.nombre || _Genre.lettre => true,
      _Genre.commande =>
        !const {
              'end',
              'to',
              'rightarrow',
              'rfloor',
              'rceil',
              'bmod',
              'mod',
            }.contains(j.texte) &&
            !_ordres.containsKey(j.texte),
      _Genre.symbole => j.est('(') || j.est('[') || j.est('{'),
      _Genre.fin => false,
    };
  }

  Terme _produit() {
    var gauche = _unaire();
    while (true) {
      if (_courant.est('*') ||
          _courant.commande('cdot') ||
          _courant.commande('times')) {
        _i++;
        final droite = _unaire();
        // Deux vecteurs : leur produit scalaire.
        gauche = gauche.composantes != null && droite.composantes != null
            ? Terme('dot(${gauche.giac},${droite.giac})')
            : _fusion('${gauche.giac}*${droite.giac}', [gauche, droite]);
      } else if (_courant.est('/') || _courant.commande('div')) {
        _i++;
        final droite = _unaire();
        gauche = _fusion('${gauche.giac}/(${droite.giac})', [gauche, droite]);
      } else if (_courant.commande('bmod') || _courant.commande('mod')) {
        _i++;
        final droite = _unaire();
        // Le reste de la division euclidienne : -7 mod 3 vaut 2, jamais -1.
        final (a, b) = (gauche.giac, droite.giac);
        gauche = _fusion('(($a)-($b)*floor(($a)/($b)))', [gauche, droite]);
      } else if (_peutSuivre) {
        final droite = _puissance();
        gauche = _fusion('${gauche.giac}*${droite.giac}', [gauche, droite]);
      } else {
        return gauche;
      }
    }
  }

  Terme _unaire() {
    if (_prendre('-')) {
      final t = _unaire();
      return Terme('(-${t.giac})', symboles: t.symboles);
    }
    if (_prendre('+')) return _unaire();
    return _puissance();
  }

  Terme _puissance() {
    final base = _postfixe();
    if (_exposantDeCote || !_prendre('^')) return base;
    if (_estDegre) return _degres(base);
    if (base.estMatrice && _estTransposee) {
      _i += _courant.est('{') ? 3 : 1;
      return Terme(
        'transpose(${base.giac})',
        symboles: base.symboles,
        estMatrice: true,
      );
    }
    final exposant = _groupeOuAtome();
    return Terme(
      '(${base.giac})^(${exposant.giac})',
      symboles: {...base.symboles, ...exposant.symboles},
    );
  }

  /// `^T`, `^t`, `^{T}`, `^\top` après une matrice.
  bool get _estTransposee {
    bool signe(_Jeton j) => j.est('T') || j.est('t') || j.commande('top');
    return signe(_courant) ||
        (_courant.est('{') && signe(_voir(1)) && _voir(2).est('}'));
  }

  /// `'`, `''`, `^{\prime}`, `^\prime` : combien de dérivations.
  int _primes() {
    var n = 0;
    while (true) {
      if (_prendre("'")) {
        n++;
      } else if (_courant.est('^') && _voir(1).commande('prime')) {
        _i += 2;
        n++;
      } else if (_courant.est('^') &&
          _voir(1).est('{') &&
          _voir(2).commande('prime') &&
          _voir(3).est('}')) {
        _i += 4;
        n++;
      } else {
        return n;
      }
    }
  }

  /// `^\circ` ou `^{\circ}`, le signe degré.
  bool get _estDegre =>
      _courant.commande('circ') ||
      (_courant.est('{') && _voir(1).commande('circ'));

  Terme _degres(Terme base) {
    _i += _courant.est('{') ? 3 : 1;
    return degres
        ? base
        : Terme('(${base.giac})*pi/180', symboles: base.symboles);
  }

  Terme _postfixe() {
    var t = _atome();
    while (true) {
      if (_prendre('!')) {
        t = Terme('factorial(${t.giac})', symboles: t.symboles);
      } else if (_prendre('%')) {
        t = Terme('(${t.giac})/100', symboles: t.symboles);
      } else {
        final primes = _primes();
        if (primes == 0) return t;
        t = _deriver(t, _variableDe(t), primes);
      }
    }
  }

  /// La variable d'une dérivée sans `dx` : x s'il est là, sinon la seule.
  String _variableDe(Terme t) {
    if (t.symboles.contains('x')) return 'x';
    if (t.symboles.length == 1) return t.symboles.single;
    throw const ErreurLatex('dérivée sans variable claire');
  }

  Terme _deriver(Terme t, String variable, int ordre) => Terme(
    ordre == 1
        ? 'diff(${t.giac},$variable)'
        : 'diff(${t.giac},$variable,$ordre)',
    symboles: {...t.symboles, variable},
  );

  /// Un seul signe, comme en LaTeX : dans `_0^1`, la borne est 0, pas `0^1`.
  Terme _borne() {
    if (_prendre('{')) {
      final t = _somme();
      _attendre('}');
      return t;
    }
    if (_prendre('-')) {
      final t = _borne();
      return Terme('(-${t.giac})', symboles: t.symboles);
    }
    _prendre('+');
    return _atome();
  }

  Terme _groupeOuAtome() {
    if (_prendre('{')) {
      final t = _somme();
      _attendre('}');
      return t;
    }
    return _unaire();
  }

  Terme _atome() {
    final j = _courant;
    switch (j.genre) {
      case _Genre.nombre:
        _i++;
        return Terme(j.texte);
      case _Genre.lettre:
        return _lettre();
      case _Genre.commande:
        return _commande();
      case _Genre.symbole:
        if (_prendre('(') || _prendre('[')) {
          final ferme = _jetons[_i - 1].texte == '(' ? ')' : ']';
          final t = _somme();
          _attendre(ferme);
          return Terme(
            t.estMatrice ? t.giac : '(${t.giac})',
            symboles: t.symboles,
            estMatrice: t.estMatrice,
          );
        }
        if (_prendre('{')) {
          final t = _somme();
          _attendre('}');
          return t;
        }
        if (_prendre(r'\|')) {
          final t = _somme();
          _attendre(r'\|');
          demandeResultat = true;
          final c = t.composantes;
          return Terme(
            c == null ? 'abs(${t.giac})' : 'sqrt((${c.$1})^2+(${c.$2})^2)',
            symboles: t.symboles,
          );
        }
        if (_prendre('|')) {
          final t = _somme();
          _attendre('|');
          // Entre barres, une matrice dit son déterminant.
          return Terme(
            t.estMatrice ? 'det(${t.giac})' : 'abs(${t.giac})',
            symboles: t.symboles,
          );
        }
        throw ErreurLatex('signe inattendu : « ${j.texte} »');
      case _Genre.fin:
        throw const ErreurLatex('expression incomplète');
    }
  }

  (double, double) _ecart(String a, String b) {
    final (p, q) = (points[a]!, points[b]!);
    return (q.$1 - p.$1, q.$2 - p.$2);
  }

  static String _nombre(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// `\overrightarrow{AB}` ou `\vec{u}`, qu'on sait calculer si la feuille les
  /// a déclarés.
  Terme _vecteur() {
    final nom = StringBuffer();
    if (_prendre('{')) {
      while (!_prendre('}')) {
        if (_courant.genre != _Genre.lettre) {
          throw const ErreurLatex('nom de vecteur');
        }
        nom.write(_courant.texte);
        _i++;
      }
    } else if (_courant.genre == _Genre.lettre) {
      nom.write(_courant.texte);
      _i++;
    }
    final n = nom.toString();
    final declare = vecteurs[n];
    final (double, double) c;
    if (declare != null) {
      c = declare;
    } else if (n.length == 2 &&
        points.containsKey(n[0]) &&
        points.containsKey(n[1])) {
      c = _ecart(n[0], n[1]);
    } else {
      throw ErreurLatex('vecteur inconnu : $n');
    }
    demandeResultat = true;
    final (x, y) = (_nombre(c.$1), _nombre(c.$2));
    return Terme('[$x,$y]', composantes: (x, y));
  }

  Terme _lettre() {
    final nom = _courant.texte;
    // Un l manuscrit se lit souvent I : `In(5)` veut dire ln(5).
    if (nom == 'I' && _voir(1).est('n') && _voir(2).est('(')) {
      _i += 2;
      return _appel('ln');
    }
    _i++;
    // `AB` entre deux points déclarés : leur distance.
    final suivante = _courant;
    if (points.containsKey(nom) &&
        suivante.genre == _Genre.lettre &&
        points.containsKey(suivante.texte) &&
        !_voir(1).est('(')) {
      _i++;
      demandeResultat = true;
      final (dx, dy) = _ecart(nom, suivante.texte);
      return Terme('sqrt((${_nombre(dx)})^2+(${_nombre(dy)})^2)');
    }
    if (valeurs.containsKey(nom)) return Terme('(${valeurs[nom]})');
    if (_prendre('_')) {
      final indice = _borne();
      // `C_5^2` et `A_5^2`, la notation française, avec des nombres seulement.
      final combinaison = const {'C': 'comb', 'A': 'perm'}[nom];
      if (combinaison != null &&
          _estEntier(indice.giac) &&
          _courant.est('^') &&
          _voir(1).genre == _Genre.nombre &&
          _estEntier(_voir(1).texte)) {
        final haut = _voir(1).texte;
        _i += 2;
        return Terme('$combinaison(${indice.giac},$haut)');
      }
      // `u_{n+1}` dit une suite. Tout le texte sera relu par [analyserLatex].
      if (RegExp(r'^[a-z][+-]\d+$').hasMatch(indice.giac)) {
        suite = nom;
        return Terme('$nom(${indice.giac})');
      }
      // Autrement, `u_{2n}` n'est pas une variable : mieux vaut refuser.
      if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(indice.giac)) {
        throw ErreurLatex('indice non pris en charge : ${indice.giac}');
      }
      final complet = '${nom}_${indice.giac}';
      return Terme(complet, symboles: _libre(complet));
    }
    final primes = _primes();
    final definie = definitions[nom];
    final fonction =
        primes > 0 ||
        _nomsDeFonctionsLibres.contains(nom) ||
        definie != null ||
        _enTeteDeDefinition;
    if (fonction && _courant.est('(')) {
      _i++;
      final argument = _somme();
      _attendre(')');
      final variableSeule =
          primes == 0 && RegExp(r'^[a-z]$').hasMatch(argument.giac);
      final ecrit = "$nom${"'" * primes}(${argument.giac})";
      if (definie != null) {
        demandeResultat = true;
        return Terme(
          definie.appel(argument.giac, primes: primes),
          symboles: {...argument.symboles, ...definie.symboles}
            ..remove(argument.symboles.isEmpty ? definie.variable : ''),
          definitionDeFonction: variableSeule ? ecrit : null,
          fonctionDefinie: true,
        );
      }
      return Terme(
        ecrit,
        symboles: argument.symboles,
        definitionDeFonction: variableSeule ? ecrit : null,
      );
    }
    if (primes > 0) throw const ErreurLatex('prime sans parenthèses');
    // Giac réserve `i` : un indice de somme change de nom pour lui.
    if (nom == 'i' && _liees.contains(_indiceI)) return const Terme(_indiceI);
    if (nom == 'e' || nom == 'i') return Terme(nom);
    return Terme(nom, symboles: _libre(nom));
  }

  static const _indiceI = 'ii';

  bool _estEntier(String texte) => RegExp(r'^\d+$').hasMatch(texte);

  /// `k(x)=` tout au début : une définition, quelle que soit la lettre. La
  /// lettre vient d'être lue. `x(x)=` ou `y(x)=` n'en sont pas.
  bool get _enTeteDeDefinition =>
      _i == 1 &&
      !const {'x', 'y', 'z', 't', 'r'}.contains(_jetons[0].texte) &&
      _courant.est('(') &&
      _voir(1).genre == _Genre.lettre &&
      _voir(2).est(')') &&
      _voir(3).est('=');

  Set<String> _libre(String nom) => _liees.contains(nom) ? const {} : {nom};

  Terme _commande() {
    final nom = _courant.texte;
    _i++;
    if (_constantes.containsKey(nom)) return Terme(_constantes[nom]!);
    if (_grecques.contains(nom)) return Terme(nom, symboles: _libre(nom));
    if (nom == 'log' && _prendre('_')) return _logarithme();
    if (_fonctions.containsKey(nom)) {
      if (nom == 'det') demandeResultat = true;
      return _appel(_fonctions[nom]!);
    }
    if (_autresFonctions.containsKey(nom)) {
      return _appel(_autresFonctions[nom]!);
    }
    if (_fonctionsADeux.containsKey(nom)) {
      demandeResultat = true;
      return _appelADeux(_fonctionsADeux[nom]!);
    }
    if (_transformations.containsKey(nom)) {
      demandeResultat = true;
      _attendre('(');
      final t = _somme();
      _attendre(')');
      return Terme('${_transformations[nom]}(${t.giac})', symboles: t.symboles);
    }
    if (_statistiques.containsKey(nom)) {
      demandeResultat = true;
      final valeurs = _liste();
      final liste = '[${valeurs.join(',')}]';
      if (_statistiques[nom] == 'median') {
        // Giac rend la plus petite des deux valeurs centrales (banc, Pad 7) ;
        // au lycée, c'est leur moyenne.
        final n = valeurs.length;
        return Terme(
          '(sort($liste)[${(n - 1) ~/ 2}]+sort($liste)[${n ~/ 2}])/2',
        );
      }
      return Terme('${_statistiques[nom]}($liste)');
    }
    if (nom == 'discriminant') return _discriminant();
    if (nom == 'tangente') return _tangente();
    switch (nom) {
      case 'frac' || 'dfrac' || 'tfrac':
        final derivee = _essayerDerivee();
        if (derivee != null) return derivee;
        final (numerateur, denominateur) = _deuxArguments();
        return Terme(
          '(${numerateur.giac})/(${denominateur.giac})',
          symboles: {...numerateur.symboles, ...denominateur.symboles},
        );
      case 'binom' || 'dbinom' || 'tbinom':
        final n = _groupeOuAtome();
        final k = _groupeOuAtome();
        return Terme(
          'comb(${n.giac},${k.giac})',
          symboles: {...n.symboles, ...k.symboles},
        );
      case 'overline':
        final t = _groupeOuAtome();
        return Terme('conj(${t.giac})', symboles: t.symboles);
      case 'lfloor':
        final t = _somme();
        if (!_courant.commande('rfloor')) throw const ErreurLatex(r'\rfloor');
        _i++;
        return Terme('floor(${t.giac})', symboles: t.symboles);
      case 'lceil':
        final t = _somme();
        if (!_courant.commande('rceil')) throw const ErreurLatex(r'\rceil');
        _i++;
        return Terme('ceil(${t.giac})', symboles: t.symboles);
      case 'overrightarrow' || 'vec':
        return _vecteur();
      case 'sqrt':
        return _racine();
      case 'int':
        return _integrale();
      case 'lim':
        return _limite();
      case 'sum':
        return _serie('sum');
      case 'prod':
        return _serie('product');
      case 'begin':
        _i--;
        final determinant = _nomEnvironnement(0) == 'vmatrix';
        final lignes = _environnement();
        final rangs = lignes
            .map((l) => '[${l.map((c) => c.giac).join(',')}]')
            .join(',');
        if (determinant) demandeResultat = true;
        return Terme(
          determinant ? 'det([$rangs])' : '[$rangs]',
          symboles: {
            for (final l in lignes)
              for (final c in l) ...c.symboles,
          },
          estMatrice: !determinant,
        );
      default:
        throw ErreurLatex('commande non prise en charge : \\$nom');
    }
  }

  /// Les deux arguments de `\frac` : `\frac12` vaut un demi, comme en LaTeX.
  (Terme, Terme) _deuxArguments() {
    final j = _courant;
    if (j.genre == _Genre.nombre && j.texte.length > 1 && j.parties == null) {
      if (!j.texte.contains('.')) {
        _i++;
        return (Terme(j.texte[0]), Terme(j.texte.substring(1)));
      }
    }
    final numerateur = _groupeOuAtome();
    return (numerateur, _groupeOuAtome());
  }

  /// `\frac{d}{dx}(…)`, `\frac{d^2}{dx^2}…`, `\frac{d(…)}{dx}`, avec `d` ou
  /// `\partial`. Autrement : `null`, c'est une fraction comme une autre.
  Terme? _essayerDerivee() {
    if (!_courant.est('{')) return null;
    bool marque(_Jeton j) => j.est('d') || j.commande('partial');
    if (!marque(_voir(1))) return null;
    var profondeur = 0;
    var fin = 0;
    while (true) {
      final j = _voir(fin);
      if (j.genre == _Genre.fin) return null;
      if (j.est('{')) profondeur++;
      if (j.est('}') && --profondeur == 0) {
        break;
      }
      fin++;
    }
    final (ordre, longueur) = _ordreDe(2);
    // Le dénominateur : `{`, `d`, la variable, son ordre, `}`.
    if (!_voir(fin + 1).est('{') ||
        !marque(_voir(fin + 2)) ||
        _voir(fin + 3).genre != _Genre.lettre) {
      return null;
    }
    final (ordreBas, longueurBas) = _ordreDe(fin + 4);
    if (!_voir(fin + 4 + longueurBas).est('}') || ordre != ordreBas) {
      return null;
    }

    final variable = _voir(fin + 3).texte;
    final corpsVide = 2 + longueur == fin;
    final suite = fin + 5 + longueurBas;
    if (corpsVide) {
      _i += suite;
      return _deriver(_produit(), variable, ordre);
    }
    final debut = _i + 2 + longueur;
    final fermeture = _i + fin;
    // `\frac{dy}{dx}` ne dit pas ce qu'est y : ce serait 0 sans rien dire.
    if (fermeture - debut == 1 && _jetons[debut].genre == _Genre.lettre) {
      final nom = _jetons[debut].texte;
      if (!_nomsDeFonctionsLibres.contains(nom)) {
        throw ErreurLatex('dérivée de $nom sans expression');
      }
      _i += suite;
      return _deriver(
        Terme('$nom($variable)', symboles: {variable}),
        variable,
        ordre,
      );
    }
    _i = debut;
    final corps = _somme();
    if (_i != fermeture) throw const ErreurLatex('dérivée');
    _i = fermeture + suite - fin;
    return _deriver(corps, variable, ordre);
  }

  /// L'ordre écrit à partir du jeton [k] : `^2`, `^{2}`, ou rien ; et sa
  /// longueur en jetons.
  (int, int) _ordreDe(int k) {
    if (!_voir(k).est('^')) return (1, 0);
    final accolade = _voir(k + 1).est('{');
    final j = _voir(accolade ? k + 2 : k + 1);
    final ordre = j.genre == _Genre.nombre ? int.tryParse(j.texte) : null;
    if (ordre == null || (accolade && !_voir(k + 3).est('}'))) return (1, 0);
    return (ordre, accolade ? 4 : 2);
  }

  /// `\log_{2}(8)`.
  Terme _logarithme() {
    // `\log_2 8` : le découpage a lu 28, mais l'indice ne prend qu'un signe.
    final j = _courant;
    if (j.genre == _Genre.nombre && _estEntier(j.texte) && j.texte.length > 1) {
      _jetons.replaceRange(_i, _i + 1, [
        _Jeton(_Genre.nombre, j.texte[0]),
        _Jeton(_Genre.nombre, j.texte.substring(1)),
      ]);
    }
    final base = _borne();
    final argument = _appel('ln');
    // Sans `simplify`, Giac rend ln(8)/ln(2) au lieu de 3.
    return Terme(
      'simplify(${argument.giac}/ln(${base.giac}))',
      symboles: {...argument.symboles, ...base.symboles},
    );
  }

  /// `(2;4;9)`, ou `(2,4,9)` sans point-virgule : des nombres seulement.
  List<String> _liste() {
    _attendre('(');
    final j = _courant;
    final parties = j.parties;
    // `2,4,9` lu comme un seul nombre : la lecture n'a pas su séparer.
    if (j.genre == _Genre.nombre && parties != null) {
      throw const ErreurLatex('liste ambiguë : écrire 2;4;9');
    }
    final valeurs = <String>[];
    do {
      final t = _somme();
      if (t.symboles.isNotEmpty) throw const ErreurLatex('liste de nombres');
      valeurs.add(t.giac);
    } while (_prendre(';') || _prendre(','));
    _attendre(')');
    if (valeurs.isEmpty) throw const ErreurLatex('liste vide');
    return valeurs;
  }

  /// `discriminant(x^2-3x+2)` : b²-4ac, pour un trinôme de la variable.
  Terme _discriminant() {
    demandeResultat = true;
    _attendre('(');
    final p = _somme();
    _attendre(')');
    final variables = p.symboles;
    if (variables.length != 1) {
      throw const ErreurLatex('discriminant d’un trinôme à une variable');
    }
    final v = variables.single;
    final q = '(${p.giac})';
    return Terme('normal(coeff($q,$v,1)^2-4*coeff($q,$v,2)*coeff($q,$v,0))');
  }

  /// `tangente(f;2)` : la tangente à la courbe de f, définie plus haut, en 2.
  Terme _tangente() {
    demandeResultat = true;
    _attendre('(');
    final nom = _courant.texte;
    final definition = definitions[nom];
    if (_courant.genre != _Genre.lettre || definition == null) {
      throw ErreurLatex('tangente : fonction inconnue $nom');
    }
    _i++;
    if (!_prendre(';') && !_prendre(',')) {
      throw const ErreurLatex('tangente(f;a)');
    }
    final a = _somme();
    _attendre(')');
    final v = definition.variable;
    return Terme(
      'normal(${definition.appel(a.giac)}'
      '+${definition.appel(a.giac, primes: 1)}*($v-(${a.giac})))',
      symboles: {v},
    );
  }

  /// `\gcd(12,18)` : ici la virgule sépare, elle n'est plus décimale.
  Terme _appelADeux(String nom) {
    _attendre('(');
    final j = _courant;
    final parties = j.parties;
    // `arrondi(3,14;2)` : avec un `;`, la virgule reste décimale.
    final pointVirgule = _jetons
        .skip(_i)
        .takeWhile((t) => !t.est(')'))
        .any((t) => t.est(';'));
    if (j.genre == _Genre.nombre &&
        parties != null &&
        parties.length == 1 &&
        !pointVirgule) {
      final reste = j.texte.substring(parties.single.length + 1);
      _jetons.replaceRange(_i, _i + 1, [
        _Jeton(_Genre.nombre, parties.single),
        const _Jeton(_Genre.symbole, ','),
        _Jeton(_Genre.nombre, reste),
      ]);
    }
    final a = _somme();
    if (!_prendre(',') && !_prendre(';')) {
      throw ErreurLatex('$nom attend deux nombres');
    }
    final b = _somme();
    _attendre(')');
    return Terme(
      '$nom(${a.giac},${b.giac})',
      symboles: {...a.symboles, ...b.symboles},
    );
  }

  /// `\sin x`, `\sin(x)`, `\sin^2 x`.
  Terme _appel(String nom) {
    Terme? exposant;
    if (_prendre('^')) exposant = _groupeOuAtome();
    final Terme argument;
    if (_prendre('(')) {
      argument = _somme();
      _attendre(')');
    } else {
      argument = _argumentSansParentheses();
    }
    final appel = '$nom(${argument.giac})';
    if (exposant == null) return Terme(appel, symboles: argument.symboles);
    return Terme(
      '($appel)^(${exposant.giac})',
      symboles: {...argument.symboles, ...exposant.symboles},
    );
  }

  /// `\sin 2x` est `sin(2x)`, et `\sin x \cos x` s'arrête à `\cos`.
  Terme _argumentSansParentheses() {
    var argument = _puissance();
    while (!_debutDeDifferentielle &&
        (_courant.genre == _Genre.lettre ||
            (_courant.genre == _Genre.commande &&
                (_constantes.containsKey(_courant.texte) ||
                    _grecques.contains(_courant.texte))))) {
      final suite = _puissance();
      argument = _fusion('${argument.giac}*${suite.giac}', [argument, suite]);
    }
    return argument;
  }

  Terme _racine() {
    Terme? indice;
    if (_prendre('[')) {
      indice = _somme();
      _attendre(']');
    }
    final corps = _groupeOuAtome();
    if (indice == null) {
      return Terme('sqrt(${corps.giac})', symboles: corps.symboles);
    }
    return Terme(
      '(${corps.giac})^(1/(${indice.giac}))',
      symboles: {...corps.symboles, ...indice.symboles},
    );
  }

  /// Bornes `_{a}^{b}` dans n'importe quel ordre, ou aucune.
  (Terme?, Terme?) _bornes() {
    Terme? bas;
    Terme? haut;
    for (var k = 0; k < 2; k++) {
      if (_prendre('_')) {
        bas = _borne();
      } else if (_prendre('^')) {
        haut = _borne();
      }
    }
    // Une seule borne ne dit rien : la perdre rendrait une primitive.
    if ((bas == null) != (haut == null)) throw const ErreurLatex('borne seule');
    return (bas, haut);
  }

  Terme _integrale() {
    final (bas, haut) = _bornes();
    final variable = _trouverDifferentielle();
    _liees.add(variable);
    _integrales++;
    final corps = _somme();
    _integrales--;
    _liees.removeLast();
    if (!_debutDifferentielleSimple) {
      throw const ErreurLatex('intégrale sans dx');
    }
    _i += 2;
    final symboles = {...corps.symboles, ...?bas?.symboles, ...?haut?.symboles};
    if (bas != null && haut != null) {
      return Terme(
        'integrate(${corps.giac},$variable,${bas.giac},${haut.giac})',
        symboles: symboles,
      );
    }
    // `3x^3/3+x` brut (Pad 7) : la primitive se simplifie.
    return Terme(
      'normal(integrate(${corps.giac},$variable))',
      symboles: symboles,
    );
  }

  bool get _debutDifferentielleSimple =>
      _courant.est('d') && _voir(1).genre == _Genre.lettre;

  /// Regarde en avant le `d x` qui ferme l'intégrale de ce niveau.
  String _trouverDifferentielle() {
    var profondeur = 0;
    var dernier = '';
    for (var k = 0; _voir(k).genre != _Genre.fin; k++) {
      final j = _voir(k);
      if (j.est('{') || j.est('(')) profondeur++;
      if (j.est('}') || j.est(')')) profondeur--;
      if (profondeur < 0) break;
      if (profondeur == 0 &&
          j.est('d') &&
          _voir(k + 1).genre == _Genre.lettre) {
        dernier = _voir(k + 1).texte;
      }
    }
    if (dernier.isEmpty) throw const ErreurLatex('intégrale sans dx');
    return dernier;
  }

  Terme _limite() {
    _attendre('_');
    _attendre('{');
    if (_courant.genre != _Genre.lettre) throw const ErreurLatex('limite');
    final variable = _courant.texte;
    _i++;
    if (!_courant.commande('to') && !_courant.commande('rightarrow')) {
      throw const ErreurLatex('limite sans flèche');
    }
    _i++;
    _dansCible = true;
    final cible = _somme();
    _dansCible = false;
    final cote = _coteDeLimite();
    _attendre('}');
    _liees.add(variable);
    final corps = _somme();
    _liees.removeLast();
    return Terme(
      'limit(${corps.giac},$variable,${cible.giac}$cote)',
      symboles: {...corps.symboles, ...cible.symboles},
    );
  }

  /// Pour Giac : `,1` à droite, `,-1` à gauche, rien des deux côtés.
  String _coteDeLimite() {
    var signe = '';
    if (_courant.est('^')) {
      _i++;
      final accolade = _prendre('{');
      signe = _courant.texte;
      _i++;
      if (accolade) _attendre('}');
    } else if (_courant.est('+') || _courant.est('-')) {
      signe = _courant.texte;
      _i++;
    }
    return switch (signe) {
      '+' => ',1',
      '-' => ',-1',
      _ => '',
    };
  }

  /// `\sum_{k=a}^{b}`, avec un corps limité au produit qui suit.
  Terme _serie(String nom) {
    _attendre('_');
    _attendre('{');
    if (_courant.genre != _Genre.lettre) throw const ErreurLatex('indice');
    final variable = _courant.texte == 'i' ? _indiceI : _courant.texte;
    _i++;
    _attendre('=');
    final debut = _somme();
    _attendre('}');
    _attendre('^');
    final fin = _borne();
    _liees.add(variable);
    final corps = _produit();
    _liees.removeLast();
    return Terme(
      '$nom(${corps.giac},$variable,${debut.giac},${fin.giac})',
      symboles: {...corps.symboles, ...debut.symboles, ...fin.symboles},
    );
  }
}
