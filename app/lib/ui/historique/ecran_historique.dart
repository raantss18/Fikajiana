import 'package:fikajiana/comprendre/carnet.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/formule_affichee.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// L'Historique : les documents gardés sur l'appareil, chacun sa feuille et
/// sa Figure (ADR 0032).
class EcranHistorique extends StatelessWidget {
  const new({super.key});

  void _revenir(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _supprimer(
    BuildContext context,
    Carnet carnet,
    ApercuFeuille feuille,
  ) async {
    final l10n = context.l10n;
    final oui = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text(l10n.historiqueSupprimerTitre),
        content: Text(l10n.historiqueSupprimerTexte),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: Text(l10n.annulerDialogue),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: Text(l10n.historiqueSupprimer),
          ),
        ],
      ),
    );
    if (oui ?? false) carnet.supprimer(feuille.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final services = PorteeServices.de(context);
    final carnet = services.carnet;
    final textes = MaterialLocalizations.of(context);
    return ListenableBuilder(
      listenable: carnet,
      builder: (context, _) {
        final feuilles = carnet.apercus();
        return ListView(
          // Sous les boutons ← et Menu.
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 64,
            bottom: AppEspacement.lg,
          ),
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.historiqueNouvelle),
              onTap: () {
                carnet.nouvelle();
                _revenir(context);
              },
            ),
            _Titre(l10n.historiqueSectionFeuilles),
            for (final feuille in feuilles)
              ListTile(
                selected: feuille.id == carnet.courante,
                title: Text(
                  [
                    textes.formatMediumDate(feuille.modifiee),
                    TimeOfDay.fromDateTime(feuille.modifiee).format(context),
                    if (feuille.id == carnet.courante) l10n.historiqueEnCours,
                  ].join(' · '),
                ),
                subtitle: _Apercu(feuille: feuille),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.historiqueSupprimer,
                  onPressed: () => _supprimer(context, carnet, feuille),
                ),
                onTap: () {
                  carnet.ouvrir(feuille.id);
                  _revenir(context);
                },
              ),
            if (feuilles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppEspacement.lg),
                child: Text(
                  l10n.historiqueVide,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Titre extends StatelessWidget {
  const new(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppEspacement.md,
        right: AppEspacement.md,
        top: AppEspacement.md,
      ),
      child: Semantics(
        header: true,
        child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _Apercu extends StatelessWidget {
  const new({required this.feuille});

  final ApercuFeuille feuille;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodyMedium;
    final Widget ecrit = feuille.calculs.isEmpty
        ? Text(
            feuille.estVide
                ? l10n.historiqueFeuilleVide
                : l10n.historiqueTraits(feuille.traits),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              pourAffichage(feuille.calculs.take(3).join(r'\quad ')),
              textStyle: style,
              onErrorFallback: (_) => Text(feuille.calculs.first, style: style),
            ),
          );
    // Sa Figure : la même ligne, puisqu'elle fait partie du document.
    if (feuille.courbes.isEmpty && feuille.objets == 0) return ecrit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ecrit,
        Text(
          l10n.historiqueFigure(feuille.courbes.length, feuille.objets),
          style: style,
        ),
      ],
    );
  }
}
