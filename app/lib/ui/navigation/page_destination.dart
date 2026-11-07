import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/calcul/ecran_feuille.dart';
import 'package:fikajiana/ui/geometrie/ecran_geometrie.dart';
import 'package:fikajiana/ui/guide/ecran_guide.dart';
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
      // La Figure du document en cours : elle change avec la feuille.
      Destination.figure => ListenableBuilder(
        listenable: PorteeServices.de(context).carnet,
        builder: (context, _) => EcranGeometrie(
          key: ValueKey(PorteeServices.de(context).carnet.courante),
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
            // En haut à gauche : Feuille ou Figure, en dessins nommés pour
            // TalkBack ; l'Historique, lui, garde son retour (Antsa).
            Positioned(
              left: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacement.sm),
                  child: destination == Destination.historique
                      ? BackButton(style: _styleFlottant(context))
                      : _DeuxEspaces(destination: destination),
                ),
              ),
            ),
            // En haut à droite : le Menu.
            Positioned(
              right: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacement.sm),
                  child: _Menu(destination: destination),
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
          // Le dessin seul (Antsa) ; le nom reste dit et montré au toucher.
          ButtonSegment(
            value: d,
            icon: Icon(d == destination ? d.iconeActive : d.icone),
            tooltip: d.libelle(l10n),
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
        // Une seule création : la feuille et sa Figure sont liées (Antsa,
        // ADR 0032). On reste dans l'espace où l'on est.
        _nouveau(Icons.note_add_outlined, l10n.nouveauDocument, () {
          services.carnet.nouvelle();
          _aller(
            context,
            destination == Destination.figure
                ? Destination.figure
                : Destination.feuille,
          );
        }),
        // Feuille et Figure sont déjà en haut à gauche : ici, l'Historique.
        const PopupMenuDivider(),
        PopupMenuItem(
          value: Destination.historique,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Destination.historique.icone),
            title: Text(Destination.historique.libelle(l10n)),
          ),
        ),
        // Le Guide : tout ce que l'app sait faire (ADR 0036).
        PopupMenuItem(
          onTap: () =>
              Navigator.of(context).push(RouteEcran((_) => const EcranGuide())),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.guide),
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
