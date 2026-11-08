import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';

/// Construit [commande] dans la Figure. Si elle ne se fait pas, le dit sous
/// la Feuille et rend `false` : la Figure ne s'ouvre pas pour rien.
bool placerConstruction(
  BuildContext context,
  Atelier atelier,
  CommandeGeo commande,
) {
  if (atelier.construire(commande)) return true;
  final l10n = context.l10n;
  final nom = atelier.manquant(commande);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          nom == null
              ? l10n.constructionImpossible
              : l10n.constructionManque(nom),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  return false;
}
