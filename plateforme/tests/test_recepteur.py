import json

import pytest

import recepteur
import schema
import stockage
from conftest import CONTRIBUTEUR, JETON, appeler, seance


def lire_export(rendu):
    return [json.loads(l) for l in rendu["corps"].decode("utf-8").splitlines()]


def exporter(app, depuis=None, jeton=JETON):
    entetes = {"Authorization": f"Bearer {jeton}"} if jeton else {}
    return appeler(app, "GET", "/v1/export", entetes=entetes, requete=f"depuis={depuis}" if depuis else "")


def test_don_valide_stocke_en_fichier_horodate(app, dossier):
    r = appeler(app, "POST", "/v1/dons", seance())
    assert r["statut"] == 201 and json.loads(r["corps"]) == {"recu": 2}
    fichiers = list((dossier / "dons" / CONTRIBUTEUR).glob("*.json"))
    assert len(fichiers) == 1
    stockage.date_de_cle(fichiers[0].name)  # horodatage lisible
    assert json.loads(fichiers[0].read_text()) == seance()


def test_don_invalide_rien_stocke(app, dossier):
    r = appeler(app, "POST", "/v1/dons", seance(auteur="Antsa"))
    assert r["statut"] == 400
    assert "non permis" in json.loads(r["corps"])["erreur"]
    assert "Antsa" not in r["corps"].decode()
    assert not (dossier / "dons").exists()


def test_taille_limitee(app):
    gros = b'{"x":"' + b"a" * schema.TAILLE_MAX + b'"}'
    r = appeler(app, "POST", "/v1/dons", gros)
    assert r["statut"] == 413


def test_content_length_obligatoire_et_type(app):
    r = appeler(app, "POST", "/v1/dons", seance(), type_="text/plain")
    assert r["statut"] == 415
    r = appeler(app, "POST", "/v1/dons", seance(), entetes={"Content-Encoding": "gzip"})
    assert r["statut"] == 415


def test_methodes_et_routes(app):
    assert appeler(app, "GET", "/v1/dons")["statut"] == 405
    assert appeler(app, "GET", "/v1/rien")["statut"] == 404
    assert appeler(app, "GET", "/v1/sante")["statut"] == 200


def test_debit_par_ip_puis_oubli(app, horloge):
    for _ in range(5):
        assert appeler(app, "POST", "/v1/dons", seance())["statut"] == 201
    r = appeler(app, "POST", "/v1/dons", seance())
    assert r["statut"] == 429 and int(r["entetes"]["Retry-After"]) >= 1
    # Une autre IP n'est pas touchée.
    assert appeler(app, "POST", "/v1/dons", seance(), ip="198.51.100.1")["statut"] == 201
    # Après la fenêtre, l'IP repasse et aucune IP n'est plus gardée.
    horloge.t += 61
    assert app.limiteur.nombre_ip() == 0
    assert appeler(app, "POST", "/v1/dons", seance())["statut"] == 201


def test_ip_derriere_proxy(dossier, horloge):
    app = recepteur.Recepteur(stockage.StockageDossier(dossier), debit=1, derriere_proxy=True, horloge=horloge)
    ent = {"X-Forwarded-For": "1.1.1.1, 192.0.2.5"}
    assert appeler(app, "POST", "/v1/dons", seance(), ip="10.0.0.2", entetes=ent)["statut"] == 201
    # L'entrée de gauche est fournie par le client : elle ne change pas l'IP comptée.
    ent2 = {"X-Forwarded-For": "9.9.9.9, 192.0.2.5"}
    assert appeler(app, "POST", "/v1/dons", seance(), ip="10.0.0.2", entetes=ent2)["statut"] == 429
    ent3 = {"X-Forwarded-For": "192.0.2.6"}
    assert appeler(app, "POST", "/v1/dons", seance(), ip="10.0.0.2", entetes=ent3)["statut"] == 201


def test_retrait_efface_et_refuse_la_suite(app, dossier):
    appeler(app, "POST", "/v1/dons", seance())
    appeler(app, "POST", "/v1/dons", seance())
    autre = "zzzzzzzzzzzzzzzz"
    appeler(app, "POST", "/v1/dons", seance(contributeur=autre))
    r = appeler(app, "POST", "/v1/retrait", {"contributeur": CONTRIBUTEUR})
    assert r["statut"] == 202 and json.loads(r["corps"]) == {"retire": 2}
    assert not list((dossier / "dons" / CONTRIBUTEUR).glob("*.json"))
    assert len(list((dossier / "dons" / autre).glob("*.json"))) == 1
    assert (dossier / "retraits" / f"{CONTRIBUTEUR}.json").exists()
    assert appeler(app, "POST", "/v1/dons", seance())["statut"] == 410


