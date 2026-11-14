#!/usr/bin/env python3
"""Construit le site vitrine (dossier site/) dans un dossier de sortie, prêt pour GitHub Pages (ADR 0063).

Le site est du HTML statique. Ce script y écrit ce qui change à chaque version, à partir de la liste des versions
publiées sur GitHub (JSON de `gh api repos/<dépôt>/releases`) : numéro, date, taille, empreinte SHA-256, lien du fichier,
nouveautés des dernières versions. Il garde ou retire les passages conditionnels du gabarit :

    <!-- SI video -->…<!-- SINON -->…<!-- FIN -->        la vidéo et ses chapitres existent (site/video/demo.mp4, site/chapitres.json)
    <!-- SI fichier:img/capture.png -->…<!-- FIN -->     ce fichier existe dans site/
    <!-- SI bientot:1.1.3 -->…<!-- FIN -->               la dernière version publiée est 1.1.3 ou plus ancienne

Aucune bibliothèque : Python 3 seulement.

Usage : python3 tool/build_site.py --releases releases.json --out _site
"""
import argparse
import hashlib
import html
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
SITE = RACINE / 'site'
DEPOT = 'https://github.com/raantss18/Fikajiana'
APK_STABLE = 'fikajiana-arm64-v8a.apk'
MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre',
        'décembre']
# Ce qui ne part pas en ligne : les modes d'emploi et les exemples.
HORS_SITE = shutil.ignore_patterns('LISEZMOI.md', 'chapitres.json', 'chapitres.exemple.json')


def date_fr(iso: str) -> str:
    d = datetime.fromisoformat(iso.replace('Z', '+00:00'))
    return f"{d.day}{'er' if d.day == 1 else ''} {MOIS[d.month - 1]} {d.year}"


def taille_fr(octets: int) -> str:
    return f"{octets / 1e6:.1f}".replace('.', ',') + ' Mo'


def e(texte: str) -> str:
    return html.escape(texte, quote=True)


def numero(version: str):
    """« 1.10.2 » → (1, 10, 2), pour comparer deux versions."""
    return tuple(int(n) for n in re.findall(r'\d+', version))


def nouveautes_fr(corps: str):
    """Le message et la liste de la section « Nouveautés » d'une note de version (écrite par tool/notes_release.py).

    Rend (message, [lignes]). Une note d'un autre format (les premières versions) rend ('', []).
    """
    m = re.search(r'^##[^\n]*Nouveautés[^\n]*\n(.*?)(?=^## |\Z)', corps or '', re.M | re.S)
    if not m:
        return '', []
    message, lignes = [], []
    for ligne in m[1].splitlines():
        ligne = ligne.strip()
        if ligne.startswith('- '):
            lignes.append(ligne[2:].strip())
        elif ligne and not lignes:
            message.append(ligne)
    message = ' '.join(message)
    # Une seule nouveauté : la liste répète le message.
    if lignes == [message]:
        lignes = []
    return message, lignes


def versions(releases):
    """Les versions publiées qui ont un fichier .apk, la plus récente d'abord."""
    out = []
    for r in releases:
        apks = [a for a in r.get('assets', []) if a['name'].endswith('.apk')]
        if r.get('draft') or r.get('prerelease') or not apks:
            continue
        stable = next((a for a in apks if a['name'] == APK_STABLE), None)
        apk = stable or apks[0]
        message, lignes = nouveautes_fr(r.get('body') or '')
        out.append({
            'version': r['tag_name'].removeprefix('app-v'),
            'date': r['published_at'],
            'url': r['html_url'],
            'apk': apk['browser_download_url'],
            'stable': stable is not None,
            'taille': apk['size'],
            'sha256': (apk.get('digest') or '').removeprefix('sha256:'),
            'message': message,
            'lignes': lignes,
        })
    out.sort(key=lambda v: numero(v['version']), reverse=True)
    return out


def html_versions(vs, combien=3):
    blocs = []
    for v in vs[:combien]:
        corps = f"<p>{e(v['message'])}</p>" if v['message'] else ''
        if v['lignes']:
            corps += '<ul>' + ''.join(f"<li>{e(ligne)}</li>" for ligne in v['lignes']) + '</ul>'
        blocs.append(
            f"<article class=\"version\"><h3>Version {e(v['version'])}</h3>"
            f"<time datetime=\"{e(v['date'][:10])}\">{date_fr(v['date'])}</time>{corps}"
            f"<p><a href=\"{e(v['url'])}\">Notes de la version {e(v['version'])} sur GitHub</a></p></article>")
    blocs.append(f'<p class="toutes"><a href="{DEPOT}/releases">Toutes les versions</a></p>')
    return '\n    '.join(blocs)


def duree_fr(secondes: float) -> str:
    s = int(secondes)
    return f"{s // 60} min {s % 60:02d}" if s >= 60 else f"{s} s"


