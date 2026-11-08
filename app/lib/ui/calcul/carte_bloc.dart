import 'dart:async';
import 'dart:math' as math;

import 'package:fikajiana/comprendre/calcul_feuille.dart';
import 'package:fikajiana/encre/traverse_ecriture.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/ui/calcul/action_manuscrite.dart';
import 'package:fikajiana/ui/calcul/marques_bloc.dart';
import 'package:fikajiana/ui/calcul/panneau_saisie.dart';
import 'package:fikajiana/ui/calcul/placer_construction.dart';
import 'package:fikajiana/ui/calcul/signes_lus.dart';
import 'package:fikajiana/ui/formule_affichee.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Autour d'une expression écrite : le résultat, et rien d'autre (ADR 0018).
/// La lecture ne s'affiche pas ; toucher le résultat ouvre sa correction.
class RepereBloc extends StatelessWidget {
  const new({
    required this.bloc,
    required this.calcul,
    required this.vue,
    required this.surTouche,
    required this.surEffacer,
    this.surChoisir,
    this.enExport = false,
    super.key,
  });

  /// Dans une image exportée : ce qui est écrit, sans aucun bouton.
  final bool enExport;
  final BlocCalcul bloc;
  final CalculFeuille calcul;
  final VueFeuille vue;

  /// Un bouton de ce repère vient d'être touché, le stylet a aussi laissé un
  /// point dans l'encre : voir [TraverseEcriture].
  final VoidCallback surTouche;

  /// « Effacer » dans le panneau d'une écriture à vérifier.
  final VoidCallback surEffacer;

  /// Appui long : la ligne est choisie (déplacer, dupliquer, effacer).
  final VoidCallback? surChoisir;

  Future<void> _corriger(BuildContext context) async {
    surTouche();
    final latex = await demanderLatex(
      context,
      bloc.latex ?? '',
      surRetirer: bloc.estSaisie ? () => calcul.retirer(bloc) : null,
      analyser: (latex) => calcul.analyserPour(bloc, latex),
      enTete: bloc.signesLus.isEmpty
          ? null
          : SignesLus(bloc: bloc, calcul: calcul),
    );
    if (latex != null && latex.trim().isNotEmpty) {
      unawaited(calcul.corriger(bloc, latex));
    }
  }

  Future<void> _ouvrirPanneau(BuildContext context, Offset ancre) async {
    surTouche();
    final l10n = context.l10n;
    final encre = PorteeReglages.de(context).support.stylos.first;
    final latex = bloc.latex?.trim() ?? '';
    final choix = await ouvrirPanneauBloc(
      context,
      ancre: ancre,
      message: switch (bloc.etat) {
        EtatBloc.arrete => l10n.blocPanneauArrete,
        EtatBloc.sansResultat => l10n.blocPanneauSansResultat,
        EtatBloc.nonCompris => l10n.blocPanneauNonCompris,
        _ => l10n.blocPanneauErreur,
      },
      // Ce qui a été lu, à l'encre de la feuille, comme sur la ligne.
      lecture: latex.isEmpty
          ? null
          : _Formule(latex: latex, couleur: encre, manuscrite: true),
      effacer: bloc.estSaisie ? l10n.retirer : l10n.blocEffacer,
      motEffacer: bloc.estSaisie ? l10n.motRetirer : l10n.motEffacer,
      autres: [
        for (final autre in bloc.autresLectures)
          LectureManuscrite(
            latex: autre,
            couleur: encre,
            libelle: '${l10n.blocChoisirLecture} : $autre',
            surToucher: () {
              Navigator.of(context, rootNavigator: true).pop();
              unawaited(calcul.corriger(bloc, autre));
            },
          ),
      ],
    );
    if (!context.mounted) return;
    switch (choix) {
      case ChoixBloc.corriger:
        await _corriger(context);
      case ChoixBloc.effacer:
        surEffacer();
      case ChoixBloc.relire:
        calcul.relire(bloc);
      case null:
        break;
    }
  }