@pytest.mark.parametrize("corps", [{"contributeur": "court"}, {"contributeur": CONTRIBUTEUR, "nom": "x"}, {}])
def test_retrait_invalide(app, corps):
    assert appeler(app, "POST", "/v1/retrait", corps)["statut"] == 400


def test_export_jeton_obligatoire(app):
    appeler(app, "POST", "/v1/dons", seance())
    assert exporter(app, jeton=None)["statut"] == 401
    assert exporter(app, jeton="x" * 40)["statut"] == 401
    r = exporter(app)
    assert r["statut"] == 200
    lignes = lire_export(r)
    assert lignes[0]["type"] == "export"
    dons = [l for l in lignes if l["type"] == "don"]
    assert len(dons) == 1 and dons[0]["seance"] == seance() and dons[0]["contributeur"] == CONTRIBUTEUR


def test_export_ferme_sans_jeton_configure(dossier):
    app = recepteur.Recepteur(stockage.StockageDossier(dossier))
    assert exporter(app)["statut"] == 404


def test_jeton_trop_court_refuse(dossier):
    with pytest.raises(ValueError):
        recepteur.Recepteur(stockage.StockageDossier(dossier), jeton_admin="court")


def test_export_depuis_et_retraits(app, dossier):
    st = app.stockage
    import datetime as dt

    vieux = dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc)
    st.deposer(CONTRIBUTEUR, seance(), quand=vieux)
    appeler(app, "POST", "/v1/dons", seance(contributeur="yyyyyyyyyyyyyyyy"))
    appeler(app, "POST", "/v1/retrait", {"contributeur": "wwwwwwwwwwwwwwww"})
    lignes = lire_export(exporter(app, depuis="2026-06-01T00:00:00Z"))
    dons = [l for l in lignes if l["type"] == "don"]
    assert [d["contributeur"] for d in dons] == ["yyyyyyyyyyyyyyyy"]
    assert [l["contributeur"] for l in lignes if l["type"] == "retrait"] == ["wwwwwwwwwwwwwwww"]
    assert len([l for l in lire_export(exporter(app)) if l["type"] == "don"]) == 2
    assert exporter(app, depuis="hier")["statut"] == 400


def test_journal_sans_contenu_ni_ip(app, caplog):
    caplog.set_level("INFO", logger="fikajiana.dons")
    appeler(app, "POST", "/v1/dons", seance(), ip="203.0.113.99")
    appeler(app, "POST", "/v1/dons", seance(auteur="Antsa"), ip="203.0.113.99")
    appeler(app, "GET", "/v1/Antsa", ip="203.0.113.99")
    texte = caplog.text
    assert "203.0.113" not in texte and "Antsa" not in texte and CONTRIBUTEUR not in texte
    assert "POST /v1/dons 201" in texte


class FauxS3:
    """Un client S3 en mémoire avec les quatre appels utilisés et une pagination à 2 objets."""

    def __init__(self):
        self.objets = {}

    def put_object(self, Bucket, Key, Body, ContentType):
        self.objets[Key] = Body

    def get_object(self, Bucket, Key):
        import io

        return {"Body": io.BytesIO(self.objets[Key])}

    def delete_object(self, Bucket, Key):
        self.objets.pop(Key, None)

    def list_objects_v2(self, Bucket, Prefix, MaxKeys=2, ContinuationToken=None):
        cles = sorted(k for k in self.objets if k.startswith(Prefix))
        debut = int(ContinuationToken or 0)
        page = cles[debut : debut + min(MaxKeys, 2)]
        suite = debut + len(page)
        return {"Contents": [{"Key": k} for k in page], "IsTruncated": suite < len(cles), "NextContinuationToken": str(suite)}


def test_stockage_s3(horloge):
    client = FauxS3()
    app = recepteur.Recepteur(stockage.StockageS3("seau", "fika", client=client), jeton_admin=JETON, horloge=horloge)
    for _ in range(3):
        assert appeler(app, "POST", "/v1/dons", seance())["statut"] == 201
    assert all(k.startswith("fika/dons/") for k in client.objets)
    assert len([l for l in lire_export(exporter(app)) if l["type"] == "don"]) == 3
    assert json.loads(appeler(app, "POST", "/v1/retrait", {"contributeur": CONTRIBUTEUR})["corps"]) == {"retire": 3}
    assert list(client.objets) == [f"fika/retraits/{CONTRIBUTEUR}.json"]
    assert appeler(app, "POST", "/v1/dons", seance())["statut"] == 410


def test_dossier_refuse_les_cles_hors_racine(dossier):
    st = stockage.StockageDossier(dossier)
    with pytest.raises(ValueError):
        st.ecrire("../evasion.json", b"{}")
