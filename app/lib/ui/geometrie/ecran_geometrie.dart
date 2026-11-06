import 'dart:math' as math;

import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';

/// Tolérance d'un toucher : la taille d'une cible, 48 dp.
const double _rayonToucher = 24;

IconData _icone(OutilGeo outil) => switch (outil) {
  OutilGeo.deplacer => Icons.open_with,
  OutilGeo.point => Icons.fiber_manual_record,
  OutilGeo.segment => Icons.horizontal_rule,
  OutilGeo.droite => Icons.linear_scale,
  OutilGeo.cercle => Icons.circle_outlined,
  OutilGeo.milieu => Icons.adjust,
  OutilGeo.mediatrice => Icons.vertical_align_center,
  OutilGeo.bissectrice => Icons.call_split,
  OutilGeo.parallele => Icons.drag_handle,
  OutilGeo.perpendiculaire => Icons.add,
  OutilGeo.intersection => Icons.close,
  OutilGeo.gomme => Icons.cleaning_services_outlined,
};

extension on OutilGeo {
  String libelle(AppLocalizations l10n) => switch (this) {
    OutilGeo.deplacer => l10n.outilDeplacer,
    OutilGeo.point => l10n.outilPoint,
    OutilGeo.segment => l10n.outilSegment,
    OutilGeo.droite => l10n.outilDroite,
    OutilGeo.cercle => l10n.outilCercle,
    OutilGeo.milieu => l10n.outilMilieu,
    OutilGeo.mediatrice => l10n.outilMediatrice,
    OutilGeo.bissectrice => l10n.outilBissectrice,
    OutilGeo.parallele => l10n.outilParallele,
    OutilGeo.perpendiculaire => l10n.outilPerpendiculaire,
    OutilGeo.intersection => l10n.outilIntersection,
    OutilGeo.gomme => l10n.outilGomme,
  };

  String aide(AppLocalizations l10n) => switch (this) {
    OutilGeo.deplacer => l10n.aideDeplacer,
    OutilGeo.point => l10n.aidePoint,
    OutilGeo.segment ||
    OutilGeo.droite ||
    OutilGeo.milieu ||
    OutilGeo.mediatrice => l10n.aideDeuxPoints,
    OutilGeo.cercle => l10n.aideCercle,
    OutilGeo.bissectrice => l10n.aideBissectrice,
    OutilGeo.parallele || OutilGeo.perpendiculaire => l10n.aideParDroite,
    OutilGeo.intersection => l10n.aideIntersection,
    OutilGeo.gomme => l10n.aideGomme,
  };
}

/// La Géométrie : une figure qui se déforme quand on déplace ses points.
class EcranGeometrie extends StatefulWidget {
  const new({super.key});

  @override
  State<EcranGeometrie> createState() => _EcranGeometrieState();
}

class _EcranGeometrieState extends State<EcranGeometrie> {
  final _vue = VueGraphe();
  var _outilsOuverts = false;
  Size _taille = Size.zero;
  Offset _dernierFocal = Offset.zero;
  double _derniereEchelle = 1;
  int? _attrape;

  Atelier get _atelier => PorteeServices.de(context).atelier;

  double get _tolerance => _rayonToucher / _vue.unite;

  @override
  void dispose() {
    _vue.dispose();
    super.dispose();
  }

  void _surDebut(ScaleStartDetails d) {
    _dernierFocal = d.localFocalPoint;
    _derniereEchelle = 1;
    final m = _vue.versMaths(d.localFocalPoint, _taille);
    _attrape = d.pointerCount == 1
        ? _atelier.pointLibreProche(m.x, m.y, _tolerance)
        : null;
  }

