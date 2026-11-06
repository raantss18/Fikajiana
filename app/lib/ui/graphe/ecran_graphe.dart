import 'dart:async';
import 'dart:math' as math;

import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/calcul/carte_bloc.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Le Graphe : les courbes en plein écran, glisser et pincer pour se déplacer.
class EcranGraphe extends StatefulWidget {
  const new({super.key});

  @override
  State<EcranGraphe> createState() => _EcranGrapheState();
}

class _EcranGrapheState extends State<EcranGraphe> {
  final _vue = VueGraphe();
  var _outilsOuverts = false;
  Offset _dernierFocal = Offset.zero;
  double _derniereEchelle = 1;
  Size _taille = Size.zero;
  ({int indice, double x, double y})? _point;

  Courbes get _courbes => PorteeServices.de(context).courbes;

  @override
  void dispose() {
    _vue.dispose();
    super.dispose();
  }

  List<FonctionReelle> _fonctions(bool degres) => [
    for (final c in _courbes.liste) c.fonction(degres: degres),
  ];

  Future<void> _ajouter() async {
    final l10n = context.l10n;
    setState(() => _outilsOuverts = false);
    final latex = await demanderLatex(
      context,
      '',
      titre: l10n.grapheAjouter,
      aide: l10n.grapheAide,
      action: l10n.grapheTracer,
    );
    if (latex == null || latex.trim().isEmpty || !mounted) return;
    if (!_courbes.ajouter(latex)) _signalerErreur();
  }

  Future<void> _modifier(int indice) async {
    final l10n = context.l10n;
    final courbes = _courbes;
    final latex = await demanderLatex(
      context,
      courbes.liste[indice].latex,
      titre: l10n.grapheModifier,
      aide: l10n.grapheAide,
      action: l10n.grapheTracer,
      surRetirer: () {
        setState(() => _point = null);
        courbes.retirer(indice);
      },
    );
    if (latex == null || latex.trim().isEmpty || !mounted) return;
    setState(() => _point = null);
    if (!courbes.remplacer(indice, latex)) _signalerErreur();
  }

