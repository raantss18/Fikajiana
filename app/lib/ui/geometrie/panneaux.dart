import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/geometrie/ecriture_geo.dart';
import 'package:fikajiana/graphe/vue_graphe.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/export.dart';
import 'package:fikajiana/ui/geometrie/pictogrammes.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

extension LibellesOutil on OutilGeo {
  String libelle(AppLocalizations l10n) => switch (this) {
    OutilGeo.deplacer => l10n.outilDeplacer,
    OutilGeo.gomme => l10n.outilGomme,
    OutilGeo.mainLevee => l10n.outilMainLevee,
    OutilGeo.point => l10n.outilPoint,
    OutilGeo.milieu => l10n.outilMilieu,
    OutilGeo.intersection => l10n.outilIntersection,
    OutilGeo.centre => l10n.outilCentre,
    OutilGeo.centreGravite => l10n.outilCentreGravite,
    OutilGeo.segment => l10n.outilSegment,
    OutilGeo.droite => l10n.outilDroite,
    OutilGeo.demiDroite => l10n.outilDemiDroite,
    OutilGeo.vecteur => l10n.outilVecteur,
    OutilGeo.parallele => l10n.outilParallele,
    OutilGeo.perpendiculaire => l10n.outilPerpendiculaire,
    OutilGeo.mediatrice => l10n.outilMediatrice,
    OutilGeo.bissectrice => l10n.outilBissectrice,
    OutilGeo.tangente => l10n.outilTangente,
    OutilGeo.cercle => l10n.outilCercle,
    OutilGeo.cercleRayon => l10n.outilCercleRayon,
    OutilGeo.cercleTroisPoints => l10n.outilCercleTroisPoints,
    OutilGeo.arc => l10n.outilArc,
    OutilGeo.arcTroisPoints => l10n.outilArcTroisPoints,
    OutilGeo.demiCercle => l10n.outilDemiCercle,
    OutilGeo.polygone => l10n.outilPolygone,
    OutilGeo.polygoneRegulier => l10n.outilPolygoneRegulier,
    OutilGeo.ellipse => l10n.outilEllipse,
    OutilGeo.hyperbole => l10n.outilHyperbole,
    OutilGeo.parabole => l10n.outilParabole,
    OutilGeo.coniqueCinqPoints => l10n.outilConiqueCinqPoints,
    OutilGeo.symetrieCentrale => l10n.outilSymetrieCentrale,
    OutilGeo.symetrieAxiale => l10n.outilSymetrieAxiale,
    OutilGeo.translation => l10n.outilTranslation,
    OutilGeo.rotation => l10n.outilRotation,
    OutilGeo.homothetie => l10n.outilHomothetie,
    OutilGeo.longueur => l10n.outilLongueur,
    OutilGeo.angle => l10n.outilAngle,
    OutilGeo.aire => l10n.outilAire,
    OutilGeo.pente => l10n.outilPente,
    OutilGeo.curseur => l10n.outilCurseur,
    OutilGeo.lieu => l10n.outilLieu,
    OutilGeo.relation => l10n.outilRelation,
  };

