# ADR 0042 — Dons d'écriture consentis, envoyés pour entraîner le modèle

- **Date** : 2026-11-08 · **Statut** : accepté (décision d'Antsa, change la règle 5 de `CLAUDE.md`)
- **Contexte** : le petit modèle par signe (ADR 0038) n'a vu qu'une main et des polices ; il lui faut l'écriture de nombreux utilisateurs. Antsa veut que les données remontent toutes seules vers une plateforme choisie avec ses amis, et ne plus passer par l'app Fikajiana Écriture.
- **Consentement** : après l'installation de la mise à jour qui l'introduit, et au premier lancement d'une installation neuve, l'app demande une fois « Aider à améliorer la reconnaissance » avec une case **non cochée** ; le choix se change à tout moment dans les Réglages. Sans « oui », rien ne part.
- **Ce qui part** : seulement les lignes jugées par la personne (👍 à côté de la ligne, ou 👎 puis correction) : traits, LaTeX juste, modèle d'appareil, version de l'app, stylet ou doigt, et un identifiant au hasard qui sert au retrait. Ni nom, ni compte, ni position, ni le reste de la feuille. Licence des dons : CC0.
- **Quand** : en arrière-plan, quand le réseau est là (option Wi-Fi seulement), par paquets, sans jamais bloquer l'app. Adresse de la plateforme réglable ; tant qu'elle est vide, rien n'est envoyé.
- **Contrôle** : voir ce qui attend, tout effacer, arrêter, demander le retrait de ce qui est parti (par l'identifiant).
- **Plateforme** : récepteur libre de référence (`plateforme/`), sans secret dans l'app, avec vérification du format, limites de taille et de débit. Choix de l'hébergement : Antsa et ses amis.
- **Entraînement** : `entrainement/` récupère les dons, les trie, et un modèle n'est embarqué que s'il bat le précédent sur un test fixe.
- **Reste** : accord parental pour les élèves mineurs ; déclaration « Sécurité des données » si l'app va sur Google Play (non vérifié).
