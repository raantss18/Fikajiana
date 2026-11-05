# Spike T2 — Giac sur Android (2026-11-05)

> Résumé : Giac compile sans Crystax avec le NDK 28 pour arm64-v8a et x86_64, et l'appel FFI fonctionne sur émulateur.
> L'exécution sur arm64 et l'annulation d'un calcul restent à prouver.

## Recette

`native/giac/construire.sh <abi>` compile tout depuis les sources : Giac au commit `19a710a` (2026-10-12), GMP 6.3.0 et
MPFR 4.2.1 (versions de `src/jni/prebuilt/README.md` de Giac), API 24, NDK 28.2.13676358, `libc++` statique.
Durée de la compilation de Giac sur cet ordinateur : 1 min 8 s.

Écarts avec le dépôt Giac :

1. **Sans pthread** : Giac annule ses calculs avec `pthread_cancel`, absent de Bionic : erreur de compilation sous
   `HAVE_LIBPTHREAD`. Ces définitions sont retirées.
2. **Correctif** `correctifs/0001-global-tampon-fread.patch` : `fread` de 32 octets dans un tampon de 24 (`global.cc`,
   `dfu_send_scriptstore`). Dépassement de tampon réel, refusé par le compilateur. À signaler en amont.

## Mesures

| Mesure | arm64-v8a | x86_64 |
|---|---|---|
| `libfikajiana_giac.so` | 19,06 Mo | 21,11 Mo |
| Alignement des segments | 16 Ko | 16 Ko |
| APK release avec Giac | 34,8 Mo | 38,3 Mo |
| APK release sans Giac | 15,8 Mo | 17,2 Mo |
| Exécution | **non essayée** | émulateur Android 16, rendu logiciel |

Premier appel (ouverture de la bibliothèque, isolat, calcul de `diff(sin(x)^2,x)`), 3 lancements : 2 416, 99 et 668 ms.
Appels suivants : le plus souvent de 0 à 19 ms, avec un écart isolé à 946 ms. Ces chiffres d'émulateur ne valent pas
pour un appareil réel.

Mémoire (`dumpsys meminfo`, TOTAL PSS) : 73,9 Mo après les 13 calculs, 66,3 Mo sans aucun appel à Giac.

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
  `liblog`, `libm`, `libdl` et `libc` ; appel FFI et 13 calculs dans un isolat sur émulateur x86_64 ; sommes SHA-256 de GMP
  et MPFR inscrites dans la recette ; mention GPL v3 ou ultérieure dans l'en-tête de `gen.cc`, et mention GPL dans 114 fichiers.
- **Supposé** : le code arm64 se comporte comme le x86_64 ; retirer pthread n'enlève pas de fonction mathématique.
- **Reste à tester** :
  1. **Exécution sur le Xiaomi Pad 7 et le Poco F8 Pro** : latence, mémoire.
  2. **Annulation** : sans pthread, rien ne prouve qu'on puisse arrêter un calcul très long. Pistes : `ctrl_c` de Giac
     (non essayé), processus séparé. À résoudre avant que l'interface propose des calculs lourds.
  3. Signatures GNU de GMP et MPFR (fichiers `.sig` non vérifiés) ; le dépôt `geogebra/giac` n'a pas de fichier `COPYING`
     et l'API GitHub ne lui attribue aucune licence : licence globale à confirmer sur la page de Xcas.
  4. Plusieurs isolats en parallèle : le contexte Giac est unique et n'est pas protégé. Les appels doivent rester
     un par un (supposé non sûr).

## Sources

https://github.com/geogebra/giac · https://github.com/geogebra/giac/blob/master/src/jni/prebuilt/android_prebuilts.sh ·
https://github.com/geogebra/giac/blob/master/src/jni/prebuilt/README.md · https://ftp.gnu.org/gnu/gmp/ ·
https://ftp.gnu.org/gnu/mpfr/ · https://www.sympy.org/