def lire_chapitres(site: Path):
    """Les chapitres de la vidéo : [{"t": secondes, "titre": "…"}], ou None si la vidéo ou la liste manque."""
    fichier = site / 'chapitres.json'
    if not (site / 'video' / 'demo.mp4').is_file() or not fichier.is_file():
        return None
    chapitres = json.loads(fichier.read_text(encoding='utf-8'))
    if not chapitres:
        return None
    for c in chapitres:
        if not isinstance(c.get('t'), (int, float)) or c['t'] < 0 or not str(c.get('titre', '')).strip():
            raise SystemExit(f'chapitres.json : il faut « t » (secondes, positif) et « titre » dans {c!r}')
    return sorted(chapitres, key=lambda c: c['t'])


def html_chapitres(chapitres):
    return '\n      '.join(
        f"<li><button type=\"button\" data-t=\"{c['t']:g}\">{e(c['titre'].strip())}"
        f"<span class=\"temps\"> ({duree_fr(c['t'])})</span></button></li>" for c in chapitres)


BLOC = re.compile(r'[ \t]*<!-- SI ([^ ]+) -->(.*?)(?:<!-- SINON -->(.*?))?<!-- FIN -->\n?', re.S)


def conditions(page: str, vrai) -> str:
    """Garde le passage « SI » quand `vrai(condition)`, sinon le passage « SINON » (ou rien)."""
    return BLOC.sub(lambda m: m[2] if vrai(m[1]) else (m[3] or ''), page)


def construire(releases, site: Path, out: Path, maintenant: datetime):
    vs = versions(releases)
    if not vs:
        raise SystemExit('Aucune version avec un fichier .apk : rien à proposer au téléchargement.')
    dernier = vs[0]
    chapitres = lire_chapitres(site)

    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(site, out, ignore=HORS_SITE)

    def vrai(condition: str) -> bool:
        if condition == 'video':
            return chapitres is not None
        sorte, _, valeur = condition.partition(':')
        if sorte == 'fichier':
            return (site / valeur).is_file()
        if sorte == 'bientot':
            return numero(dernier['version']) <= numero(valeur)
        raise SystemExit(f'Condition inconnue dans le gabarit : {condition}')

    affiche = ' poster="video/demo-affiche.jpg"' if (site / 'video' / 'demo-affiche.jpg').is_file() else ''
    piste = ''
    if (site / 'video' / 'demo.fr.vtt').is_file():
        piste = '\n        <track kind="subtitles" src="video/demo.fr.vtt" srclang="fr" label="Français" default>'
    valeurs = {
        'VERSION': e(dernier['version']), 'VERSION_DATE': date_fr(dernier['date']),
        'TAILLE': taille_fr(dernier['taille']),
        # Le nom stable suit toujours la dernière version ; à défaut, le fichier de cette version.
        'APK_URL': f'{DEPOT}/releases/latest/download/{APK_STABLE}' if dernier['stable'] else e(dernier['apk']),
        'SHA256': e(dernier['sha256'] or 'non fournie'), 'RELEASE_URL': e(dernier['url']),
        'VERSIONS': html_versions(vs), 'CHAPITRES': html_chapitres(chapitres or []),
        'AFFICHE': affiche, 'PISTE': piste, 'CONSTRUIT': date_fr(maintenant.isoformat()),
    }
    page = conditions((site / 'index.html').read_text(encoding='utf-8'), vrai)
    for cle, val in valeurs.items():
        page = page.replace('{{' + cle + '}}', val)
    # Chaque version du style et du script a son adresse : un navigateur ne garde pas l'ancien style avec la nouvelle page.
    for f in ['style.css', 'app.js']:
        h = hashlib.sha256((site / f).read_bytes()).hexdigest()[:10]
        page = page.replace(f'"{f}"', f'"{f}?v={h}"')
    if '{{' in page or '<!-- SI' in page or '<!-- FIN' in page or '<!-- SINON' in page:
        reste = re.search(r'\{\{|<!-- (SI|FIN|SINON)', page)
        raise SystemExit("Le gabarit garde un champ sans valeur : " + page[reste.start():][:60])
    (out / 'index.html').write_text(page, encoding='utf-8')
    (out / '.nojekyll').write_text('', encoding='utf-8')
    return dernier, vs, chapitres


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--releases', required=True, help='JSON de `gh api repos/<dépôt>/releases`')
    ap.add_argument('--out', required=True, help='dossier de sortie (effacé puis recréé)')
    ap.add_argument('--site', default=str(SITE), help='dossier du gabarit (site/)')
    a = ap.parse_args()
    releases = json.loads(Path(a.releases).read_text(encoding='utf-8'))
    dernier, vs, chapitres = construire(releases, Path(a.site), Path(a.out), datetime.now(timezone.utc))
    video = f"vidéo avec {len(chapitres)} chapitre(s)" if chapitres else "sans vidéo (illustration à la place)"
    print(f"Site construit dans {a.out} : version {dernier['version']}, {len(vs)} version(s), {video}.")


if __name__ == '__main__':
    main()
