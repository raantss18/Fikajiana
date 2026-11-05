# 0009 — Squelette : ce qui est retiré du gabarit

- **Date** : 2026-11-05 · **Statut** : accepté (plan validé par Antsa)
- **Décision** : `app/` et `packages/fikajiana_math/` générés par Very Good CLI 1.6.0, puis allégés : plateformes
  Android + Linux seules, une seule saveur, pas de bloc pour l'instant, Material du SDK Flutter au lieu de `material_ui`.
- **Raison** : `material_ui` n'est pas servi par `flutter_localizations` : en français, `AppBar` lève « No
  MaterialLocalizations found » (mesuré, protégé par le test `langues français`). Le reste n'a aucun usage aujourd'hui.
- **Linux** : le gabarit `flutter_app` n'a pas de `linux/` ; dossier repris de l'exemple du gabarit `flutter_plugin`.
- **Android** : Kotlin 2.2.20 (minimum exigé par Flutter 3.47.9) et `buildToolsVersion = "36.0.0"` : AGP 8.12 vise
  par défaut 35.0.0, absent ici, et Gradle est resté bloqué 1 h 16 sur le dépôt distant du SDK (mesuré le 2026-11-05).
- **Différé** : gestion d'état (décidée quand un écran en aura besoin) ; AGP 9 et Kotlin 2.3.20 (avertissements Flutter).