  VoidCallback? get _choisirAuLong {
    final choisir = surChoisir;
    if (choisir == null || enExport) return null;
    return () {
      surTouche();
      choisir();
    };
  }

  @override
  Widget build(BuildContext context) {
    final repere = _repere(context);
    final jugement = _jugement(context);
    if (jugement == null) return repere;
    return Positioned.fill(child: Stack(children: [repere, jugement]));
  }

  /// 👍 et 👎 à gauche d'une ligne lue (ADR 0042) : discrets, cibles de
  /// 48 dp. 👍 garde la lecture comme juste ; 👎 ouvre sa correction.
  Widget? _jugement(BuildContext context) {
    if (enExport || !bloc.jugeable) return null;
    // Une place libre près de la ligne, sans couvrir une autre ligne ni
    // ses boutons ; sinon ils se replient (téléphone d'Antsa en paysage).
    const taille = Size(2 * 48, 48);
    final place = calcul.placesJugement(
      taille: taille / vue.zoom,
      approcheVoulue: PorteeReglages.de(context).approche,
      virgule: Localizations.localeOf(context).languageCode == 'fr',
      gauche: -vue.decalage.dx / vue.zoom,
    )[bloc];
    if (place == null) return null;
    final position = place.topLeft * vue.zoom + vue.decalage;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final discret = theme.colorScheme.onSurfaceVariant;
    final choisi = theme.colorScheme.primary;
    final juge = bloc.juge;
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: TraverseEcriture(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('juste-${bloc.cle}'),
              tooltip: l10n.ligneJuste,
              iconSize: 18,
              isSelected: juge ?? false,
              color: discret,
              selectedIcon: Icon(Icons.thumb_up, color: choisi),
              icon: const Icon(Icons.thumb_up_outlined),
              onPressed: () {
                surTouche();
                unawaited(calcul.jugerJuste(bloc));
              },
            ),
            IconButton(
              key: ValueKey('faux-${bloc.cle}'),
              tooltip: l10n.ligneFausse,
              iconSize: 18,
              isSelected: juge == false,
              color: discret,
              selectedIcon: Icon(Icons.thumb_down, color: choisi),
              icon: const Icon(Icons.thumb_down_outlined),
              onPressed: () {
                calcul.jugerFaux(bloc);
                unawaited(_corriger(context));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _repere(BuildContext context) {
    final contenu = _contenu(context);
    final objets = bloc.aPlacer;
    final commande = bloc.commande;
    // Ce qui a été lu ne se réécrit pas sur la feuille (Antsa) : il se voit
    // en touchant le résultat, et se corrige là.
    if (objets.isEmpty || enExport || bloc.etat != EtatBloc.fait) {
      return contenu;
    }
    // Un vecteur calculé : son résultat, et de quoi le placer.
    final haut = bloc.cadre.topRight * vue.zoom + vue.decalage;
    return Positioned.fill(
      child: Stack(
        children: [
          contenu,
          Positioned(
            left: haut.dx + AppEspacement.sm,
            top: haut.dy,
            child: TraverseEcriture(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tapée au clavier, la ligne n'a pas d'encre : on l'écrit.
                  if (bloc.estSaisie)
                    _Formule(
                      latex: bloc.latex ?? '',
                      couleur: PorteeReglages.de(context).support.stylos.first,
                      manuscrite: true,
                    ),
                  _BoutonPlacer(
                    objets: objets,
                    commande: commande,
                    surTouche: surTouche,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenu(BuildContext context) {
    final reglages = PorteeReglages.de(context);
    final virgule = Localizations.localeOf(context).languageCode == 'fr';
    final accent = Theme.of(context).colorScheme.tertiary;
    // L'encre de la feuille : une ligne tapée s'écrit comme à la main.
    final encre = PorteeReglages.de(context).support.stylos.first;
    final l10n = context.l10n;
    final ecrit = bloc.ecriture(
      approcheVoulue: reglages.approche,
      virgule: virgule,
    );
    if (ecrit != null) {
      return _Zone(
        cadre: ecrit.cadre.inflate(4),
        vue: vue,
        libelle: l10n.corriger,
        surToucher: () => unawaited(_corriger(context)),
        surAppuiLong: _choisirAuLong,
      );
    }

    // Un état passager ou un point d'interrogation ne s'imprime pas.
    if (enExport && bloc.etat != EtatBloc.fait) return const SizedBox.shrink();
    final droite = bloc.cadre.centerRight * vue.zoom + vue.decalage;
    final dessous = bloc.cadre.bottomLeft * vue.zoom + vue.decalage;
    final Offset position;
    final Widget contenu;
    switch (bloc.etat) {
      case EtatBloc.lecture || EtatBloc.calcul:
        final lueur = (bloc.cadre.inflate(6).topLeft * vue.zoom) + vue.decalage;
        final taille = bloc.cadre.inflate(6).size * vue.zoom;
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned(
                left: lueur.dx,
                top: lueur.dy,
                width: taille.width,
                height: taille.height,
                child: LueurLecture(couleur: accent),
              ),
              if (bloc.etat == EtatBloc.calcul)
                Positioned(
                  left: droite.dx + AppEspacement.sm,
                  top: droite.dy - 24,
                  child: _ArretDiffere(
                    libelle: l10n.blocArreter,
                    surArreter: () {
                      surTouche();
                      calcul.arreter();
                    },
                  ),
                ),
            ],
          ),
        );
      case EtatBloc.sansModele:
        return const SizedBox.shrink();
      case EtatBloc.nonCompris ||
          EtatBloc.sansResultat ||
          EtatBloc.arrete ||
          EtatBloc.erreur:
        final message = switch (bloc.etat) {
          EtatBloc.arrete => l10n.blocArrete,
          EtatBloc.sansResultat => l10n.blocSansResultat,
          EtatBloc.nonCompris => l10n.blocNonCompris,
          _ => l10n.blocErreur,
        };
        return _AVerifier(
          bloc: bloc,
          vue: vue,
          libelle: message,
          couleur: accent,
          surOuvrir: (ancre) => _ouvrirPanneau(context, ancre),
        );
      case EtatBloc.fait:
        // Un point ou un vecteur : il a sa place en Géométrie.
        final objet = bloc.objet;
        if (objet != null) {
          if (enExport) return const SizedBox.shrink();
          return Positioned(
            left: droite.dx + AppEspacement.sm,
            top: droite.dy - 24,
            child: TraverseEcriture(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bloc.estSaisie)
                    _Formule(
                      latex: bloc.latex ?? '',
                      couleur: encre,
                      manuscrite: true,
                    ),
                  ActionManuscrite(
                    mot: l10n.motPlacer,
                    libelle: l10n.placerDansFigure,
                    surToucher: () {
                      surTouche();
                      PorteeServices.de(context).atelier.placerObjet(objet);
                      Navigator.of(context)
                          .push(RouteDestination(Destination.figure));
                    },
                  ),
                  CrayonManuscrit(
                    libelle: l10n.corriger,
                    surToucher: () => unawaited(_corriger(context)),
                  ),
                ],
              ),
            ),
          );
        }
        // Une courbe : rien à calculer, un bouton nommé pour la tracer. La
        // lecture peut être fausse : elle se corrige à côté.
        if (bloc.seTrace) {
          final formule = _Formule(
            latex: bloc.latex ?? '',
            couleur: enExport ? accent : encre,
            manuscrite: true,
          );
          if (enExport && !bloc.estSaisie) return const SizedBox.shrink();
          final dejaTracee = PorteeServices.de(context).courbes.liste
              .any((c) => c.latex == bloc.latex);
          return Positioned(
            left: droite.dx + AppEspacement.sm,
            top: droite.dy - 24,
            child: enExport
                ? formule
                : TraverseEcriture(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bloc.estSaisie) formule,
                        ActionManuscrite(
                          mot: dejaTracee ? l10n.motVoir : l10n.motTracer,
                          libelle: dejaTracee
                              ? l10n.voirDansFigure
                              : l10n.grapheTracer,
                          surToucher: () {
                            surTouche();
                            final services = PorteeServices.de(context);
                            final deja = services.courbes.liste.any(
                              (c) => c.latex == bloc.latex,
                            );
                            if (deja ||
                                services.courbes.ajouter(bloc.latex ?? '')) {
                              Navigator.of(context)
                                  .push(RouteDestination(Destination.figure));
                            }
                          },
                        ),
                        CrayonManuscrit(
                          libelle: l10n.corriger,
                          surToucher: () => unawaited(_corriger(context)),
                        ),
                      ],
                    ),
                  ),
          );
        }
        final verite = bloc.verite;
        if (verite != null) {
          final mot = Text(
            verite ? l10n.blocVrai : l10n.blocFaux,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: accent),
          );
          // Tapée, la ligne n'a pas d'encre : sans sa formule, « Vrai » seul ne
          // dirait pas de quoi (vu sur le Pad 7 avec `premier(97)`).
          position = bloc.estSaisie
              ? dessous
              : droite + const Offset(AppEspacement.sm, -14);
          // À la main comme le reste : `premier(91) = faux` (Antsa).
          final motEcrit = virgule
              ? (verite ? 'vrai' : 'faux')
              : (verite ? 'true' : 'false');
          contenu = bloc.estSaisie
              ? Wrap(
                  spacing: AppEspacement.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Formule(
                      latex: _sansEgalFinal(bloc.latex ?? ''),
                      couleur: encre,
                      manuscrite: true,
                    ),
                    EcritureManuscrite(
                      latex: '=\\mathrm{$motEcrit}',
                      couleur: accent,
                      repli: mot,
                    ),
                  ],
                )
              : mot;
        } else {
          final valeur = bloc.texte(
            approcheVoulue: reglages.approche,
            virgule: virgule,
          );
          final sansResultat = !bloc.montreResultat || valeur == null;
          if (sansResultat && bloc.estSaisie) {
            // `A=[1,2;3,4]` tapée déclare A : rien à calculer, mais la ligne
            // s'écrit comme les autres (vu sur le Pad 7, elle disparaissait).
            final latex = bloc.latex;
            if (latex == null || latex.isEmpty) return const SizedBox.shrink();
            return Positioned(
              left: dessous.dx,
              top: dessous.dy,
              child: TraverseEcriture(
                child: InkWell(
                  onTap: () => unawaited(_corriger(context)),
                  child: _Formule(
                    latex: latex,
                    couleur: encre,
                    manuscrite: true,
                  ),
                ),
              ),
            );
          }
          if (sansResultat) {
            if (enExport) return const SizedBox.shrink();
            // Rien à afficher, mais on doit pouvoir voir ce qui a été lu.
            return _AVerifier(
              bloc: bloc,
              vue: vue,
              libelle: l10n.corriger,
              couleur: accent,
              vague: false,
              surOuvrir: (_) => unawaited(_corriger(context)),
            );
          }
          position = bloc.estSaisie || bloc.resultatDessous
              ? dessous
              : droite + const Offset(AppEspacement.sm, -14);
          final ecrit = _sansEgalFinal(bloc.latex ?? '');
          // Une valeur approchée se marque `≈` (repris de Mikajy).
          final egal = bloc.estApproche(approcheVoulue: reglages.approche)
              ? r'\approx'
              : '=';
          final reponse = bloc.egalAjoute
              ? '$egal $valeur'
              : !bloc.estSaisie
              ? valeur
              : !bloc.estResolution
              ? '$egal $valeur'
              // `x+3=4 = {1}` serait faux : deux écritures équivalentes.
              : valeur.startsWith('S=')
              ? valeur
              : '\\iff $valeur';
          // Tapée, la ligne s'écrit aussi à la main : la question à l'encre
          // de la feuille, la réponse comme les autres résultats (Antsa).
          contenu = bloc.estSaisie
              ? Wrap(
                  spacing: AppEspacement.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Formule(latex: ecrit, couleur: encre, manuscrite: true),
                    _Formule(latex: reponse, couleur: accent, manuscrite: true),
                  ],
                )
              : _Formule(latex: reponse, couleur: accent, manuscrite: true);
        }
    }

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: TraverseEcriture(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, minHeight: 48),
          child: InkWell(
            onTap: () => unawaited(_corriger(context)),
            onLongPress: _choisirAuLong,
            child: Center(widthFactor: 1, child: contenu),
          ),
        ),
      ),
    );
  }
}

