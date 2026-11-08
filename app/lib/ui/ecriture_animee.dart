import 'dart:math' as math;

import 'package:fikajiana/comprendre/ecriture_resultat.dart';
import 'package:fikajiana/ui/formule_affichee.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Une ligne à écrire : ce que la main écrit, et le résultat que l'app
/// écrit à côté, s'il y en a un.
class LigneEcrite {
  const new(this.latex, [this.resultat]);

  final String latex;
  final String? resultat;
}

/// Une main posée : un trait par cinquième de seconde, jamais plus de deux
/// secondes pour une ligne.
const double _msParTrait = 200;
const double _msMin = 350;
const double _msMax = 2000;

/// Le temps de « réfléchir » avant que le résultat s'écrive.
const double _msPause = 300;
const double _interligne = 0.5;

/// Des lignes qui s'écrivent à la main, trait par trait, comme sur la
/// Feuille ; un toucher les réécrit. Sans animation si l'appareil le
/// demande. Ce que la main ne sait pas écrire s'affiche en formule.
class EcritureAnimee extends StatefulWidget {
  const new({
    required this.lignes,
    this.hauteurChiffre = 26,
    this.indiceRejouer,
    this.delai = Duration.zero,
    super.key,
  });

  final List<LigneEcrite> lignes;

  /// La hauteur d'un chiffre, en pixels logiques.
  final double hauteurChiffre;

  /// Ce que TalkBack annonce pour réécrire ; `null` : pas de réécriture.
  final String? indiceRejouer;

  /// Attente avant le premier trait (une page du tour qui arrive).
  final Duration delai;

  @override
  State<EcritureAnimee> createState() => _EcritureAnimeeState();
}

/// Un morceau écrit, à sa place, avec le moment où il commence et finit
/// (de 0 à 1 sur toute l’écriture).
typedef MorceauEcrit = ({
  EcritureResultat ecrit,
  Offset place,
  bool resultat,
  double debut,
  double fin,
});

