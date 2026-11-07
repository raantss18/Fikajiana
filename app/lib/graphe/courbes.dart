import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/foundation.dart';

/// Les quatre manières d'écrire une courbe.
enum GenreCourbe { fonction, implicite, parametree, polaire }

/// Une courbe à tracer : ce qui a été écrit, et sa traduction pour le calcul.
class Courbe {
  new({
    required this.latex,
    required this.corps,
    required this.variable,
    this.genre = GenreCourbe.fonction,
    this.corpsY,
    this.debut,
    this.fin,
    this.nom,
  });

  /// `C` pour `C : x^2+y^3=0` : un objet de la Figure, à son nom.
  final String? nom;

  final String latex;

  /// La fonction ; pour une courbe paramétrée, son abscisse ; pour une courbe
  /// implicite `g = d`, `g - d`.
  final String corps;
  final String variable;
  final GenreCourbe genre;

  /// L'ordonnée d'une courbe paramétrée.
  final String? corpsY;

  /// Le domaine écrit après la courbe, sinon celui par défaut.
  final double? debut;
  final double? fin;

  final _fonctions = <bool, FonctionReelle>{};

  FonctionReelle fonction({required bool degres}) => _fonctions.putIfAbsent(
    degres,
    () => compilerFonction(corps, variable: variable, degres: degres),
  );

  final _implicites = <bool, FonctionDeuxVariables>{};
  final _ordonnees = <bool, FonctionReelle>{};

  /// De quoi la dessiner dans [fenetre].
  List<List<PointTrace>> tracer(Fenetre fenetre, {required bool degres}) {
    final tour = degres ? 180 / math.pi : 1.0;
    switch (genre) {
      case GenreCourbe.fonction:
        return tracerFonction(fonction(degres: degres), fenetre);
      case GenreCourbe.implicite:
        return tracerImplicite(
          _implicites.putIfAbsent(
            degres,
            () => compilerFonctionXY(corps, degres: degres),
          ),
          fenetre,
        );
      case GenreCourbe.parametree:
        return tracerParametree(
          fonction(degres: degres),
          _ordonnees.putIfAbsent(
            degres,
            () => compilerFonction(corpsY!, variable: variable, degres: degres),
          ),
          debut ?? -10 * tour,
          fin ?? 10 * tour,
          fenetre,
        );
      case GenreCourbe.polaire:
        final r = fonction(degres: degres);
        // θ est compté comme le demandent les réglages.
        return tracerParametree(
          (t) => r(t) * math.cos(t / tour),
          (t) => r(t) * math.sin(t / tour),
          debut ?? 0,
          fin ?? 4 * math.pi * tour,
          fenetre,
        );
    }
  }
}

/// `, t \in [0, \pi]` à la fin d'une courbe.
final _plage = RegExp(
  r'^(.*),\s*(?:t|\\theta)\s*\\in\s*(?:\\left)?\[(.*),(.*?)(?:\\right)?\]\s*$',
  dotAll: true,
);

/// Traduit `f(x)=x^2`, `y=2x+1`, `x^2`, `x^2+y^2=4`, `(\cos(t),\sin(t))`,
/// `x=\cos(t),y=\sin(t)` ou `r=2\cos(\theta)` ; `null` si ce n'est pas traçable.
/// `C : x^2+y^3=0`, `C_1: …` : un nom, puis la courbe. `f(x)=…` n'en est pas.
final _nomDeCourbe = RegExp(
  r'^\s*([A-Za-z](?:\s*_\s*\{?\s*\d+\s*\}?)?)\s*:(?!=)\s*(.+)$',
);

/// Le nom et la courbe d'une écriture `C : …` ; sans nom, `(null, latex)`.
(String?, String) separerNomDeCourbe(String latex) {
  final m = _nomDeCourbe.firstMatch(latex);
  if (m == null) return (null, latex);
  return (m[1]!.replaceAll(RegExp(r'[\s{}]'), ''), m[2]!.trim());
}

Courbe? lireCourbe(String latex) {
  try {
    final (nom, corps) = separerNomDeCourbe(latex);
    final lue = _lire(corps);
    if (lue == null) return null;
    final courbe = nom == null
        ? lue
        : Courbe(
            latex: latex,
            corps: lue.corps,
            variable: lue.variable,
            genre: lue.genre,
            corpsY: lue.corpsY,
            debut: lue.debut,
            fin: lue.fin,
            nom: nom,
          );
    // Une erreur d'écriture se voit ici, pas au moment de dessiner.
    const essai = Fenetre(
      xMin: -1,
      xMax: 1,
      yMin: -1,
      yMax: 1,
      largeurPixels: 16,
      hauteurPixels: 16,
    );
    courbe.tracer(essai, degres: false);
    return courbe;
  } on ErreurLatex {
    return null;
  } on ErreurEvaluation {
    return null;
  }
}

