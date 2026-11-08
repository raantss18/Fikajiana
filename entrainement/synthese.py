"""Signes synthétiques tirés de polices manuscrites OFL, rendus comme un tracé au stylet.

1. Le glyphe est dessiné en grand (PIL), puis réduit à son squelette (scikit-image).
2. Le squelette devient des traits : on suit les branches entre extrémités et croisements, puis on
   recolle à chaque croisement les branches qui se prolongent (le « + » donne deux traits).
3. Chaque échantillon déforme ces traits : penchée, rotation, étirement, ondulation douce,
   décalage de chaque trait, bouts raccourcis, tremblement ; l'épaisseur varie au rendu.
"""

from __future__ import annotations

import math
import pathlib
from functools import lru_cache

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from skimage.morphology import skeletonize

TAILLE_GLYPHE = 160  # px de la police au dessin

# Caractères essayés pour chaque classe quand le signe de classes.txt manque ou a des variantes.
VARIANTES = {
    "moins": ["−", "-"],
    "point_fois": ["·", "⋅"],
    "prime": ["′", "'", "’"],
    "somme": ["Σ", "∑"],
    "phi": ["φ", "ϕ"],
    "fois": ["×"],
    "barre": ["/"],
    "abs": ["|"],
}

VOISINS = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def caracteres(ident: str, signe: str) -> list[str]:
    return VARIANTES.get(ident, [signe])


@lru_cache(maxsize=None)
def _police(chemin: str) -> ImageFont.FreeTypeFont:
    police = ImageFont.truetype(chemin, TAILLE_GLYPHE)
    try:  # Police variable (Caveat) : graisse 400.
        police.set_variation_by_axes([400])
    except Exception:
        pass
    return police


def couvre(chemin: str, car: str) -> bool:
    return ord(car) in _cmap(chemin)


@lru_cache(maxsize=None)
def _cmap(chemin: str) -> frozenset[int]:
    from fontTools.ttLib import TTFont

    return frozenset(TTFont(chemin).getBestCmap())


def _graphe(squelette: np.ndarray):
    pts = set(zip(*np.nonzero(squelette)))

    def voisins(p):
        return [(p[0] + a, p[1] + b) for a, b in VOISINS if (p[0] + a, p[1] + b) in pts]

    return pts, voisins


