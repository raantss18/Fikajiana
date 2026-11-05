# Ambition : moteur, GPU, encre, langage (étude du 2026-11-05)

> Résumé : un moteur « comme Mathematica » n'existe pas en léger et hors ligne ; Giac reste le meilleur choix. Le GPU sert au
> rendu, pas au calcul formel. La reMarkable ne corrige pas l'écriture ; ce qu'elle fait (formes sur geste) est atteignable en
> libre. La qualité de reconnaissance de MyScript, elle, n'a pas d'équivalent libre trouvé. Rust n'apporte rien de mesurable ici
> aujourd'hui.

## Demande d'Antsa et réponse

| Demande | Réponse | État |
|---|---|---|
| Moteur comme wxMaxima | Couverture comparable : Giac 57,5 %, Maxima 52,5 % d'intégrales résolues [1] | atteignable |
| Moteur comme SageMath | Pas de portage Android hors ligne trouvé ; 10 Go libres pour le construire [2] | non atteignable en léger |
| Moteur comme Mathematica | Mathematica 97,4 % contre Giac 57,5 % [1] ; pas de `pdsolve` dans Giac (recherche dans les sources), EDP dans `DSolve` [3] | non atteignable |
| GPU pour le calcul | Aucun CAS généraliste sur GPU mobile trouvé ; seul travail lu : PGCD univariés modulaires [4] | non retenu |
| GPU pour le rendu | Impeller par défaut sur Android API 29+ [5] ; `FragmentProgram` disponible [6] ; `flutter_gpu` en « early preview » [7] | oui, sans `flutter_gpu` |
| Beau comme MyScript Calculator, Nebo | Rendu et gestes faisables ; voir la suite | atteignable, à construire |
| Correction instantanée comme la reMarkable | Ses notes de version ne citent aucune correction d'écriture : lignes droites (3.8) et formes sur maintien (3.17) [8] | atteignable sur geste |
| Reconnaissance du niveau de MyScript | Aucun modèle d'encre à poids et données libres trouvé | non atteignable aujourd'hui |

## Banc d'intégration [1] (106 812 intégrales, un seul auteur, été 2024)

Mathematica 97,367 % · Maple 83,761 % · FriCAS 77,213 % · **Giac 57,511 %** · Reduce 54,34 % · Maxima 52,537 % · SymPy 42,166 %.
Ce banc ne mesure que l'intégration. Comparaison fonction par fonction de Giac : non trouvée.

Licences à retenir : Symbolica est à exclure, source-available avec modifications non redistribuables [9]. Maxima sur Android :
APK de 45 Mio et version de 2015 (extrait F-Droid, page non ouverte) [10].

## Encre

- **Ce que font les produits** : MyScript Calculator calcule pendant l'écriture ou à la demande, efface par rature [11] ; MyScript
  Notes (ex-Nebo) convertit par double tap, donne des formes parfaites au maintien du stylet [12][13].
- **Composants libres** : `perfect_freehand` 2.5.2+1 (MIT) [14] ; `one_dollar_unistroke_recognizer` 1.3.5 (BSD-3) [15] ; filtre 1€ [16] ;
  `androidx.ink` 1.0.0 (natif, Apache-2.0) [17]. Saber (Flutter, GPL-3.0) dépend déjà des deux paquets Dart [18].
- **Limite de Flutter, vérifiée dans le SDK 3.47.9** : `AndroidTouchProcessor.java` ne lit aucun historique de `MotionEvent`, et
  `PointerEvent` n'a ni `coalescedEvents` ni `predictedEvents`. `FlutterView` appelle `requestUnbufferedDispatch`. Perte réelle sur le Pad 7 : à mesurer.
- **Latence** : le levier documenté est le front buffer Android (API 29+) [19]. Seul chiffre Google : 4 ms, démo sur Tab S8, sans protocole [20].
  Une `SurfaceView` en Flutter passe par la composition hybride, qui peut dégrader le débit d'images [21]. Rien ne montre 4 ms en Flutter.
- **Écriture et reconnaissance** : ne jamais lisser les points bruts destinés au modèle. Conserver les points d'origine.

## Annulation d'un calcul

