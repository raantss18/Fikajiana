import 'dart:math' as math;

import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/calcul/action_manuscrite.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';

/// La feuille lit : une lueur passe sous ce qui est écrit, comme un surligneur.
/// Elle remplace le cercle de chargement (ADR 0023). Sans animation, la lueur
/// reste simplement posée.
class LueurLecture extends StatefulWidget {
  const new({required this.couleur, super.key});

  final Color couleur;

  @override
  State<LueurLecture> createState() => _LueurLectureState();
}

class _LueurLectureState extends State<LueurLecture>
    with SingleTickerProviderStateMixin {
  late final AnimationController _passage = AnimationController(
    vsync: this,
    duration: Durations.extralong4,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _passage.stop();
    } else if (!_passage.isAnimating) {
      _passage.repeat();
    }
  }

  @override
  void dispose() {
    _passage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fixe = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PeintreLueur(
            couleur: widget.couleur,
            passage: fixe ? null : _passage,
          ),
        ),
      ),
    );
  }
}

class _PeintreLueur extends CustomPainter {
  new({required this.couleur, required this.passage}) : super(repaint: passage);

  final Color couleur;
  final Animation<double>? passage;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppEspacement.sm),
    );
    final paint = Paint();
    final t = passage?.value;
    if (t == null) {
      paint.color = couleur.withValues(alpha: 0.12);
    } else {
      // La lueur entre par la gauche et sort par la droite.
      final centre = Easing.standard.transform(t) * 1.6 - 0.3;
      paint.shader = LinearGradient(
        colors: [
          couleur.withValues(alpha: 0),
          couleur.withValues(alpha: 0.24),
          couleur.withValues(alpha: 0),
        ],
        stops: [
          (centre - 0.3).clamp(0.0, 1.0),
          centre.clamp(0.0, 1.0),
          (centre + 0.3).clamp(0.0, 1.0),
        ],
      ).createShader(Offset.zero & size);
    }
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(_PeintreLueur ancien) =>
      ancien.couleur != couleur || ancien.passage != passage;

  @override
  bool? hitTest(Offset position) => false;
}

/// Un trait ondulé sous ce qui reste à vérifier, comme le crayon d'un
/// professeur. Il s'écrit une fois, de gauche à droite (ADR 0023).
class VagueAVerifier extends StatelessWidget {
  const new({required this.couleur, super.key});

  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final fixe = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: fixe ? 1 : 0, end: 1),
      duration: Durations.long1,
      curve: Easing.emphasizedDecelerate,
      builder: (context, avancee, _) => CustomPaint(
        size: Size.infinite,
        painter: _PeintreVague(couleur: couleur, avancee: avancee),
      ),
    );
  }
}

class _PeintreVague extends CustomPainter {
  const new({required this.couleur, required this.avancee});

  final Color couleur;
  final double avancee;

  @override
  void paint(Canvas canvas, Size size) {
    final milieu = size.height / 2;
    final chemin = Path()..moveTo(0, milieu);
    for (var x = 2.0; x <= size.width; x += 2) {
      // Deux ondes mêlées : régulière, elle ferait mécanique.
      final y =
          2.6 * math.sin(x * 2 * math.pi / 15) +
          0.9 * math.sin(x * 2 * math.pi / 37);
      chemin.lineTo(x, milieu + y);
    }
    final trace = Path();
    for (final partie in chemin.computeMetrics()) {
      trace.addPath(
        partie.extractPath(0, partie.length * avancee),
        Offset.zero,
      );
    }
    canvas.drawPath(
      trace,
      Paint()
        ..color = couleur
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(_PeintreVague ancien) =>
      ancien.avancee != avancee || ancien.couleur != couleur;

  // Le stylet doit pouvoir écrire ici : seul le toucher ouvre le panneau.
  @override
  bool? hitTest(Offset position) => false;
}

/// Ce que la personne choisit dans le panneau d'une écriture à vérifier.
enum ChoixBloc { corriger, effacer, relire }

/// Sous l'écriture : ce qui a été lu, et quoi en faire (ADR 0023).
Future<ChoixBloc?> ouvrirPanneauBloc(
  BuildContext context, {
  required Offset ancre,
  required String message,
  required Widget? lecture,
  required String effacer,
  required String motEffacer,
  List<Widget> autres = const [],
}) {
  final fixe = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<ChoixBloc>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: fixe ? Duration.zero : Durations.medium2,
    pageBuilder: (context, _, _) => _PanneauBloc(
      ancre: ancre,
      message: message,
      lecture: lecture,
      effacer: effacer,
      motEffacer: motEffacer,
      autres: autres,
    ),
    transitionBuilder: (context, animation, _, child) {
      final courbe = CurvedAnimation(
        parent: animation,
        curve: Easing.emphasizedDecelerate,
        reverseCurve: Easing.emphasizedAccelerate,
      );
      return FadeTransition(
        opacity: courbe,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.02),
            end: Offset.zero,
          ).animate(courbe),
          child: child,
        ),
      );
    },
  );
}

