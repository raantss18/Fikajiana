import 'dart:async';

import 'package:collecte/collecte.dart';
import 'package:collecte/ecran_seance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const _texteDonnees =
    'Cette app recueille votre écriture des signes mathématiques, pour '
    'apprendre à Fikajiana à la lire.\n\n'
    'Tout reste sur cet appareil. Rien ne part tant que vous ne touchez pas '
    '« Exporter », qui ouvre le partage d’Android : vous choisissez à qui '
    'envoyer le fichier. L’app n’a pas accès à Internet.\n\n'
    'Les données envoyées au projet sont versées dans le domaine public '
    '(CC0 1.0) : tout le monde pourra les réutiliser librement. Le prénom '
    'ci-dessous est écrit dans le fichier.';

class AppCollecte extends StatelessWidget {
  const new({required this.collecte, super.key});

  final Collecte collecte;

  @override
  Widget build(BuildContext context) {
    const graine = Color(0xFF1F2A44);
    return MaterialApp(
      title: 'Fikajiana Écriture',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorSchemeSeed: graine),
      darkTheme: ThemeData(
        colorSchemeSeed: graine,
        brightness: Brightness.dark,
      ),
      home: ListenableBuilder(
        listenable: collecte,
        builder: (context, _) => collecte.reglages.accueilLu
            ? EcranAccueil(collecte: collecte)
            : EcranBienvenue(collecte: collecte),
      ),
    );
  }
}

/// Premier lancement : à quoi servent les données, et le prénom.
class EcranBienvenue extends StatefulWidget {
  const new({required this.collecte, super.key});

  final Collecte collecte;

  @override
  State<EcranBienvenue> createState() => _EcranBienvenueState();
}

class _EcranBienvenueState extends State<EcranBienvenue> {
  late final _prenom = TextEditingController(
    text: widget.collecte.reglages.prenom,
  );

  @override
  void dispose() {
    _prenom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Fikajiana Écriture')),
      body: _Colonne(
        children: [
          Text('À quoi servent ces données', style: texte.headlineSmall),
          const SizedBox(height: 12),
          Text(_texteDonnees, style: texte.bodyLarge),
          const SizedBox(height: 24),
          TextField(
            controller: _prenom,
            decoration: const InputDecoration(
              labelText: 'Prénom',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),
          _GrosBouton(
            libelle: 'J’ai compris, commencer',
            surAppui: () => widget.collecte.changerReglages((r) {
              r
                ..prenom = _prenom.text.trim()
                ..accueilLu = true;
            }),
          ),
        ],
      ),
    );
  }
}

/// L'accueil : reprendre, commencer, exporter, régler.
class EcranAccueil extends StatelessWidget {
  const new({required this.collecte, super.key});

  final Collecte collecte;

