import pytest

import schema
from conftest import SEANCE, seance

CLASSES = schema.lire_classes()


def verifier(doc):
    return schema.verifier_seance(doc, CLASSES)


def test_seance_valide():
    assert verifier(seance()) == 2


def test_minimum_obligatoire():
    s = {k: SEANCE[k] for k in ("format", "licence", "contributeur", "outil")}
    s["echantillons"] = [{"type": "expression", "attendu": "x", "traits": []}]
    assert verifier(s) == 1


@pytest.mark.parametrize(
    "champ,valeur",
    [
        ("auteur", "Antsa"),  # un prénom : jamais
        ("position", [-18.9, 47.5]),
        ("email", "a@b.c"),
        ("nom", "x"),
    ],
)
def test_champ_en_trop_refuse(champ, valeur):
    with pytest.raises(schema.DonInvalide, match="non permis"):
        verifier(seance(**{champ: valeur}))


def test_champ_en_trop_dans_appareil_et_echantillon():
    s = seance()
    s["appareil"]["numero_serie"] = "123"
    with pytest.raises(schema.DonInvalide, match="non permis"):
        verifier(s)
    s = seance()
    s["echantillons"][0]["lieu"] = "Antananarivo"
    with pytest.raises(schema.DonInvalide, match="non permis"):
        verifier(s)


@pytest.mark.parametrize(
    "changes,motif",
    [
        ({"licence": "CC-BY-4.0"}, "CC0"),
        ({"format": 2}, "format"),
        ({"format": True}, "format"),
        ({"format": 1.0}, "format"),
        ({"contributeur": "court"}, "contributeur"),
        ({"contributeur": "a/../../etc/passwd/xx"}, "contributeur"),
        ({"outil": "souris"}, "outil"),
        ({"version_app": "dernière"}, "version_app"),
        ({"debut": "hier"}, "debut"),
        ({"echantillons": []}, "echantillons"),
        ({"echantillons": "x"}, "echantillons"),
    ],
)
def test_seance_invalide(changes, motif):
    with pytest.raises(schema.DonInvalide, match=motif):
        verifier(seance(**changes))


def test_champ_obligatoire_manquant():
    s = seance()
    del s["licence"]
    with pytest.raises(schema.DonInvalide, match="manquant"):
        verifier(s)


def echantillon_modifie(i, **changes):
    s = seance()
    s["echantillons"][i].update(changes)
    return s


@pytest.mark.parametrize(
    "i,changes,motif",
    [
        (0, {"classe": "inconnu"}, "classe"),
        (0, {"attendu": "-"}, "correspond"),
        (1, {"classe": "plus"}, "réservé"),
        (0, {"type": "dessin"}, "type"),
        (0, {"rejete": "non"}, "booléen"),
        (0, {"case": [0, 0, 10]}, "case"),
        (0, {"case": [0, 0, 0, 10]}, "case"),
        (1, {"attendu": "x" * 513}, "trop long"),
        (1, {"attendu": "  "}, "vide"),
        (1, {"attendu": "a\nb"}, "contrôle"),
        (0, {"traits": [[[1, 2, 3]]]}, "point"),
        (0, {"traits": [[[1, 2, -1, 0.5]]]}, "bornes"),
        (0, {"traits": [[[1, 2, 3, 1.5]]]}, "bornes"),
        (0, {"traits": [[[1e9, 2, 3, 0.5]]]}, "bornes"),
        (0, {"traits": [[[True, 2, 3, 0.5]]]}, "nombre"),
        (0, {"traits": [[["1", 2, 3, 0.5]]]}, "nombre"),
        (0, {"traits": [[[0, 0, 0, 0]]] * 65}, "traits"),
        (0, {"traits": [[[0, 0, 0, 0]] * 4001]}, "points"),
    ],
)
def test_echantillon_invalide(i, changes, motif):
    with pytest.raises(schema.DonInvalide, match=motif):
        verifier(echantillon_modifie(i, **changes))


def test_trop_d_echantillons_et_de_points():
    e = SEANCE["echantillons"][1]
    with pytest.raises(schema.DonInvalide, match="500"):
        verifier(seance(echantillons=[e] * 501))
    gros = dict(e, traits=[[[0, 0, 0, 0]] * 4000] * 40)
    with pytest.raises(schema.DonInvalide, match="points"):
        verifier(seance(echantillons=[gros]))


@pytest.mark.parametrize(
    "octets,motif",
    [
        (b'{"a": NaN}', "non fini"),
        (b'{"a": Infinity}', "non fini"),
        (b'{"a": 1, "a": 2}', "répétée"),
        (b"\xff\xfe", "UTF-8"),
        (b"{", "illisible"),
        (b"[" * 100_000, "imbriqué|illisible"),
    ],
)
def test_json_strict(octets, motif):
    with pytest.raises(schema.DonInvalide, match=motif):
        schema.analyser_json(octets)
