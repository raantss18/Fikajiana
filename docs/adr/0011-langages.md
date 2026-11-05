# 0011 — Langages : pas de Rust pour l'instant

- **Date** : 2026-11-05 · **Statut** : proposé à Antsa (`docs/recherche/ambition.md`)
- **Décision** : interface, graphe, géométrie et arbre mathématique en **Dart** ; calcul formel en **C++** (Giac, FFI) ; **Kotlin** seulement
  si la mesure de latence impose une vue d'encre native. Pas de Rust.
- **Raison** : Giac reste en C++ dans tous les cas ; la latence tient au front buffer d'Android, pas au langage ; Dart suit Rust de près
  sur nos deux noyaux (mesure maison sur x86, à refaire sur le Pad 7) ; Rust ajouterait une seconde chaîne à figer pour F-Droid.
- **Conditions pour changer d'avis** : le traceur dépasse le budget d'une image sur le Pad 7 après optimisation (ce seul noyau passe en C++ ou
  en Rust, derrière une façade FFI) ; un besoin de GPU compute est prouvé sans voie Flutter stable ; la latence reste mauvaise même avec une
  vue native (Kotlin pour l'écran d'encre, ou toute l'app).
- **Non retenu** : Rust natif (egui, wgpu) : TalkBack, composants et rendu LaTeX seraient à refaire ou à réévaluer, sans gain de latence démontré.
