# Format des données d'écriture (ADR 0038)

Contrat commun entre Fikajiana (dons d'écriture, ADR 0042), la plateforme (`plateforme/`) et l'entraînement
(`entrainement/`). L'app de collecte séparée a été retirée (ADR 0039, remplacée).
Toute modification de ce fichier passe par un nouvel ADR.

## Un fichier par séance

L'app de collecte écrit un fichier JSON par séance, nommé
`fikajiana-ecriture-<appareil>-<AAAAMMJJ-HHMMSS>.json`, encodé en UTF-8 :

```json
{
  "format": 1,
  "licence": "CC0-1.0",
  "auteur": "Antsa",
  "appareil": { "modele": "2410CRP4CG", "largeur_dp": 1280, "hauteur_dp": 800, "densite": 2.75 },
  "outil": "stylet",
  "debut": "2026-11-08T09:30:00+03:00",
  "echantillons": [
    {
      "id": "c1d2…",
      "type": "signe",
      "classe": "4",
      "attendu": "4",
      "traits": [
        [[x, y, t, p], [x, y, t, p], …],
        …
      ],
      "case": [left, top, width, height],
      "rejete": false
    },
    {
      "id": "…",
      "type": "expression",
      "attendu": "\\frac{1}{x+2}",
      "traits": [ … ],
      "case": [ … ],
      "rejete": false
    }
  ]
}
```

- `x`, `y` : position en dp, dans le repère de l'écran de collecte (origine en haut à gauche).
- `t` : millisecondes depuis le premier point de l'échantillon. `p` : pression de 0 à 1 (1 au doigt).
- `classe` : l'`id` d'une ligne de `collecte/classes.txt` (type `signe` seulement).
- `attendu` : le LaTeX de ce qui était demandé.
- `case` : le cadre où l'écriture était demandée, en dp ; sert à mesurer la taille relative.
- `outil` : `stylet` ou `doigt`, pour toute la séance (le premier point de chaque trait le confirme).
- `rejete` : la personne a dit « raté » ; l'échantillon est gardé pour mémoire, l'entraînement l'ignore.

## Règles

- Rien ne quitte l'appareil sans geste de la personne : l'app enregistre localement et propose
  « Exporter », qui ouvre le partage Android (fichier), sans réseau ni compte.
- Les données versées au projet sont sous CC0 1.0 (choix d'Antsa, 2026-11-07) ; l'app le dit avant
  la première séance.
- Les fichiers versés vont dans `donnees/ecriture/` (hors Git tant qu'Antsa ne les publie pas :
  `.gitignore`), un sous-dossier par personne.
