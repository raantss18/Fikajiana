# ADR 0035 — Lecture au tracé d'abord, le modèle en recours

- **Date** : 2026-11-07 · **Statut** : accepté (cap choisi par Antsa : « aller aussi vite que Mikajy »)
- **Contexte** : le modèle d'image (Pix2Text, ONNX) met ~300 ms par ligne sur le Pad 7, plus la pause ; il lit `Λ+Λ` le `1+1` d'Antsa et `1/1` son `4` ouvert. Le moteur (Giac, C++) et ONNX Runtime (C++) ne sont pas en cause : réécrire en Rust ne changerait rien.
- **Décision** : une ligne simple se lit sur son tracé (`trace_ligne.dart`) : chiffres et capitales par nuages de points ($P, ADR 0029), `+ − = × ( )` par leur forme, exposants par leur place ; quelques millisecondes, sans réseau ni dépendance. Dès qu'un signe doute (lettre minuscule, fraction, racine, mot), le modèle lit la ligne entière comme avant. Dans une matrice, chaque case suit la même règle. Les structures (`lim` sous `x → 0`, points, normes) se voient aussi au tracé.
- **Conséquences** : plus de formes propres à chaque main dans `signes.dart` (le `1` et le `4` d'Antsa) ; à étendre aux minuscules usuelles (x, y, n, t) et aux fractions pour que le modèle serve encore moins. Les traits relevés sur les captures servent de tests (`test/fixtures/telephone/`).
- **Vérifié** : tests `trace_ligne_test` (1+1 dans ses deux formes, 30×8, matrice au carré, limite). **Reste** : mesurer le gain sur le Pad 7 et le téléphone ; les minuscules.