class _EcritureAnimeeState extends State<EcritureAnimee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _temps = AnimationController(vsync: this);
  List<MorceauEcrit>? _morceaux;
  Size _taille = Size.zero;
  var _anime = false;

  @override
  void initState() {
    super.initState();
    _composer();
  }

  @override
  void didUpdateWidget(EcritureAnimee ancien) {
    super.didUpdateWidget(ancien);
    if (!_memesLignes(ancien.lignes, widget.lignes) ||
        ancien.hauteurChiffre != widget.hauteurChiffre) {
      _composer();
      _ecrire();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_anime) {
      _anime = true;
      _ecrire();
    }
  }

  static bool _memesLignes(List<LigneEcrite> a, List<LigneEcrite> b) =>
      a.length == b.length &&
      [
        for (var i = 0; i < a.length; i++)
          a[i].latex == b[i].latex && a[i].resultat == b[i].resultat,
      ].every((x) => x);

  void _composer() {
    final echelle = widget.hauteurChiffre;
    final morceaux = <MorceauEcrit>[];
    var y = 0.0;
    var largeur = 0.0;
    var t = widget.delai.inMilliseconds.toDouble();
    double duree(EcritureResultat e) =>
        (e.contours.length * _msParTrait).clamp(_msMin, _msMax);
    for (final ligne in widget.lignes) {
      // Tout se pose sur la même ligne d'écriture, en y = 0 ; la rangée est
      // ensuite descendue sous la précédente.
      final ecrit = ecrireALEchelle(
        ligne.latex,
        echelle,
        ligneDeBase: Offset.zero,
      );
      if (ecrit == null) {
        _morceaux = null;
        return;
      }
      final rangee = [(ecrit, false)];
      if (ligne.resultat case final resultat?) {
        // À la taille d'un chiffre, pas à celle d'un Σ et de ses bornes.
        final rendu = ecrireALEchelle(
          resultat,
          echelle * 0.85,
          ligneDeBase: Offset(ecrit.cadre.right + 0.3 * echelle, 0),
        );
        if (rendu == null) {
          _morceaux = null;
          return;
        }
        rangee.add((rendu, true));
      }
      final dessus = rangee.map((r) => r.$1.cadre.top).reduce(math.min);
      final dessous = rangee.map((r) => r.$1.cadre.bottom).reduce(math.max);
      final place = Offset(0, y - dessus);
      for (final (morceau, resultat) in rangee) {
        if (resultat) t += _msPause;
        morceaux.add((
          ecrit: morceau,
          place: place,
          resultat: resultat,
          debut: t,
          fin: t += duree(morceau),
        ));
        largeur = math.max(largeur, morceau.cadre.right);
      }
      y = place.dy + dessous + _interligne * echelle;
    }
    // Le haut d'un exposant ou d'une flèche peut monter au-dessus de 0.
    final haut = morceaux
        .map((m) => m.ecrit.cadre.top + m.place.dy)
        .fold<double>(0, math.min);
    _morceaux = [
      for (final m in morceaux)
        (
          ecrit: m.ecrit,
          place: m.place - Offset(0, haut),
          resultat: m.resultat,
          debut: m.debut / t,
          fin: m.fin / t,
        ),
    ];
    _taille = Size(largeur + 4, y - _interligne * echelle - haut + 4);
    _temps.duration = Duration(milliseconds: t.round());
  }

  void _ecrire() {
    if (_morceaux == null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _temps.value = 1;
      return;
    }
    _temps.forward(from: 0);
  }

  @override
  void dispose() {
    _temps.dispose();
    super.dispose();
  }

  String get _lu => widget.lignes
      .map(
        (l) => [
          texteDepuisLatex(l.latex),
          if (l.resultat case final r?) texteDepuisLatex(r),
        ].join(' '),
      )
      .join('\n');

  @override
  Widget build(BuildContext context) {
    final morceaux = _morceaux;
    final scheme = Theme.of(context).colorScheme;
    final Widget dessin;
    if (morceaux == null) {
      final style = Theme.of(context).textTheme.titleMedium;
      dessin = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in widget.lignes)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                pourAffichage(
                  l.resultat == null ? l.latex : '${l.latex}${l.resultat}',
                ),
                textStyle: style,
                onErrorFallback: (_) => Text(l.latex, style: style),
              ),
            ),
        ],
      );
    } else {
      dessin = Align(
        alignment: AlignmentDirectional.centerStart,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: AnimatedBuilder(
            animation: _temps,
            builder: (context, _) => CustomPaint(
              size: _taille,
              painter: PeintreEcriture(
                morceaux: morceaux,
                avancee: _temps.value,
                encre: scheme.onSurface,
                resultat: scheme.tertiary,
              ),
            ),
          ),
        ),
      );
    }
    final rejouer = widget.indiceRejouer;
    return Semantics(
      label: _lu,
      onTapHint: rejouer,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: rejouer == null || morceaux == null ? null : _ecrire,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 48,
              minWidth: double.infinity,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: dessin,
            ),
          ),
        ),
      ),
    );
  }
}

/// Peint les morceaux écrits jusqu’à [avancee], de 0 à 1.
class PeintreEcriture extends CustomPainter {
  const new({
    required this.morceaux,
    required this.avancee,
    required this.encre,
    required this.resultat,
  });

  final List<MorceauEcrit> morceaux;
  final double avancee;
  final Color encre;
  final Color resultat;

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in morceaux) {
      if (avancee <= m.debut) continue;
      final part = m.fin <= m.debut
          ? 1.0
          : ((avancee - m.debut) / (m.fin - m.debut)).clamp(0.0, 1.0);
      final pinceau = Paint()..color = m.resultat ? resultat : encre;
      canvas
        ..save()
        ..translate(m.place.dx + 2, m.place.dy + 2);
      for (final chemin in m.ecrit.ecrit(part)) {
        canvas.drawPath(chemin, pinceau);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(PeintreEcriture ancien) =>
      ancien.avancee != avancee ||
      ancien.morceaux != morceaux ||
      ancien.encre != encre ||
      ancien.resultat != resultat;
}
