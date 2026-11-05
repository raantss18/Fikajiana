import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fikajiana/encre/encre.dart';

/// Taille d'entrée du modèle (`preprocessor_config.json` de Pix2Text-MFR).
const int tailleModele = 384;

/// Part de la hauteur d'écriture occupée par le trait. Un trait épais fait lire
/// `1` comme `Λ` : mesuré dans `docs/recherche/spike-ocr.md`.
const double _traitParHauteur = 1 / 70;
const double _coteImage = 1536;
const double _hauteurMinimale = 48;
const double _marge = 0.12;

/// Dessine l'encre en noir sur blanc, recadrée, avec un trait proportionné.
///
/// Rend `null` sans encre. L'image garde les proportions de l'écriture : c'est
/// [versTenseur] qui la déforme en carré, comme le processeur du modèle.
Future<ui.Image?> rasteriser(Encre encre) => rasteriserTraits(encre.traits);

/// Comme [rasteriser], pour un bloc de la feuille.
Future<ui.Image?> rasteriserTraits(List<Trait> traits) async {
  final encre = Encre();
  for (final t in traits) {
    encre.commencer(t.points.first);
    t.points.skip(1).forEach(encre.prolonger);
  }
  final cadre = encre.cadre;
  if (cadre == null) return null;

  final hauteurEncre = cadre.height < _hauteurMinimale
      ? _hauteurMinimale
      : cadre.height;
  final marge = hauteurEncre * _marge;
  final largeur = cadre.width + 2 * marge;
  final hauteur = hauteurEncre + 2 * marge;
  final echelle = _coteImage / (largeur > hauteur ? largeur : hauteur);
  final (w, h) = ((largeur * echelle).ceil(), (hauteur * echelle).ceil());

  final enregistreur = ui.PictureRecorder();
  final canevas = ui.Canvas(enregistreur)
    ..drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src)
    ..scale(echelle)
    ..translate(
      marge - cadre.left,
      marge - cadre.top + (hauteurEncre - cadre.height) / 2,
    );
  final trait = ui.Paint()
    ..color = const ui.Color(0xFF000000)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = hauteurEncre * _traitParHauteur
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  for (final ecrit in encre.traits) {
    canevas.drawPath(cheminDuTrait(ecrit.points), trait);
  }
  return await enregistreur.endRecording().toImage(w, h);
}

/// Tenseur 1×3×384×384 attendu par l'encodeur : `(x / 255 - 0,5) / 0,5`.
Future<Float32List> versTenseur(ui.Image image) async {
  final enregistreur = ui.PictureRecorder();
  ui.Canvas(enregistreur).drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, tailleModele.toDouble(), tailleModele.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final carre = await enregistreur.endRecording().toImage(
    tailleModele,
    tailleModele,
  );
  final octets = (await carre.toByteData())!.buffer.asUint8List();
  carre.dispose();

  const n = tailleModele * tailleModele;
  final tenseur = Float32List(3 * n);
  for (var i = 0; i < n; i++) {
    for (var c = 0; c < 3; c++) {
      tenseur[c * n + i] = octets[4 * i + c] / 127.5 - 1;
    }
  }
  return tenseur;
}
