import 'dart:async';

import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/mises_a_jour/mise_a_jour.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
          const ListeSupports(),
          if (reglages.styletConnu)
            SwitchListTile(
              title: Text(l10n.ecrireAuDoigt),
              subtitle: Text(l10n.ecrireAuDoigtDetail),
              value: reglages.ecrireAuDoigt,
              onChanged: (valeur) => reglages.ecrireAuDoigt = valeur,
            ),
          SwitchListTile(
            title: Text(l10n.auPropre),
            subtitle: Text(l10n.auPropreDetail),
            value: reglages.auPropre,
            onChanged: (valeur) => reglages.auPropre = valeur,
          ),
          const Divider(),
          const _SectionModele(),
          const Divider(),
          const _SectionMiseAJour(),
          const Divider(),
          const _SectionAPropos(),
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

class _SectionMiseAJour extends StatefulWidget {
  const new();

  @override
  State<_SectionMiseAJour> createState() => _SectionMiseAJourState();
}

class _SectionMiseAJourState extends State<_SectionMiseAJour> {
  final _maj = MiseAJour();

  @override
  void initState() {
    super.initState();
    unawaited(_maj.lireVersion());
  }

  @override
  void dispose() {
    _maj.dispose();
    super.dispose();
  }

  Future<void> _installer() async {
    final cache = await getTemporaryDirectory();
    await _maj.installer(cache.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final langue = Localizations.localeOf(context).languageCode;
    return ListenableBuilder(
      listenable: _maj,
      builder: (context, _) {
        final publiee = _maj.publiee;
        final occupe =
            _maj.etat == EtatMiseAJour.recherche ||
            _maj.etat == EtatMiseAJour.telechargement;
        return Padding(
          padding: const EdgeInsets.all(AppEspacement.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.majTitre,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppEspacement.sm),
              if (_maj.versionInstallee != null)
                Text(l10n.majInstallee(_maj.versionInstallee!)),
              Text(l10n.majExplication),
              const SizedBox(height: AppEspacement.sm),
              if (_maj.etat == EtatMiseAJour.aJour) Text(l10n.majAJour),
              if (_maj.etat == EtatMiseAJour.echec) Text(l10n.majEchec),
              if (_maj.etat == EtatMiseAJour.installation)
                Text(l10n.majInstallation),
              if (_maj.etat == EtatMiseAJour.telechargement)
                LinearProgressIndicator(value: _maj.progression),
              if (publiee != null) ...[
                Text(l10n.majDisponible(publiee.version)),
                Text(publiee.notesPour(langue)),
                const SizedBox(height: AppEspacement.sm),
              ],
              FilledButton(
                onPressed: occupe
                    ? null
                    : publiee != null
                    ? () => unawaited(_installer())
                    : () => unawaited(_maj.rechercher()),
                child: Text(
                  publiee != null ? l10n.majInstaller : l10n.majRechercher,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionAPropos extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppEspacement.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.aProposTitre,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppEspacement.sm),
          SelectableText(l10n.aProposTexte),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationLegalese: l10n.aProposTexte,
            ),
            child: Text(l10n.aProposLicences),
          ),
        ],
      ),
    );
  }
}

/// Le choix du fond, avec son aperçu : dans les Réglages et sur la Feuille.
class ListeSupports extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final reglages = PorteeReglages.de(context);
    final l10n = context.l10n;
    return RadioGroup<SupportEcriture>(
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
    );
  }
}
