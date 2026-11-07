import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// `decoder_start_token_id` et `eos_token_id` de `generation_config.json`.
const int _jetonFin = 2;
const int _jetonsMaximum = 256;

/// Décode les jetons du modèle : vocabulaire BPE et décodeur ByteLevel.
class Decodeur {
  new(Map<String, dynamic> vocabulaire)
    : _jetons = {
        for (final entree in vocabulaire.entries)
          entree.value as int: entree.key,
      };

  factory depuisTokenizerJson(String texte) {
    final json = jsonDecode(texte) as Map<String, dynamic>;
    final modele = json['model'] as Map<String, dynamic>;
    return Decodeur(modele['vocab'] as Map<String, dynamic>);
  }

  final Map<int, String> _jetons;

  /// Table inverse de ByteLevel : caractère du vocabulaire → octet.
  static final Map<int, int> _octets = () {
    final directs = [
      for (var o = 0x21; o <= 0x7E; o++) o,
      for (var o = 0xA1; o <= 0xAC; o++) o,
      for (var o = 0xAE; o <= 0xFF; o++) o,
    ];
    final table = {for (final o in directs) o: o};
    var suivant = 0;
    for (var o = 0; o < 256; o++) {
      if (!table.containsKey(o)) table[256 + suivant++] = o;
    }
    return table;
  }();

  /// Les jetons de 0 à 4 sont spéciaux (`<pad>`, `<s>`, `</s>`, `<unk>`, `<mask>`).
  String decoder(Iterable<int> ids) {
    final octets = <int>[];
    for (final id in ids) {
      if (id <= 4) continue;
      for (final code in (_jetons[id] ?? '').runes) {
        final octet = _octets[code];
        if (octet != null) octets.add(octet);
      }
    }
    return utf8.decode(octets, allowMalformed: true).trim();
  }
}

class Lecture {
  const new({
    required this.latex,
    required this.msEncodeur,
    required this.msDecodeur,
    required this.jetons,
  });

  final String latex;
  final int msEncodeur;
  final int msDecodeur;
  final int jetons;
}

/// Une lecture en cours : ses jetons et sa log-probabilité.
class Hypothese {
  const new(this.jetons, this.score, {this.finie = false});

  final List<int> jetons;
  final double score;
  final bool finie;

  /// Sans ce partage par la longueur, les courtes gagneraient toujours.
  double get scoreMoyen => score / jetons.length;
}

/// Recherche en faisceau : garde les [largeur] meilleures suites à chaque pas.
/// [etape] rend les logits du jeton suivant.
Future<List<Hypothese>> decoderEnFaisceau({
  required int depart,
  required int fin,
  required int largeur,
  required int jetonsMaximum,
  required Future<List<double>> Function(List<int>) etape,
}) async {
  var faisceau = [
    Hypothese([depart], 0),
  ];
  for (var pas = 0; pas < jetonsMaximum; pas++) {
    if (faisceau.every((h) => h.finie)) break;
    final suites = <Hypothese>[];
    for (final h in faisceau) {
      if (h.finie) {
        suites.add(h);
        continue;
      }
      final probabilites = logSoftmax(await etape(h.jetons));
      final indices = List.generate(probabilites.length, (i) => i)
        ..sort((a, b) => probabilites[b].compareTo(probabilites[a]));
      for (final i in indices.take(largeur)) {
        suites.add(
          i == fin
              ? Hypothese(h.jetons, h.score + probabilites[i], finie: true)
              : Hypothese([...h.jetons, i], h.score + probabilites[i]),
        );
      }
    }
    suites.sort((a, b) => b.scoreMoyen.compareTo(a.scoreMoyen));
    faisceau = suites.take(largeur).toList();
  }
  return faisceau;
}

List<double> logSoftmax(List<double> logits) {
  final maximum = logits.reduce(math.max);
  final somme = logits.fold<double>(0, (s, v) => s + math.exp(v - maximum));
  final total = math.log(somme);
  return [for (final v in logits) v - maximum - total];
}

/// Pix2Text-MFR en ONNX. Rien ne quitte l'appareil.
class Pix2Text {
  new _(this._encodeur, this._decodeur, this._decodeurTexte);

