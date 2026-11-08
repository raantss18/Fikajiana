# ADR 0042 — L'écriture gardée pendant l'usage, un seul magasin

- **Date** : 2026-11-08 · **Statut** : accepté (accord d'Antsa : « Oui ») · Suite des ADR 0038, 0040, 0041.
- **Contexte** : le modèle par signe a besoin de l'écriture réelle ; l'app de collecte (ADR 0039) demande des séances à part. Fikajiana lit déjà, au fil de l'usage, des lignes et des signes dont la personne confirme ou corrige la lecture.
- **Décision** : `Ecritures` (`app/lib/reconnaissance/ecritures.dart`) garde sur l'appareil, en une ligne JSON par échantillon, au plus 20 Mo (les plus anciens partent) :
  - une ligne lue, résultat affiché, restée sans correction 10 min ou jusqu'au changement de feuille : `expression` juste (`attendu` = le LaTeX lu), et ses signes lus au tracé (`signe`, classe de `collecte/classes.txt`) ;
  - une correction (toucher un signe, Corriger une ligne) : l'échantillon étiqueté par la correction ; elle retire toute lecture « juste » qui partage un de ses traits. Une ligne effacée avant le délai n'est pas gardée.
- **Un seul magasin** : il remplace les corrections de l'ADR 0041 ; le plus proche voisin ne compare que les signes corrigés.
- **Réglage** « Aider la reconnaissance » (activé par défaut) : coupé, rien n'est gardé, sauf les signes corrigés, qui servent à lire. Prénom = `auteur`.
- **Export** : format exact de `collecte/FORMAT.md` (CC0, un fichier par outil `stylet`/`doigt`), écrit dans `getExternalFilesDir/ecritures` (chemin affiché, lisible par `adb pull`), puis partage Android. « Effacer mes écritures » vide tout. Rien ne part sans le geste de la personne.
- **Reste** : une ligne lue juste puis corrigée plus de 10 min après garde sa correction mais a pu être exportée entre-temps ; l'appli tuée avant le délai perd les lignes en attente.
