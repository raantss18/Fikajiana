import 'package:fikajiana/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum Destination {
  feuille(Icons.edit_outlined, Icons.edit),
  graphe(Icons.show_chart_outlined, Icons.show_chart),
  geometrie(Icons.change_history_outlined, Icons.change_history),
  historique(Icons.history_outlined, Icons.history);

  new(this.icone, this.iconeActive);

  final IconData icone;
  final IconData iconeActive;

  String libelle(AppLocalizations l10n) => switch (this) {
    feuille => l10n.destinationFeuille,
    graphe => l10n.destinationGraphe,
    geometrie => l10n.destinationGeometrie,
    historique => l10n.destinationHistorique,
  };
}
