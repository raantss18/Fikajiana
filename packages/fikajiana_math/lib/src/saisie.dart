/// La saisie au clavier : du texte naturel, traduit en LaTeX (ADR 0024).
///
/// `x^2+3x-5=0`, `sin 2x`, `racine de 2`, `x²`, `1/3` ou `\frac{1}{3}` : tout
/// devient le même LaTeX que l'écriture à la main, et rien n'est deviné en
/// silence : un mot inconnu est refusé, une lecture ambiguë propose l'autre.
library;

import 'package:fikajiana_math/src/lecteur_latex.dart'
    show nomsDeCalcul, normaliserNom;
import 'package:fikajiana_math/src/objets.dart';

/// Pourquoi une saisie ne se lit pas.
enum ProblemeSaisie {
  /// Un mot que l'on ne connaît pas, dans [Saisie.detail].
  motInconnu,

  /// `2 3` : deux nombres de suite, sans opération.
  nombresColles,

  /// Une écriture qui n'est pas finie : `2+`, `x^`.
  incomplet,

  /// Un signe de trop ou mal placé, dans [Saisie.detail].
  signeInattendu,
}

/// Ce que le texte tapé veut dire.
class Saisie {
  /// Une saisie comprise.
  const new(this.latex, {this.autreLecture}) : probleme = null, detail = null;

  /// Une saisie refusée.
  const new refusee(ProblemeSaisie this.probleme, {this.detail})
    : latex = null,
      autreLecture = null;

  /// Le LaTeX, celui que lit aussi l'écriture à la main.
  final String? latex;

  /// L'autre sens possible : `\frac{1}{2x}` pour `1/2x`.
  final String? autreLecture;

  /// Ce qui empêche de comprendre.
  final ProblemeSaisie? probleme;

  /// Le mot ou le signe en cause.
  final String? detail;
}

