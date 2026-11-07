# ADR 0036 — Le Guide : un catalogue à chercher et à essayer

- **Date** : 2026-11-07 · **Statut** : accepté (demande d'Antsa : « un tuto interactif pour apprendre les catalogues de commandes, avec une recherche »)
- **Contexte** : les commandes écrites (`pgcd`, `tangente(f;a)`, `A^{-1}`, `C : …`), les outils de la Figure et les gestes ne se découvrent qu'en lisant le code ou les notes de version.
- **Décision** : une entrée « Guide » dans le Menu, entre Historique et Réglages. Le contenu vit dans un seul fichier de données, `app/lib/guide/catalogue.dart`, par familles ; les textes dans les ARB fr/en. Les outils de la Figure reprennent le nom et l'aide de `panneaux.dart`, sans doublon. Chaque exemple est en LaTeX, montré comme écrit à la main.
- **Essayer** : revient à la Feuille et y pose l'exemple, ligne après ligne, par le même chemin que la saisie au clavier (`EssaiGuide` dans `Services`, écouté par la Feuille) ; la dernière ligne fait ce qu'elle ferait au clavier (un point, une construction ou une courbe ouvre la Figure). Pour un outil, la Figure s'ouvre avec cet outil choisi.
- **Recherche** : titres, phrases, mots-clés et exemples, sans accent ni casse ; la requête entière collée (« ecart type » → `écart-type`) ou chacun de ses mots.
- **Vérifié** : `test/guide/catalogue_test.dart` pose chaque exemple sur une `CalculFeuille` (aucun « non compris ») ; `test/ui/guide/` : menu, recherche, Essayer, largeurs 360 et 800, cibles 48 dp, contrastes. **Reste** : essai sur le Pad 7 et le Poco ; les résultats de Giac des exemples ne sont pas vérifiés un à un ici.
