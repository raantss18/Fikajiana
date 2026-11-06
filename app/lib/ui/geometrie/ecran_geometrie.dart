import 'dart:async';

import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reglages/reglages.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:fikajiana/ui/geometrie/panneaux.dart';
import 'package:fikajiana/ui/geometrie/peintre_figure.dart';
import 'package:fikajiana/ui/geometrie/pictogrammes.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Tolérance d'un toucher : la taille d'une cible, 48 dp.
const double _rayonToucher = 24;

/// Ce qui attire un point vers la grille, en pixels.
const double _rayonAimant = 8;

/// La Géométrie : une figure qui se déforme quand on déplace ses points.
class EcranGeometrie extends StatefulWidget {
  const new({super.key});

  @override
  State<EcranGeometrie> createState() => _EcranGeometrieState();
}

class _EcranGeometrieState extends State<EcranGeometrie> {
  final _vue = VueGraphe();
  Size _taille = Size.zero;
  Offset _dernierFocal = Offset.zero;
  double _derniereEchelle = 1;
  int? _attrape;
  int? _glisse;
  late ({double x, double y}) _dernierMaths;
  Offset? _doigt;
  Offset? _depart;

  Atelier get _atelier => PorteeServices.de(context).atelier;

  double get _tolerance => _rayonToucher / _vue.unite;

  bool get _construit =>
      _atelier.outil != OutilGeo.deplacer && _atelier.outil != OutilGeo.curseur;

  @override
  void dispose() {
    _vue.dispose();
    super.dispose();
  }

  void _surDebut(ScaleStartDetails d) {
    _dernierFocal = d.localFocalPoint;
    _derniereEchelle = 1;
    final m = _vue.versMaths(d.localFocalPoint, _taille);
    _dernierMaths = m;
    final unDoigt = d.pointerCount == 1;
    _depart = unDoigt && _construit ? d.localFocalPoint : null;
    _attrape = unDoigt ? _atelier.pointLibreProche(m.x, m.y, _tolerance) : null;
    _glisse = unDoigt && _attrape == null
        ? _atelier.objetAGlisser(m.x, m.y, _tolerance)
        : null;
  }

  void _surGeste(ScaleUpdateDetails d) {
    final m = _vue.versMaths(d.localFocalPoint, _taille);
    if (d.pointerCount == 1) {
      final (attrape, glisse) = (_attrape, _glisse);
      if (attrape != null) {
        _atelier.deplacer(attrape, m.x, m.y);
        return;
      }
      if (glisse != null) {
        final avant = _dernierMaths;
        _atelier.translater(glisse, m.x - avant.x, m.y - avant.y);
        _dernierMaths = m;
        return;
      }
      final depart = _depart;
      if (depart != null) {
        // Glisser construit : le départ vaut un toucher, le lever en vaut un
        // autre, et on voit le résultat en attendant.
        if (_doigt == null && _atelier.choisis.isEmpty) {
          final p = _vue.versMaths(depart, _taille);
          _atelier.toucher(p.x, p.y, _tolerance);
        }
        setState(() => _doigt = d.localFocalPoint);
        return;
      }
    } else {
      _depart = null;
      if (_doigt != null) setState(() => _doigt = null);
    }
    _vue.glisser(d.localFocalPoint - _dernierFocal);
    if (d.scale != _derniereEchelle) {
      _vue.zoomer(d.scale / _derniereEchelle, d.localFocalPoint, _taille);
    }
    _dernierFocal = d.localFocalPoint;
    _derniereEchelle = d.scale;
  }

  void _surFin(ScaleEndDetails d) {
    final doigt = _doigt;
    _attrape = null;
    _glisse = null;
    _depart = null;
    _atelier.terminerGeste();
    if (doigt != null) {
      setState(() => _doigt = null);
      _toucher(doigt);
    }
  }

  void _toucher(Offset ecran) {
    final m = _vue.versMaths(ecran, _taille);
    _atelier.toucher(m.x, m.y, _tolerance);
    unawaited(_apresToucher());
  }