  /// [dossier] contient les deux modèles et `tokenizer.json`. Les versions int8
  /// servent aux essais par `adb` ; l'app télécharge celles de l'auteur.
  static Future<Pix2Text> ouvrir(String dossier) async {
    final ort = OnnxRuntime();
    final suffixe = File('$dossier/encoder_model_int8.onnx').existsSync()
        ? '_int8'
        : '';
    return Pix2Text._(
      await ort.createSession('$dossier/encoder_model$suffixe.onnx'),
      await ort.createSession('$dossier/decoder_model$suffixe.onnx'),
      Decodeur.depuisTokenizerJson(
        await File('$dossier/tokenizer.json').readAsString(),
      ),
    );
  }

  final OrtSession _encodeur;
  final OrtSession _decodeur;
  final Decodeur _decodeurTexte;

  Future<Lecture> lire(Float32List image) async {
    final chrono = Stopwatch()..start();
    final entree = await OrtValue.fromList(image, [1, 3, 384, 384]);
    final sortie = await _encodeur.run({'pixel_values': entree});
    await entree.dispose();
    final memoire = sortie.values.first;
    final msEncodeur = chrono.elapsedMilliseconds;

    chrono.reset();
    final jetons = <int>[_jetonFin];
    for (var i = 0; i < _jetonsMaximum; i++) {
      final ids = await OrtValue.fromList(Int64List.fromList(jetons), [
        1,
        jetons.length,
      ]);
      final resultat = await _decodeur.run({
        'input_ids': ids,
        'encoder_hidden_states': memoire,
      });
      await ids.dispose();
      final logits = resultat.values.first;
      final valeurs = await logits.asFlattenedList();
      await logits.dispose();
      final suivant = _plusGrand(valeurs, valeurs.length ~/ jetons.length);
      if (suivant == _jetonFin) break;
      jetons.add(suivant);
    }
    await memoire.dispose();

    return Lecture(
      latex: _decodeurTexte.decoder(jetons),
      msEncodeur: msEncodeur,
      msDecodeur: chrono.elapsedMilliseconds,
      jetons: jetons.length - 1,
    );
  }

  /// Plusieurs lectures, de la plus probable à la moins probable. Coûte environ
  /// [largeur] fois une lecture : réservé aux lectures douteuses (ADR 0028).
  Future<List<String>> lirePlusieurs(
    Float32List image, {
    int largeur = 3,
    int jetonsMaximum = _jetonsMaximum,
  }) async {
    final entree = await OrtValue.fromList(image, [1, 3, 384, 384]);
    final sortie = await _encodeur.run({'pixel_values': entree});
    await entree.dispose();
    final memoire = sortie.values.first;
    try {
      final hypotheses = await decoderEnFaisceau(
        depart: _jetonFin,
        fin: _jetonFin,
        largeur: largeur,
        jetonsMaximum: jetonsMaximum,
        etape: (jetons) async {
          final ids = await OrtValue.fromList(Int64List.fromList(jetons), [
            1,
            jetons.length,
          ]);
          final resultat = await _decodeur.run({
            'input_ids': ids,
            'encoder_hidden_states': memoire,
          });
          await ids.dispose();
          final logits = resultat.values.first;
          final valeurs = await logits.asFlattenedList();
          await logits.dispose();
          final vocabulaire = valeurs.length ~/ jetons.length;
          return [
            for (var i = valeurs.length - vocabulaire; i < valeurs.length; i++)
              (valeurs[i] as num).toDouble(),
          ];
        },
      );
      return [for (final h in hypotheses) _decodeurTexte.decoder(h.jetons)];
    } finally {
      await memoire.dispose();
    }
  }

  /// Indice du maximum dans la dernière ligne des logits.
  int _plusGrand(List<dynamic> valeurs, int vocabulaire) {
    final debut = valeurs.length - vocabulaire;
    var meilleur = 0;
    var maximum = double.negativeInfinity;
    for (var i = 0; i < vocabulaire; i++) {
      final v = (valeurs[debut + i] as num).toDouble();
      if (v > maximum) (meilleur, maximum) = (i, v);
    }
    return meilleur;
  }

  Future<void> fermer() async {
    await _encodeur.close();
    await _decodeur.close();
  }
}

/// Forme normale pour comparer deux LaTeX, sans juger leur sens.
String normaliserLatex(String latex) => latex
    .replaceAll(RegExp(r'\\[,;:! ]'), '')
    .replaceAll(RegExp(r'\\(left|right)(?![a-zA-Z])'), '')
    .replaceAll(r'\dfrac', r'\frac')
    .replaceAll(r'\tfrac', r'\frac')
    .replaceAll(r'\limits', '')
    .replaceAllMapped(RegExp(r'\\mathrm\{([a-zA-Z])\}'), (m) => m[1]!)
    .replaceAll(RegExp(r'\s+'), '');
