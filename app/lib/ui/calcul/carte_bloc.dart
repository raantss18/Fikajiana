import 'dart:async';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Autour d'une expression écrite : le résultat, et rien d'autre (ADR 0018).
/// La lecture ne s'affiche pas ; toucher le résultat ouvre sa correction.
class RepereBloc extends StatelessWidget {
  const new({
    required this.bloc,
    required this.calcul,
    required this.vue,
    super.key,
  });

  final BlocCalcul bloc;
  final CalculFeuille calcul;
  final VueFeuille vue;

  Future<void> _corriger(BuildContext context) async {
    final latex = await demanderLatex(
      context,
      bloc.latex ?? '',
      surRetirer: bloc.estSaisie ? () => calcul.retirer(bloc) : null,
    );
    if (latex != null && latex.trim().isNotEmpty) {
      unawaited(calcul.corriger(bloc, latex));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reglages = PorteeReglages.de(context);
    final virgule = Localizations.localeOf(context).languageCode == 'fr';
    final accent = Theme.of(context).colorScheme.tertiary;
    final l10n = context.l10n;
    final ecrit = bloc.ecriture(
      approcheVoulue: reglages.approche,
      virgule: virgule,
    );
    if (ecrit != null) {
      return _Zone(
        cadre: ecrit.cadre.inflate(4),
        vue: vue,
        libelle: l10n.corriger,
        surToucher: () => unawaited(_corriger(context)),
      );
    }

    final droite = bloc.cadre.centerRight * vue.zoom + vue.decalage;
    final dessous = bloc.cadre.bottomLeft * vue.zoom + vue.decalage;
    final Offset position;
    final Widget contenu;
    switch (bloc.etat) {
      case EtatBloc.lecture:
        return Positioned(
          left: droite.dx + AppEspacement.sm,
          top: droite.dy - 24,
          child: const SizedBox.square(
            dimension: 48,
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      case EtatBloc.calcul:
        return Positioned(
          left: droite.dx + AppEspacement.sm,
          top: droite.dy - 24,
          child: IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: l10n.blocArreter,
            onPressed: calcul.arreter,
          ),
        );
      case EtatBloc.sansModele:
        return const SizedBox.shrink();
      case EtatBloc.nonCompris ||
          EtatBloc.sansResultat ||
          EtatBloc.arrete ||
          EtatBloc.erreur:
        final message = switch (bloc.etat) {
          EtatBloc.arrete => l10n.blocArrete,
          EtatBloc.sansResultat => l10n.blocSansResultat,
          EtatBloc.nonCompris => l10n.blocNonCompris,
          _ => l10n.blocErreur,
        };
        return Positioned(
          left: droite.dx + AppEspacement.sm,
          top: droite.dy - 24,
          child: IconButton(
            icon: Icon(Icons.help_outline, color: accent),
            tooltip: message,
            onPressed: () => unawaited(_corriger(context)),
          ),
        );
      case EtatBloc.fait:
        final verite = bloc.verite;
        if (verite != null) {
          position = droite + const Offset(AppEspacement.sm, -14);
          contenu = Text(
            verite ? l10n.blocVrai : l10n.blocFaux,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: accent),
          );
        } else {
          final valeur = bloc.texte(
            approcheVoulue: reglages.approche,
            virgule: virgule,
          );
          if (!bloc.montreResultat || valeur == null) {
            return const SizedBox.shrink();
          }
          position = bloc.estSaisie || !bloc.finitParEgal
              ? dessous
              : droite + const Offset(AppEspacement.sm, -14);
          final ecrit = _sansEgalFinal(bloc.latex ?? '');
          contenu = _Formule(
            latex: !bloc.estSaisie
                ? valeur
                : !bloc.estResolution
                ? '$ecrit = $valeur'
                // `x+3=4 = {1}` serait faux : deux écritures équivalentes.
                : valeur.startsWith('S=')
                ? '$ecrit \\quad $valeur'
                : '$ecrit \\iff $valeur',
            couleur: accent,
          );
        }
    }

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minHeight: 48),
        child: InkWell(
          onTap: () => unawaited(_corriger(context)),
          child: Center(widthFactor: 1, child: contenu),
        ),
      ),
    );
  }
}

