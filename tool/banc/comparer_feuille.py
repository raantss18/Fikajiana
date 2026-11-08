#!/usr/bin/env python3
"""Compare la sortie du banc de la feuille aux valeurs numériques de SymPy (règle 8).

Usage :
  ANDROID_SERIAL=8df629a tool/banc/lancer.sh android-arm64 banc/banc_feuille.dart \\
    | python3 tool/banc/comparer_feuille.py [problème]

Seules les références numériques de `references_feuille.py` se comparent ici (les
autres se relisent à la main). Une ligne est juste si un nombre de son résultat
(approché, exact ou texte affiché) vaut la référence à 1e-6 près (relatif).
"""
import json
import pathlib
import re
import subprocess
import sys

ici = pathlib.Path(__file__).resolve().parent
refs = json.loads(
    subprocess.run(
        [sys.executable, str(ici / "references_feuille.py")],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
)
filtre = sys.argv[1] if len(sys.argv) > 1 else None
NOMBRE = re.compile(r"-?\d+(?:[.,]\d+)?(?:[eE][-+]?\d+)?")


def nombres(mesure):
    trouves = []
    for cle in ("a", "r", "t"):
        texte = mesure.get(cle) or ""
        texte = re.sub(r"\{,\}", ".", str(texte))
        for m in NOMBRE.findall(texte):
            try:
                trouves.append(float(m.replace(",", ".")))
            except ValueError:
                pass
    return trouves


justes = faux = 0
for ligne in sys.stdin:
    if "BANC {" not in ligne:
        continue
    mesure = json.loads(ligne[ligne.index("{"):])
    cle = f"{mesure['p']} | {mesure['l']}"
    attendu = refs.get(cle)
    if filtre and filtre not in mesure["p"]:
        continue
    lus = nombres(mesure)

    def vu(x):
        return any(abs(v - x) <= 1e-6 * max(1.0, abs(x)) for v in lus)

    if isinstance(attendu, bool):
        ok = mesure.get("v") is attendu
    elif isinstance(attendu, (int, float)):
        ok = vu(attendu)
    elif isinstance(attendu, list) and all(isinstance(x, (int, float)) for x in attendu):
        # Plusieurs valeurs (q et r ; le pgcd de Bézout) : toutes affichées.
        ok = all(vu(x) for x in attendu)
    else:
        continue
    if ok:
        justes += 1
    else:
        faux += 1
    print(f"{'JUSTE' if ok else 'FAUX '} {cle} : attendu {attendu}, lu {mesure.get('t')!r} v={mesure.get('v')} "
          f"(état {mesure.get('etat')}, {mesure.get('ms')} ms)")
print(f"{justes} justes, {faux} faux")
sys.exit(1 if faux else 0)
