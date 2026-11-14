import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/etapes.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/ecriture_animee.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';

/// La phrase dite à côté d'une étape.
String phraseEtape(AppLocalizations l10n, RaisonEtape raison) =>
    switch (raison) {
      RaisonEtape.depart => l10n.etapeDepart,
      RaisonEtape.toutAGauche => l10n.etapeToutAGauche,
      RaisonEtape.isoler => l10n.etapeIsoler,
      RaisonEtape.diviser => l10n.etapeDiviser,
      RaisonEtape.coefficients => l10n.etapeCoefficients,
      RaisonEtape.discriminant => l10n.etapeDiscriminant,
      RaisonEtape.deuxSolutions => l10n.etapeDeuxSolutions,
      RaisonEtape.solutionDouble => l10n.etapeSolutionDouble,
      RaisonEtape.aucuneSolution => l10n.etapeAucuneSolution,
      RaisonEtape.premiere => l10n.etapePremiere,
      RaisonEtape.seconde => l10n.etapeSeconde,
      RaisonEtape.conclusion => l10n.etapeConclusion,
    };

/// Ouvre les étapes de la résolution de [bloc], écrites l'une après l'autre
/// comme au tableau (demande d'Antsa, 2026-11-14).
Future<void> montrerEtapes(
  BuildContext context,
  CalculFeuille calcul,
  BlocCalcul bloc,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => PanneauEtapes(etapes: calcul.etapes(bloc)),
);

class PanneauEtapes extends StatelessWidget {
  const new({required this.etapes, super.key});

  final Future<List<Etape>?> etapes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        left: AppEspacement.lg,
        right: AppEspacement.lg,
        bottom: AppEspacement.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.etapesTitre, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppEspacement.sm),
          FutureBuilder<List<Etape>?>(
            future: etapes,
            builder: (context, etat) {
              if (etat.connectionState != ConnectionState.done) {
                return Padding(
                  padding: const EdgeInsets.all(AppEspacement.lg),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: l10n.etapesCalcul,
                    ),
                  ),
                );
              }
              final lignes = etat.data;
              if (lignes == null) {
                return Text(
                  l10n.etapesAucune,
                  style: theme.textTheme.bodyLarge,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, e) in lignes.indexed)
                    _LigneEtape(numero: i + 1, etape: e),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LigneEtape extends StatelessWidget {
  const new({required this.numero, required this.etape});

  final int numero;
  final Etape etape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspacement.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Le numéro, jamais la couleur seule, dit l'ordre.
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppEspacement.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phraseEtape(l10n, etape.raison),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppEspacement.xxs),
                // Chaque ligne s'écrit après la précédente, comme au tableau.
                EcritureAnimee(
                  lignes: [LigneEcrite(etape.latex)],
                  indiceRejouer: l10n.guideRejouer,
                  delai: Duration(milliseconds: 700 * (numero - 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
