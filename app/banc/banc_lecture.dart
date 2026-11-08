// Le banc tourne sur un appareil et écrit dans le journal.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math' as math;

import 'package:fikajiana/comprendre/blocs.dart';
import 'package:fikajiana/comprendre/trace_ligne.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classes_signes.dart';
import 'package:fikajiana/reconnaissance/classeur_appris.dart';
import 'package:fikajiana/reconnaissance/classeur_onnx.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:fikajiana/reconnaissance/rendu_signe.dart';
import 'package:flutter/widgets.dart';

import 'fixtures_lecture.dart';

/// Combien de fois chaque ligne se lit : on garde la médiane.
const _tours = 7;

/// Budget de l'ADR 0038 : une ligne simple en moins de 50 ms.
const _budgetMs = 50.0;

double _mediane(List<double> v) => (v..sort())[v.length ~/ 2];

double _ms(Stopwatch s) => s.elapsedMicroseconds / 1000;

/// Le temps de lecture au tracé de chaque écriture réelle des tests, avant
/// (gabarits à chaque lecture) et après (signes classés dès qu'ils sont
/// finis, ADR 0041). Usage : `tool/banc/lancer.sh android-arm64
/// banc/banc_lecture.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var simples = 0;
  var dansLeBudget = 0;
  final apres = <double>[];
  for (final (nom, json) in fixturesLecture) {
    final traits = [
      for (final t in jsonDecode(json) as List<dynamic>)
        Trait.depuisDocument(t as Map<String, dynamic>),
    ];
    final avant = <double>[];
    final signes = <double>[];
    final relue = <double>[];
    String? lu;
    for (var i = 0; i < _tours; i++) {
      final chrono = Stopwatch()..start();
      lu = avecClasseur(const ClasseurGabarits(), () => lireAuTrace(traits));
      avant.add(_ms(chrono));
      // Pendant l'écriture : chaque signe, dès qu'il est fini.
      final classeur = ClasseurAppris();
      chrono
        ..reset()
        ..start();
      for (final ligne in grouperTraits(traits)) {
        final signes = signesDeLaLigne(ligne);
        for (final s in signes) {
          await classeur.preparer(s, caseLigne: caseDansLaLigne(s, signes));
        }
      }
      signes.add(_ms(chrono));
      // À la pause : la ligne, ses signes déjà connus.
      chrono
        ..reset()
        ..start();
      final encore = avecClasseur(classeur, () => lireAuTrace(traits));
      relue.add(_ms(chrono));
      if (encore != lu) print('BANC ECART $nom : $lu puis $encore');
    }
    final (a, s, r) = (_mediane(avant), _mediane(signes), _mediane(relue));
    if (lu != null) {
      simples++;
      apres.add(r);
      if (r < _budgetMs) dansLeBudget++;
    }
    print(
      'BANC LECTURE $nom : avant ${a.toStringAsFixed(1)} ms, '
      'après ${r.toStringAsFixed(1)} ms '
      '(signes pendant l’écriture ${s.toStringAsFixed(1)} ms) '
      '→ ${lu ?? 'au modèle'}',
    );
  }
  final pire = apres.isEmpty ? 0 : apres.reduce((x, y) => x > y ? x : y);
  print(
    'BANC LECTURE pire ligne simple : ${pire.toStringAsFixed(1)} ms '
    '(budget ${_budgetMs.round()} ms)',
  );
  await _bancModele();
  print('BANC FIN : $dansLeBudget/$simples');
}

/// Les séances que l'entraînement n'a jamais vues (rapport du modèle v1).
const _jamaisVues = {
  'pad7/developper',
  'pad7/fleche_plot',
  'pad7/puissances_de_10',
  'telephone/matrice_carre',
  'telephone/un_plus_un',
};

