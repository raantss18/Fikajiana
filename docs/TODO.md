# TODO — Fikajiana

> Une seule liste, tenue à jour à chaque tâche. Statuts : ✅ fait · 🔄 en cours · ⏳ à faire · ❓ décision d'Antsa.
> Une tâche n'est ✅ qu'après tests + essai réel sur appareil arm64 (`CLAUDE.md`, règle 4).
> **Ordre de travail : toujours la première ligne non faite du niveau le plus haut.** P0 avant P1, et ainsi de suite ; dans un
> niveau, de haut en bas. Détail des études : `docs/recherche/ambition.md`.

## 0. Erreurs signalées

- ✅ 2026-11-05 : « Fikajiana keeps stopping » sur téléphone (essai.1). Cause : `SMARTPTR64` de Giac tronque les étiquettes de
  pointeurs arm64. Corrigé par `correctifs/0002`. Protection : essai obligatoire sur arm64 réel, l'émulateur ne le voit pas.
- ✅ 2026-11-05 : écran d'essai `0×0 dp`, taille lue trop tôt en release, puis perdue à une réécriture. Corrigé en attendant une
  taille non nulle ; à reprendre si l'écran d'essai sert encore.
- ✅ 2026-11-05 : `tool/essai_local.sh` prenait le premier émulateur venu et a modifié `zanakiantsa_tab`. Cause corrigée :
  le script ne vise que l'AVD `fikajiana_resizable`, et `tool/essai_appareil.sh` laisse `adb` refuser s'il y a plusieurs appareils
  sans `ANDROID_SERIAL`.
- ✅ 2026-11-06 : « les réponses s'effacent quand je fais un autre calcul » (Antsa, Poco). Cause : un nouveau trait proche fusionnait avec le bloc lu, qui changeait
  de clé et perdait son résultat. Un bloc lu est maintenant stable ; tests dans `calcul_feuille_test.dart`.
- ✅ 2026-11-06 : `sin(π)` et `ln(5)` sans résultat utile : noms enveloppés (`\operatorname{sin}`) non compris, lettres absentes de l'alphabet, `ln(5)` rendu tel quel.
- ✅ 2026-11-06 : en paysage, le bandeau et le rail bloquent la feuille (Antsa, Poco). Plein écran, un bouton Menu et un bouton Outils (ADR 0018) ; test sur trois tailles.
- ✅ 2026-11-06 : `x+3=4 = {1}` est faux, et la solution n'était pas manuscrite (Antsa, Poco). La solution s'écrit à la main sous l'équation : `x = 1`, `x = -2 ou x = 2`, `S = ∅`.
  Même classe : `sin(x)=0` ne rendait que 0 et π ; Giac donne maintenant toute la famille. Tests dans `solutions_test.dart`.
- ✅ 2026-11-06 : Géométrie « pas claire et incomplète », le `=` ne dit pas « parallèle » (Antsa, Poco). Cause : des icônes génériques sans nom. Chaque outil porte son nom et un dessin propre (ADR 0019). Même classe : le bouton Outils et le Graphe restent à revoir au prochain passage de design (P5.1).
- ✅ 2026-11-06 : créer une nouvelle feuille, un graphe ou une figure n'est pas évident (Antsa). Les trois sont en tête du Menu ; graphes et figures gardés dans l'Historique. Test dans `classeur_test.dart`.
- 🔄 2026-11-06 : l'écriture manque de vie : pas de rature, pas d'animation (Antsa). Rature, fractions redressées, résultat animé et trait au doigt ajoutés (ADR 0021). Reste : essai au vrai stylet sur le Pad 7 et au doigt sur le Poco.
- ✅ 2026-11-06 : « la page est trop petite » (Antsa, Poco). Page sans bord, glisser et zoomer (ADR 0014).

## P0 — Une app qui calcule ce qu'on écrit (prioritaire)

> Ce qu'Antsa attend en premier : écrire, voir ce qui est compris, obtenir le résultat, ne rien perdre.

