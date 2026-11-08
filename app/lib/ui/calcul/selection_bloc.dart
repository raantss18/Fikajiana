import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Pas d'une flèche de la barre, en points d'écran.
const double pasSelection = 24;

/// Par-dessus la Feuille pendant qu'on choisit une ligne : toucher choisit,
/// entourer choisit aussi (demande d'Antsa), glisser la ligne choisie la
/// déplace ; à deux doigts, la page défile et se zoome.
///
/// [zone] : ce qu'occupe la ligne choisie sur la page, ou `null`.
class CoucheSelection extends StatefulWidget {
  const new({
    required this.vue,
    required this.zone,
    required this.surToucher,
    required this.surEntourer,
    required this.surDeplacer,
    super.key,
  });

  final VueFeuille vue;
  final Rect? zone;

  /// Un toucher, en coordonnées de la page.
  final ValueChanged<Offset> surToucher;

  /// Un lasso fermé, en coordonnées de la page.
  final ValueChanged<List<Offset>> surEntourer;

  /// La ligne choisie glisse de ce décalage (page) ; `debut` au premier pas.
  final void Function(Offset delta, {required bool debut}) surDeplacer;

  @override
  State<CoucheSelection> createState() => _CoucheSelectionState();
}

enum _Geste { porte, entoure, vue }

class _CoucheSelectionState extends State<CoucheSelection> {
  _Geste? _geste;
  var _debut = true;
  var _echelle = 1.0;

  /// Le dernier point suivi : le premier pas compte depuis le doigt posé,
  /// seuil de glisser compris.
  Offset _dernier = Offset.zero;

  /// Où le dernier doigt s'est posé.
  Offset _pose = Offset.zero;

  /// Le lasso en cours, en coordonnées de l'écran.
  var _lasso = <Offset>[];

  void _commencer(ScaleStartDetails d) {
    final vue = widget.vue;
    _echelle = 1;
    _debut = true;
    _dernier = d.pointerCount > 1 ? d.localFocalPoint : _pose;
    if (d.pointerCount > 1) {
      _geste = _Geste.vue;
      return;
    }
    final z = widget.zone;
    if (z != null && z.inflate(12).contains(vue.versPage(_pose))) {
      _geste = _Geste.porte;
      return;
    }
    _geste = _Geste.entoure;
    setState(() => _lasso = [_pose, d.localFocalPoint]);
  }

  void _suivre(ScaleUpdateDetails d) {
    final vue = widget.vue;
    final delta = d.localFocalPoint - _dernier;
    _dernier = d.localFocalPoint;
    // Un second doigt arrive : la page bouge, le lasso s'oublie.
    if (d.pointerCount > 1 && _geste != _Geste.vue) {
      _geste = _Geste.vue;
      setState(() => _lasso = []);
    }
    switch (_geste) {
      case _Geste.vue:
        vue.glisser(delta);
        if (d.scale > 0 && d.scale != _echelle) {
          vue.zoomer(d.scale / _echelle, d.localFocalPoint);
          _echelle = d.scale;
        }
      case _Geste.porte:
        widget.surDeplacer(delta / vue.zoom, debut: _debut);
        _debut = false;
      case _Geste.entoure:
        setState(() => _lasso = [..._lasso, d.localFocalPoint]);
      case null:
        break;
    }
  }

  void _finir(ScaleEndDetails d) {
    if (_geste == _Geste.entoure && _lasso.length >= 3) {
      widget.surEntourer([for (final p in _lasso) widget.vue.versPage(p)]);
    }
    _geste = null;
    if (_lasso.isNotEmpty) setState(() => _lasso = []);
  }

