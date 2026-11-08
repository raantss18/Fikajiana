import 'package:fikajiana/geometrie/atelier.dart';
import 'package:fikajiana/guide/catalogue.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/ecriture_animee.dart';
import 'package:fikajiana/ui/geometrie/pictogrammes.dart';
import 'package:fikajiana/ui/guide/ecran_tour.dart';
import 'package:fikajiana/ui/navigation/destination.dart';
import 'package:fikajiana/ui/navigation/page_destination.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';

/// Le Guide : tout ce que l'app sait faire, à chercher et à essayer
/// (ADR 0036).
class EcranGuide extends StatefulWidget {
  const new({super.key});

  @override
  State<EcranGuide> createState() => _EcranGuideState();
}

class _EcranGuideState extends State<EcranGuide> {
  final _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  /// Revient à la Feuille et y pose l'exemple, ou ouvre la Figure avec
  /// l'outil choisi.
  void _essayer(EntreeGuide entree) {
    final services = PorteeServices.de(context);
    final navigateur = Navigator.of(context)
      ..popUntil((route) => route.isFirst);
    final outil = entree.outil;
    if (outil == null) {
      services.essais.demander(entree.lignes);
      return;
    }
    // Le curseur se crée par une question : on le choisit dans la Figure.
    if (outil != OutilGeo.curseur) services.atelier.outil = outil;
    navigateur.push(RouteDestination(Destination.figure));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final requete = _recherche.text;
    final trouvees = chercherGuide(catalogueGuide(l10n), requete);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.guide),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: l10n.accueil,
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppEspacement.md,
                  AppEspacement.sm,
                  AppEspacement.md,
                  AppEspacement.sm,
                ),
                child: TextField(
                  controller: _recherche,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.guideChercher,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: requete.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: l10n.guideEffacer,
                            onPressed: () => setState(_recherche.clear),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: trouvees.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppEspacement.lg),
                        child: Text(
                          l10n.guideRien,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppEspacement.md,
                          0,
                          AppEspacement.md,
                          AppEspacement.lg,
                        ),
                        children: [
                          if (requete.isEmpty) ...[
                            Text(
                              l10n.guideIntro,
                              style: theme.textTheme.bodyMedium,
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppEspacement.sm,
                                ),
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  onPressed: () => Navigator.of(
                                    context,
                                  ).push(RouteEcran((_) => const EcranTour())),
                                  icon: const Icon(Icons.draw_outlined),
                                  label: Text(l10n.guideTour),
                                ),
                              ),
                            ),
                          ],
                          for (final famille in FamilleGuide.values)
                            ..._famille(famille, trouvees, theme, l10n),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _famille(
    FamilleGuide famille,
    List<EntreeGuide> trouvees,
    ThemeData theme,
    AppLocalizations l10n,
  ) sync* {
    final entrees = trouvees.where((e) => e.famille == famille).toList();
    if (entrees.isEmpty) return;
    yield Padding(
      padding: const EdgeInsets.only(
        top: AppEspacement.md,
        bottom: AppEspacement.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(famille.titre(l10n), style: theme.textTheme.titleLarge),
      ),
    );
    for (final entree in entrees) {
      yield _CarteEntree(
        key: ValueKey('guide.${entree.cle}'),
        entree: entree,
        surEssayer: () => _essayer(entree),
      );
    }
  }
}

/// Une entrée : son titre, sa phrase, son exemple, et « Essayer ».
class _CarteEntree extends StatelessWidget {
  const new({required this.entree, required this.surEssayer, super.key});

  final EntreeGuide entree;
  final VoidCallback surEssayer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final outil = entree.outil;
    final titre = Text(entree.titre, style: theme.textTheme.titleMedium);
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: AppEspacement.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppEspacement.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (outil == null)
              titre
            else
              Row(
                children: [
                  Pictogramme(outil),
                  const SizedBox(width: AppEspacement.sm),
                  Expanded(child: titre),
                ],
              ),
            const SizedBox(height: AppEspacement.xxs),
            Text(entree.phrase, style: theme.textTheme.bodyMedium),
            if (entree.lignes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppEspacement.sm),
                child: EcritureAnimee(
                  lignes: [for (final l in entree.lignes) LigneEcrite(l)],
                  indiceRejouer: l10n.guideRejouer,
                ),
              ),
            if (entree.essayable)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppEspacement.sm),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: surEssayer,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      l10n.guideEssayer,
                      // TalkBack dit ce qu'on essaie, pas « Essayer » seul.
                      semanticsLabel: '${l10n.guideEssayer} : ${entree.titre}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
