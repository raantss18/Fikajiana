#!/usr/bin/env python3
"""Tests du site vitrine (ADR 0063) : python3 -m unittest tool/test_build_site.py

Le site est construit à partir de tool/site_exemple/releases.json, avec et sans vidéo, puis relu : aucun champ oublié,
liens internes valides, rien de chargé depuis un autre site, contrastes des couleurs (WCAG 2.2 AA).
"""
import json
import re
import shutil
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_site  # noqa: E402

EXEMPLE = Path(__file__).resolve().parent / 'site_exemple' / 'releases.json'
JOUR = datetime(2026, 11, 14, tzinfo=timezone.utc)


def luminance(couleur: str) -> float:
    """Luminance relative : https://www.w3.org/TR/WCAG22/#dfn-relative-luminance"""
    canaux = [int(couleur[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    r, v, b = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in canaux]
    return 0.2126 * r + 0.7152 * v + 0.0722 * b


def contraste(a: str, b: str) -> float:
    """Rapport de contraste : https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio"""
    la, lb = sorted([luminance(a), luminance(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)


class Construction(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        self.releases = json.loads(EXEMPLE.read_text(encoding='utf-8'))

    def construire(self, site=build_site.SITE, releases=None):
        out = self.tmp / 'out'
        build_site.construire(releases or self.releases, site, out, JOUR)
        return out, (out / 'index.html').read_text(encoding='utf-8')

    def site_avec(self, fichiers):
        """Une copie du gabarit, avec des fichiers en plus (la vidéo, les chapitres, une capture)."""
        site = self.tmp / 'site'
        # Sans la vidéo ni les chapitres du dépôt : chaque test pose les siens.
        shutil.copytree(
            build_site.SITE, site,
            ignore=lambda dossier, noms: [n for n in noms if n == 'video' or n == 'chapitres.json'],
        )
        for nom, contenu in fichiers.items():
            (site / nom).parent.mkdir(parents=True, exist_ok=True)
            (site / nom).write_text(contenu, encoding='utf-8')
        return site

    def test_derniere_version(self):
        out, page = self.construire()
        self.assertIn('Version 1.1.3, 72,2 Mo.', page)
        self.assertIn('1.1.3, du 9 novembre 2026', page)
        self.assertIn('3dce7e784e5c54eccbe992162489984046297f4198e0222fdb4418580ab8c361', page)
        self.assertIn('href="https://github.com/raantss18/Fikajiana/releases/latest/download/fikajiana-arm64-v8a.apk"', page)
        self.assertIn('Page construite le 14 novembre 2026', page)
        self.assertTrue((out / '.nojekyll').exists())

    def test_versions_triees_sans_brouillon_ni_version_sans_fichier(self):
        vs = build_site.versions(self.releases)
        self.assertEqual([v['version'] for v in vs], ['1.1.3', '1.0.9', '0.1.0'])
        _, page = self.construire()
        self.assertNotIn('9.9.9', page)
        self.assertNotIn('0.0.1', page)

    def test_nouveautes_lues_dans_la_note(self):
        vs = {v['version']: v for v in build_site.versions(self.releases)}
        self.assertEqual(vs['1.1.3']['message'],
                         'Lois de probabilité et arithmétique, comme sur une calculatrice de lycée.')
        self.assertEqual(vs['1.1.3']['lignes'],
                         ['Lois de probabilité : X ∼ B(10 ; 0,3).', 'Arithmétique : division(17;5).'])
        # Une seule nouveauté : pas de liste qui répète le message.
        self.assertEqual(vs['1.0.9']['lignes'], [])
        # Note d'un ancien format : rien d'inventé, seulement le lien.
        self.assertEqual((vs['0.1.0']['message'], vs['0.1.0']['lignes']), ('', []))
        _, page = self.construire()
        self.assertIn('Une seule nouveauté &lt;écrite&gt; &amp; échappée.', page)
        self.assertNotIn("What's new", page)
        self.assertNotIn('Probability', page)

    def test_sans_empreinte(self):
        _, page = self.construire(releases=[r for r in self.releases if r['tag_name'] == 'app-v0.1.0'])
        self.assertIn('non fournie', page)
        # Pas de fichier au nom stable : le lien va au fichier de cette version.
        self.assertIn('releases/download/app-v0.1.0/fikajiana-0.1.0-arm64-v8a.apk', page)

    def test_aucune_version(self):
        with self.assertRaises(SystemExit):
            self.construire(releases=[r for r in self.releases if not r['assets']])

    def test_sans_video_une_illustration(self):
        _, page = self.construire(self.site_avec({}))
        self.assertNotIn('<video', page)
        self.assertNotIn('class="chapitres"', page)
        self.assertIn('feuille-accueil', page)

    def test_avec_video_et_chapitres(self):
        site = self.site_avec({
            'video/demo.mp4': 'faux', 'video/demo-affiche.jpg': 'faux', 'video/demo.fr.vtt': 'WEBVTT',
            'chapitres.json': '[{"t": 75.5, "titre": "Tracer <une> courbe"}, {"t": 0, "titre": "Écrire"}]',
        })
        out, page = self.construire(site)
        self.assertIn('<source src="video/demo.mp4" type="video/mp4">', page)
        self.assertIn('poster="video/demo-affiche.jpg"', page)
        self.assertIn('<track kind="subtitles" src="video/demo.fr.vtt"', page)
        self.assertNotIn('feuille-accueil', page)
        boutons = re.findall(r'<button type="button" data-t="([^"]+)">([^<]+)<span class="temps"> \(([^)]+)\)', page)
        self.assertEqual(boutons, [('0', 'Écrire', '0 s'), ('75.5', 'Tracer &lt;une&gt; courbe', '1 min 15')])
        self.assertTrue((out / 'video' / 'demo.mp4').exists())
        self.assertFalse((out / 'chapitres.json').exists())

    def test_video_sans_chapitres_ou_chapitres_sans_video(self):
        _, page = self.construire(self.site_avec({'video/demo.mp4': 'faux'}))
        self.assertNotIn('<video', page)
        shutil.rmtree(self.tmp / 'site')
        _, page = self.construire(self.site_avec({'chapitres.json': '[{"t": 0, "titre": "Écrire"}]'}))
        self.assertNotIn('<video', page)

    def test_chapitres_mal_ecrits(self):
        site = self.site_avec({'video/demo.mp4': 'faux', 'chapitres.json': '[{"titre": "sans temps"}]'})
        with self.assertRaises(SystemExit):
            self.construire(site)

    def test_capture_montree_si_elle_existe(self):
        _, page = self.construire()
        self.assertNotIn('img/capture-', page)
        _, page = self.construire(self.site_avec({'img/capture-figure.png': 'faux'}))
        self.assertIn('src="img/capture-figure.png"', page)
        self.assertNotIn('img/capture-feuille.png', page)

    def test_pastille_prochaine_version(self):
        _, page = self.construire()
        self.assertEqual(page.count('Dans la prochaine version'), 5)
        suivante = json.loads(json.dumps(self.releases[2]).replace('1.1.3', '1.1.4'))
        _, page = self.construire(releases=[suivante] + self.releases)
        self.assertNotIn('Dans la prochaine version', page)
        self.assertIn('Vérifier ma copie', page)
        self.assertIn('Nombres complexes', page)

    def test_numero(self):
        self.assertLess(build_site.numero('1.1.9'), build_site.numero('1.2.0'))
        self.assertLess(build_site.numero('1.9.9'), build_site.numero('1.10.0'))

    def test_aucun_champ_oublie_et_liens_valides(self):
        for site in (build_site.SITE, self.site_avec({'video/demo.mp4': 'x', 'chapitres.json': '[{"t": 1, "titre": "a"}]'})):
            out, page = self.construire(site)
            self.assertNotIn('{{', page)
            self.assertNotIn('<!-- SI', page)
            ids = re.findall(r'\sid="([^"]+)"', page)
            self.assertEqual(len(ids), len(set(ids)), 'un identifiant en double')
            for ancre in re.findall(r'href="#([^"]+)"', page):
                self.assertIn(ancre, ids, f'lien interne sans cible : #{ancre}')
            for cible in re.findall(r'aria-labelledby="([^"]+)"', page):
                for un in cible.split():
                    self.assertIn(un, ids, f'aria-labelledby sans cible : {un}')
            for lien in re.findall(r'(?:href|src|poster)="([^"#]+)"', page):
                if lien.startswith(('https://', 'mailto:')) or lien == './':
                    continue
                self.assertTrue((out / lien.split('?')[0]).is_file(), f'fichier manquant : {lien}')
            self.assertFalse((out / 'LISEZMOI.md').exists())
            self.assertFalse((out / 'chapitres.exemple.json').exists())

    def test_rien_charge_depuis_un_autre_site(self):
        out, page = self.construire()
        # Seuls les liens à suivre (<a href>) et les adresses déclarées (og:url) sortent du site.
        charge = re.findall(r'<(?:img|script|source|track|video|iframe|link)\b[^>]*?(?:src|href|poster)="([^"]+)"', page)
        self.assertTrue(charge)
        for adresse in charge:
            self.assertNotRegex(adresse, r'^(https?:)?//', f'ressource distante : {adresse}')
        css = (out / 'style.css').read_text(encoding='utf-8')
        self.assertNotIn('@import', css)
        for adresse in re.findall(r'url\(\s*["\']?([^"\')]+)', css):
            self.assertTrue(adresse.startswith(('fonts/', 'data:image/svg+xml,')), adresse)
        js = (out / 'app.js').read_text(encoding='utf-8')
        for interdit in ('fetch(', 'XMLHttpRequest', 'sendBeacon', 'document.cookie', 'localStorage', 'http'):
            self.assertNotIn(interdit, js)
        self.assertNotIn('<form', page)

    def test_accessibilite_de_base(self):
        _, page = self.construire()
        self.assertIn('<html lang="fr">', page)
        self.assertRegex(page, r'<a class="evitement" href="#contenu">')
        self.assertEqual(page.count('<h1'), 1)
        self.assertEqual(page.count('<main'), 1)
        for img in re.findall(r'<img\b[^>]*>', page):
            self.assertIn('alt="', img)
        css = (build_site.SITE / 'style.css').read_text(encoding='utf-8')
        self.assertIn('prefers-reduced-motion: reduce', css)
        self.assertIn(':focus-visible', css)


class Contrastes(unittest.TestCase):
    """Chaque couple texte/fond du style, en clair et en sombre. Seuils : texte 4,5:1, contour et pictogramme 3:1."""

    TEXTE = [
        ('encre', 'papier'), ('encre', 'feuille'), ('doux', 'papier'), ('doux', 'feuille'),
        ('stylo', 'papier'), ('stylo', 'feuille'), ('resultat', 'papier'), ('resultat', 'feuille'),
        ('action', 'papier'), ('action', 'feuille'), ('sur-action', 'action'),
        ('rouge', 'feuille'), ('vert', 'feuille'), ('sur-pastille', 'pastille'),
    ]
    CONTOUR = [('bord', 'papier'), ('bord', 'feuille'), ('action', 'feuille'), ('rouge', 'papier'), ('encre', 'papier')]

    def setUp(self):
        css = (build_site.SITE / 'style.css').read_text(encoding='utf-8')
        clair, sombre = css.split('@media (prefers-color-scheme: dark)', 1)
        sombre = sombre.split('*, *::before', 1)[0]
        lire = lambda bloc: dict(re.findall(r'--([a-z-]+):\s*(#[0-9A-Fa-f]{6})\b', bloc))
        self.themes = {'clair': lire(clair), 'sombre': lire(sombre)}

    def test_memes_couleurs_dans_les_deux_themes(self):
        self.assertEqual(set(self.themes['clair']), set(self.themes['sombre']))

    def test_textes(self):
        for nom, c in self.themes.items():
            for devant, fond in self.TEXTE:
                with self.subTest(theme=nom, couple=f'{devant}/{fond}'):
                    self.assertGreaterEqual(contraste(c[devant], c[fond]), 4.5)

    def test_contours(self):
        for nom, c in self.themes.items():
            for devant, fond in self.CONTOUR:
                with self.subTest(theme=nom, couple=f'{devant}/{fond}'):
                    self.assertGreaterEqual(contraste(c[devant], c[fond]), 3)

    def test_reference(self):
        # Valeur connue : noir sur blanc vaut 21 (https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio).
        self.assertAlmostEqual(contraste('#000000', '#FFFFFF'), 21, places=6)
        # Valeur de docs/design.md : stylo bleu sur le cahier, 9,95.
        self.assertAlmostEqual(contraste('#0B3D91', '#FFFEFA'), 9.95, places=1)


if __name__ == '__main__':
    unittest.main()
