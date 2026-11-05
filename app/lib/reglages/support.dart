import 'package:fikajiana/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Support d'écriture, choisi dans les réglages (ADR 0012).
enum SupportEcriture {
  feuilleBlanche(
    fond: Color(0xFFFFFFFF),
    stylos: _stylosPapier,
    estSombre: false,
  ),
  cahierGrandsCarreaux(
    fond: Color(0xFFFFFEFA),
    stylos: _stylosPapier,
    estSombre: false,
  ),
  cahierPetitsCarreaux(
    fond: Color(0xFFFFFEFA),
    stylos: _stylosPapier,
    estSombre: false,
  ),
  tableauNoir(fond: Color(0xFF22282B), stylos: _stylosCraie, estSombre: true);

  new({required this.fond, required this.stylos, required this.estSombre});

  final Color fond;
  final List<Color> stylos;

  /// Le support décide du thème de toute l'application.
  final bool estSombre;

  String libelle(AppLocalizations l10n) => switch (this) {
    feuilleBlanche => l10n.supportFeuilleBlanche,
    cahierGrandsCarreaux => l10n.supportGrandsCarreaux,
    cahierPetitsCarreaux => l10n.supportPetitsCarreaux,
    tableauNoir => l10n.supportTableauNoir,
  };

  String nomStylo(AppLocalizations l10n, int indice) => estSombre
      ? switch (indice) {
          0 => l10n.styloCraieBlanche,
          1 => l10n.styloCraieJaune,
          2 => l10n.styloCraieBleue,
          _ => l10n.styloCraieRose,
        }
      : switch (indice) {
          0 => l10n.styloBleu,
          1 => l10n.styloNoir,
          2 => l10n.styloRouge,
          _ => l10n.styloVert,
        };
}

/// Même nombre de couleurs partout : un trait garde son rang de stylo quand le
/// support change, et reste donc lisible sur le nouveau fond.
const _stylosPapier = [
  Color(0xFF0B3D91),
  Color(0xFF1A1A1A),
  Color(0xFFC62828),
  Color(0xFF1B7A3D),
];
const _stylosCraie = [
  Color(0xFFF5F2E8),
  Color(0xFFFFE27A),
  Color(0xFF8FD3FF),
  Color(0xFFFFB3C1),
];

/// Lignes de chaque support. Longueurs en millimètres, sur la base nominale de
/// 160 dp par pouce : la taille réelle varie d'un appareil à l'autre.
class PeintreSupport extends CustomPainter {
  const new(this.support, {this.echelle = 1});

  final SupportEcriture support;
  final double echelle;

  static const double _dpParMm = 160 / 25.4;
  static const _ligneForte = Color(0xFF8E8ECB);
  static const _ligneFine = Color(0xFFD3D3EC);
  static const _marge = Color(0xFFE57373);
  static const _petitCarreau = Color(0xFFBFD6EC);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = support.fond);
    final mm = _dpParMm * echelle;
    switch (support) {
      case SupportEcriture.feuilleBlanche || SupportEcriture.tableauNoir:
        break;
      case SupportEcriture.cahierGrandsCarreaux:
        _seyes(canvas, size, mm);
      case SupportEcriture.cahierPetitsCarreaux:
        _quadrillage(canvas, size, 5 * mm);
    }
  }

  /// Réglure Seyès : carreaux de 8 mm, interlignes de 2 mm, marge rouge.
  void _seyes(Canvas canvas, Size size, double mm) {
    final fine = Paint()
      ..color = _ligneFine
      ..strokeWidth = 0.5;
    final forte = Paint()
      ..color = _ligneForte
      ..strokeWidth = 0.8;
    var n = 1;
    for (var y = 2 * mm; y < size.height; y += 2 * mm, n++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        n % 4 == 0 ? forte : fine,
      );
    }
    for (var x = 8 * mm; x < size.width; x += 8 * mm) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fine);
    }
    final marge = 24 * mm;
    canvas.drawLine(
      Offset(marge, 0),
      Offset(marge, size.height),
      Paint()
        ..color = _marge
        ..strokeWidth = 1,
    );
  }

  void _quadrillage(Canvas canvas, Size size, double pas) {
    final trait = Paint()
      ..color = _petitCarreau
      ..strokeWidth = 0.5;
    for (var x = pas; x < size.width; x += pas) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), trait);
    }
    for (var y = pas; y < size.height; y += pas) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), trait);
    }
  }

  @override
  bool shouldRepaint(PeintreSupport ancien) =>
      ancien.support != support || ancien.echelle != echelle;
}
