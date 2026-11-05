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