/// Ce qui n'a de sens que tracé : `x^2+y^2=9`, `(\cos(t),\sin(t))`,
/// `r=1+\cos(\theta)`. `x^2=2`, `2y=4` ou `r=2` restent des équations à résoudre.
bool estCourbeSeule(String latex) {
  final Courbe? courbe;
  try {
    courbe = lireCourbe(latex);
  } on Object {
    return false;
  }
  if (courbe == null) return false;
  bool contient(String nom) => RegExp('\\b$nom\\b').hasMatch(courbe!.corps);
  return switch (courbe.genre) {
    GenreCourbe.fonction => false,
    GenreCourbe.parametree => true,
    GenreCourbe.polaire => contient('theta') || contient('t'),
    GenreCourbe.implicite => contient('x') && contient('y'),
  };
}

Courbe? _lire(String latex) {
  var texte = latex.trim();
  double? debut;
  double? fin;
  final plage = _plage.firstMatch(texte);
  if (plage != null) {
    (debut, fin) = (_nombre(plage[2]!), _nombre(plage[3]!));
    if (debut == null || fin == null || debut >= fin) return null;
    texte = plage[1]!.trim();
  }
  final parametree = _parametree(latex, texte, debut, fin);
  if (parametree != null) return parametree;

  final analyse = analyserLatex(texte);
  final membres = analyse.membres;
  if (membres != null) {
    final (gauche, droite) = membres;
    // `r=2` est un cercle ; `r=x` reste une équation.
    final polaire =
        RegExp(r'^r(\*?\(theta\))?$').hasMatch(gauche) &&
        !RegExp(r'\b[xy]\b').hasMatch(droite);
    if (polaire) {
      return Courbe(
        latex: latex,
        corps: droite,
        variable: RegExp(r'\bt\b').hasMatch(droite) ? 't' : 'theta',
        genre: GenreCourbe.polaire,
        debut: debut,
        fin: fin,
      );
    }
    // `x^2=2` reste une équation à résoudre ; `x=3` est une droite verticale.
    final tous = '$gauche $droite';
    final enY = RegExp(r'\by\b').hasMatch(tous);
    if (!enY && gauche != 'x') return null;
    return Courbe(
      latex: latex,
      corps: '($gauche)-($droite)',
      variable: 'x',
      genre: GenreCourbe.implicite,
    );
  }
  final fonction = analyse.type == TypeExpression.fonction;
  if (!fonction && analyse.type != TypeExpression.calcul) return null;
  final corps = fonction ? analyse.corps! : analyse.giac;
  // `r(\theta)=…` s'écrit aussi comme une fonction.
  if (fonction &&
      analyse.giac.startsWith('r(') &&
      analyse.inconnues.single == 'theta') {
    return Courbe(
      latex: latex,
      corps: corps,
      variable: 'theta',
      genre: GenreCourbe.polaire,
      debut: debut,
      fin: fin,
    );
  }
  return Courbe(
    latex: latex,
    corps: corps,
    variable: fonction ? analyse.inconnues.single : 'x',
  );
}

Courbe? _parametree(String latex, String texte, double? debut, double? fin) {
  var interieur = texte;
  if (interieur.startsWith(r'\left(') && interieur.endsWith(r'\right)')) {
    interieur = interieur.substring(6, interieur.length - 7);
  } else if (interieur.startsWith('(') && interieur.endsWith(')')) {
    interieur = interieur.substring(1, interieur.length - 1);
  }
  final morceaux = _couperVirgule(interieur);
  if (morceaux == null) return null;
  var (ex, ey) = morceaux;
  // La forme `x=…, y=…`.
  final egaux = RegExp(r'^x\s*=(.*)$', dotAll: true).firstMatch(ex);
  final egauy = RegExp(r'^y\s*=(.*)$', dotAll: true).firstMatch(ey);
  if (egaux != null && egauy != null) {
    (ex, ey) = (egaux[1]!, egauy[1]!);
  }
  final (gx, gy) = (analyserLatex(ex), analyserLatex(ey));
  if (gx.type != TypeExpression.calcul || gy.type != TypeExpression.calcul) {
    return null;
  }
  final ensemble = '${gx.giac} ${gy.giac}';
  final variable = RegExp(r'\btheta\b').hasMatch(ensemble) ? 'theta' : 't';
  if (!RegExp('\\b$variable\\b').hasMatch(ensemble)) return null;
  return Courbe(
    latex: latex,
    corps: gx.giac,
    corpsY: gy.giac,
    variable: variable,
    genre: GenreCourbe.parametree,
    debut: debut,
    fin: fin,
  );
}

