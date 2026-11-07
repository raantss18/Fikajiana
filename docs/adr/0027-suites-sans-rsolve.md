# ADR 0027 — Suites : une formule, pas `rsolve`

- **Date** : 2026-11-07 · **Statut** : accepté, à refaire sur un appareil arm64 réel
- **Constat** : sur l'émulateur, `rsolve(u(n+2)=3*u(n+1)-2*u(n),u(n),[u(0)=0,u(1)=1])` n'a pas rendu la main en plus de 60 s, malgré l'arrêt à 15 s de `MoteurGiac`. Dans l'app, le calcul resterait figé. Le fonctionnement interne de cet arrêt n'a pas été étudié : non vérifié.
- **Décision** : pas de `rsolve`. Une suite `u_{n+1}=a·u_n+b`, ou `u_n=a·u_{n-1}+b`, s'écrit par sa formule : `u_p+b·(n-p)` si a=1, sinon `aⁿ⁻ᵖ·(u_p-b/(1-a))+b/(1-a)`, simplifiée par `normal` de Giac.
- **Contrôle** : la forme `a·w+b`, sans le rang, est vérifiée à l'évaluation. Sinon, l'écriture est refusée.
- **Refusé pour l'instant** : ordre 2 (Fibonacci), `u_{n+1}=u_n^2`, `u_{n+1}=u_n+n`, un paramètre `a`, deux premiers termes.
- **Banc** : `tool/banc/lancer.sh` signale un cas qui ne rend pas la main. 9 suites comparées à `sympy.rsolve`.
- **Source** : SymPy 1.14, `rsolve` (https://docs.sympy.org/latest/modules/solvers/solvers.html). La formule est le résultat classique sur les suites arithmético-géométriques, recoupé ici par SymPy.
