import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Largeur d'une page A4, en points : 210 mm et 297 mm.
const double _a4Court = 595.28;
const double _a4Long = 841.89;

/// Plus grand côté de page que les lecteurs acceptent tous, en points.
const double _coteMax = 14400;

/// Un PDF d'une page qui contient l'image : ni police ni dépendance.
///
/// [rgba] vient de `ImageByteFormat.rawRgba`, donc prémultiplié : ce qui est
/// transparent devient blanc. L'image garde ses proportions, sur la largeur
/// d'un A4 (ISO 32000-1, §7.5 structure du fichier, §8.9 images).
Uint8List pdfDepuisRgba(Uint8List rgba, int largeur, int hauteur) {
  final points = largeur * hauteur;
  if (largeur <= 0 || hauteur <= 0 || rgba.length != points * 4) {
    throw ArgumentError('Image de $largeur × $hauteur : ${rgba.length} octets');
  }
  final rgb = Uint8List(points * 3);
  for (var i = 0; i < points; i++) {
    final reste = 255 - rgba[i * 4 + 3];
    rgb[i * 3] = rgba[i * 4] + reste;
    rgb[i * 3 + 1] = rgba[i * 4 + 1] + reste;
    rgb[i * 3 + 2] = rgba[i * 4 + 2] + reste;
  }
  final donnees = zlib.encode(rgb);

  var l = largeur > hauteur ? _a4Long : _a4Court;
  var h = l * hauteur / largeur;
  if (h > _coteMax) (l, h) = (l * _coteMax / h, _coteMax);
  final (pl, ph) = (l.toStringAsFixed(2), h.toStringAsFixed(2));
  final dessin = 'q $pl 0 0 $ph 0 0 cm /I Do Q';

  final sortie = BytesBuilder(copy: false);
  void ecrire(String texte) => sortie.add(latin1.encode(texte));
  final positions = <int>[];
  void objet(String corps, [List<int>? flux]) {
    positions.add(sortie.length);
    ecrire('${positions.length} 0 obj\n$corps\n');
    if (flux != null) {
      ecrire('stream\n');
      sortie.add(flux);
      ecrire('\nendstream\n');
    }
    ecrire('endobj\n');
  }

  // Le commentaire binaire dit aux outils que le fichier n'est pas du texte.
  ecrire('%PDF-1.4\n%âãÏÓ\n');
  objet('<< /Type /Catalog /Pages 2 0 R >>');
  objet('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  objet(
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pl $ph] '
    '/Resources << /XObject << /I 5 0 R >> >> /Contents 4 0 R >>',
  );
  objet('<< /Length ${dessin.length} >>', latin1.encode(dessin));
  objet(
    '<< /Type /XObject /Subtype /Image /Width $largeur /Height $hauteur '
    '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode '
    '/Length ${donnees.length} >>',
    donnees,
  );
  final table = sortie.length;
  ecrire('xref\n0 ${positions.length + 1}\n0000000000 65535 f \n');
  for (final p in positions) {
    ecrire('${p.toString().padLeft(10, '0')} 00000 n \n');
  }
  ecrire(
    'trailer\n<< /Size ${positions.length + 1} /Root 1 0 R >>\n'
    'startxref\n$table\n%%EOF\n',
  );
  return sortie.takeBytes();
}
