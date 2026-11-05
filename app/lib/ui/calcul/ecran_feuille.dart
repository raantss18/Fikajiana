import 'dart:async';

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/stockage_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:fikajiana/ui/calcul/carte_bloc.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/reglages/ecran_reglages.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana/ui/theme/marque.dart';
import 'package:flutter/material.dart';

/// La Feuille : on écrit sur le support choisi, les outils à portée de main.
class EcranFeuille extends StatefulWidget {
  const new({super.key});

  @override
  State<EcranFeuille> createState() => _EcranFeuilleState();
}

class _EcranFeuilleState extends State<EcranFeuille> {
  final _encre = Encre();
  final _vue = VueFeuille();
  var _gomme = false;
  late final CalculFeuille _calcul;
  late final ModeleOcr _modele;
  StockageFeuille? _stockage;

  @override
  void initState() {
    super.initState();
    final services = context
        .getInheritedWidgetOfExactType<PorteeServices>()!
        .services;
    _stockage = services.stockage;
    _modele = services.modele..addListener(_surModele);
    _calcul = CalculFeuille(
      encre: _encre,
      lecteur: services.lecteur,
      moteur: services.moteur,
    )..addListener(_enregistrer);
    final document = _stockage?.charger();
    if (document != null) {
      _encre.chargerDocument(document['traits'] as List<dynamic>? ?? const []);
      _calcul.chargerDocument(document['blocs'] as List<dynamic>? ?? const []);
    }
  }

  void _surModele() {
    if (_modele.etat == EtatModele.present) _calcul.modeleDisponible();
  }

  void _enregistrer() {
    _stockage?.programmer(
      () => {'traits': _encre.versDocument(), 'blocs': _calcul.versDocument()},
    );
  }

  void _surEncre() {
    setState(() {});
    _calcul.encreChangee();
    _enregistrer();
  }

  @override
  void dispose() {
    _stockage?.enregistrer();
    _modele.removeListener(_surModele);
    _calcul.dispose();
    _vue.dispose();
    super.dispose();
  }

  Future<void> _saisirAuClavier() async {
    final latex = await demanderLatex(context, '');
    if (latex == null || latex.trim().isEmpty || !mounted) return;
    final centre = MediaQuery.sizeOf(context).center(Offset.zero) / 2;
    unawaited(_calcul.saisir(latex, _vue.versPage(centre)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reglages = PorteeReglages.de(context);
    final l10n = context.l10n;
    final compacte = MediaQuery.sizeOf(context).width < AppLargeurs.compacte;
    final feuille = Stack(
      fit: StackFit.expand,
      children: [
        FeuilleEncre(
          encre: _encre,
          vue: _vue,
          libelle: l10n.zoneEcriture,
          support: reglages.support,
          stylo: reglages.indiceStylo,
          gomme: _gomme,
          surChangement: _surEncre,
        ),
        if (_encre.estVide && _calcul.blocs.isEmpty)
          _Invitation(support: reglages.support),
        ListenableBuilder(
          listenable: Listenable.merge([_calcul, _vue]),
          builder: (context, _) => Stack(
            children: [
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: PeintreResultats(
                    blocs: _calcul.blocs,
                    couleur: Theme.of(context).colorScheme.tertiary,
                    zoom: _vue.zoom,
                    decalage: _vue.decalage,
                  ),
                ),
              ),
              for (final bloc in _calcul.blocs)
                CarteBloc(
                  key: ValueKey(bloc.cle),
                  bloc: bloc,
                  calcul: _calcul,
                  vue: _vue,
                ),
              if (_calcul.modeleManquant)
                Positioned(
                  left: AppEspacement.md,
                  right: AppEspacement.md,
                  bottom: AppEspacement.md,
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: Text(l10n.modeleManquant),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(RouteEcran((_) => const EcranReglages()));
                        },
                        child: Text(l10n.reglages),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    final outils = _BarreOutils(
      encre: _encre,
      vue: _vue,
      reglages: reglages,
      gomme: _gomme,
      vertical: !compacte,
      surGomme: (valeur) => setState(() => _gomme = valeur),
      surChangement: _surEncre,
      surClavier: _saisirAuClavier,
    );
    return compacte
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: feuille),
              outils,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: feuille),
              outils,
            ],
          );
  }
}

/// S'efface au premier trait et ne bloque jamais l'écriture.
class _Invitation extends StatelessWidget {
  const new({required this.support});

