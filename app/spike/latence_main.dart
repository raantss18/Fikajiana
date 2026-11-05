// Spike : combien de points du stylet arrivent à Flutter.
// Textes en français seulement : cet écran n'entre pas dans l'application.
import 'dart:async';

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana/ui/theme/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _canal = MethodChannel('fikajiana/essai');

void main() => runApp(const _AppEssai());

class _AppEssai extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fikajiana (stylet)',
      theme: AppTheme.clair,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _EcranMesure(),
    );
  }
}

class _EcranMesure extends StatefulWidget {
  const new();

  @override
  State<_EcranMesure> createState() => _EcranMesureState();
}

class _EcranMesureState extends State<_EcranMesure> {
  var _encre = Encre();
  final _ecarts = <int>[];
  var _pointsFlutter = 0;
  Duration? _dernier;
  String _rapport = 'Écris au stylet une dizaine de secondes, puis mesure.';

  void _compter(PointerEvent e) {
    if (e.kind != PointerDeviceKind.stylus) return;
    _pointsFlutter++;
    final dernier = _dernier;
    if (dernier != null && e is PointerMoveEvent) {
      _ecarts.add((e.timeStamp - dernier).inMicroseconds);
    }
    _dernier = e.timeStamp;
  }

  Future<void> _mesurer() async {
    final natif = await _canal.invokeMapMethod<String, int>('compteursStylet');
    final evenements = natif?['evenements'] ?? 0;
    final points = natif?['points'] ?? 0;
    final ecarts = [..._ecarts]..sort();
    final mediane = ecarts.isEmpty ? 0 : ecarts[ecarts.length ~/ 2];
    final pire = ecarts.isEmpty ? 0 : ecarts.last;
    final part = points == 0 ? 0 : 100 * _pointsFlutter ~/ points;
    setState(() {
      _rapport = [
        'Android : $evenements événements, $points points',
        'Flutter : $_pointsFlutter points reçus au stylet ($part %)',
        'Écart médian entre points : ${mediane / 1000} ms ; le pire : ${pire / 1000} ms',
        if (mediane > 0)
          'Soit ${(1000000 / mediane).round()} points par seconde',
      ].join('\n');
    });
  }

  Future<void> _recommencer() async {
    await _canal.invokeMethod<void>('remettreCompteursStylet');
    setState(() {
      _encre = Encre();
      _ecarts.clear();
      _pointsFlutter = 0;
      _dernier = null;
      _rapport = 'Écris au stylet une dizaine de secondes, puis mesure.';
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_canal.invokeMethod<void>('remettreCompteursStylet'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesure du stylet')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppEspacement.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(_rapport),
              const SizedBox(height: AppEspacement.sm),
              Wrap(
                spacing: AppEspacement.sm,
                children: [
                  FilledButton(
                    onPressed: _mesurer,
                    child: const Text('Mesurer'),
                  ),
                  OutlinedButton(
                    onPressed: _recommencer,
                    child: const Text('Recommencer'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(
                      Clipboard.setData(ClipboardData(text: _rapport)),
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copier'),
                  ),
                ],
              ),
              const SizedBox(height: AppEspacement.sm),
              Expanded(
                child: Listener(
                  onPointerDown: _compter,
                  onPointerMove: _compter,
                  onPointerUp: (_) => _dernier = null,
                  child: FeuilleEncre(
                    encre: _encre,
                    libelle: "Zone d'écriture",
                    surChangement: () => setState(() {}),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
