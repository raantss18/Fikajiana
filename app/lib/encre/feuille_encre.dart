import 'dart:async';

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/encre/vue_feuille.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _rayonGomme = 18;
const Duration _dureeMaintien = Duration(milliseconds: 450);
const double _bougeMaintien = 6;
const Duration _dureeAnimation = Duration(milliseconds: 340);

/// Zone d'écriture au stylet ou au doigt, sur une page sans bord.
///
/// - Au stylet : le stylet écrit, les doigts déplacent et zooment.
/// - Au doigt seul : un doigt écrit, deux doigts déplacent et zooment.
///
/// Dès qu'un stylet a servi, le doigt n'écrit plus. Le bouton du stylet, son
/// bout gomme ou [gomme] effacent les traits touchés.
class FeuilleEncre extends StatefulWidget {
  const new({
    required this.encre,
    required this.libelle,
    this.vue,
    this.support = SupportEcriture.feuilleBlanche,
    this.stylo = 0,
    this.gomme = false,
    this.surChangement,
    this.surRature,
    this.ciblesRature,
    this.doigtDefile = false,
    this.surStylet,
    super.key,
  });

  final Encre encre;
  final String libelle;
  final VueFeuille? vue;
  final SupportEcriture support;
  final int stylo;
  final bool gomme;
  final VoidCallback? surChangement;

  /// Une rature vient d'effacer quelque chose.
  final VoidCallback? surRature;

  /// Les traits à emporter en plus, pour une rature sur ce rectangle de page :
  /// ceux d'un calcul dont on rature le résultat.
  final Set<int> Function(Rect)? ciblesRature;

  /// Le doigt, et donc la main, ne fait que déplacer la page : un stylet a déjà
  /// servi sur cet appareil.
  final bool doigtDefile;

  /// Un stylet vient de toucher ou de survoler la feuille.
  final VoidCallback? surStylet;

  @override
  State<FeuilleEncre> createState() => _FeuilleEncreState();
}

