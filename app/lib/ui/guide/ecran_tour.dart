import 'package:fikajiana/guide/tour.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/ecriture_animee.dart';
import 'package:fikajiana/ui/guide/ecran_guide.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';

/// Le tour des usages de base : chaque étape s'écrit à la main sous les
/// yeux, puis son résultat (ADR 0045).
class EcranTour extends StatefulWidget {
  const new({super.key});

  @override
  State<EcranTour> createState() => _EcranTourState();
}

class _EcranTourState extends State<EcranTour> {
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _aller(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Retour à la Feuille, d'où que le tour ait été ouvert.
  void _finir() => Navigator.of(context).popUntil((route) => route.isFirst);

  void _ouvrirGuide() {
    Navigator.of(context)
      ..popUntil((route) => route.isFirst)
      ..push(RouteEcran((_) => const EcranGuide()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etapes = etapesTour(l10n);
    final derniere = _page == etapes.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tourTitre),
        automaticallyImplyLeading: false,
        actions: [
          if (!derniere)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _finir,
              child: Text(l10n.tourPasser),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  for (final (i, etape) in etapes.indexed)
                    _PageEtape(
                      key: ValueKey('tour.${etape.cle}'),
                      etape: etape,
                      numero: i + 1,
                      total: etapes.length,
                    ),
                ],
              ),
            ),
            _Points(page: _page, total: etapes.length),
            Padding(
              padding: const EdgeInsets.all(AppEspacement.md),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: AppEspacement.sm,
                runSpacing: AppEspacement.sm,
                children: [
                  if (_page > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => _aller(_page - 1),
                      child: Text(l10n.tourPrecedent),
                    ),
                  if (derniere) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _ouvrirGuide,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(l10n.tourOuvrirGuide),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _finir,
                      icon: const Icon(Icons.edit),
                      label: Text(l10n.tourCommencer),
                    ),
                  ] else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => _aller(_page + 1),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l10n.tourSuivant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageEtape extends StatelessWidget {
  const new({
    required this.etape,
    required this.numero,
    required this.total,
    super.key,
  });

  final EtapeTour etape;
  final int numero;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppEspacement.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.tourEtape(numero, total),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppEspacement.xxs),
              Semantics(
                header: true,
                child: Text(etape.titre, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: AppEspacement.sm),
              Text(etape.phrase, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppEspacement.md),
              // Un morceau de feuille, où l'exemple s'écrit.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppEspacement.md),
                  child: EcritureAnimee(
                    lignes: [
                      for (final (latex, resultat) in etape.lignes)
                        LigneEcrite(latex, resultat),
                    ],
                    hauteurChiffre: 34,
                    indiceRejouer: l10n.tourRejouer,
                    // La page finit de glisser avant le premier trait.
                    delai: const Duration(milliseconds: 350),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Où on en est : un point par étape, l'étape en cours allongée.
class _Points extends StatelessWidget {
  const new({required this.page, required this.total});

  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final immobile = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: immobile
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == page ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == page ? scheme.primary : scheme.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
