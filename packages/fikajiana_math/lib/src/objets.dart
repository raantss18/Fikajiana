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
