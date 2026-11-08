"""Lecture des signes réels : séances de collecte (`collecte/FORMAT.md`) et fixtures de l'app."""

from __future__ import annotations

import json
import pathlib
import statistics
from dataclasses import dataclass, field

RACINE = pathlib.Path(__file__).resolve().parent.parent
CLASSES = RACINE / "collecte" / "classes.txt"
FIXTURES = RACINE / "app" / "test" / "fixtures"
FIXTURES_SIGNES = pathlib.Path(__file__).resolve().parent / "fixtures_signes.json"


@dataclass
class Signe:
    """Un signe isolé : ses traits (x, y), sa case de référence et son origine."""

    traits: list[list[tuple[float, float]]]
    case: tuple[float, float, float, float]
    classe: str
    source: str  # "seance", "fixture" ou "police"
    groupe: str  # séance (fichier) ou police : l'unité de séparation entraînement / test
    appareil: str = ""
    infos: dict = field(default_factory=dict)


def lire_classes(chemin: pathlib.Path = CLASSES) -> list[tuple[str, str, str]]:
    """(id, signe, LaTeX) dans l'ordre du fichier ; l'ordre fixe celui des sorties du modèle."""
    classes = []
    for ligne in chemin.read_text(encoding="utf-8").splitlines():
        if not ligne.strip() or ligne.startswith("#"):
            continue
        ident, signe, latex = ligne.split("\t")
        classes.append((ident, signe, latex))
    return classes


def lire_seance(chemin: pathlib.Path, ids: set[str]) -> tuple[list[Signe], dict]:
    """Les signes d'un fichier de séance. Ignore `rejete`, les expressions et les classes inconnues."""
    doc = json.loads(pathlib.Path(chemin).read_text(encoding="utf-8"))
    if doc.get("format") != 1:
        raise ValueError(f"{chemin} : format {doc.get('format')!r} inconnu (attendu 1)")
    bilan = {"rejetes": 0, "expressions": 0, "inconnus": 0, "vides": 0}
    appareil = (doc.get("appareil") or {}).get("modele", "")
    signes = []
    for e in doc.get("echantillons", []):
        if e.get("rejete"):
            bilan["rejetes"] += 1
            continue
        if e.get("type") != "signe":
            bilan["expressions"] += 1
            continue
        if e.get("classe") not in ids:
            bilan["inconnus"] += 1
            continue
        traits = [[(p[0], p[1]) for p in t] for t in e.get("traits", []) if t]
        if not traits:
            bilan["vides"] += 1
            continue
        signes.append(
            Signe(
                traits=traits,
                case=tuple(float(v) for v in e["case"]),
                classe=e["classe"],
                source="seance",
                groupe=f"{doc.get('auteur', '?')}/{pathlib.Path(chemin).name}",
                appareil=appareil,
                infos={"outil": doc.get("outil", ""), "id": e.get("id", "")},
            )
        )
    return signes, bilan


def lire_seances(dossier: pathlib.Path, ids: set[str]) -> tuple[list[Signe], dict]:
    """Tous les fichiers `*.json` sous `dossier` (un sous-dossier par personne)."""
    signes, bilan = [], {"fichiers": 0, "rejetes": 0, "expressions": 0, "inconnus": 0, "vides": 0}
    dossier = pathlib.Path(dossier)
    if not dossier.exists():
        return signes, bilan
    for f in sorted(dossier.rglob("*.json")):
        s, b = lire_seance(f, ids)
        signes += s
        bilan["fichiers"] += 1
        for k, v in b.items():
            bilan[k] += v
    return signes, bilan


def _hauteur(traits) -> tuple[float, float]:
    ys = [p[1] for t in traits for p in t]
    return min(ys), max(ys)


def lire_fixtures(ids: set[str]) -> list[Signe]:
    """Signes sûrs des fixtures réelles, d'après `fixtures_signes.json`.

    Case de référence d'un signe : la boîte des traits de sa ligne, c'est-à-dire des traits qui
    recouvrent verticalement le signe, sans ceux plus hauts que 2,5 fois la hauteur médiane des
    signes (grandes parenthèses de matrice). C'est la règle proposée à l'app (`CONTRAT.md`).
    """
    etiquettes = json.loads(FIXTURES_SIGNES.read_text(encoding="utf-8"))
    signes = []
    for nom, groupes in etiquettes.items():
        if nom.startswith("_"):
            continue
        brut = json.loads((FIXTURES / f"{nom}.json").read_text(encoding="utf-8"))
        tous = [[(p[0], p[1]) for p in t["points"]] for t in brut]
        mediane = statistics.median(
            max(1e-6, _hauteur([tous[i] for i in idx])[1] - _hauteur([tous[i] for i in idx])[0])
            for idx, _ in groupes
        )
        for idx, classe in groupes:
            if classe not in ids:
                raise ValueError(f"{nom} : classe {classe!r} absente de classes.txt")
            traits = [tous[i] for i in idx]
            haut, bas = _hauteur(traits)
            ligne = list(traits)
            for t in tous:
                th, tb = _hauteur([t])
                if tb - th <= 2.5 * mediane and tb >= haut and th <= bas:
                    ligne.append(t)
            lh, lb = _hauteur(ligne)
            xs = [p[0] for t in ligne for p in t]
            signes.append(
                Signe(
                    traits=traits,
                    case=(min(xs), lh, max(xs) - min(xs), max(lb - lh, 1e-6)),
                    classe=classe,
                    source="fixture",
                    groupe=nom,
                    appareil=nom.split("/")[0],
                )
            )
    return signes
