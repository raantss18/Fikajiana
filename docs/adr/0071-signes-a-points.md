# ADR 0071 — Signes faits de points : `!`, `÷`, `:`, `;`

- **Date** : 2026-11-15 · **Statut** : accepté (Antsa : « ça ne voit pas le factoriel, corrige ça et les bugs similaires »)
- **Constat** : `53!=` écrit au stylet sur le Pad 7 rendait `53.1`. La lecture au tracé range les traits de gauche à droite : le
  point du `!`, tracé un peu à gauche de sa hampe, passait avant elle, devenait un point décimal, et la hampe un `1`. Un toucher
  du stylet sous la hampe était oublié (`531`). Même classe : les points tapés d'un `÷` oubliés (`6÷3` lu `6−3`), ceux d'un `:`
  jetés (`6:3` lu `63`), le point d'un `;` oublié et sa virgule prise pour décimale (`A(1;2)` lu `A(1,2)`).
- **Décision** : avant de classer les signes, `_signesAPoints` fond chaque trait avec ses points (petit trait ou toucher) :
  hampe + point dessous → `!` ; plat + point dessus + point dessous → `\div` ; virgule sous la ligne + point dessus → `;` ;
  deux points l'un sur l'autre entre deux signes → `\div` (la division du collège ; le lecteur ne connaît pas `:`).
- **Garde-fous** : un `1` suivi d'un point ou d'une virgule n'est pas un `!` (le `!` s'arrête au-dessus de la ligne, ou son point
  s'en écarte) ; un plat sans ses deux points reste `-` ; un trait court de `=` n'est pas un point. `30;8` ne se calcule pas :
  la ligne va au modèle au lieu d'être lue `30,8`.
- **Vérifié** : tests sur le tracé réel `30×8` du Pad 7 (`trace_ligne_test`), par la CI. **Reste à tester** : au stylet sur le Pad 7.
