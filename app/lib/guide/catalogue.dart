import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/geometrie/panneaux.dart';

/// Les familles du Guide, dans l'ordre où elles s'affichent.
enum FamilleGuide {
  calcul,
  fonctions,
  equations,
  suites,
  matrices,
  limites,
  statistiques,
  arithmetique,
  points,
  courbes,
  figure,
  gestes,
  feuille,
  reglages;

  String titre(AppLocalizations l10n) => switch (this) {
    calcul => l10n.guideFamilleCalcul,
    fonctions => l10n.guideFamilleFonctions,
    equations => l10n.guideFamilleEquations,
    suites => l10n.guideFamilleSuites,
    matrices => l10n.guideFamilleMatrices,
    limites => l10n.guideFamilleLimites,
    statistiques => l10n.guideFamilleStatistiques,
    arithmetique => l10n.guideFamilleArithmetique,
    points => l10n.guideFamillePoints,
    courbes => l10n.guideFamilleCourbes,
    figure => l10n.guideFamilleFigure,
    gestes => l10n.guideFamilleGestes,
    feuille => l10n.guideFamilleFeuille,
    reglages => l10n.guideFamilleReglages,
  };
}

/// Une chose que l'app sait faire : un titre, une phrase, un exemple.
class EntreeGuide {
  new({
    required this.cle,
    required this.famille,
    required this.titre,
    required this.phrase,
    this.lignes = const [],
    this.motsCles = '',
    this.outil,
  });

  /// Stable, pour les tests et la recherche.
  final String cle;
  final FamilleGuide famille;
  final String titre;
  final String phrase;

  /// L'exemple, en LaTeX, une ligne de la Feuille par élément : ce que lit
  /// aussi l'écriture à la main. « Essayer » les pose dans cet ordre.
  final List<String> lignes;

  /// Ce qu'on pourrait chercher sans le trouver dans le titre.
  final String motsCles;

  /// L'outil de la Figure que « Essayer » choisit.
  final OutilGeo? outil;

  /// « Essayer » a quelque chose à faire.
  bool get essayable => lignes.isNotEmpty || outil != null;

  /// Tout ce qui se cherche, sans accent ni casse.
  late final String _cherchable = sansAccents(
    [titre, phrase, motsCles, famille.name, ...lignes].join(' '),
  );

  /// [requete] se trouve ici : en entier (« ecart type » trouve
  /// `écart-type`), ou chacun de ses mots.
  bool correspond(String requete) {
    final mots = sansAccents(requete).split(' ').where((m) => m.isNotEmpty);
    if (mots.isEmpty) return true;
    final colle = _cherchable.replaceAll(' ', '');
    return colle.contains(mots.join()) || mots.every(_cherchable.contains);
  }
}

/// Minuscules, sans accent, et tout ce qui n'est ni lettre ni chiffre devient
/// une espace : `Écart-type` → `ecart type`.
String sansAccents(String texte) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'î': 'i', 'ï': 'i', 'í': 'i', //
    'ô': 'o', 'ö': 'o', 'ó': 'o', //
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
    'ç': 'c', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae', //
  };
  final b = StringBuffer();
  for (final c in texte.toLowerCase().split('')) {
    final lettre = accents[c] ?? c;
    b.write(RegExp('[a-z0-9]').hasMatch(lettre) ? lettre : ' ');
  }
  return b.toString().replaceAll(RegExp(' +'), ' ').trim();
}

/// Les entrées de [catalogueGuide] que [requete] retrouve.
List<EntreeGuide> chercherGuide(List<EntreeGuide> tout, String requete) => [
  for (final e in tout)
    if (e.correspond(requete)) e,
];

// Les exemples, en LaTeX : ce que donne la saisie au clavier (`lireSaisie`)
// ou ce que lit le modèle. Un test les pose tous sur une Feuille.
const _matriceA = r'A=\begin{pmatrix}1&2\\3&4\end{pmatrix}';
const _pointA = 'A(1;2)';
const _pointB = 'B(4;6)';
const _triangleA = 'A(0;0)';
const _triangleB = 'B(4;0)';
const _triangleC = 'C(1;3)';
const _triangleD = 'D(4;3)';

