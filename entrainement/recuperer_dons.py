# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Récupère les dons d'écriture de la plateforme (ADR 0042), les trie et les range pour `entrainer.py`.

Usage, depuis la racine du dépôt :
    FIKA_DONS_ADRESSE=https://dons.exemple.org FIKA_JETON_ADMIN=… uv run entrainement/recuperer_dons.py

Options : --depuis 2026-11-01T00:00:00Z (sinon : la fin du dernier export, notée dans --etat),
          --fichier export.ndjson (lire un export déjà téléchargé au lieu d'appeler la plateforme),
          --dossier donnees/ecriture/dons, --etat donnees/dons-etat.json, --rapport donnees/dons-rapport.md

Ce que fait le script :
1. `GET /v1/export` (jeton dans l'en-tête Authorization, jamais dans l'adresse).
2. Applique **tous** les retraits connus : efface le dossier local de chaque identifiant retiré.
3. Vérifie chaque séance avec `plateforme/schema.py` (le même code que le récepteur), puis trie les
   échantillons : traits vides, signes impossibles, doublons exacts, LaTeX qui ne s'analyse pas.
4. Écrit les séances gardées dans `donnees/ecriture/dons/<contributeur>/`, au format
   `collecte/FORMAT.md` : `entrainer.py` les lit sans changement. Écrit un rapport du tri.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import shutil
import sys
import urllib.parse
import urllib.request

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "plateforme"))
import schema  # noqa: E402

# --- LaTeX : une analyse volontairement simple, mais stricte ---------------------------------

COMMANDES = {
    # opérateurs et relations
    "times", "cdot", "div", "pm", "mp", "leq", "geq", "le", "ge", "neq", "ne", "approx", "equiv",
    "lt", "gt", "to", "rightarrow", "leftarrow", "Rightarrow", "Leftarrow", "Leftrightarrow",
    "iff", "implies", "mapsto", "in", "notin", "subset", "subseteq", "cup", "cap", "setminus",
    "emptyset", "varnothing", "forall", "exists", "infty", "partial", "nabla", "circ", "perp",
    "parallel", "angle", "mid", "ldots", "cdots", "dots", "prime", "degree",
    # structures
    "frac", "dfrac", "tfrac", "sqrt", "left", "right", "begin", "end", "binom", "vec",
    "overrightarrow", "overline", "bar", "hat", "dot", "mathbb", "mathrm", "operatorname", "text",
    "quad", "qquad",
    # fonctions
    "sin", "cos", "tan", "cot", "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "ln", "log",
    "exp", "lim", "sum", "prod", "int", "iint", "oint", "det", "min", "max", "sup", "inf", "arg",
    "gcd", "deg", "dim", "ker",
    # grec
    "alpha", "beta", "gamma", "delta", "epsilon", "varepsilon", "zeta", "eta", "theta", "vartheta",
    "iota", "kappa", "lambda", "mu", "nu", "xi", "pi", "rho", "sigma", "tau", "upsilon", "phi",
    "varphi", "chi", "psi", "omega", "Gamma", "Delta", "Theta", "Lambda", "Xi", "Pi", "Sigma",
    "Upsilon", "Phi", "Psi", "Omega",
}
ENVIRONNEMENTS = {"pmatrix", "bmatrix", "vmatrix", "matrix", "cases", "array"}
SYMBOLES_ECHAPPES = set("{}\\,;:! |_%&#$")
DELIMITEURS = {"(", ")", "[", "]", "|", ".", "\\{", "\\}", "\\|", "\\langle", "\\rangle"}
RE_JETON = re.compile(r"\\[A-Za-z]+|\\.|[{}\[\]^_&]|\s+|.", re.S)


class LatexIllisible(ValueError):
    pass


def latex_valide(texte: str) -> bool:
    try:
        _analyser(texte)
        return True
    except LatexIllisible:
        return False


