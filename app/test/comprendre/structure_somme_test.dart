import 'package:fikajiana/comprendre/structure.dart';
import 'package:fikajiana/encre/encre.dart';
import 'package:fikajiana/reconnaissance/lecteur.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un trait par liste de points (x, y).
List<Trait> _traits(List<List<(double, double)>> dessins) {
  final encre = Encre();
  for (final d in dessins) {
    encre.commencer(PointEncre(d.first.$1, d.first.$2, 0.5));
    for (final (x, y) in d.skip(1)) {
      encre.prolonger(PointEncre(x, y, 0.5));
    }
    encre.terminer();
  }
  return encre.traits.toList();
}

/// Le Σ d'Antsa (Pad 7), `5` dessus, `n = 0` dessous, `1/(n+1)` à droite.
List<Trait> _sommeDAntsa() => _traits([
  // Σ : en haut à droite, à gauche, zigzag vers le bas, en bas à droite.
  [(60, 20), (10, 22), (40, 45), (10, 70), (62, 72)],
  // 5 au-dessus.
  [(40, -20), (22, -20), (20, -6), (36, -6), (38, 2), (22, 4)],
  // n = 0 dessous : un n à deux bosses, deux plats, un rond.
  [(8, 92), (10, 80), (18, 82), (20, 92), (22, 82), (30, 84), (32, 92)],
  [(40, 84), (52, 84)],
  [(40, 90), (52, 90)],
  [(66, 80), (60, 86), (66, 94), (72, 86), (66, 80)],
  // Le corps : 1 sur n+1.
  [(100, 20), (102, 40)],
  [(90, 48), (130, 48)],
  [(92, 58), (94, 72), (100, 60), (104, 72)],
  [(108, 64), (120, 64)],
  [(114, 58), (114, 70)],
  [(126, 56), (128, 72)],
]);

class _Modele extends Lecteur {
  @override
  Future<String> lire(List<Trait> traits) async =>
      traits.length == 6 ? r'\frac{1}{n+1}' : r'\varLambda';
}

void main() {
  test('Σ de n = 0 à 5 de 1/(n+1), bornes lues au tracé', () async {
    final traits = _sommeDAntsa();
    expect(trouverStructure(traits), isA<StructureSomme>());
    expect(
      await lireStructure(_Modele(), traits),
      r'\sum_{n=0}^{5} \frac{1}{n+1}',
    );
  });

  test('sans borne du bas, ce n’est pas une somme', () {
    final traits = _sommeDAntsa().sublist(0, 2) + _sommeDAntsa().sublist(6);
    expect(trouverStructure(traits), isNot(isA<StructureSomme>()));
  });
}
