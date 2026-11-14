import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fikajiana/comprendre/signes.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/classes_signes.dart';
import 'package:fikajiana/reconnaissance/classeur_signes.dart';
import 'package:flutter/foundation.dart';

/// D'où vient un échantillon.
enum Origine {
  /// La personne a dit que la lecture était juste (👍).
  juste,

  /// La personne a dit ce qu'il fallait lire.
  correction,
}

/// Un échantillon d'écriture : une ligne (`expression`) ou un signe
/// (`signe`), ses traits bruts et ce qu'ils disent (ADR 0042, 0044).
class Echantillon {
  const new({
    required this.id,
    required this.type,
    required this.attendu,
    required this.traits,
    required this.caseLigne,
    required this.origine,
    required this.cle,
    required this.quand,
    required this.auStylet,
    this.clesTraits = const [],
    this.envoye = false,
  });

  factory depuisJson(Map<String, dynamic> json) {
    final c = (json['case'] as List<dynamic>).cast<num>();
    return Echantillon(
      id: json['id'] as String,
      type: json['type'] as String,
      attendu: json['attendu'] as String,
      origine: Origine.values.byName(json['origine'] as String),
      cle: json['cle'] as String? ?? '',
      quand: DateTime.parse(json['quand'] as String),
      auStylet: json['auStylet'] as bool? ?? true,
      envoye: json['envoye'] as bool? ?? false,
      clesTraits: (json['clesTraits'] as List<dynamic>? ?? const [])
          .cast<String>(),
      caseLigne: Rect.fromLTWH(
        c[0].toDouble(),
        c[1].toDouble(),
        c[2].toDouble(),
        c[3].toDouble(),
      ),
      traits: [
        for (final t in json['traits'] as List<dynamic>)
          [
            for (final p in t as List<dynamic>)
              PointEncre.depuisJson(p as List<dynamic>),
          ],
      ],
    );
  }

  final String id;

  /// `signe` ou `expression`, comme `collecte/FORMAT.md`.
  final String type;

  /// Le LaTeX : la classe d'un signe, ou la ligne entière.
  final String attendu;

  /// Les points bruts, en dp de la page.
  final List<List<PointEncre>> traits;

  /// La case : celle de la ligne pour un signe, la ligne pour une ligne.
  final Rect caseLigne;
  final Origine origine;

  /// [cleDuSigne] des traits : les mêmes traits relus prennent la classe
  /// corrigée, sans calcul.
  final String cle;
  final DateTime quand;
  final bool auStylet;

  /// La clé de chaque trait ([cleDuSigne] d'un trait seul) : une correction
  /// retire toute lecture « juste » qui partage un de ses traits.
  final List<String> clesTraits;

  /// Déjà donné à la plateforme (ADR 0042).
  final bool envoye;

  Echantillon envoyeA() => Echantillon(
    id: id,
    type: type,
    attendu: attendu,
    traits: traits,
    caseLigne: caseLigne,
    origine: origine,
    cle: cle,
    quand: quand,
    auStylet: auStylet,
    clesTraits: clesTraits,
    envoye: true,
  );

  bool get estSigne => type == 'signe';

  List<List<Offset>> get dessin => [
    for (final t in traits) [for (final p in t) p.position],
  ];

  Map<String, dynamic> versJson() => {
    'id': id,
    'type': type,
    'attendu': attendu,
    'origine': origine.name,
    'cle': cle,
    'quand': quand.toIso8601String(),
    'auStylet': auStylet,
    'clesTraits': clesTraits,
    'envoye': envoye,
    'case': [caseLigne.left, caseLigne.top, caseLigne.width, caseLigne.height],
    'traits': [
      for (final t in traits) [for (final p in t) p.versJson()],
    ],
  };
}

/// Un signe lu au tracé : ses traits, ce qu'on y a lu, la case de sa ligne.
typedef SigneDeLigne = (List<Trait> traits, String latex, Rect caseLigne);

/// Toute l'écriture gardée sur l'appareil, un seul magasin (ADR 0041,
/// 0042) : les lignes lues justes, les corrections. Rien ne part sans le
/// geste de la personne. Les signes corrigés servent aussi à lire : un
/// plus proche voisin passe avant le modèle quand il est sûr.
class Ecritures extends ChangeNotifier {
  new({this.fichier, this.plafond = 20 * 1000 * 1000});