/// Zone invisible sur le résultat écrit : on écrit partout ailleurs.
class _Zone extends StatelessWidget {
  const new({
    required this.cadre,
    required this.vue,
    required this.libelle,
    required this.surToucher,
  });

  final Rect cadre;
  final VueFeuille vue;
  final String libelle;
  final VoidCallback surToucher;

  @override
  Widget build(BuildContext context) {
    final coin = cadre.topLeft * vue.zoom + vue.decalage;
    final largeur = cadre.width * vue.zoom;
    final hauteur = cadre.height * vue.zoom;
    return Positioned(
      left: coin.dx,
      top: coin.dy,
      child: Semantics(
        button: true,
        label: libelle,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: surToucher,
          child: SizedBox(
            width: largeur < 48 ? 48 : largeur,
            height: hauteur < 48 ? 48 : hauteur,
          ),
        ),
      ),
    );
  }
}

/// Le résultat écrit à la main après le `=` (ADR 0017), sous la même vue que
/// l'encre. Il n'intercepte aucun geste.
class PeintreResultats extends CustomPainter {
  const new({
    required this.blocs,
    required this.couleur,
    required this.zoom,
    required this.decalage,
    required this.approche,
    required this.virgule,
  });

  final List<BlocCalcul> blocs;
  final Color couleur;
  final double zoom;
  final Offset decalage;
  final bool approche;
  final bool virgule;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..translate(decalage.dx, decalage.dy)
      ..scale(zoom);
    final encre = Paint()..color = couleur;
    for (final bloc in blocs) {
      final ecrit = bloc.ecriture(approcheVoulue: approche, virgule: virgule);
      for (final contour in ecrit?.contours ?? const <Path>[]) {
        canvas.drawPath(contour, encre);
      }
    }
  }

  @override
  bool shouldRepaint(PeintreResultats ancien) => true;
}

/// `2+3=` s'affiche `2+3 = 5` : le signe n'est écrit qu'une fois.
String _sansEgalFinal(String latex) =>
    latex.trimRight().replaceFirst(RegExp(r'=$'), '').trimRight();

class _Formule extends StatelessWidget {
  const new({required this.latex, this.couleur});

  final String latex;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium
        ?.copyWith(color: couleur);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        latex,
        textStyle: style,
        onErrorFallback: (_) => Text(latex, style: style),
      ),
    );
  }
}

/// Dialogue de saisie ou de correction, avec aperçu de la formule.
Future<String?> demanderLatex(
  BuildContext context,
  String initial, {
  VoidCallback? surRetirer,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogueLatex(initial: initial, surRetirer: surRetirer),
  );
}

class _DialogueLatex extends StatefulWidget {
  const new({required this.initial, this.surRetirer});

  final String initial;
  final VoidCallback? surRetirer;

  @override
  State<_DialogueLatex> createState() => _DialogueLatexState();
}

class _DialogueLatexState extends State<_DialogueLatex> {
  late final _texte = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.saisieTitre),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _texte,
            autofocus: widget.initial.isEmpty,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(hintText: l10n.saisieAide),
            onChanged: (_) => setState(() {}),
            // En paysage, le clavier couvre les boutons du dialogue.
            textInputAction: TextInputAction.done,
            onSubmitted: (texte) => Navigator.of(context).pop(texte),
          ),
          const SizedBox(height: AppEspacement.md),
          if (_texte.text.isNotEmpty) _Formule(latex: _texte.text),
        ],
      ),
      actions: [
        if (widget.surRetirer != null)
          TextButton(
            onPressed: () {
              widget.surRetirer!();
              Navigator.of(context).pop();
            },
            child: Text(l10n.retirer),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.annulerDialogue),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_texte.text),
          child: Text(l10n.valider),
        ),
      ],
    );
  }
}
