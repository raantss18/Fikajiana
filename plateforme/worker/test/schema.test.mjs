import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { CLASSES_TXT } from "../src/classes.js";
import { DonInvalide, analyserJson, lireClasses, verifierSeance } from "../src/schema.js";

const CLASSES = lireClasses(CLASSES_TXT);
const CAS = JSON.parse(readFileSync(new URL("../../tests/cas_schema.json", import.meta.url), "utf-8"));

function verdict(texte) {
  try {
    return [true, verifierSeance(analyserJson(new TextEncoder().encode(texte)), CLASSES)];
  } catch (e) {
    if (e instanceof DonInvalide) return [false, null];
    throw e;
  }
}

test("classes.js recopie exactement collecte/classes.txt", () => {
  const source = readFileSync(new URL("../../../collecte/classes.txt", import.meta.url), "utf-8");
  assert.equal(CLASSES_TXT, source, "lancer : npm run classes");
  assert.equal(CLASSES.get("plus"), "+");
  assert.equal(CLASSES.get("racine"), "\\sqrt");
});

test("même verdict que schema.py sur les cas communs", () => {
  assert.ok(CAS.length > 40);
  for (const c of CAS) {
    if (c.python_seulement) continue;
    const [valide, recu] = verdict(c.texte);
    assert.equal(valide, c.valide, c.nom);
    if (valide) assert.equal(recu, c.recu, c.nom);
  }
});

test("écarts connus avec Python : acceptés, mais réécrits proprement", () => {
  for (const c of CAS.filter((x) => x.python_seulement)) {
    const [valide] = verdict(c.texte);
    assert.equal(valide, true, c.nom);
  }
});

test("plus de 150 000 points refusés", () => {
  const seance = JSON.parse(CAS.find((c) => c.nom === "valide").texte);
  const e = { type: "expression", attendu: "x", traits: Array(40).fill(Array(4000).fill([0, 0, 0, 0])) };
  seance.echantillons = [e];
  assert.throws(() => verifierSeance(seance, CLASSES), /150000 points/);
});

test("UTF-8 invalide refusé", () => {
  assert.throws(() => analyserJson(new Uint8Array([0xff, 0xfe])), /UTF-8/);
});