class _PanneauBloc extends StatelessWidget {
  const new({
    required this.ancre,
    required this.message,
    required this.lecture,
    required this.effacer,
    required this.motEffacer,
    this.autres = const [],
  });

  /// D'autres lectures possibles, à toucher.
  final List<Widget> autres;
  final Offset ancre;
  final String message;
  final Widget? lecture;
  final String effacer;

  /// [effacer], tel qu'il s'écrit à la main (sans accent).
  final String motEffacer;

  static const _largeur = 420.0;

  /// Assez pour le panneau : plus bas, il s'ouvre au-dessus de l'écriture.
  static const _hauteur = 220.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ecran = MediaQuery.sizeOf(context);
    final largeur = math.min(_largeur, ecran.width - 2 * AppEspacement.md);
    final gauche = math.max(
      AppEspacement.md,
      math.min(ancre.dx, ecran.width - largeur - AppEspacement.md),
    );
    final auDessus = ancre.dy + _hauteur > ecran.height;
    return Stack(
      children: [
        Positioned(
          left: gauche,
          top: auDessus ? null : ancre.dy,
          bottom: auDessus ? ecran.height - ancre.dy + 48 : null,
          width: largeur,
          // Un petit papier posé sur la Feuille : sa couleur, et ses actions
          // écrites à la main comme les résultats (Antsa, cap n° 8).
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppEspacement.md),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppEspacement.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // À la main aussi, accents compris ; réduit s'il est long
                  // (téléphone). TalkBack lit la phrase.
                  Semantics(
                    label: message,
                    excludeSemantics: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: EcritureManuscrite(
                        // Le compositeur saute les espaces : `\,` les garde.
                        latex: '\\text{${message.replaceAll(' ', r'\,\,\,')}}',
                        couleur: theme.colorScheme.onSurface,
                        hauteur: 26,
                        repli: Text(message, style: theme.textTheme.titleSmall),
                      ),
                    ),
                  ),
                  if (lecture != null) ...[
                    const SizedBox(height: AppEspacement.sm),
                    lecture!,
                  ],
                  if (autres.isNotEmpty) ...[
                    const SizedBox(height: AppEspacement.sm),
                    Text(
                      l10n.blocAutresLectures,
                      style: theme.textTheme.bodySmall,
                    ),
                    Wrap(spacing: AppEspacement.sm, children: autres),
                  ],
                  const SizedBox(height: AppEspacement.sm),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppEspacement.sm,
                    children: [
                      ActionManuscrite(
                        mot: l10n.motRelire,
                        libelle: l10n.blocRelire,
                        surToucher: () =>
                            Navigator.of(context).pop(ChoixBloc.relire),
                      ),
                      ActionManuscrite(
                        mot: motEffacer,
                        libelle: effacer,
                        surToucher: () =>
                            Navigator.of(context).pop(ChoixBloc.effacer),
                      ),
                      ActionManuscrite(
                        mot: l10n.motCorriger,
                        libelle: l10n.corriger,
                        surToucher: () =>
                            Navigator.of(context).pop(ChoixBloc.corriger),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
