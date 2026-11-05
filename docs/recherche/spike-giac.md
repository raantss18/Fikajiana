# Spike T2 — Giac sur Android (2026-11-05)

> Résumé : Giac compile sans Crystax avec le NDK 28 pour arm64-v8a et x86_64, et l'appel FFI fonctionne sur le Xiaomi Pad 7.
> L'annulation d'un calcul reste à prouver.

## Recette

`native/giac/construire.sh <abi>` compile tout depuis les sources : Giac au commit `19a710a` (2026-10-12), GMP 6.3.0 et
MPFR 4.2.1 (versions de `src/jni/prebuilt/README.md` de Giac), API 24, NDK 28.2.13676358, `libc++` statique.
Durée de la compilation de Giac sur cet ordinateur : 1 min 8 s.

Écarts avec le dépôt Giac :

1. **Sans pthread** : Giac annule ses calculs avec `pthread_cancel`, absent de Bionic : erreur de compilation sous
   `HAVE_LIBPTHREAD`. Ces définitions sont retirées.
2. **Correctif** `correctifs/0001-global-tampon-fread.patch` : `fread` de 32 octets dans un tampon de 24 (`global.cc`,
   `dfu_send_scriptstore`). Dépassement de tampon réel, refusé par le compilateur. À signaler en amont.
3. **Sans `SMARTPTR64`** (`correctifs/0002-first-sans-smartptr64.patch`, avec `DOUBLEVAL`) : ce mode efface les bits hauts
   des pointeurs. Sur arm64, Android 11+ y met une étiquette, vérifiée à la libération de la mémoire.
   Mesuré sur le Pad 7 avec la première version : `Pointer tag for 0x7383b10c80 was truncated`, `SIGABRT`, dans `free`
   appelé depuis `libfikajiana_giac.so`. L'émulateur ne le montre pas, même avec l'APK arm64 traduit :
   **seul un appareil arm64 réel valide ce point**. L'option `allowNativeHeapPointerTagging` n'est pas utilisée :
   Android annonce son retrait (https://source.android.com/docs/security/test/tagged-pointers).

## Mesures

| Mesure | arm64-v8a | x86_64 |
|---|---|---|
| `libfikajiana_giac.so` | 19,91 Mo | 22,02 Mo |
| Alignement des segments | 16 Ko | 16 Ko |
| APK release avec Giac et écran d'essai | 36,7 Mo | 40,3 Mo |
| APK release sans Giac | 15,8 Mo | 17,2 Mo |
| Exécution | **Xiaomi Pad 7** (Android 16) | émulateur Android 16, rendu logiciel |

**Xiaomi Pad 7** : premier appel (bibliothèque, isolat, `diff(sin(x)^2,x)`) 48 et 16 ms sur 2 lancements relevés ; appels
suivants de 0 à 6 ms. Les 13 calculs aboutissent, sans erreur dans le journal. Mémoire : PSS de 244 à 257 Mo en plein écran
après les calculs, RSS de 195 à 204 Mo vu par l'app. Sur l'émulateur, avant ce correctif : premier appel 99 à 2 416 ms.

## Résultats comparés à SymPy 1.14.0

| Entrée | Giac | SymPy |
|---|---|---|
| `diff(sin(x)^2,x)` | `2*cos(x)*sin(x)` | `2*sin(x)*cos(x)` |
| `latex(diff(sin(x)^2,x))` | `"2 \cos\left(x\right) \sin\left(x\right)"` | non comparé |
| `integrate(1/(x^2+1),x)` | `atan(x)` | `atan(x)` |
| `limit(sin(x)/x,x,0)` | `1` | `1` |
| `solve(x^2-2=0,x)` | `list[-√2,√2]` | `[-sqrt(2), sqrt(2)]` |
| `factor(x^4-1)` | `(x-1)*(x+1)*(x^2+1)` | `(x - 1)*(x + 1)*(x**2 + 1)` |
| `det([[1,2],[3,4]])` | `-2` | `-2` |
| `sum(1/k^2,k,1,inf)` | `1/6*pi^2` | `pi**2/6` |
| `2^200` | `160693…301376` | identique |
| `1/3+1/6` | `1/2` | `1/2` |
| `evalf(pi,30)` | `3.14159265358979323846264338328` | identique |

À traiter dans la façade : `1/0` rend `infinity` et l'entrée invalide `2+` rend `undef`, sans erreur levée. Le résultat
de `latex()` est entre guillemets ; `solve` rend `list[…]` et le caractère `√`, à cause de `GIAC_GGB` (supposé).

## Vérifié / Supposé / Reste à tester

- **Vérifié** : compilation des deux ABI ; `.so` arm64 de type AArch64, deux symboles exportés, dépendances limitées à
  `liblog`, `libm`, `libdl` et `libc` ; appel FFI et 13 calculs dans un isolat sur le Xiaomi Pad 7 et sur émulateur ; sommes SHA-256 de GMP
  et MPFR inscrites dans la recette ; mention GPL v3 ou ultérieure dans l'en-tête de `gen.cc`, et mention GPL dans 114 fichiers.
- **Supposé** : retirer pthread et `SMARTPTR64` n'enlève pas de fonction mathématique et ne change pas les résultats
  au-delà des 13 calculs essayés ; `DOUBLEVAL` double la taille de `gen` (16 octets, voir `gen.h`), effet non mesuré.
- **Reste à tester** :
  1. **Poco F8 Pro** : même essai, avec l'APK de la version `0.1.0-essai.2`.
  2. **Annulation** : sans pthread, rien ne prouve qu'on puisse arrêter un calcul très long. Pistes : `ctrl_c` de Giac
     (non essayé), processus séparé. À résoudre avant que l'interface propose des calculs lourds.
  3. Signatures GNU de GMP et MPFR (fichiers `.sig` non vérifiés) ; le dépôt `geogebra/giac` n'a pas de fichier `COPYING`
     et l'API GitHub ne lui attribue aucune licence ; la page de Xcas annonce GPL3 (https://xcas.univ-grenoble-alpes.fr/en.html).
  4. Plusieurs isolats en parallèle : le contexte Giac est unique et n'est pas protégé. Les appels doivent rester
     un par un (supposé non sûr).

## Sources

https://github.com/geogebra/giac · https://github.com/geogebra/giac/blob/master/src/jni/prebuilt/android_prebuilts.sh ·
https://github.com/geogebra/giac/blob/master/src/jni/prebuilt/README.md · https://ftp.gnu.org/gnu/gmp/ ·
https://ftp.gnu.org/gnu/mpfr/ · https://www.sympy.org/
