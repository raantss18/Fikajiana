import 'package:collecte/seance.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Les traits de la case, effacés à chaque nouvelle demande.
class EncreCase extends ChangeNotifier {
  final List<List<PointEncre>> traits = [];

  /// Les mêmes traits dans le repère de la case, pour les dessiner.
  final List<List<Offset>> _dessin = [];
  double? _origine;

  /// Le premier trait a été fait au stylet.
  bool stylet = false;

  bool get vide => traits.isEmpty;

  void effacer() {
    traits.clear();
    _dessin.clear();
    _origine = null;
    stylet = false;
    notifyListeners();
  }

  void _commencer(
    Offset position,
    Offset local,
    double tempsMs,
    double pression, {
    required bool auStylet,
  }) {
    if (traits.isEmpty) stylet = auStylet;
    _origine ??= tempsMs;
    traits.add([]);
    _dessin.add([]);
    _ajouter(position, local, tempsMs, pression);
  }

  void _ajouter(
    Offset position,
    Offset local,
    double tempsMs,
    double pression,
  ) {
    traits.last.add((
      x: position.dx,
      y: position.dy,
      t: tempsMs - _origine!,
      p: pression,
    ));
    _dessin.last.add(local);
    notifyListeners();
  }
}

/// Grande case d'écriture aux proportions d'une ligne de cahier.
///
/// Le stylet écrit toujours. Le doigt écrit tant qu'aucun stylet n'a servi,
/// ou si [doigtEcrit] : sinon c'est la main posée, ignorée.
class CaseEcriture extends StatefulWidget {
  const new({
    required this.encre,
    required this.doigtEcrit,
    required this.styletVu,
    required this.surStylet,
    required this.surDebut,
    required this.surFin,
    required this.consigne,
    super.key,
  });

  final EncreCase encre;
  final bool doigtEcrit;
  final bool styletVu;
  final VoidCallback surStylet;
  final VoidCallback surDebut;
  final VoidCallback surFin;

  /// Ce qu'annonce le lecteur d'écran.
  final String consigne;

  @override
  State<CaseEcriture> createState() => _CaseEcritureState();
}

class _CaseEcritureState extends State<CaseEcriture> {
  int? _pointeur;

  static bool _estStylet(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus ||
      e.kind == PointerDeviceKind.invertedStylus;

  double _pression(PointerEvent e) =>
      _estStylet(e) ? e.pressure.clamp(0.0, 1.0) : 1.0;

  void _baisser(PointerDownEvent e) {
    if (_pointeur != null) return;
    final stylet = _estStylet(e);
    if (stylet) {
      widget.surStylet();
    } else if (e.kind == PointerDeviceKind.touch &&
        widget.styletVu &&
        !widget.doigtEcrit) {
      return;
    }
    _pointeur = e.pointer;
    widget.surDebut();
    widget.encre._commencer(
      e.position,
      e.localPosition,
      e.timeStamp.inMicroseconds / 1000,
      _pression(e),
      auStylet: stylet,
    );
  }

  void _bouger(PointerMoveEvent e) {
    if (e.pointer != _pointeur) return;
    widget.encre._ajouter(
      e.position,
      e.localPosition,
      e.timeStamp.inMicroseconds / 1000,
      _pression(e),
    );
  }

  void _lever(PointerEvent e) {
    if (e.pointer != _pointeur) return;
    _pointeur = null;
    widget.surFin();
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.consigne,
      hint: 'Écrire ici au stylet',
      container: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _baisser,
        onPointerMove: _bouger,
        onPointerUp: _lever,
        onPointerCancel: _lever,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: couleurs.surfaceContainerLowest,
            border: Border.all(color: couleurs.outline, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: _Peintre(
                widget.encre,
                encre: couleurs.onSurface,
                lignes: couleurs.primary.withValues(alpha: 0.35),
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _Peintre extends CustomPainter {
  new(this.contenu, {required this.encre, required this.lignes})
    : super(repaint: contenu);

  final EncreCase contenu;
  final Color encre;
  final Color lignes;

  @override
  void paint(Canvas canvas, Size size) {
    // Les lignes d'un cahier : haut des majuscules, milieu, ligne de base.
    final trait = Paint()
      ..color = lignes
      ..strokeWidth = 1.5;
    for (final f in const [0.25, 0.5, 0.75]) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), trait);
    }
    final stylo = Paint()
      ..color = encre
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final t in contenu._dessin) {
      if (t.length == 1) {
        canvas.drawCircle(t.first, 2, Paint()..color = encre);
        continue;
      }
      final chemin = Path()..moveTo(t.first.dx, t.first.dy);
      for (final p in t.skip(1)) {
        chemin.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(chemin, stylo);
    }
  }

  @override
  bool shouldRepaint(_Peintre ancien) =>
      ancien.contenu != contenu ||
      ancien.encre != encre ||
      ancien.lignes != lignes;
}
