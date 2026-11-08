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


def lancer(app):
    srv = waitress.create_server(app, host="127.0.0.1", port=0, **recepteur.options_waitress(app))
    threading.Thread(target=srv.run, daemon=True).start()
    return srv


@pytest.fixture
def serveur(tmp_path):
    srv = lancer(recepteur.Recepteur(stockage.StockageDossier(tmp_path), debit=100))
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


def test_debit_par_client_derriere_proxy(tmp_path):
    # Erreur trouvée le 2026-11-08 : Waitress effaçait X-Forwarded-For, tous les clients partageaient un compteur.
    srv = lancer(recepteur.Recepteur(stockage.StockageDossier(tmp_path), debit=1, derriere_proxy=1))
    try:
        corps = json.dumps(seance()).encode()
        assert envoyer(srv.effective_port, corps, {"X-Forwarded-For": "192.0.2.1"})[0] == 201
        assert envoyer(srv.effective_port, corps, {"X-Forwarded-For": "192.0.2.1"})[0] == 429
        assert envoyer(srv.effective_port, corps, {"X-Forwarded-For": "192.0.2.2"})[0] == 201
    finally:
        srv.task_dispatcher.shutdown()
        srv.close()


def test_sans_proxy_l_en_tete_est_ignore(tmp_path):
    srv = lancer(recepteur.Recepteur(stockage.StockageDossier(tmp_path), debit=1))
    try:
        corps = json.dumps(seance()).encode()
        assert envoyer(srv.effective_port, corps, {"X-Forwarded-For": "192.0.2.1"})[0] == 201
        assert envoyer(srv.effective_port, corps, {"X-Forwarded-For": "192.0.2.2"})[0] == 429
    finally:
        srv.task_dispatcher.shutdown()
        srv.close()
