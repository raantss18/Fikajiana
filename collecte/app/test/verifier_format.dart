/// Vérifie un fichier de séance contre `collecte/FORMAT.md`, clé par clé.
List<String> erreursFormat(Map<String, Object?> j) {
  final erreurs = <String>[];
  // Une assertion à la manière d'`expect` : le booléen d'abord, lisible.
  // ignore: avoid_positional_boolean_parameters
  void exiger(bool condition, String message) {
    if (!condition) erreurs.add(message);
  }

  exiger(
    _memesCles(j, {
      'format',
      'licence',
      'auteur',
      'appareil',
      'outil',
      'debut',
      'echantillons',
    }),
    'clés de tête : ${j.keys}',
  );
  exiger(j['format'] == 1, 'format');
  exiger(j['licence'] == 'CC0-1.0', 'licence');
  exiger(j['auteur'] is String, 'auteur');
  final a = j['appareil'];
  exiger(
    a is Map<String, Object?> &&
        _memesCles(a, {'modele', 'largeur_dp', 'hauteur_dp', 'densite'}) &&
        a['modele'] is String &&
        a['largeur_dp'] is int &&
        a['hauteur_dp'] is int &&
        a['densite'] is num,
    'appareil',
  );
  exiger(['stylet', 'doigt'].contains(j['outil']), 'outil');
  exiger(
    RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$')
        .hasMatch('${j['debut']}'),
    'debut',
  );
  final echantillons = j['echantillons'];
  if (echantillons is! List) return erreurs..add('echantillons');
  for (final e in echantillons) {
    if (e is! Map<String, Object?>) {
      erreurs.add('échantillon');
      continue;
    }
    final signe = e['type'] == 'signe';
    exiger(
      _memesCles(e, {
        'id',
        'type',
        if (signe) 'classe',
        'attendu',
        'traits',
        'case',
        'rejete',
      }),
      'clés d’échantillon : ${e.keys}',
    );
    exiger(['signe', 'expression'].contains(e['type']), 'type');
    exiger(e['id'] is String && (e['id']! as String).isNotEmpty, 'id');
    exiger(!signe || e['classe'] is String, 'classe');
    exiger(e['attendu'] is String, 'attendu');
    exiger(e['rejete'] is bool, 'rejete');
    final cadre = e['case'];
    exiger(
      cadre is List && cadre.length == 4 && cadre.every((v) => v is num),
      'case',
    );
    final traits = e['traits'];
    exiger(traits is List && traits.isNotEmpty, 'traits');
    if (traits is! List) continue;
    num? dernierT;
    for (final t in traits) {
      exiger(t is List && t.isNotEmpty, 'trait vide');
      if (t is! List) continue;
      for (final p in t) {
        final ok =
            p is List &&
            p.length == 4 &&
            p.every((v) => v is num) &&
            (p[3] as num) >= 0 &&
            (p[3] as num) <= 1 &&
            (p[2] as num) >= 0;
        exiger(ok, 'point $p');
        if (ok) {
          exiger(dernierT == null || p[2] as num >= dernierT, 'temps $p');
          dernierT = p[2] as num;
        }
      }
    }
  }
  return erreurs;
}

bool _memesCles(Map<String, Object?> m, Set<String> cles) =>
    m.keys.toSet().length == cles.length && m.keys.toSet().containsAll(cles);
