# 0004 — Moteur de calcul formel : Giac

- **Date** : 2026-11-05 · **Statut** : accepté sur émulateur, à confirmer sur appareil réel (`docs/recherche/spike-giac.md`)
- **Décision** : **Giac** (GPL-3) compilé avec le NDK actuel pour arm64-v8a et x86_64, appelé par `dart:ffi`
  (chaîne d'entrée → résultat + `latex()`), dans un isolat pour ne jamais bloquer l'interface.
- **Raison** : CAS le plus complet libre et embarquable ; moteur de GeoGebra et de la HP Prime
  (https://en.wikipedia.org/wiki/Xcas) ; wrappers Android existants (https://github.com/geogebra/giac).
- **Calcul instantané** : évaluateur numérique en Dart pour l'aperçu pendant l'écriture.
- **Portage** : `native/giac/construire.sh`, NDK 28, sans Crystax ni pthread (absent de Bionic pour `pthread_cancel`).
- **Risque** : annulation d'un calcul long non prouvée. Si elle ou l'essai sur arm64 échoue, repli SymPy + Chaquopy (MIT).
