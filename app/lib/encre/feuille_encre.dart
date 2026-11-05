import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reglages/support.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const double _epaisseur = 3;
const double _rayonGomme = 18;

/// Zone d'écriture au stylet ou au doigt.
///
/// Dès qu'un stylet a servi, le doigt et la paume n'écrivent plus. Le bouton du
/// stylet, son bout gomme ou [gomme] effacent les traits touchés.
class FeuilleEncre extends StatefulWidget {
  const new({
    required this.encre,
    required this.libelle,
    this.support = SupportEcriture.feuilleBlanche,
    this.stylo = 0,
    this.gomme = false,
    this.surChangement,
    super.key,
  });

  final Encre encre;
  final String libelle;
  final SupportEcriture support;
  final int stylo;
  final bool gomme;
  final VoidCallback? surChangement;

  @override
  State<FeuilleEncre> createState() => _FeuilleEncreState();
}

class _FeuilleEncreState extends State<FeuilleEncre> {
  var _styletVu = false;
  var _gomme = false;
  int? _pointeur;

  bool _estStylet(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus ||
      e.kind == PointerDeviceKind.invertedStylus;

  bool _estGomme(PointerEvent e) =>
      widget.gomme ||
      e.kind == PointerDeviceKind.invertedStylus ||
      e.buttons & kSecondaryStylusButton != 0;

  PointEncre _point(PointerEvent e) =>
      PointEncre(e.localPosition.dx, e.localPosition.dy, e.pressure);

  void _changer(VoidCallback action) {
    setState(action);
    widget.surChangement?.call();
  }

  void _baisser(PointerDownEvent e) {
    if (_estStylet(e)) _styletVu = true;
    if (_pointeur != null || (_styletVu && !_estStylet(e))) return;
    _pointeur = e.pointer;
    _gomme = _estGomme(e);
    _changer(() {
      if (_gomme) {
        widget.encre.gommer(e.localPosition, _rayonGomme);
      } else {
        widget.encre.commencer(_point(e), stylo: widget.stylo);
      }
    });
  }

  void _deplacer(PointerMoveEvent e) {
    if (e.pointer != _pointeur) return;
    _changer(() {
      if (_gomme) {
        widget.encre.gommer(e.localPosition, _rayonGomme);
      } else {
        widget.encre.prolonger(_point(e));
      }
    });
  }

  void _lever(PointerEvent e) {
    if (e.pointer == _pointeur) _pointeur = null;
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(painter: PeintreSupport(widget.support)),
              ),
              CustomPaint(
                painter: _PeintreEncre(
                  traits: widget.encre.traits,
                  support: widget.support,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeintreEncre extends CustomPainter {
  const new({required this.traits, required this.support});

  final List<Trait> traits;
  final SupportEcriture support;

  @override
  void paint(Canvas canvas, Size size) {
    final encre = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _epaisseur
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final trait in traits) {
      encre.color = support.stylos[trait.stylo];
      canvas.drawPath(cheminDuTrait(trait.points), encre);
    }
  }

  @override
  bool shouldRepaint(_PeintreEncre ancien) =>
      !identical(ancien.traits, traits) || ancien.support != support;
}
