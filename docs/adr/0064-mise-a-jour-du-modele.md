# ADR 0064 — Mettre à jour le modèle de lecture depuis l'app

- **Date** : 2026-11-14 · **Statut** : accepté (Antsa : « on n'a plus besoin de l'entraînement, mais juste une façon de mettre à jour le modèle depuis
  l'app directement »). L'entraînement du petit modèle par signe (ADR 0038, 0040) n'est plus poursuivi.
- **Décision** : Réglages → Lecture de l'écriture → « Rechercher une mise à jour du modèle ». À la demande seulement (comme ADR 0015), l'app lit
  `modele.json` et `modele.json.sig` publiés avec chaque version (`releases/latest/download`) : version, adresse et, pour chaque fichier, taille et SHA-256.
- **Sûreté** : la fiche est signée Ed25519 par la clé des versions (`lireJsonSigne`) ; les noms de fichiers doivent être exactement ceux que le lecteur
  ouvre (pas de chemin), l'adresse en HTTPS, chaque empreinte vérifiée ; le nouveau modèle est téléchargé à côté de l'ancien puis le remplace d'un coup ;
  au moindre échec l'ancien reste. Rien de l'écriture n'est envoyé.
- **Publier un modèle** : changer `models/modele.json` (version + 1, adresse, tailles, empreintes) ; `tool/release.sh` le copie et le signe.
  Le format ne change jamais (`"format": 1`). Le nouveau modèle sert au prochain démarrage de l'app.
- **Vérifié** : `maj_modele_test` (serveur local : proposé, installé, retrouvé au redémarrage ; même version ; autre clé refusée ; fichier changé :
  l'ancien reste ; formes inattendues). **Reste à tester** : sur appareil avec une vraie version 2 ; rechargement du modèle sans redémarrer.