class _FeuilleEncreState extends State<FeuilleEncre>
    with SingleTickerProviderStateMixin {
  /// Après le stylet, le temps de lever la main sans déplacer la page.
  static const _delaiMain = Duration(milliseconds: 400);

  /// Les traits qui s'en vont, et ceux qui vont ailleurs : (avant, après).
  var _partants = <Trait>[];
  var _trajets = <(Trait, Trait)>[];
  late final AnimationController _animation =
      AnimationController(vsync: this, duration: _dureeAnimation)
        ..addStatusListener((etat) {
          if (etat == AnimationStatus.completed && mounted) {
            setState(() {
              _partants = [];
              _trajets = [];
            });
          }
        });
  late final VueFeuille _vueLocale = VueFeuille();
  VueFeuille get _vue => widget.vue ?? _vueLocale;

  var _styletVu = false;
  var _gomme = false;
  int? _pointeur;

  /// Le pointeur en cours est le stylet, pas un doigt.
  var _pointeurStylet = false;

  /// Le dernier signe de vie du stylet, posé ou survolant : juste autour, le
  /// doigt qui bouge est la main qui écrit, pas un défilement.
  Duration? _styletProche;
  Offset _positionPointeur = Offset.zero;
  Timer? _maintien;
  Offset _ancre = Offset.zero;

  /// Doigts qui déplacent ou zooment, avec leur dernière position.
  final Map<int, Offset> _doigts = {};

  @override
  void initState() {
    super.initState();
    widget.encre.surDeplacement = _surDeplacement;
  }

  @override
  void didUpdateWidget(FeuilleEncre ancien) {
    super.didUpdateWidget(ancien);
    if (!identical(ancien.encre, widget.encre)) {
      ancien.encre.surDeplacement = null;
      widget.encre.surDeplacement = _surDeplacement;
    }
  }

  bool get _animer => !MediaQuery.disableAnimationsOf(context);

  void _surDeplacement(List<(Trait, Trait)> paires) {
    if (!mounted) return;
    setState(() {
      if (!_animer) return;
      _trajets = paires;
      _animation.forward(from: 0);
    });
  }

  void _raturer() {
    final rature = widget.encre.raturerDernierTrait(
      enPlus: widget.ciblesRature,
    );
    if (rature == null) return;
    unawaited(HapticFeedback.lightImpact());
    if (_animer) {
      _partants = [rature.trait, ...rature.emportes];
      _animation.forward(from: 0);
    }
    widget.surRature?.call();
  }

  void _armerMaintien(Offset position) {
    _ancre = position;
    _maintien?.cancel();
    _maintien = Timer(_dureeMaintien, () {
      if (!mounted || _pointeur == null || _gomme) return;
      if (widget.encre.formerDernierTrait()) {
        unawaited(HapticFeedback.selectionClick());
        _changer(() {});
      }
    });
  }

  @override
  void dispose() {
    _maintien?.cancel();
    if (identical(widget.encre.surDeplacement, _surDeplacement)) {
      widget.encre.surDeplacement = null;
    }
    _animation.dispose();
    _vueLocale.dispose();
    super.dispose();
  }

  bool _estStylet(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus ||
      e.kind == PointerDeviceKind.invertedStylus;

  bool _estGomme(PointerEvent e) =>
      widget.gomme ||
      e.kind == PointerDeviceKind.invertedStylus ||
      e.buttons & kSecondaryStylusButton != 0;

  PointEncre _point(PointerEvent e) {
    final page = _vue.versPage(e.localPosition);
    return PointEncre(
      page.dx,
      page.dy,
      e.pressure,
      tempsMs: e.timeStamp.inMicroseconds / 1000,
    );
  }

  void _changer(VoidCallback action) {
    setState(action);
    widget.surChangement?.call();
  }

  void _gommer(Offset ecran) {
    widget.encre.gommer(_vue.versPage(ecran), _rayonGomme / _vue.zoom);
  }

  void _baisser(PointerDownEvent e) {
    final stylet = _estStylet(e);
    if (stylet) {
      _signalerStylet(e.timeStamp);
      // La main posée avant le stylet n'écrit pas et ne déplace plus la page.
      _doigts.clear();
      // Un doigt avait commencé un trait : c'était la main.
      if (_pointeur != null && !_pointeurStylet) {
        _maintien?.cancel();
        if (!_gomme) widget.encre.abandonnerDernierTrait();
        _pointeur = null;
      }
    }
    if (!stylet && (_styletVu || widget.doigtDefile)) {
      // Pendant que le stylet écrit, la main ne fait rien ; sinon, elle défile.
      if (_pointeur == null) _doigts[e.pointer] = e.localPosition;
      return;
    }
    if (!stylet && _doigts.isNotEmpty) {
      _doigts[e.pointer] = e.localPosition;
      return;
    }
    if (!stylet && _pointeur != null) {
      _passerAuxDoigts(e);
      return;
    }
    if (_pointeur != null) return;
    _pointeurStylet = stylet;
    _pointeur = e.pointer;
    _positionPointeur = e.localPosition;
    _gomme = _estGomme(e);
    _changer(() {
      if (_gomme) {
        _gommer(e.localPosition);
      } else {
        widget.encre.commencer(
          _point(e),
          stylo: widget.stylo,
          auStylet: stylet,
        );
        _armerMaintien(e.localPosition);
      }
    });
  }

  /// Un second doigt arrive : ce qu'écrivait le premier n'était pas un trait.
  void _passerAuxDoigts(PointerDownEvent e) {
    _maintien?.cancel();
    _doigts[_pointeur!] = _positionPointeur;
    _doigts[e.pointer] = e.localPosition;
    _pointeur = null;
    _changer(() {
      if (!_gomme) widget.encre.abandonnerDernierTrait();
    });
  }

  void _deplacer(PointerMoveEvent e) {
    if (_doigts.containsKey(e.pointer)) {
      _bougerDoigt(e);
      return;
    }
    if (e.pointer != _pointeur) return;
    _positionPointeur = e.localPosition;
    _changer(() {
      if (_gomme) {
        _gommer(e.localPosition);
      } else {
        widget.encre.prolonger(_point(e));
        if ((e.localPosition - _ancre).distance > _bougeMaintien) {
          _armerMaintien(e.localPosition);
        }
      }
    });
  }

  void _signalerStylet(Duration quand) {
    _styletVu = true;
    _styletProche = quand;
    widget.surStylet?.call();
  }

  void _survoler(PointerHoverEvent e) {
    if (_estStylet(e)) _signalerStylet(e.timeStamp);
  }

  bool _styletTresProche(Duration maintenant) {
    if (_pointeur != null && _pointeurStylet) return true;
    final proche = _styletProche;
    return proche != null && maintenant - proche < _delaiMain;
  }

  void _bougerDoigt(PointerMoveEvent e) {
    final avant = _doigts[e.pointer]!;
    if (_doigts.length == 1) {
      _doigts[e.pointer] = e.localPosition;
      if (_styletTresProche(e.timeStamp)) return;
      _vue.glisser(e.localPosition - avant);
      return;
    }
    final autre = _doigts.entries.firstWhere((d) => d.key != e.pointer).value;
    final centreAvant = (avant + autre) / 2;
    final centre = (e.localPosition + autre) / 2;
    final distanceAvant = (avant - autre).distance;
    final distance = (e.localPosition - autre).distance;
    _doigts[e.pointer] = e.localPosition;
    _vue.glisser(centre - centreAvant);
    if (distanceAvant > 0 && distance > 0) {
      _vue.zoomer(distance / distanceAvant, centre);
    }
  }

  void _lever(PointerEvent e) {
    _doigts.remove(e.pointer);
    if (e.pointer != _pointeur) return;
    if (_pointeurStylet) _styletProche = e.timeStamp;
    _pointeur = null;
    _maintien?.cancel();
    if (!_gomme) {
      _changer(() {
        widget.encre.terminer();
        _raturer();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.libelle,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _baisser,
        onPointerHover: _survoler,
        onPointerMove: _deplacer,
        onPointerUp: _lever,
        onPointerCancel: _lever,
        child: ClipRect(
          child: ListenableBuilder(
            listenable: _vue,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: PeintreSupport(
                      widget.support,
                      zoom: _vue.zoom,
                      decalage: _vue.decalage,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) => CustomPaint(
                    painter: _PeintreEncre(
                      traits: widget.encre.traits,
                      support: widget.support,
                      zoom: _vue.zoom,
                      decalage: _vue.decalage,
                      partants: _partants,
                      trajets: _trajets,
                      avancee: _animation.value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeintreEncre extends CustomPainter {
  const new({
    required this.traits,
    required this.support,
    required this.zoom,
    required this.decalage,
    this.partants = const [],
    this.trajets = const [],
    this.avancee = 0,
  });

  final List<Trait> partants;
  final List<(Trait, Trait)> trajets;
  final double avancee;
  final List<Trait> traits;
  final SupportEcriture support;
  final double zoom;
  final Offset decalage;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..translate(decalage.dx, decalage.dy)
      ..scale(zoom);
    final encre = Paint()..style = PaintingStyle.fill;
    final enRoute = {for (final (_, apres) in trajets) apres.id};
    for (final trait in traits) {
      if (enRoute.contains(trait.id)) continue;
      encre.color = support.stylos[trait.stylo];
      canvas.drawPath(trait.contour, encre);
    }
    // Les traits voyagent en douceur, freinés à l'arrivée.
    final t = Curves.easeOutCubic.transform(avancee);
    for (final (avant, apres) in trajets) {
      encre.color = support.stylos[apres.stylo];
      canvas.drawPath(_entre(avant, apres, t).contour, encre);
    }
    // Ce qui est raturé s'évapore : plus pâle, un peu plus haut.
    for (final trait in partants) {
      encre.color = support.stylos[trait.stylo].withValues(alpha: 1 - t);
      canvas.drawPath(trait.contour.shift(Offset(0, -10 * t)), encre);
    }
  }

  Trait _entre(Trait avant, Trait apres, double t) {
    if (avant.points.length != apres.points.length) return apres;
    return Trait.deplace(avant, [
      for (var i = 0; i < avant.points.length; i++)
        PointEncre(
          avant.points[i].x + (apres.points[i].x - avant.points[i].x) * t,
          avant.points[i].y + (apres.points[i].y - avant.points[i].y) * t,
          avant.points[i].pression,
          tempsMs: avant.points[i].tempsMs,
        ),
    ]);
  }

  @override
  bool shouldRepaint(_PeintreEncre ancien) =>
      !identical(ancien.traits, traits) ||
      ancien.support != support ||
      ancien.zoom != zoom ||
      ancien.decalage != decalage ||
      ancien.avancee != avancee;
}
