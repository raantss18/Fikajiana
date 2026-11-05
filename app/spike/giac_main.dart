// Version d'essai sans câble : mesure Giac et donne un rapport à copier.
// Textes en français seulement : cet écran n'entre pas dans l'application.
import 'dart:io';

import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana/ui/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _version = '0.1.0-essai.2';

const _essais = [
  'diff(sin(x)^2,x)',
  'latex(diff(sin(x)^2,x))',
  'integrate(1/(x^2+1),x)',
  'limit(sin(x)/x,x,0)',
  'solve(x^2-2=0,x)',
  'factor(x^4-1)',
  'det([[1,2],[3,4]])',
  'sum(1/k^2,k,1,inf)',
  '2^200',
  '1/3+1/6',
  'evalf(pi,30)',
  '1/0',
  '2+',
];

const _proprietes = [
  'ro.product.manufacturer',
  'ro.product.model',
  'ro.product.cpu.abi',
  'ro.soc.model',
  'ro.build.version.release',
  'ro.build.version.sdk',
];

void main() => runApp(const _AppEssai());

class _AppEssai extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fikajiana (essai)',
      theme: AppTheme.clair,
      darkTheme: AppTheme.sombre,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _EcranEssai(),
    );
  }
}

class _EcranEssai extends StatefulWidget {
  const new();

  @override
  State<_EcranEssai> createState() => _EcranEssaiState();
}

class _EcranEssaiState extends State<_EcranEssai> {
  final _lignes = <String>[];
  final _trace = File('${Directory.systemTemp.path}/fikajiana_essai.txt');
  var _enCours = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decrire());
  }

  /// Rien ne touche Giac ici : si le calcul plante, ce rapport reste lisible.
  Future<void> _decrire() async {
    _ajouter('Fikajiana $_version');
    for (final propriete in _proprietes) {
      final resultat = await Process.run('getprop', [propriete]);
      _ajouter('$propriete = ${resultat.stdout.toString().trim()}');
    }
    // En version release, la taille vaut zéro pendant les premières images.
    final vue = WidgetsBinding.instance.platformDispatcher.views.first;
    for (var i = 0; i < 40 && vue.physicalSize.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final taille = vue.physicalSize / vue.devicePixelRatio;
    _ajouter(
      'écran = ${taille.width.round()}×${taille.height.round()} dp, '
      'densité ${vue.devicePixelRatio}',
    );
    if (_trace.existsSync()) {
      _ajouter('PLANTAGE PRÉCÉDENT pendant : ${_trace.readAsStringSync()}');
    }
    const canal = MethodChannel('fikajiana/essai');
    final arrets = await canal.invokeListMethod<String>('derniersArrets');
    for (final arret in arrets ?? const <String>[]) {
      _ajouter('arrêt : $arret');
    }
  }

  Future<void> _calculer() async {
    setState(() => _enCours = true);
    _ajouter('mémoire avant = ${ProcessInfo.currentRss ~/ 1000000} Mo');
    for (final entree in _essais) {
      _trace.writeAsStringSync(entree, flush: true);
      final chrono = Stopwatch()..start();
      final sortie = await evaluerGiac(entree);
      _ajouter('${chrono.elapsedMilliseconds} ms | $entree | $sortie');
    }
    _trace.deleteSync();
    _ajouter('mémoire après = ${ProcessInfo.currentRss ~/ 1000000} Mo');
    _ajouter('mémoire maximale = ${ProcessInfo.maxRss ~/ 1000000} Mo');
    _ajouter('FIN : tous les calculs ont abouti');
    if (mounted) setState(() => _enCours = false);
  }

  void _ajouter(String ligne) {
    if (mounted) setState(() => _lignes.add(ligne));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Essai du moteur')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppEspacement.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(_lignes.join('\n')),
                ),
              ),
              const SizedBox(height: AppEspacement.sm),
              FilledButton(
                onPressed: _enCours ? null : _calculer,
                child: Text(
                  _enCours ? 'Calcul en cours…' : 'Lancer les calculs',
                ),
              ),
              const SizedBox(height: AppEspacement.sm),
              OutlinedButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: _lignes.join('\n'))),
                icon: const Icon(Icons.copy),
                label: const Text('Copier le rapport'),
              ),
              const SizedBox(height: AppEspacement.sm),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context)
                        .push(RouteDestination(Destination.feuille)),
                child: const Text("Voir les écrans de l'application"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
