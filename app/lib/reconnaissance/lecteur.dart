import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/modele.dart';
import 'package:fikajiana/reconnaissance/pix2text.dart';
import 'package:fikajiana/reconnaissance/rasteriser.dart';

/// Le modèle n'est pas téléchargé.
class ModeleAbsent implements Exception {
  const new();
}

/// Transforme des traits en LaTeX : remplaçable dans les tests.
abstract class Lecteur {
  Future<String> lire(List<Trait> traits);

  /// Plusieurs lectures, la plus probable d'abord, pour une lecture douteuse.
  Future<List<String>> lirePlusieurs(List<Trait> traits) async => [
    await lire(traits),
  ];
}

class LecteurPix2Text extends Lecteur {
  new(this.modele);

  final ModeleOcr modele;
  Pix2Text? _ouvert;

  @override
  Future<String> lire(List<Trait> traits) async {
    final dossier = modele.dossier;
    if (dossier == null || modele.etat != EtatModele.present) {
      throw const ModeleAbsent();
    }
    final pix2text = _ouvert ??= await Pix2Text.ouvrir(dossier);
    final image = await rasteriserTraits(traits);
    if (image == null) return '';
    try {
      return (await pix2text.lire(await versTenseur(image))).latex;
    } finally {
      image.dispose();
    }
  }

  @override
  Future<List<String>> lirePlusieurs(List<Trait> traits) async {
    final dossier = modele.dossier;
    if (dossier == null || modele.etat != EtatModele.present) {
      throw const ModeleAbsent();
    }
    final pix2text = _ouvert ??= await Pix2Text.ouvrir(dossier);
    final image = await rasteriserTraits(traits);
    if (image == null) return const [];
    try {
      return await pix2text.lirePlusieurs(
        await versTenseur(image),
        // Une lecture douteuse ne vaut pas d'attendre sans fin.
        jetonsMaximum: 96,
      );
    } finally {
      image.dispose();
    }
  }
}
