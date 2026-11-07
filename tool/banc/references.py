#!/usr/bin/env python3
"""Valeurs de référence du calcul formel, calculées par SymPy (règle 8).

Chaque résultat est écrit ici en SymPy, indépendamment du lecteur LaTeX de l'app :
un écart dit qu'un des deux logiciels, ou la lecture, se trompe.
Usage : python3 tool/banc/references.py > app/banc/references.dart
"""
import json

import sympy as sp
from sympy import E, I, Integer, Matrix, Rational as R, oo, pi, sqrt

x, y, z, t, n, k = sp.symbols("x y z t n k")
POINTS = [1.37, 0.61]
cas = []


def nombre(v):
    v = sp.N(v, 20)
    if v in (oo, sp.zoo):
        return ["inf", 0]
    if v == -oo:
        return ["-inf", 0]
    re, im = v.as_real_imag()
    return [float(re), float(im)]


def valeur(famille, latex, attendu):
    cas.append({"f": famille, "l": latex, "g": "valeur", "a": nombre(attendu)})


def fonction(famille, latex, attendu, variable=x):
    cas.append({"f": famille, "l": latex, "g": "fonction", "v": str(variable),
                "p": POINTS, "a": [float(sp.N(attendu.subs(variable, p), 20)) for p in POINTS]})


def primitive(famille, latex, derivee):
    """Une primitive n'est juste qu'à une constante près : on compare un écart."""
    ecart = sp.Integral(derivee, (x, POINTS[1], POINTS[0])).evalf(20)
    cas.append({"f": famille, "l": latex, "g": "primitive", "p": POINTS, "a": float(ecart)})


def solutions(famille, latex, attendues):
    cas.append({"f": famille, "l": latex, "g": "liste",
                "a": sorted(float(sp.N(v, 20)) for v in attendues)})


def matrice(famille, latex, attendue):
    cas.append({"f": famille, "l": latex, "g": "liste", "ordre": True,
                "a": [float(sp.N(v, 20)) for v in attendue]})


def verite(famille, latex, attendu):
    cas.append({"f": famille, "l": latex, "g": "verite", "a": bool(attendu)})


def ordre(latex, vrais, faux):
    """Une inéquation : le résultat doit garder ces nombres, et refuser ceux-là."""
    cas.append({"f": "inequations", "l": latex, "g": "ordre", "vrais": vrais, "faux": faux})


# Arithmétique
for latex, v in [
    (r"\frac{1}{2}+\frac{1}{3}", R(5, 6)),
    (r"\frac12", R(1, 2)),
    (r"2^{10}", 2**10),
    (r"10^{-3}", R(1, 1000)),
    (r"\sqrt{50}", 5 * sqrt(2)),
    (r"\sqrt[3]{8}", 2),
    (r"5!", 120),
    (r"\binom{5}{2}", sp.binomial(5, 2)),
    (r"C_5^2", sp.binomial(5, 2)),
    (r"A_5^2", 20),
    (r"\gcd(12,18)", sp.gcd(12, 18)),
    (r"\operatorname{pgcd}(12;18)", sp.gcd(12, 18)),
    (r"\operatorname{ppcm}(4,6)", sp.lcm(4, 6)),
    (r"17 \bmod 5", 17 % 5),
    (r"-7 \bmod 3", (-7) % 3),
    (r"\lfloor 2{,}5 \rfloor", sp.floor(R(5, 2))),
    (r"\lceil 2{,}5 \rceil", sp.ceiling(R(5, 2))),
    (r"|-3|", 3),
    (r"30\%", R(3, 10)),
    (r"1{,}5+1", R(5, 2)),
]:
    valeur("arithmetique", latex, v)

# Fonctions usuelles
for latex, v in [
    (r"\sin(\pi/6)", R(1, 2)),
    (r"\cos(\pi/3)", R(1, 2)),
    (r"\tan(\pi/4)", 1),
    (r"\cot(1)", sp.cot(1)),
    (r"\arcsin(1)", pi / 2),
    (r"\arccos(0)", pi / 2),
    (r"\arctan(1)", pi / 4),
    (r"\sinh(1)", sp.sinh(1)),
    (r"\cosh(1)", sp.cosh(1)),
    (r"\ln(5)", sp.log(5)),
    (r"\ln(e)", 1),
    (r"\log(100)", 2),
    (r"\log_{2}(8)", 3),
    (r"\log_2 8", 3),
    (r"\exp(1)", E),
    (r"e^{2}", E**2),
]:
    valeur("fonctions", latex, v)