1. 🔄 Page sans bord : glisser, zoomer, recentrer (ADR 0014). Reste : essai au vrai stylet et au doigt
2. ✅ Sauvegarde automatique de la feuille (JSON, sur l'appareil) : revient après arrêt et réinstallation, sur le Pad 7
3. ✅ Modèle téléchargé depuis les Réglages, empreinte vérifiée, jamais redistribué (ADR 0016) : essai réel sur le Pad 7
4. ✅ `fikajiana_math` : LaTeX → Giac, 60 tests ; 30 calculs vérifiés à la main sur le Pad 7
5. ✅ Façade du moteur : un calcul à la fois ; `undef`, `infinity`, vrai ou faux traités
6. ✅ Arrêt d'un calcul long : `ifactor(2^1009-1)` et `expand((x+y+z+t)^900)` arrêtés, moteur encore utilisable ; délai de 15 s
7. ✅ Blocs : traits proches regroupés, lus à la pause
8. 🔄 **Tranche verticale** : `2+3=` écrit → `2+3 = 5` sur le Pad 7, au stylet simulé. Reste : vrai stylet
9. ✅ Correction : toucher une carte pour corriger le LaTeX ; saisie au clavier
10. ✅ Résultat écrit à la main après le `=` (ADR 0017) : `5` et la fraction `5/6` sur le Pad 7, au stylet simulé

## P1 — Mises à jour et versions

> Modèle commun à COMIMa, zanakiantsa et academik (`docs/RELEASING.md`). **Seul Antsa décide d'une publication.**

1. 🔄 Clés créées dans `release-keys/`, hors de Git. Reste : **Antsa doit les sauvegarder ailleurs**. Passage de la clé de débogage : désinstaller une fois
2. ✅ `tool/release.sh` : APK arm64, `release.json` signé, message sur ce que la version permet de faire (`app/CHANGELOG.md`)
3. ✅ Réglages → Mises à jour : version installée, « Rechercher » ; signature, SHA-256, même clé Android (ADR 0015). Rien sans le réseau, aucune donnée envoyée
4. 🔄 Essai réel : sur émulateur, 0.0.9 trouve la 0.1.0 publiée, vérifie signature et empreinte, l'installateur la pose. Reste : sur un appareil réel, avec une feuille conservée, à la version suivante
5. ✅ Provenance des poids : contournée, pas de redistribution (ADR 0016). La question reste ouverte pour un modèle embarqué (P6)
6. ✅ Première version publique : [`app-v0.1.0`](https://github.com/raantss18/Fikajiana/releases/tag/app-v0.1.0) (demandée par Antsa le 2026-11-06)
7. ✅ Version corrective `app-v0.1.1`, retours du Poco (demandée par Antsa le 2026-11-06)
8. ⏳ Installer cette version signée sur le Pad 7 et le Poco : à faire par Antsa (désinstaller l'ancienne d'abord), puis essai au vrai stylet

## P2 — Écriture et reconnaissance de qualité

1. ⏳ Réglage au vrai stylet : épaisseur, pression, retard du lissage, seuils des formes ; pointe du trait irrégulière en fin de ligne
2. ⏳ Rejet de la paume et bouton du stylet, au vrai stylet
3. ⏳ Latence réelle, caméra rapide sur Pad 7 : `Listener`, puis `LowLatencyCanvasView` si besoin. Aucun objectif chiffré avant
4. ⏳ Débit d'images sur une longue page d'encre
5. ⏳ Nouvel essai OCR sur d'autres expressions : 37/50 est optimiste (`docs/recherche/spike-ocr.md`)
6. ⏳ T3 Segmentation : système à accolade et matrice 2×2 découpés correctement sur 20 essais
7. 🔄 Gestes : ✅ rature pour effacer (ADR 0021). Reste : barré, alternatives proposées à la correction
8. ⏳ Sélection, déplacement et copie d'un bloc ; copie du LaTeX
9. ⏳ Alternative au glissement sans geste, boutons de déplacement (WCAG 2.2, critère 2.5.7 ; le zoom a déjà ses boutons)

## P3 — Calcul formel complet

1. ⏳ Types devinés : calcul, équation, système, fonction, matrice, suite ; actions proposées (résoudre, dériver, intégrer, tracer)
2. ⏳ Dérivées, primitives et intégrales, limites, suites et séries, polynômes, matrices, équations et systèmes
3. ⏳ Banc de tests croisé avec SymPy pour chaque famille ; effet de `DOUBLEVAL` et du retrait de pthread
4. ⏳ Liste publique et honnête de ce que l'app sait faire ou non ; manques comblés par règles ciblées
5. ⏳ Signaler à Giac le dépassement de tampon (action publique : à valider par Antsa)
6. ❌ Écarté : SageMath, Maxima (lourds), Symbolica (licence), calcul formel sur GPU (aucune preuve d'intérêt)

## P4 — Graphique et géométrie

1. 🔄 Traceur Dart : ✅ fonctions `y=f(x)`, échantillonnage adaptatif, coupures, glisser, zoom, lecture d'un point. Reste : quadtree et marching squares (implicites), budget d'une image mesuré sur un appareil réel
2. ⏳ Courbes paramétrées, polaires, implicites ; tableau de valeurs ; écran partagé sur tablette
3. ⏳ Fiabilité des implicites : intervalles façon Tupper, à comparer à `graphest` (MIT)
4. ⏳ `FragmentProgram` en option pour aperçus et fonds denses, avec repli CPU ; pas de `flutter_gpu` en préversion
5. 🔄 Géométrie dynamique (ADR 0019) : ✅ 40 outils, points sur objet, arcs, polygones, coniques, transformations, mesures, curseurs animés, lieux, relations, liste et propriétés des objets, annuler et refaire, aimant. Reste : texte libre, trace d'un point, fonctions dans la figure, saisie d'équations, formes dessinées reconnues, tangence entre coniques
6. ✅ Historique : plusieurs feuilles, graphes et figures, reprise de l'existant ; création depuis le Menu

## P5 — Design, confort et accessibilité

> Méthode : `docs/design.md`. Le plus visible passe en P0 et P2 ; ici, la finition.

1. ⏳ Passe de design sur chaque écran : barre d'outils, Réglages, états vides ; maquettes Penpot si utile
2. ⏳ Choix de la langue dans les réglages, malgré la langue de l'appareil ; revue fr/en de tous les textes
3. ⏳ Historique : feuilles enregistrées, renommer, supprimer avec annulation
4. ⏳ TalkBack réel, grands textes, animations coupées (dont l'indicateur de la barre du bas)
5. ⏳ **Exporter une feuille en PDF ou PNG** (demande d'Antsa, pas urgent)
6. ⏳ Essais du script sur chaque support : `tool/essai_appareil.sh` bascule encore le mode de l'appareil (ADR 0012)
7. ⏳ Budgets de `CLAUDE.md` mesurés à chaque version ; alléger l'APK

## P6 — Plus tard

1. ⏳ F-Droid : Giac, GMP, MPFR compilés dans la recette ; builds reproductibles
2. ⏳ Modèle d'encre maison sur données libres (synthétiques + collecte CC0)
3. ⏳ Vérifier les signatures GNU de GMP et MPFR, licence des gabarits Very Good CLI, Maxima (`reverification.md`)
4. ⏳ Poids du modèle réduit ; `pix2text-mfr-1.5` à réévaluer sur une nouvelle mesure
4b. ⏳ Résultat dans l'écriture de l'utilisateur, à partir de ses propres chiffres (non étudié) ; élargir l'alphabet
5. ⏳ 3D : différée (ADR 0005)

## Fait

- ✅ Cadrage : dépôt `raantss18/Fikajiana`, GPL-3.0-or-later, français et anglais, appareils (ADR 0001, 0007, 0008)
- ✅ Études : `ocr-manuscrit.md`, `moteurs.md`, `reverification.md`, `ambition.md` ; langages (ADR 0011)
- ✅ Squelette, navigation ← ≠ Accueil, thème, CI GitHub Actions, constructions locales (ADR 0006, 0009)
- ✅ T2 Giac : arm64 et x86_64, FFI sur le Pad 7 (`spike-giac.md`) ; essai sur le Poco en attente d'un rapport
- ✅ T1 OCR : chaîne sur le Pad 7, 37/50 (`spike-ocr.md`) ; à confirmer en P2
- ✅ Identité : π, palette, icône, Nunito (ADR 0010, `docs/design.md`)
- ✅ Supports, stylos, gomme (ADR 0012) ; lancés sur le Poco par Antsa, sans latence ressentie
- ✅ Points du stylet : au moins 97 % reçus, 250 points/s (`spike-latence.md`)
- ✅ Trait à pression, formes au maintien (ADR 0013) ; à régler au vrai stylet en P2
