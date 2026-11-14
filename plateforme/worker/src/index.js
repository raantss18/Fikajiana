// Récepteur des dons d'écriture sur Cloudflare Workers (ADR 0045) : même API et même rangement dans R2
// que le récepteur Python (`plateforme/recepteur.py`, `stockage.py`), pour que
// `entrainement/recuperer_dons.py` lise l'un ou l'autre sans changement.
//
//   POST /v1/dons     une séance → 201 {"recu": n}
//   POST /v1/retrait  {"contributeur": id} → 202 {"retire": n}
//   GET  /v1/export?depuis=<ISO>[&apres=<clé>]  avec « Authorization: Bearer <jeton> » → JSON lines, par pages
//   GET  /v1/sante    → 200 {"ok": true}
//   GET  /v1/mon-ip   avec le jeton → l'adresse comptée pour l'appelant
//
// Liaisons (wrangler.toml) : DONS (seau R2), LIMITEUR (limite de débit, facultative),
// secret FIKA_JETON_ADMIN (≥ 32 caractères ; absent : export fermé).
// Journal : méthode, route connue, statut. Jamais l'IP, jamais le contenu.

import { CLASSES_TXT } from "./classes.js";
import { DonInvalide, RE_CONTRIBUTEUR, TAILLE_MAX, analyserJson, champs, lireClasses, verifierSeance } from "./schema.js";

const CLASSES = lireClasses(CLASSES_TXT);
const ROUTES = new Set(["/v1/dons", "/v1/retrait", "/v1/export", "/v1/sante", "/v1/mon-ip"]);

// Offre gratuite : 50 sous-requêtes par appel, chaque accès à R2 compte. On en garde une marge.
export const BUDGET_EXPORT = 40;
export const OCTETS_EXPORT = 24 * 1024 * 1024;

class Refus extends Error {
  constructor(statut, message, entetes = {}) {
    super(message);
    this.statut = statut;
    this.entetes = entetes;
  }
}

function json(statut, objet, entetes = {}) {
  return new Response(JSON.stringify(objet), {
    status: statut,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      ...entetes,
    },
  });
}

// --- Dates et clés, au même format que stockage.py (« %Y%m%dT%H%M%S%fZ ») ----------------------

const deux = (n) => String(n).padStart(2, "0");

export function horodatage(d) {
  return (
    `${d.getUTCFullYear()}${deux(d.getUTCMonth() + 1)}${deux(d.getUTCDate())}T` +
    `${deux(d.getUTCHours())}${deux(d.getUTCMinutes())}${deux(d.getUTCSeconds())}` +
    `${String(d.getUTCMilliseconds() * 1000).padStart(6, "0")}Z`
  );
}

export function dateDeCle(cle) {
  const m = /(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(\d{6})Z-[0-9a-f]+\.json$/.exec(cle);
  if (!m) return null;
  const [, a, mo, j, h, mi, s, us] = m;
  return new Date(Date.UTC(+a, +mo - 1, +j, +h, +mi, +s, Math.floor(+us / 1000)));
}

function hasard(n) {
  const octets = crypto.getRandomValues(new Uint8Array(n));
  return [...octets].map((o) => o.toString(16).padStart(2, "0")).join("");
}

// --- Lecture du corps, bornée même sans Content-Length ------------------------------------------

async function corpsJson(request, maxi) {
  const type = (request.headers.get("Content-Type") || "").split(";")[0].trim().toLowerCase();
  if (type !== "application/json") throw new Refus(415, "Content-Type: application/json attendu");
  const codage = (request.headers.get("Content-Encoding") || "identity").toLowerCase();
  if (codage !== "identity" && codage !== "") throw new Refus(415, "corps compressé non accepté");
  const annonce = Number(request.headers.get("Content-Length") || "-1");
  if (annonce > maxi) throw new Refus(413, `corps de plus de ${maxi} octets`);
  if (!request.body) throw new Refus(400, "corps vide");
  const morceaux = [];
  let total = 0;
  const lecteur = request.body.getReader();
  for (;;) {
    const { done, value } = await lecteur.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxi) {
      await lecteur.cancel();
      throw new Refus(413, `corps de plus de ${maxi} octets`);
    }
    morceaux.push(value);
  }
  const octets = new Uint8Array(total);
  let pos = 0;
  for (const m of morceaux) {
    octets.set(m, pos);
    pos += m.byteLength;
  }
  try {
    return analyserJson(octets);
  } catch (e) {
    if (e instanceof DonInvalide) throw new Refus(400, e.message);
    throw e;
  }
}

// --- Jeton d'administration, comparé en temps constant ------------------------------------------

