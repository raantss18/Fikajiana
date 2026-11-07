import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/formule_affichee.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Combien de lignes montre le tableau.
const int lignesTableau = 21;

/// Les valeurs des fonctions de x : `NaN` là où elles ne sont pas définies.
List<({double x, List<double> y})> calculerTableau(
  List<FonctionReelle> fonctions,
  double debut,
  double pas,
) => [
  for (var i = 0; i < lignesTableau; i++)
    () {
      // Multiplier plutôt qu'ajouter : pas d'erreur qui s'accumule.
      final x = debut + i * pas;
      return (x: x, y: [for (final f in fonctions) f(x)]);
    }(),
];

/// Le tableau de valeurs des fonctions tracées.
class TableauValeurs extends StatefulWidget {
  const new({required this.courbes, required this.degres, super.key});

  final List<Courbe> courbes;
  final bool degres;

  @override
  State<TableauValeurs> createState() => _TableauValeursState();
}

class _TableauValeursState extends State<TableauValeurs> {
  final _debut = TextEditingController(text: '-5');
  final _pas = TextEditingController(text: '1');
  double _d = -5;
  double _p = 1;
  var _invalide = false;

  @override
  void dispose() {
    _debut.dispose();
    _pas.dispose();
    super.dispose();
  }

  void _appliquer() {
    final (d, p) = (_lire(_debut.text), _lire(_pas.text));
    setState(() {
      _invalide = d == null || p == null || p == 0;
      if (!_invalide) {
        _d = d!;
        _p = p!;
      }
    });
  }

  double? _lire(String texte) {
    try {
      final v = compilerFonction(
        texte.trim().replaceAll(',', '.'),
        variable: '_',
      )(0);
      return v.isFinite ? v : null;
    } on ErreurEvaluation {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final virgule = Localizations.localeOf(context).languageCode == 'fr';
    final fonctions = [
      for (final c in widget.courbes)
        if (c.genre == GenreCourbe.fonction) c,
    ];
    if (fonctions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppEspacement.lg),
          child: Text(
            l10n.grapheTableauVide,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }
    final lignes = calculerTableau(
      [for (final c in fonctions) c.fonction(degres: widget.degres)],
      _d,
      _p,
    );
    String nombre(double v) => v.isFinite
        ? texteValeur(v, virgule: virgule, chiffres: 6)
        : l10n.grapheNonDefini;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppEspacement.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.grapheTableau,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _debut,
                      decoration: InputDecoration(labelText: l10n.grapheDebut),
                      onSubmitted: (_) => _appliquer(),
                    ),
                  ),
                  const SizedBox(width: AppEspacement.md),
                  Expanded(
                    child: TextField(
                      controller: _pas,
                      decoration: InputDecoration(labelText: l10n.graphePas),
                      onSubmitted: (_) => _appliquer(),
                    ),
                  ),
                  const SizedBox(width: AppEspacement.sm),
                  FilledButton(
                    onPressed: _appliquer,
                    child: Text(l10n.appliquer),
                  ),
                ],
              ),
              if (_invalide)
                Padding(
                  padding: const EdgeInsets.only(top: AppEspacement.xxs),
                  child: Text(
                    l10n.grapheTableauInvalide,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('x'), numeric: true),
                  for (final c in fonctions)
                    DataColumn(
                      numeric: true,
                      label: Math.tex(
                        pourAffichage(c.latex),
                        textStyle: theme.textTheme.bodyMedium,
                        onErrorFallback: (_) => Text(c.latex),
                      ),
                    ),
                ],
                rows: [
                  for (final l in lignes)
                    DataRow(
                      cells: [
                        DataCell(Text(nombre(l.x))),
                        for (final y in l.y) DataCell(Text(nombre(y))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
