import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { beforeEach, test } from "node:test";

import worker, { BUDGET_EXPORT, dateDeCle, horodatage } from "../src/index.js";

const CAS = JSON.parse(readFileSync(new URL("../../tests/cas_schema.json", import.meta.url), "utf-8"));
const SEANCE = JSON.parse(CAS.find((c) => c.nom === "valide").texte);
const C = SEANCE.contributeur;
const JETON = "j".repeat(40);

/** R2 en mémoire, avec les appels utilisés par le Worker, et le compte des sous-requêtes. */
class FauxR2 {
  constructor() {
    this.objets = new Map();
    this.appels = 0;
  }
  async head(cle) {
    this.appels++;
    return this.objets.has(cle) ? { key: cle } : null;
  }
  async put(cle, corps) {
    this.appels++;
    this.objets.set(cle, { texte: String(corps), uploaded: new Date() });
  }
  async get(cle) {
    this.appels++;
    const o = this.objets.get(cle);
    return o ? { text: async () => o.texte } : null;
  }
  async delete(cles) {
    this.appels++;
    for (const c of [].concat(cles)) this.objets.delete(c);
  }
  async list({ prefix = "", cursor, startAfter, limit = 1000 }) {
    this.appels++;
    let cles = [...this.objets.keys()].filter((k) => k.startsWith(prefix)).sort();
    if (startAfter) cles = cles.filter((k) => k > startAfter);
    const debut = Number(cursor || 0);
    const page = cles.slice(debut, debut + Math.min(limit, 7)); // pages courtes pour tester la suite
    const fin = debut + page.length;
    return {
      objects: page.map((k) => ({ key: k, size: this.objets.get(k).texte.length, uploaded: this.objets.get(k).uploaded })),
      truncated: fin < cles.length,
      cursor: String(fin),
    };
  }
}

class FauxLimiteur {
  constructor(permis) {
    this.permis = permis;
    this.vus = new Map();
  }
  async limit({ key }) {
    const n = (this.vus.get(key) || 0) + 1;
    this.vus.set(key, n);
    return { success: n <= this.permis };
  }
}

let env;
beforeEach(() => {
  env = { DONS: new FauxR2(), LIMITEUR: new FauxLimiteur(1000), FIKA_JETON_ADMIN: JETON };
});

function appel(methode, chemin, { corps, ip = "203.0.113.7", entetes = {}, type = "application/json" } = {}) {
  const init = { method: methode, headers: { "CF-Connecting-IP": ip, ...entetes } };
  if (corps !== undefined) {
    init.body = typeof corps === "string" || corps instanceof Uint8Array ? corps : JSON.stringify(corps);
    init.headers["Content-Type"] = type;
  }
  return worker.fetch(new Request(`https://dons.exemple${chemin}`, init), env);
}

async function exporter(requete = "", jeton = JETON) {
  const r = await appel("GET", `/v1/export${requete}`, { entetes: jeton ? { Authorization: `Bearer ${jeton}` } : {} });
  return { statut: r.status, lignes: r.status === 200 ? (await r.text()).trim().split("\n").map((l) => JSON.parse(l)) : [] };
}

test("horodatage au format de stockage.py, et relu", () => {
  const d = new Date(Date.UTC(2026, 10, 8, 6, 52, 58, 285));
  assert.equal(horodatage(d), "20261108T065258285000Z");
  assert.equal(dateDeCle(`dons/${C}/20261108T065258285507Z-3e3de13c868f.json`).toISOString(), "2026-11-08T06:52:58.285Z");
});

test("don valide : 201, rangé comme le récepteur Python", async () => {
  const r = await appel("POST", "/v1/dons", { corps: SEANCE });
  assert.equal(r.status, 201);
  assert.deepEqual(await r.json(), { recu: 2 });
  const [cle] = env.DONS.objets.keys();
  assert.match(cle, new RegExp(`^dons/${C}/\\d{8}T\\d{12}Z-[0-9a-f]{12}\\.json$`));
  assert.deepEqual(JSON.parse(env.DONS.objets.get(cle).texte), SEANCE);
  assert.ok(env.DONS.appels <= 2);
});

