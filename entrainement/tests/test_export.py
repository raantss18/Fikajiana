import numpy as np
import onnxruntime as ort
import torch

import rendu
from modele import Reseau, exporter_onnx


def test_export_onnx_memes_sorties(tmp_path):
    torch.manual_seed(0)
    modele = Reseau(109, rendu.K).eval()
    chemin = tmp_path / "signes.onnx"
    exporter_onnx(modele, rendu.K, chemin)
    assert chemin.stat().st_size < 2 * 1024 * 1024

    session = ort.InferenceSession(str(chemin), providers=["CPUExecutionProvider"])
    assert [e.name for e in session.get_inputs()] == ["image", "mesures"]
    assert [s.name for s in session.get_outputs()] == ["logits"]

    rng = np.random.default_rng(0)
    image = rng.random((3, 1, 32, 32), dtype=np.float32)
    mesures = rng.random((3, rendu.K), dtype=np.float32)
    (logits,) = session.run(None, {"image": image, "mesures": mesures})
    with torch.no_grad():
        attendu = modele(torch.from_numpy(image), torch.from_numpy(mesures)).numpy()
    assert logits.shape == (3, 109)
    np.testing.assert_allclose(logits, attendu, rtol=1e-4, atol=1e-4)
