"""Vérification d'un don : une séance au format `collecte/FORMAT.md`, réduite à ce que l'ADR 0042 autorise.

Bibliothèque standard seulement : ce module sert au récepteur (`recepteur.py`) et à la récupération
(`entrainement/recuperer_dons.py`). Tout champ non listé ici est refusé, pour qu'aucune donnée
personnelle (prénom, position, compte…) ne puisse passer, même par erreur.
"""

from __future__ import annotations

import json
import math
import pathlib
import re

RACINE = pathlib.Path(__file__).resolve().parent.parent
CLASSES = RACINE / "collecte" / "classes.txt"

TAILLE_MAX = 2 * 1024 * 1024  # octets, corps de `POST /v1/dons`
ECHANTILLONS_MAX = 500
TRAITS_MAX = 64  # par échantillon (une ligne d'expression)
POINTS_MAX = 4000  # par trait
POINTS_TOTAL_MAX = 150_000  # par séance
LATEX_MAX = 512  # caractères
COORD_MAX = 100_000.0  # dp, en valeur absolue
TEMPS_MAX = 3_600_000.0  # ms depuis le premier point de l'échantillon

RE_CONTRIBUTEUR = re.compile(r"[A-Za-z0-9_-]{16,64}")
RE_ID = re.compile(r"[A-Za-z0-9_-]{1,64}")
RE_VERSION = re.compile(r"[0-9]{1,4}(\.[0-9]{1,4}){1,3}([+-][0-9A-Za-z.]{1,32})?")
RE_MODELE = re.compile(r"[A-Za-z0-9 ._+()-]{1,64}")
RE_DEBUT = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-][0-9]{2}:[0-9]{2})")

CHAMPS_SEANCE = {"format", "licence", "contributeur", "version_app", "appareil", "outil", "debut", "echantillons"}
OBLIGATOIRES_SEANCE = {"format", "licence", "contributeur", "outil", "echantillons"}
CHAMPS_APPAREIL = {"modele", "largeur_dp", "hauteur_dp", "densite"}
CHAMPS_ECHANTILLON = {"id", "type", "classe", "attendu", "traits", "case", "rejete"}
OBLIGATOIRES_ECHANTILLON = {"type", "attendu", "traits"}


class DonInvalide(ValueError):
    """Le don ne respecte pas le format ; le message dit pourquoi, sans recopier le contenu."""


def lire_classes(chemin: pathlib.Path = CLASSES) -> dict[str, str]:
    """{id: LaTeX} des signes connus (`collecte/classes.txt`)."""
    classes = {}
    for ligne in chemin.read_text(encoding="utf-8").splitlines():
        if not ligne.strip() or ligne.startswith("#"):
            continue
        ident, _signe, latex = ligne.split("\t")
        classes[ident] = latex
    return classes


def _sans_doublon(paires):
    objet = {}
    for cle, valeur in paires:
        if cle in objet:
            raise DonInvalide(f"clé répétée : {cle[:40]!r}")
        objet[cle] = valeur
    return objet


def _constante(nom):
    raise DonInvalide(f"nombre non fini : {nom}")


def analyser_json(octets: bytes):
    """JSON strict : UTF-8, pas de NaN/Infinity, pas de clé répétée, profondeur raisonnable."""
    try:
        texte = octets.decode("utf-8")
    except UnicodeDecodeError as e:
        raise DonInvalide("le corps n'est pas de l'UTF-8") from e
    try:
        return json.loads(texte, object_pairs_hook=_sans_doublon, parse_constant=_constante)
    except DonInvalide:
        raise
    except RecursionError as e:
        raise DonInvalide("JSON trop imbriqué") from e
    except ValueError as e:
        raise DonInvalide("JSON illisible") from e


def _nombre(v, chemin: str, mini: float, maxi: float) -> float:
    # bool est un int en Python : on l'écarte explicitement.
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v):
        raise DonInvalide(f"{chemin} : nombre attendu")
    if not mini <= v <= maxi:
        raise DonInvalide(f"{chemin} : hors bornes [{mini}, {maxi}]")
    return float(v)


def _texte(v, chemin: str, motif: re.Pattern | None = None, maxi: int = 64) -> str:
    if not isinstance(v, str):
        raise DonInvalide(f"{chemin} : texte attendu")
    if len(v) > maxi:
        raise DonInvalide(f"{chemin} : texte trop long (> {maxi})")
    if motif is not None and not motif.fullmatch(v):
        raise DonInvalide(f"{chemin} : forme non permise")
    return v


def _champs(objet, chemin: str, permis: set[str], obligatoires: set[str]) -> None:
    if not isinstance(objet, dict):
        raise DonInvalide(f"{chemin} : objet attendu")
    en_trop = sorted(set(objet) - permis)
    if en_trop:
        # Le nom du champ est tronqué : il ne doit pas servir à faire passer du contenu dans le journal.
        raise DonInvalide(f"{chemin} : champ non permis {en_trop[0][:32]!r}")
    manquants = sorted(obligatoires - set(objet))
    if manquants:
        raise DonInvalide(f"{chemin} : champ manquant {manquants[0]!r}")


