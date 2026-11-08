import json

import fabriquer_cas


def test_cas_communs_a_jour():
    """`cas_schema.json` (lu aussi par le Worker) correspond au schéma Python actuel."""
    assert json.loads(fabriquer_cas.CIBLE.read_text(encoding="utf-8")) == fabriquer_cas.fabriquer()


def test_cas_varies():
    cas = fabriquer_cas.fabriquer()
    assert sum(c["valide"] for c in cas) >= 4 and sum(not c["valide"] for c in cas) >= 30