/// Place dans la Figure ce qu'une ligne a calculé : un vecteur et ses points.
class _BoutonPlacer extends StatelessWidget {
  const new({required this.objets, required this.surTouche, this.commande});

  final List<ObjetLu> objets;
  final CommandeGeo? commande;
  final VoidCallback surTouche;

  @override
  Widget build(BuildContext context) => ActionManuscrite(
    mot: context.l10n.motPlacer,
    libelle: context.l10n.placerDansFigure,
    surToucher: () {
      surTouche();
      final atelier = PorteeServices.de(context).atelier;
      objets.forEach(atelier.placerObjet);
      final c = commande;
      if (c != null && !placerConstruction(context, atelier, c)) return;
      Navigator.of(context).push(RouteDestination(Destination.figure));
    },
  );
}

/// « Arrêter » n'apparaît que si le calcul dure : un calcul court ne montre
/// que la lueur.
class _ArretDiffere extends StatefulWidget {
  const new({required this.libelle, required this.surArreter});

  final String libelle;
  final VoidCallback surArreter;

  @override
  State<_ArretDiffere> createState() => _ArretDiffereState();
}

class _ArretDiffereState extends State<_ArretDiffere> {
  static const _attente = Duration(milliseconds: 1500);

  late final Timer _minuteur;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer(_attente, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _minuteur.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Durations.short3,
      child: _visible
          ? TraverseEcriture(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.stop_outlined),
                label: Text(widget.libelle),
                onPressed: widget.surArreter,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Une écriture à vérifier : un trait ondulé dessous, à toucher. Le stylet peut
/// écrire par-dessus. Une expression saisie au clavier se montre aussi.
class _AVerifier extends StatelessWidget {
  const new({
    required this.bloc,
    required this.vue,
    required this.libelle,
    required this.couleur,
    required this.surOuvrir,
    this.vague = true,
  });

  static const _hauteur = 48.0;

  /// Sans trait : la ligne n'a rien à signaler, on peut seulement la toucher.
  final bool vague;

  final BlocCalcul bloc;
  final VueFeuille vue;
  final String libelle;
  final Color couleur;
  final ValueChanged<Offset> surOuvrir;

  @override
  Widget build(BuildContext context) {
    final bas = bloc.cadre.bottomLeft * vue.zoom + vue.decalage;
    final largeur = math.max(_hauteur, bloc.cadre.width * vue.zoom);
    final ligne = Semantics(
      button: true,
      label: libelle,
      child: Builder(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            final boite = context.findRenderObject()! as RenderBox;
            surOuvrir(boite.localToGlobal(Offset(0, boite.size.height)));
          },
          child: SizedBox(
            width: largeur,
            height: _hauteur,
            child: vague ? VagueAVerifier(couleur: couleur) : null,
          ),
        ),
      ),
    );
    if (!bloc.estSaisie) {
      return Positioned(left: bas.dx, top: bas.dy - 16, child: ligne);
    }
    return Positioned(
      left: bas.dx,
      top: bas.dy,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Formule(latex: bloc.latex ?? '', couleur: couleur),
            ligne,
          ],
        ),
      ),
    );
  }
}