# Dérivées
fonction("derivees", r"\frac{d}{dx}(x^3)", sp.diff(x**3, x))
fonction("derivees", r"\frac{d}{dx}x^3", sp.diff(x**3, x))
fonction("derivees", r"\frac{d}{dx}\sin(x)", sp.cos(x))
fonction("derivees", r"\frac{d}{dx}(e^{x^2})", sp.diff(sp.exp(x**2), x))
fonction("derivees", r"\frac{d}{dx}(\ln(x))", 1 / x)
fonction("derivees", r"\frac{d}{dx}(x\sin(x))", sp.diff(x * sp.sin(x), x))
fonction("derivees", r"\frac{d}{dx}\left(\frac{x^2+1}{x-1}\right)", sp.diff((x**2 + 1) / (x - 1), x))
fonction("derivees", r"\frac{d^2}{dx^2}(x^4)", sp.diff(x**4, x, 2))
fonction("derivees", r"\frac{d(x^2)}{dx}", 2 * x)
fonction("derivees", r"\frac{\mathrm{d}}{\mathrm{d}x}(x^2)", 2 * x)
fonction("derivees", r"(x^2+1)'", 2 * x)
fonction("derivees", r"(\sin(x))''", -sp.sin(x))
fonction("derivees", r"\frac{d}{dt}(t^3)", 3 * t**2, t)
fonction("derivees", r"\frac{d}{dx}(\tan(x))", sp.diff(sp.tan(x), x))
fonction("derivees", r"\frac{d}{dx}(\sqrt{x})", sp.diff(sqrt(x), x))

# Primitives
primitive("primitives", r"\int x^2 dx", x**2)
primitive("primitives", r"\int \frac{1}{x} dx", 1 / x)
primitive("primitives", r"\int \sin(x) dx", sp.sin(x))
primitive("primitives", r"\int e^{2x} dx", sp.exp(2 * x))
primitive("primitives", r"\int x e^{x} dx", x * sp.exp(x))
primitive("primitives", r"\int \ln(x) dx", sp.log(x))
primitive("primitives", r"\int \frac{1}{1+x^2} dx", 1 / (1 + x**2))
primitive("primitives", r"\int \frac{x}{x^2+1} dx", x / (x**2 + 1))
primitive("primitives", r"\int \cos^2(x) dx", sp.cos(x) ** 2)

# Intégrales définies
for latex, f, a, b in [
    (r"\int_0^1 x^2 dx", x**2, 0, 1),
    (r"\int_{0}^{1}x^{2}\,dx", x**2, 0, 1),
    (r"\int_0^{\pi}\sin(x)dx", sp.sin(x), 0, pi),
    (r"\int_1^e \frac{1}{x} dx", 1 / x, 1, E),
    (r"\int_0^{+\infty} e^{-x} dx", sp.exp(-x), 0, oo),
    (r"\int_{-\infty}^{+\infty} e^{-x^2} dx", sp.exp(-(x**2)), -oo, oo),
    (r"\int_0^1 x e^{x} dx", x * sp.exp(x), 0, 1),
    (r"\int_1^e \ln(x) dx", sp.log(x), 1, E),
    (r"\int_0^1 \frac{1}{1+x^2} dx", 1 / (1 + x**2), 0, 1),
    (r"\int_{-1}^{1} |x| dx", sp.Abs(x), -1, 1),
]:
    valeur("integrales", latex, sp.integrate(f, (x, a, b)))

# Limites
for latex, f, cible, sens in [
    (r"\lim_{x\to0}\frac{\sin(x)}{x}", sp.sin(x) / x, 0, "+"),
    (r"\lim_{x\to+\infty}\frac{1}{x}", 1 / x, oo, "-"),
    (r"\lim_{x\to+\infty}(1+\frac{1}{x})^x", (1 + 1 / x) ** x, oo, "-"),
    (r"\lim_{x\to1}\frac{x^2-1}{x-1}", (x**2 - 1) / (x - 1), 1, "+"),
    (r"\lim_{x\to0}\frac{1-\cos(x)}{x^2}", (1 - sp.cos(x)) / x**2, 0, "+"),
    (r"\lim_{x\to0^+}\frac{1}{x}", 1 / x, 0, "+"),
    (r"\lim_{x\to0^-}\frac{1}{x}", 1 / x, 0, "-"),
    (r"\lim_{x\to0^{+}}\ln(x)", sp.log(x), 0, "+"),
    (r"\lim_{x\to-\infty}e^{x}", sp.exp(x), -oo, "+"),
    (r"\lim_{x\to+\infty}\frac{2x+1}{x-3}", (2 * x + 1) / (x - 3), oo, "-"),
]:
    valeur("limites", latex, sp.limit(f, x, cible, sens))

# Sommes et produits
for latex, v in [
    (r"\sum_{k=1}^{10}k", sp.summation(k, (k, 1, 10))),
    (r"\sum_{i=1}^{10}i^2", sp.summation(k**2, (k, 1, 10))),
    (r"\sum_{k=0}^{\infty}\frac{1}{2^k}", sp.summation(R(1, 2) ** k, (k, 0, oo))),
    (r"\sum_{n=1}^{+\infty}\frac{1}{n^2}", sp.summation(1 / n**2, (n, 1, oo))),
    (r"\prod_{k=1}^{5}k", 120),
]:
    valeur("series", latex, v)