  /// Ce qu'un toucher peut demander ensuite : un nombre, ou lire un constat.
  Future<void> _apresToucher() async {
    final l10n = context.l10n;
    final atelier = _atelier;
    final demande = atelier.nombreAttendu;
    if (demande != null) {
      final titre = switch (demande) {
        NombreDemande.rayon => l10n.nombreRayon,
        NombreDemande.angle => l10n.nombreAngle,
        NombreDemande.rapport => l10n.nombreRapport,
        NombreDemande.cotes => l10n.nombreCotes,
      };
      final donne = await demanderNombre(
        context,
        atelier,
        titre,
        entier: demande == NombreDemande.cotes,
      );
      final (valeur, objet) = (donne?.valeur, donne?.objet);
      if (objet != null) {
        atelier.donnerNombre(objet);
      } else if (valeur != null) {
        atelier.donnerValeur(valeur);
      } else {
        atelier.renoncerAuNombre();
      }
    }
    final constat = atelier.prendreConstat();
    if (constat != null && mounted) await _montrerConstat(constat);
  }

  Future<void> _montrerConstat(ConstatRelation constat) {
    final l10n = context.l10n;
    final figure = _atelier.figure;
    String phrase(RelationGeo r) => switch (r) {
      RelationGeo.confondus => l10n.relationConfondus,
      RelationGeo.paralleles => l10n.relationParalleles,
      RelationGeo.perpendiculaires => l10n.relationPerpendiculaires,
      RelationGeo.memeLongueur => l10n.relationMemeLongueur,
      RelationGeo.appartient => l10n.relationAppartient,
      RelationGeo.tangents => l10n.relationTangents,
      RelationGeo.concentriques => l10n.relationConcentriques,
    };
    return showDialog<void>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text(
          l10n.relationTitre(figure.nom(constat.a), figure.nom(constat.b)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constat.constats.isEmpty) Text(l10n.relationAucune),
              for (final c in constat.constats)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppEspacement.sm),
                  child: Text(
                    [
                      phrase(c.relation),
                      if (c.resiste)
                        l10n.relationResiste(positionsEssayees)
                      else
                        l10n.relationIciSeulement,
                    ].join(' '),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(contexte).pop(),
            child: Text(l10n.fermer),
          ),
        ],
      ),
    );
  }

  Future<void> _feuille(WidgetBuilder contenu) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (contexte) => SizedBox(
        height: MediaQuery.sizeOf(contexte).height * 0.75,
        child: contenu(contexte),
      ),
    );
  }

  Future<void> _ouvrirOutils() {
    final centre = _taille.center(Offset.zero);
    return _feuille(
      (contexte) => PanneauOutils(
        atelier: _atelier,
        surOutil: (outil) {
          Navigator.of(contexte).pop();
          if (outil == OutilGeo.curseur) {
            unawaited(_creerCurseur());
          } else {
            _atelier.outil = outil;
          }
        },
        surZoomPlus: () => _vue.zoomer(1.5, centre, _taille),
        surZoomMoins: () => _vue.zoomer(1 / 1.5, centre, _taille),
        surRecentrer: _vue.recentrer,
      ),
    );
  }

  Future<void> _creerCurseur() async {
    final atelier = _atelier;
    final donne = await demanderNombre(
      context,
      atelier,
      context.l10n.nombreCurseur,
      initiale: 1,
    );
    final valeur = donne?.valeur;
    if (valeur != null) atelier.ajouterCurseur(valeur);
  }

  Future<void> _ouvrirObjets() => _feuille(
    (contexte) => PanneauObjets(
      atelier: _atelier,
      surObjet: (id) {
        Navigator.of(contexte).pop();
        unawaited(_ouvrirProprietes(id));
      },
    ),
  );

  Future<void> _ouvrirProprietes(int id) {
    final support = PorteeReglages.de(context).support;
    final l10n = context.l10n;
    return _feuille(
      (contexte) => PanneauProprietes(
        atelier: _atelier,
        id: id,
        couleurs: support.stylos,
        nomsCouleurs: support == SupportEcriture.tableauNoir
            ? [
                l10n.styloCraieBlanche,
                l10n.styloCraieJaune,
                l10n.styloCraieBleue,
                l10n.styloCraieRose,
              ]
            : [l10n.styloBleu, l10n.styloNoir, l10n.styloRouge, l10n.styloVert],
      ),
    );
  }

  ButtonStyle get _flottant => IconButton.styleFrom(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    elevation: 2,
  );

  @override
  Widget build(BuildContext context) {
    final reglages = PorteeReglages.de(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final atelier = _atelier;
    final francais = Localizations.localeOf(context).languageCode == 'fr';
    return ListenableBuilder(
      listenable: Listenable.merge([atelier, _vue]),
      builder: (context, _) {
        final pas = pasDeGraduation(_vue.unite);
        atelier.reglerAimant(pas, _rayonAimant / _vue.unite);
        final doigt = _doigt;
        final doigtMaths = doigt == null
            ? null
            : _vue.versMaths(doigt, _taille);
        final selection = atelier.selection;
        return Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, contraintes) {
                _taille = contraintes.biggest;
                return Semantics(
                  label: atelier.estVide
                      ? l10n.geometrieVide
                      : l10n.geometrieDescription(atelier.figure.objets.length),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _surDebut,
                    onScaleUpdate: _surGeste,
                    onScaleEnd: _surFin,
                    onTapUp: (d) => _toucher(d.localPosition),
                    onLongPressStart: (d) {
                      final m = _vue.versMaths(d.localPosition, _taille);
                      final id = atelier.objetProche(m.x, m.y, _tolerance);
                      if (id != null) unawaited(_ouvrirProprietes(id));
                    },
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: PeintreFigure(
                        atelier: atelier,
                        vue: _vue,
                        fond: reglages.support.fond,
                        grille: theme.colorScheme.outlineVariant,
                        palette: reglages.support.stylos,
                        choix: theme.colorScheme.tertiary,
                        francais: francais,
                        texte: theme.textTheme.titleSmall!.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        doigt: doigt,
                        apercu: doigtMaths == null
                            ? null
                            : atelier.apercu(doigtMaths.x, doigtMaths.y),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (atelier.estVide && atelier.outil == OutilGeo.deplacer)
              IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppEspacement.lg),
                    child: Text(
                      l10n.geometrieVide,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            // Ce qui se passe, à droite de ← et de Menu.
            Positioned(
              left: 112,
              right: AppEspacement.sm,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppEspacement.sm),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: selection != null
                        ? _BandeauSelection(
                            atelier: atelier,
                            id: selection,
                            surModifier: () =>
                                unawaited(_ouvrirProprietes(selection)),
                          )
                        : _construit
                        ? _BandeauOutil(atelier: atelier)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            if (atelier.curseurs.isNotEmpty)
              Positioned(
                left: AppEspacement.sm,
                bottom: 64,
                child: SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final id in atelier.curseurs)
                            _BarreCurseur(
                              key: ValueKey(id),
                              atelier: atelier,
                              id: id,
                              surModifier: () =>
                                  unawaited(_ouvrirProprietes(id)),
                            ),
                        ],
                      ),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        style: _flottant,
                        icon: const Icon(Icons.undo),
                        tooltip: l10n.annuler,
                        onPressed: atelier.peutAnnuler ? atelier.annuler : null,
                      ),
                      IconButton(
                        style: _flottant,
                        icon: const Icon(Icons.redo),
                        tooltip: l10n.refaire,
                        onPressed: atelier.peutRetablir
                            ? atelier.retablir
                            : null,
                      ),
                      IconButton(
                        style: _flottant,
                        icon: const Icon(Icons.format_list_bulleted),
                        tooltip: l10n.objets,
                        onPressed: () => unawaited(_ouvrirObjets()),
                      ),
                      const SizedBox(width: AppEspacement.xxs),
                      FloatingActionButton.extended(
                        heroTag: null,
                        elevation: 2,
                        onPressed: () => unawaited(_ouvrirOutils()),
                        icon: Pictogramme(atelier.outil, taille: 24),
                        label: Text(l10n.outils),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// L'outil en main et ce qu'il attend : on sait toujours où on en est.
class _BandeauOutil extends StatelessWidget {
  const new({required this.atelier});

  final Atelier atelier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final outil = atelier.outil;
    final etapes = outil.etapes;
    final etape = etapes == null || etapes < 2
        ? ''
        : ' · ${atelier.choisis.length + 1}/$etapes';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.only(left: AppEspacement.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pictogramme(outil, taille: 28),
            const SizedBox(width: AppEspacement.sm),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${outil.libelle(l10n)}$etape',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(outil.aide(l10n), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.terminerOutil,
              onPressed: () => atelier.outil = OutilGeo.deplacer,
            ),
          ],
        ),
      ),
    );
  }
}

