import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/copie.dart';
import 'package:fikajiana/comprendre/fautes.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/ecriture_animee.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';

/// Ouvre la relecture de [copie], ligne par ligne (demande d'Antsa,
/// 2026-11-14 : « vérifier ma copie »).
Future<void> montrerCopie(
  BuildContext context,
  CalculFeuille calcul,
  List<LigneCopie> copie,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) {
    final verdicts = calcul.verifier(copie);
    return PanneauCopie(
      copie: copie,
      verdicts: verdicts,
      pistes: verdicts.then((v) => calcul.pistes(copie, v)),
    );
  },
);

/// La phrase qui nomme une faute classique.
String phraseFaute(AppLocalizations l10n, Faute faute) => switch (faute) {
  Faute.doubleProduit => l10n.fauteDoubleProduit,
  Faute.distribution => l10n.fauteDistribution,
  Faute.signeParenthese => l10n.fauteSigneParenthese,
  Faute.deplacementSansSigne => l10n.fauteDeplacementSansSigne,
  Faute.soustraireAuLieuDeDiviser => l10n.fauteSoustraire,
  Faute.multiplierAuLieuDeDiviser => l10n.fauteMultiplier,
  Faute.divisionALEnvers => l10n.fauteDivisionALEnvers,
  Faute.signeDeLaSolution => l10n.fauteSigneSolution,
};

class PanneauCopie extends StatelessWidget {
  const new({
    required this.copie,
    required this.verdicts,
    this.pistes,
    super.key,
  });

  final List<LigneCopie> copie;
  final Future<List<VerdictLigne>> verdicts;

  /// La faute reconnue sur chaque ligne fausse (« Où est ma faute ? »).
  final Future<List<PisteFaute?>>? pistes;

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
            child: Text(l10n.copieTitre, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppEspacement.sm),
          FutureBuilder<List<VerdictLigne>>(
            future: verdicts,
            builder: (context, etat) {
              final v = etat.data;
              if (v == null) {
                return Padding(
                  padding: const EdgeInsets.all(AppEspacement.lg),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: l10n.copieCalcul,
                    ),
                  ),
                );
              }
              final fausses = v.where((e) => e == VerdictLigne.fausse).length;
              final toutJuste = v.skip(1).every((e) => e == VerdictLigne.juste);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, ligne) in copie.indexed)
                    _LigneRelue(
                      ligne: ligne,
                      verdict: v[i],
                      piste: pistes?.then((p) => p[i]),
                    ),
                  if (toutJuste || fausses > 0)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        toutJuste
                            ? l10n.copieToutJuste
                            : l10n.copieBilan(fausses),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LigneRelue extends StatelessWidget {
  const new({required this.ligne, required this.verdict, this.piste});

  final LigneCopie ligne;
  final VerdictLigne verdict;
  final Future<PisteFaute?>? piste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final couleurs = theme.colorScheme;
    // Une forme et une phrase par verdict : la couleur ne dit jamais seule.
    final (icone, teinte, phrase) = switch (verdict) {
      VerdictLigne.depart => (
        Icons.flag_outlined,
        couleurs.onSurfaceVariant,
        l10n.copieDepart,
      ),
      VerdictLigne.juste => (
        Icons.check_circle_outline,
        couleurs.primary,
        l10n.copieJuste,
      ),
      VerdictLigne.fausse => (
        Icons.error_outline,
        couleurs.error,
        l10n.copieFausse,
      ),
      VerdictLigne.inconnue => (
        Icons.help_outline,
        couleurs.onSurfaceVariant,
        l10n.copieInconnue,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspacement.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: teinte, size: 28),
          const SizedBox(width: AppEspacement.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EcritureAnimee(lignes: [LigneEcrite(ligne.latex)]),
                const SizedBox(height: AppEspacement.xxs),
                Text(
                  phrase,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: verdict == VerdictLigne.fausse
                        ? couleurs.error
                        : couleurs.onSurfaceVariant,
                  ),
                ),
                if (verdict == VerdictLigne.fausse && piste != null)
                  FutureBuilder<PisteFaute?>(
                    future: piste,
                    builder: (context, etat) {
                      final p = etat.data;
                      if (p == null) return const SizedBox.shrink();
                      return _Piste(piste: p);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La faute reconnue, comme un professeur l'écrit en marge. La ligne juste
/// ne s'affiche qu'à la demande : on cherche d'abord seul (le Guide promet
/// de montrer l'erreur sans donner la réponse).
class _Piste extends StatefulWidget {
  const new({required this.piste});

  final PisteFaute piste;

  @override
  State<_Piste> createState() => _EtatPiste();
}

class _EtatPiste extends State<_Piste> {
  var _montree = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final correction = widget.piste.correction;
    final encre = theme.colorScheme.onTertiaryContainer;
    return Container(
      margin: const EdgeInsets.only(top: AppEspacement.sm),
      padding: const EdgeInsets.all(AppEspacement.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppEspacement.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '${l10n.fautePiste} ${phraseFaute(l10n, widget.piste.faute)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: encre),
            ),
          ),
          if (correction != null && !_montree)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: encre,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => setState(() => _montree = true),
              child: Text(l10n.fauteVoirLigneJuste),
            ),
          if (correction != null && _montree) ...[
            const SizedBox(height: AppEspacement.xxs),
            Text(
              l10n.fauteIlFallait,
              style: theme.textTheme.labelLarge?.copyWith(color: encre),
            ),
            EcritureAnimee(lignes: [LigneEcrite(correction)]),
          ],
        ],
      ),
    );
  }
}
