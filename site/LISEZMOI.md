# Le site vitrine

Une page, publiée sur GitHub Pages par `.github/workflows/site.yml` (ADR 0063). Ce fichier n'est pas mis en ligne.

## Construire et regarder

```bash
gh api "repos/raantss18/Fikajiana/releases?per_page=30" > /tmp/releases.json
python3 tool/build_site.py --releases /tmp/releases.json --out /tmp/site
python3 -m http.server --directory /tmp/site 8000    # puis http://localhost:8000
python3 -m unittest tool/test_build_site.py
```

`index.html` est un gabarit : `{{VERSION}}`, `{{TAILLE}}`, `{{SHA256}}`, `{{APK_URL}}`, `{{VERSIONS}}`… sont remplis par
`tool/build_site.py`. Les passages `<!-- SI … -->…<!-- SINON -->…<!-- FIN -->` sont gardés ou retirés (voir l'en-tête du script).

## Ce qu'Antsa dépose (rien d'autre à modifier)

| Fichier | Rôle | Sans lui |
|---|---|---|
| `site/video/demo.mp4` | la vidéo de démonstration, en tête de page (16:9 conseillé, H.264) | pas de vidéo : la feuille dessinée prend sa place |
| `site/chapitres.json` | les passages de la vidéo : `[{"t": 0, "titre": "Écrire un calcul"}, …]`, `t` en secondes (modèle : `chapitres.exemple.json`) | pas de vidéo, même si `demo.mp4` est là |
| `site/video/demo-affiche.jpg` | l'image montrée avant la lecture | la première image de la vidéo |
| `site/video/demo.fr.vtt` | les sous-titres français (WebVTT) | pas de sous-titres |
| `site/img/capture-feuille.png` | capture de la Feuille, section « Écrire comme sur papier » | rien : le dessin suffit |
| `site/img/capture-graphe.png` | capture d'une courbe, section « Courbes et géométrie » | rien |
| `site/img/capture-figure.png` | capture d'une construction, même section | rien |

Les captures sont de vraies captures de l'application (règle 7 de `CLAUDE.md`), 1 200 px de large au plus. Si une capture
montre autre chose que ce que dit son texte de remplacement (`alt` dans `index.html`), corriger ce texte.

## La pastille « Dans la prochaine version »

Ce qui est fusionné mais pas encore publié porte `<!-- SI bientot:1.1.3 -->` : la pastille disparaît toute seule dès qu'une
version plus récente que 1.1.3 est publiée. Pour annoncer une autre fonction à venir, mettre le numéro de la dernière
version publiée ce jour-là.

## Polices

`fonts/nunito.woff` (graisses 400 à 900) et `fonts/caveat.woff` (graisse 500) sont des sous-ensembles (latin, signes de
maths) faits avec `pyftsubset` (fontTools) à partir de `app/assets/polices/Nunito.ttf` et du `Caveat[wght].ttf` de
<https://github.com/google/fonts/tree/main/ofl/caveat>. Licences : `fonts/OFL-Nunito.txt`, `fonts/OFL-Caveat.txt`
(SIL OFL 1.1, sans nom réservé). Caveat n'a ni √, ni ∫, ni Δ : ces signes sont dessinés en SVG dans la page.

## Couleurs

Celles de l'application (`app/lib/ui/theme/couleurs.dart`, `docs/design.md`) : papier, encre, stylo bleu, résultats ;
en sombre, le tableau noir et ses craies. `tool/test_build_site.py` recalcule les contrastes (WCAG 2.2 AA).
