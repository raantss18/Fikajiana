import 'dart:async';
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/comprendre/fraction_ecrite.dart';
import 'package:fikajiana/comprendre/solutions.dart';
import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:fikajiana/reconnaissance/pix2text.dart' show normaliserLatex;
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/foundation.dart';

enum EtatBloc {
  lecture,
  calcul,
  fait,

  /// Le LaTeX ne se traduit pas : à corriger.
  nonCompris,

  /// Giac ne donne pas de résultat utilisable.
  sansResultat,
  arrete,
  sansModele,
  erreur,
}

/// Ce que la feuille sait au-dessus d'une ligne.
class _Contexte {
  final definitions = <String, DefinitionFonction>{};
  final points = <String, (double, double)>{};
  final vecteurs = <String, (double, double)>{};
  final valeurs = <String, String>{};

  Analyse analyser(String latex, {bool degres = false}) => analyserLatex(
    latex,
    degres: degres,
    definitions: definitions,
    points: points,
    vecteurs: vecteurs,
    valeurs: valeurs,
  );
}

/// Une expression de la feuille : ses traits, ce qui est compris, son résultat.
class BlocCalcul {
  new({
    required this.cle,
    required this.cadre,
    Set<int>? traits,
    this.latex,
    this.etat = EtatBloc.lecture,
  }) : traits = traits ?? {};

  factory depuisJson(Map<String, dynamic> json) {
    final cle = json['cle'] as String;
    final ids = (json['traits'] as List<dynamic>?)?.cast<int>().toSet();
    return BlocCalcul(
        cle: cle,
        // Les sauvegardes de la 0.1.0 gardaient les traits dans la clé.
        traits:
            ids ??
            (cle.startsWith('saisie-')
                ? <int>{}
                : cle.split(',').map(int.tryParse).nonNulls.toSet()),
        cadre: Rect.fromLTRB(
          (json['g'] as num).toDouble(),
          (json['h'] as num).toDouble(),
          (json['d'] as num).toDouble(),
          (json['b'] as num).toDouble(),
        ),
        latex: json['latex'] as String?,
        etat: EtatBloc.values.asNameMap()[json['etat']] ?? EtatBloc.erreur,
      )
      ..type = TypeExpression.values.asNameMap()[json['type']]
      ..inconnues = (json['inconnues'] as List<dynamic>? ?? const [])
          .cast<String>()
      ..verite = json['verite'] as bool?
      ..resultat = json['resultat'] as String?
      ..approche = json['approche'] as String?
      ..inchange = json['inchange'] as bool? ?? false
      ..hauteurLigne = (json['hl'] as num?)?.toDouble()
      ..demandeResultat = json['dr'] as bool? ?? false
      ..lueParMorceaux = json['lm'] as bool? ?? false
      .._points = json['points'] as int? ?? 0;
  }

  final String cle;
  final Set<int> traits;
  Rect cadre;
  String? latex;
  EtatBloc etat;
  TypeExpression? type;

  /// Ce que Giac a résolu, pour écrire `x = 1`.
  List<String> inconnues = const [];

  /// Réponse à une égalité sans inconnue, comme `2+2=5`.
  bool? verite;

  /// Résultat exact, en LaTeX.
  String? resultat;
  String? approche;

  /// Giac rend l'entrée telle quelle, comme `ln(5)` : l'approchée informe.
  bool inchange = false;

  /// La hauteur de l'écriture avant qu'une fraction ne soit redressée.
  double? hauteurLigne;

  /// Nombre de points lus : un trait prolongé se relit.
  int _points = 0;

  /// Augmente à chaque changement : une lecture périmée est ignorée.
  int _version = 0;

  bool get estSaisie => cle.startsWith('saisie-');

  String? _courbeLue;
  bool _courbeSeule = false;

  /// Une courbe, pas un calcul : elle se trace et Giac n'a rien à résoudre.
  bool get courbeSeule {
    final lu = latex;
    if (lu == null) return false;
    if (_courbeLue != lu) {
      _courbeLue = lu;
      _courbeSeule = estCourbeSeule(lu);
    }
    return _courbeSeule;
  }

  String? _objetLu;
  ObjetLu? _objet;

