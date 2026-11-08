"""Fabrique `cas_schema.json` : des séances valides et invalides, avec le verdict de `schema.py`.

Le Worker JavaScript (`worker/test/schema.test.mjs`) doit rendre le même verdict sur chaque cas.
Relancer après toute modification du schéma : `uv run python tests/fabriquer_cas.py`.
"""

import copy
import json
import pathlib
import sys

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI.parent))
sys.path.insert(0, str(ICI))

import schema  # noqa: E402
from conftest import SEANCE, seance  # noqa: E402

CIBLE = ICI / "cas_schema.json"


def ech(i, **changes):
    s = seance()
    s["echantillons"][i].update(changes)
    return s


def sans(cle):
    s = seance()
    del s[cle]
    return s


def documents():
    e1 = SEANCE["echantillons"][1]
    minimum = {k: SEANCE[k] for k in ("format", "licence", "contributeur", "outil")}
    minimum["echantillons"] = [{"type": "expression", "attendu": "x", "traits": []}]
    appareil_en_trop = seance()
    appareil_en_trop["appareil"]["numero_serie"] = "123"
    yield "valide", seance()
    yield "minimum", minimum
    yield "racine seule", seance(echantillons=[{"type": "signe", "classe": "racine", "attendu": "\\sqrt", "traits": [[[0, 0, 0, 1]]]}])
    yield "latex non ASCII", ech(1, attendu="x≤2 et π")
    for champ, valeur in [("auteur", "Antsa"), ("position", [-18.9, 47.5]), ("email", "a@b.c")]:
        yield f"champ en trop {champ}", seance(**{champ: valeur})
    yield "champ en trop dans appareil", appareil_en_trop
    yield "champ en trop dans échantillon", ech(0, lieu="Antananarivo")
    yield "licence", seance(licence="CC-BY-4.0")
    yield "format 2", seance(format=2)
    yield "format booléen", seance(format=True)
    yield "contributeur court", seance(contributeur="court")
    yield "contributeur chemin", seance(contributeur="a/../../etc/passwd/xx")
    yield "outil", seance(outil="souris")
    yield "version_app", seance(version_app="dernière")
    yield "debut", seance(debut="hier")
    yield "echantillons vide", seance(echantillons=[])
    yield "echantillons texte", seance(echantillons="x")
    yield "licence manquante", sans("licence")
    yield "trop d'échantillons", seance(echantillons=[e1] * 501)
    # (« plus de 150 000 points » : trop gros pour ce fichier ; testé à part dans chaque langage.)
    for nom, i, changes in [
        ("classe inconnue", 0, {"classe": "inconnu"}),
        ("attendu ≠ classe", 0, {"attendu": "-"}),
        ("classe sur expression", 1, {"classe": "plus"}),
        ("type", 0, {"type": "dessin"}),
        ("rejete texte", 0, {"rejete": "non"}),
        ("case à 3", 0, {"case": [0, 0, 10]}),
        ("case largeur nulle", 0, {"case": [0, 0, 0, 10]}),
        ("latex long", 1, {"attendu": "x" * 513}),
        ("latex 512 non ASCII", 1, {"attendu": "π" * 512}),
        ("latex 513 non ASCII", 1, {"attendu": "π" * 513}),
        ("latex vide", 1, {"attendu": "  "}),
        ("latex contrôle", 1, {"attendu": "a\nb"}),
        ("point à 3", 0, {"traits": [[[1, 2, 3]]]}),
        ("temps négatif", 0, {"traits": [[[1, 2, -1, 0.5]]]}),
        ("pression > 1", 0, {"traits": [[[1, 2, 3, 1.5]]]}),
        ("x énorme", 0, {"traits": [[[1e9, 2, 3, 0.5]]]}),
        ("x booléen", 0, {"traits": [[[True, 2, 3, 0.5]]]}),
        ("x texte", 0, {"traits": [[["1", 2, 3, 0.5]]]}),
        ("65 traits", 0, {"traits": [[[0, 0, 0, 0]]] * 65}),
        ("4001 points", 0, {"traits": [[[0, 0, 0, 0]] * 4001]}),
    ]:
        yield nom, ech(i, **changes)


def textes_bruts():
    yield "NaN", '{"a": NaN}', False
    yield "Infinity", '{"a": Infinity}', False
    yield "illisible", "{", False
    yield "pas un objet", "[1, 2]", False
    # Écarts connus (JSON.parse) : sans effet sur ce qui est stocké, le Worker réécrit le JSON lu.
    texte = json.dumps(seance())
    yield "clé répétée", texte[:-1] + ', "licence": "CC0-1.0"}', None
    yield "format 1.0", texte.replace('"format": 1', '"format": 1.0'), None


def verdict(texte):
    try:
        n = schema.verifier_seance(schema.analyser_json(texte.encode("utf-8")), schema.lire_classes())
        return True, n
    except schema.DonInvalide:
        return False, None


def fabriquer():
    cas = []
    for nom, doc in documents():
        texte = json.dumps(doc, ensure_ascii=False)
        valide, n = verdict(texte)
        cas.append({"nom": nom, "texte": texte, "valide": valide, "recu": n})
    for nom, texte, attendu in textes_bruts():
        valide, n = verdict(texte)
        assert attendu in (None, valide)
        cas.append({"nom": nom, "texte": texte, "valide": valide, "recu": n, "python_seulement": attendu is None})
    return cas


if __name__ == "__main__":
    CIBLE.write_text(json.dumps(fabriquer(), ensure_ascii=False, indent=0) + "\n", encoding="utf-8")
    print(f"{CIBLE} écrit")
