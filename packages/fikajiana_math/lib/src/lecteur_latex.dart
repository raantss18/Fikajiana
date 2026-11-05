import 'package:fikajiana_math/src/analyse.dart';

/// Résultat brut de la lecture d'un LaTeX.
sealed class Lecture {
  const new();
}

/// Une expression, éventuellement suivie de `=` et d'une seconde expression.
class LectureExpression extends Lecture {
  /// Crée la lecture.
  const new(this.gauche, {required this.aEgal, this.droite});

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
  });

  /// Texte Giac.
  final String giac;

  /// Variables libres.
  final Set<String> symboles;

  /// Vrai pour une matrice.
  final bool estMatrice;

  /// `f(x)` si ce morceau a la forme d'un début de définition.
  final String? definitionDeFonction;
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
  const new(this.genre, this.texte);

  final _Genre genre;
  final String texte;

  bool est(String s) => genre != _Genre.fin && texte == s;
  bool commande(String s) => genre == _Genre.commande && texte == s;
}

List<_Jeton> _decouper(String latex) {
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
        } else if (suivant == '{' || suivant == '}') {
          jetons.add(_Jeton(_Genre.symbole, '\\$suivant'));
        } else if (!_ignores.contains(suivant)) {
          throw ErreurLatex('commande inconnue : \\$suivant');
        }
      }
    } else if (chiffre(c)) {
      // Les espaces ne comptent pas en LaTeX, et le lecteur écrit `1 0` pour 10.
      final nombre = StringBuffer(c);
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
          nombre
            ..write('.')
            ..write(latex[m]);
          j = m + 1;
        } else {
          break;
        }
      }
      jetons.add(_Jeton(_Genre.nombre, nombre.toString()));
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
    String? trouve;
    for (final nom in _nomsEnLettres) {
      if (i + nom.length > jetons.length) continue;
      var ok = true;
      for (var k = 0; k < nom.length; k++) {
        final j = jetons[i + k];
        if (j.genre != _Genre.lettre || j.texte != nom[k]) ok = false;
      }
      if (ok) {
        trouve = nom;
        break;
      }
    }
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
  new(String latex) : _jetons = _decouper(latex);

  final List<_Jeton> _jetons;
  var _i = 0;

  /// Niveau d'intégrale en cours : `d x` y ferme le corps.
  var _integrales = 0;

  /// Variables liées (intégrales, sommes, limites), absentes du résultat.
  final List<String> _liees = [];

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
    while (_courant.est('+') || _courant.est('-')) {
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
        !j.commande('end') && !j.commande('to') && !j.commande('rightarrow'),
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
        gauche = _fusion('${gauche.giac}*${droite.giac}', [gauche, droite]);
      } else if (_courant.est('/') || _courant.commande('div')) {
        _i++;
        final droite = _unaire();
        gauche = _fusion('${gauche.giac}/(${droite.giac})', [gauche, droite]);
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
    if (!_prendre('^')) return base;
    final exposant = _groupeOuAtome();
    return Terme(
      '(${base.giac})^(${exposant.giac})',
      symboles: {...base.symboles, ...exposant.symboles},
    );
  }

  Terme _postfixe() {
    var t = _atome();
    while (_prendre('!')) {
      t = Terme('factorial(${t.giac})', symboles: t.symboles);
    }
    return t;
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
        if (_prendre('|')) {
          final t = _somme();
          _attendre('|');
          return Terme('abs(${t.giac})', symboles: t.symboles);
        }
        throw ErreurLatex('signe inattendu : « ${j.texte} »');
      case _Genre.fin:
        throw const ErreurLatex('expression incomplète');
    }
  }

  Terme _lettre() {
    final nom = _courant.texte;
    _i++;
    if (_prendre('_')) {
      final indice = _groupeOuAtome();
      final complet = '${nom}_${indice.giac}';
      return Terme(complet, symboles: _libre(complet));
    }
    final prime = _prendre("'");
    final fonction = prime || _nomsDeFonctionsLibres.contains(nom);
    if (fonction && _courant.est('(')) {
      _i++;
      final argument = _somme();
      _attendre(')');
      final appel = prime
          ? "$nom'(${argument.giac})"
          : '$nom(${argument.giac})';
      final variableSeule =
          !prime && RegExp(r'^[a-z]$').hasMatch(argument.giac);
      return Terme(
        appel,
        symboles: argument.symboles,
        definitionDeFonction: variableSeule ? appel : null,
      );
    }
    if (prime) throw const ErreurLatex('prime sans parenthèses');
    if (nom == 'e' || nom == 'i') return Terme(nom);
    return Terme(nom, symboles: _libre(nom));
  }

  Set<String> _libre(String nom) => _liees.contains(nom) ? const {} : {nom};

  Terme _commande() {
    final nom = _courant.texte;
    _i++;
    if (_constantes.containsKey(nom)) return Terme(_constantes[nom]!);
    if (_grecques.contains(nom)) return Terme(nom, symboles: _libre(nom));
    if (_fonctions.containsKey(nom)) return _appel(_fonctions[nom]!);
    switch (nom) {
      case 'frac' || 'dfrac' || 'tfrac':
        final numerateur = _groupeOuAtome();
        final denominateur = _groupeOuAtome();
        return Terme(
          '(${numerateur.giac})/(${denominateur.giac})',
          symboles: {...numerateur.symboles, ...denominateur.symboles},
        );
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
        final lignes = _environnement();
        final rangs = lignes
            .map((l) => '[${l.map((c) => c.giac).join(',')}]')
            .join(',');
        return Terme(
          '[$rangs]',
          symboles: {
            for (final l in lignes)
              for (final c in l) ...c.symboles,
          },
          estMatrice: true,
        );
      default:
        throw ErreurLatex('commande non prise en charge : \\$nom');
    }
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
      argument = _puissance();
    }
    final appel = '$nom(${argument.giac})';
    if (exposant == null) return Terme(appel, symboles: argument.symboles);
    return Terme(
      '($appel)^(${exposant.giac})',
      symboles: {...argument.symboles, ...exposant.symboles},
    );
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
        bas = _groupeOuAtome();
      } else if (_prendre('^')) {
        haut = _groupeOuAtome();
      }
    }
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
    return Terme('integrate(${corps.giac},$variable)', symboles: symboles);
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
    final cible = _somme();
    _attendre('}');
    _liees.add(variable);
    final corps = _somme();
    _liees.removeLast();
    return Terme(
      'limit(${corps.giac},$variable,${cible.giac})',
      symboles: {...corps.symboles, ...cible.symboles},
    );
  }

  /// `\sum_{k=a}^{b}`, avec un corps limité au produit qui suit.
  Terme _serie(String nom) {
    _attendre('_');
    _attendre('{');
    if (_courant.genre != _Genre.lettre) throw const ErreurLatex('indice');
    final variable = _courant.texte;
    _i++;
    _attendre('=');
    final debut = _somme();
    _attendre('}');
    _attendre('^');
    final fin = _groupeOuAtome();
    _liees.add(variable);
    final corps = _produit();
    _liees.removeLast();
    return Terme(
      '$nom(${corps.giac},$variable,${debut.giac},${fin.giac})',
      symboles: {...corps.symboles, ...debut.symboles, ...fin.symboles},
    );
  }
}
