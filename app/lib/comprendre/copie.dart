import 'package:fikajiana/moteur/moteur.dart';

/// Une ligne d'une démarche écrite : une équation en [x], ou une expression.
class LigneCopie {
  /// [giac] : `(gauche)=(droite)` pour une équation en [x], l'expression
  /// sinon ([x] absent).
  const new(this.latex, this.giac, [this.x]);

  /// Une équation `gauche = droite`, à résoudre en [x].
  factory equation(String latex, String gauche, String droite, String x) =>
      LigneCopie(latex, '($gauche)=($droite)', x);

  /// Ce qui est écrit.
  final String latex;

  /// Traduit pour Giac.
  final String giac;

  /// L'inconnue d'une équation, `null` pour une expression.
  final String? x;

  /// Deux lignes se comparent si elles sont de la même sorte.
  String get sorte => x == null ? 'expression' : 'équation en $x';
}

/// Ce que vaut une ligne par rapport à celle d'avant.
enum VerdictLigne {
  /// La première ligne : l'énoncé, rien à lui comparer.
  depart,

  /// Elle dit la même chose que la ligne d'avant.
  juste,

  /// Elle ne dit pas la même chose : l'erreur est dans ce passage.
  fausse,

  /// Giac n'a pas su comparer : ni cochée ni barrée.
  inconnue,
}

/// Vérifie une démarche ligne par ligne, comme un professeur relit une copie
/// (demande d'Antsa, 2026-11-14) : chaque ligne est comparée à la précédente.
///
/// Deux équations disent la même chose si elles ont les mêmes solutions
/// (`solve` de Giac) ; deux expressions, si leur différence se simplifie en 0.
/// Dans le doute (calcul arrêté, erreur), le verdict est « inconnue » :
/// jamais « faux » sans preuve.
Future<List<VerdictLigne>> verifierCopie(
  Moteur moteur,
  List<LigneCopie> lignes,
) async {
  Future<String?> exact(String entree) async {
    final r = await moteur.calculer(entree);
    if (r.arrete || r.erreur != null) return null;
    final e = r.exact.trim();
    return e.isEmpty || e == 'undef' ? null : e;
  }

  final verdicts = <VerdictLigne>[];
  for (var i = 0; i < lignes.length; i++) {
    if (i == 0) {
      verdicts.add(VerdictLigne.depart);
      continue;
    }
    final avant = lignes[i - 1];
    final ici = lignes[i];
    if (avant.sorte != ici.sorte) {
      verdicts.add(VerdictLigne.inconnue);
      continue;
    }
    final x = ici.x;
    if (x == null) {
      final ecart = await exact('simplify((${avant.giac})-(${ici.giac}))');
      verdicts.add(
        ecart == null
            ? VerdictLigne.inconnue
            : ecart == '0'
            ? VerdictLigne.juste
            : VerdictLigne.fausse,
      );
      continue;
    }
    final a = await exact('sort(simplify(solve(${avant.giac},$x)))');
    final b = await exact('sort(simplify(solve(${ici.giac},$x)))');
    verdicts.add(
      a == null || b == null
          ? VerdictLigne.inconnue
          : a == b
          ? VerdictLigne.juste
          : VerdictLigne.fausse,
    );
  }
  return verdicts;
}
