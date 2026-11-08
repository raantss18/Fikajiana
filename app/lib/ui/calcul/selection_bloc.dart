import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Pas d'une flèche de la barre, en points d'écran.
const double pasSelection = 24;

/// Par-dessus la Feuille pendant qu'on choisit une ligne : toucher choisit,
/// glisser la ligne choisie la déplace, glisser ailleurs fait défiler.
///
/// [zone] : ce qu'occupe la ligne choisie sur la page, ou `null`.
class CoucheSelection extends StatefulWidget {
  const new({
    required this.vue,
    required this.zone,
    required this.surToucher,
    required this.surDeplacer,
    super.key,
  });

  final VueFeuille vue;
  final Rect? zone;

  /// Un toucher, en coordonnées de la page.
  final ValueChanged<Offset> surToucher;

  /// La ligne choisie glisse de ce décalage (page) ; `debut` au premier pas.
  final void Function(Offset delta, {required bool debut}) surDeplacer;

  @override
  State<CoucheSelection> createState() => _CoucheSelectionState();
}

class _CoucheSelectionState extends State<CoucheSelection> {
  /// Le glisser en cours porte la ligne choisie (sinon, la page).
  var _porte = false;
  var _debut = true;

  @override
  Widget build(BuildContext context) {
    final vue = widget.vue;
    final couleurs = Theme.of(context).colorScheme;
    final zone = widget.zone;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          // La ligne suit le doigt depuis où il s'est posé, seuil compris.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (d) => widget.surToucher(vue.versPage(d.localPosition)),
          onPanStart: (d) {
            final z = widget.zone;
            _porte =
                z != null &&
                z.inflate(12).contains(vue.versPage(d.localPosition));
            _debut = true;
          },
          onPanUpdate: (d) {
            if (!_porte) {
              vue.glisser(d.delta);
              return;
            }
            widget.surDeplacer(d.delta / vue.zoom, debut: _debut);
            _debut = false;
          },
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
