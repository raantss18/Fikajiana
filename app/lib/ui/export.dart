import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:fikajiana/export/pdf_image.dart';
import 'package:fikajiana/l10n/l10n.dart';
import 'package:fikajiana/reconnaissance/exemples_personnels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FormatExport {
  png('png', 'image/png'),
  pdf('pdf', 'application/pdf');

  new(this.extension, this.type);

  final String extension;
  final String type;
}

const _systeme = MethodChannel('fikajiana/systeme');

/// Encode l'image et demande à Android où l'enregistrer (ADR 0022). Rien ne
/// part ailleurs que là où la personne choisit de le mettre.
Future<void> exporter(
  BuildContext context, {
  required String nom,
  required FormatExport format,
  required Future<ui.Image> Function() capture,
}) async {
  final messager = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  // À gauche du bouton Outils, qu'elle ne doit pas couvrir.
  void dire(String texte) => messager.showSnackBar(
    SnackBar(
      content: Text(texte),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(left: 8, right: 136, bottom: 8),
    ),
  );
  try {
    final image = await capture();
    final Uint8List octets;
    try {
      octets = await _encoder(image, format);
    } finally {
      image.dispose();
    }
    final jour = DateTime.now().toIso8601String().substring(0, 10);
    final enregistre = await _systeme.invokeMethod<bool>('enregistrer', {
      'nom': 'fikajiana-$nom-$jour.${format.extension}',
      'type': format.type,
      'octets': octets,
    });
    if (enregistre ?? false) dire(l10n.exportFait);
  } on Exception {
    dire(l10n.exportErreur);
  }
}

Future<Uint8List> _encoder(ui.Image image, FormatExport format) async {
  switch (format) {
    case FormatExport.png:
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return png!.buffer.asUint8List();
    case FormatExport.pdf:
      final brut = await image.toByteData();
      final (rgba, l, h) = (
        brut!.buffer.asUint8List(),
        image.width,
        image.height,
      );
      // Compresser une grande image prendrait plusieurs images d'écran.
      return await Isolate.run(() => pdfDepuisRgba(rgba, l, h));
  }
}

/// Les deux lignes d'export d'un panneau d'outils.
List<Widget> lignesExport(
  BuildContext context, {
  required bool actif,
  required ValueChanged<FormatExport> surChoix,
  bool dense = false,
}) {
  final l10n = context.l10n;
  return [
    ListTile(
      dense: dense,
      leading: const Icon(Icons.image_outlined),
      title: Text(l10n.exportPng),
      enabled: actif,
      onTap: () => surChoix(FormatExport.png),
    ),
    ListTile(
      dense: dense,
      leading: const Icon(Icons.picture_as_pdf_outlined),
      title: Text(l10n.exportPdf),
      enabled: actif,
      onTap: () => surChoix(FormatExport.pdf),
    ),
  ];
}

/// Les corrections de la personne, en JSON (`collecte/FORMAT.md`), là où
/// elle choisit de les mettre (ADR 0039). Rien ne part autrement.
Future<void> exporterCorrections(
  BuildContext context,
  ExemplesPersonnels exemples,
) async {
  final messager = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final vue = View.of(context);
  final ecran = vue.physicalSize / vue.devicePixelRatio;
  try {
    final modele = await _systeme.invokeMethod<String>('modele') ?? 'inconnu';
    final json = exemples.exporter(
      modele: modele,
      ecranDp: ecran,
      densite: vue.devicePixelRatio,
    );
    final quand = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(RegExp('[-:]'), '')
        .replaceFirst('T', '-');
    final enregistre = await _systeme.invokeMethod<bool>('enregistrer', {
      'nom': 'fikajiana-ecriture-$modele-$quand.json',
      'type': 'application/json',
      'octets': Uint8List.fromList(utf8.encode(json)),
    });
    if (enregistre ?? false) {
      messager.showSnackBar(SnackBar(content: Text(l10n.exportFait)));
    }
  } on Exception {
    messager.showSnackBar(SnackBar(content: Text(l10n.exportErreur)));
  }
}
