import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Côté maximal d'une image exportée : au-delà, certains appareils refusent
/// la texture, et le fichier devient lourd pour rien.
const double coteMaxExport = 4096;
const double _finesse = 3;

/// L'échelle d'export d'une zone de [largeur] × [hauteur].
double echelleExport(double largeur, double hauteur) =>
    math.min(_finesse, coteMaxExport / math.max(largeur, hauteur));

/// Ce que montre le [RepaintBoundary] de clé [cle], plus fin que l'écran.
Future<ui.Image> capturerCadre(GlobalKey cle) {
  final cadre =
      cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return cadre.toImage(
    pixelRatio: echelleExport(cadre.size.width, cadre.size.height),
  );
}

/// Tout ce qui est écrit, avec une marge ; `null` si la page est vide.
/// Bords entiers : à zoom 1, les tuiles tombent sur des pixels entiers.
Rect? cadreDeLaPage(Iterable<Rect> zones, {double marge = 32}) {
  Rect? tout;
  for (final zone in zones) {
    tout = tout?.expandToInclude(zone) ?? zone;
  }
  if (tout == null) return null;
  final large = tout.inflate(marge);
  return Rect.fromLTRB(
    large.left.floorToDouble(),
    large.top.floorToDouble(),
    large.right.ceilToDouble(),
    large.bottom.ceilToDouble(),
  );
}

/// Les morceaux d'écran qui couvrent [cadre] : chaque tuile est le coin de
/// page à mettre en haut à gauche de l'écran, sans recouvrement.
List<Rect> tuilesDeLaPage(Rect cadre, Size ecran) {
  final pasX = ecran.width.floorToDouble();
  final pasY = ecran.height.floorToDouble();
  return [
    for (var y = cadre.top; y < cadre.bottom; y += pasY)
      for (var x = cadre.left; x < cadre.right; x += pasX)
        Rect.fromLTRB(
          x,
          y,
          math.min(x + pasX, cadre.right),
          math.min(y + pasY, cadre.bottom),
        ),
  ];
}

/// Photographie [cadre] de la page morceau par morceau, à zoom 1 : une formule
/// garde ainsi sa taille à côté de l'encre, quelle que soit la longueur.
/// [placer] amène un coin de page en haut à gauche et attend l'image suivante.
Future<ui.Image> capturerPage(
  GlobalKey cle,
  Rect cadre,
  Future<void> Function(Offset coin) placer,
) async {
  final zone = cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final echelle = echelleExport(cadre.width, cadre.height);
  final enregistreur = ui.PictureRecorder();
  final toile = Canvas(enregistreur);
  final images = <ui.Image>[];
  final peinture = Paint()..filterQuality = FilterQuality.none;
  try {
    for (final tuile in tuilesDeLaPage(cadre, zone.size)) {
      await placer(tuile.topLeft);
      final image = await zone.toImage(pixelRatio: echelle);
      images.add(image);
      toile.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, tuile.width * echelle, tuile.height * echelle),
        (tuile.shift(-cadre.topLeft).topLeft * echelle) &
            (tuile.size * echelle),
        peinture,
      );
    }
    return await enregistreur.endRecording().toImage(
      (cadre.width * echelle).ceil(),
      (cadre.height * echelle).ceil(),
    );
  } finally {
    for (final image in images) {
      image.dispose();
    }
  }
}
