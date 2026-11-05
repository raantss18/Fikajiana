import 'dart:async';

import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';

class EcranReglages extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reglages = PorteeReglages.de(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reglages),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: l10n.accueil,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppEspacement.md),
            child: Text(
              l10n.reglagesSupport,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<SupportEcriture>(
            groupValue: reglages.support,
            onChanged: (valeur) {
              if (valeur != null) reglages.support = valeur;
            },
            child: Column(
              children: [
                for (final support in SupportEcriture.values)
                  RadioListTile<SupportEcriture>(
                    value: support,
                    title: Text(support.libelle(l10n)),
                    secondary: ExcludeSemantics(
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CustomPaint(
                            size: const Size(72, 48),
                            painter: PeintreSupport(support),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          const _SectionModele(),
        ],
      ),
    );
  }
}

class _SectionModele extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final modele = PorteeServices.de(context).modele;
    return ListenableBuilder(
      listenable: modele,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.all(AppEspacement.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.modeleTitre, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppEspacement.sm),
              Text(l10n.modeleExplication),
              const SizedBox(height: AppEspacement.sm),
              ...switch (modele.etat) {
                EtatModele.present => [
                  Text(l10n.modelePresent),
                  TextButton(
                    onPressed: () => unawaited(modele.supprimer()),
                    child: Text(l10n.modeleSupprimer),
                  ),
                ],
                EtatModele.telechargement => [
                  Text(l10n.modeleEnCours((modele.progression * 100).round())),
                  const SizedBox(height: AppEspacement.sm),
                  LinearProgressIndicator(value: modele.progression),
                  TextButton(
                    onPressed: modele.annuler,
                    child: Text(l10n.annulerDialogue),
                  ),
                ],
                EtatModele.absent || EtatModele.echec => [
                  if (modele.etat == EtatModele.echec) Text(l10n.modeleEchec),
                  Text(l10n.modeleTaille(modele.octetsTotal ~/ 1000000)),
                  const SizedBox(height: AppEspacement.sm),
                  FilledButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: Text(l10n.modeleTelecharger),
                    onPressed: modele.dossier == null
                        ? null
                        : () => unawaited(modele.telecharger()),
                  ),
                ],
              },
            ],
          ),
        );
      },
    );
  }
}
