import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/calcul/action_manuscrite.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';

/// Le mot écrit à la main d'une action proposée.
String motProposition(AppLocalizations l10n, GenreProposition genre) =>
    switch (genre) {
      GenreProposition.resoudre => l10n.motResoudre,
      GenreProposition.factoriser => l10n.motFactoriser,
      GenreProposition.developper => l10n.motDevelopper,
      GenreProposition.valeur => l10n.motValeur,
      GenreProposition.tangente => l10n.motTangente,
      GenreProposition.limite => l10n.motLimite,
      GenreProposition.inverse => l10n.motInverse,
      GenreProposition.deriver => l10n.motDeriver,
      GenreProposition.integrer => l10n.motIntegrer,
      GenreProposition.tracer => l10n.motTracer,
      GenreProposition.determinant => l10n.motDeterminant,
    };

/// Ce que TalkBack dit d'une action proposée, en entier.
String libelleProposition(AppLocalizations l10n, GenreProposition genre) =>
    switch (genre) {
      GenreProposition.resoudre => l10n.proposerResoudre,
      GenreProposition.factoriser => l10n.proposerFactoriser,
      GenreProposition.developper => l10n.proposerDevelopper,
      GenreProposition.valeur => l10n.proposerValeur,
      GenreProposition.tangente => l10n.proposerTangente,
      GenreProposition.limite => l10n.proposerLimite,
      GenreProposition.inverse => l10n.proposerInverse,
      GenreProposition.deriver => l10n.proposerDeriver,
      GenreProposition.integrer => l10n.proposerIntegrer,
      GenreProposition.tracer => l10n.proposerTracer,
      GenreProposition.determinant => l10n.proposerDeterminant,
    };

/// Une entrée de la liste d'une ligne : son mot écrit à la main, ce que
/// TalkBack en dit, et ce qu'elle fait.
@immutable
class EntreeLigne {
  const new({
    required this.cle,
    required this.mot,
    required this.libelle,
    required this.agir,
    this.apercu,
    this.icone,
    this.choisie = false,
  });

  /// Pour les tests : `juste`, `faux`, `corriger`, `tracer`, `deriver`…
  final String cle;
  final String mot;
  final String libelle;
  final VoidCallback agir;

  /// Une formule en petit à côté du mot : la ligne qui sera posée, ou une
  /// autre lecture possible.
  final String? apercu;

  /// Un dessin devant le mot (👍, 👎), jamais seul : le mot est là.
  final IconData? icone;

  /// L'entrée déjà choisie (la ligne jugée juste) : icône pleine.
  final bool choisie;
}

/// Le seul bouton d'une ligne (Antsa, 2026-11-08 : « dans la même liste
/// déroulante, même l'option de modification ») : il ouvre une liste avec
/// juste, faux, corriger, les autres lectures, tracer ou placer, et ce qu'on
/// peut faire de la ligne. Plus rien d'autre n'est posé à côté d'elle.
///
/// Le dessin, tracé à la main : une flèche qui descend puis part à droite
/// (« écrire la suite dessous ») et trois points (« au choix ») ; une petite
/// coche quand la ligne est jugée juste, une croix si elle est jugée fausse.
/// TalkBack lit son nom, l'état et les entrées. Cible de 48 dp (règle 9).
class BoutonLigne extends StatelessWidget {
  const new({
    required this.entrees,
    required this.surTouche,
    this.juge,
    super.key,
  });

  final List<EntreeLigne> entrees;

  /// Jugée juste (`true`), fausse (`false`), pas encore (`null`).
  final bool? juge;

  /// Le toucher laisse aussi un point dans l'encre (TraverseEcriture) : il
  /// s'efface dès l'ouverture, sinon il se lit comme une ligne (Pad 7).
  final VoidCallback surTouche;

