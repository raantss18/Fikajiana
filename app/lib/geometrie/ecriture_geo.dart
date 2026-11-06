import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana_math/fikajiana_math.dart';

/// Ce que vaut un objet, écrit comme au tableau : `(2 ; 3)`, `y = 2x + 1`,
/// `(x − 1)² + y² = 4`, `45°`. `null` s'il n'a pas de valeur à montrer.
String? ecrireForme(FormeGeo? forme, {required bool francais}) {
  String n(double v) => texteValeur(v, virgule: francais);
  return switch (forme) {
    final PointGeo p =>
      francais ? '(${n(p.x)} ; ${n(p.y)})' : '(${n(p.x)}, ${n(p.y)})',
    final DroiteGeo d => _droite(d, francais),
    final CercleGeo c =>
      '${_carre('x', c.centre.x, n)} + ${_carre('y', c.centre.y, n)} '
          '= ${n(c.rayon * c.rayon)}',
    final AngleGeo a => '${n(a.valeur)}°',
    final NombreGeo v => n(v.valeur),
    final ConiqueGeo k => _conique(k, n),
    PolygoneGeo() || LieuGeo() || null => null,
  };
}

String _carre(String lettre, double centre, String Function(double) n) {
  if (centre.abs() < 1e-9) return '$lettre²';
  return centre > 0
      ? '($lettre − ${n(centre)})²'
      : '($lettre + ${n(-centre)})²';
}

String _droite(DroiteGeo d, bool francais) {
  String n(double v) => texteValeur(v, virgule: francais);
  if (d.b.abs() < 1e-9) return 'x = ${n(d.c / d.a)}';
  final (pente, ordonnee) = (-d.a / d.b, d.c / d.b);
  return 'y = ${_terme(pente, 'x', n, premier: true)}'
          '${_terme(ordonnee, '', n, premier: pente.abs() < 1e-9)}'
      .replaceFirst(RegExp(r'= $'), '= 0');
}

/// `2x`, ` + 2x`, ` − x` ; rien pour un coefficient nul.
String _terme(
  double coefficient,
  String lettre,
  String Function(double) n, {
  required bool premier,
}) {
  if (coefficient.abs() < 1e-9) return '';
  final absolu = coefficient.abs();
  final corps = lettre.isNotEmpty && (absolu - 1).abs() < 1e-9
      ? lettre
      : '${n(absolu)}$lettre';
  if (premier) return coefficient < 0 ? '−$corps' : corps;
  return coefficient < 0 ? ' − $corps' : ' + $corps';
}

String _conique(ConiqueGeo k, String Function(double) n) {
  // Unitaire : le premier coefficient non nul vaut 1, c'est plus lisible.
  final c = k.coefficients;
  final pivot = c.firstWhere((v) => v.abs() > 1e-9);
  final termes = <String>[];
  const lettres = ['x²', 'xy', 'y²', 'x', 'y', ''];
  for (var i = 0; i < 6; i++) {
    final v = c[i] / pivot;
    final t = _terme(v, lettres[i], n, premier: termes.isEmpty);
    if (t.isNotEmpty) termes.add(t);
  }
  return '${termes.join()} = 0';
}
