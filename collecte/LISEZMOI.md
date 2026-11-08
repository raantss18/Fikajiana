# Fikajiana Écriture : recueillir son écriture

Petite app Android qui demande des signes et des expressions à écrire, et les garde pour
entraîner la lecture de Fikajiana (ADR 0038, 0039). Format des fichiers : [`FORMAT.md`](FORMAT.md).
Rien ne quitte l'appareil sans « Exporter » ; aucune permission réseau ; données sous CC0 1.0.

## Installer

- Sur le téléphone ou la tablette : ouvrir la page de la release `collecte-v0.1.0` du dépôt
  (https://github.com/raantss18/Fikajiana/releases), toucher `fikajiana-ecriture-0.1.0.apk`,
  puis l'ouvrir ; Android demande d'autoriser l'installation depuis le navigateur une fois.
- Depuis l'ordinateur : `adb install -r fikajiana-ecriture-0.1.0.apk`.
- Construire soi-même : `cd collecte/app && flutter build apk --release --target-platform android-arm64`
  (signé avec la clé de Fikajiana si `app/android/key.properties` existe, sinon en débogage).

## Faire une séance

1. Au premier lancement, lire l'écran sur les données, vérifier le prénom, « J'ai compris ».
2. « Nouvelle séance de signes » : chaque signe de `classes.txt` est demandé 3 fois, mélangé
   (réglable). Écrire dans la case, au stylet (ou au doigt si l'appareil n'a pas de stylet, ou si
   « Le doigt écrit » est activé).
   - **Suivant** garde l'écriture ; elle est aussi gardée seule après 1,2 s sans trait (réglable, ou jamais).
   - **Effacer** recommence le même signe, sans rien garder.
   - **Raté** garde l'écriture à part (`rejete: true`) et redemande le même signe.
3. **Pause** à tout moment : l'accueil propose ensuite « Reprendre la séance … 37 / 327 »,
   même après avoir fermé l'app.
4. « Nouvelle séance d'expressions » : 60 lignes courtes (`expressions.txt`) à recopier.

## Exporter et envoyer à Claude

- « Exporter » ouvre le partage d'Android avec les fichiers des séances
  (`fikajiana-ecriture-<appareil>-<date>.json`) : les envoyer par courriel, Drive, etc.
- Ou, l'appareil branché à l'ordinateur :

  ```bash
  adb pull /sdcard/Android/data/mg.fikajiana.collecte/files/seances donnees/ecriture/antsa
  ```

  Le chemin exact est affiché sous le bouton « Exporter ». `donnees/` n'entre pas dans Git.