  void _signalerErreur() {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.grapheErreur)));
  }

  @override
  Widget build(BuildContext context) {
    final reglages = PorteeReglages.de(context);
    final theme = Theme.of(context);
    final couleurs = theme.colorScheme;
    final l10n = context.l10n;
    final virgule = Localizations.localeOf(context).languageCode == 'fr';
    final stylos = reglages.support.stylos;
    return ListenableBuilder(
      listenable: Listenable.merge([_courbes, _vue]),
      builder: (context, _) {
        final courbes = _courbes.liste;
        final fonctions = _fonctions(reglages.degres);
        return Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, contraintes) {
                _taille = contraintes.biggest;
                return Semantics(
                  label: courbes.isEmpty
                      ? l10n.grapheVide
                      : l10n.grapheDescription(courbes.length),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (d) {
                      _dernierFocal = d.localFocalPoint;
                      _derniereEchelle = 1;
                    },
                    onScaleUpdate: (d) {
                      _vue.glisser(d.localFocalPoint - _dernierFocal);
                      if (d.scale != _derniereEchelle) {
                        _vue.zoomer(
                          d.scale / _derniereEchelle,
                          d.localFocalPoint,
                          _taille,
                        );
                      }
                      _dernierFocal = d.localFocalPoint;
                      _derniereEchelle = d.scale;
                    },
                    onTapUp: (d) => setState(() {
                      _point = courbeProche(
                        fonctions,
                        d.localPosition,
                        _vue,
                        _taille,
                      );
                    }),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: PeintreGraphe(
                        vue: _vue,
                        fonctions: fonctions,
                        stylos: stylos,
                        fond: reglages.support.fond,
                        axes: couleurs.onSurface,
                        grille: couleurs.outlineVariant,
                        texte: theme.textTheme.bodySmall!.copyWith(
                          color: couleurs.onSurface,
                        ),
                        virgule: virgule,
                        point: _point,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (courbes.isEmpty)
              IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppEspacement.lg),
                    child: Text(
                      l10n.grapheVide,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            // La légende, à droite de ← et de Menu : numéro et formule, jamais
            // la couleur seule.
            Positioned(
              left: 120,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppEspacement.sm),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < courbes.length; i++)
                          _Legende(
                            numero: i + 1,
                            latex: courbes[i].latex,
                            couleur: stylos[i % stylos.length],
                            surToucher: () => unawaited(_modifier(i)),
                          ),
                      ],
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
                    surBasculer: () =>
                        setState(() => _outilsOuverts = !_outilsOuverts),
                    surAjouter: () => unawaited(_ajouter()),
                    vue: _vue,
                    taille: _taille,
                    reglages: reglages,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Legende extends StatelessWidget {
  const new({
    required this.numero,
    required this.latex,
    required this.couleur,
    required this.surToucher,
  });

  final int numero;
  final String latex;
  final Color couleur;
  final VoidCallback surToucher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppEspacement.sm),
      child: Material(
        elevation: 1,
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: surToucher,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppEspacement.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$numero',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: couleur,
                    ),
                  ),
                  const SizedBox(width: AppEspacement.sm),
                  Math.tex(
                    latex,
                    textStyle: theme.textTheme.bodyMedium,
                    onErrorFallback: (_) => Text(latex),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Outils extends StatelessWidget {
  const new({
    required this.ouverts,
    required this.surBasculer,
    required this.surAjouter,
    required this.vue,
    required this.taille,
    required this.reglages,
  });

  final bool ouverts;
  final VoidCallback surBasculer;
  final VoidCallback surAjouter;
  final VueGraphe vue;
  final Size taille;
  final Reglages reglages;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final centre = Offset(taille.width / 2, taille.height / 2);
    final bouton = FloatingActionButton.small(
      heroTag: null,
      tooltip: l10n.outils,
      elevation: 2,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      onPressed: surBasculer,
      child: Icon(ouverts ? Icons.close : Icons.tune),
    );
    if (!ouverts) return bouton;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppEspacement.sm),
            child: Wrap(
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: l10n.grapheAjouter,
                  onPressed: surAjouter,
                ),
                // Sans geste à deux doigts (WCAG 2.2, critère 2.5.7).
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
                Tooltip(
                  message: reglages.degres ? l10n.modeDegres : l10n.modeRadians,
                  child: TextButton(
                    onPressed: () => reglages.degres = !reglages.degres,
                    child: Text(reglages.degres ? 'DEG' : 'RAD'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppEspacement.sm),
        bouton,
      ],
    );
  }
}

/// Grille, axes, graduations, courbes numérotées et point lu.
class PeintreGraphe extends CustomPainter {
  const new({
    required this.vue,
    required this.fonctions,
    required this.stylos,
    required this.fond,
    required this.axes,
    required this.grille,
    required this.texte,
    required this.virgule,
    this.point,
  });

  final VueGraphe vue;
  final List<FonctionReelle> fonctions;
  final List<Color> stylos;
  final Color fond;
  final Color axes;
  final Color grille;
  final TextStyle texte;
  final bool virgule;
  final ({int indice, double x, double y})? point;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = fond)
      ..clipRect(Offset.zero & size);
    _grille(canvas, size);
    for (var i = 0; i < fonctions.length; i++) {
      _courbe(canvas, size, i);
    }
    final point = this.point;
    if (point != null) _pointLu(canvas, size, point);
  }

  void _grille(Canvas canvas, Size size) {
    final fenetre = vue.fenetre(size);
    final pas = pasDeGraduation(vue.unite);
    final ligne = Paint()
      ..color = grille
      ..strokeWidth = 1;
    final origine = vue.versEcran(0, 0, size);
    // Hors de l'écran, les nombres restent lisibles le long du bord.
    final xAxe = origine.dx.clamp(4.0, size.width - 44);
    final yAxe = origine.dy.clamp(4.0, size.height - 20);

    final premierX = (fenetre.xMin / pas).ceil();
    for (var k = premierX; k * pas <= fenetre.xMax; k++) {
      final x = vue.versEcran(k * pas, 0, size).dx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), ligne);
      if (k != 0) {
        _ecrire(
          canvas,
          texteGraduation(k * pas, pas, virgule: virgule),
          Offset(x + 3, yAxe + 2),
        );
      }
    }
    final premierY = (fenetre.yMin / pas).ceil();
    for (var k = premierY; k * pas <= fenetre.yMax; k++) {
      final y = vue.versEcran(0, k * pas, size).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ligne);
      if (k != 0) {
        _ecrire(
          canvas,
          texteGraduation(k * pas, pas, virgule: virgule),
          Offset(xAxe + 3, y + 2),
        );
      }
    }
    final axe = Paint()
      ..color = axes
      ..strokeWidth = 1.5;
    canvas
      ..drawLine(Offset(origine.dx, 0), Offset(origine.dx, size.height), axe)
      ..drawLine(Offset(0, origine.dy), Offset(size.width, origine.dy), axe);
  }

  void _courbe(Canvas canvas, Size size, int indice) {
    final couleur = stylos[indice % stylos.length];
    final trait = Paint()
      ..color = couleur
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final morceaux = tracerFonction(fonctions[indice], vue.fenetre(size));
    Offset? repere;
    for (final morceau in morceaux) {
      final chemin = Path();
      for (var i = 0; i < morceau.length; i++) {
        // Skia gère mal les coordonnées immenses des asymptotes.
        final p = vue.versEcran(morceau[i].x, morceau[i].y, size);
        final q = Offset(p.dx, p.dy.clamp(-4000.0, size.height + 4000));
        if (i == 0) {
          chemin.moveTo(q.dx, q.dy);
        } else {
          chemin.lineTo(q.dx, q.dy);
        }
        final dansLaVue = q.dy >= 72 && q.dy <= size.height - 72;
        final etale = q.dx <= size.width - 40 - indice * 24;
        if (dansLaVue && etale) repere = q;
      }
      canvas.drawPath(chemin, trait);
    }
    // Chaque courbe porte son numéro, celui de la légende.
    final position = repere;
    if (position != null) {
      _ecrire(
        canvas,
        '${indice + 1}',
        position + const Offset(4, -22),
        style: texte.copyWith(color: couleur, fontWeight: FontWeight.bold),
      );
    }
  }

  void _pointLu(
    Canvas canvas,
    Size size,
    ({int indice, double x, double y}) point,
  ) {
    final p = vue.versEcran(point.x, point.y, size);
    canvas
      ..drawCircle(p, 6, Paint()..color = fond)
      ..drawCircle(p, 5, Paint()..color = stylos[point.indice % stylos.length]);
    final x = texteValeur(point.x, virgule: virgule);
    final y = texteValeur(point.y, virgule: virgule);
    final position = Offset(
      math.min(p.dx + 10, size.width - 140),
      math.max(p.dy - 28, 4),
    );
    _ecrire(canvas, '($x ; $y)', position, surFond: true);
  }

  void _ecrire(
    Canvas canvas,
    String contenu,
    Offset position, {
    TextStyle? style,
    bool surFond = false,
  }) {
    final peintre = TextPainter(
      text: TextSpan(text: contenu, style: style ?? texte),
      textDirection: TextDirection.ltr,
    )..layout();
    if (surFond) {
      canvas.drawRect(
        (position & peintre.size).inflate(3),
        Paint()..color = fond,
      );
    }
    peintre
      ..paint(canvas, position)
      ..dispose();
  }

  @override
  bool shouldRepaint(PeintreGraphe ancien) => true;
}
