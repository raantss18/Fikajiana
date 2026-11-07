/// Le LaTeX à montrer : `flutter_math_fork` ne connaît pas `\operatorname`,
/// que le modèle écrit souvent ; la formule s'affichait alors en texte brut.
String pourAffichage(String latex) =>
    latex.replaceAll(RegExp(r'\\operatorname\*?\s*\{'), r'\mathrm{');
