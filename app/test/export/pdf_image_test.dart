import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fikajiana/export/pdf_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pdfDepuisRgba', () {
    // Deux points : un rouge opaque, un transparent, qui doit devenir blanc.
    final rgba = Uint8List.fromList([255, 0, 0, 255, 0, 0, 0, 0]);
    final pdf = pdfDepuisRgba(rgba, 2, 1);
    final texte = latin1.decode(pdf);

    test('commence et finit comme un PDF', () {
      expect(texte, startsWith('%PDF-1.4'));
      expect(texte.trimRight(), endsWith('%%EOF'));
    });

    test('la table xref désigne chaque objet à son octet exact', () {
      final table = int.parse(
        RegExp(r'startxref\n(\d+)').firstMatch(texte)![1]!,
      );
      expect(texte.substring(table), startsWith('xref\n0 6\n'));
      final entrees = RegExp(r'(\d{10}) 00000 n ')
          .allMatches(texte.substring(table))
          .toList();
      expect(entrees, hasLength(5));
      for (var i = 0; i < 5; i++) {
        final position = int.parse(entrees[i][1]!);
        expect(texte.substring(position), startsWith('${i + 1} 0 obj'));
      }
    });

    test('les longueurs de flux sont exactes', () {
      final image = RegExp(r'/Length (\d+) >>\nstream\n').allMatches(texte);
      for (final flux in image) {
        final fin = flux.end + int.parse(flux[1]!);
        expect(texte.substring(fin), startsWith('\nendstream'));
      }
      expect(image, hasLength(2));
    });

    test('le transparent devient blanc, le reste garde sa couleur', () {
      final flux = RegExp(r'/FlateDecode /Length (\d+) >>\nstream\n')
          .firstMatch(texte)!;
      final compresse = pdf.sublist(flux.end, flux.end + int.parse(flux[1]!));
      expect(zlib.decode(compresse), [255, 0, 0, 255, 255, 255]);
    });

    test('la page garde les proportions, sur un A4', () {
      expect(texte, contains('/MediaBox [0 0 841.89 420.94]'));
      final debout = latin1.decode(pdfDepuisRgba(Uint8List(32), 2, 4));
      expect(debout, contains('/MediaBox [0 0 595.28 1190.56]'));
    });

    test('une taille fausse est refusée', () {
      expect(() => pdfDepuisRgba(Uint8List(4), 2, 1), throwsArgumentError);
    });
  });
}
