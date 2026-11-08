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

# Feuille d'Antsa, 15 h 14 : équations différentielles (constante C0) et suite.
yf = sp.Function("y")
t = sp.symbols("t")
p = "feuille d’Antsa, 15 h 14"
note(p, r"y ^ { 1 } - 3 y = \cos \left( x \right)", sp.dsolve(yf(x).diff(x) - 3 * yf(x) - sp.cos(x)).rhs)
note(p, "y'+y=0", sp.dsolve(yf(x).diff(x) + yf(x)).rhs)
note(p, "y'=2y", sp.dsolve(yf(x).diff(x) - 2 * yf(x)).rhs)
note(p, "y'(t)=t", sp.dsolve(yf(t).diff(t) - t).rhs)
note(p, "y''+y=0", sp.dsolve(yf(x).diff(x, 2) + yf(x)).rhs)
note(p, "y''+4y=x", sp.dsolve(yf(x).diff(x, 2) + 4 * yf(x) - x).rhs)
note(p, r"y''+y=\cos(x)", sp.dsolve(yf(x).diff(x, 2) + yf(x) - sp.cos(x)).rhs)
note(p, "y''-3y'+2y=e^{x}", sp.dsolve(yf(x).diff(x, 2) - 3 * yf(x).diff(x) + 2 * yf(x) - sp.exp(x)).rhs)
u4 = 2
for _ in range(4):
    u4 = 3 * u4 - 1
note(p, "u_{4}=", u4)
note(p, r"\text{résoudre}(x^{2}-4=0)", solve(x**2 - 4, x))

# Vague 1 : lois de probabilité, par sympy.stats (indépendant du lecteur de l'app).
from sympy import stats as st  # noqa: E402


def nombre(probleme, ligne, valeur):
    ref[f"{probleme} | {ligne}"] = float(sp.N(valeur, 15))


def plus_petit(loi, alpha, debut=0):
    """Le plus petit entier k tel que P(loi <= k) >= alpha."""
    k = debut
    while float(sp.N(st.P(loi <= k))) < alpha:
        k += 1
    return k


p = "lois de probabilité"
X = st.Binomial("X", 10, R(3, 10))
nombre(p, "P(X=3)=", st.P(sp.Eq(X, 3)))
nombre(p, r"P(X\le3)=", st.P(X <= 3))
nombre(p, r"P(2\le X<5)=", st.P(sp.And(X >= 2, X < 5)))
nombre(p, "P(X>8)=", st.P(X > 8))
nombre(p, "E(X)=", st.E(X))
nombre(p, "V(X)=", st.variance(X))
nombre(p, r"\sigma(X)=", st.std(X))
nombre(p, r"P(X\le k)\ge0{,}95", plus_petit(X, 0.95))
Z = st.Poisson("Z", 3)
nombre(p, "P(Z=0)=", st.P(sp.Eq(Z, 0)))
nombre(p, r"P(Z\ge2)=", 1 - st.P(Z <= 1))
nombre(p, r"P(Z\le k)\ge0{,}9", plus_petit(Z, 0.9))
T = st.Geometric("T", R(1, 5))  # sympy : support 1, 2, 3… (premier succès)
nombre(p, r"P(T\le3)=", st.P(T <= 3))
nombre(p, "E(T)=", st.E(T))
nombre(p, r"P(T\le k)\ge0{,}5", plus_petit(T, 0.5, debut=1))
Y = st.Normal("Y", 100, 15)  # écart type 15, variance 15²
nombre(p, r"P(Y\le115)=", st.cdf(Y)(115))
nombre(p, r"P(85\le Y\le115)=", st.cdf(Y)(115) - st.cdf(Y)(85))
nombre(p, "P(Y>130)=", 1 - st.cdf(Y)(130))
tt = sp.symbols("tt")
nombre(p, r"P(Y\le t)=0{,}975", sp.nsolve(st.cdf(Y)(tt) - R(975, 1000), tt, 130))
nombre(p, r"P(Y\ge t)=0{,}05", sp.nsolve(st.cdf(Y)(tt) - R(95, 100), tt, 125))
D = st.Exponential("D", R(1, 2))
nombre(p, r"P(D\le2)=", st.cdf(D)(2))
nombre(p, "V(D)=", st.variance(D))
nombre(p, r"P(D\le t)=0{,}5", sp.solve(sp.Eq(st.cdf(D)(tt), R(1, 2)), tt)[0])
U = st.Uniform("U", 0, 10)
nombre(p, r"P(2\le U\le5)=", st.cdf(U)(5) - st.cdf(U)(2))
nombre(p, r"P(U\le t)=0{,}3", 3)

# Vague 2 : arithmétique (SymPy et Python, sans le lecteur de l'app).
p = "arithmétique"
q, r = divmod(17, 5)  # Python : reste toujours >= 0 pour un diviseur > 0
ref[f"{p} | \\text{{division}}(17;5)"] = [q, r]
q, r = divmod(-17, 5)
ref[f"{p} | \\text{{division}}(-17;5)"] = [q, r]
ref[f"{p} | \\text{{quotient}}(47;6)="] = 47 // 6
ref[f"{p} | \\text{{reste}}(47;6)="] = 47 % 6
ref[f"{p} | \\text{{reste}}(-17;5)="] = -17 % 5
for a, b in [(12, 18), (240, 46)]:
    u, v, d = sp.gcdex(a, b)
    assert a * u + b * v == d
    ref[f"{p} | \\text{{bezout}}({a};{b})"] = [int(d)]
ref[f"{p} | 17\\equiv2[5]"] = (17 - 2) % 5 == 0
ref[f"{p} | 17\\equiv3[5]"] = (17 - 3) % 5 == 0
ref[f"{p} | 2^{{10}}\\equiv1\\pmod{{11}}"] = (2**10 - 1) % 11 == 0
ref[f"{p} | A_{{5}}^{{2}}="] = int(sp.ff(5, 2))
ref[f"{p} | \\binom{{10}}{{3}}="] = int(sp.binomial(10, 3))
ref[f"{p} | 6!="] = int(sp.factorial(6))

print(json.dumps(ref, ensure_ascii=False, indent=1))
