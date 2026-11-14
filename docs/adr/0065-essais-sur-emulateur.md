# ADR 0065 — Essais : le Pad 7 par ADB sans fil, sinon l'émulateur léger

- **Date** : 2026-11-14 · **Statut** : accepté (Antsa : « on doit se contenter d'émulateur mais pas de tablette pour le test, ou activer adb wifi »).
  Remplace, dans `CLAUDE.md` § 4, l'essai obligatoire sur le Xiaomi Pad 7 avant de dire « fini ».
- **Mise à jour le même jour** : Antsa a activé le débogage sans fil ; le Pad 7 est joignable sans câble (`adb mdns services`), et redevient
  l'essai de référence. L'émulateur sert quand le Pad n'est pas joignable.
- **Décision** : sans le Pad, l'essai d'une version se fait sur l'émulateur léger (ADR 0057), APK x86_64 du même code, en tablette (`wm size 2560x1600`) et en
  téléphone, avec capture. Le Pad 7 sert quand Antsa l'appaire par ADB sans fil (Android 11+ : Options pour les développeurs → Débogage sans
  fil → code d'association, puis `adb pair` et `adb connect`, https://developer.android.com/tools/adb#connect-to-a-device-over-wi-fi).
- **Ce que l'émulateur ne montre pas** : le code arm64 réel (Giac y a déjà eu un défaut propre à arm64, ADR 0008), le vrai stylet et sa
  pression, l'installateur d'Android (image ATD), la mémoire et la vitesse d'un appareil. Chaque compte rendu le dit dans « Reste à tester ».
- **Conséquence** : une version peut sortir après l'essai sur l'émulateur ; ce qui dépend d'arm64 ou du stylet reste noté au TODO jusqu'à un
  essai sur appareil.