  void _surGeste(ScaleUpdateDetails d) {
    final attrape = _attrape;
    if (attrape != null && d.pointerCount == 1) {
      final m = _vue.versMaths(d.localFocalPoint, _taille);
      _atelier.deplacer(attrape, m.x, m.y);
      return;
    }
    _vue.glisser(d.localFocalPoint - _dernierFocal);
    if (d.scale != _derniereEchelle) {
      _vue.zoomer(d.scale / _derniereEchelle, d.localFocalPoint, _taille);
    }
    _dernierFocal = d.localFocalPoint;
    _derniereEchelle = d.scale;
  }

  @override
  Widget build(BuildContext context) {
    final reglages = PorteeReglages.de(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final atelier = _atelier;
    return ListenableBuilder(
      listenable: Listenable.merge([atelier, _vue]),
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, contraintes) {
              _taille = contraintes.biggest;
              return Semantics(
                label: atelier.estVide
                    ? l10n.geometrieVide
                    : l10n.geometrieDescription(atelier.figure.objets.length),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _surDebut,
                  onScaleUpdate: _surGeste,
                  onScaleEnd: (_) => _attrape = null,
                  onTapUp: (d) {
                    final m = _vue.versMaths(d.localPosition, _taille);
                    atelier.toucher(m.x, m.y, _tolerance);
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: PeintreFigure(
                      atelier: atelier,
                      vue: _vue,
                      fond: reglages.support.fond,
                      grille: theme.colorScheme.outlineVariant,
                      trait: reglages.support.stylos[0],
                      libre: reglages.support.stylos[2],
                      choix: theme.colorScheme.tertiary,
                      texte: theme.textTheme.titleSmall!.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (atelier.estVide && atelier.outil == OutilGeo.deplacer)
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacement.lg),
                  child: Text(
                    l10n.geometrieVide,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          // L'aide de l'outil choisi, à droite de ← et de Menu.
          if (!atelier.estVide || atelier.outil != OutilGeo.deplacer)
            Positioned(
              left: 128,
              right: AppEspacement.sm,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppEspacement.md),
                    child: Text(
                      atelier.outil.aide(l10n),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppEspacement.sm),
                child: _Outils(
                  ouverts: _outilsOuverts,
                  atelier: atelier,
                  vue: _vue,
                  taille: _taille,
                  surBasculer: () =>
                      setState(() => _outilsOuverts = !_outilsOuverts),
                  surOutil: (outil) {
                    atelier.outil = outil;
                    setState(() => _outilsOuverts = false);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Outils extends StatelessWidget {
  const new({
    required this.ouverts,
    required this.atelier,
    required this.vue,
    required this.taille,
    required this.surBasculer,
    required this.surOutil,
  });

  final bool ouverts;
  final Atelier atelier;
  final VueGraphe vue;
  final Size taille;
  final VoidCallback surBasculer;
  final ValueChanged<OutilGeo> surOutil;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final couleurs = Theme.of(context).colorScheme;
    final centre = Offset(taille.width / 2, taille.height / 2);
    final bouton = FloatingActionButton.small(
      heroTag: null,
      tooltip: l10n.outils,
      elevation: 2,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      backgroundColor: couleurs.surfaceContainerHigh,
      foregroundColor: couleurs.onSurface,
      onPressed: surBasculer,
      child: Icon(ouverts ? Icons.close : _icone(atelier.outil)),
    );
    if (!ouverts) return bouton;
    final media = MediaQuery.sizeOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: media.height < media.width ? 340 : 224,
              maxHeight: media.height * 0.6,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppEspacement.sm),
              child: Wrap(
                children: [
                  for (final outil in OutilGeo.values)
                    IconButton(
                      icon: Icon(_icone(outil)),
                      isSelected: atelier.outil == outil,
                      tooltip: outil.libelle(l10n),
                      onPressed: () => surOutil(outil),
                    ),
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: l10n.annuler,
                    onPressed: atelier.estVide ? null : atelier.annuler,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.effacerTout,
                    onPressed: atelier.estVide ? null : atelier.effacer,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    tooltip: l10n.zoomPlus,
                    onPressed: () => vue.zoomer(1.5, centre, taille),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out),
                    tooltip: l10n.zoomMoins,
                    onPressed: () => vue.zoomer(1 / 1.5, centre, taille),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fit_screen_outlined),
                    tooltip: l10n.recentrer,
                    onPressed: vue.estInitiale ? null : vue.recentrer,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppEspacement.sm),
        bouton,
      ],
    );
  }
}

/// La grille légère, les lignes et cercles, puis les points et leurs noms.
class PeintreFigure extends CustomPainter {
  const new({
    required this.atelier,
    required this.vue,
    required this.fond,
    required this.grille,
    required this.trait,
    required this.libre,
    required this.choix,
    required this.texte,
  });

  final Atelier atelier;
  final VueGraphe vue;
  final Color fond;
  final Color grille;
  final Color trait;
  final Color libre;
  final Color choix;
  final TextStyle texte;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = fond)
      ..clipRect(Offset.zero & size);
    _grille(canvas, size);
    final choisis = atelier.choisis;
    atelier.formes.forEach((id, forme) {
      final peinture = Paint()
        ..color = choisis.contains(id) ? choix : trait
        ..strokeWidth = choisis.contains(id) ? 3.5 : 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      switch (forme) {
        case final DroiteGeo d:
          _droite(canvas, size, d, peinture);
        case final CercleGeo c:
          canvas.drawCircle(
            vue.versEcran(c.centre.x, c.centre.y, size),
            c.rayon * vue.unite,
            peinture,
          );
        case PointGeo() || null:
          break;
      }
    });
    atelier.formes.forEach((id, forme) {
      if (forme is! PointGeo) return;
      final p = vue.versEcran(forme.x, forme.y, size);
      final estLibre = atelier.figure.definition(id) is PointLibre;
      if (choisis.contains(id)) {
        canvas.drawCircle(p, 11, Paint()..color = choix);
      }
      canvas
        ..drawCircle(p, estLibre ? 7 : 5, Paint()..color = fond)
        ..drawCircle(
          p,
          estLibre ? 6 : 4,
          Paint()..color = estLibre ? libre : trait,
        );
      TextPainter(
          text: TextSpan(text: atelier.nomDuPoint(id), style: texte),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, p + const Offset(9, -24))
        ..dispose();
    });
  }

  void _grille(Canvas canvas, Size size) {
    final fenetre = vue.fenetre(size);
    final pas = pasDeGraduation(vue.unite);
    final ligne = Paint()
      ..color = grille.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var k = (fenetre.xMin / pas).ceil(); k * pas <= fenetre.xMax; k++) {
      final x = vue.versEcran(k * pas, 0, size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), ligne);
    }
    for (var k = (fenetre.yMin / pas).ceil(); k * pas <= fenetre.yMax; k++) {
      final y = vue.versEcran(0, k * pas, size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ligne);
    }
  }

  void _droite(Canvas canvas, Size size, DroiteGeo d, Paint peinture) {
    final (debut, fin) = (d.debut, d.fin);
    if (debut != null && fin != null) {
      canvas.drawLine(
        vue.versEcran(debut.x, debut.y, size),
        vue.versEcran(fin.x, fin.y, size),
        peinture,
      );
      return;
    }
    // Une droite déborde de l'écran : deux points assez loin du centre.
    final centre = vue.versMaths(size.center(Offset.zero), size);
    final ecart = d.c - d.a * centre.x - d.b * centre.y;
    final (px, py) = (centre.x + d.a * ecart, centre.y + d.b * ecart);
    final portee =
        2 * math.max(size.width, size.height) / vue.unite + ecart.abs();
    canvas.drawLine(
      vue.versEcran(px + d.b * portee, py - d.a * portee, size),
      vue.versEcran(px - d.b * portee, py + d.a * portee, size),
      peinture,
    );
  }

  @override
  bool shouldRepaint(PeintreFigure ancien) => true;
}
