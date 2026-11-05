# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = ["onnx", "onnxruntime", "matplotlib", "pillow", "numpy", "tokenizers"]
# ///
"""Télécharge Pix2Text-MFR, vérifie les empreintes, quantifie en int8 et compare les deux versions.

Usage : uv run models/preparer_pix2text.py
Les poids restent hors Git (voir models/pix2text-mfr.md).
"""

import hashlib
import json
import os
import pathlib
import time
import urllib.request

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import onnxruntime as ort
from onnxruntime.quantization import QuantType, quantize_dynamic
from PIL import Image
from tokenizers import Tokenizer

ICI = pathlib.Path(__file__).parent
DEPOT = "https://huggingface.co/breezedeus/pix2text-mfr/resolve"
REVISION = "bea257edb2653f2ae413b084f2ac0e8299d08df0"
POIDS = {
    "encoder_model.onnx": "bd8d5c322792e9ec45793af5569e9748f82a3d728a9e00213dbfc56c1486f37d",
    "decoder_model.onnx": "fd0f92d7a012f3dae41e1ac79421aea0ea888b5a66cb3f9a004e424f82f3daed",
}
AUTRES = ["config.json", "preprocessor_config.json", "tokenizer.json", "generation_config.json"]

# Formules imprimées, seulement pour comparer les deux versions : le manuscrit se mesure sur l'appareil.
ESSAIS = [r"\frac{a+b}{2}", r"x^{2}+y^{2}=1", r"\sqrt{2}", r"\int_{0}^{1}x\,dx", r"\sum_{k=1}^{n}k", r"\sin(x)"]


def empreinte(chemin):
    return hashlib.sha256(chemin.read_bytes()).hexdigest()


def telecharger(dossier):
    dossier.mkdir(parents=True, exist_ok=True)
    for nom in [*POIDS, *AUTRES]:
        cible = dossier / nom
        if not cible.exists():
            urllib.request.urlretrieve(f"{DEPOT}/{REVISION}/{nom}", cible)
    for nom, attendu in POIDS.items():
        if empreinte(dossier / nom) != attendu:
            raise SystemExit(f"Empreinte inattendue : {nom}")


def quantifier(dossier):
    for nom in POIDS:
        sortie = dossier / nom.replace(".onnx", "_int8.onnx")
        if not sortie.exists():
            # MatMul et Gemm seulement : les Conv quantifiées ne passent pas sur tous les fournisseurs CPU.
            quantize_dynamic(dossier / nom, sortie, weight_type=QuantType.QInt8, op_types_to_quantize=["MatMul", "Gemm"])


def image_de(latex, dossier):
    figure = plt.figure(figsize=(4, 1.2), dpi=100)
    figure.text(0.5, 0.5, f"${latex}$", ha="center", va="center", fontsize=22)
    chemin = dossier / "essai.png"
    figure.savefig(chemin)
    plt.close(figure)
    return Image.open(chemin).convert("RGB")


def lire(encodeur, decodeur, tokenizer, config, pretraitement, image):
    taille = pretraitement["size"]
    image = image.resize((taille["width"], taille["height"]), Image.BILINEAR)
    x = (np.asarray(image, dtype=np.float32) / 255.0 - pretraitement["image_mean"]) / pretraitement["image_std"]
    x = x.transpose(2, 0, 1)[None].astype(np.float32)
    debut = time.perf_counter()
    memoire = encodeur.run(None, {"pixel_values": x})[0]
    jetons = [config["decoder_start_token_id"]]
    for _ in range(128):
        logits = decodeur.run(None, {"input_ids": np.array([jetons], dtype=np.int64), "encoder_hidden_states": memoire})[0]
        suivant = int(logits[0, -1].argmax())
        if suivant == config["eos_token_id"]:
            break
        jetons.append(suivant)
    return tokenizer.decode(jetons, skip_special_tokens=True), time.perf_counter() - debut


def comparer(dossier):
    config = json.loads((dossier / "generation_config.json").read_text())
    pretraitement = json.loads((dossier / "preprocessor_config.json").read_text())
    tokenizer = Tokenizer.from_file(str(dossier / "tokenizer.json"))
    for nom, suffixe in (("flottant", ""), ("int8", "_int8")):
        fournisseurs = ["CPUExecutionProvider"]
        encodeur = ort.InferenceSession(dossier / f"encoder_model{suffixe}.onnx", providers=fournisseurs)
        decodeur = ort.InferenceSession(dossier / f"decoder_model{suffixe}.onnx", providers=fournisseurs)
        taille = sum(os.path.getsize(dossier / f"{m}_model{suffixe}.onnx") for m in ("encoder", "decoder")) / 1e6
        print(f"--- {nom} : {taille:.1f} Mo")
        for latex in ESSAIS:
            texte, duree = lire(encodeur, decodeur, tokenizer, config, pretraitement, image_de(latex, dossier))
            print(f"{duree * 1000:7.0f} ms | {latex} | {texte}")


if __name__ == "__main__":
    dossier = ICI / "pix2text-mfr"
    telecharger(dossier)
    quantifier(dossier)
    for nom in POIDS:
        for fichier in (nom, nom.replace(".onnx", "_int8.onnx")):
            chemin = dossier / fichier
            print(f"{fichier} {chemin.stat().st_size} {empreinte(chemin)}")
    comparer(dossier)