  /// Une ligne JSON par échantillon ; `null` : en mémoire (tests).
  final File? fichier;

  /// Place maximale, en octets : au-delà, les plus anciens partent.
  final int plafond;

  final List<(Echantillon, int)> _liste = [];
  int _octets = 0;
  var _compteur = 0;

  /// Assez proche d'une correction pour en prendre la classe…
  static const double seuil = 0.5;

  /// … et plus loin d'autant des corrections d'une autre classe.
  static const double ecart = 0.25;

  /// Au plus tant de signes corrigés comparés : la lecture reste rapide.
  static const int _voisinsMaximum = 400;

  List<Echantillon> get liste => [for (final (e, _) in _liste) e];

  /// La place prise, en octets.
  int get octets => _octets;

  Iterable<Echantillon> get _corrections => _liste.reversed
      .map((e) => e.$1)
      .where((e) => e.estSigne && e.origine == Origine.correction)
      .take(_voisinsMaximum);

  Future<void> charger() async {
    final f = fichier;
    if (f == null || !f.existsSync()) return;
    _liste.clear();
    _octets = 0;
    for (final ligne in await f.readAsLines()) {
      if (ligne.trim().isEmpty) continue;
      try {
        final e = Echantillon.depuisJson(
          jsonDecode(ligne) as Map<String, dynamic>,
        );
        final n = utf8.encode(ligne).length + 1;
        _liste.add((e, n));
        _octets += n;
      } on Object {
        // Une ligne abîmée (arrêt brutal) ou de mauvaise forme : les autres
        // restent, sinon la réécriture suivante effacerait la fin du fichier.
      }
    }
    notifyListeners();
  }

  /// Les écritures sur le disque, l'une après l'autre : deux réécritures
  /// mêlées, ou un ajout pendant une réécriture, perdaient des lignes
  /// (audit 2026-11-14, M4).
  Future<void> _ecriture = Future.value();

  Future<void> _enFile(Future<void> Function() tache) {
    final suite = _ecriture.then((_) => tache());
    _ecriture = suite.then((_) {}, onError: (_) {});
    return suite;
  }

  /// Écrit tout le fichier : après un retrait.
  Future<void> _reecrire() => _enFile(_reecrireMaintenant);

  /// Nombre de réécritures faites : un ajout mis en file avant l'une d'elles
  /// est déjà dans le fichier, la réécriture ayant pris toute la liste.
  int _reecritures = 0;

  Future<void> _reecrireMaintenant() async {
    final f = fichier;
    if (f == null) return;
    _reecritures++;
    await f.parent.create(recursive: true);
    final provisoire = File('${f.path}.tmp');
    final sortie = provisoire.openWrite();
    for (final (e, _) in _liste) {
      sortie.writeln(jsonEncode(e.versJson()));
    }
    await sortie.close();
    await provisoire.rename(f.path);
  }

  Future<void> _ajouter(List<Echantillon> nouveaux, {Set<String>? retirer}) {
    var retire = false;
    if (retirer != null && retirer.isNotEmpty) {
      _liste.removeWhere((e) {
        final oui = retirer.contains(e.$1.cle);
        if (oui) _octets -= e.$2;
        retire |= oui;
        return oui;
      });
    }
    final lignes = <String>[];
    for (final e in nouveaux) {
      final ligne = jsonEncode(e.versJson());
      final n = utf8.encode(ligne).length + 1;
      _liste.add((e, n));
      _octets += n;
      lignes.add(ligne);
    }
    while (_octets > plafond && _liste.isNotEmpty) {
      _octets -= _liste.removeAt(0).$2;
      retire = true;
    }
    notifyListeners();
    final f = fichier;
    if (f == null) return Future.value();
    if (retire) return _reecrire();
    final avant = _reecritures;
    return _enFile(() async {
      if (_reecritures != avant) return;
      await f.parent.create(recursive: true);
      await f.writeAsString(
        lignes.map((l) => '$l\n').join(),
        mode: FileMode.append,
        flush: true,
      );
    });
  }

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${(_compteur++).toRadixString(36)}';

