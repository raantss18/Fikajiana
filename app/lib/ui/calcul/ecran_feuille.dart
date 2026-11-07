import 'dart:async';
import 'dart:ui' as ui;

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/stockage_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/export/capture.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:fikajiana/ui/calcul/carte_bloc.dart';
import 'package:fikajiana/ui/calcul/couche_resultats.dart';
import 'package:fikajiana/ui/calcul/panneau_saisie.dart';
import 'package:fikajiana/ui/export.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/reglages/ecran_reglages.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana/ui/theme/marque.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';

const double _ecartSaisies = 64;

/// La Feuille : on écrit sur le support choisi, outils repliés dans un bouton.
class EcranFeuille extends StatefulWidget {
  const new({super.key});

  @override
  State<EcranFeuille> createState() => _EcranFeuilleState();
}

class _EcranFeuilleState extends State<EcranFeuille> {
  final _encre = Encre();
  final _vue = VueFeuille();
  var _gomme = false;
  var _outilsOuverts = false;
  final GlobalKey _image = GlobalKey();
  var _enExport = false;
  bool? _degres;
  bool get _degresVus => _degres ?? false;
  late final CalculFeuille _calcul;
  late final ModeleOcr _modele;
  StockageFeuille? _stockage;

  @override
  void initState() {
    super.initState();
    final services = context
        .getInheritedWidgetOfExactType<PorteeServices>()!
        .services;
    _stockage = services.carnet.stockage;
    _modele = services.modele..addListener(_surModele);
    _calcul = CalculFeuille(
      encre: _encre,
      lecteur: services.lecteur,
      moteur: services.moteur,
      degres: () => _degresVus,
    )..addListener(_enregistrer);
    final document = _stockage?.charger();
    if (document != null) {
      _encre.chargerDocument(document['traits'] as List<dynamic>? ?? const []);
      _calcul.chargerDocument(document['blocs'] as List<dynamic>? ?? const []);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final degres = PorteeReglages.de(context).degres;
    final change = _degres != null && _degres != degres;
    _degres = degres;
    // Après la construction : recalculer prévient les écouteurs.
    if (change) unawaited(Future.microtask(_calcul.recalculer));
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

  /// Une rature a effacé : un geste si rapide doit pouvoir se rattraper.
  void _surRature() => _proposerAnnuler(context.l10n.ratureFaite);

  void _proposerAnnuler(String message) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          // Avec une action, Flutter la garderait jusqu'à ce qu'on la ferme.
          persist: false,
          // À gauche du bouton Outils, qu'elle ne doit pas couvrir.
          margin: const EdgeInsets.only(
            left: AppEspacement.sm,
            right: 72,
            bottom: AppEspacement.sm,
          ),
          action: SnackBarAction(
            label: l10n.annuler,
            onPressed: () {
              _encre.annuler();
              _surEncre();
            },
          ),
        ),
      );
  }

  @override
  void dispose() {
    _stockage?.enregistrer();
    _modele.removeListener(_surModele);
    _calcul.dispose();
    _vue.dispose();
    super.dispose();
  }

  Future<void> _choisirFond() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => const SingleChildScrollView(child: ListeSupports()),
  );

  Future<void> _saisirAuClavier() async {
    final latex = await demanderLatex(context, '');
    if (latex == null || latex.trim().isEmpty || !mounted) return;
    // Chaque saisie sous la précédente : elles ne se recouvrent pas.
    final saisies = _calcul.blocs.where((b) => b.estSaisie).length;
    final depart = MediaQuery.sizeOf(context).center(Offset.zero) / 2;
    final position = depart + Offset(0, saisies * _ecartSaisies);
    unawaited(_calcul.saisir(latex, _vue.versPage(position)));
    setState(() {});
    final services = PorteeServices.de(context);
    final objet = lireObjet(latex);
    if (objet != null) {
      services.atelier.placerObjet(objet);
      Navigator.of(context).push(RouteDestination(Destination.figure));
      return;
    }
    // Le bouton a dit Tracer : la ligne se pose, et le graphique s'ouvre.
    if (verbeDe(latex) is VerbeTracer && services.courbes.ajouter(latex)) {
      Navigator.of(context).push(RouteDestination(Destination.figure));
    }
  }

  /// Où se trouve ce qui est écrit, résultats compris.
  Iterable<Rect> _zonesEcrites(Reglages reglages) sync* {
    final virgule = Localizations.localeOf(context).languageCode == 'fr';
    for (final trait in _encre.traits) {
      final points = trait.pointsVisibles;
      if (points.isEmpty) continue;
      yield points.fold(
        points.first & Size.zero,
        (zone, p) => zone.expandToInclude(p & Size.zero),
      );
    }
    for (final bloc in _calcul.blocs) {
      yield bloc.cadre;
      final ecrit = bloc.ecriture(
        approcheVoulue: reglages.approche,
        virgule: virgule,
      );
      if (ecrit != null) {
        yield ecrit.cadre;
      } else if (bloc.estSaisie) {
        // Une formule saisie vit à côté, dans la largeur de sa carte.
        yield bloc.cadre.bottomLeft & const Size(480, 96);
      }
    }
  }

  Future<ui.Image> _capturer(Reglages reglages) async {
    final cadre = cadreDeLaPage(_zonesEcrites(reglages))!;
    final (zoom, decalage) = (_vue.zoom, _vue.decalage);
    setState(() {
      _enExport = true;
      _outilsOuverts = false;
    });
    try {
      return await capturerPage(_image, cadre, (coin) async {
        _vue.placer(1, -coin);
        await WidgetsBinding.instance.endOfFrame;
      });
    } finally {
      _vue.placer(zoom, decalage);
      if (mounted) setState(() => _enExport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reglages = PorteeReglages.de(context);
    final l10n = context.l10n;
    return Stack(
      fit: StackFit.expand,
      children: [
        // L'image exportée : l'encre et les résultats, sans les boutons.
        RepaintBoundary(
          key: _image,
          child: Stack(
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
                surRature: _surRature,
                doigtDefile: reglages.doigtDefile,
                surStylet: reglages.noterStylet,
                ciblesRature: (zone) => _calcul.traitsDuResultatSous(
                  zone,
                  approcheVoulue: reglages.approche,
                  virgule: Localizations.localeOf(context).languageCode == 'fr',
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([_calcul, _vue]),
                builder: (context, _) => Stack(
                  children: [
                    CoucheResultats(
                      blocs: _calcul.blocs,
                      vue: _vue,
                      approche: reglages.approche,
                      virgule:
                          Localizations.localeOf(context).languageCode == 'fr',
                    ),
                    for (final bloc in _calcul.blocs)
                      RepereBloc(
                        key: ValueKey(bloc.cle),
                        bloc: bloc,
                        calcul: _calcul,
                        vue: _vue,
                        enExport: _enExport,
                        surTouche: () {
                          _encre.retirerPointDuToucher();
                          _surEncre();
                        },
                        surEffacer: () {
                          if (bloc.estSaisie) {
                            _calcul.retirer(bloc);
                            return;
                          }
                          _encre.retirerTraits(bloc.traits);
                          _surEncre();
                          _proposerAnnuler(context.l10n.blocEfface);
                        },
                      ),
                    if (_calcul.modeleManquant && !_enExport)
                      Positioned(
                        left: AppEspacement.md,
                        right: 80,
                        bottom: 72,
                        child: SafeArea(
                          child: Card(
                            child: ListTile(
                              leading: const Icon(Icons.download_outlined),
                              title: Text(l10n.modeleManquant),
                              trailing: TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    RouteEcran((_) => const EcranReglages()),
                                  );
                                },
                                child: Text(l10n.reglages),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_encre.estVide && _calcul.blocs.isEmpty)
          _Invitation(support: reglages.support),
        if (!_enExport)
          Positioned(
            right: 0,
            // Sur un petit téléphone, sous la barre : rien ne se chevauche.
            top: MediaQuery.sizeOf(context).width < 420 ? 56 : 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppEspacement.sm),
                child: TextButton.icon(
                  icon: const Icon(Icons.texture),
                  label: Text(l10n.choisirFond),
                  onPressed: () => unawaited(_choisirFond()),
                ),
              ),
            ),
          ),
        if (!_enExport)
          Positioned(
            left: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppEspacement.sm),
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.keyboard_outlined),
                  label: Text(l10n.saisieOuvrir),
                  onPressed: () {
                    setState(() => _outilsOuverts = false);
                    unawaited(_saisirAuClavier());
                  },
                ),
              ),
            ),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppEspacement.sm),
              child: _Outils(
                ouverts: _outilsOuverts,
                surBasculer: () =>
                    setState(() => _outilsOuverts = !_outilsOuverts),
                encre: _encre,
                vue: _vue,
                reglages: reglages,
                gomme: _gomme,
                surGomme: (valeur) => setState(() {
                  _gomme = valeur;
                  _outilsOuverts = false;
                }),
                surChangement: _surEncre,
                peutExporter: !_encre.estVide || _calcul.blocs.isNotEmpty,
                surExporter: (format) => unawaited(
                  exporter(
                    context,
                    nom: 'feuille',
                    format: format,
                    capture: () => _capturer(reglages),
                  ),
                ),
              ),
            ),
          ),
        ),
        // La page défile sous ce voile, le temps de la photographier.
        if (_enExport)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    label: l10n.exportEnCours,
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
          ),
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