  /// Un point ou un vecteur déclaré : `A(1;2)`. Il se place en Géométrie.
  ObjetLu? get objet {
    final lu = latex;
    if (lu == null) return null;
    if (_objetLu != lu) {
      _objetLu = lu;
      _objet = lireObjet(lu);
    }
    return _objet;
  }

  /// Lue par morceaux : ce qui a été compris se montre, un chiffre peut être
  /// faux et le résultat avec lui.
  bool lueParMorceaux = false;

  /// Un vecteur calculé peut aussi se placer dans la Figure.
  List<ObjetLu> aPlacer = const [];

  /// Ce que le modèle a aussi pu lire, à proposer à la correction.
  List<String> autresLectures = const [];

  /// `f'(x)` ou `det(…)` : la réponse s'affiche même sans `=`.
  bool demandeResultat = false;

  /// La feuille propose de la tracer.
  bool get seTrace => courbeSeule || type == TypeExpression.fonction;

  bool get finitParEgal => latex?.trimRight().endsWith('=') ?? false;

  /// Un résultat se montre après un `=`, ou sous une équation ou un système.
  /// Une expression sans `=` ne demande rien.
  bool get montreResultat {
    if (etat != EtatBloc.fait || verite != null || courbeSeule) return false;
    return estSaisie || finitParEgal || estResolution || demandeResultat;
  }

  /// Rien d'écrit juste dessous : une solution peut s'y poser.
  bool dessousLibre = true;

  bool get _sousLEcriture => !finitParEgal && dessousLibre;

  /// Une équation ou un système : le résultat n'est pas une valeur à égaler.
  bool get estResolution =>
      type == TypeExpression.equation ||
      type == TypeExpression.systeme ||
      type == TypeExpression.suite;

  /// Ce qu'il faut afficher selon le mode, en LaTeX.
  String? texte({required bool approcheVoulue, required bool virgule}) {
    final exact = resultat;
    // Une valeur que Giac n'a trouvée que numériquement est déjà approchée.
    final longue = exact != null && RegExp(r'\d\.\d{9}').hasMatch(exact);
    final choisie = approcheVoulue || inchange || longue ? approche : null;
    final String? valeur;
    if (estResolution) {
      final brut = choisie == null ? exact : _ensembleApproche(choisie);
      valeur = brut == null
          ? null
          : ecrireSolutions(
              brut,
              type: type!,
              inconnues: inconnues,
              francais: virgule,
            );
    } else {
      valeur = choisie == null ? exact : abregerApproche(choisie);
    }
    if (valeur == null || !virgule) return valeur;
    return valeur.replaceAllMapped(
      RegExp(r'(\d)\.(\d)'),
      (m) => '${m[1]}{,}${m[2]}',
    );
  }

  String? _ecritPour;
  EcritureResultat? _ecrit;

  /// Le résultat tracé à la main, ou `null` s'il se montre autrement.
  EcritureResultat? ecriture({
    required bool approcheVoulue,
    required bool virgule,
  }) {
    if (!montreResultat || estSaisie) return null;
    final valeur = texte(approcheVoulue: approcheVoulue, virgule: virgule);
    if (valeur == null) return null;
    if (_ecritPour != valeur) {
      _ecritPour = valeur;
      _ecrit = ecrireResultat(
        valeur,
        cadre,
        dessous: _sousLEcriture,
        hauteurLigne: hauteurLigne,
      );
    }
    return _ecrit;
  }

  void _oublierResultat() {
    verite = null;
    resultat = null;
    approche = null;
    inchange = false;
    type = null;
    inconnues = const [];
    _ecritPour = null;
    _ecrit = null;
  }

  Map<String, dynamic> versJson() => {
    'cle': cle,
    'traits': traits.toList(),
    'g': cadre.left,
    'h': cadre.top,
    'd': cadre.right,
    'b': cadre.bottom,
    'latex': latex,
    'etat': etat.name,
    'type': type?.name,
    'inconnues': inconnues,
    'verite': verite,
    'resultat': resultat,
    'approche': approche,
    'inchange': inchange,
    'points': _points,
    'hl': ?hauteurLigne,
    if (demandeResultat) 'dr': true,
    if (lueParMorceaux) 'lm': true,
  };
}