class _BandeauSelection extends StatelessWidget {
  const new({
    required this.atelier,
    required this.id,
    required this.surModifier,
  });

  final Atelier atelier;
  final int id;
  final VoidCallback surModifier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final francais = Localizations.localeOf(context).languageCode == 'fr';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.only(left: AppEspacement.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titreObjet(atelier, id, francais: francais),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      decrireObjet(atelier, id, l10n),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: l10n.modifierObjet,
              onPressed: surModifier,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.fermer,
              onPressed: atelier.deselectionner,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un curseur : son nom, sa valeur, sa barre, et de quoi l'animer.
class _BarreCurseur extends StatefulWidget {
  const new({
    required this.atelier,
    required this.id,
    required this.surModifier,
    super.key,
  });

  final Atelier atelier;
  final int id;
  final VoidCallback surModifier;

  @override
  State<_BarreCurseur> createState() => _BarreCurseurState();
}

class _BarreCurseurState extends State<_BarreCurseur>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_avancer);
  Duration _precedent = Duration.zero;
  var _sens = 1;

  void _avancer(Duration temps) {
    final n = widget.atelier.figure.definition(widget.id) as NombreLibre;
    final ecoule = (temps - _precedent).inMicroseconds / 1e6;
    _precedent = temps;
    // Un aller en quatre secondes, quelle que soit la largeur du curseur.
    var v = n.valeur + _sens * ecoule * (n.max - n.min) / 4;
    if (v >= n.max || v <= n.min) {
      v = v.clamp(n.min, n.max);
      _sens = -_sens;
    }
    widget.atelier.fixerNombre(widget.id, v);
  }

