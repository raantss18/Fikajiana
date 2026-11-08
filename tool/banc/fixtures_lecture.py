"""Embarque les écritures réelles de app/test/fixtures pour le banc de lecture.

Usage : python3 tool/banc/fixtures_lecture.py > app/banc/fixtures_lecture.dart
"""
import json
import pathlib

racine = pathlib.Path(__file__).resolve().parents[2] / "app" / "test" / "fixtures"
print("// Produit par tool/banc/fixtures_lecture.py : ne pas modifier à la main.")
print("// ignore_for_file: unnecessary_raw_strings")
print()
print("/// Les écritures réelles des tests : `(appareil/nom, traits en JSON)`.")
print("const List<(String, String)> fixturesLecture = [")
for f in sorted(racine.glob("*/*.json")):
    texte = json.dumps(json.loads(f.read_text(encoding="utf-8")), separators=(",", ":"))
    assert "'''" not in texte
    print(f"  ('{f.parent.name}/{f.stem}', r'''{texte}'''),")
print("];")
