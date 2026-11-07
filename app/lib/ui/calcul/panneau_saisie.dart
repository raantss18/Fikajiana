import 'dart:async';

import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Ce qui se passera en validant : la saisie le dit avant qu'on valide.
sealed class Verbe {
  const new();
}

/// `2+3`, `2+3=`.
class VerbeCalculer extends Verbe {
  const new();
}

/// `x^2=2`.
class VerbeResoudre extends Verbe {
  const new(this.inconnue);
  final String inconnue;
}

/// `f(x)=x^2`, `x^2+y^2=4`.
class VerbeTracer extends Verbe {
  const new();
}

/// `A(1;2)`, `\\vec{u}(1;3)`.
class VerbePlacer extends Verbe {
  const new();
}

/// Ce que fera ce LaTeX ; `null` s'il ne se comprend pas.
Verbe? verbeDe(String latex) {
  if (lireObjet(latex) != null) return const VerbePlacer();
  if (estCourbeSeule(latex)) return const VerbeTracer();
  final Analyse analyse;
  try {
    analyse = analyserLatex(latex);
  } on ErreurLatex {
    return null;
  }
  return switch (analyse.type) {
    TypeExpression.fonction => const VerbeTracer(),
    TypeExpression.equation => VerbeResoudre(analyse.inconnues.first),
    TypeExpression.systeme ||
    TypeExpression.suite ||
    TypeExpression.calcul ||
    TypeExpression.matrice => const VerbeCalculer(),
  };
}

/// La saisie au clavier (ADR 0024) : on tape, l'aperçu dit ce qui est compris,
/// et le bouton dit ce qui va se passer. Rend le LaTeX.
Future<String?> ouvrirPanneauSaisie(
  BuildContext context,
  String initial, {
  VoidCallback? surRetirer,
  String? aide,
  String? action,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => PanneauSaisie(
      initial: initial,
      surRetirer: surRetirer,
      aide: aide,
      action: action,
    ),
  );
}

/// Les touches qu'un clavier de téléphone cache.
const _touches = <(String, String, int)>[
  ('√', 'sqrt()', 1),
  (';', ';', 0),
  ('^', '^', 0),
  ('π', 'π', 0),
  ('/', '/', 0),
  ('( )', '()', 1),
  ('x', 'x', 0),
  ('=', '=', 0),
];

class PanneauSaisie extends StatefulWidget {
  const new({
    required this.initial,
    this.surRetirer,
    this.aide,
    this.action,
    super.key,
  });

  final String initial;
  final VoidCallback? surRetirer;
  final String? aide;

  /// Le nom du bouton s'il est imposé : au Graphe, on trace toujours.
  final String? action;

  @override
  State<PanneauSaisie> createState() => _PanneauSaisieState();
}

class _PanneauSaisieState extends State<PanneauSaisie> {
  late final _texte = TextEditingController(
    text: texteDepuisLatex(widget.initial),
  );
  final _foyer = FocusNode();

  /// Le dernier aperçu compris : il reste pendant qu'on finit de taper.
  String? _apercu;
  var _autreChoisie = false;

  @override
  void dispose() {
    _texte.dispose();
    _foyer.dispose();
    super.dispose();
  }

  void _inserer(String valeur, int recul) {
    final selection = _texte.selection;
    final debut = selection.isValid ? selection.start : _texte.text.length;
    final fin = selection.isValid ? selection.end : _texte.text.length;
    final texte = _texte.text.replaceRange(debut, fin, valeur);
    _texte.value = TextEditingValue(
      text: texte,
      selection: TextSelection.collapsed(offset: debut + valeur.length - recul),
    );
    _foyer.requestFocus();
    setState(() => _autreChoisie = false);
  }

  String _messageDe(Saisie saisie) {
    final l10n = context.l10n;
    return switch (saisie.probleme) {
      ProblemeSaisie.motInconnu => l10n.saisieMotInconnu(saisie.detail ?? ''),
      ProblemeSaisie.nombresColles => l10n.saisieNombresColles,
      ProblemeSaisie.signeInattendu => l10n.saisieSigneInattendu(
        saisie.detail ?? '',
      ),
      ProblemeSaisie.incomplet || null => l10n.saisieIncomplet,
    };
  }

  String _nomDe(Verbe? verbe) {
    final l10n = context.l10n;
    return widget.action ??
        switch (verbe) {
          VerbeResoudre(:final inconnue) => l10n.saisieResoudre(inconnue),
          VerbeTracer() => l10n.grapheTracer,
          VerbePlacer() => l10n.placerDansFigure,
          VerbeCalculer() || null => l10n.saisieCalculer,
        };
  }

  /// L'aperçu est ce qui a été compris, pas ce qui a été tapé.
  Widget _apercuLu(ThemeData theme, bool valable) {
    final l10n = context.l10n;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          liveRegion: true,
          label: valable ? '${l10n.saisieCompris} : ${_texte.text}' : null,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _apercu == null
                ? Text(
                    widget.aide ?? l10n.saisieAide,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Opacity(
                    // Pas encore comprise : la lecture d'avant reste,
                    // effacée, pour qu'elle ne passe pas pour la bonne.
                    opacity: valable ? 1 : 0.45,
                    child: Math.tex(
                      _apercu!,
                      textStyle: theme.textTheme.titleLarge,
                      onErrorFallback: (_) =>
                          Text(_apercu!, style: theme.textTheme.titleLarge),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final saisie = lireSaisie(_texte.text);
    final autre = saisie.autreLecture;
    final latex = _autreChoisie && autre != null ? autre : saisie.latex;
    final verbe = latex == null ? null : verbeDe(latex);
    // Ce qu'on valide doit se comprendre, ou se tracer : `(cos(t),sin(t))`.
    final valable = latex != null && (verbe != null || widget.action != null);
    if (valable) _apercu = latex;
    final vide = _texte.text.trim().isEmpty;
    final message = vide || valable
        ? null
        : latex != null
        ? l10n.saisiePasCompris
        : _messageDe(saisie);

    return Padding(
      padding: EdgeInsets.only(
        left: AppEspacement.md,
        right: AppEspacement.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppEspacement.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _apercuLu(theme, valable)),
              // Sur un téléphone, les touches défilent : Retirer reste visible.
              if (widget.surRetirer != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.retirer),
                  onPressed: () {
                    widget.surRetirer!();
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppEspacement.xxs),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppEspacement.xxs),
                  Expanded(
                    child: Text(message, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          if (autre != null && valable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: Text(
                  _autreChoisie
                      ? l10n.saisieLectureUne
                      : l10n.saisieLectureDeux,
                ),
                onPressed: () => setState(() => _autreChoisie = !_autreChoisie),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _texte,
                  focusNode: _foyer,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    hintText: l10n.saisieExemple,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() => _autreChoisie = false),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (valable) Navigator.of(context).pop(latex);
                  },
                ),
              ),
              const SizedBox(width: AppEspacement.sm),
              FilledButton(
                onPressed: valable
                    ? () => Navigator.of(context).pop(latex)
                    : null,
                child: Text(_nomDe(verbe)),
              ),
            ],
          ),
          const SizedBox(height: AppEspacement.xxs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (libelle, valeur, recul) in _touches)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => _inserer(valeur, recul),
                    child: Text(libelle),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
