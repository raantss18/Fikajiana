import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/decimale.dart';
import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/comprendre/fraction_ecrite.dart';
import 'package:fikajiana/comprendre/mots.dart';
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
      ..note = json['note'] as String?
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

  /// Un mot écrit à côté d'une ligne, `longueur` : une note, pas un calcul
  /// à signaler (Pad 7).
  String? note;

  /// `cercle(A;2)`, `(AB)` : ce qu'il faut construire dans la Figure.
  CommandeGeo? commande;

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

  /// Ce qui est écrit autour : un résultat ne s'y pose pas.
  List<Rect> _voisins = const [];

  /// `f'(x)`, `det(…)` sans `=` : l'app l'écrit devant la valeur. Une
  /// équation se résout dessous, sans `=` (« x+3=4 = {1} » serait faux).
  bool get egalAjoute => !finitParEgal && !estResolution && !estSaisie;

  /// Le résultat se pose sous l'écriture : une équation, si la place est libre.
  bool get resultatDessous => estResolution && dessousLibre;

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
      // `74×10^{-4}+85×10^8` : la fraction exacte 42500000000037/5000 ne se
      // lit pas ; sa valeur décimale, exacte aussi, si (Pad 7).
      final decimale =
          choisie == null && exact != null && ecritEnDecimal(latex ?? '')
          ? decimaleExacte(exact)
          : null;
      valeur = decimale ?? (choisie == null ? exact : abregerApproche(choisie));
    }
    // `2\cdot x^{2}` de Giac s'écrit `2x^{2}`, comme à la main.
    final sansPoint = valeur?.replaceAllMapped(
      RegExp(r'(\d|\})\s*\\cdot\s*([a-zA-Z(]|\\left|\\sqrt|\\pi)'),
      (m) => '${m[1]}${m[2]}',
    );
    if (sansPoint == null || !virgule) return sansPoint;
    return sansPoint.replaceAllMapped(
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
    if (estSaisie || etat != EtatBloc.fait) return null;
    final v = verite;
    // `premier(17)` : « = vrai », écrit à la main comme tout résultat (Antsa).
    final valeur = v != null
        ? '\\mathrm{${virgule ? (v ? 'vrai' : 'faux') : (v ? 'true' : 'false')}}'
        : montreResultat
        ? texte(approcheVoulue: approcheVoulue, virgule: virgule)
        : null;
    if (valeur == null) return null;
    if (_ecritPour != valeur) {
      _ecritPour = valeur;
      _ecrit = _placer(valeur);
    }
    return _ecrit;
  }

  /// À droite après un `=`, dessous pour une équation ; de l'autre côté si la
  /// place est prise, et à la place voulue si les deux le sont.
  EcritureResultat? _placer(String valeur) {
    EcritureResultat? essai({required bool dessous}) => ecrireResultat(
      // Sous l'écriture, la valeur seule ne dirait pas ce qu'elle égale.
      // `2+2=5` est faux : le mot suit, sans `=` ; `premier(17) = vrai`.
      (verite != null ? demandeResultat : egalAjoute) ||
              (finitParEgal && dessous)
          ? '=$valeur'
          : valeur,
      cadre,
      dessous: dessous,
      hauteurLigne: hauteurLigne,
    );
    final dessous = resultatDessous;
    final voulu = essai(dessous: dessous);
    if (voulu == null || !_gene(voulu.cadre)) return voulu;
    final autre = essai(dessous: !dessous);
    return autre != null && !_gene(autre.cadre) ? autre : voulu;
  }

  /// Le bord droit de la page : un résultat qui le dépasse sort de l'écran
  /// (vu sur le Pad 7 avec `développer(…)`).
  double _bordDroit = double.infinity;

  bool _gene(Rect zone) =>
      zone.right > _bordDroit || _voisins.any(zone.deflate(1).overlaps);

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
    'note': ?note,
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

  /// Le bord droit de la page visible, en coordonnées de page.
  double _bordDroit = double.infinity;

  double get bordDroit => _bordDroit;

  set bordDroit(double bord) {
    if (bord == _bordDroit) return;
    _bordDroit = bord;
    for (final bloc in _blocs.values) {
      bloc
        .._bordDroit = bord
        .._ecritPour = null;
    }
  }

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
      final voisins = [
        for (final autre in _blocs.values)
          if (!identical(autre, bloc) && !autre.estSaisie) autre.cadre,
      ];
      if (libre != bloc.dessousLibre || !listEquals(voisins, bloc._voisins)) {
        bloc
          ..dessousLibre = libre
          .._voisins = voisins
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
      ..note = null
      .._oublierResultat();
    notifyListeners();
    try {
      // Ce qui sort d'une seule ligne se lit par morceaux (ADR 0029).
      final structuree = await lireStructure(lecteur, traits);
      var latex =
          structuree ?? redresserEgal(traits, await lecteur.lire(traits));
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
      if (structuree == null && bloc.etat == EtatBloc.nonCompris) {
        await _lireUnMot(bloc, traits, version);
      }
    } on ModeleAbsent {
      bloc.etat = EtatBloc.sansModele;
    } on Object {
      bloc.etat = EtatBloc.erreur;
    }
    if (!_ferme) notifyListeners();
  }

  /// `premier(17)` en cursive : le modèle ne lit pas les mots. Le mot se
  /// reconnaît à sa silhouette, la parenthèse se lit à part (ADR 0031). Dans
  /// le doute, rien n'est choisi : les mots proches sont proposés.
  Future<void> _lireUnMot(
    BlocCalcul bloc,
    List<Trait> traits,
    int version,
  ) async {
    final ecrit = separerMot(traits);
    if (ecrit == null) {
      _lireUnMotSeul(bloc, traits);
      if (bloc.note == null && bloc.latex != null) {
        await _calculer(bloc);
      }
      return;
    }
    final classes = classerMots(ecrit.mot);
    final suite = (await lireAuMieux(lecteur, ecrit.suite)).trim();
    if (bloc._version != version || !identical(_blocs[bloc.cle], bloc)) return;
    final candidats = [
      for (final (nom, _) in classes.take(3)) '\\text{$nom}$suite',
    ];
    final sur = motSur(classes);
    bloc.autresLectures = [
      ...candidats.skip(sur == null ? 0 : 1),
      ...bloc.autresLectures,
    ];
    if (sur == null) return;
    // `plot(g(x))` : ce qui est entre parenthèses se trace (Pad 7).
    final courbe = motsTracer.contains(sur) ? _courbeDe(bloc, suite) : null;
    if (motsTracer.contains(sur) && courbe == null) return;
    bloc
      ..latex = courbe ?? candidats.first
      // Ce qui a été compris s'affiche, à vérifier d'un coup d'œil.
      ..lueParMorceaux = true;
    await _calculer(bloc);
  }

  /// La courbe de `(g(x))` : la définition de g écrite plus haut, telle
  /// quelle ; sinon `y=` l'expression en x.
  String? _courbeDe(BlocCalcul bloc, String suite) {
    var dedans = suite.replaceAll(RegExp(r'\\(left|right)'), '').trim();
    while (dedans.startsWith('(') && dedans.endsWith(')')) {
      dedans = dedans.substring(1, dedans.length - 1).trim();
    }
    final appel = RegExp(r'^([a-zA-Z])\(x\)$')
        .firstMatch(dedans.replaceAll(' ', ''));
    if (appel != null) {
      final dessus =
          _blocs.values
              .where((b) => b.cadre.top < bloc.cadre.top && b.seTrace)
              .where((b) {
                try {
                  return analyserLatex(b.latex ?? '').nomFonction == appel[1];
                } on ErreurLatex {
                  return false;
                }
              })
              .toList()
            ..sort((a, b) => a.cadre.top.compareTo(b.cadre.top));
      return dessus.lastOrNull?.latex;
    }
    return RegExp(r'(?<![a-zA-Z\\])x').hasMatch(dedans) ? 'y=$dedans' : null;
  }

  /// `30×8` sans `=` : un calcul de nombres attend sa valeur (Antsa : « le =
  /// oublié »). Un nombre seul, `8`, ou une lettre, non.
  static bool _calculDeNombres(Analyse analyse) {
    if (analyse.type != TypeExpression.calcul || analyse.nomValeur != null) {
      return false;
    }
    final giac = analyse.giac;
    if (giac.contains('==') || RegExp('[<>]').hasMatch(giac)) return false;
    final sansFonctions = giac.replaceAll(
      RegExp(
        r'\b(sqrt|sin|cos|tan|asin|acos|atan|ln|log10|exp|abs|floor|ceil|'
        r'comb|gcd|lcm|round|pi|normal|simplify)\b',
      ),
      '',
    );
    if (RegExp('[a-zA-Z]').hasMatch(sansFonctions)) return false;
    return RegExp('[-+*/^(]').hasMatch(giac.replaceFirst(RegExp(r'^\(?-'), ''));
  }

  /// `⇒ plot` à côté de `f'(x)=2x-2` : la ligne d'à côté se trace ; un mot
  /// comme `longueur` reste une note (Pad 7, ADR 0031).
  void _lireUnMotSeul(BlocCalcul bloc, List<Trait> traits) {
    final mot = reconnaitreMotSeul(traits);
    if (mot == null) return;
    final courbe = motsTracer.contains(mot) ? _courbeAGauche(bloc) : null;
    if (courbe != null) {
      bloc
        ..latex = courbe
        ..lueParMorceaux = true;
      return;
    }
    bloc
      ..note = mot
      ..latex = '\\text{$mot}'
      ..etat = EtatBloc.fait;
  }

  /// La courbe de la ligne écrite juste à gauche, sur la même ligne :
  /// sa définition, ou `y=` son résultat en x.
  String? _courbeAGauche(BlocCalcul bloc) {
    final ici = bloc.cadre;
    BlocCalcul? voisin;
    for (final autre in _blocs.values) {
      if (identical(autre, bloc) || autre.estSaisie) continue;
      final c = autre.cadre;
      final commun = math.min(c.bottom, ici.bottom) - math.max(c.top, ici.top);
      if (commun < 0.4 * math.min(c.height, ici.height)) continue;
      if (c.left >= ici.left) continue;
      if (voisin == null || c.right > voisin.cadre.right) voisin = autre;
    }
    if (voisin == null) return null;
    if (voisin.seTrace) return voisin.latex;
    final resultat = voisin.resultat;
    if (resultat == null || voisin.estResolution) return null;
    if (!RegExp(r'(?<![a-zA-Z\\])x(?![a-zA-Z])').hasMatch(resultat)) {
      return null;
    }
    return 'y=$resultat';
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
      ..note = null
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
  /// [latex] compris comme s'il était écrit à la place de [bloc].
  Analyse analyserPour(BlocCalcul bloc, String latex) =>
      _contextePour(bloc).analyser(latex);

  /// [latex] compris sous tout ce qui est écrit : une ligne tapée.
  Analyse analyserEnBas(String latex) => _contextePour(
    BlocCalcul(cle: '', cadre: const Rect.fromLTWH(0, 1000000000, 0, 0)),
  ).analyser(latex);

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
    final commande = lireCommande(bloc.latex ?? '');
    if (commande != null) {
      // Ses points doivent être déclarés au-dessus : sinon, rien à placer.
      final points = _contextePour(bloc).points;
      if (!commande.points.every(points.containsKey)) {
        bloc.etat = EtatBloc.nonCompris;
        return;
      }
      bloc
        ..aPlacer = [
          for (final n in commande.points)
            PointLu(n, points[n]!.$1, points[n]!.$2),
        ]
        ..commande = commande
        ..etat = EtatBloc.fait;
      return;
    }
    if (bloc.note != null) {
      bloc.etat = EtatBloc.fait;
      return;
    }
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
      ..demandeResultat = analyse.demandeResultat || _calculDeNombres(analyse)
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