`pthread_cancel` est « Unlikely to ever be implemented » dans Bionic [22]. Giac expose `volatile bool ctrl_c, interrupted`
(`global.h`), et `TIMEOUT` est compilé. Pistes dans l'ordre : `timeout N`, puis Giac dans un service `android:process=":calcul"` [23],
tué si le délai est dépassé. GeoGebra utilise un délai de 5 s (`CASgiac`) [24]. Aucune n'est essayée sur appareil.

## Tracé

Quadtree et marching squares, comme le décrivent des sources communautaires pour Desmos (extrait, non officiel) [25] ; intervalles
étendus de Tupper pour la fiabilité [26] ; Graphest (MIT, Rust) à étudier [27] ; rendu direct d'implicites sur GPU [28], à évaluer
en option : `FragmentProgram` n'a ni SSBO, ni UBO [6], et `shaderFloat64` est optionnel en Vulkan [29].

## Langage (ADR 0011)

Giac reste en C++ ; `giacrs` (MIT, 0.1.3) est en développement et demande Giac installé sur le système (extrait, page non ouverte) [30].
Marching squares sur grille de 1000×1000, Ryzen 7735HS, Dart 3.13.7 AOT contre rustc 1.99.1 `-O3` : 27,2–28,4 ms contre 21,5–21,9 ms.
Évaluation d'arbre : 25,6–26,2 ms contre 31,8–32,0 ms. Mesure maison (petit programme, pas sur ARM, sans SIMD ni fils) à refaire sur le Pad 7.
La latence d'encre tient au front buffer, pas au langage [19]. Dans Mahay, en Rust, le stylet arrive comme un toucher et TalkBack n'est pas essayé.

## Vérifié / Supposé / Reste à tester

- **Vérifié** : les points chiffrés ci-dessus, et, relus une seconde fois : [1], [8], [22], paquets et Saber, SDK Flutter local, sources de Giac.
- **Supposé** : un petit modèle réentraîné sur encre synthétique et collecte CC0 pourrait progresser (qualité inconnue) ; un calcul long dans GMP ne teste pas `ctrl_c`.
- **Reste à tester** : latence d'encre et perte de points sur le Pad 7, `timeout` et `ctrl_c`, service séparé, précision des shaders sur Adreno.

## Sources

[1] https://www.12000.org/my_notes/CAS_integration_tests/reports/summer_2024/indexchapter1.htm [2] https://github.com/sagemath/sage
[3] https://reference.wolfram.com/language/ref/DSolve.html [4] https://hgpu.org/?p=6601 [5] https://docs.flutter.dev/perf/impeller
[6] https://docs.flutter.dev/ui/design/graphics/fragment-shaders [7] https://github.com/flutter/flutter/blob/main/docs/engine/impeller/Flutter-GPU.md
[8] https://support.remarkable.com/articles/Knowledge/Release-notes-overview [9] https://raw.githubusercontent.com/symbolica-dev/symbolica/main/License.md
[10] https://f-droid.org/packages/jp.yhonda/ [11] https://myscript.com/calculator/ [12] https://help.myscript.com/notes/edit-content/pen-gestures-and-interactions/
[13] https://www.myscript.com/notes [14] https://pub.dev/packages/perfect_freehand [15] https://pub.dev/packages/one_dollar_unistroke_recognizer
[16] https://gery.casiez.net/1euro/ [17] https://developer.android.com/jetpack/androidx/releases/ink [18] https://github.com/saber-notes/saber
[19] https://developer.android.com/develop/ui/views/touch-and-input/stylus-input/advanced-stylus-features
[20] https://android-developers.googleblog.com/2024/10/introducing-ink-api-jetpack-library.html [21] https://docs.flutter.dev/platform-integration/android/platform-views
[22] https://android.googlesource.com/platform/bionic/+/refs/heads/main/docs/status.md [23] https://developer.android.com/guide/topics/manifest/service-element
[24] https://github.com/geogebra/geogebra/blob/HEAD/source/shared/common/src/main/java/org/geogebra/common/cas/giac/CASgiac.java
[25] https://cl.desmos.com/t/y-4-0-not-being-graphed/4130 [26] https://history.siggraph.org/?p=116900 [27] https://github.com/unageek/graphest
[28] https://www.mattkeeter.com/research/mpr [29] https://docs.vulkan.org/spec/latest/chapters/features.html [30] https://docs.rs/giacrs/latest/giacrs/
