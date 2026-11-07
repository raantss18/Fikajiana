import 'package:fikajiana/comprendre/carnet.dart';
import 'package:fikajiana/comprendre/classeur.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/formule_affichee.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// L'Historique : les feuilles, graphes et figures gardés sur l'appareil.
class EcranHistorique extends StatelessWidget {
  const new({super.key});

  void _revenir(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _supprimer(
    BuildContext context,
    Carnet carnet,
    ApercuFeuille feuille,
  ) async {
    final l10n = context.l10n;
    final oui = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text(l10n.historiqueSupprimerTitre),
        content: Text(l10n.historiqueSupprimerTexte),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: Text(l10n.annulerDialogue),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: Text(l10n.historiqueSupprimer),
          ),
        ],
      ),
    );
    if (oui ?? false) carnet.supprimer(feuille.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final services = PorteeServices.de(context);
    final carnet = services.carnet;
    final textes = MaterialLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        carnet,
        services.graphes,
        services.figures,
      ]),
      builder: (context, _) {
        final feuilles = carnet.apercus();
        return ListView(
          // Sous les boutons ← et Menu.
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 64,
            bottom: AppEspacement.lg,
          ),
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.historiqueNouvelle),
              onTap: () {
                carnet.nouvelle();
                _revenir(context);
              },
            ),
            _Titre(l10n.historiqueSectionFeuilles),
            for (final feuille in feuilles)
              ListTile(
                selected: feuille.id == carnet.courante,
                title: Text(
                  [
                    textes.formatMediumDate(feuille.modifiee),
                    TimeOfDay.fromDateTime(feuille.modifiee).format(context),
                    if (feuille.id == carnet.courante) l10n.historiqueEnCours,
                  ].join(' · '),
                ),
                subtitle: _Apercu(feuille: feuille),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.historiqueSupprimer,
                  onPressed: () => _supprimer(context, carnet, feuille),
                ),
                onTap: () {
                  carnet.ouvrir(feuille.id);
                  _revenir(context);
                },
              ),
            if (feuilles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppEspacement.lg),
                child: Text(
                  l10n.historiqueVide,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            _Section(
              titre: l10n.historiqueSectionGraphes,
              nouveau: l10n.nouvelleFigure,
              classeur: services.graphes,
              destination: Destination.figure,
              apercu: (d) => _ApercuGraphe(document: d),
            ),
            _Section(
              titre: l10n.historiqueSectionFigures,
              nouveau: l10n.nouvelleFigure,
              classeur: services.figures,
              destination: Destination.figure,
              apercu: (d) => Text(l10n.historiqueObjets(_nombreObjets(d))),
            ),
          ],
        );
      },
    );
  }
}

int _nombreObjets(ApercuDocument d) => switch (d.contenu) {
  final List<dynamic> liste => liste.length,
  final Map<String, dynamic> carte =>
    (carte['objets'] as List<dynamic>? ?? const []).length,
  _ => 0,
};

class _Titre extends StatelessWidget {
  const new(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppEspacement.md,
        right: AppEspacement.md,
        top: AppEspacement.md,
      ),
      child: Semantics(
        header: true,
        child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// Les graphes ou les figures : ouvrir, créer, supprimer.
class _Section extends StatelessWidget {
  const new({
    required this.titre,
    required this.nouveau,
    required this.classeur,
    required this.destination,
    required this.apercu,
  });

  final String titre;
  final String nouveau;
  final Classeur classeur;
  final Destination destination;
  final Widget Function(ApercuDocument) apercu;

  void _aller(BuildContext context) {
    Navigator.of(context)
      ..popUntil((route) => route.isFirst)
      ..push(RouteDestination(destination));
  }

  Future<void> _supprimer(BuildContext context, ApercuDocument d) async {
    final l10n = context.l10n;
    final oui = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text(l10n.historiqueSupprimerAutre),
        content: Text(l10n.historiqueSupprimerTexte),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: Text(l10n.annulerDialogue),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: Text(l10n.historiqueSupprimer),
          ),
        ],
      ),
    );
    if (oui ?? false) classeur.supprimer(d.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textes = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Titre(titre),
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(nouveau),
          onTap: () {
            classeur.nouveau();
            _aller(context);
          },
        ),
        for (final d in classeur.apercus())
          ListTile(
            selected: d.id == classeur.courant,
            title: Text(
              [
                textes.formatMediumDate(d.modifie),
                TimeOfDay.fromDateTime(d.modifie).format(context),
                if (d.id == classeur.courant) l10n.historiqueEnCours,
              ].join(' · '),
            ),
            subtitle: apercu(d),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.historiqueSupprimer,
              onPressed: () => _supprimer(context, d),
            ),
            onTap: () {
              classeur.ouvrir(d.id);
              _aller(context);
            },
          ),
      ],
    );
  }
}

class _ApercuGraphe extends StatelessWidget {
  const new({required this.document});

  final ApercuDocument document;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final courbes = switch (document.contenu) {
      final List<dynamic> liste => liste.whereType<String>().toList(),
      _ => const <String>[],
    };
    if (courbes.isEmpty) return Text(context.l10n.historiqueGrapheVide);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        pourAffichage(courbes.take(3).join(r'\quad ')),
        textStyle: style,
        onErrorFallback: (_) => Text(courbes.first, style: style),
      ),
    );
  }
}

class _Apercu extends StatelessWidget {
  const new({required this.feuille});

  final ApercuFeuille feuille;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodyMedium;
    if (feuille.calculs.isEmpty) {
      return Text(
        feuille.estVide
            ? l10n.historiqueFeuilleVide
            : l10n.historiqueTraits(feuille.traits),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        pourAffichage(feuille.calculs.take(3).join(r'\quad ')),
        textStyle: style,
        onErrorFallback: (_) => Text(feuille.calculs.first, style: style),
      ),
    );
  }
}
