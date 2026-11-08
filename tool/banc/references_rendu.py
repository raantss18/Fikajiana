"""Images et mesures de rendu.py (contrat v1, ADR 0040) pour les signes étiquetés des fixtures.

Usage (depuis entrainement/) : uv run python -I ../tool/banc/references_rendu.py . > ../app/test/fixtures/rendu_signes.json
"""
import json, sys, pathlib
E = pathlib.Path(sys.argv[1]); sys.path.insert(0, str(E))
import rendu, donnees
ids = {l.split('\t')[0] for l in (E.parent / 'collecte/classes.txt').read_text().splitlines() if l and not l.startswith('#')}
sortie = []
etiq = json.loads((E / 'fixtures_signes.json').read_text())
signes = donnees.lire_fixtures(ids)
# retrouver les indices dans l'ordre de lire_fixtures
groupes = [(nom, idx, c) for nom, g in etiq.items() if not nom.startswith('_') for idx, c in g]
assert len(groupes) == len(signes)
for (nom, idx, c), s in zip(groupes, signes):
    assert s.classe == c and s.groupe == nom
    img = rendu.rendre(s.traits, s.case)
    seize = [int(round(v * 16)) for v in img.reshape(-1)]
    assert all(abs(a / 16 - b) < 1e-6 for a, b in zip(seize, img.reshape(-1)))
    sortie.append({'fixture': nom, 'traits': idx, 'classe': c,
                   'case': [round(v, 4) for v in s.case],
                   'image16': ''.join('0123456789abcdefg'[v] for v in seize),
                   'mesures': [round(float(v), 5) for v in rendu.mesurer(s.traits, s.case)]})
print(json.dumps({'_note': "Produit par rendu.py (contrat v1, ADR 0040) sur fixtures_signes.json ; image16 : part d'encre × 16 par pixel, en un caractère (0…g).", 'signes': sortie}, ensure_ascii=False))
