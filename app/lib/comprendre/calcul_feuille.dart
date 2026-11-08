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
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/graphe/courbes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana/reconnaissance/classeur_appris.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/reconnaissance/ecritures.dart';
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
      ..corrige = json['co'] as bool? ?? false
      ..juge = json['ju'] as bool?
      ..sansLimite = json['sl'] as bool? ?? false
      ..approche = json['approche'] as String?
      ..inchange = json['inchange'] as bool? ?? false
      ..hauteurLigne = (json['hl'] as num?)?.toDouble()
      ..demandeResultat = json['dr'] as bool? ?? false
      ..lueParMorceaux = json['lm'] as bool? ?? false
      ..inconnueMatrice = json['im'] as String?
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

  /// Lu au tracé : chaque signe, ses traits et ce qu'on y a lu. Toucher
  /// l'un d'eux propose d'autres lectures (ADR 0041).
  List<(List<Trait>, String)> signesLus = const [];

  /// `f'(x)` ou `det(…)` : la réponse s'affiche même sans `=`.
  bool demandeResultat = false;

  /// `X` pour `AX=B` : la réponse s'écrit `X = …`, comme une résolution.
  String? inconnueMatrice;

  /// La feuille propose de la tracer.
  bool get seTrace => courbeSeule || type == TypeExpression.fonction;

  bool get finitParEgal => latex?.trimRight().endsWith('=') ?? false;

  /// Un résultat se montre après un `=`, ou sous une équation ou un système.
  /// Une expression sans `=` ne demande rien.
  bool get montreResultat {
    if (etat != EtatBloc.fait || verite != null || courbeSeule) return false;
    return estSaisie ||
        finitParEgal ||
        estResolution ||
        demandeResultat ||
        sansLimite;
  }

  /// Rien d'écrit juste dessous : une solution peut s'y poser.
  bool dessousLibre = true;

  /// Une ligne lue, pas tapée : 👍 et 👎 s'y proposent (ADR 0042).
  bool get jugeable =>
      !estSaisie &&
      latex != null &&
      switch (etat) {
        EtatBloc.fait ||
        EtatBloc.nonCompris ||
        EtatBloc.sansResultat ||
        EtatBloc.erreur ||
        EtatBloc.arrete => true,
        _ => false,
      };

  /// Ce qui est écrit autour : un résultat ne s'y pose pas.
  List<Rect> _voisins = const [];

  /// Corrigé à la main : « Relire la feuille » ne le regroupe pas.
  bool corrige = false;

  /// Jugée par la personne : `true` (👍, ou corrigée), `false` (👎, en
  /// attente de correction), `null` (pas jugée) (ADR 0042).
  bool? juge;

  /// Un signe vient d'être corrigé : la ligne relue sera l'exemple.
  bool _retenirApresRelecture = false;

  /// Une limite demandée qui n'existe pas : la réponse est « pas de limite ».
  bool sansLimite = false;

  /// `f'(x)`, `det(…)` sans `=` : l'app l'écrit devant la valeur. Une
  /// équation se résout dessous, sans `=` (« x+3=4 = {1} » serait faux).
  bool get egalAjoute => !finitParEgal && !estResolution && !estSaisie;

  /// Le résultat se pose sous l'écriture : une équation, si la place est libre.
  bool get resultatDessous => estResolution && dessousLibre;

  /// Une équation ou un système : le résultat n'est pas une valeur à égaler.
  bool get estResolution =>
      inconnueMatrice != null ||
      type == TypeExpression.equation ||
      type == TypeExpression.systeme ||
      type == TypeExpression.suite;

  String? _approcheChoisie({required bool approcheVoulue}) {
    final exact = resultat;
    // Une valeur que Giac n'a trouvée que numériquement est déjà approchée.
    final longue = exact != null && RegExp(r'\d\.\d{9}').hasMatch(exact);
    return approcheVoulue || inchange || longue ? approche : null;
  }

  /// La valeur montrée n'est qu'approchée : `≈` au lieu de `=` (repris de
  /// Mikajy, GPL-3.0) ; `1/4 → 0,25` reste exact.
  bool estApproche({required bool approcheVoulue}) {
    final exact = resultat;
    if (exact == null || estResolution || inconnueMatrice != null) {
      return false;
    }
    if (_approcheChoisie(approcheVoulue: approcheVoulue) == null) return false;
    final plat = exact.replaceAll(' ', '');
    return num.tryParse(plat) == null && decimaleExacte(plat) == null;
  }

  /// Ce qu'il faut afficher selon le mode, en LaTeX.
  String? texte({required bool approcheVoulue, required bool virgule}) {
    if (sansLimite) {
      return virgule ? r'\mathrm{pas\,de\,limite}' : r'\mathrm{no\,limit}';
    }
    final exact = resultat;
    // Une valeur que Giac n'a trouvée que numériquement est déjà approchée.
    final choisie = _approcheChoisie(approcheVoulue: approcheVoulue);
    final String? valeur;
    final matrice = inconnueMatrice;
    if (matrice != null) {
      valeur = exact == null ? null : '$matrice=$exact';
    } else if (estResolution) {
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

  bool _auPropreActif = false;
  String? _proprePour;
  EcritureResultat? _propre;

  /// Ce qui a été lu, écrit au propre à la place de l'encre (Antsa) : une
  /// ligne comprise seulement, que la main sait écrire. Sinon `null`, et
  /// l'encre reste.
  EcritureResultat? auPropre() {
    final lu = latex;
    if (estSaisie || etat != EtatBloc.fait || note != null || lu == null) {
      return null;
    }
    // Seulement ce qui est sûrement compris : une lecture douteuse ou qui ne
    // donne rien ne cache jamais l'écriture (téléphone d'Antsa : `A(3;-1)`
    // remplacé par `+(3i-1)`).
    if (!_compris) return null;
    final cle = '$lu|$cadre';
    if (_proprePour != cle) {
      _proprePour = cle;
      _propre = ecrireALaPlace(
        lu.replaceAll(RegExp(r'\\(left|right)'), ''),
        cadre,
      );
    }
    return _propre;
  }

  bool get _compris {
    if (autresLectures.isNotEmpty || lueParMorceaux) return false;
    final resultatMontre =
        verite != null || (montreResultat && resultat != null && !inchange);
    final declaration =
        objet != null ||
        commande != null ||
        seTrace ||
        inconnueMatrice != null ||
        type == TypeExpression.matrice ||
        type == TypeExpression.suite;
    return resultatMontre || declaration;
  }

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
    // Une ligne relue pendant ce placement : son résultat d'avant suffit.
    if (_enPlacement) return _ecrit;
    final approche = v == null && estApproche(approcheVoulue: approcheVoulue);
    _enPlacement = true;
    try {
      // Les résultats des lignes d'avant sont posés : celui-ci les évite
      // (Pad 7 d'Antsa : `= 81/2` écrit sur `7⁹ = 40353607`).
      final pris = [
        for (final autre in _avant)
          ?autre
              .ecriture(approcheVoulue: approcheVoulue, virgule: virgule)
              ?.cadre,
      ];
      final cle = '$approche$valeur|$cadre|$hauteurLigne|$pris';
      if (_ecritPour != cle) {
        _ecritPour = cle;
        _ecrit = _placer(valeur, pris, approche: approche);
      }
    } finally {
      _enPlacement = false;
    }
    return _ecrit;
  }

  /// Les lignes placées avant celle-ci : de haut en bas, puis de gauche à
  /// droite. Leur résultat est posé d'abord.
  List<BlocCalcul> _avant = const [];
  bool _enPlacement = false;

  /// À droite après un `=`, dessous pour une équation ; de l'autre côté si la
  /// place est prise ; sinon décalé le long de sa ligne, puis plus petit.
  /// Jamais sur l'encre ni le résultat d'une autre ligne quand une place
  /// libre existe ; sinon là où il gêne le moins.
  EcritureResultat? _placer(
    String valeur,
    List<Rect> pris, {
    bool approche = false,
  }) {
    final obstacles = [..._voisins, ...pris];
    // Au propre, l'écriture est plus courte : le résultat la suit.
    final ecriture =
        (_auPropreActif
            ? auPropre()?.cadre.expandToInclude(
                Rect.fromLTWH(cadre.left, cadre.top, 0, cadre.height),
              )
            : null) ??
        cadre;
    EcritureResultat? essai({required bool dessous, double reduction = 1}) =>
        ecrireResultat(
          // Sous l'écriture, la valeur seule ne dirait pas ce qu'elle égale.
          // `2+2=5` est faux : le mot suit, sans `=` ; `premier(17) = vrai`.
          (verite != null ? demandeResultat : egalAjoute) ||
                  (finitParEgal && dessous)
              ? '${approche ? r'\approx ' : '='}$valeur'
              : valeur,
          ecriture,
          dessous: dessous,
          hauteurLigne: hauteurLigne,
          reduction: reduction,
        );
    final cotes = [resultatDessous, !resultatDessous];
    EcritureResultat? moinsGenant;
    var moindre = double.infinity;
    for (final reduction in _reductions) {
      final essais = [
        for (final dessous in cotes)
          (dessous, essai(dessous: dessous, reduction: reduction)),
      ];
      // Les deux côtés à leur place, puis décalés : une place libre de
      // l'autre côté vaut mieux qu'un résultat qui glisse.
      for (final decale in [false, true]) {
        for (final (dessous, e) in essais) {
          if (e == null) return null;
          final decalages = _decalages(e.cadre, ecriture, dessous: dessous);
          for (final d in decale ? decalages.skip(1) : decalages.take(1)) {
            final gene = _gene(e.cadre.shift(d), obstacles);
            if (gene == 0) return e.decale(d);
            if (gene < moindre) {
              moindre = gene;
              moinsGenant = e.decale(d);
            }
          }
        }
      }
    }
    return moinsGenant;
  }

  /// Plus petit, mais lisible : jamais sous la hauteur minimale d'une
  /// écriture (`ecrireResultat`), et une matrice garde la moitié de sa
  /// taille.
  static const _reductions = [1.0, 0.8, 0.65, 0.5];

  /// Où glisser le résultat sans quitter sa ligne : à droite, vers le haut
  /// ou le bas, en touchant toujours la hauteur de la ligne ; dessous, vers
  /// la droite, sans dépasser la fin de la ligne.
  static Iterable<Offset> _decalages(
    Rect zone,
    Rect ecriture, {
    required bool dessous,
  }) sync* {
    yield Offset.zero;
    final pas = math.max<double>(
      4,
      0.2 * math.min(zone.height, ecriture.height),
    );
    for (var k = 1; k <= 12; k++) {
      if (dessous) {
        final dx = k * pas;
        if (zone.left + dx > ecriture.right) return;
        yield Offset(dx, 0);
      } else {
        for (final dy in [-k * pas, k * pas]) {
          final z = zone.shift(Offset(0, dy));
          if (z.top < ecriture.bottom && z.bottom > ecriture.top) {
            yield Offset(0, dy);
          }
        }
      }
    }
  }

  /// Le bord droit de la page : un résultat qui le dépasse sort de l'écran
  /// (vu sur le Pad 7 avec `développer(…)`).
  double _bordDroit = double.infinity;

  /// L'écart gardé autour de ce qui est écrit : un résultat ne le touche pas.
  static const _ecart = 3.0;

  /// Combien [zone] gêne : 0 si elle est libre et sur la page.
  double _gene(Rect zone, List<Rect> obstacles) {
    var gene = zone.right > _bordDroit
        ? (zone.right - _bordDroit) * zone.height
        : 0.0;
    for (final o in obstacles) {
      final autour = o.inflate(_ecart);
      if (!autour.overlaps(zone)) continue;
      final commun = autour.intersect(zone);
      gene += math.max(1, commun.width * commun.height);
    }
    return gene;
  }

  void _oublierResultat() {
    sansLimite = false;
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
    'co': corrige,
    'ju': ?juge,
    'sl': sansLimite,
    'inchange': inchange,
    'points': _points,
    'hl': ?hauteurLigne,
    if (demandeResultat) 'dr': true,
    if (lueParMorceaux) 'lm': true,
    'im': ?inconnueMatrice,
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
    this.pause = const Duration(milliseconds: 700),
    this.pauseConnue = const Duration(milliseconds: 400),
    ClasseurAppris? classeur,
    bool Function()? degres,
  }) : degres = degres ?? (() => false),
       classeur = classeur ?? ClasseurAppris(ecritures: Ecritures());

  /// Les signes lus de [bloc], avec la case de leur ligne.
  List<SigneDeLigne> _signesAvecCase(BlocCalcul bloc) {
    final signes = [for (final (t, _) in bloc.signesLus) t];
    return [
      for (final (t, l) in bloc.signesLus) (t, l, caseDansLaLigne(t, signes)),
    ];
  }

  /// 👍 : la lecture de [bloc] est juste ; elle est gardée (et donnée si la
  /// personne l'a accepté, ADR 0042).
  Future<void> jugerJuste(BlocCalcul bloc) async {
    final latex = bloc.latex;
    final traits = _traitsDe(bloc);
    if (latex == null || bloc.estSaisie || traits.isEmpty) return;
    bloc.juge = true;
    notifyListeners();
    await classeur.ecritures?.jugerJuste(
      traits,
      latex,
      cadreDuGroupe(traits),
      _signesAvecCase(bloc),
    );
  }

  /// 👎 : la lecture est fausse ; rien n'est gardé tant qu'elle n'est pas
  /// corrigée.
  void jugerFaux(BlocCalcul bloc) {
    bloc.juge = false;
    notifyListeners();
  }

  final Encre encre;
  final Lecteur lecteur;
  final Moteur moteur;
  final Duration pause;

  /// La pause quand tous les signes de la ligne sont déjà lus (ADR 0041).
  final Duration pauseConnue;

  /// Lit chaque signe : corrections de la personne, petit modèle, gabarits.
  final ClasseurAppris classeur;
  final bool Function() degres;

  final Map<String, BlocCalcul> _blocs = {};
  Timer? _minuteur;
  Timer? _minuteurSignes;
  DateTime _dernierTrait = DateTime.now();
  var _enCours = false;
  var _ferme = false;
  var _compteur = 0;

  List<BlocCalcul> get blocs => _blocs.values.toList();

  /// Le bord droit de la page visible, en coordonnées de page.
  double _bordDroit = double.infinity;

  double get bordDroit => _bordDroit;

  bool _auPropre = false;

  bool get auPropre => _auPropre;

  /// L'écriture lue est montrée au propre : les résultats la suivent.
  set auPropre(bool actif) {
    if (actif == _auPropre) return;
    _auPropre = actif;
    for (final bloc in _blocs.values) {
      bloc
        .._auPropreActif = actif
        .._ecritPour = null;
    }
  }

  set bordDroit(double bord) {
    if (bord == _bordDroit) return;
    _bordDroit = bord;
    for (final bloc in _blocs.values) {
      bloc
        .._bordDroit = bord
        .._ecritPour = null;
    }
  }

  /// Où poser 👍 et 👎 de chaque ligne jugeable, en coordonnées de page :
  /// à gauche de la ligne, sinon dessous, dessus, ou après son résultat ;
  /// jamais sur l'encre, un résultat ou les boutons d'une autre ligne
  /// (téléphone d'Antsa en paysage : posés sur les bornes d'une limite).
  /// Sans place libre, la ligne n'en a pas : ils se replient.
  ///
  /// [taille] : les deux boutons, en unités de page ; [gauche] : le bord
  /// gauche de l'écran.
  Map<BlocCalcul, Rect> placesJugement({
    required Size taille,
    required bool approcheVoulue,
    required bool virgule,
    double gauche = double.negativeInfinity,
  }) {
    final ecrits = _blocs.values.where((b) => !b.estSaisie).toList()
      ..sort(
        (a, b) => a.cadre.top != b.cadre.top
            ? a.cadre.top.compareTo(b.cadre.top)
            : a.cadre.left.compareTo(b.cadre.left),
      );
    final resultats = {
      for (final b in ecrits)
        b: b.ecriture(approcheVoulue: approcheVoulue, virgule: virgule)?.cadre,
    };
    final obstacles = [
      for (final b in ecrits) b.cadre,
      ...resultats.values.nonNulls,
    ];
    const ecart = BlocCalcul._ecart;
    final (l, h) = (taille.width, taille.height);
    final places = <BlocCalcul, Rect>{};
    for (final b in ecrits.where((b) => b.jugeable)) {
      final c = b.cadre;
      final r = resultats[b];
      final apres = math.max(c.right, r?.right ?? c.right);
      final essais = [
        Rect.fromLTWH(c.left - l - ecart, c.center.dy - h / 2, l, h),
        Rect.fromLTWH(c.left - l - ecart, c.top, l, h),
        Rect.fromLTWH(c.left - l - ecart, c.bottom - h, l, h),
        Rect.fromLTWH(c.left, c.bottom + ecart, l, h),
        Rect.fromLTWH(c.left, c.top - h - ecart, l, h),
        Rect.fromLTWH(apres + ecart, c.center.dy - h / 2, l, h),
        // Un résultat passé dessous (bord de l'écran) : à côté de lui, ou
        // sous lui (téléphone en portrait).
        if (r != null) ...[
          Rect.fromLTWH(r.right + ecart, r.center.dy - h / 2, l, h),
          Rect.fromLTWH(c.left, math.max(c.bottom, r.bottom) + ecart, l, h),
        ],
      ];
      final place = essais.where((e) {
        if (e.left < gauche || e.right > _bordDroit) return false;
        return !obstacles.any((o) => o.inflate(ecart).overlaps(e));
      }).firstOrNull;
      if (place == null) continue;
      places[b] = place;
      obstacles.add(place);
    }
    return places;
  }

  /// Un résultat ne s'écrit pas sur la ligne d'en dessous.
  void _placerResultats() {
    for (final bloc in _blocs.values) {
      if (bloc._auPropreActif != _auPropre) {
        bloc
          .._auPropreActif = _auPropre
          .._ecritPour = null;
      }
      // Une ligne arrivée après le dernier changement de largeur (document
      // ouvert, nouvelle ligne) connaît aussi le bord de la page.
      if (bloc._bordDroit != _bordDroit) {
        bloc
          .._bordDroit = _bordDroit
          .._ecritPour = null;
      }
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
    // L'ordre où les résultats se posent : de haut en bas, puis de gauche à
    // droite. Chacun évite ceux d'avant.
    final ordre = _blocs.values.where((b) => !b.estSaisie).toList()
      ..sort(
        (a, b) => a.cadre.top != b.cadre.top
            ? a.cadre.top.compareTo(b.cadre.top)
            : a.cadre.left.compareTo(b.cadre.left),
      );
    for (var i = 0; i < ordre.length; i++) {
      ordre[i]._avant = ordre.sublist(0, i);
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
    // Un `=` qui ferme la ligne demande le résultat : lu presque aussitôt
    // (idée de Mikajy, GPL-3.0).
    final attente = _finitParUnEgal() && pause > _apresEgal
        ? _apresEgal
        : pause;
    _minuteur = Timer(attente, () => unawaited(_lireLesNouveaux()));
    // Chaque signe se lit dès qu'il est fini : le stylet levé, et rien de
    // nouveau depuis un instant (ADR 0041).
    _dernierTrait = DateTime.now();
    _minuteurSignes?.cancel();
    unawaited(_lireLesSignes(finis: true));
    if (pauseConnue < attente) {
      _minuteurSignes = Timer(_signeFini, () => unawaited(_lireLesSignes()));
    }
  }

  static const _signeFini = Duration(milliseconds: 250);

  /// Classe les signes des traits pas encore lus. Si chaque ligne se lit
  /// déjà au tracé, la lecture n'attend plus toute la pause.
  ///
  /// [finis] : seulement les signes que le dernier trait ne touche pas,
  /// sitôt ce trait posé ; ils ne changeront plus.
  Future<void> _lireLesSignes({bool finis = false}) async {
    if (_ferme) return;
    final dernier = finis ? _ecrits.lastOrNull : null;
    final pris = {
      for (final b in _blocs.values)
        if (_compterPoints(_traitsDe(b)) == b._points) ...b.traits,
    };
    final nouveaux = _ecrits.where((t) => !pris.contains(t.id)).toList();
    if (nouveaux.isEmpty) return;
    final top = Stopwatch()..start();
    final lignes = grouperTraits(nouveaux);
    var toutesLues = true;
    for (final ligne in lignes) {
      final signes = signesDeLaLigne(ligne);
      for (final signe in signes) {
        if (dernier != null && signe.contains(dernier)) continue;
        await classeur.preparer(
          signe,
          caseLigne: caseDansLaLigne(signe, signes),
        );
      }
      if (finis) continue;
      if (avecClasseur(classeur, () => lireAuTrace(ligne)) == null) {
        toutesLues = false;
      }
    }
    final enAttente = _minuteur?.isActive ?? false;
    if (finis || _ferme || !toutesLues || !enAttente) return;
    // Un trait de plus entre-temps : sa propre attente compte.
    final ecoule = DateTime.now().difference(_dernierTrait);
    if (ecoule < _signeFini) return;
    _minuteur?.cancel();
    final reste = pauseConnue - ecoule;
    // Un print : c'est bien le journal local qu'on veut, rien d'autre.
    // ignore: avoid_print
    print(
      'fikajiana.lecture signes prêts en ${top.elapsedMilliseconds} ms, '
      'pause réduite à ${pauseConnue.inMilliseconds} ms',
    );
    _minuteur = Timer(
      reste.isNegative ? Duration.zero : reste,
      () => unawaited(_lireLesNouveaux()),
    );
  }

  static const _apresEgal = Duration(milliseconds: 250);

  /// Les deux derniers traits font un `=`, au bout de leur ligne.
  bool _finitParUnEgal() {
    final traits = _ecrits.toList();
    if (traits.length < 3) return false;
    final a = cadreDuGroupe([traits[traits.length - 2]]);
    final b = cadreDuGroupe([traits.last]);
    bool plat(Rect c) => c.width >= 6 && c.height <= 0.35 * c.width;
    if (!plat(a) || !plat(b)) return false;
    final commun = math.min(a.right, b.right) - math.max(a.left, b.left);
    final ecart = (a.center.dy - b.center.dy).abs();
    if (commun < 0.5 * math.min(a.width, b.width) ||
        ecart < 2 ||
        ecart > math.max(a.width, b.width)) {
      return false;
    }
    final egal = a.expandToInclude(b);
    // Rien après lui sur la même ligne : il ferme le calcul.
    return !traits.take(traits.length - 2).any((t) {
      final c = cadreDuGroupe([t]);
      return c.left > egal.right &&
          c.center.dy > egal.top - 2 * egal.height &&
          c.center.dy < egal.bottom + 2 * egal.height;
    });
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
    // Les grands groupes d'abord : un Σ avant ses bornes, `lim` avant
    // `x → 0`, pour que la borne trouve son signe.
    grouperTraits(nouveaux)
      ..sort(
        (a, b) => cadreDuGroupe(b).height.compareTo(cadreDuGroupe(a).height),
      )
      ..forEach(_rattacherGroupe);
  }

  /// Un groupe de traits rejoint le bloc qu'il prolonge, ou en fait un.
  void _rattacherGroupe(List<Trait> groupe) {
    final cadre = cadreDuGroupe(groupe);
    final ecrits = _blocs.values.where((b) => !b.estSaisie).toList();
    // Sa propre ligne d'abord : un bout de `7⁹ =` n'est pas une borne de la
    // ligne du dessus, même s'il en est assez près (Pad 7 d'Antsa).
    final hote =
        ecrits
            .where((b) => prolonge(b.cadre, cadre, ferme: b.finitParEgal))
            .firstOrNull ??
        ecrits
            .where(
              (b) =>
                  estDenominateur(b.cadre, groupe) ||
                  estBorne(b.cadre, _traitsDe(b), groupe),
            )
            .firstOrNull;
    final bloc =
        hote ??
        BlocCalcul(cle: 'bloc-${_compteur++}-${groupe.first.id}', cadre: cadre);
    bloc.traits.addAll(groupe.map((t) => t.id));
    // Le cadre suit tout de suite : la borne suivante voit le bloc entier.
    if (hote != null) bloc.cadre = bloc.cadre.expandToInclude(cadre);
    _blocs[bloc.cle] = bloc;
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
    // Relue, la ligne n'est plus jugée ; sauf si elle vient d'être corrigée.
    final retenir = bloc._retenirApresRelecture;
    bloc
      ..juge = null
      .._retenirApresRelecture = false
      .._points = _compterPoints(traits)
      ..cadre = cadreDuGroupe(traits)
      ..etat = EtatBloc.lecture
      ..note = null
      .._oublierResultat();
    notifyListeners();
    try {
      final (trouves, calcules) = (classeur.trouves, classeur.calcules);
      final (msModele, signesModele) = (
        classeur.msModele,
        classeur.signesModele,
      );
      // Le modèle par signe, s'il est là : ce qu'il n'a pas encore vu.
      if (classeur.modele != null) await _preparerSignes(traits);
      final chrono = Stopwatch()..start();
      // Ce qui sort d'une seule ligne se lit par morceaux (ADR 0029).
      final structuree = await avecClasseur(
        classeur,
        () => lireStructure(lecteur, traits),
      );
      final tempsStructure = chrono.elapsedMicroseconds;
      // `AB =` : deux points de la feuille, lus à leur tracé (Pad 7).
      final nomDePoints = structuree == null
          ? lireNomDePoints(traits, _contextePour(bloc).points.keys.toSet())
          : null;
      // Une ligne simple se lit sur son tracé, sans le modèle (ADR 0035).
      final detail = structuree == null && nomDePoints == null
          ? avecClasseur(classeur, () => lireAuTraceDetaille(traits))
          : null;
      var tracee = detail?.latex;
      final tempsTrace = chrono.elapsedMicroseconds - tempsStructure;
      // `4=0` : personne n'écrit cela ; c'est `n = 0` mal vu (Pad 7).
      if (tracee != null && RegExp(r'^\d+=\d*$').hasMatch(tracee)) {
        tracee = null;
      }
      var latex =
          structuree ??
          nomDePoints ??
          tracee ??
          redresserEgal(traits, await lecteur.lire(traits));
      final tempsModele =
          chrono.elapsedMicroseconds - tempsStructure - tempsTrace;
      if (bloc._version != version || !identical(_blocs[bloc.cle], bloc)) {
        return;
      }
      final fonctions = _definitionsPour(bloc).keys.toSet();
      bloc
        ..autresLectures = const []
        ..signesLus = tracee == null ? const [] : detail!.signes;
      // Une lecture qui étonne : on en demande d'autres (ADR 0028). Ce coût
      // n'est payé que dans le doute.
      if (structuree == null &&
          tracee == null &&
          plausibilite(latex, fonctions: fonctions) < 0) {
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
      // Dans le journal de l'appareil seulement (logcat), pour comprendre une
      // lecture fausse : l'encre ne quitte pas l'appareil.
      final voie = structuree != null
          ? 'structure'
          : tracee != null
          ? 'tracé'
          : 'modèle';
      // Un print : c'est bien le journal local qu'on veut, rien d'autre.
      // ignore: avoid_print
      print(
        'fikajiana.lecture $voie (${trouverStructure(traits).runtimeType}) : '
        '$latex',
      );
      String ms(int us) => (us / 1000).toStringAsFixed(1);
      // Le temps de chaque voie, dans le même journal local.
      // ignore: avoid_print
      print(
        'fikajiana.lecture temps : structure ${ms(tempsStructure)} ms, '
        'tracé ${ms(tempsTrace)} ms '
        '(signes ${classeur.trouves - trouves} en cache, '
        '${classeur.calcules - calcules} calculés'
        '${classeur.modele == null ? '' : ', modèle par signe '
                  '${(classeur.msModele - msModele).toStringAsFixed(1)} ms '
                  'pour ${classeur.signesModele - signesModele}'}), '
        'Pix2Text ${ms(tempsModele)} ms',
      );
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
      // Un signe corrigé : la ligne relue est l'exemple (ADR 0042).
      final latexLu = bloc.latex;
      if (retenir &&
          latexLu != null &&
          bloc._version == version &&
          identical(_blocs[bloc.cle], bloc)) {
        bloc.juge = true;
        await classeur.ecritures?.corrigerLigne(
          traits,
          latexLu,
          cadreDuGroupe(traits),
          signes: _signesAvecCase(bloc),
        );
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
    if (!bloc.estSaisie) {
      // La lecture était fausse : jamais gardée comme juste ; la ligne
      // corrigée, elle, l'est (ADR 0042).
      final traits = _traitsDe(bloc);
      if (traits.isNotEmpty) {
        bloc.juge = true;
        unawaited(
          classeur.ecritures?.corrigerLigne(
            traits,
            latex,
            cadreDuGroupe(traits),
          ),
        );
      }
    }
    bloc
      ..note = null
      ..latex = latex
      ..corrige = !bloc.estSaisie
      .._oublierResultat();
    await _calculer(bloc);
    if (!_ferme) notifyListeners();
  }

  /// Les meilleures lectures d'un signe lu au tracé.
  Future<Classement> autresSignes(BlocCalcul bloc, List<Trait> signe) =>
      classeur.classer(
        signe,
        caseLigne: caseDansLaLigne(signe, [
          for (final (traits, _) in bloc.signesLus) traits,
        ]),
      );

  /// Le modèle classe les signes de [traits] qu'il n'a pas encore vus.
  Future<void> _preparerSignes(List<Trait> traits) async {
    for (final ligne in grouperTraits(traits)) {
      final signes = signesDeLaLigne(ligne);
      for (final signe in signes) {
        await classeur.preparer(
          signe,
          caseLigne: caseDansLaLigne(signe, signes),
        );
      }
    }
  }

  /// La personne dit ce qu'est [signe] : la ligne se relit, et l'exemple
  /// reste sur l'appareil pour les prochaines fois (ADR 0041).
  Future<void> corrigerSigne(
    BlocCalcul bloc,
    List<Trait> signe,
    String classe,
  ) async {
    bloc._retenirApresRelecture = true;
    await classeur.ecritures?.corrigerSigne(
      signe,
      classe,
      caseLigne: caseDansLaLigne(signe, [
        for (final (t, _) in bloc.signesLus) t,
      ]),
    );
    classeur.oublier();
    relire(bloc);
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
        // `AX=B` résolu : X sert aux lignes suivantes.
        final inconnue = a.inconnueMatrice;
        if (inconnue != null) contexte.valeurs[inconnue] = '(${a.giac})';
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
    // Ce qui n'a rien donné (une borne lue à part : `x → 0` sous `lim`,
    // `n = 0` sous Σ, Pad 7 d'Antsa) cherche un bloc à rejoindre, en
    // gardant son découpage d'origine : tout regrouper d'un coup fondait la
    // page en une matrice. Les lignes tapées et corrigées ne bougent pas.
    final orphelins = [
      for (final b in _blocs.values)
        if (!b.estSaisie &&
            !b.corrige &&
            (b.etat == EtatBloc.nonCompris || !b._compris))
          b,
    ];
    for (final b in orphelins) {
      _blocs.remove(b.cle);
    }
    orphelins.sort((a, b) => b.cadre.height.compareTo(a.cadre.height));
    for (final ancien in orphelins) {
      final groupe = _traitsDe(ancien);
      if (groupe.isEmpty) continue;
      _rattacherGroupe(groupe);
    }
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
      ..inconnueMatrice = analyse.inconnueMatrice
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
    } else if (reponse.erreur == null &&
        analyse.giac.startsWith('limit(') &&
        const {'undef', 'infinity'}.contains(exact)) {
      // Une limite qui n'existe pas (infini sans signe, ou rien) est une
      // réponse, pas une erreur (Pad 7 d'Antsa : `lim (x²−3)/(x−3)` en 3).
      bloc
        ..sansLimite = true
        ..etat = EtatBloc.fait;
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
    // Les voisins se connaissent dès l'ouverture : sinon chaque résultat se
    // posait comme si la ligne était seule sur la page.
    _placerResultats();
  }

  @override
  void dispose() {
    _ferme = true;
    _minuteur?.cancel();
    _minuteurSignes?.cancel();
    super.dispose();
  }
}