function egauxEnTempsConstant(a, b) {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

function refusAdmin(request, env) {
  const jeton = env.FIKA_JETON_ADMIN;
  if (!jeton || jeton.length < 32) return json(404, { erreur: "inconnu" });
  if (!egauxEnTempsConstant(request.headers.get("Authorization") || "", `Bearer ${jeton}`)) {
    return json(401, { erreur: "jeton requis" }, { "WWW-Authenticate": "Bearer" });
  }
  return null;
}

// --- Routes ---------------------------------------------------------------------------------------

/** Séances acceptées par identifiant et par jour (UTC) ; l'app en envoie quelques-unes. */
export const DONS_PAR_JOUR = 200;

/** Compte les clés sous `prefixe`, sans dépasser `plafond`. */
async function compter(env, prefixe, plafond) {
  let n = 0;
  let curseur;
  do {
    const page = await env.DONS.list({ prefix: prefixe, cursor: curseur, limit: Math.min(1000, plafond - n) });
    n += page.objects.length;
    curseur = page.truncated && n < plafond ? page.cursor : undefined;
  } while (curseur);
  return n;
}

/** La clé du limiteur : l'adresse en IPv4, le préfixe /64 en IPv6 (un abonné en a une infinité). */
export function cleDebit(ip) {
  if (!ip.includes(":")) return ip;
  const [tete, queue = ""] = ip.split("::");
  const debut = tete.split(":").filter(Boolean);
  if (ip.includes("::")) {
    const fin = queue.split(":").filter(Boolean);
    while (debut.length + fin.length < 8) debut.push("0");
    debut.push(...fin);
  }
  return debut.slice(0, 4).join(":") + "::/64";
}

async function don(request, env) {
  const seance = await corpsJson(request, TAILLE_MAX);
  let n;
  try {
    n = verifierSeance(seance, CLASSES);
  } catch (e) {
    if (e instanceof DonInvalide) throw new Refus(400, e.message);
    throw e;
  }
  const c = seance.contributeur;
  if (await env.DONS.head(`retraits/${c}.json`)) {
    throw new Refus(410, "identifiant retiré : en tirer un nouveau");
  }
  // Plafond par identifiant et par jour : un seul identifiant ne remplit pas le seau (audit 2026-11-14).
  const maintenant = new Date();
  const jour = horodatage(maintenant).slice(0, 9); // « AAAAMMJJT »
  if ((await compter(env, `dons/${c}/${jour}`, DONS_PAR_JOUR)) >= DONS_PAR_JOUR) {
    throw new Refus(429, "trop de dons aujourd'hui", { "Retry-After": "3600" });
  }
  const cle = `dons/${c}/${horodatage(maintenant)}-${hasard(6)}.json`;
  await env.DONS.put(cle, JSON.stringify(seance), { httpMetadata: { contentType: "application/json" } });
  return json(201, { recu: n });
}

async function retrait(request, env) {
  const demande = await corpsJson(request, 1024);
  try {
    champs(demande, "retrait", new Set(["contributeur"]), ["contributeur"]);
    if (typeof demande.contributeur !== "string" || !RE_CONTRIBUTEUR.test(demande.contributeur)) {
      throw new DonInvalide("contributeur : forme non permise");
    }
  } catch (e) {
    if (e instanceof DonInvalide) throw new Refus(400, e.message);
    throw e;
  }
  const c = demande.contributeur;
  // Un identifiant qui n'a jamais rien donné ne laisse pas de note : sinon chacun en écrirait sans fin.
  if (!(await env.DONS.head(`retraits/${c}.json`)) && (await compter(env, `dons/${c}/`, 1)) === 0) {
    return json(202, { retire: 0 });
  }
  // La note d'abord : un don qui arriverait pendant l'effacement sera refusé.
  const note = { contributeur: c, date: new Date().toISOString() };
  await env.DONS.put(`retraits/${c}.json`, JSON.stringify(note), { httpMetadata: { contentType: "application/json" } });
  // Toutes les clés d'abord, puis l'effacement : ne pas effacer pendant qu'on parcourt la liste.
  const cles = [];
  let curseur;
  do {
    const page = await env.DONS.list({ prefix: `dons/${c}/`, cursor: curseur, limit: 1000 });
    cles.push(...page.objects.map((o) => o.key));
    curseur = page.truncated ? page.cursor : undefined;
  } while (curseur);
  for (let i = 0; i < cles.length; i += 1000) await env.DONS.delete(cles.slice(i, i + 1000)); // 1000 clés par appel
  return json(202, { retire: cles.length });
}

async function exporter(request, env) {
  const refus = refusAdmin(request, env);
  if (refus) return refus;
  const url = new URL(request.url);
  const brut = url.searchParams.get("depuis") || "1970-01-01T00:00:00+00:00";
  const depuis = new Date(/[zZ]|[+-]\d{2}:\d{2}$/.test(brut) ? brut : `${brut}Z`);
  if (Number.isNaN(depuis.getTime())) return json(400, { erreur: "depuis : date ISO 8601 attendue" });
  const apres = url.searchParams.get("apres") || undefined;
  if (apres !== undefined && !/^dons\/[A-Za-z0-9_-]{16,64}\/[0-9TZ]+-[0-9a-f]+\.json$/.test(apres)) {
    return json(400, { erreur: "apres : clé attendue" });
  }

  let sousRequetes = 0;
  const lignes = [JSON.stringify({ type: "export", depuis: depuis.toISOString(), jusqua: new Date().toISOString() })];

  if (!apres) {
    // Les retraits, en entier, sur la première page seulement.
    let curseur;
    do {
      const page = await env.DONS.list({ prefix: "retraits/", cursor: curseur, limit: 1000 });
      sousRequetes++;
      for (const o of page.objects) {
        const c = o.key.slice("retraits/".length, -".json".length);
        lignes.push(JSON.stringify({ type: "retrait", contributeur: c, date: o.uploaded.toISOString() }));
      }
      curseur = page.truncated ? page.cursor : undefined;
    } while (curseur && sousRequetes < 5);
  }

  // Les dons, dans l'ordre des clés, jusqu'au budget ; la suite se demande avec « apres ».
  let octets = 0;
  let suite = null;
  let curseur;
  let dernier = apres;
  parcours: for (;;) {
    const page = await env.DONS.list({ prefix: "dons/", startAfter: apres, cursor: curseur, limit: 1000 });
    sousRequetes++;
    for (const o of page.objects) {
      const quand = dateDeCle(o.key);
      if (!quand || quand < depuis) {
        dernier = o.key;
        continue;
      }
      if (sousRequetes >= BUDGET_EXPORT || octets + o.size > OCTETS_EXPORT) {
        suite = dernier;
        break parcours;
      }
      const objet = await env.DONS.get(o.key);
      sousRequetes++;
      dernier = o.key;
      if (!objet) continue; // retiré entre-temps
      const texte = await objet.text();
      octets += texte.length;
      const c = o.key.split("/")[1];
      // La séance est recopiée telle qu'elle a été écrite (JSON vérifié), sans la relire : peu de calcul.
      lignes.push(
        `{"type":"don","cle":${JSON.stringify(o.key)},"recu":${JSON.stringify(quand.toISOString())},` +
          `"contributeur":${JSON.stringify(c)},"seance":${texte}}`,
      );
    }
    if (!page.truncated) break;
    if (sousRequetes >= BUDGET_EXPORT) {
      suite = dernier;
      break;
    }
    curseur = page.cursor;
  }
  if (suite) lignes.push(JSON.stringify({ type: "suite", apres: suite }));
  return new Response(lignes.join("\n") + "\n", {
    status: 200,
    headers: { "Content-Type": "application/x-ndjson; charset=utf-8", "Cache-Control": "no-store" },
  });
}

function monIp(request, env) {
  const refus = refusAdmin(request, env);
  if (refus) return refus;
  return json(200, { ip: request.headers.get("CF-Connecting-IP") || "" });
}

const TABLE = {
  "/v1/dons": ["POST", don],
  "/v1/retrait": ["POST", retrait],
  "/v1/export": ["GET", exporter],
  "/v1/sante": ["GET", () => json(200, { ok: true })],
  "/v1/mon-ip": ["GET", monIp],
};

async function router(request, env) {
  const chemin = new URL(request.url).pathname;
  if (!(chemin in TABLE)) return json(404, { erreur: "inconnu" });
  const [attendue, action] = TABLE[chemin];
  if (request.method !== attendue) return json(405, { erreur: `${attendue} seulement` }, { Allow: attendue });
  if (chemin !== "/v1/sante" && env.LIMITEUR) {
    // CF-Connecting-IP est posé par Cloudflare ; l'IP n'est ni journalisée ni stockée par ce code.
    const ip = request.headers.get("CF-Connecting-IP") || "";
    const { success } = await env.LIMITEUR.limit({ key: cleDebit(ip) });
    if (!success) return json(429, { erreur: "trop de requêtes" }, { "Retry-After": "60" });
  }
  try {
    return await action(request, env);
  } catch (e) {
    if (e instanceof Refus) return json(e.statut, { erreur: e.message }, e.entetes);
    throw e;
  }
}

export default {
  async fetch(request, env) {
    let reponse;
    try {
      reponse = await router(request, env);
    } catch {
      reponse = json(500, { erreur: "erreur interne" });
    }
    const chemin = new URL(request.url).pathname;
    console.log(`${request.method.slice(0, 8)} ${ROUTES.has(chemin) ? chemin : "?"} ${reponse.status}`);
    return reponse;
  },
};
