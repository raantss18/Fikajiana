import pathlib

import donnees

ICI = pathlib.Path(__file__).resolve().parent


def ids():
    return {c[0] for c in donnees.lire_classes()}


def test_classes_stables():
    classes = donnees.lire_classes()
    assert classes[0][0] == "0" and classes[10][0] == "plus"
    assert len({c[0] for c in classes}) == len(classes)


def test_lecture_seance_exemple():
    signes, bilan = donnees.lire_seance(ICI / "exemple_seance.json", ids())
    assert [s.classe for s in signes] == ["plus"]
    assert bilan == {"rejetes": 1, "expressions": 1, "inconnus": 1, "vides": 0}
    plus = signes[0]
    assert len(plus.traits) == 2 and plus.traits[0][0] == (100, 150)
    assert plus.case == (50.0, 50.0, 200.0, 200.0)
    assert plus.groupe == "Exemple/exemple_seance.json" and plus.appareil == "essai"


def test_dossier_absent_sans_erreur(tmp_path):
    signes, bilan = donnees.lire_seances(tmp_path / "rien", ids())
    assert signes == [] and bilan["fichiers"] == 0


def test_fixtures_etiquetees():
    signes = donnees.lire_fixtures(ids())
    assert len(signes) > 100
    for s in signes:
        assert s.case[3] > 0
        haut = min(p[1] for t in s.traits for p in t)
        bas = max(p[1] for t in s.traits for p in t)
        assert s.case[1] <= haut and bas <= s.case[1] + s.case[3] + 1e-6
