import 'dart:async';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/ui/formule_affichee.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Les signes d'une ligne lue au tracé : toucher l'un d'eux propose ses
/// meilleures autres lectures (idée de Mikajy, ADR 0039). Le choix corrige
/// la ligne et reste sur l'appareil comme exemple.
class SignesLus extends StatefulWidget {
  const new({required this.bloc, required this.calcul, super.key});

  final BlocCalcul bloc;
  final CalculFeuille calcul;

  @override
  State<SignesLus> createState() => _SignesLusState();
}

class _SignesLusState extends State<SignesLus> {
  int? _choisi;
  Classement _autres = const [];

  Future<void> _toucher(int i, List<Trait> signe) async {
    setState(() {
      _choisi = i;
      _autres = const [];
    });
    final autres = await widget.calcul.autresSignes(widget.bloc, signe);
    if (!mounted || _choisi != i) return;
    setState(() => _autres = autres);
  }

  void _corriger(List<Trait> signe, String classe) {
    Navigator.of(context).pop();
    unawaited(widget.calcul.corrigerSigne(widget.bloc, signe, classe));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final signes = widget.bloc.signesLus;
    final choisi = _choisi;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspacement.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.signesLusTitre, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppEspacement.xxs),
          Wrap(
            spacing: AppEspacement.xxs,
            runSpacing: AppEspacement.xxs,
            children: [
              for (final (i, (traits, signe)) in signes.indexed)
                ChoiceChip(
                  key: ValueKey('signe-lu-$i'),
                  label: _Signe(latex: signe),
                  tooltip: l10n.signeLuToucher,
                  selected: choisi == i,
                  onSelected: (_) => unawaited(_toucher(i, traits)),
                ),
            ],
          ),
          if (choisi != null && choisi < signes.length) ...[
            const SizedBox(height: AppEspacement.sm),
            Text(l10n.signeLuAutres, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppEspacement.xxs),
            if (_autres.isEmpty)
              const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Wrap(
                spacing: AppEspacement.xxs,
                children: [
                  for (final (classe, _) in _autres)
                    if (classe != signes[choisi].$2)
                      ActionChip(
                        key: ValueKey('autre-signe-$classe'),
                        label: _Signe(latex: classe),
                        tooltip: l10n.blocChoisirLecture,
                        onPressed: () => _corriger(signes[choisi].$1, classe),
                      ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _Signe extends StatelessWidget {
  const new({required this.latex});

  final String latex;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Semantics(
      label: latex,
      excludeSemantics: true,
      child: Math.tex(
        pourAffichage(latex),
        textStyle: style,
        onErrorFallback: (_) => Text(latex, style: style),
      ),
    );
  }
}