  void _basculer() {
    if (_ticker.isActive) {
      _ticker.stop();
      widget.atelier.terminerGeste();
    } else {
      _precedent = Duration.zero;
      _ticker.start();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final francais = Localizations.localeOf(context).languageCode == 'fr';
    final atelier = widget.atelier;
    final figure = atelier.figure;
    if (!figure.objets.contains(widget.id)) return const SizedBox.shrink();
    final n = figure.definition(widget.id) as NombreLibre;
    final valeur = texteValeur(n.valeur, virgule: francais);
    final texte = '${figure.nom(widget.id)} = $valeur';
    return Card(
      margin: const EdgeInsets.only(bottom: AppEspacement.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: widget.surModifier, child: Text(texte)),
          SizedBox(
            width: 120,
            child: Slider(
              value: n.valeur.clamp(n.min, n.max),
              min: n.min,
              max: n.max,
              semanticFormatterCallback: (_) => texte,
              onChanged: (v) => atelier.fixerNombre(widget.id, v),
              onChangeEnd: (_) => atelier.terminerGeste(),
            ),
          ),
          IconButton(
            icon: Icon(_ticker.isActive ? Icons.pause : Icons.play_arrow),
            tooltip: _ticker.isActive ? l10n.arreter : l10n.animer,
            onPressed: _basculer,
          ),
        ],
      ),
    );
  }
}
