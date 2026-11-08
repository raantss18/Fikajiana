import copy
import io
import json
import pathlib
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))

import recepteur  # noqa: E402
import stockage  # noqa: E402

JETON = "j" * 40
CONTRIBUTEUR = "abcdefghijklmnop_1234"

SEANCE = {
    "format": 1,
    "licence": "CC0-1.0",
    "contributeur": CONTRIBUTEUR,
    "version_app": "1.0.5",
    "appareil": {"modele": "2410CRP4CG", "largeur_dp": 1164, "hauteur_dp": 777, "densite": 2.75},
    "outil": "stylet",
    "debut": "2026-11-08T09:30:00+03:00",
    "echantillons": [
        {
            "id": "e1",
            "type": "signe",
            "classe": "plus",
            "attendu": "+",
            "traits": [[[100, 150, 0, 0.5], [200, 150, 80, 0.6]], [[150, 100, 300, 0.5], [150, 200, 380, 0.5]]],
            "case": [50, 50, 200, 200],
            "rejete": False,
        },
        {
            "id": "e2",
            "type": "expression",
            "attendu": "\\frac{1}{x+2}",
            "traits": [[[10, 10, 0, 1], [20, 30, 15, 1]]],
            "case": [0, 0, 300, 100],
        },
    ],
}


def seance(**changes):
    s = copy.deepcopy(SEANCE)
    s.update(changes)
    return s


class Horloge:
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t


@pytest.fixture
def horloge():
    return Horloge()


@pytest.fixture
def dossier(tmp_path):
    return tmp_path / "dons"


@pytest.fixture
def app(dossier, horloge):
    return recepteur.Recepteur(stockage.StockageDossier(dossier), jeton_admin=JETON, debit=5, fenetre=60, horloge=horloge)


def appeler(app, methode, chemin, corps=None, ip="203.0.113.7", entetes=None, type_="application/json", requete=""):
    if corps is not None and not isinstance(corps, bytes):
        corps = json.dumps(corps).encode("utf-8")
    environ = {
        "REQUEST_METHOD": methode,
        "PATH_INFO": chemin,
        "QUERY_STRING": requete,
        "REMOTE_ADDR": ip,
        "wsgi.input": io.BytesIO(corps or b""),
    }
    if corps is not None:
        environ["CONTENT_TYPE"] = type_
        environ["CONTENT_LENGTH"] = str(len(corps))
    for k, v in (entetes or {}).items():
        environ["HTTP_" + k.upper().replace("-", "_")] = v
    rendu = {}

    def start_response(statut, hs):
        rendu["statut"] = int(statut[:3])
        rendu["entetes"] = dict(hs)

    rendu["corps"] = b"".join(app(environ, start_response))
    return rendu
