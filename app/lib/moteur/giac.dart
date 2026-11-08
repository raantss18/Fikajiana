import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _EvalNatif = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _LibererNatif = Void Function(Pointer<Utf8>);
typedef _Liberer = void Function(Pointer<Utf8>);

/// Évalue une expression Giac sur le fil courant.
///
/// Bloque le temps du calcul : l'interface passe par [evaluerGiac].
String evaluerGiacSurCeFil(String entree) {
  final bibliotheque = DynamicLibrary.open('libfikajiana_giac.so');
  final eval = bibliotheque.lookupFunction<_EvalNatif, _EvalNatif>(
    'fikajiana_giac_eval',
  );
  final liberer = bibliotheque.lookupFunction<_LibererNatif, _Liberer>(
    'fikajiana_giac_liberer',
  );

  final entreeNative = entree.toNativeUtf8();
  try {
    final sortieNative = eval(entreeNative);
    try {
      return sortieNative.toDartString();
    } finally {
      liberer(sortieNative);
    }
  } finally {
    malloc.free(entreeNative);
  }
}

/// Évalue une expression Giac dans un isolat, sans bloquer l'interface.
Future<String> evaluerGiac(String entree) {
  return Isolate.run(() => evaluerGiacSurCeFil(entree));
}

const String _separateur = '\x1f';

/// Le LaTeX de Giac tel qu'on l'écrit : `\mathrm{inv}\left(e^{1}\right)`
/// (pour `h(1)` avec `h(x)=xe^{-x}`, banc de la feuille) devient
/// `\frac{1}{e}`.
String latexLisible(String latex) => latex
    .replaceAllMapped(
      RegExp(r'\\mathrm\{inv\}\\left\(((?:(?!\\left|\\right).)*)\\right\)'),
      (m) => '\\frac{1}{${m[1]}}',
    )
    .replaceAll(RegExp(r'e\^\{1\}(?![0-9])'), 'e')
    // La constante d'une équation différentielle : `C_{0}`, pas `c\_0`.
    .replaceAllMapped(RegExp(r'\\mathrm\{c\\_(\d+)\}'), (m) => 'C_{${m[1]}}');

/// Réponse de Giac à [calculerGiac].
class ReponseGiac {
  const new({
    required this.exact,
    required this.latex,
    required this.approche,
    this.arrete = false,
    this.erreur,
  });

  factory analyser(String brut) {
    if (brut == 'ARRET') {
      return const ReponseGiac(
        exact: '',
        latex: '',
        approche: '',
        arrete: true,
      );
    }
    if (brut.startsWith('ERREUR: ')) {
      return ReponseGiac(
        exact: '',
        latex: '',
        approche: '',
        erreur: brut.substring(8),
      );
    }
    final morceaux = brut.split(_separateur);
    if (morceaux.length != 3) {
      return ReponseGiac(
        exact: '',
        latex: '',
        approche: '',
        erreur: 'réponse illisible : $brut',
      );
    }
    return ReponseGiac(
      exact: morceaux[0],
      latex: latexLisible(morceaux[1]),
      approche: morceaux[2],
    );
  }

  final String exact;
  final String latex;
  final String approche;
  final bool arrete;
  final String? erreur;
}

String _calculerSurCeFil(String entree, {required bool degres}) {
  final bibliotheque = DynamicLibrary.open('libfikajiana_giac.so');
  final calculer = bibliotheque
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Utf8>, Int32),
        Pointer<Utf8> Function(Pointer<Utf8>, int)
      >('fikajiana_giac_calculer');
  final liberer = bibliotheque.lookupFunction<_LibererNatif, _Liberer>(
    'fikajiana_giac_liberer',
  );
  final entreeNative = entree.toNativeUtf8();
  try {
    final sortie = calculer(entreeNative, degres ? 1 : 0);
    try {
      return sortie.toDartString();
    } finally {
      liberer(sortie);
    }
  } finally {
    malloc.free(entreeNative);
  }
}

/// Calcule dans un isolat. Un appel à la fois : le contexte Giac est unique.
Future<ReponseGiac> calculerGiac(String entree, {bool degres = false}) async =>
    ReponseGiac.analyser(
      await Isolate.run(() => _calculerSurCeFil(entree, degres: degres)),
    );

/// Demande l'arrêt du calcul en cours, depuis n'importe quel fil.
void interrompreGiac() {
  DynamicLibrary.open('libfikajiana_giac.so')
      .lookupFunction<Void Function(), void Function()>(
        'fikajiana_giac_interrompre',
      )
      .call();
}
