// Le banc tourne sur un appareil, où est Giac, et écrit dans le journal.
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter/widgets.dart';

import 'references.dart';

/// Écart toléré : Giac et SymPy comptent en virgule flottante à l'arrivée.
const double _tolerance = 1e-6;

final _nombre = RegExp(r'-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?');

Future<String> _evaluer(String entree) async =>
    (await evaluerGiac(entree)).trim();

Future<List<double>> _nombres(String entree) async => _nombre
    .allMatches(await _evaluer('evalf($entree)'))
    .map((m) => double.parse(m[0]!))
    .toList();

bool _proche(double a, double b) => (a - b).abs() <= _tolerance * (1 + b.abs());

Future<double> _reel(String entree) async {
  final texte = await _evaluer('evalf($entree)');
  if (texte.contains('inf')) {
    return texte.contains('-') ? double.negativeInfinity : double.infinity;
  }
  final vu = _nombre.firstMatch(texte);
  if (vu == null) throw StateError('pas un nombre : $texte');
  return double.parse(vu[0]!);
}

/// Vide si tout va bien, sinon ce qui ne va pas.
Future<String> _verifier(Map<String, dynamic> cas, ReponseGiac reponse) async {
  final exact = reponse.exact;
  switch (cas['g'] as String) {
    case 'valeur':
      final attendu = cas['a'] as List<dynamic>;
      if (attendu[0] is String) {
        final infini = attendu[0] == 'inf'
            ? double.infinity
            : double.negativeInfinity;
        final vu = await _reel(exact);
        return vu == infini ? '' : 'attendu ${attendu[0]}, lu $exact';
      }
      final re = await _reel('re($exact)');
      final im = await _reel('im($exact)');
      final bon =
          _proche(re, (attendu[0] as num).toDouble()) &&
          _proche(im, (attendu[1] as num).toDouble());
      return bon ? '' : 'attendu $attendu, lu $exact ≈ $re + ${im}i';
    case 'fonction':
      final v = cas['v'] as String;
      final points = (cas['p'] as List<dynamic>).cast<num>();
      final attendu = (cas['a'] as List<dynamic>).cast<num>();
      for (var i = 0; i < points.length; i++) {
        final vu = await _reel('subst($exact,$v=${points[i]})');
        if (!_proche(vu, attendu[i].toDouble())) {
          return 'en ${points[i]} : attendu ${attendu[i]}, lu $vu ($exact)';
        }
      }
      return '';
    case 'primitive':
      final points = (cas['p'] as List<dynamic>).cast<num>();
      final haut = await _reel('subst($exact,x=${points[0]})');
      final bas = await _reel('subst($exact,x=${points[1]})');
      final attendu = (cas['a'] as num).toDouble();
      return _proche(haut - bas, attendu)
          ? ''
          : 'écart attendu $attendu, lu ${haut - bas} ($exact)';
    case 'liste':
      final attendu = (cas['a'] as List<dynamic>).cast<num>();
      final vus = await _nombres(exact);
      if (cas['ordre'] != true) vus.sort();
      var bon = vus.length == attendu.length;
      for (var i = 0; bon && i < vus.length; i++) {
        bon = _proche(vus[i], attendu[i].toDouble());
      }
      return bon ? '' : 'attendu $attendu, lu $vus ($exact)';
    case 'verite':
      return exact == '${cas['a']}' ? '' : 'attendu ${cas['a']}, lu $exact';
    case 'ordre':
      // Le résultat, tel quel, doit répondre juste aux nombres d'essai : vrai
      // si l'une de ses relations l'est.
      for (final (liste, attendu) in [
        (cas['vrais'], true),
        (cas['faux'], false),
      ]) {
        for (final p in (liste as List<dynamic>).cast<num>()) {
          final vu = await _evaluer('map($exact,e->evalb(subst(e,x=$p)))');
          if (vu.contains('true') != attendu) {
            return 'en $p : attendu $attendu, lu $vu ($exact)';
          }
        }
      }
      return '';
  }
  return 'genre inconnu';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final liste = (jsonDecode(referencesJson) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  // Le même délai que dans l'app : un calcul trop long est un écart.
  final moteur = MoteurGiac();
  final bons = <String, int>{};
  final totaux = <String, int>{};
  for (final cas in liste) {
    final famille = cas['f'] as String;
    final latex = cas['l'] as String;
    totaux[famille] = (totaux[famille] ?? 0) + 1;
    print('BANC CAS $latex');
    var ecart = '';
    try {
      final definition = cas['d'] as String?;
      final avant = definition == null ? null : analyserLatex(definition);
      // Les valeurs déclarées plus haut sur la feuille : `A = (…)`.
      final valeurs = {
        for (final v in (cas['vals'] as List<dynamic>? ?? const []))
          if (analyserLatex(v as String) case Analyse(
            :final nomValeur?,
            :final giac,
          ))
            nomValeur: giac,
      };
      final analyse = analyserLatex(
        latex,
        valeurs: valeurs,
        definitions: avant == null
            ? const {}
            : {avant.nomFonction!: avant.definition!},
        vecteurs: {
          for (final MapEntry(:key, :value)
              in (cas['vec'] as Map<String, dynamic>? ?? const {}).entries)
            key: (
              ((value as List<dynamic>)[0] as num).toDouble(),
              (value[1] as num).toDouble(),
            ),
        },
      );
      final reponse = await moteur.calculer(analyse.giac);
      ecart = reponse.arrete
          ? 'arrêté après le délai de l’app (${analyse.giac})'
          : reponse.erreur != null
          ? 'erreur Giac : ${reponse.erreur} (${analyse.giac})'
          : await _verifier(cas, reponse);
    } on Object catch (e) {
      ecart = 'exception : $e';
    }
    if (ecart.isEmpty) {
      bons[famille] = (bons[famille] ?? 0) + 1;
    } else {
      print('BANC ECART [$famille] $latex : $ecart');
    }
  }
  var total = 0;
  var justes = 0;
  for (final famille in totaux.keys) {
    print('BANC $famille : ${bons[famille] ?? 0}/${totaux[famille]}');
    total += totaux[famille]!;
    justes += bons[famille] ?? 0;
  }
  print('BANC FIN : $justes/$total');
}
