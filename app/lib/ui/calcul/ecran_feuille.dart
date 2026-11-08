import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/comprendre/stockage_feuille.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/feuille_encre.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/export/capture.dart';
import 'package:fikajiana/guide/essai.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:fikajiana/ui/calcul/carte_bloc.dart';
import 'package:fikajiana/ui/calcul/couche_resultats.dart';
import 'package:fikajiana/ui/calcul/panneau_saisie.dart';
import 'package:fikajiana/ui/export.dart';
import 'package:fikajiana/ui/guide/ecran_tour.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/reglages/ecran_reglages.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana/ui/theme/marque.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';

const double _ecartSaisies = 64;

/// Une ligne tapée occupe environ cette place à l'écran : sa formule et son
/// résultat, ou son bouton, centrés sur sa position.
const Size _placeSaisie = Size(480, 64);

/// La première place, en descendant depuis [depart], où une ligne tapée ne
/// couvre rien de [zones] (en coordonnées de la page). Vu sur le Pad 7 : posée
/// à une place fixe, elle recouvrait l'écriture.
@visibleForTesting
Offset placeLibre(Offset depart, List<Rect> zones, {double zoom = 1}) {
  final taille = _placeSaisie / zoom;
  final pas = _ecartSaisies / zoom;
  for (var i = 0; i < 200; i++) {
    final position = depart + Offset(0, i * pas);
    final occupe = Rect.fromLTWH(
      position.dx,
      position.dy - taille.height / 2,
      taille.width,
      taille.height,
    );
    if (!zones.any(occupe.overlaps)) return position;
  }
  return depart;
}

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
  late final EssaiGuide _essais;
  StockageFeuille? _stockage;

  @override
  void initState() {
    super.initState();
    final services = context
        .getInheritedWidgetOfExactType<PorteeServices>()!
        .services;
    _stockage = services.carnet.stockage;
    _modele = services.modele..addListener(_surModele);
    _essais = services.essais..addListener(_lancerEssai);
    _calcul = CalculFeuille(
      encre: _encre,
      lecteur: services.lecteur,
      moteur: services.moteur,
      classeur: services.classeur,
      degres: () => _degresVus,
    )..addListener(_enregistrer);
    final document = _stockage?.charger();
    if (document != null) {
      _encre.chargerDocument(document['traits'] as List<dynamic>? ?? const []);
      _calcul.chargerDocument(document['blocs'] as List<dynamic>? ?? const []);
    }
    // Une demande du Guide faite avant que cette feuille soit là.
    if (_essais.enAttente) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lancerEssai());
    }
    // Après une mise à jour, le modèle déjà là : le tour se propose.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_proposerTour()),
    );
  }

  var _tourEnQuestion = false;
  var _tourEnAttente = false;

  /// Une fois par version, quand le modèle est là : un petit tour des
  /// usages de base (ADR 0045).
  Future<void> _proposerTour() async {
    if (_tourEnQuestion || _modele.etat != EtatModele.present) return;
    _tourEnQuestion = true;
    try {
      final services = PorteeServices.de(context);
      final reglages = PorteeReglages.de(context);
      final version = await services.lireVersion();
      if (!mounted || version == null || reglages.tourPropose == version) {
        return;
      }
      // Une autre question (les dons, ADR 0042) ou un autre écran est
      // devant : le tour attend que la Feuille revienne au premier plan.
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
        _tourEnAttente = true;
        return;
      }
      _tourEnAttente = false;
      reglages.noterTourPropose(version);
      final l10n = context.l10n;
      final oui = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.draw_outlined),
          title: Text(l10n.tourProposeTitre),
          content: Text(l10n.tourProposeTexte(version)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.tourPlusTard),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.guideTour),
            ),
          ],
        ),
      );
      if (oui ?? false) {
        if (!mounted) return;
        await Navigator.of(context).push(RouteEcran((_) => const EcranTour()));
      }
    } finally {
      _tourEnQuestion = false;
    }
  }

  void _lancerEssai() => unawaited(_surEssai());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // De retour au premier plan : le tour en attente se propose.
    if (_tourEnAttente && (ModalRoute.of(context)?.isCurrent ?? true)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_proposerTour()),
      );
    }
    final degres = PorteeReglages.de(context).degres;
    final change = _degres != null && _degres != degres;
    _degres = degres;
    // Après la construction : recalculer prévient les écouteurs.
    if (change) unawaited(Future.microtask(_calcul.recalculer));
  }

  void _surModele() {
    if (_modele.etat != EtatModele.present) return;
    _calcul.modeleDisponible();
    // Le modèle vient d'arriver : la première fois, le tour se propose.
    unawaited(_proposerTour());
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
    _essais.removeListener(_lancerEssai);
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
    final latex = await demanderLatex(
      context,
      '',
      analyser: _calcul.analyserEnBas,
    );
    if (latex == null || latex.trim().isEmpty || !mounted) return;
    await _poser(latex);
    if (mounted) _apresSaisie(latex);
  }

  /// Le Guide demande de poser son exemple : ligne après ligne, comme au
  /// clavier, puis la dernière fait ce qu'elle ferait au clavier (ADR 0036).
  Future<void> _surEssai() async {
    final lignes = _essais.prendre();
    if (lignes == null || !mounted) return;
    for (final latex in lignes) {
      await _poser(latex);
      if (!mounted) return;
    }
    _apresSaisie(lignes.last);
  }

  /// Pose [latex] sous tout ce qui est écrit : la ligne voit les fonctions et
  /// les points de la feuille, et ne recouvre rien.
  Future<void> _poser(String latex) async {
    final ecran = MediaQuery.sizeOf(context);
    final depart = _vue.versPage(ecran.center(Offset.zero) / 2);
    final zones = _zonesEcrites(PorteeReglages.de(context)).toList();
    final bas = zones.fold(depart.dy, (b, z) => math.max(b, z.bottom));
    final position = placeLibre(
      Offset(
        depart.dx,
        bas + (_placeSaisie.height / 2 + AppEspacement.sm) / _vue.zoom,
      ),
      zones,
      zoom: _vue.zoom,
    );
    // Hors de vue, la feuille défile jusqu'à elle.
    final y = position.dy * _vue.zoom + _vue.decalage.dy;
    if (y > ecran.height * 0.7) _vue.glisser(Offset(0, ecran.height / 2 - y));
    await _calcul.saisir(latex, position);
    if (mounted) setState(() {});
  }

  /// Une construction, un point ou une courbe : la Figure s'ouvre avec eux.
  void _apresSaisie(String latex) {
    final services = PorteeServices.de(context);
    // Une construction : la ligne se pose, puis la Figure s'ouvre avec elle.
    if (lireCommande(latex) != null) {
      final bloc = _calcul.blocs.lastOrNull;
      final commande = bloc?.commande;
      if (bloc != null && commande != null) {
        bloc.aPlacer.forEach(services.atelier.placerObjet);
        services.atelier.construire(commande);
        Navigator.of(context).push(RouteDestination(Destination.figure));
      }
      return;
    }
    final objet = lireObjet(latex);
    if (objet != null) {
      services.atelier.placerObjet(objet);
      Navigator.of(context).push(RouteDestination(Destination.figure));
      return;
    }
    // Le bouton a dit Tracer : la ligne se pose, et le graphique s'ouvre.
    if (verbeDe(latex, analyser: _calcul.analyserEnBas) is VerbeTracer &&
        services.courbes.ajouter(latex)) {
      Navigator.of(context).push(RouteDestination(Destination.figure));
    }
  }

  /// Les traits écrits au propre : l'encre ne les dessine plus.
  Set<int> _masques() => {
    for (final b in _calcul.blocs)
      if (b.auPropre() != null) ...b.traits,
  };

  /// La couleur de l'encre de la ligne : celle de son premier trait.
  Color _couleurDe(BlocCalcul bloc, Reglages reglages) {
    final premier = _encre.traits
        .where((t) => bloc.traits.contains(t.id))
        .firstOrNull;
    final stylos = reglages.support.stylos;
    return stylos[(premier?.stylo ?? 0).clamp(0, stylos.length - 1)];
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

  /// Le coin de la page : (0, 0), ou plus haut et plus à gauche si une
  /// feuille d'avant les limites y a de l'encre.
  late final Offset _coin = () {
    var (x, y) = (0.0, 0.0);
    for (final trait in _encre.traits) {
      for (final p in trait.pointsVisibles) {
        x = math.min(x, p.dx - AppEspacement.md);
        y = math.min(y, p.dy - AppEspacement.md);
      }
    }
    return Offset(x, y);
  }();

  Future<ui.Image> _capturer(Reglages reglages) async {
    // La page depuis son coin, comme une feuille de cahier : au moins la
    // largeur de l'écran, jusqu'à ce qui est écrit (demande d'Antsa).
    final ecrit = cadreDeLaPage(_zonesEcrites(reglages))!;
    final cadre = Rect.fromLTRB(
      _vue.coin.dx,
      _vue.coin.dy,
      math.max(ecrit.right, _vue.coin.dx + MediaQuery.sizeOf(context).width),
      ecrit.bottom,
    );
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
    // La largeur de l'écran borne les résultats, à la vue de départ.
    _calcul
      ..bordDroit = MediaQuery.sizeOf(context).width - AppEspacement.sm
      ..auPropre = reglages.auPropre;
    _vue.borner(MediaQuery.sizeOf(context).width, coin: _coin);
    return Stack(
      fit: StackFit.expand,
      children: [
        // L'image exportée : l'encre et les résultats, sans les boutons.
        RepaintBoundary(
          key: _image,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ListenableBuilder(
                listenable: _calcul,
                builder: (context, _) => FeuilleEncre(
                  masques: reglages.auPropre ? _masques() : const {},
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
                    virgule:
                        Localizations.localeOf(context).languageCode == 'fr',
                  ),
                ),
              ),
              if (reglages.auPropre)
                IgnorePointer(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_calcul, _vue]),
                    builder: (context, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _PeintrePropre(
                        lignes: [
                          for (final b in _calcul.blocs)
                            if (b.auPropre() case final propre?)
                              (propre, _couleurDe(b, reglages)),
                        ],
                        zoom: _vue.zoom,
                        decalage: _vue.decalage,
                      ),
                    ),
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
            // À gauche du Menu, en haut à droite (Antsa).
            right: 64,
            top: 0,
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
                surRelire: () {
                  setState(() => _outilsOuverts = false);
                  _calcul.relireTout();
                },
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
    required this.surRelire,
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
  final VoidCallback surRelire;

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
      // Sans stylet, le doigt écrit déjà ; avec, on choisit ici (Antsa : « on
      // n'a pas forcément un stylet »).
      SwitchListTile(
        dense: true,
        secondary: const Icon(Icons.touch_app_outlined),
        title: Text(l10n.doigtEcrit),
        subtitle: reglages.styletConnu ? null : Text(l10n.ecrireAuDoigtDetail),
        value: reglages.ecrireAuDoigt || !reglages.styletConnu,
        onChanged: reglages.styletConnu
            ? (valeur) => _agir(() => reglages.ecrireAuDoigt = valeur)
            : null,
      ),
      ligne(Icons.refresh, l10n.relireFeuille, surRelire),
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

/// Ce qui a été lu, écrit au propre à la place de l'encre (Antsa).
class _PeintrePropre extends CustomPainter {
  const new({required this.lignes, required this.zoom, required this.decalage});

  final List<(EcritureResultat, Color)> lignes;
  final double zoom;
  final Offset decalage;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..translate(decalage.dx, decalage.dy)
      ..scale(zoom);
    final encre = Paint();
    for (final (ecrit, couleur) in lignes) {
      encre.color = couleur;
      for (final contour in ecrit.contours) {
        canvas.drawPath(contour, encre);
      }
    }
  }

  @override
  bool shouldRepaint(_PeintrePropre ancien) => true;
}
