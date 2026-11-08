import hashlib

import numpy as np

import rendu

PLUS = [[(100, 150), (150, 151), (200, 150)], [(150, 100), (151, 150), (150, 200)]]
CASE = (50, 50, 200, 200)


def test_rendu_deterministe():
    a = rendu.rendre(PLUS, CASE)
    b = rendu.rendre(PLUS, CASE)
    assert a.shape == (32, 32) and a.dtype == np.float32
    assert np.array_equal(a, b)
    assert 0 <= a.min() and a.max() <= 1


def test_rendu_independant_de_l_echelle_et_de_la_position():
    loin = [[(x * 3 + 1000, y * 3 - 500) for x, y in t] for t in PLUS]
    case = (CASE[0] * 3 + 1000, CASE[1] * 3 - 500, CASE[2] * 3, CASE[3] * 3)
    ecart = np.abs(rendu.rendre(PLUS, CASE) - rendu.rendre(loin, case))
    # Seuls quelques sous-pixels du bord changent (arrondis de la toile 128×128).
    assert ecart.mean() < 0.01 and ecart.max() <= 0.25


def test_proportions_gardees():
    # Un trait horizontal reste horizontal : de l'encre seulement sur les lignes du milieu.
    moins = [[(0, 100), (100, 100)]]
    img = rendu.rendre(moins, (0, 0, 100, 100))
    lignes = np.nonzero(img.sum(1) > 0)[0]
    assert lignes.min() >= 13 and lignes.max() <= 18
    colonnes = np.nonzero(img.sum(0) > 0)[0]
    assert colonnes.min() <= 2 and colonnes.max() >= 29


def test_un_point_ne_remplit_pas_l_image():
    img = rendu.rendre([[(10, 10)]], (0, 0, 100, 100))
    assert 0 < (img > 0).sum() < 20


def test_mesures():
    m = rendu.mesurer(PLUS, CASE)
    assert m.shape == (rendu.K,)
    np.testing.assert_allclose(m, [0.0, 0.5, 0.5, 0.5, 0.5], atol=1e-6)


def test_empreinte_du_rendu():
    # Fige l'algorithme : changer le rendu change le contrat (nouvelle version de CONTRAT.md).
    img = rendu.rendre(PLUS, CASE)
    q = np.round(img * 255).astype(np.uint8).tobytes()
    assert hashlib.sha256(q).hexdigest()[:16] == EMPREINTE


EMPREINTE = "ea6bee5aeff4c806"
