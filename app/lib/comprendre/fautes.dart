import 'package:fikajiana/comprendre/copie.dart';
import 'package:fikajiana/comprendre/etapes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';

/// Une faute classique de calcul, reconnue entre deux lignes d'une copie.
enum Faute {
  /// (a + b)² écrit a² + b² : le double produit 2ab est oublié.
  doubleProduit,

  /// k(a + b) écrit ka + b : le facteur n'a multiplié que le premier terme.
  distribution,

  /// −(a + b) écrit −a + b : le moins n'a changé que le premier signe.
  signeParenthese,

  /// Un terme passe de l'autre côté du = sans changer de signe.
  deplacementSansSigne,

  /// a·x = c donne x = c − a : on a soustrait au lieu de diviser.
  soustraireAuLieuDeDiviser,

  /// a·x = c donne x = c × a : on a multiplié au lieu de diviser.
  multiplierAuLieuDeDiviser,

  /// a·x = c donne x = a / c : la division est à l'envers.
  divisionALEnvers,

  /// La solution a le mauvais signe.
  signeDeLaSolution,
}

/// La faute trouvée, et la ligne juste à sa place (`null` s'il n'y en a pas
/// une seule à montrer).
class PisteFaute {
  const new(this.faute, this.correction);

  final Faute faute;

  /// Le LaTeX de ce qu'il fallait écrire.
  final String? correction;

  @override
  String toString() => '${faute.name} : $correction';
}

/// Cherche la faute classique qui mène de [avant] à [ici], quand [ici] est
/// fausse : Giac écrit la ligne qu'aurait donnée chaque faute du catalogue,
/// et la piste n'est donnée que si l'une d'elles dit exactement la même
/// chose que [ici] (mêmes solutions, ou différence nulle). Rien n'est
/// deviné : sinon, `null`.
Future<PisteFaute?> chercherFaute(
  Moteur moteur,
  LigneCopie avant,
  LigneCopie ici,
) async {
  Future<ReponseGiac?> g(String e) => giacAuTableau(moteur, e);
  final x = ici.x;
  if (avant.sorte != ici.sorte) return null;

  // Ce que dit [ici] : ses solutions, ou sa forme simplifiée.
  final cible = x == null ? null : await g(_solutions(ici.giac, x));
  if (x != null && cible == null) return null;
  Future<bool> commeIci(String candidat) async {
    if (x == null) {
      final ecart = await g('simplify(($candidat)-(${ici.giac}))');
      return ecart?.exact.trim() == '0';
    }
    final s = await g(_solutions(candidat, x));
    return s != null && s.exact == cible!.exact;
  }

  // 1. Une parenthèse mal développée, dans l'expression ou l'équation.
  for (final (debut, fin) in _parentheses(avant.giac)) {
    final dedans = avant.giac.substring(debut + 1, fin);
    final termes = await _termes(g, dedans);
    if (termes == null || termes.length < 2) continue;
    final interieur = await g(dedans);
    if (interieur == null) continue;
    final reste = '(($dedans)-(${termes.first}))';

    // (a + b)² → a² + b² (ou a² − b²).
    if (avant.giac.startsWith('^(2)', fin + 1) && termes.length == 2) {
      final [t1, t2] = termes;
      for (final faux in ['(($t1)^2+($t2)^2)', '(($t1)^2-($t2)^2)']) {
        final candidat = _remplacer(avant.giac, debut, fin + 5, faux);
        if (await commeIci(candidat)) {
          final juste = await g('expand(($dedans)^2)');
          return PisteFaute(
            Faute.doubleProduit,
            juste == null
                ? null
                : '\\left(${interieur.latex}\\right)^{2}=${juste.latex}',
          );
        }
      }
    }

    // k(a + b) → ka + b.
    final facteur = RegExp(r'(\d+)\*$')
        .firstMatch(avant.giac.substring(0, debut));
    if (facteur != null) {
      final k = facteur[1]!;
      final candidat = _remplacer(
        avant.giac,
        facteur.start,
        fin + 1,
        '($k*(${termes.first})+$reste)',
      );
      if (await commeIci(candidat)) {
        final juste = await g('expand($k*($dedans))');
        return PisteFaute(
          Faute.distribution,
          juste == null
              ? null
              : '$k\\left(${interieur.latex}\\right)=${juste.latex}',
        );
      }
    }

    // −(a + b) → −a + b.
    if (debut > 0 && avant.giac[debut - 1] == '-') {
      final candidat = _remplacer(
        avant.giac,
        debut - 1,
        fin + 1,
        '-(${termes.first})+$reste',
      );
      if (await commeIci(candidat)) {
        final juste = await g('expand(-($dedans))');
        return PisteFaute(
          Faute.signeParenthese,
          juste == null
              ? null
              : '-\\left(${interieur.latex}\\right)=${juste.latex}',
        );
      }
    }
  }
  if (x == null) return null;

  // 2. Les fautes propres aux équations.
  final membres = _membres(avant.giac);
  if (membres == null) return null;
  final (gauche, droite) = membres;

  // Un terme passé de l'autre côté sans changer de signe.
  for (final (cote, autre, aGauche) in [
    (gauche, droite, true),
    (droite, gauche, false),
  ]) {
    final termes = await _termes(g, 'expand($cote)');
    if (termes == null || termes.length < 2) continue;
    for (final t in termes) {
      // Comme un élève : les nombres passent à droite, les termes en x à
      // gauche.
      final avecX = (await g('has($t,$x)'))?.exact.trim() == '1';
      if (avecX == aGauche) continue;
      final candidat = aGauche
          ? '(($cote)-($t))=(($autre)+($t))'
          : '(($autre)+($t))=(($cote)-($t))';
      if (await commeIci(candidat)) {
        final g1 = await g('expand(($gauche)-($t))');
        final d1 = await g('expand(($droite)-($t))');
        return PisteFaute(
          Faute.deplacementSansSigne,
          g1 == null || d1 == null ? null : '${g1.latex}=${d1.latex}',
        );
      }
    }
  }

  // a·x = c : soustraire, multiplier ou diviser à l'envers.
  final degreDroite = await g('degree($droite,$x)');
  final constante = await g('subst(expand($gauche),$x=0)');
  final degreGauche = await g('degree(expand($gauche),$x)');
  final a = await g('coeff(expand($gauche),$x,1)');
  if (degreDroite?.exact.trim() == '0' &&
      constante?.exact.trim() == '0' &&
      degreGauche?.exact.trim() == '1' &&
      a != null &&
      a.exact.trim() != '1') {
    final c = droite;
    final solution = await g('normal(($c)/(${a.exact}))');
    final cLatex = await g(c);
    for (final (faute, faux) in [
      (Faute.soustraireAuLieuDeDiviser, '$x=($c)-(${a.exact})'),
      (Faute.multiplierAuLieuDeDiviser, '$x=($c)*(${a.exact})'),
      (Faute.divisionALEnvers, '$x=(${a.exact})/($c)'),
    ]) {
      if (await commeIci(faux)) {
        return PisteFaute(
          faute,
          solution == null || cLatex == null
              ? null
              : '$x=\\frac{${cLatex.latex}}{${a.latex}}=${solution.latex}',
        );
      }
    }
  }

  // La solution a le mauvais signe.
  if (await commeIci('subst(($gauche)-($droite),$x=-$x)=0')) {
    final une = await g('solve(${avant.giac},$x)[0]');
    final taille = await g('size(solve(${avant.giac},$x))');
    return PisteFaute(
      Faute.signeDeLaSolution,
      une == null || taille?.exact.trim() != '1' ? null : '$x=${une.latex}',
    );
  }
  return null;
}