def _analyser(texte: str) -> None:
    jetons = [j for j in RE_JETON.findall(texte) if not j.isspace()]
    pos = 0
    pile: list[str] = []  # "{", "left", "env:<nom>"

    def suivant():
        return jetons[pos] if pos < len(jetons) else None

    def argument():
        """Un argument obligatoire : un groupe {…} ou un seul jeton (TeX accepte \\frac12)."""
        nonlocal pos
        j = suivant()
        if j is None or j in ("}", "^", "_", "&", "\\\\"):
            raise LatexIllisible("argument manquant")
        if j == "{":
            profondeur = 0
            while pos < len(jetons):
                if jetons[pos] == "{":
                    profondeur += 1
                elif jetons[pos] == "}":
                    profondeur -= 1
                    if profondeur == 0:
                        pos += 1
                        return
                pos += 1
            raise LatexIllisible("accolade non fermée")
        if j.startswith("\\") and j[1:] not in COMMANDES and j[1:] not in SYMBOLES_ECHAPPES:
            raise LatexIllisible("commande inconnue")
        pos += 1

    # Première passe : équilibre global et commandes connues ; les arguments sont vérifiés au vol.
    while pos < len(jetons):
        j = jetons[pos]
        pos += 1
        if j == "{":
            pile.append("{")
        elif j == "}":
            if not pile or pile[-1] != "{":
                raise LatexIllisible("accolade fermante seule")
            pile.pop()
        elif j in ("^", "_"):
            argument_debut = pos
            argument()
            pos = argument_debut  # le contenu du groupe est relu normalement
        elif j in ("&", "\\\\"):
            if not any(p.startswith("env:") for p in pile):
                raise LatexIllisible(f"{j} hors d'un tableau")
        elif j.startswith("\\") and len(j) == 2 and not j[1].isalpha():
            if j[1] not in SYMBOLES_ECHAPPES:
                raise LatexIllisible("symbole échappé inconnu")
        elif j.startswith("\\"):
            nom = j[1:]
            if nom not in COMMANDES:
                raise LatexIllisible("commande inconnue")
            if nom in ("frac", "dfrac", "tfrac", "binom"):
                debut = pos
                argument()
                argument()
                pos = debut
            elif nom == "sqrt":
                if suivant() == "[":
                    while pos < len(jetons) and jetons[pos] != "]":
                        pos += 1
                    if pos >= len(jetons):
                        raise LatexIllisible("crochet de racine non fermé")
                    pos += 1
                debut = pos
                argument()
                pos = debut
            elif nom in ("vec", "overrightarrow", "overline", "bar", "hat", "dot", "mathbb", "mathrm",
                         "operatorname", "text"):
                debut = pos
                argument()
                pos = debut
            elif nom in ("left", "right"):
                d = suivant()
                if d is None or d not in DELIMITEURS:
                    raise LatexIllisible("délimiteur manquant après \\left ou \\right")
                pos += 1
                if nom == "left":
                    pile.append("left")
                else:
                    if not pile or pile[-1] != "left":
                        raise LatexIllisible("\\right sans \\left")
                    pile.pop()
            elif nom in ("begin", "end"):
                if jetons[pos : pos + 1] != ["{"]:
                    raise LatexIllisible("environnement sans nom")
                fin = pos + 1
                while fin < len(jetons) and jetons[fin] != "}":
                    fin += 1
                env = "".join(jetons[pos + 1 : fin])
                if fin >= len(jetons) or env not in ENVIRONNEMENTS:
                    raise LatexIllisible("environnement inconnu")
                pos = fin + 1
                if nom == "begin":
                    pile.append("env:" + env)
                else:
                    if not pile or pile[-1] != "env:" + env:
                        raise LatexIllisible("\\end sans \\begin")
                    pile.pop()
    if pile:
        raise LatexIllisible("groupe non fermé")


# --- Tri ---------------------------------------------------------------------------------------

TRAITS_MAX_SIGNE = 6
SANS_ETENDUE = {"point", "point_fois"}  # un tapotement : un seul point est normal


