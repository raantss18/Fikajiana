import 'package:flutter/services.dart';

/// Un signe de `collecte/classes.txt` : `id⇥signe⇥LaTeX`.
class Signe {
  const new(this.id, this.signe, this.latex);

  final String id;
  final String signe;
  final String latex;

  /// Ce que la personne lit sous le signe, pour ne pas confondre `O` et `0`.
  String get precision {
    if (RegExp(r'^[0-9]$').hasMatch(id)) return 'chiffre';
    if (RegExp(r'^[a-z]{1}$').hasMatch(id)) return 'lettre minuscule';
    if (RegExp(r'^[A-Z]{1}$').hasMatch(id)) return 'lettre majuscule';
    return _noms[id] ?? id.replaceAll('_', ' ');
  }
}

/// Le nom des signes dont l'id n'est pas parlant ; sinon l'id est lu tel quel.
const _noms = {
  'fois': 'multiplié par',
  'point_fois': 'point de multiplication',
  'divise': 'divisé par',
  'barre': 'barre oblique',
  'egal': 'égal',
  'inf': 'inférieur à',
  'sup': 'supérieur à',
  'infeg': 'inférieur ou égal',
  'supeg': 'supérieur ou égal',
  'diff': 'différent de',
  'approx': 'environ égal',
  'plusmoins': 'plus ou moins',
  'par_g': 'parenthèse ouvrante',
  'par_d': 'parenthèse fermante',
  'cro_g': 'crochet ouvrant',
  'cro_d': 'crochet fermant',
  'acc_g': 'accolade ouvrante',
  'acc_d': 'accolade fermante',
  'abs': 'barre verticale',
  'pointvirgule': 'point-virgule',
  'deuxpoints': 'deux-points',
  'fact': 'point d’exclamation',
  'prime': 'prime',
  'integrale': 'intégrale',
  'somme': 'somme (sigma majuscule)',
  'infini': 'infini',
  'fleche': 'flèche',
  'implique': 'implique',
  'equiv': 'équivaut à',
  'appartient': 'appartient à',
  'Delta': 'delta majuscule',
  'theta': 'thêta',
  'mu': 'mu',
  'phi': 'phi',
  'omega': 'oméga',
  'lambda': 'lambda',
  'sigma': 'sigma minuscule',
  'delta': 'delta minuscule',
};

/// Les signes et les expressions à recopier, lus dans les assets.
class Catalogue {
  const new(this.signes, this.expressions);

  final List<Signe> signes;
  final List<String> expressions;

  static Iterable<String> _lignes(String texte) => texte
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty && !l.startsWith('#'));

  static List<Signe> lireClasses(String texte) => [
    for (final ligne in _lignes(texte))
      if (ligne.split('\t') case [final id, final signe, final latex])
        Signe(id, signe, latex)
      else
        throw FormatException('Ligne de classes.txt mal formée', ligne),
  ];

  static List<String> lireExpressions(String texte) =>
      _lignes(texte).map((l) => l.trim()).toList();

  static Future<Catalogue> charger([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    return Catalogue(
      lireClasses(await b.loadString('assets/classes.txt')),
      lireExpressions(await b.loadString('assets/expressions.txt')),
    );
  }

  Signe? signe(String id) {
    for (final s in signes) {
      if (s.id == id) return s;
    }
    return null;
  }
}