/// `list[-1.41421356237,1.41421356237]` de Giac, en LaTeX et abrégé.
String _ensembleApproche(String approche) {
  final valeurs = approche
      .replaceAll(RegExp(r'list\[|\[|\]'), '')
      .split(',')
      .map(abregerApproche);
  return '\\{${valeurs.join(',')}\\}';
}

/// Une valeur approchée courte : assez de chiffres, sans encombrer.
String abregerApproche(String approche) {
  final valeur = double.tryParse(approche.trim());
  if (valeur == null || valeur.abs() >= 1e9) return approche.trim();
  if (valeur != 0 && valeur.abs() < 1e-4) return approche.trim();
  var texte = valeur.toStringAsPrecision(8);
  if (texte.contains('.')) {
    texte = texte
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return texte;
}

/// Lit l'encre à la pause et calcule chaque expression de la feuille.
///
/// **Un bloc lu reste stable** : seul un trait qui le touche, ou un trait écrit
/// juste à sa droite sur la même ligne avant son `=`, le modifie. Un nouveau
/// calcul, même proche, ne l'efface donc jamais.
class CalculFeuille extends ChangeNotifier {
  new({
    required this.encre,
    required this.lecteur,
    required this.moteur,
    this.pause = const Duration(milliseconds: 900),
    bool Function()? degres,
  }) : degres = degres ?? (() => false);

  final Encre encre;
  final Lecteur lecteur;
  final Moteur moteur;
  final Duration pause;
  final bool Function() degres;

  final Map<String, BlocCalcul> _blocs = {};
  Timer? _minuteur;
  var _enCours = false;
  var _ferme = false;
  var _compteur = 0;

  List<BlocCalcul> get blocs => _blocs.values.toList();

  /// Un résultat ne s'écrit pas sur la ligne d'en dessous.
  void _placerResultats() {
    for (final bloc in _blocs.values) {
      final dessous = Rect.fromLTWH(
        bloc.cadre.left,
        bloc.cadre.bottom,
        bloc.cadre.width,
        bloc.cadre.height,
      );
      final libre = !_blocs.values.any(
        (autre) =>
            !identical(autre, bloc) &&
            !autre.estSaisie &&
            autre.cadre.overlaps(dessous),
      );
      if (libre != bloc.dessousLibre) {
        bloc
          ..dessousLibre = libre
          .._ecritPour = null;
      }
    }
  }

  @override
  void notifyListeners() {
    _placerResultats();
    super.notifyListeners();
  }

  bool get modeleManquant =>
      _blocs.values.any((b) => b.etat == EtatBloc.sansModele);

  /// À appeler à chaque changement de l'encre : la lecture attend la pause.
  void encreChangee() {
    _retirerTraitsDisparus();
    _minuteur?.cancel();
    _minuteur = Timer(pause, () => unawaited(_lireLesNouveaux()));
  }

  Iterable<Trait> get _ecrits => encre.traits.where((t) => t.forme == null);

  void _retirerTraitsDisparus() {
    final vivants = _ecrits.map((t) => t.id).toSet();
    final vides = <String>[];
    for (final bloc in _blocs.values) {
      if (bloc.estSaisie) continue;
      bloc.traits.retainAll(vivants);
      if (bloc.traits.isEmpty) {
        vides.add(bloc.cle);
      } else {
        _suivreTraits(bloc);
      }
    }
    if (vides.isEmpty) return;
    vides.forEach(_blocs.remove);
    notifyListeners();
  }

  /// Des traits ont bougé, comme une fraction redressée puis annulée : le
  /// résultat suit.
  void _suivreTraits(BlocCalcul bloc) {
    final traits = _traitsDe(bloc);
    if (traits.isEmpty) return;
    final cadre = cadreDuGroupe(traits);
    if (cadre == bloc.cadre) return;
    bloc
      ..cadre = cadre
      .._ecritPour = null;
    notifyListeners();
  }

  /// Les traits du résultat qui touche [zone] : le raturer efface le calcul.
  Set<int> traitsDuResultatSous(
    Rect zone, {
    required bool approcheVoulue,
    required bool virgule,
  }) {
    final traits = <int>{};
    for (final bloc in _blocs.values.toList()) {
      final ecrit = bloc.ecriture(
        approcheVoulue: approcheVoulue,
        virgule: virgule,
      );
      if (ecrit != null && ecrit.cadre.overlaps(zone)) {
        traits.addAll(bloc.traits);
      }
    }
    return traits;
  }

  /// Le modèle vient d'arriver : relire ce qui attendait.
  void modeleDisponible() {
    for (final bloc in _blocs.values) {
      if (bloc.etat == EtatBloc.sansModele) bloc._points = -1;
    }
    unawaited(_lireLesNouveaux());
  }

  /// Rattache les nouveaux traits à un bloc qu'ils touchent, sinon à eux seuls.
  void _rattacher() {
    final pris = {for (final b in _blocs.values) ...b.traits};
    final nouveaux = _ecrits.where((t) => !pris.contains(t.id)).toList();
    for (final groupe in grouperTraits(nouveaux)) {
      final cadre = cadreDuGroupe(groupe);
      final hote = _blocs.values.where((b) => !b.estSaisie).where((b) {
        return prolonge(b.cadre, cadre, ferme: b.finitParEgal);
      }).firstOrNull;
      final bloc =
          hote ??
          BlocCalcul(
            cle: 'bloc-${_compteur++}-${groupe.first.id}',
            cadre: cadre,
          );
      bloc.traits.addAll(groupe.map((t) => t.id));
      _blocs[bloc.cle] = bloc;
    }
  }

  List<Trait> _traitsDe(BlocCalcul bloc) =>
      _ecrits.where((t) => bloc.traits.contains(t.id)).toList();

  int _compterPoints(List<Trait> traits) =>
      traits.fold(0, (s, t) => s + t.points.length);

  Future<void> _lireLesNouveaux() async {
    if (_enCours || _ferme) return;
    _enCours = true;
    try {
      while (!_ferme) {
        _rattacher();
        BlocCalcul? suivant;
        for (final bloc in _blocs.values) {
          if (bloc.estSaisie) continue;
          if (_compterPoints(_traitsDe(bloc)) != bloc._points) {
            suivant = bloc;
            break;
          }
        }
        if (suivant == null) break;
        await _lire(suivant);
      }
    } finally {
      _enCours = false;
    }
  }

  Future<void> _lire(BlocCalcul bloc) async {
    final traits = _traitsDe(bloc);
    final version = ++bloc._version;
    bloc
      .._points = _compterPoints(traits)
      ..cadre = cadreDuGroupe(traits)
      ..etat = EtatBloc.lecture
      .._oublierResultat();
    notifyListeners();
    try {
      // Ce qui sort d'une seule ligne se lit par morceaux (ADR 0029).
      final structuree = await lireStructure(lecteur, traits);
      var latex = structuree ?? await lecteur.lire(traits);
      if (bloc._version != version || !identical(_blocs[bloc.cle], bloc)) {
        return;
      }
      final fonctions = _definitionsPour(bloc).keys.toSet();
      bloc.autresLectures = const [];
      // Une lecture qui étonne : on en demande d'autres (ADR 0028). Ce coût
      // n'est payé que dans le doute.
      if (structuree == null && plausibilite(latex, fonctions: fonctions) < 0) {
        final lectures = await lecteur.lirePlusieurs(traits);
        if (bloc._version != version || !identical(_blocs[bloc.cle], bloc)) {
          return;
        }
        final choix = choisirLecture([
          latex,
          ...lectures,
        ], fonctions: fonctions);
        final garde = redresserLecture(choix, fonctions: fonctions);
        final vues = <String>{normaliserLatex(garde)};
        bloc.autresLectures = [
          for (final l in lectures)
            if (vues.add(
              normaliserLatex(redresserLecture(l, fonctions: fonctions)),
            ))
              redresserLecture(l, fonctions: fonctions),
        ];
        latex = choix;
      }
      bloc
        ..latex = _redresser(
          bloc,
          redresserLecture(latex, fonctions: fonctions),
        )
        // Un nom se vérifie à l'œil ; les chiffres d'une matrice, moins.
        ..lueParMorceaux = structuree?.contains('matrix') ?? false;
      await _calculer(bloc);
    } on ModeleAbsent {
      bloc.etat = EtatBloc.sansModele;
    } on Object {
      bloc.etat = EtatBloc.erreur;
    }
    if (!_ferme) notifyListeners();
  }

  /// `1/3` écrit en ligne : les traits se rangent en fraction, et s'annulent.
  String _redresser(BlocCalcul bloc, String latex) {
    final traits = _traitsDe(bloc);
    final redresse = redresserFractions(traits, latex);
    if (redresse == null) return latex;
    bloc.hauteurLigne = bloc.cadre.height;
    encre.remplacer(redresse.traits);
    bloc.cadre = cadreDuGroupe(_traitsDe(bloc));
    return redresse.latex;
  }

  /// Toute lecture reste corrigeable : le calcul repart du texte corrigé.
  Future<void> corriger(BlocCalcul bloc, String latex) async {
    bloc
      ..latex = latex
      .._oublierResultat();
    await _calculer(bloc);
    if (!_ferme) notifyListeners();
  }

  /// Saisie au clavier, sans encre : passe par le même calcul.
  Future<void> saisir(String latex, Offset position) async {
    final bloc = BlocCalcul(
      cle: 'saisie-${DateTime.now().microsecondsSinceEpoch}-${_compteur++}',
      cadre: position & Size.zero,
    );
    _blocs[bloc.cle] = bloc;
    await corriger(bloc, latex);
  }

  void retirer(BlocCalcul bloc) {
    _blocs.remove(bloc.cle);
    notifyListeners();
  }

  void arreter() => moteur.interrompre();

  /// Le mode d'angle a changé : tout se recalcule depuis ce qui a été lu.
  Future<void> recalculer() async {
    for (final bloc in blocs) {
      if (bloc.latex == null) continue;
      bloc._oublierResultat();
      await _calculer(bloc);
      if (_ferme) return;
    }
    notifyListeners();
  }

  /// Ce qui est défini au-dessus de [bloc] : le plus proche l'emporte.
  _Contexte _contextePour(BlocCalcul bloc) {
    final contexte = _Contexte();
    final dessus =
        _blocs.values
            .where((b) => !identical(b, bloc) && b.latex != null)
            .where((b) => b.cadre.top <= bloc.cadre.top)
            .toList()
          ..sort((a, b) => a.cadre.top.compareTo(b.cadre.top));
    for (final b in dessus) {
      switch (b.objet) {
        case PointLu(:final nom, :final x, :final y):
          contexte.points[nom] = (x, y);
          continue;
        case VecteurLu(:final nom, :final x, :final y):
          contexte.vecteurs[nom] = (x, y);
          continue;
        case null:
          break;
      }
      try {
        final a = contexte.analyser(b.latex!);
        final definition = a.definition;
        if (definition != null) {
          contexte.definitions[a.nomFonction!] = definition;
        }
        final valeur = a.nomValeur;
        if (valeur != null) contexte.valeurs[valeur] = a.giac;
      } on ErreurLatex {
        continue;
      }
    }
    return contexte;
  }

  Map<String, DefinitionFonction> _definitionsPour(BlocCalcul bloc) =>
      _contextePour(bloc).definitions;

  /// [bloc] (re)définit une fonction : les lignes en dessous qui s'en servent
  /// se recalculent.
  Future<void> _recalculerCeuxQuiUtilisent(BlocCalcul bloc) async {
    final String? nom;
    try {
      final a = analyserLatex(bloc.latex ?? '');
      nom = a.nomFonction ?? a.nomValeur;
    } on ErreurLatex {
      return;
    }
    if (nom == null) return;
    final usage = RegExp(
      r'(^|[^a-zA-Z\\])'
      '$nom'
      '(?![a-zA-Z])',
    );
    for (final autre in blocs) {
      if (identical(autre, bloc) || autre.latex == null) continue;
      if (autre.cadre.top < bloc.cadre.top) continue;
      if (!usage.hasMatch(autre.latex!)) continue;
      autre._oublierResultat();
      await _calculer(autre, propager: false);
      if (_ferme) return;
    }
  }

  /// `\\vec{AB}` entre deux points de la feuille : ce qu'il faut en Figure.
  List<ObjetLu> _aPlacer(BlocCalcul bloc) {
    final m = RegExp(
      r'^\s*\\(?:overrightarrow|vec)\s*\{\s*([A-Z])\s*([A-Z])\s*\}\s*=?\s*$',
    ).firstMatch(bloc.latex ?? '');
    if (m == null) return const [];
    final points = _contextePour(bloc).points;
    final (a, b) = (points[m[1]], points[m[2]]);
    if (a == null || b == null) return const [];
    return [
      PointLu(m[1]!, a.$1, a.$2),
      PointLu(m[2]!, b.$1, b.$2),
      VecteurLu('${m[1]}${m[2]}', b.$1 - a.$1, b.$2 - a.$2),
    ];
  }

  /// Relit toute la feuille : après une mise à jour, tout peut mieux se lire.
  void relireTout() {
    for (final bloc in _blocs.values) {
      if (!bloc.estSaisie) bloc._points = -1;
    }
    unawaited(_lireLesNouveaux());
  }

  /// Relit une ligne : son écriture n'a pas changé, sa lecture peut changer.
  void relire(BlocCalcul bloc) {
    bloc._points = -1;
    unawaited(_lireLesNouveaux());
  }

  Future<void> _calculer(BlocCalcul bloc, {bool propager = true}) async {
    if (bloc.objet != null || bloc.courbeSeule) {
      bloc.etat = EtatBloc.fait;
      return;
    }
    final Analyse analyse;
    final enDegres = degres();
    try {
      analyse = _contextePour(bloc)
          .analyser(bloc.latex ?? '', degres: enDegres);
    } on ErreurLatex {
      bloc.etat = EtatBloc.nonCompris;
      return;
    }
    bloc
      ..type = analyse.type
      ..inconnues = analyse.inconnues
      ..demandeResultat = analyse.demandeResultat
      ..aPlacer = _aPlacer(bloc);
    if (analyse.nomValeur != null) {
      bloc.etat = EtatBloc.fait;
      if (propager) unawaited(_recalculerCeuxQuiUtilisent(bloc));
      return;
    }
    if (propager && analyse.nomFonction != null) {
      unawaited(_recalculerCeuxQuiUtilisent(bloc));
    }
    // Une définition n'a rien à rendre : elle reste sur la feuille. Envoyée à
    // Giac telle quelle, `y=2x+1` empêcherait ensuite de résoudre en y.
    if (analyse.type == TypeExpression.fonction) {
      bloc.etat = EtatBloc.fait;
      return;
    }
    bloc.etat = EtatBloc.calcul;
    notifyListeners();
    final ReponseGiac reponse;
    try {
      reponse = await moteur.calculer(analyse.giac, degres: enDegres);
    } on Object {
      bloc.etat = EtatBloc.erreur;
      return;
    }
    final exact = reponse.exact.trim();
    if (reponse.arrete) {
      bloc.etat = EtatBloc.arrete;
    } else if (reponse.erreur != null ||
        // `infinity` sans signe : 1/0 n'a pas de valeur, ce n'est pas un résultat.
        const {'undef', 'infinity', ''}.contains(exact)) {
      bloc.etat = EtatBloc.sansResultat;
    } else if (exact == 'true' || exact == 'false') {
      bloc
        ..verite = exact == 'true'
        ..etat = EtatBloc.fait;
    } else {
      String sansEspaces(String s) => s.replaceAll(RegExp(r'[\s()]'), '');
      bloc
        ..resultat = reponse.latex
        // Une valeur déjà décimale ou entière ne se répète pas.
        ..approche = reponse.approche.isEmpty || num.tryParse(exact) != null
            ? null
            : reponse.approche
        ..inchange =
            !analyse.demandeResultat &&
            sansEspaces(exact) == sansEspaces(analyse.giac)
        ..etat = EtatBloc.fait;
    }
  }

  List<Map<String, dynamic>> versDocument() => [
    for (final b in _blocs.values)
      if (b.etat != EtatBloc.lecture && b.etat != EtatBloc.calcul) b.versJson(),
  ];

  void chargerDocument(List<dynamic> document) {
    _blocs.clear();
    for (final json in document.cast<Map<String, dynamic>>()) {
      final bloc = BlocCalcul.depuisJson(json);
      _blocs[bloc.cle] = bloc;
    }
    // Une sauvegarde de la 0.1.0 ne compte pas les points : pas de relecture.
    for (final bloc in _blocs.values) {
      if (bloc._points == 0 && !bloc.estSaisie) {
        bloc._points = _compterPoints(_traitsDe(bloc));
      }
    }
    _retirerTraitsDisparus();
  }

  @override
  void dispose() {
    _ferme = true;
    _minuteur?.cancel();
    super.dispose();
  }
}