def empreinte(e: dict) -> str:
    """Identité exacte d'un échantillon : ce qui a été écrit et ce qui était demandé."""
    cle = [e["type"], e.get("classe"), e["attendu"], e["traits"]]
    return hashlib.sha256(json.dumps(cle, separators=(",", ":")).encode("utf-8")).hexdigest()


def motif_de_rejet(e: dict) -> str | None:
    """None si l'échantillon est gardé, sinon la raison (clé du rapport)."""
    traits = [t for t in e["traits"] if t]
    if not traits:
        return "traits vides"
    if e["type"] != "signe":
        # Un signe porte le LaTeX de sa classe (vérifié par le schéma, « \\sqrt » seul compris).
        return None if latex_valide(e["attendu"]) else "LaTeX illisible"
    if len(traits) > TRAITS_MAX_SIGNE:
        return "signe impossible"
    xs = [p[0] for t in traits for p in t]
    ys = [p[1] for t in traits for p in t]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    if w == 0 and h == 0 and e["classe"] not in SANS_ETENDUE:
        return "signe impossible"
    if "case" in e:
        cl, ct, cw, ch = e["case"]
        if w > 3 * cw or h > 3 * ch:
            return "signe impossible"
        # Entièrement hors de la case agrandie d'une case de chaque côté : écrit ailleurs.
        if max(xs) < cl - cw or min(xs) > cl + 2 * cw or max(ys) < ct - ch or min(ys) > ct + 2 * ch:
            return "signe impossible"
    return None


def empreintes_locales(dossier: pathlib.Path) -> set[str]:
    vues = set()
    for f in sorted(dossier.rglob("*.json")):
        try:
            doc = json.loads(f.read_text(encoding="utf-8"))
            for e in doc.get("echantillons", []):
                vues.add(empreinte(e))
        except (ValueError, KeyError, TypeError):
            continue
    return vues


def appliquer_retraits(dossier: pathlib.Path, retires: set[str]) -> int:
    effaces = 0
    for ident in sorted(retires):
        if not schema.RE_CONTRIBUTEUR.fullmatch(ident):
            continue
        cible = dossier / ident
        if cible.is_dir():
            effaces += sum(1 for _ in cible.glob("*.json"))
            shutil.rmtree(cible)
    return effaces


def trier(lignes, dossier: pathlib.Path, etat: dict, classes: dict[str, str]) -> dict:
    """Applique un export (liste d'objets JSON lines) au dossier local. Rend le bilan du tri."""
    bilan = collections.Counter()
    motifs = collections.Counter()
    retires = set(etat.get("retraits", []))
    entete = None
    dons = []
    for ligne in lignes:
        if ligne.get("type") == "export":
            entete = ligne
        elif ligne.get("type") == "retrait":
            retires.add(ligne["contributeur"])
        elif ligne.get("type") == "don":
            dons.append(ligne)
    if entete is None:
        raise SystemExit("export sans en-tête : réponse inattendue de la plateforme")

    dossier.mkdir(parents=True, exist_ok=True)
    bilan["fichiers effacés (retraits)"] = appliquer_retraits(dossier, retires)
    vues = empreintes_locales(dossier)

    for don in dons:
        bilan["séances reçues"] += 1
        seance = don.get("seance")
        try:
            schema.verifier_seance(seance, classes)
        except schema.DonInvalide:
            bilan["séances refusées (format)"] += 1
            continue
        contributeur = seance["contributeur"]
        if contributeur in retires:
            bilan["séances ignorées (retirées)"] += 1
            continue
        nom = pathlib.PurePosixPath(don.get("cle", "")).name
        if not re.fullmatch(r"[0-9TZ]+-[0-9a-f]+\.json", nom):
            bilan["séances refusées (format)"] += 1
            continue
        cible = dossier / contributeur / nom
        if cible.exists():
            bilan["séances déjà là"] += 1
            continue
        gardes = []
        for e in seance["echantillons"]:
            bilan["échantillons reçus"] += 1
            motif = motif_de_rejet(e)
            if motif is None:
                h = empreinte(e)
                if h in vues:
                    motif = "doublon exact"
                else:
                    vues.add(h)
            if motif:
                motifs[motif] += 1
            else:
                gardes.append(e)
        if not gardes:
            bilan["séances vides après tri"] += 1
            continue
        cible.parent.mkdir(parents=True, exist_ok=True)
        sortie = dict(seance, echantillons=gardes)
        cible.write_text(json.dumps(sortie, ensure_ascii=False), encoding="utf-8")
        bilan["séances écrites"] += 1
        bilan["échantillons gardés"] += len(gardes)

    etat["retraits"] = sorted(retires)
    etat["jusqua"] = entete.get("jusqua")
    return {"bilan": dict(bilan), "motifs": dict(motifs), "depuis": entete.get("depuis"), "jusqua": entete.get("jusqua")}


