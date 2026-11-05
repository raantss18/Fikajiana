# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = ["onnxruntime", "pillow", "numpy", "tokenizers"]
# ///
"""Rejoue l'encre du spike T1 avec plusieurs réglages, sur l'ordinateur.

Usage : uv run --python 3.12 models/rejouer_encre.py <resultats.jsonl> <dossier du modèle> ...
Les traits restent hors Git. Le score compare le sens du LaTeX, pas son orthographe.
"""

import json
import pathlib
import re
import statistics
import sys
import time

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageDraw
from tokenizers import Tokenizer

TAILLE = 384


def sens(latex):
    """Forme de comparaison : retire ce qui ne change pas le sens."""
    s = re.sub(r"(?<!\\)\\[,;:! ]", "", latex)
    s = s.replace(r"\left\{", "{CAS}").replace(r"\right.", "")
    s = re.sub(r"\\(left|right|Big|big|mathbf|bf|mathrm|limits)(?![a-zA-Z])", "", s)
    s = s.replace(r"\dfrac", r"\frac").replace(r"\rightarrow", r"\to")
    s = s.replace(r"\begin{cases}", "{CAS}\\begin{matrix}").replace(r"\end{cases}", "\\end{matrix}")
    s = re.sub(r"\s+", "", s)
    s = s.replace(r"(\begin{matrix}", r"\begin{pmatrix}").replace(r"\end{matrix})", r"\end{pmatrix}")
    s = s.replace(r"\\\end", r"\end")
    # { x } autour d'un seul signe : sans effet, sauf après \frac et \sqrt où la forme reste la même des deux côtés.
    avant = None
    while avant != s:
        avant = s
        s = re.sub(r"\{(\\?[A-Za-z0-9]+)\}", r"\1", s)
    return s


def dessiner(traits, epaisseur, carre):
    """epaisseur : part de la hauteur du cadre. carre : complète en blanc au lieu de déformer."""
    points = [p for t in traits for p in t]
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    g, d, h, b = min(xs), max(xs), min(ys), max(ys)
    haut = max(b - h, 48.0)
    marge = haut * 0.12
    largeur, hauteur = d - g + 2 * marge, haut + 2 * marge
    if carre:
        cote = max(largeur, hauteur)
        ox, oy = (cote - largeur) / 2, (cote - hauteur) / 2
        largeur = hauteur = cote
    else:
        ox = oy = 0.0
    echelle = 1536 / max(largeur, hauteur)
    w, h_img = max(1, round(largeur * echelle)), max(1, round(hauteur * echelle))
    image = Image.new("L", (w, h_img), 255)
    dessin = ImageDraw.Draw(image)
    e = max(1, round(epaisseur * haut * echelle))
    for t in traits:
        c = [((p[0] - g + marge + ox) * echelle, (p[1] - h + marge + oy + (haut - (b - h)) / 2) * echelle) for p in t]
        if len(c) > 1:
            dessin.line(c, fill=0, width=e, joint="curve")
        for x, y in (c[0], c[-1]):
            dessin.ellipse((x - e / 2, y - e / 2, x + e / 2, y + e / 2), fill=0)
    image = image.resize((TAILLE, TAILLE), Image.BICUBIC).convert("RGB")
    x = (np.asarray(image, dtype=np.float32) / 255 - 0.5) / 0.5
    return x.transpose(2, 0, 1)[None].astype(np.float32)


class Modele:
    def __init__(self, dossier, suffixe):
        dossier = pathlib.Path(dossier)
        options = ort.SessionOptions()
        self.enc = ort.InferenceSession(dossier / f"encoder_model{suffixe}.onnx", options, ["CPUExecutionProvider"])
        self.dec = ort.InferenceSession(dossier / f"decoder_model{suffixe}.onnx", options, ["CPUExecutionProvider"])
        self.tok = Tokenizer.from_file(str(dossier / "tokenizer.json"))
        self.debut = json.loads((dossier / "generation_config.json").read_text())["decoder_start_token_id"]

    def lire(self, x):
        memoire = self.enc.run(None, {"pixel_values": x})[0]
        jetons = [self.debut]
        for _ in range(200):
            logits = self.dec.run(None, {"input_ids": np.array([jetons], dtype=np.int64), "encoder_hidden_states": memoire})[0]
            suivant = int(logits[0, -1].argmax())
            if suivant == 2:
                break
            jetons.append(suivant)
        return self.tok.decode(jetons, skip_special_tokens=True)


def main():
    reponses = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8")]
    print("sur l'appareil :", sum(sens(r["lu"]) == sens(r["cible"]) for r in reponses), "/", len(reponses))
    for r in reponses:
        if r["juste"] != (sens(r["lu"]) == sens(r["cible"])):
            print("  écart avec le jugement :", r["indice"], "juste" if r["juste"] else "faux", "|", r["cible"], "|", r["lu"])
    for dossier in sys.argv[2:]:
        for suffixe in ("_int8", ""):
            if not (pathlib.Path(dossier) / f"encoder_model{suffixe}.onnx").exists():
                continue
            modele = Modele(dossier, suffixe)
            for carre in (False,):
                for epaisseur in (1 / 22, 1 / 70, 1 / 100):
                    debut = time.perf_counter()
                    bons, familles = 0, {}
                    for r in reponses:
                        juste = sens(modele.lire(dessiner(r["traits"], epaisseur, carre))) == sens(r["cible"])
                        bons += juste
                        familles[r["famille"]] = familles.get(r["famille"], 0) + juste
                    print(
                        f"{pathlib.Path(dossier).name}{suffixe} carre={carre} trait=1/{round(1 / epaisseur)} : "
                        f"{bons}/{len(reponses)} {familles} ({time.perf_counter() - debut:.0f} s)",
                        flush=True,
                    )


if __name__ == "__main__":
    main()
