# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "torch>=2.4",
#   "numpy",
#   "pillow>=10.1",
#   "scikit-image",
#   "fonttools",
#   "onnx",
#   "onnxruntime",
# ]
# [[tool.uv.index]]
# name = "pytorch-cpu"
# url = "https://download.pytorch.org/whl/cpu"
# explicit = true
# [tool.uv.sources]
# torch = { index = "pytorch-cpu" }
# ///
"""Entraîne le modèle de signes de Fikajiana en une commande (ADR 0038).

Usage : uv run entrainement/entrainer.py [--donnees donnees/ecriture] [--epoques 15]
                                         [--sortie entrainement/sortie/]
Lit `entrainement/LISEZMOI.md` pour la marche à suivre et `CONTRAT.md` pour ce que l'app attend.
"""

from __future__ import annotations

import argparse
import collections
import datetime
import hashlib
import json
import multiprocessing
import os
import pathlib
import subprocess
import sys
import time

ICI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ICI))

import numpy as np  # noqa: E402
import torch  # noqa: E402
from torch import nn  # noqa: E402

import donnees  # noqa: E402
import rendu  # noqa: E402
import synthese  # noqa: E402
from modele import Reseau, exporter_onnx  # noqa: E402

GRAINE = 20261108
POLICE_TEST = "patrickhand"  # jamais vue à l'entraînement : mesure la généralisation à une main
PAR_CLASSE = 600  # signes synthétiques d'entraînement + validation par classe
PAR_CLASSE_TEST = 40
AUGMENTATIONS_REELLES = 15  # copies déformées de chaque signe réel d'entraînement


# ---------------------------------------------------------------- données

def _graine(*cles) -> int:
    return int.from_bytes(hashlib.sha256("/".join(map(str, cles)).encode()).digest()[:8], "little")


def _travail_police(args):
    """Rend `n` signes d'une classe avec une police ; renvoie images, mesures."""
    ident, signe, chemin, nom, n, force = args
    rng = np.random.default_rng(_graine(GRAINE, ident, nom, n))
    gabarits = [g for c in synthese.caracteres(ident, signe) if (g := synthese.glyphe(chemin, c))]
    if not gabarits:
        return ident, nom, None, None
    images, mesures = [], []
    for i in range(n):
        g = gabarits[i % len(gabarits)]
        traits = synthese.deformer(g, rng, force)
        case = synthese.case_synthetique(traits, rng)
        images.append(rendu.rendre(traits, case, epaisseur=float(rng.uniform(0.7, 1.4))))
        mesures.append(rendu.mesurer(traits, case))
    return ident, nom, np.stack(images), np.stack(mesures)


def _travail_reel(args):
    """Signe réel : l'original, puis `n` copies déformées (traits en unités de la case)."""
    traits, case, n, cle = args
    images = [rendu.rendre(traits, case)]
    mesures = [rendu.mesurer(traits, case)]
    rng = np.random.default_rng(_graine(GRAINE, cle))
    h = case[3]
    # Déformer dans le repère de la case (hauteur 1), puis revenir aux unités d'origine.
    norm = [[((x - case[0]) / h, (y - case[1]) / h) for x, y in t] for t in traits]
    for _ in range(n):
        d = synthese.deformer(norm, rng, 0.5)
        d = [[(x * h + case[0], y * h + case[1]) for x, y in t] for t in d]
        c = (case[0], case[1] + rng.normal(0, 0.05) * h, case[2], case[3] * float(np.exp(rng.normal(0, 0.15))))
        images.append(rendu.rendre(d, c, epaisseur=float(rng.uniform(0.8, 1.25))))
        mesures.append(rendu.mesurer(d, c))
    return np.stack(images), np.stack(mesures)


def repartir_groupes(groupes: list[str], part_test=0.25, part_val=0.15):
    """Séparation stricte par séance : une séance entière va dans un seul jeu."""
    ordre = sorted(set(groupes), key=lambda g: hashlib.sha256(f"{GRAINE}{g}".encode()).hexdigest())
    n = len(ordre)
    if n == 0:
        return {}
    if n == 1:
        return {ordre[0]: "test"}
    n_test = max(1, round(part_test * n))
    n_val = max(1, round(part_val * n)) if n >= 3 else 0
    return {g: ("test" if i < n_test else "val" if i < n_test + n_val else "entrainement") for i, g in enumerate(ordre)}