  final SupportEcriture support;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MarquePi(),
            const SizedBox(height: AppEspacement.sm),
            Text(
              context.l10n.ecrireIci,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: support.estSombre
                    ? support.stylos[0]
                    : support.stylos[1],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarreOutils extends StatelessWidget {
  const new({
    required this.encre,
    required this.vue,
    required this.reglages,
    required this.gomme,
    required this.vertical,
    required this.surGomme,
    required this.surChangement,
    required this.surClavier,
  });

  final VoidCallback surClavier;
  final Encre encre;
  final VueFeuille vue;
  final Reglages reglages;
  final bool gomme;
  final bool vertical;
  final ValueChanged<bool> surGomme;
  final VoidCallback surChangement;

  Offset _centre(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    return Offset(taille.width / 2, taille.height / 2);
  }

  void _agir(VoidCallback action) {
    action();
    surChangement();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final support = reglages.support;
    final boutons = <Widget>[
      for (var i = 0; i < support.stylos.length; i++)
        _BoutonStylo(
          couleur: support.stylos[i],
          fond: support.fond,
          libelle: support.nomStylo(l10n, i),
          choisi: !gomme && reglages.indiceStylo == i,
          surChoix: () {
            reglages.indiceStylo = i;
            surGomme(false);
          },
        ),
      IconButton(
        icon: const Icon(Icons.cleaning_services_outlined),
        selectedIcon: const Icon(Icons.cleaning_services),
        isSelected: gomme,
        tooltip: l10n.gomme,
        onPressed: () => surGomme(!gomme),
      ),
      IconButton(
        icon: const Icon(Icons.keyboard_outlined),
        tooltip: l10n.saisirClavier,
        onPressed: surClavier,
      ),
      IconButton(
        icon: const Icon(Icons.undo),
        tooltip: l10n.annuler,
        onPressed: encre.peutAnnuler ? () => _agir(encre.annuler) : null,
      ),
      IconButton(
        icon: const Icon(Icons.redo),
        tooltip: l10n.refaire,
        onPressed: encre.peutRefaire ? () => _agir(encre.refaire) : null,
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.effacerTout,
        onPressed: encre.estVide ? null : () => _agir(encre.effacer),
      ),
      // Alternative aux gestes à deux doigts (WCAG 2.2, critère 2.5.7).
      IconButton(
        icon: const Icon(Icons.zoom_in),
        tooltip: l10n.zoomPlus,
        onPressed: () => vue.zoomerPlus(_centre(context)),
      ),
      IconButton(
        icon: const Icon(Icons.zoom_out),
        tooltip: l10n.zoomMoins,
        onPressed: () => vue.zoomerMoins(_centre(context)),
      ),
      ListenableBuilder(
        listenable: vue,
        builder: (context, _) => IconButton(
          icon: const Icon(Icons.fit_screen_outlined),
          tooltip: l10n.recentrer,
          onPressed: vue.estInitiale ? null : vue.recentrer,
        ),
      ),
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: vertical,
        left: false,
        child: SingleChildScrollView(
          scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
          child: Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            children: boutons,
          ),
        ),
      ),
    );
  }
}

/// Pastille de couleur : le stylo choisi porte aussi une coche et un anneau.
class _BoutonStylo extends StatelessWidget {
  const new({
    required this.couleur,
    required this.fond,
    required this.libelle,
    required this.choisi,
    required this.surChoix,
  });

  final Color couleur;
  final Color fond;
  final String libelle;
  final bool choisi;
  final VoidCallback surChoix;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Semantics(
      selected: choisi,
      button: true,
      label: libelle,
      excludeSemantics: true,
      child: Tooltip(
        message: libelle,
        child: InkResponse(
          onTap: surChoix,
          radius: 24,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: couleur,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: choisi ? couleurs.primary : couleurs.outline,
                    width: choisi ? 3 : 1,
                  ),
                ),
                child: choisi ? Icon(Icons.check, size: 16, color: fond) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
