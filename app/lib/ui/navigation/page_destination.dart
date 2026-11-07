import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/calcul/ecran_feuille.dart';
import 'package:fikajiana/ui/geometrie/ecran_geometrie.dart';
import 'package:fikajiana/ui/historique/ecran_historique.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/reglages/ecran_reglages.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Coquille commune à tous les écrans : plein écran, un seul bouton (ADR 0018).
///
/// ← revient à l'écran précédent, Feuille dans le menu revient à l'accueil :
/// ce sont deux gestes distincts (`CLAUDE.md`, règle 9).
class PageDestination extends StatelessWidget {
  const new({required this.destination, super.key});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final sombre = PorteeReglages.de(context).support.estSombre;
    final corps = switch (destination) {
      // Changer de feuille reconstruit l'écran : l'ancienne s'enregistre.
      Destination.feuille => ListenableBuilder(
        listenable: PorteeServices.de(context).carnet,
        builder: (context, _) => EcranFeuille(
          key: ValueKey(PorteeServices.de(context).carnet.courante),
        ),
      ),
      Destination.figure => ListenableBuilder(
        listenable: Listenable.merge([
          PorteeServices.de(context).figures,
          PorteeServices.de(context).graphes,
        ]),
        builder: (context, _) => EcranGeometrie(
          key: ValueKey(
            '${PorteeServices.de(context).figures.courant}'
            '/${PorteeServices.de(context).graphes.courant}',
          ),
        ),
      ),
      Destination.historique => const EcranHistorique(),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (sombre ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            corps,
            Positioned(
              left: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacement.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (Navigator.of(context).canPop()) ...[
                        BackButton(style: _styleFlottant(context)),
                        const SizedBox(width: AppEspacement.sm),
                      ],
                      _Menu(destination: destination),
                      if (destination != Destination.historique) ...[
                        const SizedBox(width: AppEspacement.sm),
                        _DeuxEspaces(destination: destination),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _styleFlottant(BuildContext context) => IconButton.styleFrom(
  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
  elevation: 2,
);

/// Feuille ou Figure, toujours en vue : on sait où l'on est (ADR 0027).
class _DeuxEspaces extends StatelessWidget {
  const new({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<Destination>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        minimumSize: const Size(48, 48),
      ),
      segments: [
        for (final d in [Destination.feuille, Destination.figure])
          ButtonSegment(
            value: d,
            icon: Icon(d.icone),
            label: Text(d.libelle(l10n)),
          ),
      ],
      selected: {destination},
      onSelectionChanged: (choix) {
        final navigateur = Navigator.of(context);
        if (choix.single == Destination.feuille) {
          navigateur.popUntil((route) => route.isFirst);
        } else {
          navigateur.push(RouteDestination(choix.single));
        }
      },
    );
  }
}

/// Le seul bouton de navigation : tous les écrans et les réglages.
class _Menu extends StatelessWidget {
  const new({required this.destination});

  final Destination destination;

  void _aller(BuildContext context, Destination cible) {
    final navigateur = Navigator.of(context);
    if (cible == Destination.feuille) {
      navigateur.popUntil((route) => route.isFirst);
    } else if (cible != destination) {
      navigateur.push(RouteDestination(cible));
    }
  }

  PopupMenuItem<Destination> _nouveau(
    IconData icone,
    String titre,
    VoidCallback surToucher,
  ) => PopupMenuItem(
    onTap: surToucher,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone),
      title: Text(titre),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = PorteeServices.de(context);
    return PopupMenuButton<Destination>(
      icon: const Icon(Icons.menu),
      tooltip: l10n.menu,
      style: _styleFlottant(context),
      onSelected: (cible) => _aller(context, cible),
      itemBuilder: (_) => [
        _nouveau(Icons.note_add_outlined, l10n.nouvelleFeuille, () {
          services.carnet.nouvelle();
          _aller(context, Destination.feuille);
        }),
        _nouveau(Icons.add_box_outlined, l10n.nouvelleFigure, () {
          services.graphes.nouveau();
          services.figures.nouveau();
          _aller(context, Destination.figure);
        }),
        const PopupMenuDivider(),
        for (final d in Destination.values)
          PopupMenuItem(
            value: d,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(d == destination ? d.iconeActive : d.icone),
              title: Text(d.libelle(l10n)),
              trailing: d == destination ? const Icon(Icons.check) : null,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () =>
              Navigator.of(context)
                  .push(RouteEcran((_) => const EcranReglages())),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.reglages),
          ),
        ),
      ],
    );
  }
}

/// Route sans transition quand l'appareil demande de couper les animations.
class RouteDestination extends RouteEcran {
  new(Destination destination)
    : super((_) => PageDestination(destination: destination));
}

class RouteEcran extends MaterialPageRoute<void> {
  new(WidgetBuilder constructeur) : super(builder: constructeur);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
