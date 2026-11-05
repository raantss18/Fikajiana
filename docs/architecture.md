# Architecture — Fikajiana (proposition du 2026-11-05)

```
app/                         application Flutter (Android + Linux pour le développement)
  lib/
    ui/                      écrans, thème, composants (feature-first : calcul/, graphe/, geometrie/, historique/)
    encre/                   canevas d'écriture (stylet + doigt, pression, gomme, annuler/refaire)
    reconnaissance/          segmentation des traits → rastérisation → ONNX → LaTeX + alternatives
    comprendre/              LaTeX → arbre (AST) → type : calcul | équation | système | fonction | matrice | suite
    moteur/                  façade CAS (isolat) : Giac FFI ; évaluateur numérique Dart pour l'aperçu
    graphe/                  traceur (échantillonnage adaptatif, implicite, tableau de valeurs)
    geometrie/               noyau dynamique (objets libres/construits, contraintes, mesures, lieux)
packages/
  fikajiana_math/            Dart pur, sans Flutter : AST, parseur LaTeX, classification, évaluateur, géométrie
native/giac/                 recette de compilation NDK (arm64-v8a, x86_64) + en-tête C minimal pour FFI
models/                      fiche de chaque modèle ONNX (licence, empreinte SHA-256) ; poids hors Git
```

## Flux principal

encre → segmentation (lignes, accolade `{`, matrices) → reconnaissance par bloc → LaTeX → AST → **type deviné**
→ actions proposées (calculer, valeur approchée, résoudre, dériver, intégrer, limite, tracer, construire) → Giac
→ résultat exact (LaTeX) → affiché sous l'écriture, éditable.

## Écrans

1. **Feuille** (accueil) : page infinie quadrillée, écriture libre ; chaque bloc reconnu devient une « cellule » avec
   son résultat. Clavier mathématique en repli.
2. **Graphe** : fonctions de la feuille tracées ; écran partagé sur tablette (feuille | graphe).
3. **Géométrie** : outils de construction en barre latérale (tablette) ou tiroir (téléphone) ; on peut aussi
   **dessiner** un cercle ou un segment à main levée → reconnu comme objet.
4. **Historique / fichiers** : feuilles enregistrées localement (format ouvert JSON).

## Adaptatif

Classes de largeur Material (compacte < 600 dp, moyenne, étendue ≥ 840 dp) : une colonne sur téléphone,
deux panneaux sur tablette paysage. Stylet : rejet de la paume, bouton du stylet = gomme.
