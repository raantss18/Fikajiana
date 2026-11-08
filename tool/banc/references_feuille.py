#!/usr/bin/env python3
"""Valeurs attendues du banc de la feuille (app/banc/banc_feuille.dart), par SymPy.

Chaque ligne d'un problème est recalculée ici, sans le lecteur LaTeX de l'app
(règle 8). Usage : python3 tool/banc/references_feuille.py
Sortie : JSON {"problème | ligne": valeur attendue en texte SymPy}.
"""
import json

import sympy as sp
from sympy import E, Matrix, Rational as R, exp, integrate, limit, ln, oo, solve, summation

x, n, k = sp.symbols("x n k")
ref = {}


def note(probleme, ligne, valeur):
    ref[f"{probleme} | {ligne}"] = str(sp.simplify(valeur)) if not isinstance(valeur, (list, set)) else str(valeur)


# Matrices 2×2
A = Matrix([[2, 1], [1, 3]])
B = Matrix([[1, -1], [0, 2]])
p = "matrices 2×2"
note(p, "AB=", A * B)
note(p, "BA=", B * A)
note(p, r"\det(A)=", A.det())
note(p, "A^{-1}=", A.inv())
note(p, "AX=B", A.inv() * B)
note(p, "A^{2}-5A=", A**2 - 5 * A)
note(p, r"\det(AB)=", (A * B).det())

# Matrices 3×3
C = Matrix([[1, 2, 0], [0, 1, 3], [2, 0, 1]])
D = Matrix([1, 2, 3])
p = "matrices 3×3"
note(p, r"\det(C)=", C.det())
note(p, "C^{-1}=", C.inv())
note(p, "C^{2}=", C**2)
note(p, "CD=", C * D)
note(p, "CX=D", C.inv() * D)

# Suites
u = 2 * n + 3
p = "suite arithmétique"
note(p, "u_{10}=", u.subs(n, 10))
note(p, r"\sum_{n=0}^{10}u_{n}=", summation(u, (n, 0, 10)))
note(p, r"\lim_{n\to+\infty}\frac{u_{n}}{n}=", limit(u / n, n, oo))
v = 3 * 2**n
p = "suite géométrique"
note(p, "v_{5}=", v.subs(n, 5))
note(p, r"\sum_{k=0}^{5}3\times2^{k}=", summation(3 * 2**k, (k, 0, 5)))
note(p, r"\lim_{n\to+\infty}\frac{2n+1}{n+3}=", limit((2 * n + 1) / (n + 3), n, oo))
w = 2
for _ in range(3):
    w = 3 * w - 4
note("suite récurrente", "w_{3}=", w)

# Fonctions
f = x**3 - 3 * x**2 + 2
p = "fonction polynôme"
note(p, "f'(x)=", sp.diff(f, x))
note(p, "f'(x)=0", solve(sp.diff(f, x), x))
note(p, "f(2)=", f.subs(x, 2))
note(p, "f(0)=", f.subs(x, 0))
note(p, r"\int_{0}^{2}f(x)dx=", integrate(f, (x, 0, 2)))
note(p, r"\lim_{x\to+\infty}f(x)=", limit(f, x, oo))
note(p, "f(x)=0", solve(f, x))
note(p, "g'(1)=", sp.diff(f + x, x).subs(x, 1))
h = x * exp(-x)
p = "fonction exponentielle"
note(p, "h'(x)=", sp.diff(h, x))
note(p, "h'(x)=0", solve(sp.diff(h, x), x))
note(p, "h(1)=", h.subs(x, 1))
note(p, r"\lim_{x\to+\infty}h(x)=", limit(h, x, oo))
note(p, r"\int_{0}^{1}h(x)dx=", integrate(h, (x, 0, 1)))
kk = ln(x) - x
p = "fonction logarithme"
note(p, "k'(x)=", sp.diff(kk, x))
note(p, "k'(x)=0", solve(sp.diff(kk, x), x))
note(p, "k(1)=", kk.subs(x, 1))
note(p, r"\lim_{x\to0^{+}}k(x)=", limit(kk, x, 0, "+"))

print(json.dumps(ref, ensure_ascii=False, indent=1))
