# 0004 — Moteur de calcul formel : Giac

- **Date** : 2026-11-05 · **Statut** : proposé (portage NDK à prouver, tranche T2)
- **Décision** : **Giac** (GPL-3) compilé avec le NDK actuel pour arm64-v8a et x86_64, appelé par `dart:ffi`
  (chaîne d'entrée → résultat + `latex()`), dans un isolat pour ne jamais bloquer l'interface.
- **Raison** : CAS le plus complet libre et embarquable ; moteur de GeoGebra et de la HP Prime
  (https://en.wikipedia.org/wiki/Xcas) ; wrappers Android existants (https://github.com/geogebra/giac).
- **Calcul instantané** : évaluateur numérique en Dart pour l'aperçu pendant l'écriture.
- **Risque** : chaîne Android basée sur Crystax NDK 10.2.1 (obsolète) → si le portage échoue, repli SymPy + Chaquopy (MIT).
