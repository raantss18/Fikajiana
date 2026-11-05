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
    super.key,
  });

  final Encre encre;
  final String libelle;
  final VueFeuille? vue;
  final SupportEcriture support;
  final int stylo;
  final bool gomme;
  final VoidCallback? surChangement;

  @override
  State<FeuilleEncre> createState() => _FeuilleEncreState();
}

class _FeuilleEncreState extends State<FeuilleEncre> {
  late final VueFeuille _vueLocale = VueFeuille();
  VueFeuille get _vue => widget.vue ?? _vueLocale;

  var _styletVu = false;
  var _gomme = false;
  int? _pointeur;
  Offset _positionPointeur = Offset.zero;
  Timer? _maintien;
  Offset _ancre = Offset.zero;

  /// Doigts qui déplacent ou zooment, avec leur dernière position.
  final Map<int, Offset> _doigts = {};

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
    if (stylet) _styletVu = true;
    if (!stylet && _styletVu) {
      // La paume pendant l'écriture ne déplace pas la page.
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

  void _bougerDoigt(PointerMoveEvent e) {
    final avant = _doigts[e.pointer]!;
    if (_doigts.length == 1) {
      _doigts[e.pointer] = e.localPosition;
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
    _pointeur = null;
    _maintien?.cancel();
    if (!_gomme) _changer(widget.encre.terminer);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.libelle,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _baisser,
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
                CustomPaint(
                  painter: _PeintreEncre(
                    traits: widget.encre.traits,
                    support: widget.support,
                    zoom: _vue.zoom,
                    decalage: _vue.decalage,
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
  });

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
    for (final trait in traits) {
      encre.color = support.stylos[trait.stylo];
      canvas.drawPath(trait.contour, encre);
    }
  }

  @override
  bool shouldRepaint(_PeintreEncre ancien) =>
      !identical(ancien.traits, traits) ||
      ancien.support != support ||
      ancien.zoom != zoom ||
      ancien.decalage != decalage;
}
