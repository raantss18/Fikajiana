# Pix2Text-MFR

- **Source** : https://huggingface.co/breezedeus/pix2text-mfr, révision `bea257edb2653f2ae413b084f2ac0e8299d08df0`. Licence MIT.
- **Provenance des poids** : non publiée (`docs/recherche/reverification.md`) ; pas de diffusion publique pour l'instant.
- **Préparation** : `uv run --python 3.12 models/preparer_pix2text.py` ; fichiers hors Git, dans `models/pix2text-mfr/`.

| Fichier | Octets | SHA-256 |
|---|---|---|
| `encoder_model.onnx` | 87 496 990 | `bd8d5c322792e9ec45793af5569e9748f82a3d728a9e00213dbfc56c1486f37d` |
| `decoder_model.onnx` | 30 114 937 | `fd0f92d7a012f3dae41e1ac79421aea0ea888b5a66cb3f9a004e424f82f3daed` |
| `encoder_model_int8.onnx` | 23 966 185 | `2d04bcc0e70ca960f2c326c37d56a1696a229d81549bb4ff8077a5d817677f23` |
| `decoder_model_int8.onnx` | 9 305 287 | `f5b463fc8e6cd10367f6ce2f53a09b9e3608e7fb56749292a8504f77c7941887` |

Quantification dynamique de MatMul et Gemm : 117,6 → 33,3 Mo. Sur 6 formules imprimées, sur l'ordinateur, le flottant et l'int8
donnent le même texte, y compris la même erreur (`K` au lieu de `k`). Le manuscrit reste à mesurer sur l'appareil.
