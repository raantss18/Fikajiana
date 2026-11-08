import pathlib

import numpy as np
import pytest

import synthese

POLICES = pathlib.Path(__file__).resolve().parent.parent / "polices"


def test_squelette_d_une_croix_donne_deux_traits():
    masque = np.zeros((60, 60), bool)
    masque[28:33, 5:55] = True
    masque[5:55, 28:33] = True
    traits = synthese.squelette_en_traits(masque)
    assert len(traits) == 2


def test_squelette_d_un_anneau_donne_un_trait():
    yy, xx = np.mgrid[:60, :60]
    r = np.hypot(yy - 30, xx - 30)
    traits = synthese.squelette_en_traits((r > 18) & (r < 23))
    assert len(traits) == 1 and len(traits[0]) > 50


def test_deformation_reproductible():
    traits = [[(0.0, 0.0), (0.5, -1.0), (1.0, 0.0)]]
    a = synthese.deformer(traits, np.random.default_rng(1))
    b = synthese.deformer(traits, np.random.default_rng(1))
    assert a == b


@pytest.mark.skipif(not (POLICES / "caveat").exists(), reason="polices non téléchargées")
def test_glyphe_caveat():
    chemin = synthese.polices(POLICES)["caveat"]
    assert len(synthese.glyphe(chemin, "+")) == 2
    assert len(synthese.glyphe(chemin, "0")) == 1
