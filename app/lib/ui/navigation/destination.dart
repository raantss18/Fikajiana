import 'package:fikajiana/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum Destination {
  feuille(Icons.edit_outlined, Icons.edit),
  figure(Icons.change_history_outlined, Icons.change_history),
  historique(Icons.history_outlined, Icons.history);

  new(this.icone, this.iconeActive);

  final IconData icone;
  final IconData iconeActive;

  String libelle(AppLocalizations l10n) => switch (this) {
    feuille => l10n.destinationFeuille,
    figure => l10n.destinationFigure,
    historique => l10n.destinationHistorique,
  };
}