test("don invalide : 400 sans rien stocker ni recopier le contenu", async () => {
  const r = await appel("POST", "/v1/dons", { corps: { ...SEANCE, auteur: "Antsa" } });
  assert.equal(r.status, 400);
  const texte = await r.text();
  assert.match(texte, /non permis/);
  assert.doesNotMatch(texte, /Antsa/);
  assert.equal(env.DONS.objets.size, 0);
});

test("clé répétée : le JSON stocké est réécrit, sans doublon", async () => {
  const texte = CAS.find((c) => c.nom === "clé répétée").texte;
  assert.equal((await appel("POST", "/v1/dons", { corps: texte })).status, 201);
  const [o] = env.DONS.objets.values();
  assert.equal((o.texte.match(/"licence"/g) || []).length, 1);
});

test("taille limitée, même sans Content-Length", async () => {
  const gros = new Uint8Array(2 * 1024 * 1024 + 10).fill(32);
  assert.equal((await appel("POST", "/v1/dons", { corps: gros })).status, 413);
  const flux = new ReadableStream({
    start(c) {
      for (let i = 0; i < 3; i++) c.enqueue(new Uint8Array(1024 * 1024).fill(32));
      c.close();
    },
  });
  const req = new Request("https://dons.exemple/v1/dons", {
    method: "POST", body: flux, duplex: "half", headers: { "Content-Type": "application/json" },
  });
  assert.equal((await worker.fetch(req, env)).status, 413);
});

test("type et compression refusés", async () => {
  assert.equal((await appel("POST", "/v1/dons", { corps: SEANCE, type: "text/plain" })).status, 415);
  assert.equal((await appel("POST", "/v1/dons", { corps: SEANCE, entetes: { "Content-Encoding": "gzip" } })).status, 415);
});

test("routes et méthodes", async () => {
  assert.equal((await appel("GET", "/v1/dons")).status, 405);
  assert.equal((await appel("GET", "/v1/rien")).status, 404);
  assert.equal((await appel("GET", "/v1/sante")).status, 200);
});

test("débit par IP (CF-Connecting-IP)", async () => {
  env.LIMITEUR = new FauxLimiteur(2);
  assert.equal((await appel("POST", "/v1/dons", { corps: SEANCE })).status, 201);
  assert.equal((await appel("POST", "/v1/dons", { corps: SEANCE })).status, 201);
  const r = await appel("POST", "/v1/dons", { corps: SEANCE });
  assert.equal(r.status, 429);
  assert.ok(Number(r.headers.get("Retry-After")) >= 1);
  assert.equal((await appel("POST", "/v1/dons", { corps: SEANCE, ip: "198.51.100.1" })).status, 201);
});

test("retrait : efface, note, puis refuse l'identifiant (410)", async () => {
  for (let i = 0; i < 9; i++) await appel("POST", "/v1/dons", { corps: SEANCE });
  await appel("POST", "/v1/dons", { corps: { ...SEANCE, contributeur: "z".repeat(16) } });
  const r = await appel("POST", "/v1/retrait", { corps: { contributeur: C } });
  assert.equal(r.status, 202);
  assert.deepEqual(await r.json(), { retire: 9 });
  assert.deepEqual([...env.DONS.objets.keys()].filter((k) => k.includes(C)), [`retraits/${C}.json`]);
  assert.equal((await appel("POST", "/v1/dons", { corps: SEANCE })).status, 410);
  for (const corps of [{ contributeur: "court" }, { contributeur: C, nom: "x" }, {}]) {
    assert.equal((await appel("POST", "/v1/retrait", { corps })).status, 400);
  }
});