def _latex(v, chemin: str) -> str:
    v = _texte(v, chemin, maxi=LATEX_MAX)
    if not v.strip():
        raise DonInvalide(f"{chemin} : LaTeX vide")
    if any(ord(c) < 0x20 or 0x7F <= ord(c) < 0xA0 for c in v):
        raise DonInvalide(f"{chemin} : caractère de contrôle")
    return v


def verifier_seance(doc, classes: dict[str, str]) -> int:
    """Vérifie une séance ; rend le nombre d'échantillons. Lève `DonInvalide` sinon."""
    _champs(doc, "séance", CHAMPS_SEANCE, OBLIGATOIRES_SEANCE)
    if type(doc["format"]) is not int or doc["format"] != 1:
        raise DonInvalide("format : 1 attendu")
    if doc["licence"] != "CC0-1.0":
        raise DonInvalide("licence : CC0-1.0 obligatoire")
    _texte(doc["contributeur"], "contributeur", RE_CONTRIBUTEUR)
    if doc["outil"] not in ("stylet", "doigt"):
        raise DonInvalide("outil : stylet ou doigt")
    if "version_app" in doc:
        _texte(doc["version_app"], "version_app", RE_VERSION)
    if "debut" in doc:
        _texte(doc["debut"], "debut", RE_DEBUT, maxi=40)
    if "appareil" in doc:
        app = doc["appareil"]
        _champs(app, "appareil", CHAMPS_APPAREIL, set())
        if "modele" in app:
            _texte(app["modele"], "appareil.modele", RE_MODELE)
        for cle in ("largeur_dp", "hauteur_dp"):
            if cle in app:
                _nombre(app[cle], f"appareil.{cle}", 1, 20_000)
        if "densite" in app:
            _nombre(app["densite"], "appareil.densite", 0.1, 10)

    echantillons = doc["echantillons"]
    if not isinstance(echantillons, list) or not echantillons:
        raise DonInvalide("echantillons : liste non vide attendue")
    if len(echantillons) > ECHANTILLONS_MAX:
        raise DonInvalide(f"echantillons : plus de {ECHANTILLONS_MAX}")
    total = 0
    for i, e in enumerate(echantillons):
        c = f"echantillons[{i}]"
        _champs(e, c, CHAMPS_ECHANTILLON, OBLIGATOIRES_ECHANTILLON)
        if "id" in e:
            _texte(e["id"], f"{c}.id", RE_ID)
        attendu = _latex(e["attendu"], f"{c}.attendu")
        if e["type"] == "signe":
            if "classe" not in e:
                raise DonInvalide(f"{c}.classe : obligatoire pour un signe")
            if not isinstance(e["classe"], str) or e["classe"] not in classes:
                raise DonInvalide(f"{c}.classe : signe inconnu de classes.txt")
            if classes[e["classe"]] != attendu:
                raise DonInvalide(f"{c}.attendu : ne correspond pas à la classe")
        elif e["type"] == "expression":
            if "classe" in e:
                raise DonInvalide(f"{c}.classe : réservé aux signes")
        else:
            raise DonInvalide(f"{c}.type : signe ou expression")
        if "rejete" in e and not isinstance(e["rejete"], bool):
            raise DonInvalide(f"{c}.rejete : booléen attendu")
        if "case" in e:
            case = e["case"]
            if not isinstance(case, list) or len(case) != 4:
                raise DonInvalide(f"{c}.case : 4 nombres attendus")
            _nombre(case[0], f"{c}.case", -COORD_MAX, COORD_MAX)
            _nombre(case[1], f"{c}.case", -COORD_MAX, COORD_MAX)
            _nombre(case[2], f"{c}.case", 1e-3, COORD_MAX)
            _nombre(case[3], f"{c}.case", 1e-3, COORD_MAX)
        traits = e["traits"]
        if not isinstance(traits, list) or len(traits) > TRAITS_MAX:
            raise DonInvalide(f"{c}.traits : liste de {TRAITS_MAX} traits au plus")
        for j, t in enumerate(traits):
            if not isinstance(t, list) or len(t) > POINTS_MAX:
                raise DonInvalide(f"{c}.traits[{j}] : liste de {POINTS_MAX} points au plus")
            total += len(t)
            for p in t:
                if not isinstance(p, list) or len(p) != 4:
                    raise DonInvalide(f"{c}.traits[{j}] : point [x, y, t, p] attendu")
                _nombre(p[0], f"{c}.traits[{j}].x", -COORD_MAX, COORD_MAX)
                _nombre(p[1], f"{c}.traits[{j}].y", -COORD_MAX, COORD_MAX)
                _nombre(p[2], f"{c}.traits[{j}].t", 0, TEMPS_MAX)
                _nombre(p[3], f"{c}.traits[{j}].p", 0, 1)
        if total > POINTS_TOTAL_MAX:
            raise DonInvalide(f"séance : plus de {POINTS_TOTAL_MAX} points")
    return len(echantillons)