/// Les signes étiquetés, lus par les gabarits et par le petit modèle s'il
/// est embarqué : justesse, temps, et règle de doute (ADR 0041).
Future<void> _bancModele() async {
  final modele = await ClasseurOnnx.charger();
  if (modele == null) {
    print('BANC MODELE absent (assets/modeles/) : gabarits seuls');
    return;
  }
  final latex = {for (final (id, l) in classesSignes) id: l};
  final traitsDe = <String, List<Trait>>{
    for (final (nom, json) in fixturesLecture)
      nom: [
        for (final t in jsonDecode(json) as List<dynamic>)
          Trait.depuisDocument(t as Map<String, dynamic>),
      ],
  };
  final parFixture = <String, List<(List<int>, String)>>{};
  for (final (nom, rangs, classe) in signesEtiquetes) {
    parFixture.putIfAbsent(nom, () => []).add((rangs, classe));
  }
  final resultats = <(String, Classement, Map<String, double>?, bool)>[];
  final temps = <double>[];
  for (final MapEntry(key: nom, value: signes) in parFixture.entries) {
    final tous = traitsDe[nom]!;
    final groupes = [
      for (final (rangs, _) in signes) [for (final i in rangs) tous[i]],
    ];
    final mediane = hauteurMediane([for (final g in groupes) dessinDe(g)]);
    for (final (i, (_, classe)) in signes.indexed) {
      final signe = groupes[i];
      final caseLigne = caseDuSigne(dessinDe(signe), dessinDe(tous), mediane);
      final chrono = Stopwatch()..start();
      final classement = await modele.classer(
        signe,
        caseLigne: caseLigne,
        combien: 2,
      );
      temps.add(_ms(chrono));
      final gabarits = const ClasseurGabarits().signe(
        signe,
        hauteurLigne: caseLigne.height,
      );
      resultats.add((
        latex[classe]!,
        classement,
        gabarits,
        _jamaisVues.contains(nom),
      ));
    }
  }
  final n = resultats.length;
  var justesModele = 0;
  var justesGabarits = 0;
  var fauxGabarits = 0;
  var vus = 0;
  var justesVus = 0;
  for (final (attendu, c, g, jamaisVu) in resultats) {
    if (c.first.$1 == attendu) justesModele++;
    if (jamaisVu) {
      vus++;
      if (c.first.$1 == attendu) justesVus++;
    }
    if (g != null && g.length == 1) {
      g.containsKey(attendu) ? justesGabarits++ : fauxGabarits++;
    }
  }
  print(
    'BANC MODELE $n signes : modèle juste ${justesModele * 100 ~/ n} % '
    '(premier choix), $justesVus/$vus sur les séances jamais vues ; '
    'gabarits sûrs $justesGabarits justes, '
    '$fauxGabarits faux ; ${_mediane(temps).toStringAsFixed(1)} ms '
    'par signe en médiane, ${temps.reduce(math.max).toStringAsFixed(1)} '
    'au pire',
  );
  // La règle de doute : ce que le modèle ajoute là où les gabarits doutent.
  for (final seuil in const [0.5, 0.7, 0.8, 0.9, 0.95]) {
    for (final ecart in const [0.0, 0.3, 0.5]) {
      var pris = 0;
      var justes = 0;
      var doutes = 0;
      for (final (attendu, c, g, jamaisVu) in resultats) {
        if (!jamaisVu || (g != null && g.length == 1)) continue;
        doutes++;
        final p = c.first.$2;
        final second = c.length > 1 ? c[1].$2 : 0.0;
        if (p < seuil || p - second < ecart) continue;
        if (!ClasseurAppris.classesLues.hasMatch(c.first.$1)) continue;
        pris++;
        if (c.first.$1 == attendu) justes++;
      }
      print(
        'BANC SEUIL $seuil écart $ecart : $pris pris sur $doutes doutes '
        'des gabarits (séances jamais vues), $justes justes',
      );
    }
  }
  // Les lignes entières : ce que le modèle change à la lecture au tracé.
  for (final (nom, json) in fixturesLecture) {
    final traits = [
      for (final t in jsonDecode(json) as List<dynamic>)
        Trait.depuisDocument(t as Map<String, dynamic>),
    ];
    final sans = avecClasseur(
      const ClasseurGabarits(),
      () => lireAuTrace(traits),
    );
    final classeur = ClasseurAppris()..modele = modele;
    final chrono = Stopwatch()..start();
    for (final ligne in grouperTraits(traits)) {
      final signes = signesDeLaLigne(ligne);
      for (final s in signes) {
        await classeur.preparer(s, caseLigne: caseDansLaLigne(s, signes));
      }
    }
    final ms = _ms(chrono);
    final avec = avecClasseur(classeur, () => lireAuTrace(traits));
    print(
      'BANC LIGNE $nom : gabarits ${sans ?? 'au modèle'} ; '
      'avec le modèle ${avec ?? 'au modèle'} '
      '(${classeur.signesModele} signes, ${ms.toStringAsFixed(1)} ms)',
    );
  }
  await modele.fermer();
}