  Future<void> _ouvrir(BuildContext context) async {
    surTouche();
    final theme = Theme.of(context);
    final boite = context.findRenderObject()! as RenderBox;
    final dessus =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    // Le menu s'ouvre sous le bouton : la ligne reste visible.
    final bas = boite.localToGlobal(
      boite.size.bottomLeft(Offset.zero),
      ancestor: dessus,
    );
    final choix = await showMenu<EntreeLigne>(
      context: context,
      position: RelativeRect.fromRect(
        bas & const Size(1, 1),
        Offset.zero & dessus.size,
      ),
      color: theme.colorScheme.surface,
      items: [
        for (final e in entrees)
          PopupMenuItem(
            key: ValueKey('menu-${e.cle}'),
            value: e,
            child: Semantics(
              label: e.libelle,
              selected: e.choisie,
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.icone != null) ...[
                    Icon(
                      e.icone,
                      size: 20,
                      color: e.choisie
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppEspacement.sm),
                  ],
                  MotManuscrit(mot: e.mot, hauteur: 26),
                  if (e.apercu case final apercu?) ...[
                    const SizedBox(width: AppEspacement.md),
                    // En petit, à l'encre discrète.
                    Flexible(
                      child: EcritureManuscrite(
                        latex: apercu,
                        couleur: theme.colorScheme.onSurfaceVariant,
                        hauteur: 20,
                        repli: Text(
                          apercu,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
    choix?.agir();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etat = switch (juge) {
      true => ', ${l10n.ligneJugeeJuste}',
      false => ', ${l10n.ligneJugeeFausse}',
      null => '',
    };
    final libelle =
        '${l10n.actionsLigne}$etat : ${entrees.map((e) => e.mot).join(', ')}';
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: libelle,
      excludeSemantics: true,
      child: Tooltip(
        message: libelle,
        child: InkWell(
          onTap: () => _ouvrir(context),
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 48,
            child: CustomPaint(
              painter: _PeintreActions(
                theme.colorScheme.tertiary,
                juge: juge,
                marque: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeintreActions extends CustomPainter {
  const new(this.couleur, {required this.juge, required this.marque});

  final Color couleur;
  final bool? juge;
  final Color marque;

  @override
  void paint(Canvas canvas, Size size) {
    final trait = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final c = size.center(Offset.zero);
    Offset p(double x, double y) => c + Offset(x, y);
    // La flèche, d'un geste un peu penché : elle descend, tourne, avance.
    final fleche = Path()
      ..moveTo(p(-10, -11).dx, p(-10, -11).dy)
      ..quadraticBezierTo(
        p(-11.5, -3).dx,
        p(-11.5, -3).dy,
        p(-10, 2).dx,
        p(-10, 2).dy,
      )
      ..quadraticBezierTo(p(-9, 6).dx, p(-9, 6).dy, p(-4, 6).dx, p(-4, 6).dy)
      ..lineTo(p(8, 5.5).dx, p(8, 5.5).dy)
      ..moveTo(p(3.5, 1).dx, p(3.5, 1).dy)
      ..lineTo(p(8, 5.5).dx, p(8, 5.5).dy)
      ..lineTo(p(3.5, 10).dx, p(3.5, 10).dy);
    canvas.drawPath(fleche, trait);
    // Trois points : plusieurs choix.
    final point = Paint()..color = couleur;
    for (final x in [-2.0, 3.5, 9.0]) {
      canvas.drawCircle(p(x, -8), 1.8, point);
    }
    // Jugée : une petite coche (juste) ou une croix (fausse), en bas à
    // droite, dans la couleur des choix ; la forme le dit aussi (règle 9).
    final etat = Paint()
      ..color = marque
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (juge) {
      case true:
        canvas.drawPath(
          Path()
            ..moveTo(p(9, 13).dx, p(9, 13).dy)
            ..lineTo(p(12.5, 16.5).dx, p(12.5, 16.5).dy)
            ..lineTo(p(19, 9).dx, p(19, 9).dy),
          etat,
        );
      case false:
        canvas
          ..drawLine(p(11, 10), p(18, 17), etat)
          ..drawLine(p(18, 10), p(11, 17), etat);
      case null:
        break;
    }
  }

  @override
  bool shouldRepaint(_PeintreActions ancien) =>
      ancien.couleur != couleur ||
      ancien.juge != juge ||
      ancien.marque != marque;
}
