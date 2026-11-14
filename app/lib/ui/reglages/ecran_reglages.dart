import 'dart:async';

import 'package:fikajiana/a_propos/contact.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/mises_a_jour/mise_a_jour.dart';
import 'package:fikajiana/reconnaissance/ecritures.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:fikajiana/ui/export.dart';
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
            child: Semantics(
              header: true,
              child: Text(
                l10n.reglagesLangue,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          RadioGroup<String>(
            groupValue: reglages.langue ?? '',
            onChanged: (code) => reglages.langue = code,
            child: Column(
              children: [
                RadioListTile<String>(
                  value: '',
                  title: Text(l10n.langueSysteme),
                ),
                // Chaque langue s'écrit dans sa langue : on la reconnaît
                // même sans lire celle de l'écran.
                const RadioListTile<String>(
                  value: 'fr',
                  title: Text('Français', locale: Locale('fr')),
                ),
                const RadioListTile<String>(
                  value: 'en',
                  title: Text('English', locale: Locale('en')),
                ),
              ],
            ),
          ),
          const Divider(),
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
          const _MesEcritures(),
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
                  Text(l10n.modelePresentVersion(modele.version)),
                  // La mise à jour du modèle, à la demande (ADR 0064).
                  Semantics(
                    liveRegion: true,
                    child: switch (modele.maj) {
                      EtatMajModele.repos => const SizedBox.shrink(),
                      EtatMajModele.recherche => Text(l10n.modeleMajRecherche),
                      EtatMajModele.aJour => Text(l10n.modeleMajAJour),
                      EtatMajModele.echec => Text(l10n.modeleMajEchec),
                      EtatMajModele.installe => Text(l10n.modeleMajInstallee),
                      EtatMajModele.disponible => Text(
                        l10n.modeleMajDisponible(
                          modele.publie?.version ?? 0,
                          (modele.publie?.fichiers.fold<int>(
                                    0,
                                    (s, f) => s + f.octets,
                                  ) ??
                                  0) ~/
                              1000000,
                        ),
                      ),
                    },
                  ),
                  Wrap(
                    spacing: AppEspacement.sm,
                    children: [
                      if (modele.maj == EtatMajModele.disponible)
                        FilledButton.icon(
                          icon: const Icon(Icons.download_outlined),
                          label: Text(l10n.modeleMajInstaller),
                          onPressed: () =>
                              unawaited(modele.installerMiseAJour()),
                        )
                      else
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.modeleMajRechercher),
                          onPressed: modele.maj == EtatMajModele.recherche
                              ? null
                              : () => unawaited(modele.rechercherMiseAJour()),
                        ),
                      TextButton(
                        onPressed: () => unawaited(modele.supprimer()),
                        child: Text(l10n.modeleSupprimer),
                      ),
                    ],
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
          const SizedBox(height: AppEspacement.sm),
          // Les coordonnées d'Antsa : chaque toucher ouvre une autre app.
          Text(
            '${l10n.contactAutrice} ${Contact.nom}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          _Lien(
            icone: Icons.mail_outline,
            titre: l10n.contactCourriel,
            detail: Contact.courriel,
            lien: 'mailto:${Contact.courriel}',
          ),
          _Lien(
            icone: Icons.code,
            titre: l10n.contactDepot,
            detail: Contact.depot.replaceFirst('https://', ''),
            lien: Contact.depot,
          ),
          if (Contact.lienWhatsApp case final lien?)
            _Lien(
              icone: Icons.chat_outlined,
              titre: l10n.contactWhatsApp,
              detail: '+${Contact.whatsApp}',
              lien: lien,
            ),
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

/// Un lien d'À propos : son nom en toutes lettres, son dessin, et ce qu'il
/// ouvre en petit. Ouvert seulement au toucher ; sans app pour l'ouvrir,
/// on le dit.
class _Lien extends StatelessWidget {
  const new({
    required this.icone,
    required this.titre,
    required this.detail,
    required this.lien,
  });

  final IconData icone;
  final String titre;
  final String detail;
  final String lien;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icone),
    title: Text(titre),
    subtitle: Text(detail),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: () async {
      final message = context.l10n.contactSansApp;
      final messager = ScaffoldMessenger.of(context);
      if (!await ouvrirLien(lien)) {
        messager.showSnackBar(SnackBar(content: Text(message)));
      }
    },
  );
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

/// Ce que l'app garde de l'écriture jugée (👍, ou 👎 corrigé) : sur
/// l'appareil seulement, pour mieux lire la personne (ADR 0041, 0066).
/// Rien n'est envoyé ; on peut l'exporter dans un fichier, ou l'effacer.
class _MesEcritures extends StatelessWidget {
  const new();

  Future<void> _effacer(BuildContext context, Ecritures ecritures) async {
    final l10n = context.l10n;
    final oui = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.effacerEcrituresQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.annulerDialogue),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.effacer),
          ),
        ],
      ),
    );
    if (oui ?? false) await ecritures.toutEffacer();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ecritures = PorteeServices.de(context).classeur.ecritures;
    if (ecritures == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: ecritures,
      builder: (context, _) {
        final n = ecritures.liste.length;
        final vide = n == 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.exporterEcritures),
              subtitle: Text(
                vide
                    ? l10n.aucuneEcriture
                    : l10n.exporterEcrituresAide(
                        n,
                        ecritures.octets < 1000000
                            ? l10n.tailleKo((ecritures.octets / 1000).ceil())
                            : l10n.tailleMo(
                                (ecritures.octets / 1e6).toStringAsFixed(1),
                              ),
                      ),
              ),
              enabled: !vide,
              onTap: () =>
                  unawaited(exporterEcritures(context, ecritures, auteur: '')),
            ),
            if (!vide)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.effacerEcritures),
                onTap: () => unawaited(_effacer(context, ecritures)),
              ),
          ],
        );
      },
    );
  }
}