  String aide(AppLocalizations l10n) => switch (this) {
    OutilGeo.deplacer || OutilGeo.curseur => l10n.aideDeplacer,
    OutilGeo.gomme => l10n.aideGomme,
    OutilGeo.mainLevee => l10n.aideMainLevee,
    OutilGeo.point => l10n.aidePoint,
    OutilGeo.milieu => l10n.aideMilieu,
    OutilGeo.intersection => l10n.aideIntersection,
    OutilGeo.centre => l10n.aideCentre,
    OutilGeo.centreGravite => l10n.aideCentreGravite,
    OutilGeo.segment || OutilGeo.droite => l10n.aideDeuxPoints,
    OutilGeo.demiDroite => l10n.aideDemiDroite,
    OutilGeo.vecteur => l10n.aideVecteur,
    OutilGeo.parallele || OutilGeo.perpendiculaire => l10n.aideParDroite,
    OutilGeo.mediatrice => l10n.aideMediatrice,
    OutilGeo.bissectrice => l10n.aideBissectrice,
    OutilGeo.tangente => l10n.aideTangente,
    OutilGeo.cercle => l10n.aideCercle,
    OutilGeo.cercleRayon => l10n.aideCercleRayon,
    OutilGeo.cercleTroisPoints => l10n.aideTroisPoints,
    OutilGeo.arc => l10n.aideArc,
    OutilGeo.arcTroisPoints => l10n.aideArcTroisPoints,
    OutilGeo.demiCercle => l10n.aideDemiCercle,
    OutilGeo.polygone => l10n.aidePolygone,
    OutilGeo.polygoneRegulier => l10n.aidePolygoneRegulier,
    OutilGeo.ellipse || OutilGeo.hyperbole => l10n.aideFoyers,
    OutilGeo.parabole => l10n.aideParabole,
    OutilGeo.coniqueCinqPoints => l10n.aideCinqPoints,
    OutilGeo.symetrieCentrale => l10n.aideSymetrieCentrale,
    OutilGeo.symetrieAxiale => l10n.aideSymetrieAxiale,
    OutilGeo.translation => l10n.aideTranslation,
    OutilGeo.rotation => l10n.aideRotation,
    OutilGeo.homothetie => l10n.aideHomothetie,
    OutilGeo.longueur => l10n.aideLongueur,
    OutilGeo.angle => l10n.aideAngle,
    OutilGeo.aire => l10n.aideAire,
    OutilGeo.pente => l10n.aidePente,
    OutilGeo.lieu => l10n.aideLieu,
    OutilGeo.relation => l10n.aideRelation,
  };
}

/// Le nom d'une famille d'outils, repris par le Guide.
String titreGroupe(GroupeOutils groupe, AppLocalizations l10n) =>
    switch (groupe) {
      GroupeOutils.base => l10n.groupeBase,
      GroupeOutils.points => l10n.groupePoints,
      GroupeOutils.lignes => l10n.groupeLignes,
      GroupeOutils.cercles => l10n.groupeCercles,
      GroupeOutils.polygones => l10n.groupePolygones,
      GroupeOutils.coniques => l10n.groupeConiques,
      GroupeOutils.transformations => l10n.groupeTransformations,
      GroupeOutils.mesures => l10n.groupeMesures,
      GroupeOutils.avance => l10n.groupeAvance,
    };

/// La boîte à outils : chaque outil dit son nom, et montre ce qu'il fait.
class PanneauOutils extends StatelessWidget {
  const new({
    required this.atelier,
    required this.surOutil,
    required this.surZoomPlus,
    required this.surZoomMoins,
    required this.surRecentrer,
    required this.surExporter,
    this.enTete = const [],
    this.peutExporter,
    super.key,
  });

  /// Ce qui passe avant les outils : les courbes de la Figure.
  final List<Widget> enTete;

