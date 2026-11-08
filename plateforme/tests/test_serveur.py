"""Le récepteur derrière le vrai serveur Waitress, par HTTP, sur un port local."""

import http.client
import json
import threading

import pytest
import waitress

import recepteur
import schema
import stockage
from conftest import seance


@pytest.fixture
def serveur(tmp_path):
    app = recepteur.Recepteur(stockage.StockageDossier(tmp_path), debit=100)
    srv = waitress.create_server(app, host="127.0.0.1", port=0, max_request_body_size=schema.TAILLE_MAX + 1024)
    fil = threading.Thread(target=srv.run, daemon=True)
    fil.start()
    yield srv.effective_port
    srv.task_dispatcher.shutdown()
    srv.close()


def envoyer(port, corps: bytes, entetes=None, chunked=False):
    c = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
    h = {"Content-Type": "application/json", **(entetes or {})}
    if chunked:
        c.request("POST", "/v1/dons", body=iter([corps[: len(corps) // 2], corps[len(corps) // 2 :]]), headers=h, encode_chunked=True)
    else:
        c.request("POST", "/v1/dons", body=corps, headers=h)
    r = c.getresponse()
    return r.status, r.read()


def test_don_par_http(serveur):
    statut, corps = envoyer(serveur, json.dumps(seance()).encode())
    assert statut == 201 and json.loads(corps) == {"recu": 2}


def test_don_en_morceaux(serveur):
    # Transfer-Encoding: chunked : Waitress rassemble le corps et fournit sa longueur.
    statut, _ = envoyer(serveur, json.dumps(seance()).encode(), chunked=True)
    assert statut == 201


def test_trop_gros_par_http(serveur):
    statut, _ = envoyer(serveur, b" " * (schema.TAILLE_MAX + 10))
    assert statut == 413