/// Tous les outils, repliés dans un seul bouton à la couleur du stylo.
class _Outils extends StatelessWidget {
  const new({
    required this.encre,
    required this.vue,
    required this.reglages,
    required this.gomme,
    required this.ouverts,
    required this.surBasculer,
    required this.surGomme,
    required this.surChangement,
    required this.peutExporter,
    required this.surExporter,
  });

  final bool peutExporter;
  final ValueChanged<FormatExport> surExporter;
  final Encre encre;
  final VueFeuille vue;
  final Reglages reglages;
  final bool gomme;
  final bool ouverts;
  final VoidCallback surBasculer;
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
    // Chaque commande porte son nom, seuls les stylos restent des pastilles.
    ListTile ligne(IconData icone, String nom, VoidCallback? action) =>
        ListTile(
          dense: true,
          leading: Icon(icone),
          title: Text(nom),
          enabled: action != null,
          onTap: action,
        );
    final boutons = <Widget>[
      Wrap(
        children: [
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
        ],
      ),
      ListTile(
        dense: true,
        leading: Icon(
          gomme ? Icons.cleaning_services : Icons.cleaning_services_outlined,
        ),
        title: Text(l10n.gomme),
        selected: gomme,
        onTap: () => surGomme(!gomme),
      ),
      ligne(
        Icons.undo,
        l10n.annuler,
        encre.peutAnnuler ? () => _agir(encre.annuler) : null,
      ),
      ligne(
        Icons.redo,
        l10n.refaire,
        encre.peutRefaire ? () => _agir(encre.refaire) : null,
      ),
      ligne(
        Icons.delete_outline,
        l10n.effacerTout,
        encre.estVide ? null : () => _agir(encre.effacer),
      ),
      const Divider(),
      ligne(
        Icons.calculate_outlined,
        reglages.approche ? l10n.modeApproche : l10n.modeExact,
        () => reglages.approche = !reglages.approche,
      ),
      ligne(
        Icons.straighten,
        reglages.degres ? l10n.modeDegres : l10n.modeRadians,
        () => reglages.degres = !reglages.degres,
      ),
      const Divider(),
      // Alternative aux gestes à deux doigts (WCAG 2.2, critère 2.5.7).
      ligne(
        Icons.zoom_in,
        l10n.zoomPlus,
        () => vue.zoomerPlus(_centre(context)),
      ),
      ligne(
        Icons.zoom_out,
        l10n.zoomMoins,
        () => vue.zoomerMoins(_centre(context)),
      ),
      ListenableBuilder(
        listenable: vue,
        builder: (context, _) => ligne(
          Icons.fit_screen_outlined,
          l10n.recentrer,
          vue.estInitiale ? null : vue.recentrer,
        ),
      ),
      const Divider(),
      ...lignesExport(
        context,
        actif: peutExporter,
        surChoix: surExporter,
        dense: true,
      ),
    ];
    final couleurs = Theme.of(context).colorScheme;
    final bouton = Semantics(
      button: true,
      expanded: ouverts,
      label: l10n.outils,
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.outils,
        child: Material(
          elevation: 2,
          shape: const CircleBorder(),
          color: couleurs.surfaceContainerHigh,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: surBasculer,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: ouverts
                    ? const Icon(Icons.close)
                    : gomme
                    ? const Icon(Icons.cleaning_services)
                    : Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: support.stylos[reglages.indiceStylo],
                          shape: BoxShape.circle,
                          border: Border.all(color: couleurs.outline),
                        ),
                        child: Icon(Icons.edit, size: 16, color: support.fond),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!ouverts) return bouton;
    final taille = MediaQuery.sizeOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 300,
              maxHeight: taille.height * 0.6,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppEspacement.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: boutons,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppEspacement.sm),
        bouton,
      ],
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