/// Tout ce que l'app sait faire, dans la langue de [l10n].
List<EntreeGuide> catalogueGuide(AppLocalizations l10n) => [
  // Calcul.
  EntreeGuide(
    cle: 'operations',
    famille: FamilleGuide.calcul,
    titre: l10n.guideOperationsTitre,
    phrase: l10n.guideOperationsPhrase,
    motsCles: l10n.guideOperationsMots,
    lignes: [r'2+3\cdot 4=', r'(2+3)\cdot 4='],
  ),
  EntreeGuide(
    cle: 'egal',
    famille: FamilleGuide.calcul,
    titre: l10n.guideEgalTitre,
    phrase: l10n.guideEgalPhrase,
    motsCles: l10n.guideEgalMots,
    lignes: [r'12\cdot 7'],
  ),
  EntreeGuide(
    cle: 'fractions',
    famille: FamilleGuide.calcul,
    titre: l10n.guideFractionsTitre,
    phrase: l10n.guideFractionsPhrase,
    motsCles: l10n.guideFractionsMots,
    lignes: [r'\frac{1}{3}+\frac{1}{6}='],
  ),
  EntreeGuide(
    cle: 'puissances',
    famille: FamilleGuide.calcul,
    titre: l10n.guidePuissancesTitre,
    phrase: l10n.guidePuissancesPhrase,
    motsCles: l10n.guidePuissancesMots,
    lignes: ['2^{10}=', '5!='],
  ),
  EntreeGuide(
    cle: 'racines',
    famille: FamilleGuide.calcul,
    titre: l10n.guideRacinesTitre,
    phrase: l10n.guideRacinesPhrase,
    motsCles: l10n.guideRacinesMots,
    lignes: [r'\sqrt{18}='],
  ),
  EntreeGuide(
    cle: 'approche',
    famille: FamilleGuide.calcul,
    titre: l10n.guideApprocheTitre,
    phrase: l10n.guideApprochePhrase,
    motsCles: l10n.guideApprocheMots,
    lignes: [r'\sqrt{2}+\pi='],
  ),
  EntreeGuide(
    cle: 'arrondi',
    famille: FamilleGuide.calcul,
    titre: l10n.guideArrondiTitre,
    phrase: l10n.guideArrondiPhrase,
    motsCles: l10n.guideArrondiMots,
    lignes: [r'\text{arrondi}\left(\pi;3\right)'],
  ),
  // Fonctions.
  EntreeGuide(
    cle: 'fonction',
    famille: FamilleGuide.fonctions,
    titre: l10n.guideFonctionTitre,
    phrase: l10n.guideFonctionPhrase,
    motsCles: l10n.guideFonctionMots,
    lignes: ['f(x)=x^{2}-3x+1', r'f\left(2\right)='],
  ),
  EntreeGuide(
    cle: 'usuelles',
    famille: FamilleGuide.fonctions,
    titre: l10n.guideUsuellesTitre,
    phrase: l10n.guideUsuellesPhrase,
    motsCles: l10n.guideUsuellesMots,
    lignes: [r'\cos\left(\pi\right)=', r'\ln\left(1\right)='],
  ),
  EntreeGuide(
    cle: 'equadiff',
    famille: FamilleGuide.equations,
    titre: l10n.guideEquadiffTitre,
    phrase: l10n.guideEquadiffPhrase,
    motsCles: l10n.guideEquadiffMots,
    lignes: [r"y'-3y=\cos(x)"],
  ),
  EntreeGuide(
    cle: 'derivee',
    famille: FamilleGuide.fonctions,
    titre: l10n.guideDeriveeTitre,
    phrase: l10n.guideDeriveePhrase,
    motsCles: l10n.guideDeriveeMots,
    lignes: ['g(x)=x^{3}-2x', "g'(x)="],
  ),
  EntreeGuide(
    cle: 'tangente',
    famille: FamilleGuide.fonctions,
    titre: l10n.guideTangenteTitre,
    phrase: l10n.guideTangentePhrase,
    motsCles: l10n.guideTangenteMots,
    lignes: ['h(x)=x^{2}', r'\text{tangente}\left(h;1\right)'],
  ),
  EntreeGuide(
    cle: 'tracer',
    famille: FamilleGuide.fonctions,
    titre: l10n.guideTracerTitre,
    phrase: l10n.guideTracerPhrase,
    motsCles: l10n.guideTracerMots,
    lignes: ['y=2x+1'],
  ),
  EntreeGuide(
    cle: 'developper',
    famille: FamilleGuide.fonctions,
    titre: l10n.guideDevelopperTitre,
    phrase: l10n.guideDevelopperPhrase,
    motsCles: l10n.guideDevelopperMots,
    lignes: [r'\text{développer}\left(\left(x+1\right)^{2}\right)'],
  ),
  EntreeGuide(
    cle: 'factoriser',
    famille: FamilleGuide.fonctions,
    titre: l10n.guideFactoriserTitre,
    phrase: l10n.guideFactoriserPhrase,
    motsCles: l10n.guideFactoriserMots,
    lignes: [r'\text{factoriser}\left(x^{2}-1\right)'],
  ),
  EntreeGuide(
    cle: 'resoudre',
    famille: FamilleGuide.fonctions,
    titre: l10n.guideResoudreTitre,
    phrase: l10n.guideResoudrePhrase,
    motsCles: l10n.guideResoudreMots,
    lignes: [r'\text{résoudre}\left(x^{2}-4=0\right)'],
  ),
  EntreeGuide(
    cle: 'simplifier',
    famille: FamilleGuide.fonctions,
    titre: l10n.guideSimplifierTitre,
    phrase: l10n.guideSimplifierPhrase,
    motsCles: l10n.guideSimplifierMots,
    lignes: [r'\text{simplifier}\left(\frac{x^{2}-1}{x-1}\right)'],
  ),
  // Équations.
  EntreeGuide(
    cle: 'equation',
    famille: FamilleGuide.equations,
    titre: l10n.guideEquationTitre,
    phrase: l10n.guideEquationPhrase,
    motsCles: l10n.guideEquationMots,
    lignes: ['x^{2}-5x+6=0'],
  ),
  EntreeGuide(
    cle: 'discriminant',
    famille: FamilleGuide.equations,
    titre: l10n.guideDiscriminantTitre,
    phrase: l10n.guideDiscriminantPhrase,
    motsCles: l10n.guideDiscriminantMots,
    lignes: [r'\text{discriminant}\left(x^{2}-5x+6\right)'],
  ),
  EntreeGuide(
    cle: 'systeme',
    famille: FamilleGuide.equations,
    titre: l10n.guideSystemeTitre,
    phrase: l10n.guideSystemePhrase,
    motsCles: l10n.guideSystemeMots,
    lignes: [r'\begin{cases}x+y=3\\x-y=1\end{cases}'],
  ),
  // Suites.
  EntreeGuide(
    cle: 'suite',
    famille: FamilleGuide.suites,
    titre: l10n.guideSuiteTitre,
    phrase: l10n.guideSuitePhrase,
    motsCles: l10n.guideSuiteMots,
    lignes: ['u_{0}=1', 'u_{n+1}=2u_{n}+1', 'u_{5}='],
  ),
  // Matrices.
  EntreeGuide(
    cle: 'matrice',
    famille: FamilleGuide.matrices,
    titre: l10n.guideMatriceTitre,
    phrase: l10n.guideMatricePhrase,
    motsCles: l10n.guideMatriceMots,
    lignes: [_matriceA, r'\det\left(A\right)='],
  ),
  EntreeGuide(
    cle: 'inverse',
    famille: FamilleGuide.matrices,
    titre: l10n.guideInverseTitre,
    phrase: l10n.guideInversePhrase,
    motsCles: l10n.guideInverseMots,
    lignes: [_matriceA, 'A^{-1}='],
  ),
  EntreeGuide(
    cle: 'axb',
    famille: FamilleGuide.matrices,
    titre: l10n.guideAxbTitre,
    phrase: l10n.guideAxbPhrase,
    motsCles: l10n.guideAxbMots,
    lignes: [_matriceA, r'B=\begin{pmatrix}5\\6\end{pmatrix}', 'AX=B'],
  ),
  // Limites, sommes, intégrales.
  EntreeGuide(
    cle: 'limite',
    famille: FamilleGuide.limites,
    titre: l10n.guideLimiteTitre,
    phrase: l10n.guideLimitePhrase,
    motsCles: l10n.guideLimiteMots,
    lignes: [r'\lim_{x\to0}\frac{\sin x}{x}='],
  ),
  EntreeGuide(
    cle: 'somme',
    famille: FamilleGuide.limites,
    titre: l10n.guideSommeTitre,
    phrase: l10n.guideSommePhrase,
    motsCles: l10n.guideSommeMots,
    lignes: [r'\sum_{k=1}^{10}k^{2}='],
  ),
  EntreeGuide(
    cle: 'integrale',
    famille: FamilleGuide.limites,
    titre: l10n.guideIntegraleTitre,
    phrase: l10n.guideIntegralePhrase,
    motsCles: l10n.guideIntegraleMots,
    lignes: [r'\int_{0}^{1}x^{2}dx='],
  ),
  // Statistiques.
  EntreeGuide(
    cle: 'moyenne',
    famille: FamilleGuide.statistiques,
    titre: l10n.guideMoyenneTitre,
    phrase: l10n.guideMoyennePhrase,
    motsCles: l10n.guideMoyenneMots,
    lignes: [r'\text{moyenne}\left(2;4;9\right)'],
  ),
  EntreeGuide(
    cle: 'mediane',
    famille: FamilleGuide.statistiques,
    titre: l10n.guideMedianeTitre,
    phrase: l10n.guideMedianePhrase,
    motsCles: l10n.guideMedianeMots,
    lignes: [r'\text{médiane}\left(3;1;7;5\right)'],
  ),
  EntreeGuide(
    cle: 'variance',
    famille: FamilleGuide.statistiques,
    titre: l10n.guideVarianceTitre,
    phrase: l10n.guideVariancePhrase,
    motsCles: l10n.guideVarianceMots,
    lignes: [r'\text{variance}\left(2;4;9\right)'],
  ),
  EntreeGuide(
    cle: 'ecartType',
    famille: FamilleGuide.statistiques,
    titre: l10n.guideEcartTypeTitre,
    phrase: l10n.guideEcartTypePhrase,
    motsCles: l10n.guideEcartTypeMots,
    lignes: [r'\text{écart-type}\left(2;4;9\right)'],
  ),
  // Arithmétique.
  EntreeGuide(
    cle: 'pgcd',
    famille: FamilleGuide.arithmetique,
    titre: l10n.guidePgcdTitre,
    phrase: l10n.guidePgcdPhrase,
    motsCles: l10n.guidePgcdMots,
    lignes: [r'\text{pgcd}\left(12;18\right)'],
  ),
  EntreeGuide(
    cle: 'ppcm',
    famille: FamilleGuide.arithmetique,
    titre: l10n.guidePpcmTitre,
    phrase: l10n.guidePpcmPhrase,
    motsCles: l10n.guidePpcmMots,
    lignes: [r'\text{ppcm}\left(4;6\right)'],
  ),
  EntreeGuide(
    cle: 'premier',
    famille: FamilleGuide.arithmetique,
    titre: l10n.guidePremierTitre,
    phrase: l10n.guidePremierPhrase,
    motsCles: l10n.guidePremierMots,
    lignes: [r'\text{premier}\left(97\right)'],
  ),
  EntreeGuide(
    cle: 'decomposer',
    famille: FamilleGuide.arithmetique,
    titre: l10n.guideDecomposerTitre,
    phrase: l10n.guideDecomposerPhrase,
    motsCles: l10n.guideDecomposerMots,
    lignes: [r'\text{décomposer}\left(360\right)'],
  ),
  // Points et vecteurs.
  EntreeGuide(
    cle: 'point',
    famille: FamilleGuide.points,
    titre: l10n.guidePointTitre,
    phrase: l10n.guidePointPhrase,
    motsCles: l10n.guidePointMots,
    lignes: [_pointA],
  ),
  EntreeGuide(
    cle: 'vecteur',
    famille: FamilleGuide.points,
    titre: l10n.guideVecteurTitre,
    phrase: l10n.guideVecteurPhrase,
    motsCles: l10n.guideVecteurMots,
    lignes: [_pointA, _pointB, r'\vec{AB}='],
  ),
  EntreeGuide(
    cle: 'norme',
    famille: FamilleGuide.points,
    titre: l10n.guideNormeTitre,
    phrase: l10n.guideNormePhrase,
    motsCles: l10n.guideNormeMots,
    lignes: [_pointA, _pointB, r'\|\vec{AB}\|='],
  ),
  EntreeGuide(
    cle: 'construction',
    famille: FamilleGuide.points,
    titre: l10n.guideConstructionTitre,
    phrase: l10n.guideConstructionPhrase,
    motsCles: l10n.guideConstructionMots,
    lignes: [_pointA, _pointB, 'milieu(A;B)'],
  ),
  // Constructions et mesures de géométrie, sur le triangle A, B, C.
  EntreeGuide(
    cle: 'geo.parallele',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoParalleleTitre,
    phrase: l10n.guideGeoParallelePhrase,
    motsCles: l10n.guideGeoParalleleMots,
    lignes: [_triangleA, _triangleB, _triangleC, 'parallèle((AB);C)'],
  ),
  EntreeGuide(
    cle: 'geo.perpendiculaire',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoPerpendiculaireTitre,
    phrase: l10n.guideGeoPerpendiculairePhrase,
    motsCles: l10n.guideGeoPerpendiculaireMots,
    lignes: [_triangleA, _triangleB, _triangleC, 'perpendiculaire((AB);C)'],
  ),
  EntreeGuide(
    cle: 'geo.bissectrice',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoBissectriceTitre,
    phrase: l10n.guideGeoBissectricePhrase,
    motsCles: l10n.guideGeoBissectriceMots,
    lignes: [_triangleA, _triangleB, _triangleC, 'bissectrice(A;B;C)'],
  ),
  EntreeGuide(
    cle: 'geo.tangente',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoTangenteTitre,
    phrase: l10n.guideGeoTangentePhrase,
    motsCles: l10n.guideGeoTangenteMots,
    lignes: [
      _triangleA,
      _triangleB,
      _triangleC,
      'k=cercle(A;2)',
      'tangente(k;B)',
    ],
  ),
  EntreeGuide(
    cle: 'geo.symetrique',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoSymetriqueTitre,
    phrase: l10n.guideGeoSymetriquePhrase,
    motsCles: l10n.guideGeoSymetriqueMots,
    lignes: [_triangleA, _triangleB, _triangleC, "A'=symétrique(A;B)"],
  ),
  EntreeGuide(
    cle: 'geo.projete',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoProjeteTitre,
    phrase: l10n.guideGeoProjetePhrase,
    motsCles: l10n.guideGeoProjeteMots,
    lignes: [_triangleA, _triangleB, _triangleC, 'H=projeté(C;(AB))'],
  ),
  EntreeGuide(
    cle: 'geo.intersection',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoIntersectionTitre,
    phrase: l10n.guideGeoIntersectionPhrase,
    motsCles: l10n.guideGeoIntersectionMots,
    lignes: [
      _triangleA,
      _triangleB,
      _triangleC,
      _triangleD,
      'I=intersection((AC);(BD))',
    ],
  ),
  EntreeGuide(
    cle: 'geo.polygone',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoPolygoneTitre,
    phrase: l10n.guideGeoPolygonePhrase,
    motsCles: l10n.guideGeoPolygoneMots,
    lignes: [_triangleA, _triangleB, _triangleC, 'triangle(A;B;C)'],
  ),
  EntreeGuide(
    cle: 'geo.angle',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoAngleTitre,
    phrase: l10n.guideGeoAnglePhrase,
    motsCles: l10n.guideGeoAngleMots,
    lignes: [_triangleA, _triangleB, _triangleC, 'angle(A;B;C)='],
  ),
  EntreeGuide(
    cle: 'geo.aire',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoAireTitre,
    phrase: l10n.guideGeoAirePhrase,
    motsCles: l10n.guideGeoAireMots,
    lignes: [_triangleA, _triangleB, _triangleC, 'aire(ABC)='],
  ),
  EntreeGuide(
    cle: 'geo.perimetre',
    famille: FamilleGuide.points,
    titre: l10n.guideGeoPerimetreTitre,
    phrase: l10n.guideGeoPerimetrePhrase,
    motsCles: l10n.guideGeoPerimetreMots,
    lignes: [_triangleA, _triangleB, _triangleC, 'périmètre(ABC)='],
  ),
  EntreeGuide(
    cle: 'parametree',
    famille: FamilleGuide.courbes,
    titre: l10n.guideParametreeTitre,
    phrase: l10n.guideParametreePhrase,
    motsCles: l10n.guideParametreeMots,
    lignes: [r'\begin{cases}x=\cos(t)\\y=\sin(2t)\end{cases}'],
  ),
  // Courbes nommées.
  EntreeGuide(
    cle: 'courbe',
    famille: FamilleGuide.courbes,
    titre: l10n.guideCourbeTitre,
    phrase: l10n.guideCourbePhrase,
    motsCles: l10n.guideCourbeMots,
    lignes: ['C : x^{2}+y^{3}=0'],
  ),
  // Les outils de la Figure : leur nom et leur aide, ceux de la boîte.
  for (final outil in OutilGeo.values)
    EntreeGuide(
      cle: 'outil.${outil.name}',
      famille: FamilleGuide.figure,
      titre: outil.libelle(l10n),
      phrase: outil.aide(l10n),
      motsCles: titreGroupe(outil.groupe, l10n),
      outil: outil,
    ),
  // Gestes.
  EntreeGuide(
    cle: 'stylet',
    famille: FamilleGuide.gestes,
    titre: l10n.guideStyletTitre,
    phrase: l10n.guideStyletPhrase,
    motsCles: l10n.guideStyletMots,
  ),
  EntreeGuide(
    cle: 'doigt',
    famille: FamilleGuide.gestes,
    titre: l10n.guideDoigtTitre,
    phrase: l10n.guideDoigtPhrase,
    motsCles: l10n.guideDoigtMots,
  ),
  EntreeGuide(
    cle: 'deuxDoigts',
    famille: FamilleGuide.gestes,
    titre: l10n.guideDeuxDoigtsTitre,
    phrase: l10n.guideDeuxDoigtsPhrase,
    motsCles: l10n.guideDeuxDoigtsMots,
  ),
  EntreeGuide(
    cle: 'rature',
    famille: FamilleGuide.gestes,
    titre: l10n.guideRatureTitre,
    phrase: l10n.guideRaturePhrase,
    motsCles: l10n.guideRatureMots,
  ),
  EntreeGuide(
    cle: 'corriger',
    famille: FamilleGuide.gestes,
    titre: l10n.guideCorrigerTitre,
    phrase: l10n.guideCorrigerPhrase,
    motsCles: l10n.guideCorrigerMots,
  ),
  EntreeGuide(
    cle: 'mainLevee',
    famille: FamilleGuide.gestes,
    titre: l10n.guideMainLeveeTitre,
    phrase: l10n.aideMainLevee,
    motsCles: l10n.guideMainLeveeMots,
    outil: OutilGeo.mainLevee,
  ),
  // Outils de la Feuille.
  EntreeGuide(
    cle: 'clavier',
    famille: FamilleGuide.feuille,
    titre: l10n.guideClavierTitre,
    phrase: l10n.guideClavierPhrase,
    motsCles: l10n.guideClavierMots,
  ),
  EntreeGuide(
    cle: 'fond',
    famille: FamilleGuide.feuille,
    titre: l10n.guideFondTitre,
    phrase: l10n.guideFondPhrase,
    motsCles: l10n.guideFondMots,
  ),
  EntreeGuide(
    cle: 'gomme',
    famille: FamilleGuide.feuille,
    titre: l10n.guideGommeTitre,
    phrase: l10n.guideGommePhrase,
    motsCles: l10n.guideGommeMots,
  ),
  EntreeGuide(
    cle: 'selection',
    famille: FamilleGuide.feuille,
    titre: l10n.guideSelectionTitre,
    phrase: l10n.guideSelectionPhrase,
    motsCles: l10n.guideSelectionMots,
  ),
  EntreeGuide(
    cle: 'annuler',
    famille: FamilleGuide.feuille,
    titre: l10n.guideAnnulerTitre,
    phrase: l10n.guideAnnulerPhrase,
    motsCles: l10n.guideAnnulerMots,
  ),
  EntreeGuide(
    cle: 'relire',
    famille: FamilleGuide.feuille,
    titre: l10n.guideRelireTitre,
    phrase: l10n.guideRelirePhrase,
    motsCles: l10n.guideRelireMots,
  ),
  EntreeGuide(
    cle: 'degres',
    famille: FamilleGuide.feuille,
    titre: l10n.guideDegresTitre,
    phrase: l10n.guideDegresPhrase,
    motsCles: l10n.guideDegresMots,
  ),
  EntreeGuide(
    cle: 'zoom',
    famille: FamilleGuide.feuille,
    titre: l10n.guideZoomTitre,
    phrase: l10n.guideZoomPhrase,
    motsCles: l10n.guideZoomMots,
  ),
  EntreeGuide(
    cle: 'exporter',
    famille: FamilleGuide.feuille,
    titre: l10n.guideExporterTitre,
    phrase: l10n.guideExporterPhrase,
    motsCles: l10n.guideExporterMots,
  ),
  EntreeGuide(
    cle: 'juger',
    famille: FamilleGuide.feuille,
    titre: l10n.guideJugerTitre,
    phrase: l10n.guideJugerPhrase,
    motsCles: l10n.guideJugerMots,
  ),
  EntreeGuide(
    cle: 'signes',
    famille: FamilleGuide.feuille,
    titre: l10n.guideSignesTitre,
    phrase: l10n.guideSignesPhrase,
    motsCles: l10n.guideSignesMots,
  ),
  EntreeGuide(
    cle: 'autresLectures',
    famille: FamilleGuide.feuille,
    titre: l10n.guideAutresLecturesTitre,
    phrase: l10n.guideAutresLecturesPhrase,
    motsCles: l10n.guideAutresLecturesMots,
  ),
  // Réglages et documents.
  EntreeGuide(
    cle: 'auPropre',
    famille: FamilleGuide.reglages,
    titre: l10n.guideAuPropreTitre,
    phrase: l10n.guideAuProprePhrase,
    motsCles: l10n.guideAuPropreMots,
  ),
  EntreeGuide(
    cle: 'documents',
    famille: FamilleGuide.reglages,
    titre: l10n.guideDocumentsTitre,
    phrase: l10n.guideDocumentsPhrase,
    motsCles: l10n.guideDocumentsMots,
  ),
  EntreeGuide(
    cle: 'historique',
    famille: FamilleGuide.reglages,
    titre: l10n.guideHistoriqueTitre,
    phrase: l10n.guideHistoriquePhrase,
    motsCles: l10n.guideHistoriqueMots,
  ),
  EntreeGuide(
    cle: 'modele',
    famille: FamilleGuide.reglages,
    titre: l10n.guideModeleTitre,
    phrase: l10n.guideModelePhrase,
    motsCles: l10n.guideModeleMots,
  ),
  EntreeGuide(
    cle: 'miseAJour',
    famille: FamilleGuide.reglages,
    titre: l10n.guideMiseAJourTitre,
    phrase: l10n.guideMiseAJourPhrase,
    motsCles: l10n.guideMiseAJourMots,
  ),
  EntreeGuide(
    cle: 'ecritures',
    famille: FamilleGuide.reglages,
    titre: l10n.guideEcrituresTitre,
    phrase: l10n.guideEcrituresPhrase,
    motsCles: l10n.guideEcrituresMots,
  ),
  EntreeGuide(
    cle: 'dons',
    famille: FamilleGuide.reglages,
    titre: l10n.guideDonsTitre,
    phrase: l10n.guideDonsPhrase,
    motsCles: l10n.guideDonsMots,
  ),
  EntreeGuide(
    cle: 'tour',
    famille: FamilleGuide.reglages,
    titre: l10n.guideTourTitre,
    phrase: l10n.guideTourPhrase,
    motsCles: l10n.guideTourMots,
  ),
];
