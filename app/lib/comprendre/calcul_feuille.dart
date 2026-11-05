import 'dart:async';
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
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

  /// Le LaTeX est affiché, mais il ne se traduit pas : à corriger.
  nonCompris,

  /// Giac ne donne pas de résultat utilisable.
  sansResultat,
  arrete,
  sansModele,
  erreur,
}

/// Une expression de la feuille : ce qui est compris, et son résultat.
class BlocCalcul {
  new({
    required this.cle,
    required this.cadre,
    this.latex,
    this.etat = EtatBloc.lecture,
  });

  factory depuisJson(Map<String, dynamic> json) =>
      BlocCalcul(
          cle: json['cle'] as String,
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
        ..verite = json['verite'] as bool?
        ..resultat = json['resultat'] as String?
        ..approche = json['approche'] as String?;

  final String cle;
  Rect cadre;
  String? latex;
  EtatBloc etat;
  TypeExpression? type;

  /// Réponse à une égalité sans inconnue, comme `2+2=5`.
  bool? verite;

  /// Résultat exact, en LaTeX.
  String? resultat;
  String? approche;

  bool get estSaisie => cle.startsWith('saisie-');

  /// On écrit le résultat à la main seulement si l'écriture finit par `=` :
  /// c'est là qu'il est attendu, et il y a la place sur la ligne.
  bool get finitParEgal =>
      !estSaisie && (latex?.trimRight().endsWith('=') ?? false);

  String? _ecritPour;
  EcritureResultat? _ecrit;

  /// Le résultat tracé après le `=`, ou `null` s'il reste sur la carte.
  EcritureResultat? get ecriture {
    final resultat = this.resultat;
    if (etat != EtatBloc.fait || resultat == null || !finitParEgal) return null;
    if (_ecritPour != resultat) {
      _ecritPour = resultat;
      _ecrit = ecrireResultat(resultat, cadre);
    }
    return _ecrit;
  }

  Map<String, dynamic> versJson() => {
    'cle': cle,
    'g': cadre.left,
    'h': cadre.top,
    'd': cadre.right,
    'b': cadre.bottom,
    'latex': latex,
    'etat': etat.name,
    'type': type?.name,
    'verite': verite,
    'resultat': resultat,
    'approche': approche,
  };
}

/// Lit l'encre à la pause et calcule chaque expression de la feuille.
class CalculFeuille extends ChangeNotifier {
  new({
    required this.encre,
    required this.lecteur,
    required this.moteur,
    this.pause = const Duration(milliseconds: 900),
  });

  final Encre encre;
  final Lecteur lecteur;
  final Moteur moteur;
  final Duration pause;

  final Map<String, BlocCalcul> _blocs = {};
  Timer? _minuteur;
  var _enCours = false;
  var _ferme = false;
  var _saisies = 0;

  List<BlocCalcul> get blocs => _blocs.values.toList();
  bool get modeleManquant =>
      _blocs.values.any((b) => b.etat == EtatBloc.sansModele);

  /// À appeler à chaque changement de l'encre : la lecture attend la pause.
  void encreChangee() {
    _retirerObsoletes();
    _minuteur?.cancel();
    _minuteur = Timer(pause, () => unawaited(_lireLesNouveaux()));
  }

  void _retirerObsoletes() {
    final vivants = grouperTraits(encre.traits).map(cleDuGroupe).toSet();
    final avant = _blocs.length;
    _blocs.removeWhere((k, b) => !b.estSaisie && !vivants.contains(k));
    if (_blocs.length != avant) notifyListeners();
  }

  /// Le modèle vient d'arriver : relire ce qui attendait.
  void modeleDisponible() {
    _blocs.removeWhere((_, b) => b.etat == EtatBloc.sansModele);
    unawaited(_lireLesNouveaux());
  }

  Future<void> _lireLesNouveaux() async {
    if (_enCours || _ferme) return;
    _enCours = true;
    try {
      while (!_ferme) {
        final groupes = grouperTraits(encre.traits);
        List<Trait>? groupe;
        for (final g in groupes) {
          if (!_blocs.containsKey(cleDuGroupe(g))) {
            groupe = g;
            break;
          }
        }
        if (groupe == null) break;
        await _lireGroupe(groupe);
      }
    } finally {
      _enCours = false;
    }
  }

  Future<void> _lireGroupe(List<Trait> groupe) async {
    final cle = cleDuGroupe(groupe);
    final bloc = BlocCalcul(cle: cle, cadre: cadreDuGroupe(groupe));
    _blocs[cle] = bloc;
    notifyListeners();
    try {
      final latex = await lecteur.lire(groupe);
      if (!identical(_blocs[cle], bloc)) return;
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
      ..verite = null
      ..resultat = null
      ..approche = null;
    await _calculer(bloc);
    if (!_ferme) notifyListeners();
  }

  /// Saisie au clavier, sans encre : passe par le même calcul.
  Future<void> saisir(String latex, Offset position) async {
    final bloc = BlocCalcul(
      cle: 'saisie-${DateTime.now().microsecondsSinceEpoch}-${_saisies++}',
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

  Future<void> _calculer(BlocCalcul bloc) async {
    final Analyse analyse;
    try {
      analyse = analyserLatex(bloc.latex ?? '');
    } on ErreurLatex {
      bloc.etat = EtatBloc.nonCompris;
      return;
    }
    bloc
      ..type = analyse.type
      ..etat = EtatBloc.calcul;
    notifyListeners();
    final ReponseGiac reponse;
    try {
      reponse = await moteur.calculer(analyse.giac);
    } on Object {
      bloc.etat = EtatBloc.erreur;
      return;
    }
    if (reponse.arrete) {
      bloc.etat = EtatBloc.arrete;
    } else if (reponse.erreur != null ||
        // `infinity` sans signe : 1/0 n'a pas de valeur, ce n'est pas un résultat.
        const {'undef', 'infinity', ''}.contains(reponse.exact.trim())) {
      bloc.etat = EtatBloc.sansResultat;
    } else if (reponse.exact == 'true' || reponse.exact == 'false') {
      bloc
        ..verite = reponse.exact == 'true'
        ..etat = EtatBloc.fait;
    } else {
      bloc
        ..resultat = reponse.latex
        // Une valeur déjà décimale ou entière ne se répète pas.
        ..approche =
            reponse.approche.isEmpty ||
                num.tryParse(reponse.exact.trim()) != null
            ? null
            : reponse.approche
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
    _retirerObsoletes();
  }

  @override
  void dispose() {
    _ferme = true;
    _minuteur?.cancel();
    super.dispose();
  }
}
