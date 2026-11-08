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

/// Un seul petit bouton à côté d'une ligne comprise : il ouvre la liste de ce
/// qu'on peut en faire (résoudre, dériver…), au lieu d'une rangée de mots
/// qui passait sur les lignes voisines (téléphone d'Antsa, 2026-11-08).
///
/// Le dessin, tracé à la main : une flèche qui descend puis part à droite
/// (« écrire la suite dessous ») et trois points (« au choix »). TalkBack
/// lit son nom et les actions. Cible de 48 dp (règle 9).
class BoutonActions extends StatelessWidget {
  const new({required this.propositions, required this.surChoisir, super.key});

  final List<Proposition> propositions;

  /// L'action choisie : sa ligne se pose dessous.
  final ValueChanged<Proposition> surChoisir;

  Future<void> _ouvrir(BuildContext context) async {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final boite = context.findRenderObject()! as RenderBox;
    final dessus =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    // Le menu s'ouvre sous le bouton : la ligne reste visible.
    final bas = boite.localToGlobal(
      boite.size.bottomLeft(Offset.zero),
      ancestor: dessus,
    );
    final choix = await showMenu<Proposition>(
      context: context,
      position: RelativeRect.fromRect(
        bas & const Size(1, 1),
        Offset.zero & dessus.size,
      ),
      color: theme.colorScheme.surface,
      items: [
        for (final p in propositions)
          PopupMenuItem(
            key: ValueKey('menu-${p.genre.name}'),
            value: p,
            child: Semantics(
              label: libelleProposition(l10n, p.genre),
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MotManuscrit(mot: motProposition(l10n, p.genre), hauteur: 26),
                  const SizedBox(width: AppEspacement.md),
                  // La ligne qui sera posée, en petit, à l'encre discrète.
                  Flexible(
                    child: EcritureManuscrite(
                      latex: p.latex,
                      couleur: theme.colorScheme.onSurfaceVariant,
                      hauteur: 20,
                      repli: const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (choix != null) surChoisir(choix);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mots = [for (final p in propositions) motProposition(l10n, p.genre)];
    final libelle = '${l10n.actionsLigne} : ${mots.join(', ')}';
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
              painter: _PeintreActions(Theme.of(context).colorScheme.tertiary),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeintreActions extends CustomPainter {
  const new(this.couleur);

  final Color couleur;

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
  }

  @override
  bool shouldRepaint(_PeintreActions ancien) => ancien.couleur != couleur;
}