/// Coupe sur l'unique virgule hors de toute parenthèse.
(String, String)? _couperVirgule(String texte) {
  var profondeur = 0;
  int? virgule;
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if ('({['.contains(c)) profondeur++;
    if (')}]'.contains(c)) profondeur--;
    if (profondeur < 0) return null;
    if (c == ',' && profondeur == 0) {
      if (virgule != null) return null;
      virgule = i;
    }
  }
  if (virgule == null) return null;
  return (
    texte.substring(0, virgule).trim(),
    texte.substring(virgule + 1).trim(),
  );
}

double? _nombre(String latex) {
  try {
    final v = compilerFonction(analyserLatex(latex).giac, variable: '_')(0);
    return v.isFinite ? v : null;
  } on ErreurLatex {
    return null;
  } on ErreurEvaluation {
    return null;
  }
}

/// Les fonctions tracées, gardées sur l'appareil.
class Courbes extends ChangeNotifier {
  new({this.fichier}) {
    _charger();
  }

  void _charger() {
    final fichier = this.fichier;
    if (fichier == null || !fichier.existsSync()) return;
    try {
      final liste = jsonDecode(fichier.readAsStringSync()) as List<dynamic>;
      _courbes.addAll(liste.cast<String>().map(lireCourbe).nonNulls);
    } on Object {
      // Un fichier abîmé est mis de côté, jamais écrasé.
      fichier.renameSync('${fichier.path}.illisible');
    }
  }

  static const int maximum = 6;

  File? fichier;
  final _courbes = <Courbe>[];

  List<Courbe> get liste => List.unmodifiable(_courbes);

  /// Les noms des objets de la Figure : une courbe nommée ne les prend pas.
  Set<String> Function() nomsPris = () => const {};

  /// Les noms des courbes.
  Set<String> get noms => {for (final c in _courbes) ?c.nom};

  /// [nom], ou `C_1`, `C_2`… s'il est déjà pris (demande d'Antsa).
  String nomLibre(String nom) {
    final pris = {...nomsPris(), ...noms};
    if (!pris.contains(nom)) return nom;
    final base = nom.split('_').first;
    for (var i = 1; ; i++) {
      if (!pris.contains('${base}_$i')) return '${base}_$i';
    }
  }

  /// Ajoute [latex] ; `false` s'il n'est pas traçable. Déjà là : rien à faire.
  /// Un nom déjà pris devient `C_1`.
  bool ajouter(String latex) {
    var courbe = lireCourbe(latex);
    if (courbe == null) return false;
    final nom = courbe.nom;
    if (nom != null) {
      final deja = _courbes.where((c) => c.nom == nom).firstOrNull;
      if (deja != null && deja.corps == courbe.corps) return true;
      final libre = nomLibre(nom);
      if (libre != nom) {
        courbe = lireCourbe('$libre : ${separerNomDeCourbe(latex).$2}')!;
      }
    }
    final nouvelle = courbe;
    if (nouvelle.nom == null &&
        _courbes.any(
          (c) => c.corps == nouvelle.corps && c.corpsY == nouvelle.corpsY,
        )) {
      return true;
    }
    if (_courbes.length == maximum) _courbes.removeAt(0);
    _courbes.add(nouvelle);
    _changer();
    return true;
  }

  /// Remplace la courbe [indice] ; `false` si [latex] n'est pas traçable.
  bool remplacer(int indice, String latex) {
    final courbe = lireCourbe(latex);
    if (courbe == null) return false;
    _courbes[indice] = courbe;
    _changer();
    return true;
  }

  /// Passe aux courbes gardées dans [autre].
  void changerDeFichier(File? autre) {
    fichier = autre;
    _courbes.clear();
    _charger();
    notifyListeners();
  }

  void retirer(int indice) {
    _courbes.removeAt(indice);
    _changer();
  }

  void _changer() {
    notifyListeners();
    fichier?.writeAsStringSync(jsonEncode([for (final c in _courbes) c.latex]));
  }
}
