# Message de démarrage — session 2 (étape 2 : squelette + spikes)

Dépôt raantss18/Fikajiana, branche `claude/fikajiana-math-handwriting-app-mkyn9h` (PR #1, brouillon).

1. Lire `CLAUDE.md`, `docs/TODO.md`, `docs/adr/`, `docs/architecture.md`, `docs/recherche/`.
2. Vérifier l'outillage : `flutter --version` (3.47.9 attendu dans /opt/sdk/flutter), `very_good --version`,
   et que le serveur MCP Very Good CLI est connecté. S'il ne l'est pas : s'arrêter et le signaler (ne jamais
   contourner le hook qui interdit `flutter create` / `flutter test`).
3. Installer le SDK Android en ligne de commande (dl.google.com est autorisé) : platform-tools, platforms;android-36,
   build-tools, ndk (version stable actuelle, noter laquelle).
4. Squelette avec l'outil MCP `create` : `app/` (org `mg.fikajiana`, Android + Linux) et `packages/fikajiana_math/`
   (Dart pur). Localisation fr/en (ADR 0007). Thème Material 3 clair/sombre. `flutter analyze` + tests verts.
5. CI GitHub Actions : analyse, tests, APK arm64 + x86_64, essai émulateur téléphone et tablette avec captures.
6. Spike T1 OCR : télécharger Pix2Text-MFR (huggingface.co/breezedeus/pix2text-mfr, MIT), noter SHA-256 et tailles
   dans `models/`, quantifier int8, mesurer sur un jeu de 50 expressions manuscrites rendues depuis l'encre
   (taux exact, latence CPU, mémoire). Résultat dans `docs/recherche/spike-ocr.md`.
7. Spike T2 Giac : compiler giac (github.com/geogebra/giac) + GMP + MPFR avec le NDK actuel pour arm64-v8a et x86_64,
   appel FFI `diff(sin(x)^2,x)` → LaTeX, taille de la .so. Résultat dans `docs/recherche/spike-giac.md`.
8. Mettre à jour `docs/TODO.md` à chaque tâche ; commits courts en français, chemins explicites ; pousser sur la branche.
9. Compte rendu final : résumé ≤ 5 lignes · fichiers · Vérifié / Supposé / Reste à tester · sources (URL).
