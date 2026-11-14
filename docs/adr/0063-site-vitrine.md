# ADR 0063 — Un site vitrine sur GitHub Pages, en feuille à petits carreaux

- **Date** : 2026-11-14 · **Statut** : accepté, pas encore en ligne (Antsa : « un site GitHub, dans l'esprit de celui de Zanak'i Antsa » ; elle active Pages elle-même).
- **Décision** : une page (`site/`). `tool/build_site.py` (Python seul) y écrit la dernière version (numéro, date, taille, SHA-256, lien du fichier) et les trois dernières
  nouveautés, depuis l'API des versions (https://docs.github.com/en/rest/releases/releases). `.github/workflows/site.yml` teste, construit et publie par GitHub Actions
  (https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), à chaque version publiée ; actions épinglées par SHA.
- **Promesse tenue** : aucune requête vers un autre site, aucun cookie, polices Nunito et Caveat servies sur place (SIL OFL 1.1, `site/fonts/`) ; un test l'exige.
- **Rien d'inventé** : chaque fonction citée est au Guide (`app/lib/guide/catalogue.dart`) ; ce qui n'est pas publié porte « Dans la prochaine version », retirée seule
  après la 1.1.3. Dit sans détour : lecture encore fautive (37 sur 50, `docs/recherche/spike-ocr.md`), modèle à part (ADR 0016), usages du réseau (ADR 0015, 0042).
- **Design** : cahier à petits carreaux, encre bleue `#0B3D91`, réponses dans la couleur des résultats ; sombre = tableau noir et craies (`docs/design.md`). Maths en
  Caveat ; √, ∫ et Δ, absents de la police, dessinés en SVG. Captures facultatives, jamais inventées (`site/LISEZMOI.md`). Vidéo : `site/video/demo.mp4` et
  `site/chapitres.json` à fournir ; sans eux, une feuille dessinée prend la place (les deux cas sont testés).
- **Vérifié** : 19 tests (`python3 -m unittest tool/test_build_site.py`) : champs, liens internes, rien de distant, contrastes clair et sombre ≥ 4,5:1
  (https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio) ; page construite avec les 28 vraies versions, vue à 375 et 1360 px, claire et sombre, sans défilement horizontal.
- **Reste à tester** : en ligne après activation de Pages ; lecteur d'écran ; Firefox et Safari ; le saut de chapitre avec la vraie vidéo ; un vrai téléphone.