  Echantillon _echantillon(
    String type,
    List<Trait> traits,
    String attendu,
    Rect caseLigne,
    Origine origine,
  ) => Echantillon(
    id: _id(),
    type: type,
    attendu: attendu,
    traits: [for (final t in traits) List.of(t.points)],
    caseLigne: caseLigne,
    origine: origine,
    cle: '$type:${cleDuSigne(traits)}',
    quand: DateTime.now(),
    auStylet: traits.every((t) => t.auStylet),
    clesTraits: [
      for (final t in traits) cleDuSigne([t]),
    ],
  );

  /// Les lectures « justes » qui touchent ces traits : fausses, puisqu'on
  /// les corrige.
  Set<String> _justesTouchant(Echantillon correction) {
    final cles = correction.clesTraits.toSet();
    return {
      for (final (e, _) in _liste)
        if (e.origine == Origine.juste && e.clesTraits.any(cles.contains))
          e.cle,
    };
  }

  /// [signe] est un [classe] (LaTeX) : la correction remplace ce que ces
  /// traits disaient avant.
  Future<void> corrigerSigne(
    List<Trait> signe,
    String classe, {
    required Rect caseLigne,
  }) {
    final e = _echantillon(
      'signe',
      signe,
      classe,
      caseLigne,
      Origine.correction,
    );
    return _ajouter([e], retirer: {e.cle, ..._justesTouchant(e)});
  }

  /// La ligne [traits] se lit [latex] : la personne l'a dit (👎 puis
  /// correction). [signes] : ses signes lus au tracé après correction.
  Future<void> corrigerLigne(
    List<Trait> traits,
    String latex,
    Rect cadre, {
    List<SigneDeLigne> signes = const [],
  }) {
    final e = _echantillon(
      'expression',
      traits,
      latex,
      cadre,
      Origine.correction,
    );
    final retires = {e.cle, ..._justesTouchant(e)};
    final corriges = {
      for (final (x, _) in _liste)
        if (x.origine == Origine.correction && !retires.contains(x.cle)) x.cle,
    };
    final lus = [
      for (final (s, l, c) in signes)
        if (idDeClasse(l) != null)
          _echantillon('signe', s, l, c, Origine.juste),
    ].where((x) => !corriges.contains(x.cle)).toList();
    return _ajouter(
      [e, ...lus],
      retirer: {...retires, for (final x in lus) x.cle},
    );
  }

  /// Une ligne jugée juste (👍) : la ligne entière et ses signes lus au
  /// tracé. Ce que la personne a déjà corrigé n'est pas remplacé.
  Future<void> jugerJuste(
    List<Trait> traits,
    String latex,
    Rect cadre,
    List<SigneDeLigne> signes,
  ) {
    final corriges = {
      for (final (e, _) in _liste)
        if (e.origine == Origine.correction) e.cle,
    };
    final nouveaux = [
      _echantillon('expression', traits, latex, cadre, Origine.juste),
      for (final (s, l, c) in signes)
        if (idDeClasse(l) != null)
          _echantillon('signe', s, l, c, Origine.juste),
    ].where((e) => !corriges.contains(e.cle)).toList();
    return _ajouter(nouveaux, retirer: {for (final e in nouveaux) e.cle});
  }

  Future<void> toutEffacer() async {
    _liste.clear();
    _octets = 0;
    notifyListeners();
    final f = fichier;
    if (f != null && f.existsSync()) await f.delete();
  }

  /// La classe corrigée de ces traits-là, s'ils l'ont été.
  String? corrige(List<Trait> signe) {
    if (_liste.isEmpty) return null;
    final cle = 'signe:${cleDuSigne(signe)}';
    for (final e in _corrections) {
      if (e.cle == cle) return e.attendu;
    }
    return null;
  }

  /// Les classes des signes corrigés, de la plus proche à la plus loin,
  /// avec la distance du plus proche de chacune.
  List<(String, double)> voisins(List<Trait> signe) {
    final dessin = dessinDe(signe);
    final parClasse = <String, double>{};
    for (final e in _corrections) {
      final d = distanceDessins(dessin, e.dessin);
      parClasse[e.attendu] = math.min(parClasse[e.attendu] ?? d, d);
    }
    return parClasse.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
  }