test("export : jeton obligatoire, fermé sans jeton configuré", async () => {
  await appel("POST", "/v1/dons", { corps: SEANCE });
  assert.equal((await exporter("", null)).statut, 401);
  assert.equal((await exporter("", "x".repeat(40))).statut, 401);
  const { statut, lignes } = await exporter();
  assert.equal(statut, 200);
  assert.equal(lignes[0].type, "export");
  const dons = lignes.filter((l) => l.type === "don");
  assert.equal(dons.length, 1);
  assert.deepEqual(dons[0].seance, SEANCE);
  assert.equal(dons[0].contributeur, C);
  delete env.FIKA_JETON_ADMIN;
  assert.equal((await exporter()).statut, 404);
});

test("export par pages sous le budget de sous-requêtes, puis complet", async () => {
  const n = 3 * BUDGET_EXPORT;
  for (let i = 0; i < n; i++) {
    const c = `c${String(i).padStart(3, "0")}${"x".repeat(13)}`;
    await env.DONS.put(`dons/${c}/20261108T10000${i % 10}000000Z-${String(i).padStart(12, "0")}.json`, JSON.stringify({ ...SEANCE, contributeur: c }));
  }
  await appel("POST", "/v1/retrait", { corps: { contributeur: "w".repeat(16) } });
  const vus = new Set();
  let apres = "";
  let pages = 0;
  for (;;) {
    env.DONS.appels = 0;
    const { statut, lignes } = await exporter(`?depuis=2026-01-01T00:00:00Z${apres ? `&apres=${encodeURIComponent(apres)}` : ""}`);
    assert.equal(statut, 200);
    assert.ok(env.DONS.appels <= 50, `${env.DONS.appels} sous-requêtes`);
    const retraits = lignes.filter((l) => l.type === "retrait");
    assert.equal(retraits.length, pages === 0 ? 1 : 0);
    for (const l of lignes.filter((x) => x.type === "don")) {
      assert.ok(!vus.has(l.cle), "doublon entre pages");
      vus.add(l.cle);
    }
    pages++;
    const suite = lignes.find((l) => l.type === "suite");
    if (!suite) break;
    apres = suite.apres;
  }
  assert.equal(vus.size, n);
  assert.ok(pages >= 3);
});

test("export depuis une date, et paramètres invalides", async () => {
  await env.DONS.put(`dons/${C}/20260101T000000000000Z-000000000001.json`, JSON.stringify(SEANCE));
  await appel("POST", "/v1/dons", { corps: SEANCE });
  const { lignes } = await exporter("?depuis=2026-06-01T00:00:00Z");
  assert.equal(lignes.filter((l) => l.type === "don").length, 1);
  assert.equal((await exporter("?depuis=hier")).statut, 400);
  assert.equal((await exporter("?apres=../../x")).statut, 400);
});

test("mon-ip : avec jeton seulement", async () => {
  assert.equal((await appel("GET", "/v1/mon-ip")).status, 401);
  const r = await appel("GET", "/v1/mon-ip", { ip: "192.0.2.5", entetes: { Authorization: `Bearer ${JETON}` } });
  assert.deepEqual(await r.json(), { ip: "192.0.2.5" });
});

test("journal : ni IP ni contenu", async () => {
  const lignes = [];
  const origine = console.log;
  console.log = (...a) => lignes.push(a.join(" "));
  try {
    await appel("POST", "/v1/dons", { corps: SEANCE, ip: "203.0.113.99" });
    await appel("POST", "/v1/dons", { corps: { ...SEANCE, auteur: "Antsa" }, ip: "203.0.113.99" });
    await appel("GET", "/v1/Antsa");
  } finally {
    console.log = origine;
  }
  const texte = lignes.join("\n");
  assert.doesNotMatch(texte, /203\.0\.113|Antsa/);
  assert.ok(!texte.includes(C));
  assert.match(texte, /POST \/v1\/dons 201/);
});