def rapport_md(resultat: dict) -> str:
    lignes = [
        "# Tri des dons d'écriture",
        "",
        f"- Export du {resultat['depuis']} au {resultat['jusqua']}",
        "",
        "| Compte | Nombre |",
        "|---|---|",
    ]
    lignes += [f"| {k} | {v} |" for k, v in sorted(resultat["bilan"].items())]
    lignes += ["", "| Échantillon écarté | Nombre |", "|---|---|"]
    lignes += [f"| {k} | {v} |" for k, v in sorted(resultat["motifs"].items())] or ["| (aucun) | 0 |"]
    return "\n".join(lignes) + "\n"


def telecharger(adresse: str, jeton: str, depuis: str | None):
    url = adresse.rstrip("/") + "/v1/export"
    if depuis:
        url += "?" + urllib.parse.urlencode({"depuis": depuis})
    if not url.startswith("https://") and not url.startswith("http://127.0.0.1") and not url.startswith("http://localhost"):
        raise SystemExit("FIKA_DONS_ADRESSE doit commencer par https:// (le jeton ne passe jamais en clair)")
    requete = urllib.request.Request(url, headers={"Authorization": f"Bearer {jeton}"})
    with urllib.request.urlopen(requete, timeout=120) as reponse:
        for brut in reponse:
            if brut.strip():
                yield json.loads(brut)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--dossier", type=pathlib.Path, default=pathlib.Path("donnees/ecriture/dons"))
    p.add_argument("--etat", type=pathlib.Path, default=pathlib.Path("donnees/dons-etat.json"))
    p.add_argument("--rapport", type=pathlib.Path, default=pathlib.Path("donnees/dons-rapport.md"))
    p.add_argument("--depuis", help="date ISO 8601 ; par défaut la fin du dernier export")
    p.add_argument("--fichier", type=pathlib.Path, help="export JSON lines déjà téléchargé")
    args = p.parse_args(argv)

    etat = json.loads(args.etat.read_text(encoding="utf-8")) if args.etat.exists() else {}
    if args.fichier:
        lignes = [json.loads(l) for l in args.fichier.read_text(encoding="utf-8").splitlines() if l.strip()]
    else:
        adresse, jeton = os.environ.get("FIKA_DONS_ADRESSE"), os.environ.get("FIKA_JETON_ADMIN")
        if not adresse or not jeton:
            raise SystemExit("FIKA_DONS_ADRESSE et FIKA_JETON_ADMIN sont nécessaires (ou --fichier)")
        lignes = list(telecharger(adresse, jeton, args.depuis or etat.get("jusqua")))

    resultat = trier(lignes, args.dossier, etat, schema.lire_classes())
    args.etat.parent.mkdir(parents=True, exist_ok=True)
    args.etat.write_text(json.dumps(etat, indent=1, ensure_ascii=False), encoding="utf-8")
    texte = rapport_md(resultat)
    args.rapport.write_text(texte, encoding="utf-8")
    print(texte)
    print(f"Séances rangées dans {args.dossier} ; lancer : uv run entrainement/entrainer.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
