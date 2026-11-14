# ADR 0062 — Vérifier ma copie

- **Date** : 2026-11-14 · **Statut** : accepté (Antsa : « je veux que tu innoves » ; piste choisie : vérifier ma copie)
- **Décision** : quand au moins deux lignes de la même sorte sont écrites l'une sous l'autre (équations de la même inconnue, ou expressions), la liste d'une
  ligne propose « vérifier ». Un panneau relit la démarche : chaque ligne est comparée à la précédente, cochée « juste » ou signalée « à revoir ».
  L'app montre où est l'erreur sans donner la réponse (rétroaction sur la démarche plutôt que sur le résultat :
  Hattie et Timperley, *The Power of Feedback*, 2007, https://doi.org/10.3102/003465430298487).
- **Critère** : deux équations disent la même chose si `sort(simplify(solve(…)))` de Giac rend la même chose ; deux expressions si
  `simplify(a − b)` vaut 0. Une ligne se compare à la précédente, pas à l'énoncé : seule la ligne fautive est signalée, la suite reste juste.
- **Jamais « faux » sans preuve** : calcul arrêté, erreur de Giac ou sortes mêlées donnent « je n'ai pas su comparer ».
- **Vérifié** : Giac compilé pour Linux au commit de l'app, 11 démarches justes ou fautives (`tool/enregistrer_giac.dart`), réponses enregistrées pour
  `copie_test` ; `panneau_copie_test` (icône et phrase par verdict, bilan).
- **Limites** : un passage qui ajoute ou perd une solution est « à revoir » (élever au carré) ; deux écritures du même ensemble que Giac rend
  différemment seraient « à revoir » à tort : non rencontré sur les 11 démarches. **Reste à tester** : à la main sur le Pad 7 ; inéquations, systèmes.