  /// La classe d'un signe corrigé tout proche, si aucune autre ne s'en
  /// approche.
  String? reconnaitre(List<Trait> signe) {
    final v = voisins(signe);
    if (v.isEmpty || v.first.$2 > seuil) return null;
    if (v.length > 1 && v[1].$2 - v.first.$2 < ecart) return null;
    return v.first.$1;
  }

  bool get aDesCorrections => _corrections.isNotEmpty;

  /// Les lignes jugées pas encore données.
  int get lignesEnAttente =>
      _liste.where((e) => !e.$1.envoye && !e.$1.estSigne).length;

  /// Les dons à envoyer, par paquets de séances au format accepté par la
  /// plateforme (ADR 0042 ; `plateforme/schema.py`) : sans prénom, avec
  /// l'identifiant au hasard [contributeur]. Chaque paquet porte les ids
  /// des échantillons qu'il emporte (ceux qu'on ne peut pas donner aussi :
  /// ils quittent la file avec lui).
  List<Don> dons({
    required String contributeur,
    required String modele,
    required Size ecranDp,
    required double densite,
    String? versionApp,
    int echantillonsMax = 400,
    int pointsMax = 120000,
    int octetsMax = 1500000,
  }) {
    final paquets = <Don>[];
    for (final stylet in [true, false]) {
      final pris = [
        for (final (e, _) in _liste)
          if (!e.envoye && e.auStylet == stylet) e,
      ];
      var ids = <String>[];
      var echantillons = <Map<String, dynamic>>[];
      var points = 0;
      var octets = 0;
      DateTime? debut;
      void fermer() {
        if (echantillons.isEmpty) {
          if (ids.isNotEmpty) paquets.add(Don(ids, null));
        } else {
          paquets.add(
            Don(
              ids,
              jsonEncode({
                'format': 1,
                'licence': 'CC0-1.0',
                'contributeur': contributeur,
                'version_app': ?versionApp,
                'appareil': {
                  'modele': _modelePermis(modele),
                  'largeur_dp': ecranDp.width.round().clamp(1, 20000),
                  'hauteur_dp': ecranDp.height.round().clamp(1, 20000),
                  'densite': densite.clamp(0.1, 10),
                },
                'outil': stylet ? 'stylet' : 'doigt',
                'debut': ?(debut == null ? null : _iso(debut!)),
                'echantillons': echantillons,
              }),
            ),
          );
        }
        ids = [];
        echantillons = [];
        points = 0;
        octets = 0;
        debut = null;
      }

      for (final e in pris) {
        final json = _versFormat(e);
        final n = e.traits.fold<int>(0, (s, t) => s + t.length);
        final taille = json == null ? 0 : jsonEncode(json).length;
        if (echantillons.length >= echantillonsMax ||
            points + n > pointsMax ||
            octets + taille > octetsMax) {
          fermer();
        }
        ids.add(e.id);
        if (json == null) continue;
        echantillons.add(json);
        points += n;
        octets += taille;
        final d = debut;
        if (d == null || e.quand.isBefore(d)) debut = e.quand;
      }
      fermer();
    }
    return paquets;
  }

  /// Ces échantillons sont partis (ou ne partiront jamais).
  Future<void> marquerEnvoyes(Iterable<String> ids) {
    final pris = ids.toSet();
    for (var i = 0; i < _liste.length; i++) {
      final (e, n) = _liste[i];
      if (pris.contains(e.id) && !e.envoye) _liste[i] = (e.envoyeA(), n);
    }
    notifyListeners();
    return _reecrire();
  }

  /// Le modèle d'appareil, tel que la plateforme l'accepte.
  static String _modelePermis(String modele) {
    final net = modele.replaceAll(RegExp(r'[^A-Za-z0-9 ._+()\-]'), '_');
    final court = net.length > 64 ? net.substring(0, 64) : net;
    return court.isEmpty ? 'android' : court;
  }

