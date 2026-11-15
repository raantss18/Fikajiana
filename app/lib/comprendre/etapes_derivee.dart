import 'package:fikajiana/comprendre/etapes.dart';
import 'package:fikajiana/moteur/giac.dart';
import 'package:fikajiana/moteur/moteur.dart';

/// `diff(corps,x)` ou `normal(diff(corps,x))` (ce que la feuille envoie à
/// Giac pour `f'(x)=` ou `\frac{d}{dx}(…)`) : le corps et la variable ;
/// `null` sinon (dérivée seconde, `f'(2)`).
({String corps, String x})? lireDerivee(String giac) {
  final m =
      RegExp(r'^normal\(diff\((.+),([a-zA-Z])\)\)$').firstMatch(giac) ??
      RegExp(r'^diff\((.+),([a-zA-Z])\)$').firstMatch(giac);
  if (m == null) return null;
  return (corps: m[1]!, x: m[2]!);
}

/// Les étapes du calcul de la dérivée de [corps] (écrit pour Giac) en [x],
/// comme au tableau : on reconnaît la forme (somme, produit, quotient,
/// puissance, fonction composée), on nomme u et v, on les dérive, on
/// applique la formule du cours, puis Giac factorise
/// (formules : programme de première et de terminale,
/// https://eduscol.education.gouv.fr/document/24553/download).
///
/// Une seule formule par calcul : u' et v' sont donnés directement par
/// Giac. `null` si la forme n'est pas reconnue : pas d'étapes plutôt que
/// des étapes fausses.
Future<List<Etape>?> etapesDerivee(
  Moteur moteur, {
  required String corps,
  required String x,
  String nom = 'f',
}) async {
  Future<ReponseGiac?> g(String entree) => giacAuTableau(moteur, entree);
  Future<String?> sommet(String e) async =>
      (await g('sommet($e)'))?.exact.replaceAll("'", '').trim();
  Future<bool?> depend(String e) async {
    final r = await g('has($e,$x)');
    return r == null ? null : r.exact.trim() != '0';
  }

  Future<ReponseGiac?> derivee(String e) => _derivee(g, e, x);

  final f = await g(corps);
  final fPrime = await derivee(corps);
  final forme = await sommet(corps);
  if (f == null || fPrime == null || forme == null) return null;
  final gauche = "$nom'($x)=";
  final etapes = <Etape>[
    Etape(RaisonEtape.deriveeDepart, '$nom($x)=${f.latex}'),
  ];
  final conclusion = Etape(RaisonEtape.conclusion, '$gauche${fPrime.latex}');
  void conclure() {
    if (etapes.last.latex != conclusion.latex) etapes.add(conclusion);
  }

  // Une formule du cours appliquée telle quelle : x, xⁿ, sin x, eˣ, 1/x…
  Future<bool> usuelle(String e) async {
    final s = await sommet(e);
    if (s == null) return false;
    if (s == 'id') return true; // x ou un nombre.
    if (const ['sin', 'cos', 'exp', 'ln', 'inv'].contains(s)) {
      return (await g('feuille($e)'))?.exact.trim() == x;
    }
    if (s == '^') {
      final base = await g('feuille($e)[0]');
      final n = await g('feuille($e)[1]');
      return base?.exact.trim() == x &&
          n != null &&
          await depend(n.exact) == false;
    }
    return false;
  }

  if (await usuelle(corps)) {
    etapes.add(Etape(RaisonEtape.usuelle, '$gauche${fPrime.latex}'));
    return etapes;
  }

  switch (forme) {
    case '+':
      final n = int.tryParse((await g('size(feuille($corps))'))?.exact ?? '');
      if (n == null || n < 2) return null;
      final termes = <String>[];
      for (var k = 0; k < n; k++) {
        final t = await g('feuille($corps)[$k]');
        if (t == null) return null;
        final d = await derivee(t.exact);
        if (d == null) return null;
        if (d.exact.trim() != '0') termes.add(d.latex);
      }
      final somme = termes.join('+').replaceAll('+-', '-');
      etapes.add(
        Etape(RaisonEtape.somme, '$gauche${somme.isEmpty ? '0' : somme}'),
      );
      conclure();
      return etapes;

    case '-':
      final u = await g('feuille($corps)');
      if (u == null) return null;
      return await _nombreFois(g, etapes, conclure, gauche, x, '-1', u);

    case '*':
      final n = int.tryParse((await g('size(feuille($corps))'))?.exact ?? '');
      if (n == null || n < 2) return null;
      final avecX = <ReponseGiac>[];
      var quotient = false;
      for (var k = 0; k < n; k++) {
        final t = await g('feuille($corps)[$k]');
        if (t == null) return null;
        if (await depend(t.exact) ?? false) {
          avecX.add(t);
          if (await sommet(t.exact) == 'inv') quotient = true;
        }
      }
      if (avecX.length == 1) {
        final k = await g('normal(($corps)/(${avecX.single.exact}))');
        if (k == null) return null;
        return await _nombreFois(
          g,
          etapes,
          conclure,
          gauche,
          x,
          k.exact,
          avecX.single,
        );
      }
      if (avecX.isEmpty) return null;
      final ReponseGiac? u;
      final ReponseGiac? v;
      if (quotient) {
        u = await g('numer($corps)');
        v = await g('denom($corps)');
      } else {
        u = avecX.first;
        v = await g('normal(($corps)/(${avecX.first.exact}))');
      }
      if (u == null || v == null) return null;
      final du = await derivee(u.exact);
      final dv = await derivee(v.exact);
      if (du == null || dv == null) return null;
      etapes
        ..add(Etape(RaisonEtape.poser, 'u($x)=${u.latex},\\ v($x)=${v.latex}'))
        ..add(
          Etape(
            RaisonEtape.deriverMorceaux,
            "u'($x)=${du.latex},\\ v'($x)=${dv.latex}",
          ),
        );
      if (quotient) {
        etapes
          ..add(
            const Etape(
              RaisonEtape.formule,
              r"\left(\frac{u}{v}\right)'=\frac{u'v-uv'}{v^{2}}",
            ),
          )
          ..add(
            Etape(
              RaisonEtape.remplacer,
              '$gauche\\frac{${_p(du)}\\cdot ${_p(v)}-${_p(u)}\\cdot '
              '${_p(dv)}}{${_puissance(v)}^{2}}',
            ),
          );
      } else {
        etapes
          ..add(const Etape(RaisonEtape.formule, "(uv)'=u'v+uv'"))
          ..add(
            Etape(
              RaisonEtape.remplacer,
              '$gauche${_p(du)}\\cdot ${_p(v)}+${_p(u)}\\cdot ${_p(dv)}',
            ),
          );
      }
      conclure();
      return etapes;
  }

  // Une seule fonction appliquée à u : 1/u, uⁿ, √u, sin u, cos u, eᵘ, ln u.
  final ReponseGiac? u;
  ReponseGiac? exposant;
  if (forme == '^') {
    u = await g('feuille($corps)[0]');
    exposant = await g('feuille($corps)[1]');
    if (exposant == null || await depend(exposant.exact) != false) return null;
  } else if (const ['inv', 'sin', 'cos', 'exp', 'ln'].contains(forme)) {
    u = await g('feuille($corps)');
  } else {
    return null;
  }
  if (u == null) return null;
  final du = await derivee(u.exact);
  if (du == null) return null;
  etapes
    ..add(Etape(RaisonEtape.poser, 'u($x)=${u.latex}'))
    ..add(Etape(RaisonEtape.deriverMorceaux, "u'($x)=${du.latex}"));
  final String formule;
  final String remplace;
  switch (forme) {
    case 'inv':
      formule = r"\left(\frac{1}{u}\right)'=-\frac{u'}{u^{2}}";
      remplace = '-\\frac{${du.latex}}{${_puissance(u)}^{2}}';
    case 'sin':
      formule = r"\left(\sin(u)\right)'=u'\cos(u)";
      remplace = '${_p(du)}\\cdot \\cos\\left(${u.latex}\\right)';
    case 'cos':
      formule = r"\left(\cos(u)\right)'=-u'\sin(u)";
      remplace = '-${_p(du)}\\cdot \\sin\\left(${u.latex}\\right)';
    case 'exp':
      formule = r"\left(e^{u}\right)'=u'e^{u}";
      remplace = '${_p(du)}\\cdot e^{${u.latex}}';
    case 'ln':
      formule = r"\left(\ln(u)\right)'=\frac{u'}{u}";
      remplace = '\\frac{${du.latex}}{${u.latex}}';
    default: // '^'
      final n = exposant!;
      if (n.exact.trim() == '1/2') {
        formule = r"\left(\sqrt{u}\right)'=\frac{u'}{2\sqrt{u}}";
        remplace = '\\frac{${du.latex}}{2\\sqrt{${u.latex}}}';
      } else {
        final moinsUn = await g('(${n.exact})-1');
        if (moinsUn == null) return null;
        // u¹ s'écrit u.
        final puissance = moinsUn.exact.trim() == '1'
            ? ''
            : '^{${moinsUn.latex}}';
        formule = "\\left(u^{${n.latex}}\\right)'=${_p(n)}u'u$puissance";
        remplace =
            '${_p(n)}\\cdot ${_p(du)}\\cdot '
            '${_puissance(u)}$puissance';
      }
  }
  etapes
    ..add(Etape(RaisonEtape.formule, formule))
    ..add(Etape(RaisonEtape.remplacer, '$gauche$remplace'));
  conclure();
  return etapes;
}

