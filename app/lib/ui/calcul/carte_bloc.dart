import 'dart:async';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Sous l'écriture : ce qui a été compris et le résultat. L'écriture reste
/// telle quelle (ADR 0012). Toucher la carte permet de corriger (ADR 0003).
class CarteBloc extends StatelessWidget {
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
    final latex = await demanderLatex(context, bloc.latex ?? '');
    if (latex != null && latex.trim().isNotEmpty) {
      unawaited(calcul.corriger(bloc, latex));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final position = bloc.cadre.bottomLeft * vue.zoom + vue.decalage;
    final message = switch (bloc.etat) {
      EtatBloc.lecture => l10n.blocLecture,
      EtatBloc.calcul => l10n.blocCalcul,
      EtatBloc.nonCompris || EtatBloc.sansModele => l10n.blocNonCompris,
      EtatBloc.sansResultat => l10n.blocSansResultat,
      EtatBloc.arrete => l10n.blocArrete,
      EtatBloc.erreur => l10n.blocErreur,
      EtatBloc.fait =>
        bloc.type == TypeExpression.fonction ? l10n.blocFonction : null,
    };
    final virgule = Localizations.localeOf(context).languageCode == 'fr';
    String nombres(String texte) => virgule
        ? texte.replaceAllMapped(
            RegExp(r'(\d)\.(\d)'),
            (m) => '${m[1]}{,}${m[2]}',
          )
        : texte;
    final verite = bloc.verite;
    final resultat = bloc.resultat;
    final afficherResultat =
        bloc.etat == EtatBloc.fait &&
        bloc.type != TypeExpression.fonction &&
        resultat != null;

    return Positioned(
      left: position.dx,
      top: position.dy + AppEspacement.sm,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minHeight: 48),
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: bloc.etat == EtatBloc.lecture
                ? null
                : () => unawaited(_corriger(context)),
            child: Padding(
              padding: const EdgeInsets.all(AppEspacement.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (bloc.latex != null && bloc.latex!.isNotEmpty)
                        _Formule(latex: _sansEgalFinal(bloc.latex!)),
                      if (afficherResultat) ...[
                        Text(
                          ' = ',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                        _Formule(
                          latex: nombres(resultat),
                          couleur: theme.colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                  if (afficherResultat && bloc.approche != null)
                    Text(
                      '≈ ${nombres(bloc.approche!).replaceAll('{,}', ',')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  if (verite != null)
                    Text(
                      verite ? l10n.blocVrai : l10n.blocFaux,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  if (message != null)
                    Text(message, style: theme.textTheme.bodySmall),
                  if (bloc.etat == EtatBloc.calcul)
                    TextButton(
                      onPressed: calcul.arreter,
                      child: Text(l10n.blocArreter),
                    ),
                  if (bloc.estSaisie && bloc.etat != EtatBloc.calcul)
                    TextButton(
                      onPressed: () => calcul.retirer(bloc),
                      child: Text(l10n.retirer),
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
Future<String?> demanderLatex(BuildContext context, String initial) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogueLatex(initial: initial),
  );
}

class _DialogueLatex extends StatefulWidget {
  const new({required this.initial});

  final String initial;

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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _texte,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(hintText: l10n.saisieAide),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppEspacement.md),
          if (_texte.text.isNotEmpty) _Formule(latex: _texte.text),
        ],
      ),
      actions: [
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
