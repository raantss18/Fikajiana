import 'dart:async';
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/comprendre/solutions.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
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

  /// Nombre de points lus : un trait prolongé se relit.
  int _points = 0;

  /// Augmente à chaque changement : une lecture périmée est ignorée.
  int _version = 0;

  bool get estSaisie => cle.startsWith('saisie-');

  bool get finitParEgal => latex?.trimRight().endsWith('=') ?? false;

  /// Un résultat se montre après un `=`, ou sous une équation ou un système.
  /// Une expression sans `=` ne demande rien.
  bool get montreResultat {
    if (etat != EtatBloc.fait || verite != null) return false;
    return estSaisie || finitParEgal || estResolution;
  }

  bool get _sousLEcriture => !finitParEgal;

  /// Une équation ou un système : le résultat n'est pas une valeur à égaler.
  bool get estResolution =>
      type == TypeExpression.equation || type == TypeExpression.systeme;

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
      _ecrit = ecrireResultat(valeur, cadre, dessous: _sousLEcriture);
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
      if (bloc.traits.isEmpty) vides.add(bloc.cle);
    }
    if (vides.isEmpty) return;
    vides.forEach(_blocs.remove);
    notifyListeners();
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
      final latex = await lecteur.lire(traits);
      if (bloc._version != version || !identical(_blocs[bloc.cle], bloc)) {
        return;
      }
      bloc.latex = latex;
      await _calculer(bloc);
    } on ModeleAbsent {
      bloc.etat = EtatBloc.sansModele;
    } on Object {
      bloc.etat = EtatBloc.erreur;
    }
    if (!_ferme) notifyListeners();
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

  Future<void> _calculer(BlocCalcul bloc) async {
    final Analyse analyse;
    final enDegres = degres();
    try {
      analyse = analyserLatex(bloc.latex ?? '', degres: enDegres);
    } on ErreurLatex {
      bloc.etat = EtatBloc.nonCompris;
      return;
    }
    bloc
      ..type = analyse.type
      ..inconnues = analyse.inconnues
      ..etat = EtatBloc.calcul;
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
        ..inchange = sansEspaces(exact) == sansEspaces(analyse.giac)
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