/// (ku)' = ku' : k est un nombre, ou ne dépend pas de x.
Future<List<Etape>?> _nombreFois(
  Future<ReponseGiac?> Function(String) g,
  List<Etape> etapes,
  void Function() conclure,
  String gauche,
  String x,
  String k,
  ReponseGiac u,
) async {
  final nombre = await g(k);
  final du = await _derivee(g, u.exact, x);
  if (nombre == null || du == null) return null;
  final fois = nombre.exact.trim() == '-1'
      ? '-${_p(du)}'
      : '${_p(nombre)}\\cdot ${_p(du)}';
  etapes
    ..add(Etape(RaisonEtape.poser, 'u($x)=${u.latex}'))
    ..add(Etape(RaisonEtape.deriverMorceaux, "u'($x)=${du.latex}"))
    ..add(const Etape(RaisonEtape.nombreFois, "(ku)'=ku'"))
    ..add(Etape(RaisonEtape.remplacer, '$gauche$fois'));
  conclure();
  return etapes;
}

/// La dérivée de [e] sous sa forme la plus courte : développée
/// (`-2x\sin(x^{2})`) ou factorisée (`-\frac{2}{(x-1)^{2}}`) ; développée
/// à longueur égale, comme la feuille l'écrit.
Future<ReponseGiac?> _derivee(
  Future<ReponseGiac?> Function(String) g,
  String e,
  String x,
) async {
  final developpee = await g('normal(diff($e,$x))');
  final factorisee = await g('factor(diff($e,$x))');
  if (developpee == null || factorisee == null) {
    return developpee ?? factorisee;
  }
  return factorisee.exact.length < developpee.exact.length
      ? factorisee
      : developpee;
}

/// Entre parenthèses dès qu'un `+` ou un `-` s'y trouve.
String _p(ReponseGiac r) =>
    RegExp('[+-]').hasMatch(r.latex) ? '\\left(${r.latex}\\right)' : r.latex;

/// Entre parenthèses avant un exposant, sauf une lettre ou un nombre seul.
String _puissance(ReponseGiac r) =>
    RegExp(r'^([a-zA-Z]|\d+)$').hasMatch(r.latex)
    ? r.latex
    : '\\left(${r.latex}\\right)';
