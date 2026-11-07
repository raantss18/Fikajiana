# CLAUDE.md — Fikajiana

> Calculatrice, calcul formel, graphique et géométrie plane, **avec saisie manuscrite reconnue hors ligne**.
> Android téléphone + tablette. Relire ce fichier au début de chaque étape et après chaque `/compact`.
> Ordre en cas de conflit : ce fichier > `docs/adr/` > le reste. Règles reprises de zanakiantsa, academik, mahay.

## Règles qui ne se discutent pas

1. **Rien d'inventé.** Toute affirmation technique, mathématique ou légale cite une source primaire (URL).
   Chaque livrable sépare **Vérifié / Supposé / Reste à tester**. Sans source : écrire « non vérifié ».
2. **Plan d'abord**, puis une tranche verticale minimale, puis élargissement.
3. **Rien casser.** Une décision = un ADR ≤ 15 lignes (`docs/adr/NNNN-titre.md`). Commits courts en français
   (Conventional Commits), chemins explicites (jamais `git add -A`), `main` toujours vert.
4. **Ne jamais dire « fini » sans l'avoir fait tourner** : `flutter analyze`, tests, puis essai sur émulateur (téléphone **et** tablette,
   portrait **et** paysage, chaque support) **et sur un appareil arm64 réel** : l'émulateur ne voit pas tout, capture à l'appui.
5. **Libre et 100 % hors ligne.** Licence du code : voir ADR 0001. Aucune dépendance non OSI (ni ML Kit, ni MyScript),
   modèles et poids sous licence compatible. Aucun compte, aucune pub, aucune télémétrie ; l'encre ne quitte jamais l'appareil.
   Seule exception : la recherche de mise à jour, à la demande (ADR 0015). Test réseau coupé avant chaque version.
6. **Aucun secret dans Git** (clés de signature dans `release-keys/`, ignoré).
7. **Pas de copie** d'une app existante (nom, icônes, textes, captures). Code d'un tiers repris seulement si sa licence
   est compatible, noté dans `THIRD_PARTY_LICENSES.md`.
8. **Résultats mathématiques vérifiés** : chaque fonction du moteur a des tests contre des valeurs de référence
   (sources citées ou calcul croisé avec un second logiciel).
9. **Interface** : ← retour ≠ Accueil ; cibles tactiles ≥ 48 dp ; contrastes WCAG 2.2 AA ; couleur jamais seule ;
   animations coupées si l'appareil le demande ; lecteur d'écran (TalkBack) pris en compte.
10. **Une erreur signalée ne revient jamais** : l'inscrire dans `docs/TODO.md` § 0, corriger la cause, chercher la même
    classe d'erreur ailleurs, ajouter le test qui la protège.

## Façon de travailler (reprise d'academik et de COMIMa)

- **Autonomie** : décider seul ce qui est réversible et le noter (ADR). Une branche et une PR par tâche, ouverte dès que la tâche est poussée ;
  fusionner soi-même quand tous les contrôles sont verts, si la PR ne publie rien.
- **Versions** : en sortir une après chaque modification majeure ou plusieurs améliorations, sans redemander (demande d'Antsa, 2026-11-06), une fois les contrôles passés. Chaque chiffre va de 0 à 9 : 0.1.9 → 0.2.0, 1.9.9 → 2.0.0 (`tool/version_suivante.py`).
- **Réservé à Antsa** : les clés (`release-keys/`), toute action publique hors du dépôt, un grand changement de cap.
- **Pile de PR** : ne jamais supprimer la branche d'une PR qui sert de base à une autre (les PR empilées seraient fermées).
- **Nouveautés** : une ligne fr/en sous `## [Non publié]` de `app/CHANGELOG.md`. Le message de mise à jour dit ce que la version permet de faire.
- **Léger** : mesurer le poids avant et après chaque dépendance.

## Budgets (⚠ hypothèses à recaler sur mesure)

| Élément | Budget | Mesuré |
|---|---|---|
| APK arm64, modèle compris | < 100 Mo | 66,6 Mo sans le modèle (33,3 Mo non compressé) |
| Mémoire pendant une lecture (PSS, Pad 7) | < 450 Mo | 405 Mo |
| Démarrage à froid sur le Pad 7 | < 2 s | 0,5 à 1,1 s (Fikajiana sans lecture) |
| Lecture d'une expression | < 500 ms | 276 ms en médiane, 561 ms au pire |

## Organisation

- **`docs/TODO.md`** : la liste des tâches, seule source d'avancement, mise à jour à chaque tâche.
- `docs/vision.md` : quoi et pour qui. `docs/adr/` : décisions. `docs/recherche/` : études sourcées.
- `docs/architecture.md`, `docs/design.md`, `THIRD_PARTY_LICENSES.md`, `docs/RELEASING.md`.
- Compte rendu à chaque étape : résumé ≤ 5 lignes · fichiers créés · Vérifié / Supposé / Reste à tester · sources.
- Questions à Antsa **avant** un grand chantier, une action irréversible ou publique.