/// Zone invisible sur le résultat : la toucher le corrige, y écrire écrit.
class _Zone extends StatelessWidget {
  const new({
    required this.cadre,
    required this.vue,
    required this.libelle,
    required this.surToucher,
    this.surAppuiLong,
  });

  final Rect cadre;
  final VueFeuille vue;
  final String libelle;
  final VoidCallback surToucher;
  final VoidCallback? surAppuiLong;

  @override
  Widget build(BuildContext context) {
    final coin = cadre.topLeft * vue.zoom + vue.decalage;
    final largeur = cadre.width * vue.zoom;
    final hauteur = cadre.height * vue.zoom;
    return Positioned(
      left: coin.dx,
      top: coin.dy,
      child: Semantics(
        button: true,
        label: libelle,
        child: GestureDetector(
          // Le stylet passe aussi à la feuille : on rature un résultat.
          behavior: HitTestBehavior.translucent,
          onTap: surToucher,
          onLongPress: surAppuiLong,
          child: SizedBox(
            width: largeur < 48 ? 48 : largeur,
            height: hauteur < 48 ? 48 : hauteur,
          ),
        ),
      ),
    );
  }
}

/// Le résultat écrit à la main après le `=` (ADR 0017), sous la même vue que
/// l'encre. Il n'intercepte aucun geste.
class PeintreResultats extends CustomPainter {
  const new({
    required this.blocs,
    required this.couleur,
    required this.zoom,
    required this.decalage,
    required this.approche,
    required this.virgule,
    this.avancees = const {},
  });