/// Les pistes de chaque ligne fausse d'une copie déjà vérifiée.
Future<List<PisteFaute?>> pistesCopie(
  Moteur moteur,
  List<LigneCopie> lignes,
  List<VerdictLigne> verdicts,
) async {
  final pistes = <PisteFaute?>[];
  for (var i = 0; i < lignes.length; i++) {
    pistes.add(
      i > 0 && verdicts[i] == VerdictLigne.fausse
          ? await chercherFaute(moteur, lignes[i - 1], lignes[i])
          : null,
    );
  }
  return pistes;
}

String _solutions(String equation, String x) =>
    'sort(simplify(solve($equation,$x)))';

/// Les termes d'une somme, tels que Giac les voit (`x+1` : `x`, `1`).
Future<List<String>?> _termes(
  Future<ReponseGiac?> Function(String) g,
  String expression,
) async {
  final sommet = await g('sommet($expression)');
  if (sommet == null) return null;
  if (sommet.exact.replaceAll("'", '').trim() != '+') {
    final seul = await g(expression);
    return seul == null ? null : [seul.exact];
  }
  final n = int.tryParse((await g('size(feuille($expression))'))?.exact ?? '');
  if (n == null) return null;
  final termes = <String>[];
  for (var k = 0; k < n; k++) {
    final t = await g('feuille($expression)[$k]');
    if (t == null) return null;
    termes.add(t.exact);
  }
  return termes;
}

/// Chaque paire de parenthèses qui se répondent, de la plus extérieure à
/// la plus intérieure.
List<(int, int)> _parentheses(String s) {
  final paires = <(int, int)>[];
  final pile = <int>[];
  for (var i = 0; i < s.length; i++) {
    if (s[i] == '(') pile.add(i);
    if (s[i] == ')' && pile.isNotEmpty) paires.add((pile.removeLast(), i));
  }
  return paires..sort((a, b) => a.$1.compareTo(b.$1));
}

String _remplacer(String s, int debut, int fin, String par) =>
    '${s.substring(0, debut)}$par${s.substring(fin)}';

/// `(G)=(D)` lu en ses deux membres, coupé au `=` hors de toute parenthèse.
(String, String)? _membres(String equation) {
  var profondeur = 0;
  for (var i = 0; i < equation.length; i++) {
    final c = equation[i];
    if (c == '(') profondeur++;
    if (c == ')') profondeur--;
    if (c == '=' && profondeur == 0) {
      return (equation.substring(0, i), equation.substring(i + 1));
    }
  }
  return null;
}