def squelette_en_traits(masque: np.ndarray, rayon: float = 6.0) -> list[list[tuple[float, float]]]:
    """Traits (x, y) en pixels suivant le squelette du masque.

    `rayon` : deux croisements plus proches que cela n'en font qu'un (le squelette d'un « + »
    a souvent deux nœuds voisins reliés par un bout de branche).
    """
    sq = skeletonize(masque)
    pts, voisins = _graphe(sq)
    if not pts:
        return []
    degre = {p: len(voisins(p)) for p in pts}
    noeuds = {p for p in pts if degre[p] != 2}
    # Croisements : regrouper les pixels de degré ≥ 3 proches les uns des autres.
    croisements = sorted(p for p in noeuds if degre[p] >= 3)
    groupe = {}
    for p in croisements:
        if p not in groupe:
            pile, g = [p], len(groupe) + 1000000
            groupe[p] = g
            while pile:
                q = pile.pop()
                for r in croisements:
                    if r not in groupe and math.dist(q, r) <= rayon:
                        groupe[r] = g
                        pile.append(r)
    vus_aretes = set()
    branches = []  # (chemin, noeud_debut, noeud_fin)
    for depart in sorted(noeuds):
        for suivant in voisins(depart):
            if (depart, suivant) in vus_aretes or suivant in groupe and groupe.get(depart) == groupe[suivant]:
                continue
            chemin = [depart, suivant]
            vus_aretes.add((depart, suivant))
            precedent, courant = depart, suivant
            while courant not in noeuds:
                nxt = [r for r in voisins(courant) if r != precedent and r not in chemin[-3:]]
                if not nxt:
                    break
                precedent, courant = courant, nxt[0]
                chemin.append(courant)
            vus_aretes.add((chemin[-1], chemin[-2]))
            branches.append(chemin)
    # Points isolés (le point d'un « i », un « . » très petit).
    branches += [[p] for p in sorted(pts) if degre[p] == 0]
    # Bouts de branche internes à un croisement.
    branches = [
        b
        for b in branches
        if not (b[0] in groupe and b[-1] in groupe and groupe[b[0]] == groupe[b[-1]] and len(b) <= 3 * rayon)
    ]
    # Boucles sans nœud (« o », « 0 ») : pixels non couverts.
    couverts = {p for b in branches for p in b}
    for p in sorted(pts - couverts):
        if p in couverts or degre[p] != 2 or any(math.dist(p, q) <= rayon for q in croisements):
            continue
        chemin, precedent, courant = [p], None, p
        while True:
            nxt = [r for r in voisins(courant) if r != precedent and r not in chemin[-3:]]
            nxt = [r for r in nxt if r not in couverts or r == p]
            if not nxt or (len(chemin) > 2 and p in voisins(courant)):
                break
            precedent, courant = courant, nxt[0]
            chemin.append(courant)
            couverts.add(courant)
        couverts.add(p)
        chemin.append(p)
        branches.append(chemin)

    # Ergots : petites branches pendantes.
    branches = [
        b
        for b in branches
        if not (len(b) < 2 * rayon and (degre[b[0]] == 1) != (degre[b[-1]] == 1))
    ] or branches

    # Recoller aux croisements les branches qui se prolongent.
    def cle(p):
        return groupe.get(p, p)

    def direction(b, au_debut):
        seg = b[: min(len(b), 12)] if au_debut else b[-min(len(b), 12):][::-1]
        dy, dx = seg[-1][0] - seg[0][0], seg[-1][1] - seg[0][1]
        n = math.hypot(dx, dy) or 1
        return dx / n, dy / n

    bouts = {}  # nœud -> [(indice branche, au_debut)]
    for i, b in enumerate(branches):
        for au_debut in (True, False):
            p = b[0] if au_debut else b[-1]
            if degre.get(p, 0) >= 3:
                bouts.setdefault(cle(p), []).append((i, au_debut))
    lien = {}
    for liste in bouts.values():
        paires = []
        for a in range(len(liste)):
            for c in range(a + 1, len(liste)):
                (i, di), (j, dj) = liste[a], liste[c]
                if i == j:
                    continue
                u, v = direction(branches[i], di), direction(branches[j], dj)
                paires.append((u[0] * v[0] + u[1] * v[1], liste[a], liste[c]))
        paires.sort()
        # Croisement à quatre branches (« + », « x ») : on apparie toujours ; à trois (« T »,
        # jonction du « 4 ») : seulement les branches qui se prolongent nettement.
        seuil = 0.3 if len(liste) >= 4 else -0.5
        for cosinus, a, c in paires:
            if cosinus > seuil:
                break
            if a in lien or c in lien:
                continue
            lien[a], lien[c] = c, a
    traits, utilisees = [], set()
    for i in range(len(branches)):
        if i in utilisees:
            continue
        # Remonter au début de la chaîne.
        debut, sens = i, True
        pas = 0
        while (debut, sens) in lien and pas < len(branches):
            j, dj = lien[(debut, sens)]
            if j == i:
                break
            debut, sens = j, not dj
            pas += 1
        chaine, courant, sens_courant = [], debut, sens
        while courant is not None and courant not in utilisees:
            utilisees.add(courant)
            b = branches[courant] if sens_courant else branches[courant][::-1]
            chaine += b
            fin = (courant, not sens_courant)
            if fin in lien:
                j, dj = lien[fin]
                courant, sens_courant = j, dj
            else:
                courant = None
        traits.append([(float(p[1]), float(p[0])) for p in chaine])
    return traits


def _simplifier(trait, pas):
    """Garde un point tous les `pas` pixels environ, puis lisse légèrement."""
    if len(trait) <= 2:
        return trait
    garde = [trait[0]]
    for p in trait[1:-1]:
        if math.dist(p, garde[-1]) >= pas:
            garde.append(p)
    garde.append(trait[-1])
    if len(garde) > 3:
        lisse = [garde[0]]
        for a, b, c in zip(garde, garde[1:], garde[2:]):
            lisse.append(((a[0] + 2 * b[0] + c[0]) / 4, (a[1] + 2 * b[1] + c[1]) / 4))
        lisse.append(garde[-1])
        garde = lisse
    return garde