  /// Où en est l'écriture de chaque résultat, de 0 à 1 ; absent : fini.
  final Map<String, double> avancees;
  final List<BlocCalcul> blocs;
  final Color couleur;
  final double zoom;
  final Offset decalage;
  final bool approche;
  final bool virgule;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..translate(decalage.dx, decalage.dy)
      ..scale(zoom);
    final encre = Paint()..color = couleur;
    for (final bloc in blocs) {
      final ecrit = bloc.ecriture(approcheVoulue: approche, virgule: virgule);
      final avancee = avancees[bloc.cle] ?? 1;
      for (final contour in ecrit?.ecrit(avancee) ?? const <Path>[]) {
        canvas.drawPath(contour, encre);
      }
    }
  }

  @override
  bool shouldRepaint(PeintreResultats ancien) => true;
}

/// `2+3=` s'affiche `2+3 = 5` : le signe n'est écrit qu'une fois.
String _sansEgalFinal(String latex) =>
    latex.trimRight().replaceFirst(RegExp(r'=$'), '').trimRight();

class _Formule extends StatelessWidget {
  const new({required this.latex, this.couleur, this.manuscrite = false});

  final String latex;
  final Color? couleur;

  /// Sur la Feuille, même tapée, une formule s'écrit à la main (Antsa).
  final bool manuscrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium?.copyWith(color: couleur);
    final imprimee = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        pourAffichage(latex),
        textStyle: style,
        onErrorFallback: (_) => Text(latex, style: style),
      ),
    );
    if (!manuscrite) return imprimee;
    return EcritureManuscrite(
      latex: latex,
      couleur: couleur ?? theme.colorScheme.onSurface,
      repli: imprimee,
    );
  }
}

/// Saisie ou correction : voir [ouvrirPanneauSaisie].
Future<String?> demanderLatex(
  BuildContext context,
  String initial, {
  VoidCallback? surRetirer,
  String? aide,
  String? action,
  Analyseur analyser = analyserLatex,
  Widget? enTete,
}) => ouvrirPanneauSaisie(
  context,
  initial,
  surRetirer: surRetirer,
  aide: aide,
  action: action,
  analyser: analyser,
  enTete: enTete,
);