class Jeu:
    def __init__(self):
        self.images, self.mesures, self.etiquettes, self.sources, self.groupes = [], [], [], [], []

    def ajouter(self, images, mesures, etiquette, source, groupe):
        self.images.append(images)
        self.mesures.append(mesures)
        self.etiquettes += [etiquette] * len(images)
        self.sources += [source] * len(images)
        self.groupes += [groupe] * len(images)

    def figer(self):
        self.x = torch.from_numpy(np.concatenate(self.images)[:, None]) if self.images else torch.zeros(0, 1, 32, 32)
        self.m = torch.from_numpy(np.concatenate(self.mesures)) if self.mesures else torch.zeros(0, rendu.K)
        self.y = torch.tensor(self.etiquettes, dtype=torch.long)
        return self

    def __len__(self):
        return len(self.etiquettes)


def construire(args, classes, ids):
    index = {c[0]: i for i, c in enumerate(classes)}
    jeux = {n: Jeu() for n in ("entrainement", "val", "test_police", "test_reel")}
    bilan = {"couverture": {}, "polices": [], "seances": {}, "fixtures": 0}

    # 1. Polices.
    polices = synthese.polices(args.polices)
    if not polices:
        sys.exit(f"Aucune police dans {args.polices} : lancer d'abord bash entrainement/recuperer_polices.sh")
    bilan["polices"] = list(polices)
    travaux = []
    for ident, signe, _ in classes:
        dispo = [n for n, ch in polices.items() if any(synthese.couvre(ch, c) for c in synthese.caracteres(ident, signe))]
        bilan["couverture"][ident] = dispo
        entr = [n for n in dispo if n != POLICE_TEST]
        for nom in entr:
            travaux.append((ident, signe, polices[nom], nom, max(1, args.par_classe // len(entr)), 1.0))
        if POLICE_TEST in dispo:
            travaux.append((ident, signe, polices[POLICE_TEST], POLICE_TEST, PAR_CLASSE_TEST, 1.0))

    # 2. Signes réels : séances de collecte et fixtures.
    seances, bilan_seances = donnees.lire_seances(args.donnees, ids)
    bilan["seances"] = bilan_seances
    fixtures = donnees.lire_fixtures(ids)
    bilan["fixtures"] = len(fixtures)
    reels = seances + fixtures
    repartition = repartir_groupes([s.groupe for s in seances])
    repartition.update(repartir_groupes([s.groupe for s in fixtures]))
    bilan["repartition"] = repartition

    travaux_reels = []
    for i, s in enumerate(reels):
        jeu = repartition[s.groupe]
        n = AUGMENTATIONS_REELLES if jeu == "entrainement" else 0
        travaux_reels.append((s.traits, s.case, n, f"{s.groupe}#{i}"))

    with multiprocessing.get_context("fork").Pool(max(1, (os.cpu_count() or 2) - 1)) as pool:
        resultats = pool.map(_travail_police, travaux, chunksize=1)
        resultats_reels = pool.map(_travail_reel, travaux_reels, chunksize=4)

    rng = np.random.default_rng(GRAINE)
    for ident, nom, images, mesures in resultats:
        if images is None:
            continue
        if nom == POLICE_TEST:
            jeux["test_police"].ajouter(images, mesures, index[ident], "police", nom)
            continue
        val = rng.random(len(images)) < 0.1
        jeux["val"].ajouter(images[val], mesures[val], index[ident], "police", nom)
        jeux["entrainement"].ajouter(images[~val], mesures[~val], index[ident], "police", nom)
    for s, (images, mesures) in zip(reels, resultats_reels):
        jeu = repartition[s.groupe]
        cible = {"test": "test_reel", "val": "val", "entrainement": "entrainement"}[jeu]
        jeux[cible].ajouter(images, mesures, index[s.classe], s.source, s.groupe)
    bilan["reels"] = reels
    return {k: v.figer() for k, v in jeux.items()}, bilan


# ---------------------------------------------------------------- entraînement

def predire(modele, jeu, lot=1024):
    modele.eval()
    sorties = []
    with torch.no_grad():
        for i in range(0, len(jeu), lot):
            sorties.append(modele(jeu.x[i:i + lot], jeu.m[i:i + lot]))
    return torch.cat(sorties) if sorties else torch.zeros(0)


def justesse(modele, jeu):
    if len(jeu) == 0:
        return float("nan")
    return (predire(modele, jeu).argmax(1) == jeu.y).float().mean().item()


def entrainer(jeux, nb_classes, epoques, journal):
    torch.manual_seed(GRAINE)
    modele = Reseau(nb_classes, rendu.K)
    entr = jeux["entrainement"]
    lot = 256
    pas = epoques * ((len(entr) + lot - 1) // lot)
    opt = torch.optim.AdamW(modele.parameters(), lr=3e-3, weight_decay=1e-4)
    planning = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=3e-3, total_steps=pas)
    perte = nn.CrossEntropyLoss(label_smoothing=0.05)
    meilleur, etat = -1.0, None
    gen = torch.Generator().manual_seed(GRAINE)
    for e in range(epoques):
        modele.train()
        debut = time.time()
        ordre = torch.randperm(len(entr), generator=gen)
        total = 0.0
        for i in range(0, len(entr), lot):
            idx = ordre[i:i + lot]
            opt.zero_grad()
            p = perte(modele(entr.x[idx], entr.m[idx]), entr.y[idx])
            p.backward()
            opt.step()
            planning.step()
            total += p.item() * len(idx)
        j = justesse(modele, jeux["val"])
        journal(f"époque {e + 1}/{epoques} : perte {total / len(entr):.3f}, validation {j:.3f} ({time.time() - debut:.0f} s)")
        if j > meilleur:
            meilleur, etat = j, {k: v.clone() for k, v in modele.state_dict().items()}
    modele.load_state_dict(etat)
    return modele.eval(), meilleur


# ---------------------------------------------------------------- rapport

def evaluer(modele, jeu, classes):
    n = len(classes)
    matrice = np.zeros((n, n), np.int64)
    if len(jeu):
        pred = predire(modele, jeu).argmax(1).numpy()
        for v, p in zip(jeu.y.numpy(), pred):
            matrice[v, p] += 1
    return matrice


def _pct(a, b):
    return f"{100 * a / b:.1f} %" if b else "—"


def section_jeu(titre, matrice, classes, explication):
    ids = [c[0] for c in classes]
    signes = [c[1] for c in classes]
    total = matrice.sum()
    lignes = [f"## {titre}", "", explication, ""]
    if not total:
        lignes += ["Aucun échantillon.", ""]
        return lignes
    lignes += [f"**Justesse globale : {_pct(np.trace(matrice), total)}** sur {total} signes.", ""]
    confusions = [
        (matrice[v, p], v, p) for v in range(len(ids)) for p in range(len(ids)) if v != p and matrice[v, p]
    ]
    confusions.sort(reverse=True)
    lignes += ["Confusions principales (vrai → lu : nombre) :", ""]
    lignes += [f"- `{signes[v]}` ({ids[v]}) → `{signes[p]}` ({ids[p]}) : {c}" for c, v, p in confusions[:15]] or ["- aucune"]
    lignes += ["", "| Signe | id | n | Justesse |", "|---|---|---:|---:|"]
    for i, (ident, signe) in enumerate(zip(ids, signes)):
        n = matrice[i].sum()
        if n:
            lignes.append(f"| `{signe}` | {ident} | {n} | {_pct(matrice[i, i], n)} |")
    lignes.append("")
    return lignes


def temps_inference(chemin_onnx, jeu):
    import onnxruntime as ort

    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    session = ort.InferenceSession(str(chemin_onnx), options, providers=["CPUExecutionProvider"])
    n = min(len(jeu), 500)
    x, m = jeu.x[:n].numpy(), jeu.m[:n].numpy()
    for i in range(min(n, 20)):
        session.run(None, {"image": x[i:i + 1], "mesures": m[i:i + 1]})
    debut = time.perf_counter()
    for i in range(n):
        session.run(None, {"image": x[i:i + 1], "mesures": m[i:i + 1]})
    return (time.perf_counter() - debut) / max(n, 1) * 1000


def parts_sources(jeux):
    lignes = ["## Données : part de chaque source", "", "| Jeu | Source | Échantillons | Part du jeu |", "|---|---|---:|---:|"]
    for nom, jeu in jeux.items():
        compte = collections.Counter(jeu.sources)
        for source, n in sorted(compte.items()):
            lignes.append(f"| {nom} | {source} | {n} | {_pct(n, len(jeu))} |")
    lignes += [
        "",
        "Le jeu d'entraînement compte aussi les copies déformées des signes réels "
        f"({AUGMENTATIONS_REELLES} par signe, plus l'original).",
        "",
    ]
    return lignes


def ecrire_rapport(args, jeux, bilan, modele, classes, val, ms, taille, signature, duree):
    mat_police = evaluer(modele, jeux["test_police"], classes)
    mat_reel = evaluer(modele, jeux["test_reel"], classes)
    seances_test = sorted(g for g, j in bilan["repartition"].items() if j == "test")
    reels_test = [s for s in bilan["reels"] if bilan["repartition"][s.groupe] == "test"]
    nb_seances = bilan["seances"].get("fichiers", 0)
    lignes = [
        "# Rapport d'entraînement du modèle de signes",
        "",
        f"- Date : {datetime.datetime.now().astimezone().isoformat(timespec='seconds')} · commit `{signature}`",
        f"- Commande : `uv run entrainement/entrainer.py --donnees {args.donnees} --epoques {args.epoques}`",
        f"- Durée : {duree / 60:.1f} min sur CPU ({os.cpu_count()} cœurs)",
        f"- Modèle : `signes.onnx`, {taille / 1024:.0f} Kio, {sum(p.numel() for p in modele.parameters())} paramètres, {len(classes)} classes, K = {rendu.K} mesures",
        f"- Justesse de validation retenue : {100 * val:.1f} %",
        f"- **Temps d'inférence moyen : {ms:.2f} ms par signe** (onnxruntime, CPU de l'ordinateur, 1 fil, lot de 1) ;"
        " à mesurer sur le Pad 7 et le téléphone.",
        "",
    ]
    if nb_seances == 0:
        lignes += [
            "> **Aucune séance de collecte n'a été lue** (`" + str(args.donnees) + "` vide ou absent).",
            "> Le modèle n'a vu que des polices et les quelques signes relevés dans les fixtures.",
            "> **La justesse sur la main d'Antsa reste inconnue** : le test réel ci-dessous ne porte que",
            f"> sur {len(reels_test)} signes de {len(seances_test)} lignes de fixtures, trop peu pour conclure.",
            "",
        ]
    lignes += parts_sources(jeux)
    lignes += section_jeu(
        "Test réel (séances jamais vues)",
        mat_reel,
        classes,
        "Séances entières mises de côté avant l'entraînement : " + (", ".join(f"`{g}`" for g in seances_test) or "aucune") + ".",
    )
    par_appareil = collections.defaultdict(lambda: [0, 0])
    if len(jeux["test_reel"]):
        pred = predire(modele, jeux["test_reel"]).argmax(1).numpy()
        for s, p in zip(reels_test, pred):
            par_appareil[s.appareil][0] += int(p == s.classe_index)
            par_appareil[s.appareil][1] += 1
        lignes += ["Par appareil :", ""] + [f"- {a or '?'} : {_pct(b, n)} ({n} signes)" for a, (b, n) in sorted(par_appareil.items())] + [""]
    lignes += section_jeu(
        f"Test police inconnue ({POLICE_TEST})",
        mat_police,
        classes,
        f"Signes synthétiques d'une police jamais vue à l'entraînement ({PAR_CLASSE_TEST} par classe couverte) :"
        " mesure la généralisation à une autre main, pas la justesse sur une vraie écriture.",
    )
    sans = [c[0] for c in classes if not bilan["couverture"][c[0]]]
    lignes += [
        "## Couverture des polices",
        "",
        "Polices : " + ", ".join(bilan["polices"]) + " (licences et sources : `entrainement/SOURCES.md`).",
        "",
        "| Classe | Polices |",
        "|---|---|",
    ]
    lignes += [f"| {c[0]} | {len(bilan['couverture'][c[0]])} |" for c in classes if len(bilan["couverture"][c[0]]) < len(bilan["polices"])]
    lignes += ["", f"Classes sans aucune police : {', '.join(sans) or 'aucune'}.", ""]
    lignes += [
        "## Données laissées de côté",
        "",
        f"- Séances : {json.dumps(bilan['seances'], ensure_ascii=False)}",
        "- MNIST et HASYv2 : non utilisés (licence non confirmée compatible avec des poids GPL, voir `SOURCES.md`).",
        "",
        "Matrice de confusion complète : `confusions_reel.csv` et `confusions_police.csv`.",
        "",
    ]
    (args.sortie / "rapport.md").write_text("\n".join(lignes), encoding="utf-8")
    for nom, mat in (("reel", mat_reel), ("police", mat_police)):
        entete = "vrai\\lu," + ",".join(c[0] for c in classes)
        corps = [c[0] + "," + ",".join(map(str, ligne)) for c, ligne in zip(classes, mat)]
        (args.sortie / f"confusions_{nom}.csv").write_text("\n".join([entete] + corps) + "\n", encoding="utf-8")
    return mat_reel, mat_police


def ecrire_contrat_json(args, classes, taille, sha, val, signature):
    contrat = {
        "version": 1,
        "modele": "signes.onnx",
        "sha256": sha,
        "taille_octets": taille,
        "commit": signature,
        "classes": "signes_classes.txt",
        "nb_classes": len(classes),
        "entrees": {
            "image": {"type": "float32", "forme": ["N", 1, rendu.TAILLE, rendu.TAILLE]},
            "mesures": {"type": "float32", "forme": ["N", rendu.K]},
        },
        "sortie": {"logits": {"type": "float32", "forme": ["N", len(classes)], "note": "softmax pour des probabilités"}},
        "image": {
            "taille": rendu.TAILLE,
            "sur_echantillonnage": rendu.SUR,
            "marge_px": rendu.MARGE_PX,
            "epaisseur_px": rendu.EPAISSEUR_PX,
            "cote_minimal_relatif": rendu.COTE_MINIMAL,
            "chemin": "cheminDuTrait (quadratiques par les milieux)",
            "anticrenelage": "toile 128×128 sans anticrénelage, puis moyenne des blocs 4×4",
            "valeurs": "0 = fond, 1 = encre",
            "normalisation": "aucune",
        },
        "mesures": {
            "K": rendu.K,
            "ordre": list(rendu.MESURES),
            "formules": {
                "rapport": "clamp(ln((w + 0.02 H) / (h + 0.02 H)), -3, 3)",
                "traits": "min(nombre de traits, 4) / 4",
                "hauteur": "clamp(h / H, 0, 2)",
                "largeur": "clamp(w / H, 0, 3)",
                "centre": "clamp(((y0 + y1) / 2 - top) / H, -0.5, 1.5)",
            },
            "case": "boîte de la ligne d'écriture du signe (top, H = hauteur) ; voir CONTRAT.md",
        },
        "justesse_validation": round(val, 4),
    }
    (args.sortie / "signes.json").write_text(json.dumps(contrat, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def principal(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--donnees", type=pathlib.Path, default=pathlib.Path("donnees/ecriture"))
    p.add_argument("--epoques", type=int, default=15)
    p.add_argument("--sortie", type=pathlib.Path, default=ICI / "sortie")
    p.add_argument("--polices", type=pathlib.Path, default=ICI / "polices")
    p.add_argument("--par-classe", type=int, default=PAR_CLASSE, help="signes synthétiques par classe")
    args = p.parse_args(argv)
    args.sortie.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(max(1, min(8, os.cpu_count() or 1)))
    debut = time.time()

    def journal(texte):
        print(f"[{time.time() - debut:6.0f} s] {texte}", flush=True)

    if not any(args.polices.glob("*/*.ttf")):
        journal("polices absentes : téléchargement")
        subprocess.run(["bash", str(ICI / "recuperer_polices.sh")], check=True)

    classes = donnees.lire_classes()
    ids = {c[0] for c in classes}
    index = {c[0]: i for i, c in enumerate(classes)}
    journal(f"{len(classes)} classes ; préparation des données")
    jeux, bilan = construire(args, classes, ids)
    for s in bilan["reels"]:
        s.classe_index = index[s.classe]
    journal(", ".join(f"{k} : {len(v)}" for k, v in jeux.items()))

    modele, val = entrainer(jeux, len(classes), args.epoques, journal)

    chemin = args.sortie / "signes.onnx"
    exporter_onnx(modele, rendu.K, chemin)
    taille = chemin.stat().st_size
    if taille > 2 * 1024 * 1024:
        sys.exit(f"signes.onnx fait {taille} octets, au-delà de 2 Mio : réduire le réseau")
    sha = hashlib.sha256(chemin.read_bytes()).hexdigest()
    (args.sortie / "signes_classes.txt").write_text("\n".join(c[0] for c in classes) + "\n", encoding="utf-8")
    try:
        signature = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, cwd=ICI).stdout.strip()
    except OSError:
        signature = "?"
    ecrire_contrat_json(args, classes, taille, sha, val, signature)
    ms = temps_inference(chemin, jeux["val"])
    ecrire_rapport(args, jeux, bilan, modele, classes, val, ms, taille, signature, time.time() - debut)
    journal(f"fini : {chemin} ({taille / 1024:.0f} Kio), rapport : {args.sortie / 'rapport.md'}")


if __name__ == "__main__":
    principal()