@lru_cache(maxsize=None)
def glyphe(chemin: str, car: str):
    """Traits du glyphe (unité : hauteur des capitales = 1, y = 0 sur la ligne de base) et métriques.

    Rend None si la police n'a pas le caractère ou si le dessin est vide.
    """
    if not couvre(chemin, car):
        return None
    police = _police(chemin)
    marge = TAILLE_GLYPHE
    image = Image.new("L", (TAILLE_GLYPHE * 3, TAILLE_GLYPHE * 3), 0)
    ImageDraw.Draw(image).text((marge, 2 * marge), car, font=police, fill=255, anchor="ls")
    masque = np.asarray(image) > 127
    if not masque.any():
        return None
    _, haut_h, _, _ = police.getbbox("H", anchor="ls")
    capitale = -haut_h if haut_h < 0 else TAILLE_GLYPHE * 0.7
    traits = squelette_en_traits(masque)
    traits = [_simplifier(t, max(2.0, capitale / 40)) for t in traits]
    traits = [
        [((x - marge) / capitale, (y - 2 * marge) / capitale) for x, y in t] for t in traits if t
    ]
    return traits or None


def _ondulation(rng):
    """Champ de déplacement doux (somme de deux sinusoïdes) en unités de hauteur."""
    termes = []
    for _ in range(2):
        f = rng.uniform(0.8, 2.5)
        termes.append((rng.uniform(0, 2 * math.pi), rng.uniform(0, 2 * math.pi), f, rng.normal(0, 0.025), rng.normal(0, 0.025)))

    def champ(x, y):
        dx = dy = 0.0
        for ph1, ph2, f, ax, ay in termes:
            dx += ax * math.sin(2 * math.pi * f * y + ph1)
            dy += ay * math.sin(2 * math.pi * f * x + ph2)
        return dx, dy

    return champ


def deformer(traits, rng, force: float = 1.0):
    """Une écriture plausible de ces traits : géométrie seulement (unités de hauteur)."""
    rot = math.radians(np.clip(rng.normal(0, 5 * force), -12, 12))
    penche = rng.uniform(-0.3, 0.25) * force
    ex = math.exp(rng.normal(0, 0.12 * force))
    ey = math.exp(rng.normal(0, 0.06 * force))
    c, s = math.cos(rot), math.sin(rot)
    champ = _ondulation(rng) if force > 0 else (lambda x, y: (0.0, 0.0))
    sortie = []
    for t in traits:
        if len(t) > 3 and rng.random() < 0.5 * force:
            # Bouts raccourcis ou prolongés.
            a = int(rng.integers(0, max(1, len(t) // 10) + 1))
            b = len(t) - int(rng.integers(0, max(1, len(t) // 10) + 1))
            t = t[a:b] if b - a >= 2 else t
        ox, oy = rng.normal(0, 0.025 * force, 2)
        nouveau = []
        for x, y in t:
            x, y = x + penche * -y, y
            x, y = x * ex, y * ey
            x, y = c * x - s * y, s * x + c * y
            dx, dy = champ(x, y)
            jx, jy = rng.normal(0, 0.006 * force, 2)
            nouveau.append((x + dx + ox + jx, y + dy + oy + jy))
        sortie.append(nouveau)
    if len(sortie) == 1 and len(sortie[0]) > 12 and rng.random() < 0.06 * force:
        # Lever de stylet au milieu d'un trait.
        t, m = sortie[0], int(rng.integers(4, len(sortie[0]) - 4))
        sortie = [t[: m + 1], t[m:]]
    return sortie


def case_synthetique(traits, rng):
    """Case de référence autour d'un glyphe : la ligne d'écriture (capitale = 1, base en y = 0)."""
    haut = -rng.uniform(1.0, 1.35)
    hauteur = rng.uniform(1.3, 2.0)
    ys = [p[1] for t in traits for p in t]
    xs = [p[0] for t in traits for p in t]
    haut = min(haut, min(ys))
    bas = max(haut + hauteur, max(ys))
    return (min(xs), haut, max(xs) - min(xs), bas - haut)


def polices(dossier: pathlib.Path) -> dict[str, str]:
    """Nom de police -> chemin du .ttf."""
    return {p.parent.name: str(p) for p in sorted(pathlib.Path(dossier).glob("*/*.ttf"))}