fonction("series", r"\sum_{k=1}^{n}k", sp.summation(k, (k, 1, n)), n)
fonction("series", r"\sum_{k=1}^{n}k^2", sp.summation(k**2, (k, 1, n)), n)

# Complexes
for latex, v in [
    (r"(1+i)^2", (1 + I) ** 2),
    (r"\overline{1+i}", 1 - I),
    (r"\mathrm{Re}(3+4i)", 3),
    (r"\mathrm{Im}(3+4i)", 4),
    (r"|3+4i|", 5),
    (r"\arg(1+i)", pi / 4),
    (r"e^{i\pi}", -1),
    (r"\frac{1}{1+i}", 1 / (1 + I)),
]:
    valeur("complexes", latex, v)

# Matrices
A = Matrix([[1, 2], [3, 4]])
TEX = r"\begin{pmatrix}1&2\\3&4\end{pmatrix}"
valeur("matrices", r"\det" + TEX, A.det())
valeur("matrices", r"\begin{vmatrix}1&2\\3&4\end{vmatrix}", A.det())
valeur("matrices", r"\left|" + TEX + r"\right|", A.det())
matrice("matrices", TEX + r"^{-1}", list(A.inv()))
matrice("matrices", TEX + r"^T", list(A.T))
matrice("matrices", TEX + r"^2", list(A**2))
matrice("matrices", TEX + r"\begin{pmatrix}0&1\\1&0\end{pmatrix}", list(A * Matrix([[0, 1], [1, 0]])))
matrice("matrices", TEX + r"+\begin{pmatrix}1&0\\0&1\end{pmatrix}", list(A + sp.eye(2)))

# Équations et systèmes
for latex, f in [
    (r"2x+1=5", 2 * x + 1 - 5),
    (r"x^2=2", x**2 - 2),
    (r"x^2-5x+6=0", x**2 - 5 * x + 6),
    (r"x^3-x=0", x**3 - x),
    (r"x^4-5x^2+4=0", x**4 - 5 * x**2 + 4),
    (r"e^{x}=2", sp.exp(x) - 2),
    (r"\ln(x)=1", sp.log(x) - 1),
    (r"\sqrt{x}=2", sqrt(x) - 2),
    (r"\frac{1}{x}=4", 1 / x - 4),
    (r"x^2+1=0", x**2 + 1),
]:
    solutions("equations", latex, sp.solveset(f, x, sp.S.Reals))
solutions("equations", r"|x|=3", [-3, 3])
matrice("systemes", r"\begin{cases}x+y=1\\x-y=3\end{cases}", [2, -1])
matrice("systemes", r"\begin{cases}x+y+z=6\\x-y=1\\z=1\end{cases}", [3, 2, 1])
matrice("systemes", r"\begin{cases}2x+3y=7\\x-y=1\end{cases}", [2, 1])

# La mémoire de la feuille : une définition, puis ce qui s'en sert.
F = x**2 + 1
AVANT = len(cas)
valeur("memoire", "f(2)", F.subs(x, 2))
fonction("memoire", "f'(x)", sp.diff(F, x))
valeur("memoire", "f'(3)", sp.diff(F, x).subs(x, 3))
valeur("memoire", "f''(3)", sp.diff(F, x, 2).subs(x, 3))
solutions("memoire", "f(x)=5", sp.solveset(F - 5, x, sp.S.Reals))
fonction("memoire", "f(x)+1", F + 1)
for c in cas[AVANT:]:
    c["d"] = "f(x)=x^2+1"

# Vrai ou faux
verite("verite", "2+2=5", False)
verite("verite", r"\frac{1}{2}+\frac{1}{3}=\frac{5}{6}", True)
verite("verite", "2<3", True)
verite("verite", r"3\leq2", False)

# Inéquations, contrôlées par SymPy
for latex, relation in [
    ("x>2", x > 2),
    (r"x^2<4", x**2 < 4),
    (r"2x+1\geq3", 2 * x + 1 >= 3),
    (r"x^2-1\geq0", x**2 - 1 >= 0),
]:
    essais = [-3, -1.5, -0.5, 0.5, 1.5, 3]
    ordre(latex, [p for p in essais if relation.subs(x, p) == True],  # noqa: E712
          [p for p in essais if relation.subs(x, p) != True])  # noqa: E712

print("// Produit par tool/banc/references.py : ne pas modifier à la main.")
print(f"// SymPy {sp.__version__}.")
print("const String referencesJson = r'''")
print(json.dumps(cas, ensure_ascii=False, indent=0))
print("''';")
