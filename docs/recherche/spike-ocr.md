# Spike T1 — Pix2Text-MFR sur l'encre (2026-11-05)

> Résumé : la chaîne complète tourne sur le Xiaomi Pad 7. Sur 50 expressions écrites au stylet par Antsa, 16 étaient justes
> au premier essai et 37 après correction de la rastérisation. Ce second chiffre est optimiste : le réglage a été choisi sur ces 50.

## Méthode

- 50 expressions de `app/spike/ocr_main.dart`, une seule fois chacune, écrites par une seule personne.
- Modèle : Pix2Text-MFR int8 (`models/pix2text-mfr.md`), décodage glouton, chaque image déformée en 384×384.
- « Juste » = même sens mathématique. Comparaison automatique par `sens()` de `models/rejouer_encre.py`, relue à la main
  pour `array` et `matrix`, qui s'écrivent autrement mais disent la même chose.
- Relecture : mêmes traits relus sur le Pad par le bouton « Relire mes traits ».

## Résultats

| Famille | Nombre | Trait épais (1/22) | Trait fin (1/70) |
|---|---|---|---|
| fraction | 6 | 1 | 6 |
| puissance | 5 | 2 | 4 |
| racine | 5 | 2 | 4 |
| intégrale | 6 | 0 | 2 |
| limite | 5 | 2 | 3 |
| somme | 5 | 0 | 3 |
| matrice | 5 | 1 | 4 |
| système | 5 | 4 | 5 |
| fonction | 8 | 4 | 6 |
| **Total** | **50** | **16 (32 %)** | **37 (74 %)** |

Antsa avait coché 19 « Juste » au premier essai ; trois ne correspondent pas à la cible (`+4/6` pour `+1/6`, `+4` pour `+1`,
`χ²` pour `x²`) : le score retenu est 16. Ces trois écarts montrent aussi que juger à l'œil est difficile : l'interface devra le faciliter.

- **Cause du gain** : le trait épais transformait `1` en `Λ` ou `4` (mesuré par les relectures ci-dessus).
- **Erreurs restantes** : `dx` et `dt` mal lus, racine d'indice perdue, confusions `x`/`a`, `ln` et `f'`, expression tronquée.
- **Latence sur le Pad 7** : médiane 276 ms, de 168 à 561 ms (trait fin). Elle croît avec la longueur, le décodeur relit tout à chaque jeton.
- **Mémoire** : PSS 405 Mo et RSS 380 Mo après les 50 relectures, sur un écran à 3200×2136.
- **Poids** : APK arm64 de 67,3 Mo avec Giac, ONNX Runtime et l'écran d'essai, modèle non compris (33,3 Mo).
- **Rejeu sur l'ordinateur** : `pix2text-mfr-1.5` ne fait pas mieux que la version 1.0 (32 contre 34 selon `sens()`, avant relecture des matrices).
  Le flottant ne fait pas mieux que l'int8 (32 contre 34).

## Vérifié / Supposé / Reste à tester

- **Vérifié** : les chiffres ci-dessus, sur le Pad 7, sur ces 50 expressions. Stylet réel, écriture d'une seule personne.
- **Supposé** : 74 % ne se généralise pas tel quel : réglage choisi sur les mêmes données, 50 exemples, une seule main.
- **Reste à tester** : nouvel essai sur d'autres expressions avec le trait fin ; autres personnes ; rejet de la paume et bouton du
  stylet ; modèle embarqué dans l'APK. La provenance des poids reste non établie (`reverification.md`).

## Sources

https://huggingface.co/breezedeus/pix2text-mfr · https://huggingface.co/breezedeus/pix2text-mfr-1.5 ·
https://pub.dev/packages/flutter_onnxruntime
