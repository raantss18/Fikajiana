import 'package:fikajiana/encre/encre.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const double _epaisseur = 3;
const double _rayonGomme = 18;
const double _pasQuadrillage = 32;

/// Zone d'écriture au stylet ou au doigt.
///
/// Dès qu'un stylet a servi, le doigt et la paume n'écrivent plus. Le bouton du
/// stylet, ou son bout gomme, efface les traits touchés.
class FeuilleEncre extends StatefulWidget {
  const new({
    required this.encre,
    required this.libelle,
    this.surChangement,
    super.key,
  });

  final Encre encre;
  final String libelle;
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
        widget.encre.commencer(_point(e));
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
    final couleurs = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.libelle,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _baisser,
        onPointerMove: _deplacer,
        onPointerUp: _lever,
        onPointerCancel: _lever,
        child: ClipRect(
          child: CustomPaint(
            painter: _PeintreEncre(
              traits: widget.encre.traits,
              couleurEncre: couleurs.onSurface,
              couleurQuadrillage: couleurs.outlineVariant,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _PeintreEncre extends CustomPainter {
  const new({
    required this.traits,
    required this.couleurEncre,
    required this.couleurQuadrillage,
  });

  final List<List<PointEncre>> traits;
  final Color couleurEncre;
  final Color couleurQuadrillage;

  @override
  void paint(Canvas canvas, Size size) {
    final quadrillage = Paint()
      ..color = couleurQuadrillage.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    for (var x = _pasQuadrillage; x < size.width; x += _pasQuadrillage) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), quadrillage);
    }
    for (var y = _pasQuadrillage; y < size.height; y += _pasQuadrillage) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), quadrillage);
    }
    final encre = Paint()
      ..color = couleurEncre
      ..style = PaintingStyle.stroke
      ..strokeWidth = _epaisseur
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final trait in traits) {
      canvas.drawPath(cheminDuTrait(trait), encre);
    }
  }

  @override
  bool shouldRepaint(_PeintreEncre ancien) =>
      !identical(ancien.traits, traits) ||
      ancien.couleurEncre != couleurEncre ||
      ancien.couleurQuadrillage != couleurQuadrillage;
}
