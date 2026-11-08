import 'dart:async';

import 'package:fikajiana/comprendre/carnet.dart';
import 'package:fikajiana/guide/catalogue.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/ui/formule_affichee.dart';
import 'package:fikajiana/ui/services.dart';
import 'package:fikajiana/ui/theme/espacement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Comment l'Historique range les documents.
enum TriHistorique { recents, anciens, nom }

/// L'Historique : les documents gardés sur l'appareil, chacun sa feuille et
/// sa Figure (ADR 0032). Un document se renomme, se supprime (« Annuler »
/// le rend quelques secondes), et la liste se trie.
class EcranHistorique extends StatefulWidget {
  const new({super.key});

  @override
  State<EcranHistorique> createState() => _EcranHistoriqueState();
}

class _EcranHistoriqueState extends State<EcranHistorique> {
  TriHistorique _tri = TriHistorique.recents;

  void _revenir(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _supprimer(Carnet carnet, ApercuFeuille feuille) {
    final l10n = context.l10n;
    final etaitCourante = feuille.id == carnet.courante;
    carnet.supprimer(feuille.id);
    final messager = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    var rendu = false;
    unawaited(
      messager
          .showSnackBar(
            SnackBar(
              content: Text(l10n.historiqueSupprime),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
              persist: false,
              action: SnackBarAction(
                label: l10n.annuler,
                onPressed: () {
                  rendu = true;
                  carnet.restaurer(feuille.id, ouvrir: etaitCourante);
                },
              ),
            ),
          )
          .closed
          .then((_) {
            if (!rendu) carnet.oublierSupprime(feuille.id);
          }),
    );
  }

  Future<void> _renommer(Carnet carnet, ApercuFeuille feuille) async {
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => _DialogueNom(initial: feuille.nom ?? ''),
    );
    if (nom != null) carnet.renommer(feuille.id, nom);
  }

  String _nomTri(AppLocalizations l10n) => switch (_tri) {
    TriHistorique.recents => l10n.historiqueTriRecents,
    TriHistorique.anciens => l10n.historiqueTriAnciens,
    TriHistorique.nom => l10n.historiqueTriNom,
  };

