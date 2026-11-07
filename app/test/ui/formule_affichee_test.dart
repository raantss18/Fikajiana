import 'package:fikajiana/ui/formule_affichee.dart';
import 'package:fikajiana_math/fikajiana_math.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Ce que `Math.tex` sait rendre, sinon il montre le texte brut.
  bool rendu(String latex) {
    try {
      TexParser(latex, const TexParserSettings()).parse();
      return true;
    } on ParseException {
      return false;
    }
  }

  test(r'le modèle écrit \operatorname, la formule s’affiche quand même', () {
    const lu = r'\operatorname{moyenne}\left(2;4;9\right)';
    expect(rendu(pourAffichage(lu)), isTrue);
  });

  test('chaque commande tapée s’affiche en formule (vu sur le Pad 7)', () {
    for (final texte in [
      'moyenne(2;4;9)',
      'développer((x+1)^2)',
      'Écart-type(2;4)',
      'médiane(1;2;3;4)',
      'tangente(f;2)',
      'arrondi(2/3;2)',
      'discriminant(x^2-3x+2)',
    ]) {
      final latex = lireSaisie(texte).latex!;
      expect(rendu(pourAffichage(latex)), isTrue, reason: latex);
    }
  });
}
