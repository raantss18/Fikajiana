import 'package:fikajiana/l10n/l10n.dart';

/// Une étape du tour : ce qu'on apprend, et de quoi le voir s'écrire
/// (chaque ligne : ce que la main écrit, puis le résultat de l'app).
class EtapeTour {
  const new({
    required this.cle,
    required this.titre,
    required this.phrase,
    required this.lignes,
  });

  final String cle;
  final String titre;
  final String phrase;
  final List<(String, String?)> lignes;
}

/// Le tour des usages de base, proposé après chaque mise à jour une fois
/// le modèle là (ADR 0045). Les résultats sont ceux que l'app écrit ; le
/// test du tour les recalcule.
List<EtapeTour> etapesTour(AppLocalizations l10n) {
  final ou = l10n.localeName.startsWith('fr') ? 'ou' : 'or';
  return [
    EtapeTour(
      cle: 'calcul',
      titre: l10n.tourCalculTitre,
      phrase: l10n.tourCalculPhrase,
      lignes: const [(r'2+3\times4=', '14')],
    ),
    EtapeTour(
      cle: 'exact',
      titre: l10n.tourExactTitre,
      phrase: l10n.tourExactPhrase,
      lignes: const [
        (r'\frac{1}{2}+\frac{1}{3}=', r'\frac{5}{6}'),
        (r'\sqrt{18}=', r'3\sqrt{2}'),
      ],
    ),
    EtapeTour(
      cle: 'equation',
      titre: l10n.tourEquationTitre,
      phrase: l10n.tourEquationPhrase,
      lignes: [('x^{2}-5x+6=0', 'x=2\\,\\mathrm{$ou}\\,x=3')],
    ),
    EtapeTour(
      cle: 'fonction',
      titre: l10n.tourFonctionTitre,
      phrase: l10n.tourFonctionPhrase,
      lignes: const [('f(x)=x^{2}-1', null), ('f(3)=', '8')],
    ),
    EtapeTour(
      cle: 'matrices',
      titre: l10n.tourMatricesTitre,
      phrase: l10n.tourMatricesPhrase,
      lignes: const [
        (r'A=\begin{pmatrix}1&2\\3&4\end{pmatrix}', null),
        (r'\det(A)=', '-2'),
      ],
    ),
    EtapeTour(
      cle: 'sommes',
      titre: l10n.tourSommesTitre,
      phrase: l10n.tourSommesPhrase,
      lignes: const [
        (r'\sum_{k=1}^{10}k^{2}=', '385'),
        (r'\lim_{x\to0}\frac{\sin x}{x}=', '1'),
      ],
    ),
    EtapeTour(
      cle: 'figure',
      titre: l10n.tourFigureTitre,
      phrase: l10n.tourFigurePhrase,
      lignes: const [('A(1;2)', null), ('B(4;6)', null)],
    ),
    EtapeTour(
      cle: 'juger',
      titre: l10n.tourJugerTitre,
      phrase: l10n.tourJugerPhrase,
      lignes: const [(r'30\times8=', '240')],
    ),
    EtapeTour(
      cle: 'suite',
      titre: l10n.tourSuiteTitre,
      phrase: l10n.tourSuitePhrase,
      lignes: const [('5!=', '120')],
    ),
  ];
}
