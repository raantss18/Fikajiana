/// `\frac{42500000000037}{5000}` vaut exactement 8500000000.0074 : un
/// dénominateur fait de 2 et de 5 tombe juste en décimal. `null` sinon, ou si
/// ce n'est pas une fraction de deux entiers.
String? decimaleExacte(String latex) {
  final m = RegExp(r'^(-?)\\frac\{(\d+)\}\{(\d+)\}$')
      .firstMatch(latex.replaceAll(' ', ''));
  if (m == null) return null;
  final numerateur = BigInt.parse(m[2]!);
  var denominateur = BigInt.parse(m[3]!);
  // Rendre le dénominateur une puissance de 10.
  var facteur = BigInt.one;
  var chiffres = 0;
  final (deux, cinq, dix) = (BigInt.two, BigInt.from(5), BigInt.from(10));
  while (denominateur != BigInt.one) {
    if (denominateur % dix == BigInt.zero) {
      denominateur ~/= dix;
    } else if (denominateur % deux == BigInt.zero) {
      denominateur ~/= deux;
      facteur *= cinq;
    } else if (denominateur % cinq == BigInt.zero) {
      denominateur ~/= cinq;
      facteur *= deux;
    } else {
      return null;
    }
    chiffres++;
  }
  if (chiffres == 0 || chiffres > 30) return null;
  final texte = (numerateur * facteur).toString().padLeft(chiffres + 1, '0');
  final entier = texte.substring(0, texte.length - chiffres);
  final decimales = texte.substring(texte.length - chiffres);
  return '${m[1]}${_grouper(entier)}.$decimales';
}

/// `8500000000` s'écrit `8\,500\,000\,000` : on le lit d'un coup d'œil.
String _grouper(String entier) {
  if (entier.length <= 4) return entier;
  final groupes = <String>[];
  for (var fin = entier.length; fin > 0; fin -= 3) {
    groupes.insert(0, entier.substring(fin < 3 ? 0 : fin - 3, fin));
  }
  return groupes.join(r'\,');
}

/// Ce qu'on a écrit est décimal : `0,5`, `2.5` ou `10^{-4}`. Le résultat
/// s'écrit alors en décimal lui aussi, comme sur une calculatrice.
bool ecritEnDecimal(String latex) =>
    RegExp(r'\d\s*(\.|,|\{,\})\s*\d').hasMatch(latex) ||
    RegExp(r'10\s*\^\s*\{?\s*-').hasMatch(latex.replaceAll(' ', ''));