/// Traduit [texte] tapé au clavier. Le LaTeX passe tel quel.
Saisie lireSaisie(String texte) {
  final propre = texte.trim();
  if (propre.isEmpty) return const Saisie.refusee(ProblemeSaisie.incomplet);
  if (propre.contains(r'\') || propre.contains('{')) return Saisie(propre);
  // `A(1;2)`, `AB(1;3)` : un point ou un vecteur, tel quel.
  if (lireObjet(propre) != null || lireCommande(propre) != null) {
    return Saisie(propre);
  }
  // `angle(A;B;C)=`, `aire(ABC)=` : une mesure, lue telle quelle.
  if (RegExp(
    r'^(angle|aire|p[ée]rim[eè]tre)\s*\(\s*[A-Z](\s*[;,]?\s*[A-Z])+\s*\)\s*=?$',
  ).hasMatch(propre)) {
    return Saisie(propre);
  }
  // `ajustement([1;2;3];[2;4;7];exp)`, `quartiles(3;1;7)` (vague 3).
  final statistique = RegExp(
    r'^(ajustement|r[ée]gression|corr[ée]lation|covariance|quartiles)\s*'
    r'\((.*)\)\s*(=?)$',
  ).firstMatch(propre);
  if (statistique != null) {
    try {
      String traduit(String t) => _Traducteur(_decouper(t.trim())).traduire();
      String argument(String a) {
        final liste = RegExp(r'^\s*[\[{(](.*)[\]})]\s*$').firstMatch(a);
        if (liste != null) {
          return '\\left[${_separer(liste[1]!, ';').map(traduit).join(';')}'
              r'\right]';
        }
        // Le modèle (`exp`, `ln`, `puissance`, `2`) reste tel quel.
        return RegExp(r'^\s*[a-zé]+\s*$').hasMatch(a) ? a.trim() : traduit(a);
      }

      final morceaux = _separerHorsCrochets(statistique[2]!);
      return Saisie(
        '\\text{${statistique[1]}}\\left('
        '${morceaux.map(argument).join(';')}\\right)${statistique[3]}',
      );
    } on _Refus catch (refus) {
      return Saisie.refusee(refus.probleme, detail: refus.detail);
    }
  }
  // `17≡2[5]`, `17 equiv 2 mod 5` : une congruence.
  final congruence = RegExp(
    r'^(.+?)\s*(?:≡|\bequiv\b|\bcongru\b(?:\s*à)?)\s*(.+?)\s*'
    r'(?:\[(.+)\]|\(\s*mod\s*(.+?)\s*\)|\bmod\s*(.+))$',
  ).firstMatch(propre);
  if (congruence != null) {
    try {
      String traduit(String t) => _Traducteur(_decouper(t.trim())).traduire();
      final n = congruence[3] ?? congruence[4] ?? congruence[5]!;
      return Saisie(
        '${traduit(congruence[1]!)}\\equiv ${traduit(congruence[2]!)}'
        '\\pmod{${traduit(n)}}',
      );
    } on _Refus catch (refus) {
      return Saisie.refusee(refus.probleme, detail: refus.detail);
    }
  }
  // `X~B(10;0,3)`, `P(X<=3)=`, `E(X)=` : les lois de probabilité.
  try {
    final probabilite = _probabiliteTapee(propre);
    if (probabilite != null) return Saisie(probabilite);
  } on _Refus catch (refus) {
    return Saisie.refusee(refus.probleme, detail: refus.detail);
  }
  // `A=[1,2;3,4]` ou `A=[[1,2],[3,4]]` : une matrice au clavier.
  final matrice = _matriceTapee(propre);
  if (matrice != null) return Saisie(matrice);
  // `C : x^2+y^3=0` : une courbe nommée ; le nom reste, la suite se traduit.
  final nomme = RegExp(r'^([A-Za-z](?:_\d+)?)\s*:(?!=)\s*(.+)$')
      .firstMatch(propre);
  if (nomme != null) {
    final suite = lireSaisie(nomme[2]!);
    final latex = suite.latex;
    if (latex == null) return suite;
    return Saisie('${nomme[1]} : $latex');
  }
  try {
    final commande = _commandeDeCalcul(propre);
    if (commande != null) return Saisie(commande);
    final jetons = _decouper(propre);
    final latex = _Traducteur(jetons).traduire();
    final autre = _Traducteur(jetons, denominateurLong: true).traduire();
    return Saisie(latex, autreLecture: autre == latex ? null : autre);
  } on _Refus catch (refus) {
    return Saisie.refusee(refus.probleme, detail: refus.detail);
  }
}

/// `[1;2];[3;4];exp` : coupé aux `;` hors des crochets et parenthèses.
List<String> _separerHorsCrochets(String texte) {
  final morceaux = <String>[];
  var profondeur = 0;
  var debut = 0;
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if ('([{'.contains(c)) profondeur++;
    if (')]}'.contains(c)) profondeur--;
    if (c == ';' && profondeur == 0) {
      morceaux.add(texte.substring(debut, i));
      debut = i + 1;
    }
  }
  morceaux.add(texte.substring(debut));
  return morceaux;
}

/// Une loi déclarée (`X~B(10;0,3)`, `Y~N(100;15^2)`) ou une probabilité
/// (`P(X<=3)=`, `P(2<=X<5)`, `P(X<=k)>=0,95`), `E(X)=`, `V(X)=`,
/// `sigma(X)=` : le LaTeX qu'écrirait la main. `null` sinon.
String? _probabiliteTapee(String texte) {
  String traduit(String morceau) =>
      _Traducteur(_decouper(morceau.trim())).traduire();
  final loi = RegExp(r'^([A-Z])\s*[~∼]\s*([A-Za-z]+)\s*\((.*)\)$')
      .firstMatch(texte);
  if (loi != null) {
    var morceaux = _separer(loi[3]!, ';');
    if (morceaux.length == 1) morceaux = _separer(loi[3]!, ',');
    return '${loi[1]}\\sim ${loi[2]}\\left('
        '${morceaux.map(traduit).join(';')}\\right)';
  }
  final moment = RegExp(r'^(E|V|sigma|σ)\s*\(\s*([A-Z])\s*\)\s*(=?)$')
      .firstMatch(texte);
  if (moment != null) {
    final nom = switch (moment[1]) {
      'sigma' || 'σ' => r'\sigma',
      final autre => autre!,
    };
    return '$nom\\left(${moment[2]}\\right)${moment[3]}';
  }
  final p = RegExp(r'^P\s*\((.*)\)\s*(.*)$').firstMatch(texte);
  if (p == null || !RegExp('[A-Z]').hasMatch(p[1]!)) return null;
  const signes = {
    '<=': r'\le ',
    '>=': r'\ge ',
    '≤': r'\le ',
    '≥': r'\ge ',
    '<': '<',
    '>': '>',
    '=': '=',
  };
  // Les morceaux entre les signes d'ordre, chacun traduit.
  String relation(String s) {
    final sortie = StringBuffer();
    final morceau = StringBuffer();
    void vider() {
      if (morceau.toString().trim().isNotEmpty) {
        sortie.write(traduit(morceau.toString()));
      }
      morceau.clear();
    }

    for (var i = 0; i < s.length; i++) {
      final deux = i + 1 < s.length ? s.substring(i, i + 2) : '';
      final signe = signes.containsKey(deux)
          ? deux
          : signes.containsKey(s[i])
          ? s[i]
          : null;
      if (signe == null) {
        morceau.write(s[i]);
        continue;
      }
      vider();
      sortie.write(signes[signe]);
      i += signe.length - 1;
    }
    vider();
    return sortie.toString();
  }

  final suite = p[2]!.trim();
  return 'P\\left(${relation(p[1]!)}\\right)${relation(suite)}';
}

/// `développer((x+1)^2)`, `moyenne(2;4;9)`, `tangente(f;2)` sur toute la
/// ligne : le nom pour le lecteur, chaque argument traduit à part.
String? _commandeDeCalcul(String texte) {
  final m = RegExp(r'^([A-Za-zÀ-ÿ_-]+)\s*\((.*)\)\s*(=?)\s*$')
      .firstMatch(texte);
  if (m == null) return null;
  final nom = normaliserNom(m[1]!);
  if (!nomsDeCalcul.contains(nom)) return null;
  final dedans = m[2]!;
  final unSeul =
      !RegExp(
        r'^(moyenne|mean|mediane|median|variance|ecarttype|stddev|tangente)$',
      ).hasMatch(nom) &&
      !const {
        'arrondi',
        'round',
        'pgcd',
        'ppcm',
        'gcd',
        'lcm',
        'quotient',
        'reste',
        'remainder',
        'perm',
        'arrangement',
        'division',
        'bezout',
      }.contains(nom);
  var morceaux = unSeul ? [dedans] : _separer(dedans, ';');
  if (!unSeul && morceaux.length == 1) morceaux = _separer(dedans, ',');
  if (nom == 'tangente') {
    // `tangente(x)` reste la fonction tangente.
    if (morceaux.length != 2 ||
        !RegExp(r'^\s*[a-zA-Z]\s*$').hasMatch(morceaux.first)) {
      return null;
    }
    final a = _Traducteur(_decouper(morceaux.last)).traduire();
    return '\\text{tangente}\\left(${morceaux.first.trim()};$a'
        '\\right)${m[3]}';
  }
  final traduits = [
    for (final morceau in morceaux) _Traducteur(_decouper(morceau)).traduire(),
  ];
  // `\\text` : l'affichage garde les accents ; le lecteur les ôte.
  return '\\text{${m[1]}}\\left(${traduits.join(';')}\\right)${m[3]}';
}

/// `[1,2;3,4]`, `[[1,2],[3,4]]`, `[5;6]` (colonne), précédé ou non de `A=`.
/// Les cases se traduisent une à une. `null` si ce n'en est pas une.
String? _matriceTapee(String texte) {
  final m = RegExp(r'^(?:([A-Z])\s*=\s*)?\[(.*)\]\s*(=?)$').firstMatch(texte);
  if (m == null) return null;
  final corps = m[2]!.trim();
  final List<String> lignes;
  if (corps.startsWith('[')) {
    // `[[1,2],[3,4]]` : des lignes entre crochets.
    lignes = [
      for (final l in RegExp(r'\[([^\[\]]*)\]').allMatches(corps)) l[1]!,
    ];
    if (lignes.isEmpty) return null;
  } else {
    lignes = corps.split(';');
  }
  final cases = [
    for (final l in lignes)
      [
        for (final c in l.trim().split(RegExp(r'\s*,\s*|\s+')))
          if (c.isNotEmpty) c,
      ],
  ];
  if (cases.isEmpty || cases.any((l) => l.isEmpty)) return null;
  // `[5;6]` ou `[1,2;3,4]` ; une seule ligne d'un nombre n'est pas une matrice.
  if (cases.length == 1 && cases.single.length == 1) return null;
  final colonnes = cases.first.length;
  if (cases.any((l) => l.length != colonnes)) return null;
  try {
    final latex = [
      for (final l in cases)
        [for (final c in l) _Traducteur(_decouper(c)).traduire()].join('&'),
    ].join(r'\\');
    final nom = m[1] == null ? '' : '${m[1]}=';
    return '$nom\\begin{pmatrix}$latex\\end{pmatrix}${m[3]}';
  } on _Refus {
    return null;
  }
}

/// Coupe [texte] à chaque [signe] hors des parenthèses.
List<String> _separer(String texte, String signe) {
  final morceaux = <String>[];
  var profondeur = 0;
  var debut = 0;
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if (c == '(') profondeur++;
    if (c == ')') profondeur--;
    if (c == signe && profondeur == 0) {
      morceaux.add(texte.substring(debut, i));
      debut = i + 1;
    }
  }
  return morceaux..add(texte.substring(debut));
}

/// Le LaTeX lu à la main, en texte à corriger : `\frac{x}{2}` donne `x/2`.
/// Ce qui ne s'écrit pas simplement reste en LaTeX.
String texteDepuisLatex(String latex) {
  var s = latex.replaceAll(RegExp(r'\^\s*\{'), '^{');
  // Le LaTeX d'un `\frac` imbriqué se résout de l'intérieur vers l'extérieur.
  s = _remplacerCommande(s, 'frac', 2, (a) {
    return '${_groupe(a[0])}/${_groupe(a[1])}';
  });
  s = _remplacerCommande(s, 'sqrt', 1, (a) => 'sqrt(${a[0]})');
  // `\text{moyenne}`, `\operatorname{pgcd}` : le nom tel quel.
  for (final nom in ['text', 'operatorname', 'mathrm']) {
    s = _remplacerCommande(s, nom, 1, (a) => a[0]);
  }
  s = _sansExposantsGroupes(s);
  const simples = {
    r'\left': '',
    r'\right': '',
    r'\cdot': '*',
    r'\times': '*',
    r'\,': '',
    r'\;': '',
    r'\ ': '',
    r'\pi': 'pi',
    r'\theta': 'θ',
    r'\infty': 'infini',
    r'\arcsin': 'arcsin',
    r'\arccos': 'arccos',
    r'\arctan': 'arctan',
    r'\sinh': 'sinh',
    r'\cosh': 'cosh',
    r'\tanh': 'tanh',
    r'\sin': 'sin',
    r'\cos': 'cos',
    r'\tan': 'tan',
    r'\exp': 'exp',
    r'\log': 'log',
    r'\ln': 'ln',
  };
  for (final MapEntry(key: motif, value: valeur) in simples.entries) {
    s = s.replaceAll(motif, valeur);
  }
  s = s.replaceAll(' ', '');
  final reste = s.contains(r'\') || s.contains('{') || s.contains('_');
  return reste ? latex : s;
}

String _groupe(String a) =>
    RegExp(r'^[0-9a-zA-Zθ.,]+$').hasMatch(a.replaceAll(' ', '')) ? a : '($a)';

String _sansExposantsGroupes(String s) {
  var sortie = s;
  while (true) {
    final debut = sortie.indexOf('^{');
    if (debut < 0) return sortie;
    final fin = _fermante(sortie, debut + 1);
    if (fin < 0) return sortie;
    final dedans = sortie.substring(debut + 2, fin);
    final simple = RegExp(r'^-?\s*[0-9a-zA-Z]+$').hasMatch(dedans.trim());
    sortie =
        '${sortie.substring(0, debut)}^'
        '${simple ? dedans.trim() : '($dedans)'}'
        '${sortie.substring(fin + 1)}';
  }
}

int _fermante(String s, int ouvrante) {
  var profondeur = 0;
  for (var i = ouvrante; i < s.length; i++) {
    if (s[i] == '{') profondeur++;
    if (s[i] == '}') {
      profondeur--;
      if (profondeur == 0) return i;
    }
  }
  return -1;
}

String _remplacerCommande(
  String s,
  String nom,
  int arguments,
  String Function(List<String>) remplacer,
) {
  final motif = '\\$nom';
  var sortie = s;
  // De la dernière à la première : les plus imbriquées d'abord.
  while (true) {
    final debut = sortie.lastIndexOf(motif);
    if (debut < 0) return sortie;
    var i = debut + motif.length;
    while (i < sortie.length && sortie[i] == ' ') {
      i++;
    }
    final valeurs = <String>[];
    for (var k = 0; k < arguments; k++) {
      while (i < sortie.length && sortie[i] == ' ') {
        i++;
      }
      if (i >= sortie.length || sortie[i] != '{') return sortie;
      final fin = _fermante(sortie, i);
      if (fin < 0) return sortie;
      valeurs.add(sortie.substring(i + 1, fin).trim());
      i = fin + 1;
    }
    sortie =
        '${sortie.substring(0, debut)}'
        '${remplacer(valeurs)}${sortie.substring(i)}';
  }
}

/// `\pi` puis `x` : sans espace, ce serait la commande `\pix`.
String _coller(String a, String b) =>
    RegExp(r'\\[a-zA-Z]+$').hasMatch(a) && RegExp('^[a-zA-Z]').hasMatch(b)
    ? '$a $b'
    : '$a$b';

class _Refus implements Exception {
  const new(this.probleme, [this.detail]);
  final ProblemeSaisie probleme;
  final String? detail;
}

enum _Genre { nombre, nom, lettre, symbole, fin }

class _Jeton {
  const new(this.genre, this.texte, {this.espaceAvant = false});
  final _Genre genre;
  final String texte;

  /// Une espace le sépare de ce qui précède.
  final bool espaceAvant;

  bool est(String s) => genre == _Genre.symbole && texte == s;
}

const _fin = _Jeton(_Genre.fin, '');

/// Les fonctions usuelles, et leur LaTeX.
const _fonctions = {
  'arcsin': r'\arcsin',
  'arccos': r'\arccos',
  'arctan': r'\arctan',
  'asin': r'\arcsin',
  'acos': r'\arccos',
  'atan': r'\arctan',
  'sinus': r'\sin',
  'cosinus': r'\cos',
  'tangente': r'\tan',
  'sinh': r'\sinh',
  'cosh': r'\cosh',
  'tanh': r'\tanh',
  'sin': r'\sin',
  'cos': r'\cos',
  'tan': r'\tan',
  'exp': r'\exp',
  'det': r'\det',
  'log': r'\log',
  'ln': r'\ln',
};

const _racines = {'racine', 'sqrt', 'rac'};
const _valeursAbsolues = {'abs'};

/// Constantes et lettres grecques écrites en toutes lettres.
const _symboles = {
  'infini': r'\infty',
  'infty': r'\infty',
  'alpha': r'\alpha',
  'beta': r'\beta',
  'gamma': r'\gamma',
  'delta': r'\delta',
  'theta': r'\theta',
  'lambda': r'\lambda',
  'omega': r'\omega',
  'phi': r'\phi',
  'pi': r'\pi',
};

/// Les caractères que le clavier d'un téléphone donne.
const _unicode = {
  '²': '^2',
  '³': '^3',
  '⁴': '^4',
  'π': ' pi ',
  'θ': ' theta ',
  'α': ' alpha ',
  'β': ' beta ',
  'γ': ' gamma ',
  'δ': ' delta ',
  'λ': ' lambda ',
  'ω': ' omega ',
  'φ': ' phi ',
  '∞': ' infini ',
  '√': ' sqrt ',
  '×': '*',
  '·': '*',
  '∙': '*',
  '÷': '/',
  '−': '-',
  '–': '-',
  '**': '^',
};

/// Des mots français, qui ne se collent pas à ce qui suit : `racines` n'est pas
/// `racine(s)`.
const _motsEntiers = {'racine', 'sinus', 'cosinus', 'tangente', 'infini'};

/// Tous les noms connus, les plus longs d'abord : `sinh` avant `sin`.
final List<String> _noms = [
  ..._fonctions.keys,
  ..._racines,
  ..._valeursAbsolues,
  ..._symboles.keys,
]..sort((a, b) => b.length - a.length);

List<_Jeton> _decouper(String brut) {
  var texte = brut;
  for (final MapEntry(key: signe, value: valeur) in _unicode.entries) {
    texte = texte.replaceAll(signe, valeur);
  }
  // Les mots qui ne servent qu'à la phrase.
  texte = texte
      .replaceAll(RegExp(r'racine\s+carr[ée]e', caseSensitive: false), 'racine')
      .replaceAll(RegExp(r'racine\s+de\b', caseSensitive: false), 'racine');
  final jetons = <_Jeton>[];
  var i = 0;
  var espace = false;
  bool chiffre(int k) => k < texte.length && RegExp('[0-9]').hasMatch(texte[k]);
  bool lettre(int k) =>
      k < texte.length && RegExp('[a-zA-ZÀ-ÿ]').hasMatch(texte[k]);
  while (i < texte.length) {
    final c = texte[i];
    if (c.trim().isEmpty) {
      espace = true;
      i++;
    } else if (chiffre(i) || (c == '.' && chiffre(i + 1))) {
      var j = i;
      while (chiffre(j)) {
        j++;
      }
      // La virgule ou le point, collés entre deux chiffres, sont décimaux.
      if (j < texte.length &&
          (texte[j] == ',' || texte[j] == '.') &&
          chiffre(j + 1)) {
        j++;
        while (chiffre(j)) {
          j++;
        }
      }
      final nombre = texte.substring(i, j);
      jetons.add(_Jeton(_Genre.nombre, nombre, espaceAvant: espace));
      i = j;
      espace = false;
    } else if (lettre(i)) {
      var j = i;
      while (lettre(j)) {
        j++;
      }
      jetons.addAll(_lireMot(texte.substring(i, j), espace));
      i = j;
      espace = false;
    } else {
      jetons.add(_Jeton(_Genre.symbole, c, espaceAvant: espace));
      i++;
      espace = false;
    }
  }
  return jetons;
}

/// `sinx`, `2pi`, `xy` : les noms connus d'abord, puis des lettres. Un long mot
/// sans aucun nom connu n'est pas un produit de lettres : on le refuse.
List<_Jeton> _lireMot(String mot, bool espaceAvant) {
  final jetons = <_Jeton>[];
  var i = 0;
  var lettresDeSuite = 0;
  while (i < mot.length) {
    String? trouve;
    for (final nom in _noms) {
      if (mot.startsWith(nom, i)) {
        trouve = nom;
        break;
      }
    }
    final espace = jetons.isEmpty && espaceAvant;
    if (trouve != null &&
        _motsEntiers.contains(trouve) &&
        i + trouve.length < mot.length) {
      throw _Refus(ProblemeSaisie.motInconnu, mot);
    }
    if (trouve != null) {
      jetons.add(_Jeton(_Genre.nom, trouve, espaceAvant: espace));
      i += trouve.length;
      lettresDeSuite = 0;
    } else {
      if (!RegExp('[a-zA-Z]').hasMatch(mot[i])) {
        throw _Refus(ProblemeSaisie.motInconnu, mot);
      }
      jetons.add(_Jeton(_Genre.lettre, mot[i], espaceAvant: espace));
      i++;
      lettresDeSuite++;
      if (lettresDeSuite > 3) throw _Refus(ProblemeSaisie.motInconnu, mot);
    }
  }
  return jetons;
}

class _Terme {
  const new(
    this.latex, {
    this.entreParentheses,
    this.commenceParChiffre = false,
  });

  final String latex;

  /// Le contenu de `(…)`, sans les parenthèses, pour une fraction.
  final String? entreParentheses;
  final bool commenceParChiffre;

  /// Sans ses parenthèses, s'il en avait.
  String get nu => entreParentheses ?? latex;
}

class _Traducteur {
  new(this._jetons, {this.denominateurLong = false});

  final List<_Jeton> _jetons;

  /// `1/2x` se lit `1/(2x)`.
  final bool denominateurLong;
  var _i = 0;

  _Jeton get _courant => _i < _jetons.length ? _jetons[_i] : _fin;
  _Jeton _voir(int n) => _i + n < _jetons.length ? _jetons[_i + n] : _fin;

  bool _prendre(String s) {
    if (_courant.est(s)) {
      _i++;
      return true;
    }
    return false;
  }

  String traduire() {
    final sortie = StringBuffer(_tete() ?? _sequence());
    while (_prendre('=')) {
      sortie.write('=');
      if (_courant.genre != _Genre.fin) sortie.write(_sequence());
    }
    if (_courant.genre != _Genre.fin) {
      throw _Refus(ProblemeSaisie.signeInattendu, _courant.texte);
    }
    return sortie.toString();
  }

  /// `k(x)=` en tête est le début d'une définition, quelle que soit la lettre.
  String? _tete() {
    if (_courant.genre == _Genre.lettre &&
        _voir(1).est('(') &&
        _voir(2).genre == _Genre.lettre &&
        _voir(3).est(')') &&
        _voir(4).est('=')) {
      final tete = '${_courant.texte}(${_voir(2).texte})';
      _i += 4;
      return tete;
    }
    return null;
  }

  /// Une somme, ou plusieurs séparées par des virgules : `x=cos(t),y=sin(t)`.
  String _sequence() {
    final sortie = StringBuffer(_somme());
    while (_courant.est(',')) {
      _i++;
      sortie
        ..write(',')
        ..write(_somme());
      if (_prendre('=')) {
        sortie
          ..write('=')
          ..write(_somme());
      }
    }
    return sortie.toString();
  }

  String _somme() {
    final sortie = StringBuffer(_produit());
    while (_courant.est('+') || _courant.est('-')) {
      sortie.write(_courant.texte);
      _i++;
      sortie.write(_produit());
    }
    return sortie.toString();
  }

  bool get _peutSuivre {
    final j = _courant;
    return switch (j.genre) {
      _Genre.nombre || _Genre.nom || _Genre.lettre => true,
      _Genre.symbole => j.est('(') || (j.est('|') && !_dansValeurAbsolue),
      _Genre.fin => false,
    };
  }

  var _dansValeurAbsolue = false;

  String _produit() {
    var signe = '';
    while (_courant.est('-') || _courant.est('+')) {
      if (_courant.est('-')) signe = signe.isEmpty ? '-' : '';
      _i++;
    }
    var courant = _puissance();
    var nu = courant.nu;
    var dernierNombre = courant.commenceParChiffre;
    final sortie = StringBuffer();
    while (true) {
      if (_courant.est('*')) {
        _i++;
        final t = _facteur();
        sortie.write('${courant.latex}\\cdot ');
        courant = t;
        nu = t.nu;
        dernierNombre = t.commenceParChiffre;
      } else if (_courant.est('/')) {
        _i++;
        final bas = denominateurLong ? _denominateurLong() : _facteur();
        final fraction = '\\frac{$nu}{${bas.nu}}';
        courant = _Terme(fraction);
        nu = fraction;
        dernierNombre = false;
      } else if (_peutSuivre) {
        if (_courant.genre == _Genre.nombre &&
            dernierNombre &&
            _courant.espaceAvant) {
          throw const _Refus(ProblemeSaisie.nombresColles);
        }
        final t = _puissance();
        final point = t.commenceParChiffre ? r'\cdot ' : '';
        courant = _Terme(_coller(courant.latex, '$point${t.latex}'));
        nu = courant.latex;
        dernierNombre = t.commenceParChiffre;
      } else {
        sortie.write(courant.latex);
        return '$signe$sortie';
      }
    }
  }

  /// Le facteur après `*` ou `/` : son signe, puis une puissance.
  _Terme _facteur() {
    if (_prendre('-')) {
      final t = _facteur();
      return _Terme('-${t.latex}', entreParentheses: '-${t.nu}');
    }
    return _puissance();
  }

  _Terme _denominateurLong() {
    final premier = _facteur();
    var latex = premier.nu;
    var tout = false;
    while (_peutSuivre && !_courant.espaceAvant) {
      final t = _puissance();
      latex = _coller(
        latex,
        '${t.commenceParChiffre ? r'\cdot ' : ''}${t.latex}',
      );
      tout = true;
    }
    return tout ? _Terme(latex) : premier;
  }

  _Terme _puissance() {
    final base = _atome();
    if (!_prendre('^')) return _suffixes(base);
    final _Terme exposant;
    if (_courant.genre == _Genre.fin) {
      throw const _Refus(ProblemeSaisie.incomplet);
    }
    exposant = _prendre('-') ? _exposantNegatif() : _puissance();
    return _suffixes(
      _Terme(
        '${base.latex}^{${exposant.nu}}',
        commenceParChiffre: base.commenceParChiffre,
      ),
    );
  }

  _Terme _exposantNegatif() {
    final t = _puissance();
    return _Terme('-${t.nu}');
  }

  _Terme _suffixes(_Terme t) {
    var courant = t;
    while (_courant.est('!') || _courant.est('°')) {
      final signe = _courant.texte == '!' ? '!' : r'^{\circ}';
      _i++;
      courant = _Terme(
        '${courant.latex}$signe',
        commenceParChiffre: courant.commenceParChiffre,
      );
    }
    return courant;
  }

  _Terme _atome() {
    final j = _courant;
    switch (j.genre) {
      case _Genre.nombre:
        _i++;
        return _Terme(j.texte, commenceParChiffre: true);
      case _Genre.nom:
        _i++;
        return _nom(j.texte);
      case _Genre.lettre:
        _i++;
        return _Terme(j.texte);
      case _Genre.symbole:
        if (_prendre('(')) return _parentheses();
        if (j.est('|') && !_dansValeurAbsolue) {
          _i++;
          _dansValeurAbsolue = true;
          final dedans = _somme();
          _dansValeurAbsolue = false;
          if (!_prendre('|')) throw const _Refus(ProblemeSaisie.incomplet);
          return _Terme('|$dedans|');
        }
        throw _Refus(ProblemeSaisie.signeInattendu, j.texte);
      case _Genre.fin:
        throw const _Refus(ProblemeSaisie.incomplet);
    }
  }

  _Terme _parentheses() {
    final dedans = _sequence();
    // Une parenthèse pas encore fermée se ferme toute seule.
    _prendre(')');
    return _Terme('\\left($dedans\\right)', entreParentheses: dedans);
  }

  _Terme _nom(String nom) {
    if (_symboles.containsKey(nom)) return _Terme(_symboles[nom]!);
    if (_racines.contains(nom)) {
      return _Terme('\\sqrt{${_argument()}}');
    }
    if (_valeursAbsolues.contains(nom)) {
      return _Terme('|${_argument()}|');
    }
    final latex = _fonctions[nom]!;
    var exposant = '';
    if (_prendre('^')) {
      exposant = '^{${_puissance().nu}}';
    }
    return _Terme('$latex$exposant\\left(${_argument()}\\right)');
  }

  /// Ce à quoi une fonction s'applique. Sans parenthèses : `sin 2x` est
  /// `sin(2x)`, et `sin x cos x` s'arrête à la fonction suivante.
  String _argument() {
    if (_prendre('(')) {
      final dedans = _somme();
      _prendre(')');
      return dedans;
    }
    if (_courant.genre == _Genre.fin) {
      throw const _Refus(ProblemeSaisie.incomplet);
    }
    var latex = _prendre('-') ? '-${_puissance().latex}' : _puissance().latex;
    while (_courant.genre == _Genre.lettre ||
        (_courant.genre == _Genre.nom &&
            _symboles.containsKey(_courant.texte))) {
      latex = _coller(latex, _puissance().latex);
    }
    return latex;
  }
}
