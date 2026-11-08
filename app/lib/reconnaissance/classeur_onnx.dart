import 'dart:convert';
import 'dart:math' as math;

import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classes_signes.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/reconnaissance/rendu_signe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Les entrées du modèle pour un signe : image 32×32 et mesures (contrat
/// v1, ADR 0040).
(Float32List, Float32List) entreesDuSigne(List<Trait> signe, Rect caseLigne) {
  final dessin = dessinDe(signe);
  return (
    rendreSigne(dessin, caseLigne.height),
    mesurerSigne(dessin, caseLigne),
  );
}

/// Les probabilités, du softmax des logits.
List<double> softmax(List<double> logits) {
  final m = logits.reduce(math.max);
  final e = [for (final l in logits) math.exp(l - m)];
  final s = e.fold<double>(0, (a, b) => a + b);
  return [for (final v in e) v / s];
}

/// Le petit modèle par signe (ADR 0038), embarqué dans `assets/modeles/` :
/// `signes.onnx`, `signes_classes.txt`, `signes.json`. Rien ne quitte
/// l'appareil.
class ClasseurOnnx extends ClasseurSignes {
  new _(this._session, this._classes);

  static const _dossier = 'assets/modeles';

  /// La version du contrat que ce code sait rendre.
  static const versionContrat = 1;

  final OrtSession _session;

  /// Les classes de sortie, en LaTeX, dans l'ordre des logits.
  final List<String> _classes;

  /// Le modèle embarqué, ou `null` s'il manque ou ne suit pas le contrat :
  /// les gabarits lisent seuls, comme avant.
  static Future<ClasseurOnnx?> charger({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    try {
      // Construite sans modèle : les gabarits lisent seuls.
      final manifeste = await AssetManifest.loadFromAssetBundle(b);
      const fichiers = ['signes.json', 'signes_classes.txt', 'signes.onnx'];
      final presents = manifeste.listAssets().toSet();
      if (!fichiers.every((f) => presents.contains('$_dossier/$f'))) {
        return null;
      }
      final contrat = jsonDecode(
        await b.loadString('$_dossier/signes.json'),
      ) as Map<String, dynamic>;
      if (contrat['version'] != versionContrat) return null;
      final latex = {for (final (id, l) in classesSignes) id: l};
      final classes = [
        for (final id in const LineSplitter().convert(
          await b.loadString('$_dossier/signes_classes.txt'),
        ))
          if (id.trim().isNotEmpty) latex[id.trim()] ?? '',
      ];
      if (classes.length != contrat['nb_classes']) return null;
      final session = await OnnxRuntime().createSessionFromAsset(
        '$_dossier/signes.onnx',
      );
      return ClasseurOnnx._(session, classes);
    } on Exception {
      return null;
    }
  }

  @override
  Future<Classement> classer(
    List<Trait> signe, {
    required Rect caseLigne,
    int combien = 3,
  }) async {
    final (image, mesures) = entreesDuSigne(signe, caseLigne);
    final entreeImage = await OrtValue.fromList(image, [1, 1, 32, 32]);
    final entreeMesures = await OrtValue.fromList(mesures, [1, nombreMesures]);
    final sortie = await _session.run({
      'image': entreeImage,
      'mesures': entreeMesures,
    });
    await entreeImage.dispose();
    await entreeMesures.dispose();
    final logits = sortie['logits']!;
    final valeurs = [
      for (final v in await logits.asFlattenedList()) (v as num).toDouble(),
    ];
    await logits.dispose();
    final probas = softmax(valeurs);
    final rangs = List.generate(probas.length, (i) => i)
      ..sort((a, b) => probas[b].compareTo(probas[a]));
    return [
      for (final i in rangs.take(combien))
        if (_classes[i].isNotEmpty) (_classes[i], probas[i]),
    ];
  }

  // Le modèle ne répond pas sur-le-champ : ces verdicts passent par
  // `ClasseurAppris`, qui garde ses classements.
  @override
  Map<String, double>? signe(
    List<Trait> signe, {
    required double hauteurLigne,
  }) => null;

  @override
  String? chiffre(List<Trait> signe) => null;

  @override
  String? capitale(List<Trait> signe) => null;

  Future<void> fermer() => _session.close();
}
