# Spike T1 — Pix2Text-MFR sur l'encre (en cours, 2026-11-05)

> Résumé : la chaîne complète tourne sur le Xiaomi Pad 7. Le taux de réussite n'est pas encore mesuré : il attend les
> 50 expressions écrites par Antsa.

## En place

- `app/lib/encre/` : canevas, annuler et refaire, rejet de la paume dès qu'un stylet a servi, gomme par le bouton du stylet.
- `app/lib/reconnaissance/` : rastérisation sur l'appareil, puis ONNX int8 par `flutter_onnxruntime`.
- `app/spike/ocr_main.dart` : 50 expressions (fractions, puissances, racines, intégrales, limites, sommes, matrices 2×2,
  systèmes, fonctions), jugées juste ou faux ; réponses et traits dans `resultats.jsonl`, dans le dossier de l'app.

## Mesures

| Mesure | Valeur | Conditions |
|---|---|---|
| Modèle int8 | 33,3 Mo (flottant : 117,6 Mo) | `models/pix2text-mfr.md` |
| Lecture | 284 ms | une seule mesure, `1/2`, traits simulés par `adb input stylus` |
| Mémoire | PSS 380 Mo, après la lecture | Pad 7 en plein écran, une seule mesure |
| APK arm64 sans le modèle | 47,4 Mo (squelette 15,8 Mo) | ONNX Runtime et `flutter_math_fork` compris, écran d'essai compris |

## Vérifié / Supposé / Reste à tester

- **Vérifié** : un `1/2` en traits simulés est lu `\frac{1}{2}` ; lecture des modèles int8 dans un APK release ; R8 avec la règle
  `-keep class ai.onnxruntime.**` demandée par le README du plugin.
- **Supposé** : un trait de vrai stylet se comporte comme le trait simulé ; la mémoire ne croît pas de lecture en lecture.
- **Reste à tester** : les 50 expressions au vrai stylet (taux exact, latence, mémoire) ; bouton du stylet et paume ;
  `pix2text-mfr-1.5` ; poids du modèle dans l'APK : il est déposé par `adb push` pour ce spike et n'est pas encore embarqué.

## Sources

https://huggingface.co/breezedeus/pix2text-mfr · https://pub.dev/packages/flutter_onnxruntime ·
https://pub.dev/packages/flutter_math_fork
