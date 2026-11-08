import 'dart:async';

import 'package:collecte/app.dart';
import 'package:collecte/case_ecriture.dart';
import 'package:collecte/collecte.dart';
import 'package:collecte/seance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// La séance : le signe demandé, la case, et trois gros boutons.
class EcranSeance extends StatefulWidget {
  const new({required this.collecte, super.key});

  final Collecte collecte;

  @override
  State<EcranSeance> createState() => _EcranSeanceState();
}

class _EcranSeanceState extends State<EcranSeance> {
  final _encre = EncreCase();
  final GlobalKey<State<StatefulWidget>> _cleCase = GlobalKey();
  Timer? _minuterie;
  var _occupe = false;

  Collecte get _collecte => widget.collecte;

  @override
  void initState() {
    super.initState();
    _encre.addListener(_rafraichir);
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    _encre
      ..removeListener(_rafraichir)
      ..dispose();
    super.dispose();
  }

  void _rafraichir() => setState(() {});

  void _surFin() {
    _minuterie?.cancel();
    final delai = _collecte.reglages.delaiMs;
    if (delai > 0) {
      _minuterie = Timer(Duration(milliseconds: delai), () {
        unawaited(_enregistrer(rejete: false));
      });
    }
  }

  void _effacer() {
    _minuterie?.cancel();
    _encre.effacer();
  }

  Future<void> _enregistrer({required bool rejete}) async {
    _minuterie?.cancel();
    if (_encre.vide || _occupe) return;
    final boite = _cleCase.currentContext!.findRenderObject()! as RenderBox;
    final cadre = boite.localToGlobal(Offset.zero) & boite.size;
    _occupe = true;
    final traits = [
      for (final t in _encre.traits) [...t],
    ];
    final stylet = _encre.stylet;
    _encre.effacer();
    try {
      await _collecte.enregistrer(
        traits: traits,
        cadre: cadre,
        stylet: stylet,
        rejete: rejete,
      );
    } finally {
      _occupe = false;
    }
    if (mounted && rejete) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Raté gardé à part. Réécrivez le même signe.'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _collecte,
      builder: (context, _) {
        final s = _collecte.seance!;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Semantics(
              label: s.finie
                  ? 'Séance finie'
                  : 'Demande ${s.position + 1} sur ${s.demandes.length}',
              excludeSemantics: true,
              child: Text(
                s.finie
                    ? 'Séance finie'
                    : '${s.position + 1} / ${s.demandes.length}',
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: Icon(s.finie ? Icons.home_outlined : Icons.pause),
                  label: Text(s.finie ? 'Accueil' : 'Pause'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: s.finie ? _fin(context) : _travail(context, s),
            ),
          ),
        );
      },
    );
  }

  Widget _fin(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Merci ! La séance est enregistrée.',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          BoutonExporter(collecte: _collecte),
        ],
      ),
    ),
  );

  Widget _travail(BuildContext context, Seance s) {
    final d = s.demande;
    final r = _collecte.reglages;
    return LayoutBuilder(
      builder: (context, contraintes) {
        final court = contraintes.maxHeight < 420;
        final hauteurConsigne = court ? 72.0 : 132.0;
        const hauteurBoutons = 64.0;
        final reste =
            contraintes.maxHeight - hauteurConsigne - hauteurBoutons - 32;
        // Une ligne de cahier : bien plus large que haute.
        final hauteurCase = (contraintes.maxWidth / 2.2).clamp(80.0, reste);
        return Column(
          children: [
            SizedBox(
              height: hauteurConsigne,
              child: _Consigne(demande: d, collecte: _collecte),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  key: _cleCase,
                  width: contraintes.maxWidth,
                  height: hauteurCase,
                  child: CaseEcriture(
                    encre: _encre,
                    doigtEcrit: r.doigtEcrit,
                    styletVu: r.styletVu,
                    surStylet: _collecte.styletDetecte,
                    surDebut: () => _minuterie?.cancel(),
                    surFin: _surFin,
                    consigne: 'Case d’écriture : écrire ${_dire(d, _collecte)}',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: hauteurBoutons,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _encre.vide ? null : _effacer,
                      icon: const Icon(Icons.backspace_outlined),
                      label: const Text('Effacer'),
                      style: _style(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _encre.vide
                          ? null
                          : () => _enregistrer(rejete: true),
                      icon: const Icon(Icons.close),
                      label: const Text('Raté'),
                      style: _style(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _encre.vide
                          ? null
                          : () => _enregistrer(rejete: false),
                      icon: const Icon(Icons.check),
                      label: const Text('Suivant'),
                      style: _style(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  ButtonStyle _style(BuildContext context) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 64)),
    textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.titleMedium),
  );
}

String _dire(Demande d, Collecte c) {
  if (d.type == 'expression') return 'l’expression ${d.attendu}';
  final s = c.catalogue.signe(d.classe!);
  return s == null ? d.attendu : '${s.signe}, ${s.precision}';
}

/// Le signe demandé, en gros, ou l'expression rendue proprement.
class _Consigne extends StatelessWidget {
  const new({required this.demande, required this.collecte});

  final Demande demande;
  final Collecte collecte;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final couleur = Theme.of(context).colorScheme.onSurface;
    if (demande.type == 'expression') {
      return Semantics(
        label: 'Recopier : ${demande.attendu}',
        excludeSemantics: true,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Math.tex(
              demande.attendu,
              textStyle: TextStyle(fontSize: 40, color: couleur),
            ),
          ),
        ),
      );
    }
    final s = collecte.catalogue.signe(demande.classe!);
    return Semantics(
      label: 'Écrire : ${s?.signe ?? demande.attendu}, ${s?.precision ?? ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Expanded(
            child: FittedBox(
              child: Text(
                s?.signe ?? demande.attendu,
                style: texte.displayLarge?.copyWith(color: couleur),
              ),
            ),
          ),
          Text(s?.precision ?? '', style: texte.titleMedium),
        ],
      ),
    );
  }
}