  Future<void> _ouvrir(BuildContext context, {String? nouvelle}) async {
    if (nouvelle != null) {
      final media = MediaQuery.of(context);
      await collecte.commencer(
        mode: nouvelle,
        ecran: media.size,
        densite: media.devicePixelRatio,
      );
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EcranSeance(collecte: collecte)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = collecte.reglages;
    final s = collecte.seance;
    final texte = Theme.of(context).textTheme;
    final nbSignes = collecte.catalogue.signes.length;
    final nbExpressions = collecte.catalogue.expressions.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Fikajiana Écriture')),
      body: _Colonne(
        children: [
          Text(
            r.prenom.isEmpty ? 'Bonjour' : 'Bonjour ${r.prenom}',
            style: texte.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (s != null && !s.finie) ...[
            _GrosBouton(
              libelle:
                  'Reprendre la séance de ${s.mode} : '
                  '${s.position + 1} / ${s.demandes.length}',
              surAppui: () => _ouvrir(context),
            ),
            const SizedBox(height: 12),
          ],
          _GrosBouton(
            libelle:
                'Nouvelle séance de signes '
                '($nbSignes signes × ${r.repetitions})',
            tonal: s != null && !s.finie,
            surAppui: () => _ouvrir(context, nouvelle: 'signes'),
          ),
          const SizedBox(height: 12),
          _GrosBouton(
            libelle: 'Nouvelle séance d’expressions ($nbExpressions)',
            tonal: true,
            surAppui: () => _ouvrir(context, nouvelle: 'expressions'),
          ),
          const SizedBox(height: 12),
          BoutonExporter(collecte: collecte),
          const Divider(height: 40),
          Text('Réglages', style: texte.titleLarge),
          SwitchListTile(
            title: const Text('Le doigt écrit'),
            subtitle: const Text(
              'Sinon, dès qu’un stylet a servi, seul le stylet écrit.',
            ),
            value: r.doigtEcrit,
            onChanged: (v) => collecte.changerReglages((r) => r.doigtEcrit = v),
          ),
          ListTile(
            title: const Text('Validation automatique'),
            subtitle: Text(
              r.delaiMs == 0
                  ? 'Jamais : toucher « Suivant »'
                  : 'Après ${_secondes(r.delaiMs)} sans trait',
            ),
          ),
          Slider(
            value: r.delaiMs.toDouble(),
            max: 3000,
            divisions: 15,
            label: r.delaiMs == 0 ? 'jamais' : _secondes(r.delaiMs),
            semanticFormatterCallback: (v) =>
                v == 0 ? 'jamais' : _secondes(v.round()),
            onChanged: (v) =>
                collecte.changerReglages((r) => r.delaiMs = v.round()),
          ),
          ListTile(
            title: const Text('Chaque signe est demandé'),
            subtitle: Text('${r.repetitions} fois par séance'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Une fois de moins',
                  onPressed: r.repetitions > 1
                      ? () => collecte.changerReglages((r) => r.repetitions--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: 'Une fois de plus',
                  onPressed: r.repetitions < 10
                      ? () => collecte.changerReglages((r) => r.repetitions++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('À quoi servent ces données'),
            subtitle: Text('Prénom : ${r.prenom}. Licence CC0 1.0.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => collecte.changerReglages((r) => r.accueilLu = false),
          ),
          ListTile(
            title: const Text('Licences'),
            subtitle: const Text('App libre (GPL-3.0-or-later)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Fikajiana Écriture',
              applicationLegalese: 'GPL-3.0-or-later · données CC0 1.0',
            ),
          ),
        ],
      ),
    );
  }
}

String _secondes(int ms) =>
    '${(ms / 1000).toStringAsFixed(1).replaceAll('.', ',')} s';

/// « Exporter » : écrit les séances et ouvre le partage d'Android.
class BoutonExporter extends StatefulWidget {
  const new({required this.collecte, super.key});

  final Collecte collecte;

  @override
  State<BoutonExporter> createState() => _BoutonExporterState();
}

class _BoutonExporterState extends State<BoutonExporter> {
  String? _dossier;
  int? _nombre;

  @override
  void initState() {
    super.initState();
    unawaited(_lireDossier());
  }

  Future<void> _lireDossier() async {
    final d = await widget.collecte.depot.dossierSeances();
    if (mounted) setState(() => _dossier = d);
  }

  Future<void> _exporter() async {
    final (dossier, nombre) = await widget.collecte.exporter();
    if (mounted) {
      setState(() {
        _dossier = dossier;
        _nombre = nombre;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GrosBouton(libelle: 'Exporter', contour: true, surAppui: _exporter),
        if (_nombre != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _nombre == 0
                  ? 'Aucune séance à exporter pour l’instant.'
                  : '$_nombre séance(s) proposée(s) au partage.',
              style: texte.bodyLarge,
            ),
          ),
        if (_dossier != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(
              'Les séances sont aussi dans : $_dossier',
              style: texte.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _GrosBouton extends StatelessWidget {
  const new({
    required this.libelle,
    required this.surAppui,
    this.tonal = false,
    this.contour = false,
  });

  final String libelle;
  final VoidCallback surAppui;
  final bool tonal;
  final bool contour;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 64)),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.titleMedium,
      ),
    );
    final texte = Text(libelle, textAlign: TextAlign.center);
    if (contour) {
      return OutlinedButton(onPressed: surAppui, style: style, child: texte);
    }
    return tonal
        ? FilledButton.tonal(onPressed: surAppui, style: style, child: texte)
        : FilledButton(onPressed: surAppui, style: style, child: texte);
  }
}

class _Colonne extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    ),
  );
}
