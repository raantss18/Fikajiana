# Spike — points du stylet reçus par Flutter (2026-11-06)

> Résumé : sur le Pad 7, Flutter reçoit 97 % des points qu'Android livre, au moins, à 250 points par seconde. La perte de points
> n'est pas un problème à traiter. La latence réelle, entre la pointe et le trait affiché, n'est pas mesurée.

## Mesure

Xiaomi Pad 7, Xiaomi Focus Pen, Flutter 3.47.9, APK release, `app/spike/latence_main.dart`. Écriture d'Antsa, une session, une dizaine de secondes.

| Mesure | Valeur |
|---|---|
| Android : événements | 3 000 |
| Android : points, historique compris | 3 016 (16 seulement dans l'historique) |
| Flutter : points au stylet reçus | 2 929 (97 %) |
| Écart médian entre deux points | 4 ms, soit 250 points/s |
| Plus grand écart dans un trait | 90 ms |

- Le compte Android contient aussi les levers de stylet, pas le compte Flutter : 97 % est donc un minimum.
- Le SDK ne lit pas l'historique, mais `requestUnbufferedDispatch` fait qu'il n'y en a presque pas : 16 points sur 3 016 ici.
- 90 ms n'est pas une latence : Android n'envoie rien quand le stylet reste immobile (supposé, non isolé dans cette mesure).

## Vérifié / Supposé / Reste à tester

- **Vérifié** : les chiffres ci-dessus, sur une seule session, avec le trait dessiné en Dart.
- **Supposé** : le résultat reste vrai quand le rendu du trait devient plus lourd.
- **Reste à tester** : latence réelle au ralenti filmé, `Listener` contre `LowLatencyCanvasView` ; débit d'images avec une longue page d'encre ; Poco F8 Pro.

## Sources

https://developer.android.com/develop/ui/views/touch-and-input/stylus-input/advanced-stylus-features ·
`AndroidTouchProcessor.java` et `FlutterView.java` du SDK Flutter 3.47.9
