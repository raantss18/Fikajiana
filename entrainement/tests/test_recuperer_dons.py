"""Récupération des dons : analyse du LaTeX, tri, retraits, et un aller-retour avec le récepteur."""

import copy
import json
import pathlib
import sys
import threading
import wsgiref.simple_server

import pytest

import recuperer_dons as rd

RACINE = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RACINE / "plateforme"))
import recepteur  # noqa: E402
import schema  # noqa: E402
import stockage  # noqa: E402

CLASSES = schema.lire_classes()
A = "aaaaaaaaaaaaaaaa"
B = "bbbbbbbbbbbbbbbb"


def plus(dx=0):
    return {
        "type": "signe", "classe": "plus", "attendu": "+",
        "traits": [[[100 + dx, 150, 0, 0.5], [200, 150, 80, 0.6]], [[150, 100, 300, 0.5], [150, 200, 380, 0.5]]],
        "case": [50, 50, 200, 200],
    }


def seance(contributeur, *echantillons):
    return {"format": 1, "licence": "CC0-1.0", "contributeur": contributeur, "outil": "stylet",
            "echantillons": list(echantillons)}


def don(contributeur, s, n=1):
    return {"type": "don", "cle": f"dons/{contributeur}/20261108T10000{n}000000Z-00000{n}.json",
            "recu": "2026-11-08T10:00:00+00:00", "contributeur": contributeur, "seance": s}


ENTETE = {"type": "export", "depuis": "1970-01-01T00:00:00+00:00", "jusqua": "2026-11-08T12:00:00+00:00"}


def expressions():
    lignes = (RACINE / "collecte" / "expressions.txt").read_text(encoding="utf-8").splitlines()
    return [l for l in lignes if l.strip() and not l.startswith("#")]


@pytest.mark.parametrize("latex", expressions() + [c for c in CLASSES.values() if c != "\\sqrt"])
def test_latex_du_projet_lisible(latex):
    assert rd.latex_valide(latex), latex


@pytest.mark.parametrize(
    "latex",
    ["\\frac{1}{", "}{", "x^", "\\frac{1}", "\\inconnu{x}", "a&b", "\\left(x", "x\\right)",
     "\\begin{pmatrix}1&2", "\\begin{foo}1\\end{foo}", "\\sqrt[3{8}", "x_{}^"],
)
def test_latex_illisible(latex):
    assert not rd.latex_valide(latex)


def test_motifs_de_rejet():
    assert rd.motif_de_rejet(plus()) is None
    assert rd.motif_de_rejet(dict(plus(), traits=[[], []])) == "traits vides"
    assert rd.motif_de_rejet(dict(plus(), traits=[[[1, 1, 0, 1]]] * 7)) == "signe impossible"
    assert rd.motif_de_rejet(dict(plus(), traits=[[[1, 1, 0, 1]]])) == "signe impossible"
    point = {"type": "signe", "classe": "point", "attendu": ".", "traits": [[[100, 100, 0, 1]]], "case": [50, 50, 200, 200]}
    assert rd.motif_de_rejet(point) is None
    loin = dict(plus(), traits=[[[5000, 5000, 0, 1], [5100, 5000, 10, 1]]])
    assert rd.motif_de_rejet(loin) == "signe impossible"
    geant = dict(plus(), traits=[[[0, 0, 0, 1], [0, 900, 10, 1]]])
    assert rd.motif_de_rejet(geant) == "signe impossible"
    expr = {"type": "expression", "attendu": "\\frac{1}{", "traits": [[[0, 0, 0, 1]]]}
    assert rd.motif_de_rejet(expr) == "LaTeX illisible"


def test_tri_doublons_retraits_et_format(tmp_path):
    dossier = tmp_path / "dons"
    etat = {}
    vide = dict(plus(), traits=[])
    mauvaise = seance(B, plus())
    mauvaise["auteur"] = "Antsa"
    lignes = [
        ENTETE,
        don(A, seance(A, plus(), plus(), vide, plus(dx=1)), 1),  # un doublon, un vide
        don(B, mauvaise, 2),
    ]
    r = rd.trier(lignes, dossier, etat, CLASSES)
    assert r["bilan"]["séances écrites"] == 1 and r["bilan"]["échantillons gardés"] == 2
    assert r["motifs"] == {"doublon exact": 1, "traits vides": 1}
    assert r["bilan"]["séances refusées (format)"] == 1
    fichiers = list((dossier / A).glob("*.json"))
    assert len(fichiers) == 1
    assert len(json.loads(fichiers[0].read_text())["echantillons"]) == 2
    assert etat["jusqua"] == ENTETE["jusqua"]

    # Second export : le même don est déjà là, un doublon d'un don précédent est écarté.
    r = rd.trier([ENTETE, don(A, seance(A, plus()), 1), don(A, seance(A, plus()), 3)], dossier, etat, CLASSES)
    assert r["bilan"]["séances déjà là"] == 1 and r["motifs"] == {"doublon exact": 1}

    # Retrait : le dossier local de A est effacé, et ses dons futurs ignorés.
    r = rd.trier([ENTETE, {"type": "retrait", "contributeur": A, "date": "x"}, don(A, seance(A, plus(dx=5)), 4)],
                 dossier, etat, CLASSES)
    assert not (dossier / A).exists()
    assert r["bilan"]["fichiers effacés (retraits)"] == 1 and r["bilan"]["séances ignorées (retirées)"] == 1
    assert etat["retraits"] == [A]
    # Le retrait reste appliqué même s'il n'est pas répété dans l'export suivant.
    (dossier / A).mkdir()
    (dossier / A / "vieux.json").write_text("{}")
    rd.trier([ENTETE], dossier, etat, CLASSES)
    assert not (dossier / A).exists()