  /// Il y a de quoi exporter, courbes comprises.
  final bool? peutExporter;
  final ValueChanged<FormatExport> surExporter;
  final Atelier atelier;
  final ValueChanged<OutilGeo> surOutil;
  final VoidCallback surZoomPlus;
  final VoidCallback surZoomMoins;
  final VoidCallback? surRecentrer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget titre(String t) => Padding(
      padding: const EdgeInsets.only(
        top: AppEspacement.md,
        bottom: AppEspacement.xxs,
      ),
      child: Semantics(
        header: true,
        child: Text(t, style: theme.textTheme.titleSmall),
      ),
    );
    return ListenableBuilder(
      listenable: atelier,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppEspacement.md,
          vertical: AppEspacement.sm,
        ),
        children: [
          ...enTete,
          for (final groupe in GroupeOutils.values) ...[
            titre(titreGroupe(groupe, l10n)),
            LayoutBuilder(
              builder: (context, contraintes) {
                // Autant de colonnes que possible, et toute la largeur prise :
                // un nom long doit tenir sans être coupé.
                final colonnes = (contraintes.maxWidth / 104).floor().clamp(
                  3,
                  8,
                );
                final largeur =
                    (contraintes.maxWidth -
                        AppEspacement.xxs * (colonnes - 1)) /
                    colonnes;
                return Wrap(
                  spacing: AppEspacement.xxs,
                  runSpacing: AppEspacement.xxs,
                  children: [
                    for (final outil in OutilGeo.values)
                      if (outil.groupe == groupe)
                        _TuileOutil(
                          outil: outil,
                          largeur: largeur,
                          choisi: atelier.outil == outil,
                          surToucher: () => surOutil(outil),
                        ),
                  ],
                );
              },
            ),
          ],
          titre(l10n.groupeAffichage),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.affichageGrille),
            value: atelier.grille,
            onChanged: (v) => atelier.grille = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.affichageAxes),
            value: atelier.axes,
            onChanged: (v) => atelier.axes = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.affichageAimant),
            value: atelier.aimant,
            onChanged: (v) => atelier.aimant = v,
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.zoom_in),
                tooltip: l10n.zoomPlus,
                onPressed: surZoomPlus,
              ),
              IconButton(
                icon: const Icon(Icons.zoom_out),
                tooltip: l10n.zoomMoins,
                onPressed: surZoomMoins,
              ),
              IconButton(
                icon: const Icon(Icons.fit_screen_outlined),
                tooltip: l10n.recentrer,
                onPressed: surRecentrer,
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.effacerTout),
                onPressed: atelier.estVide ? null : atelier.effacer,
              ),
            ],
          ),
          titre(l10n.exportTitre),
          ...lignesExport(
            context,
            actif: peutExporter ?? !atelier.estVide,
            surChoix: surExporter,
          ),
        ],
      ),
    );
  }
}

class _TuileOutil extends StatelessWidget {
  const new({
    required this.outil,
    required this.largeur,
    required this.choisi,
    required this.surToucher,
  });

