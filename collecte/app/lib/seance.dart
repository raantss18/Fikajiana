import 'dart:math';
import 'dart:ui';

/// Un point d'encre : position en dp dans l'écran, temps en ms depuis le
/// premier point de l'échantillon, pression de 0 à 1 (collecte/FORMAT.md).
typedef PointEncre = ({double x, double y, double t, double p});

/// Ce qui est demandé à la personne : un signe, ou une expression entière.
class Demande {
  const new signe(String this.classe, this.attendu) : type = 'signe';
  const new expression(this.attendu) : type = 'expression', classe = null;

  factory json(Map<String, Object?> j) => j['type'] == 'signe'
      ? Demande.signe(j['classe']! as String, j['attendu']! as String)
      : Demande.expression(j['attendu']! as String);

  final String type;
  final String? classe;
  final String attendu;

  Map<String, Object?> toJson() => {
    'type': type,
    if (classe != null) 'classe': classe,
    'attendu': attendu,
  };
}

/// Une séance : ce qui a été écrit, et ce qui reste à demander.
class Seance {
  new({
    required this.nom,
    required this.mode,
    required this.auteur,
    required this.modele,
    required this.largeurDp,
    required this.hauteurDp,
    required this.densite,
    required this.outil,
    required this.debut,
    required this.demandes,
    this.position = 0,
    List<Map<String, Object?>>? echantillons,
  }) : echantillons = echantillons ?? [];

  /// Une nouvelle séance, les demandes mélangées.
  factory nouvelle({
    required String mode,
    required String auteur,
    required String modele,
    required Size ecran,
    required double densite,
    required String outil,
    required DateTime maintenant,
    required List<Demande> demandes,
    Random? hasard,
  }) {
    final appareil = modele.replaceAll(RegExp('[^A-Za-z0-9]+'), '-');
    return Seance(
      nom: 'fikajiana-ecriture-$appareil-${_horodatage(maintenant)}.json',
      mode: mode,
      auteur: auteur,
      modele: modele,
      largeurDp: ecran.width.round(),
      hauteurDp: ecran.height.round(),
      densite: densite,
      outil: outil,
      debut: isoLocal(maintenant),
      demandes: [...demandes]..shuffle(hasard),
    );
  }

  factory etat(Map<String, Object?> j) {
    final f = j['fichier']! as Map<String, Object?>;
    final appareil = f['appareil']! as Map<String, Object?>;
    return Seance(
      nom: j['nom']! as String,
      mode: j['mode']! as String,
      auteur: f['auteur']! as String,
      modele: appareil['modele']! as String,
      largeurDp: appareil['largeur_dp']! as int,
      hauteurDp: appareil['hauteur_dp']! as int,
      densite: (appareil['densite']! as num).toDouble(),
      outil: f['outil']! as String,
      debut: f['debut']! as String,
      demandes: [
        for (final d in j['demandes']! as List<Object?>)
          Demande.json(d! as Map<String, Object?>),
      ],
      position: j['position']! as int,
      echantillons: [
        for (final e in f['echantillons']! as List<Object?>)
          e! as Map<String, Object?>,
      ],
    );
  }

  final String nom;

  /// `signes` ou `expressions`.
  final String mode;
  final String auteur;
  final String modele;
  final int largeurDp;
  final int hauteurDp;
  final double densite;
  String outil;
  final String debut;
  final List<Demande> demandes;
  int position;
  final List<Map<String, Object?>> echantillons;

  /// L'outil a déjà été confirmé par un premier trait.
  bool get outilConfirme => echantillons.isNotEmpty;

  bool get finie => position >= demandes.length;
  Demande get demande => demandes[position];

  /// Ajoute l'échantillon de la demande en cours. Un échantillon validé passe à
  /// la demande suivante ; un raté la redemande.
  void ajouter({
    required String id,
    required List<List<PointEncre>> traits,
    required Rect cadre,
    required bool rejete,
  }) {
    final d = demande;
    echantillons.add({
      'id': id,
      'type': d.type,
      if (d.classe != null) 'classe': d.classe,
      'attendu': d.attendu,
      'traits': [
        for (final trait in traits)
          [
            for (final p in trait)
              [
                _arrondi(p.x, 2),
                _arrondi(p.y, 2),
                p.t.round(),
                _arrondi(p.p, 3),
              ],
          ],
      ],
      'case': [
        _arrondi(cadre.left, 2),
        _arrondi(cadre.top, 2),
        _arrondi(cadre.width, 2),
        _arrondi(cadre.height, 2),
      ],
      'rejete': rejete,
    });
    if (!rejete) position++;
  }

  /// Le fichier de la séance, exactement au format de `collecte/FORMAT.md`.
  Map<String, Object?> versFichier() => {
    'format': 1,
    'licence': 'CC0-1.0',
    'auteur': auteur,
    'appareil': {
      'modele': modele,
      'largeur_dp': largeurDp,
      'hauteur_dp': hauteurDp,
      'densite': densite,
    },
    'outil': outil,
    'debut': debut,
    'echantillons': echantillons,
  };

  /// L'état pour reprendre plus tard : le fichier, et ce qui reste à demander.
  Map<String, Object?> versEtat() => {
    'nom': nom,
    'mode': mode,
    'position': position,
    'demandes': [for (final d in demandes) d.toJson()],
    'fichier': versFichier(),
  };
}

num _arrondi(double v, int chiffres) {
  final f = pow(10, chiffres);
  return (v * f).round() / f;
}

String _deux(int n) => n.toString().padLeft(2, '0');

String _horodatage(DateTime d) =>
    '${d.year}${_deux(d.month)}${_deux(d.day)}-'
    '${_deux(d.hour)}${_deux(d.minute)}${_deux(d.second)}';

/// La date locale en ISO 8601 avec son décalage : `2026-11-08T09:30:00+03:00`.
String isoLocal(DateTime d) {
  final decalage = d.timeZoneOffset;
  final signe = decalage.isNegative ? '-' : '+';
  final minutes = decalage.inMinutes.abs();
  final annee = d.year.toString().padLeft(4, '0');
  return '$annee-${_deux(d.month)}-${_deux(d.day)}'
      'T${_deux(d.hour)}:${_deux(d.minute)}:${_deux(d.second)}'
      '$signe${_deux(minutes ~/ 60)}:${_deux(minutes % 60)}';
}

/// Un identifiant aléatoire de 32 chiffres hexadécimaux.
String nouvelId([Random? hasard]) {
  final h = hasard ?? Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      h.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