  /// Les échantillons au format de `collecte/FORMAT.md`, un fichier par
  /// outil (`stylet`, `doigt`) : nom → contenu. Un signe d'une classe
  /// inconnue de `collecte/classes.txt` est laissé de côté.
  Map<String, String> exporter({
    required String modele,
    required Size ecranDp,
    required double densite,
    String auteur = '',
    DateTime? maintenant,
  }) {
    final quand = maintenant ?? DateTime.now();
    final sortie = <String, String>{};
    for (final stylet in [true, false]) {
      final pris = [
        for (final (e, _) in _liste)
          if (e.auStylet == stylet) e,
      ];
      if (pris.isEmpty) continue;
      final echantillons = [for (final e in pris) ?_versFormat(e)];
      if (echantillons.isEmpty) continue;
      final debut = pris
          .map((e) => e.quand)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final outil = stylet ? 'stylet' : 'doigt';
      final nom =
          'fikajiana-ecriture-${_sansEspace(modele)}-${_horodatage(quand)}'
          '${stylet ? '' : '-doigt'}.json';
      sortie[nom] = const JsonEncoder.withIndent(' ').convert({
        'format': 1,
        'licence': 'CC0-1.0',
        'auteur': auteur,
        'appareil': {
          'modele': modele,
          'largeur_dp': ecranDp.width.round(),
          'hauteur_dp': ecranDp.height.round(),
          'densite': densite,
        },
        'outil': outil,
        'debut': _iso(debut),
        'echantillons': echantillons,
      });
    }
    return sortie;
  }

  static Map<String, dynamic>? _versFormat(Echantillon e) {
    final id = e.estSigne ? idDeClasse(e.attendu) : null;
    if (e.estSigne && id == null) return null;
    // Les limites du récepteur (`plateforme/schema.py`) : au-delà, gardé
    // sur l'appareil mais jamais donné.
    if (e.attendu.trim().isEmpty ||
        e.attendu.length > 512 ||
        e.traits.isEmpty ||
        e.traits.length > 64 ||
        e.traits.any((t) => t.isEmpty || t.length > 4000)) {
      return null;
    }
    final premiers = [
      for (final t in e.traits)
        if (t.isNotEmpty && t.first.tempsMs != null) t.first.tempsMs!,
    ];
    final t0 = premiers.isEmpty ? 0.0 : premiers.reduce(math.min);
    double arrondi(double v) => (v * 100).roundToDouble() / 100;
    final c = e.caseLigne;
    return {
      'id': e.id,
      'type': e.type,
      'classe': ?id,
      'attendu': e.attendu,
      'traits': [
        for (final t in e.traits)
          [
            for (final p in t)
              [
                arrondi(p.x),
                arrondi(p.y),
                ((p.tempsMs ?? t0) - t0).roundToDouble(),
                // Au doigt, la pression vaut 1 (FORMAT.md).
                if (e.auStylet) arrondi(p.pression) else 1.0,
              ],
          ],
      ],
      'case': [
        arrondi(c.left),
        arrondi(c.top),
        math.max(arrondi(c.width), 0.01),
        math.max(arrondi(c.height), 0.01),
      ],
      'rejete': false,
    };
  }

  static String _sansEspace(String s) =>
      s.trim().replaceAll(RegExp('[^A-Za-z0-9_.-]+'), '_');

  static String _horodatage(DateTime d) {
    String deux(int n) => n.toString().padLeft(2, '0');
    final l = d.toLocal();
    return '${l.year}${deux(l.month)}${deux(l.day)}-'
        '${deux(l.hour)}${deux(l.minute)}${deux(l.second)}';
  }

  /// `2026-11-08T09:30:00+03:00` : l'heure locale et son décalage.
  static String _iso(DateTime d) {
    final local = d.toLocal();
    final o = local.timeZoneOffset;
    String deux(int n) => n.abs().toString().padLeft(2, '0');
    final signe = o.isNegative ? '-' : '+';
    final base = local.toIso8601String().split('.').first;
    return '$base$signe${deux(o.inHours)}:${deux(o.inMinutes % 60)}';
  }
}

/// Un paquet de dons : les échantillons qu'il emporte et le corps JSON à
/// envoyer (`null` : rien de donnable, il ne fait que vider la file).
class Don {
  const new(this.ids, this.corps);

  final List<String> ids;
  final String? corps;
}
