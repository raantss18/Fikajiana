# 0016 — Modèle téléchargé, jamais redistribué

- **Date** : 2026-11-06 · **Statut** : accepté (Antsa : « trouve une autre solution »)
- **Contexte** : la provenance des poids Pix2Text-MFR n'est pas publiée (`docs/recherche/reverification.md`), donc Fikajiana ne les redistribue pas.
- **Décision** : l'APK ne contient aucun poids. Réglages → « Télécharger le modèle » récupère, sur demande et une fois, les fichiers publiés par
  l'auteur, à une révision épinglée, avec vérification du SHA-256 (`lib/reconnaissance/modele.dart`). Ensuite tout marche hors ligne.
- **Sans le modèle** : saisie au clavier, même calcul. L'app reste utile.
- **Conséquences** : 117 Mo à télécharger au lieu des 33 Mo de l'int8, qu'il faudrait héberger nous-mêmes ; lecture à mesurer. La licence MIT affichée par
  l'auteur est vérifiée ; la provenance des données reste inconnue : à dire dans l'app et dans la release.
- **Permission** : `INTERNET`, seulement pour ce téléchargement et les mises à jour demandées (ADR 0015).