def test_fichiers_lus_par_l_entrainement(tmp_path):
    import donnees

    rd.trier([ENTETE, don(A, seance(A, plus()), 1)], tmp_path / "ecriture" / "dons", {}, CLASSES)
    signes, bilan = donnees.lire_seances(tmp_path / "ecriture", set(CLASSES))
    assert [s.classe for s in signes] == ["plus"] and bilan["fichiers"] == 1


@pytest.fixture
def plateforme(tmp_path):
    jeton = "k" * 40
    app = recepteur.Recepteur(stockage.StockageDossier(tmp_path / "serveur"), jeton_admin=jeton, debit=100)

    class Silencieux(wsgiref.simple_server.WSGIRequestHandler):
        def log_message(self, *a):
            pass

    srv = wsgiref.simple_server.make_server("127.0.0.1", 0, app, handler_class=Silencieux)
    fil = threading.Thread(target=srv.serve_forever, daemon=True)
    fil.start()
    yield f"http://127.0.0.1:{srv.server_port}", jeton, app
    srv.shutdown()


def test_aller_retour_avec_le_recepteur(tmp_path, plateforme, monkeypatch):
    adresse, jeton, app = plateforme
    app.stockage.deposer(A, seance(A, plus()))
    app.stockage.deposer(B, seance(B, plus(dx=2)))
    monkeypatch.setenv("FIKA_DONS_ADRESSE", adresse)
    monkeypatch.setenv("FIKA_JETON_ADMIN", jeton)
    dossier, etat, rapport = tmp_path / "dons", tmp_path / "etat.json", tmp_path / "rapport.md"
    args = ["--dossier", str(dossier), "--etat", str(etat), "--rapport", str(rapport)]
    assert rd.main(args) == 0
    assert {p.name for p in dossier.iterdir()} == {A, B}
    assert "séances écrites | 2" in rapport.read_text()

    app.stockage.retirer(A)
    assert rd.main(args) == 0
    assert {p.name for p in dossier.iterdir()} == {B}
    assert json.loads(etat.read_text())["retraits"] == [A]

    monkeypatch.setenv("FIKA_JETON_ADMIN", "mauvais" * 6)
    with pytest.raises(Exception):
        rd.main(args)


def test_adresse_en_clair_refusee(monkeypatch):
    with pytest.raises(SystemExit, match="https"):
        list(rd.telecharger("http://dons.exemple.org", "x", None))


def test_signe_racine_garde():
    racine = {"type": "signe", "classe": "racine", "attendu": "\\sqrt",
              "traits": [[[100, 150, 0, 1], [120, 200, 10, 1], [150, 100, 20, 1], [250, 100, 30, 1]]],
              "case": [50, 50, 200, 200]}
    assert rd.motif_de_rejet(racine) is None


def test_export_par_pages(tmp_path, monkeypatch):
    """Le Worker répond par pages : `telecharger` suit les lignes « suite » jusqu'au bout."""
    pages = {
        None: [ENTETE, {"type": "retrait", "contributeur": B, "date": "x"}, don(A, seance(A, plus()), 1),
               {"type": "suite", "apres": "dons/a/1.json"}],
        "dons/a/1.json": [dict(ENTETE, jusqua="plus tard"), don(A, seance(A, plus(dx=3)), 2)],
    }
    vus = []

    class Reponse:
        def __init__(self, lignes):
            self.lignes = [(json.dumps(l) + "\n").encode() for l in lignes]

        def __enter__(self):
            return iter(self.lignes)

        def __exit__(self, *a):
            return False

    def ouvrir(requete, timeout):
        import urllib.parse as up

        q = up.parse_qs(up.urlparse(requete.full_url).query)
        vus.append(q)
        return Reponse(pages[q.get("apres", [None])[0]])

    monkeypatch.setattr(rd.urllib.request, "urlopen", ouvrir)
    lignes = list(rd.telecharger("https://dons.exemple", "j", "2026-01-01"))
    assert [l["type"] for l in lignes] == ["export", "retrait", "don", "export", "don"]
    assert all(q["depuis"] == ["2026-01-01"] for q in vus) and len(vus) == 2
    etat = {}
    r = rd.trier(lignes, tmp_path / "d", etat, CLASSES)
    assert r["bilan"]["séances écrites"] == 2 and etat["jusqua"] == ENTETE["jusqua"]