  @override
  Widget build(BuildContext context) {
    final vue = widget.vue;
    final couleurs = Theme.of(context).colorScheme;
    final zone = widget.zone;
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: (e) => _pose = e.localPosition,
          behavior: HitTestBehavior.opaque,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // La ligne suit le doigt depuis où il s'est posé, seuil compris.
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (d) => widget.surToucher(vue.versPage(d.localPosition)),
            onScaleStart: _commencer,
            onScaleUpdate: _suivre,
            onScaleEnd: _finir,
          ),
        ),
        if (_lasso.length > 1)
          IgnorePointer(
            child: CustomPaint(
              painter: _PeintreLasso(_lasso, couleurs.primary),
            ),
          ),
        if (zone != null)
          ListenableBuilder(
            listenable: vue,
            builder: (context, _) {
              final cadre = Rect.fromPoints(
                zone.inflate(6).topLeft * vue.zoom + vue.decalage,
                zone.inflate(6).bottomRight * vue.zoom + vue.decalage,
              );
              return Positioned.fromRect(
                rect: cadre,
                child: IgnorePointer(
                  child: Semantics(
                    label: context.l10n.selectionLigne,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: couleurs.primary.withValues(alpha: 0.08),
                        border: Border.all(color: couleurs.primary, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Ce qu'on fait de la ligne choisie, en toutes lettres ; les flèches sont
/// l'alternative au glisser (WCAG 2.2, critère 2.5.7).
class BarreSelection extends StatelessWidget {
  const new({
    required this.choisie,
    required this.surDeplacer,
    required this.surDupliquer,
    required this.surSupprimer,
    required this.surCopierLatex,
    required this.surTerminer,
    super.key,
  });

  /// Une ligne est choisie : sans elle, la barre dit seulement quoi faire.
  final bool choisie;
  final ValueChanged<Offset> surDeplacer;
  final VoidCallback? surDupliquer;
  final VoidCallback surSupprimer;
  final VoidCallback? surCopierLatex;
  final VoidCallback surTerminer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget fleche(IconData icone, String nom, Offset sens) => IconButton(
      tooltip: nom,
      icon: Icon(icone),
      onPressed: () => surDeplacer(sens * pasSelection),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppEspacement.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sur un écran bas (téléphone en paysage), le cadre suffit : la
            // phrase reste pour TalkBack.
            if (choisie && MediaQuery.sizeOf(context).height < 520)
              Semantics(
                liveRegion: true,
                label: l10n.selectionChoisie,
                child: const SizedBox.shrink(),
              )
            else
              Semantics(
                liveRegion: true,
                child: Text(
                  choisie ? l10n.selectionChoisie : l10n.selectionAide,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: AppEspacement.xxs),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (choisie) ...[
                  fleche(
                    Icons.arrow_back,
                    l10n.selectionGauche,
                    const Offset(-1, 0),
                  ),
                  fleche(
                    Icons.arrow_upward,
                    l10n.selectionMonter,
                    const Offset(0, -1),
                  ),
                  fleche(
                    Icons.arrow_downward,
                    l10n.selectionDescendre,
                    const Offset(0, 1),
                  ),
                  fleche(
                    Icons.arrow_forward,
                    l10n.selectionDroite,
                    const Offset(1, 0),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.copy_all_outlined),
                    label: Text(l10n.selectionDupliquer),
                    onPressed: surDupliquer,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.selectionSupprimer),
                    onPressed: surSupprimer,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.content_paste_go_outlined),
                    label: Text(l10n.selectionCopierLatex),
                    onPressed: surCopierLatex,
                  ),
                ],
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.check),
                  label: Text(l10n.selectionTerminer),
                  onPressed: surTerminer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Le lasso tracé autour d'une ligne, fermé en pointillé vers son départ.
class _PeintreLasso extends CustomPainter {
  const new(this.points, this.couleur);

  final List<Offset> points;
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final trait = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(Path()..addPolygon(points, false), trait)
      ..drawLine(
        points.last,
        points.first,
        trait..color = couleur.withValues(alpha: 0.4),
      );
  }

  @override
  bool shouldRepaint(_PeintreLasso ancien) => true;
}