  final OutilGeo outil;
  final double largeur;
  final bool choisi;
  final VoidCallback surToucher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: choisi,
      button: true,
      child: Material(
        color: choisi
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: surToucher,
          child: SizedBox(
            width: largeur,
            height: 88,
            child: Padding(
              padding: const EdgeInsets.all(AppEspacement.xxs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Pictogramme(outil),
                  const SizedBox(height: AppEspacement.xxs),
                  Text(
                    outil.libelle(context.l10n),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une phrase qui dit comment l'objet est construit.
String decrireObjet(Atelier atelier, int id, AppLocalizations l10n) {
  final figure = atelier.figure;
  final d = figure.definition(id);
  String noms(Iterable<int> ids) => ids.map(figure.nom).join(', ');
  return switch (d) {
    PointLibre() => l10n.descPointLibre,
    NombreLibre() => l10n.descCurseur,
    PointSur() => '${l10n.outilPoint} : ${figure.nom(d.support)}',
    Lieu() => '${l10n.outilLieu} : ${noms(d.parents)}',
    final Construite c => '${_nomGenre(c.genre, l10n)} : ${noms(c.parents)}',
  };
}

String _nomGenre(GenreConstruction g, AppLocalizations l10n) => switch (g) {
  GenreConstruction.milieu => l10n.outilMilieu,
  GenreConstruction.droite => l10n.outilDroite,
  GenreConstruction.segment => l10n.outilSegment,
  GenreConstruction.demiDroite => l10n.outilDemiDroite,
  GenreConstruction.vecteur => l10n.outilVecteur,
  GenreConstruction.cercle => l10n.outilCercle,
  GenreConstruction.cercleRayon => l10n.outilCercleRayon,
  GenreConstruction.cercleTroisPoints => l10n.outilCercleTroisPoints,
  GenreConstruction.arc => l10n.outilArc,
  GenreConstruction.arcTroisPoints => l10n.outilArcTroisPoints,
  GenreConstruction.demiCercle => l10n.outilDemiCercle,
  GenreConstruction.parallele => l10n.outilParallele,
  GenreConstruction.perpendiculaire => l10n.outilPerpendiculaire,
  GenreConstruction.mediatrice => l10n.outilMediatrice,
  GenreConstruction.bissectrice => l10n.outilBissectrice,
  GenreConstruction.tangente1 ||
  GenreConstruction.tangente2 => l10n.outilTangente,
  GenreConstruction.intersection1 ||
  GenreConstruction.intersection2 ||
  GenreConstruction.intersection3 ||
  GenreConstruction.intersection4 => l10n.outilIntersection,
  GenreConstruction.centre => l10n.outilCentre,
  GenreConstruction.centreGravite => l10n.outilCentreGravite,
  GenreConstruction.polygone => l10n.outilPolygone,
  GenreConstruction.polygoneRegulier => l10n.outilPolygoneRegulier,
  GenreConstruction.sommet => l10n.descSommet,
  GenreConstruction.ellipse => l10n.outilEllipse,
  GenreConstruction.hyperbole => l10n.outilHyperbole,
  GenreConstruction.parabole => l10n.outilParabole,
  GenreConstruction.coniqueCinqPoints => l10n.outilConiqueCinqPoints,
  GenreConstruction.symetrieCentrale => l10n.outilSymetrieCentrale,
  GenreConstruction.symetrieAxiale => l10n.outilSymetrieAxiale,
  GenreConstruction.translation => l10n.outilTranslation,
  GenreConstruction.rotation => l10n.outilRotation,
  GenreConstruction.homothetie => l10n.outilHomothetie,
  GenreConstruction.longueur ||
  GenreConstruction.distance => l10n.outilLongueur,
  GenreConstruction.angle => l10n.outilAngle,
  GenreConstruction.aire => l10n.outilAire,
  GenreConstruction.pente => l10n.outilPente,
};

/// `d : y = 2x + 1`, ou le nom seul.
String titreObjet(Atelier atelier, int id, {required bool francais}) {
  final nom = atelier.figure.nom(id);
  final valeur = ecrireForme(atelier.formes[id], francais: francais);
  return valeur == null ? nom : '$nom : $valeur';
}

/// La liste des objets : tout ce qui est dessiné, en toutes lettres.
class PanneauObjets extends StatelessWidget {
  const new({
    required this.atelier,
    required this.surObjet,
    this.courbes = const [],
    this.surCourbe,
    super.key,
  });

  final Atelier atelier;
  final ValueChanged<int> surObjet;

  /// Les courbes de la Figure, en tête, comme les autres objets : numéro,
  /// formule et couleur (jamais la couleur seule).
  final List<({String latex, String nom, Color couleur})> courbes;

  /// Toucher une courbe : la modifier.
  final ValueChanged<int>? surCourbe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final francais = Localizations.localeOf(context).languageCode == 'fr';
    return ListenableBuilder(
      listenable: atelier,
      builder: (context, _) {
        final objets = atelier.figure.objets.toList();
        if (objets.isEmpty && courbes.isEmpty) {
          return Center(child: Text(l10n.objetsVide));
        }
        final enTete = courbes.length;
        final style = Theme.of(context).textTheme.bodyLarge;
        return ListView.builder(
          itemCount: objets.length + enTete,
          itemBuilder: (context, i) {
            if (i < enTete) {
              // Même ligne que les autres objets (Antsa) : nom, formule,
              // genre dessous.
              final courbe = courbes[i];
              return ListTile(
                title: Row(
                  children: [
                    Text(
                      '${courbe.nom} : ',
                      style: style?.copyWith(color: courbe.couleur),
                    ),
                    Flexible(
                      child: Math.tex(
                        courbe.latex,
                        textStyle: style,
                        onErrorFallback: (_) =>
                            Text(courbe.latex, style: style),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(l10n.objetCourbe),
                onTap: () => surCourbe?.call(i),
              );
            }
            final id = objets[i - enTete];
            final visible = atelier.figure.apparence(id).visible;
            return ListTile(
              title: Text(titreObjet(atelier, id, francais: francais)),
              subtitle: Text(decrireObjet(atelier, id, l10n)),
              onTap: () => surObjet(id),
              trailing: IconButton(
                icon: Icon(
                  visible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: visible ? l10n.masquer : l10n.afficher,
                onPressed: () =>
                    atelier.modifierApparence(id, (a) => a.visible = !visible),
              ),
            );
          },
        );
      },
    );
  }
}

/// Lit `2,5` ou `pi/3` ; `null` si ce n'est pas un nombre.
double? lireNombre(String texte) {
  try {
    final v = compilerFonction(
      texte.trim().replaceAll(',', '.'),
      variable: '_',
    )(0);
    return v.isFinite ? v : null;
  } on ErreurEvaluation {
    return null;
  }
}

/// Le nombre donné : une valeur, ou un nombre de la figure.
typedef NombreDonne = ({double? valeur, int? objet});

/// Demande un nombre. `null` si on renonce.
Future<NombreDonne?> demanderNombre(
  BuildContext context,
  Atelier atelier,
  String titre, {
  bool entier = false,
  double? initiale,
}) {
  return showDialog<NombreDonne>(
    context: context,
    builder: (_) => _DialogueNombre(
      atelier: atelier,
      titre: titre,
      entier: entier,
      initiale: initiale,
    ),
  );
}

class _DialogueNombre extends StatefulWidget {
  const new({
    required this.atelier,
    required this.titre,
    required this.entier,
    this.initiale,
  });

  final Atelier atelier;
  final String titre;
  final bool entier;
  final double? initiale;

  @override
  State<_DialogueNombre> createState() => _DialogueNombreState();
}

class _DialogueNombreState extends State<_DialogueNombre> {
  late final _champ = TextEditingController(
    text: widget.initiale == null
        ? ''
        : texteValeur(widget.initiale!, virgule: false),
  );
  String? _erreur;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  void _valider() {
    final l10n = context.l10n;
    final v = lireNombre(_champ.text);
    if (widget.entier) {
      if (v == null || v != v.roundToDouble() || v < 3 || v > 100) {
        setState(() => _erreur = l10n.nombreCotesInvalide);
        return;
      }
    } else if (v == null) {
      setState(() => _erreur = l10n.nombreInvalide);
      return;
    }
    Navigator.of(context).pop<NombreDonne>((valeur: v, objet: null));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final francais = Localizations.localeOf(context).languageCode == 'fr';
    final nombres = widget.entier ? const <int>[] : widget.atelier.nombres;
    return AlertDialog(
      title: Text(widget.titre),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _champ,
              autofocus: true,
              decoration: InputDecoration(
                helperText: widget.entier ? null : l10n.nombreAide,
                helperMaxLines: 3,
                errorText: _erreur,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _valider(),
            ),
            if (nombres.isNotEmpty) ...[
              const SizedBox(height: AppEspacement.sm),
              Wrap(
                spacing: AppEspacement.sm,
                children: [
                  for (final id in nombres)
                    ActionChip(
                      label: Text(
                        titreObjet(widget.atelier, id, francais: francais),
                      ),
                      onPressed: () =>
                          Navigator.of(context)
                              .pop<NombreDonne>((valeur: null, objet: id)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.annulerDialogue),
        ),
        FilledButton(onPressed: _valider, child: Text(l10n.appliquer)),
      ],
    );
  }
}

/// Ce qu'on peut changer d'un objet : y compris ses coordonnées, pour qui ne
/// peut pas glisser (WCAG 2.2, critère 2.5.7).
class PanneauProprietes extends StatefulWidget {
  const new({
    required this.atelier,
    required this.id,
    required this.couleurs,
    required this.nomsCouleurs,
    super.key,
  });

  final Atelier atelier;
  final int id;
  final List<Color> couleurs;
  final List<String> nomsCouleurs;

  @override
  State<PanneauProprietes> createState() => _PanneauProprietesState();
}

class _PanneauProprietesState extends State<PanneauProprietes> {
  Atelier get _atelier => widget.atelier;
  late final _nom = TextEditingController(text: _atelier.figure.nom(widget.id));
  final _champs = <String, TextEditingController>{};
  String? _erreurNom;

  TextEditingController _champ(String cle, double valeur) =>
      _champs.putIfAbsent(
        cle,
        () => TextEditingController(text: texteValeur(valeur, virgule: false)),
      );

  @override
  void dispose() {
    _nom.dispose();
    for (final c in _champs.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _renommer() {
    final fait = _atelier.renommer(widget.id, _nom.text);
    setState(() => _erreurNom = fait ? null : context.l10n.proprieteNomPris);
  }

  void _appliquerPoint() {
    final x = lireNombre(_champs['x']!.text);
    final y = lireNombre(_champs['y']!.text);
    if (x != null && y != null) _atelier.placer(widget.id, x, y);
  }

  void _appliquerCurseur() {
    final v = lireNombre(_champs['v']!.text);
    final min = lireNombre(_champs['min']!.text);
    final max = lireNombre(_champs['max']!.text);
    if (min != null && max != null) _atelier.bornerCurseur(widget.id, min, max);
    if (v != null) {
      _atelier
        ..fixerNombre(widget.id, v)
        ..terminerGeste();
    }
  }

  Widget _champNombre(
    String cle,
    String libelle,
    double valeur,
    VoidCallback surFini,
  ) => Expanded(
    child: TextField(
      controller: _champ(cle, valeur),
      decoration: InputDecoration(labelText: libelle),
      onSubmitted: (_) => surFini(),
      onEditingComplete: surFini,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final francais = Localizations.localeOf(context).languageCode == 'fr';
    return ListenableBuilder(
      listenable: _atelier,
      builder: (context, _) {
        if (!_atelier.figure.objets.contains(widget.id)) {
          return const SizedBox.shrink();
        }
        final apparence = _atelier.figure.apparence(widget.id);
        final definition = _atelier.figure.definition(widget.id);
        final valeur = ecrireForme(
          _atelier.formes[widget.id],
          francais: francais,
        );
        return ListView(
          padding: const EdgeInsets.all(AppEspacement.md),
          children: [
            Semantics(
              header: true,
              child: Text(l10n.proprietes, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppEspacement.xxs),
            Text(decrireObjet(_atelier, widget.id, l10n)),
            if (valeur != null) Text(valeur, style: theme.textTheme.bodyLarge),
            TextField(
              controller: _nom,
              decoration: InputDecoration(
                labelText: l10n.proprieteNom,
                errorText: _erreurNom,
              ),
              onSubmitted: (_) => _renommer(),
              onEditingComplete: _renommer,
            ),
            if (definition is PointLibre)
              Row(
                children: [
                  _champNombre('x', 'x', definition.x, _appliquerPoint),
                  const SizedBox(width: AppEspacement.md),
                  _champNombre('y', 'y', definition.y, _appliquerPoint),
                ],
              ),
            if (definition is NombreLibre)
              Row(
                children: [
                  _champNombre(
                    'v',
                    l10n.proprieteValeur,
                    definition.valeur,
                    _appliquerCurseur,
                  ),
                  const SizedBox(width: AppEspacement.md),
                  _champNombre(
                    'min',
                    l10n.proprieteMin,
                    definition.min,
                    _appliquerCurseur,
                  ),
                  const SizedBox(width: AppEspacement.md),
                  _champNombre(
                    'max',
                    l10n.proprieteMax,
                    definition.max,
                    _appliquerCurseur,
                  ),
                ],
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.proprieteVisible),
              value: apparence.visible,
              onChanged: (v) =>
                  _atelier.modifierApparence(widget.id, (a) => a.visible = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.proprieteNomVisible),
              value: apparence.nomVisible,
              onChanged: (v) => _atelier.modifierApparence(
                widget.id,
                (a) => a.nomVisible = v,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.proprietePointille),
              value: apparence.pointille,
              onChanged: (v) =>
                  _atelier.modifierApparence(widget.id, (a) => a.pointille = v),
            ),
            Text(l10n.proprieteCouleur, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppEspacement.xxs),
            Wrap(
              spacing: AppEspacement.sm,
              runSpacing: AppEspacement.xxs,
              children: [
                ChoiceChip(
                  label: Text(l10n.couleurAuto),
                  selected: apparence.couleur == null,
                  onSelected: (_) => _atelier.modifierApparence(
                    widget.id,
                    (a) => a.couleur = null,
                  ),
                ),
                for (var i = 0; i < widget.couleurs.length; i++)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: widget.couleurs[i]),
                    label: Text(widget.nomsCouleurs[i]),
                    selected: apparence.couleur == i,
                    onSelected: (_) => _atelier.modifierApparence(
                      widget.id,
                      (a) => a.couleur = i,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppEspacement.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.retirer),
                  onPressed: () {
                    _atelier.retirer(widget.id);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: AppEspacement.sm),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.fermer),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