  List<ApercuFeuille> _trier(List<ApercuFeuille> feuilles) {
    final liste = [...feuilles];
    switch (_tri) {
      case TriHistorique.recents:
        liste.sort((a, b) => b.modifiee.compareTo(a.modifiee));
      case TriHistorique.anciens:
        liste.sort((a, b) => a.modifiee.compareTo(b.modifiee));
      case TriHistorique.nom:
        // Les documents nommés d'abord, par nom ; les autres, par date.
        int rang(ApercuFeuille a) => a.nom == null ? 1 : 0;
        liste.sort(
          (a, b) => rang(a) != rang(b)
              ? rang(a) - rang(b)
              : a.nom != null
              ? sansAccents(a.nom!).compareTo(sansAccents(b.nom!))
              : b.modifiee.compareTo(a.modifiee),
        );
    }
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final services = PorteeServices.de(context);
    final carnet = services.carnet;
    final textes = MaterialLocalizations.of(context);
    String date(ApercuFeuille f) => [
      textes.formatMediumDate(f.modifiee),
      TimeOfDay.fromDateTime(f.modifiee).format(context),
    ].join(' · ');
    return ListenableBuilder(
      listenable: carnet,
      builder: (context, _) {
        final feuilles = _trier(carnet.apercus());
        return ListView(
          // Sous les boutons ← et Menu.
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 64,
            bottom: AppEspacement.lg,
          ),
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.nouveauDocument),
              onTap: () {
                carnet.nouvelle();
                _revenir(context);
              },
            ),
            // Le titre, et le tri à droite ; dessous si la place manque.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Titre(l10n.historiqueSectionFeuilles),
                if (feuilles.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppEspacement.sm,
                      right: AppEspacement.sm,
                      top: AppEspacement.sm,
                    ),
                    child: PopupMenuButton<TriHistorique>(
                      tooltip: l10n.historiqueTrier,
                      initialValue: _tri,
                      onSelected: (tri) => setState(() => _tri = tri),
                      itemBuilder: (_) => [
                        for (final (tri, nom) in [
                          (TriHistorique.recents, l10n.historiqueTriRecents),
                          (TriHistorique.anciens, l10n.historiqueTriAnciens),
                          (TriHistorique.nom, l10n.historiqueTriNom),
                        ])
                          CheckedPopupMenuItem(
                            value: tri,
                            checked: tri == _tri,
                            child: Text(nom),
                          ),
                      ],
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort),
                            const SizedBox(width: AppEspacement.xxs),
                            Flexible(
                              child: Text(
                                '${l10n.historiqueTrier} : ${_nomTri(l10n)}',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (final feuille in feuilles)
              ListTile(
                key: ValueKey(feuille.id),
                selected: feuille.id == carnet.courante,
                title: Text(
                  [
                    feuille.nom ?? date(feuille),
                    if (feuille.id == carnet.courante) l10n.historiqueEnCours,
                  ].join(' · '),
                ),
                subtitle: feuille.nom == null
                    ? _Apercu(feuille: feuille)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(date(feuille)),
                          _Apercu(feuille: feuille),
                        ],
                      ),
                trailing: PopupMenuButton<bool>(
                  tooltip: l10n.historiqueActions,
                  onSelected: (renommer) => renommer
                      ? unawaited(_renommer(carnet, feuille))
                      : _supprimer(carnet, feuille),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: true,
                      child: ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(l10n.historiqueRenommer),
                      ),
                    ),
                    PopupMenuItem(
                      value: false,
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: Text(l10n.historiqueSupprimer),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  carnet.ouvrir(feuille.id);
                  _revenir(context);
                },
              ),
            if (feuilles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppEspacement.lg),
                child: Text(
                  l10n.historiqueVide,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Le nom d'un document, dans une fenêtre qui garde son propre champ.
class _DialogueNom extends StatefulWidget {
  const new({required this.initial});

  final String initial;

  @override
  State<_DialogueNom> createState() => _DialogueNomState();
}

class _DialogueNomState extends State<_DialogueNom> {
  late final _champ = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.historiqueRenommerTitre),
      content: TextField(
        controller: _champ,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.historiqueNom),
        onSubmitted: (texte) => Navigator.of(context).pop(texte),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.annulerDialogue),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_champ.text),
          child: Text(l10n.historiqueRenommer),
        ),
      ],
    );
  }
}

class _Titre extends StatelessWidget {
  const new(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppEspacement.md,
        right: AppEspacement.md,
        top: AppEspacement.md,
      ),
      child: Semantics(
        header: true,
        child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _Apercu extends StatelessWidget {
  const new({required this.feuille});

  final ApercuFeuille feuille;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodyMedium;
    final Widget ecrit = feuille.calculs.isEmpty
        ? Text(
            feuille.estVide
                ? l10n.historiqueFeuilleVide
                : l10n.historiqueTraits(feuille.traits),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              pourAffichage(feuille.calculs.take(3).join(r'\quad ')),
              textStyle: style,
              onErrorFallback: (_) => Text(feuille.calculs.first, style: style),
            ),
          );
    // Sa Figure : la même ligne, puisqu'elle fait partie du document.
    if (feuille.courbes.isEmpty && feuille.objets == 0) return ecrit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ecrit,
        Text(
          l10n.historiqueFigure(
            [
              if (feuille.courbes.isNotEmpty)
                l10n.historiqueCourbes(feuille.courbes.length),
              if (feuille.objets > 0) l10n.historiqueObjets(feuille.objets),
            ].join(', '),
          ),
          style: style,
        ),
      ],
    );
  }
}
