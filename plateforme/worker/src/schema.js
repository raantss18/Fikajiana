// Vérification d'un don : la même liste blanche que `plateforme/schema.py` (ADR 0043), en JavaScript
// pour le Worker Cloudflare (ADR 0045). Les deux sont tenus égaux par `plateforme/tests/cas_schema.json`.
// Écarts connus, sans effet sur ce qui est stocké (le Worker réécrit le JSON qu'il a lu) :
// JSON.parse garde la dernière de deux clés répétées, et 1.0 vaut 1.

export const TAILLE_MAX = 2 * 1024 * 1024;
export const ECHANTILLONS_MAX = 500;
export const TRAITS_MAX = 64;
export const POINTS_MAX = 4000;
export const POINTS_TOTAL_MAX = 150_000;
export const LATEX_MAX = 512;
export const COORD_MAX = 100_000;
export const TEMPS_MAX = 3_600_000;

export const RE_CONTRIBUTEUR = /^[A-Za-z0-9_-]{16,64}$/;
const RE_ID = /^[A-Za-z0-9_-]{1,64}$/;
const RE_VERSION = /^[0-9]{1,4}(\.[0-9]{1,4}){1,3}([+-][0-9A-Za-z.]{1,32})?$/;
const RE_MODELE = /^[A-Za-z0-9 ._+()-]{1,64}$/;
const RE_DEBUT = /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-][0-9]{2}:[0-9]{2})$/;

const CHAMPS_SEANCE = new Set(["format", "licence", "contributeur", "version_app", "appareil", "outil", "debut", "echantillons"]);
const OBLIGATOIRES_SEANCE = ["format", "licence", "contributeur", "outil", "echantillons"];
const CHAMPS_APPAREIL = new Set(["modele", "largeur_dp", "hauteur_dp", "densite"]);
const CHAMPS_ECHANTILLON = new Set(["id", "type", "classe", "attendu", "traits", "case", "rejete"]);
const OBLIGATOIRES_ECHANTILLON = ["type", "attendu", "traits"];

export class DonInvalide extends Error {}

export function lireClasses(texte) {
  const classes = new Map();
  for (const ligne of texte.split("\n")) {
    if (!ligne.trim() || ligne.startsWith("#")) continue;
    const [ident, , latex] = ligne.replace(/\r$/, "").split("\t");
    classes.set(ident, latex);
  }
  return classes;
}

/** JSON lu depuis des octets UTF-8 ; NaN et Infinity sont déjà refusés par JSON.parse. */
export function analyserJson(octets) {
  let texte;
  try {
    texte = new TextDecoder("utf-8", { fatal: true }).decode(octets);
  } catch {
    throw new DonInvalide("le corps n'est pas de l'UTF-8");
  }
  try {
    return JSON.parse(texte);
  } catch {
    throw new DonInvalide("JSON illisible");
  }
}

function estObjet(v) {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function nombre(v, chemin, mini, maxi) {
  if (typeof v !== "number" || !Number.isFinite(v)) throw new DonInvalide(`${chemin} : nombre attendu`);
  if (v < mini || v > maxi) throw new DonInvalide(`${chemin} : hors bornes [${mini}, ${maxi}]`);
  return v;
}

function longueur(s) {
  return [...s].length; // en points de code, comme len() en Python
}

function texte(v, chemin, motif = null, maxi = 64) {
  if (typeof v !== "string") throw new DonInvalide(`${chemin} : texte attendu`);
  if (longueur(v) > maxi) throw new DonInvalide(`${chemin} : texte trop long (> ${maxi})`);
  if (motif && !motif.test(v)) throw new DonInvalide(`${chemin} : forme non permise`);
  return v;
}

export function champs(objet, chemin, permis, obligatoires) {
  if (!estObjet(objet)) throw new DonInvalide(`${chemin} : objet attendu`);
  const enTrop = Object.keys(objet).filter((k) => !permis.has(k)).sort();
  if (enTrop.length) throw new DonInvalide(`${chemin} : champ non permis ${JSON.stringify(enTrop[0].slice(0, 32))}`);
  const manquants = obligatoires.filter((k) => !(k in objet)).sort();
  if (manquants.length) throw new DonInvalide(`${chemin} : champ manquant ${JSON.stringify(manquants[0])}`);
}

function latex(v, chemin) {
  v = texte(v, chemin, null, LATEX_MAX);
  if (!v.trim()) throw new DonInvalide(`${chemin} : LaTeX vide`);
  for (const c of v) {
    const o = c.codePointAt(0);
    if (o < 0x20 || (o >= 0x7f && o < 0xa0)) throw new DonInvalide(`${chemin} : caractère de contrôle`);
  }
  return v;
}

/** Vérifie une séance ; rend le nombre d'échantillons. Lève DonInvalide sinon. */
export function verifierSeance(doc, classes) {
  champs(doc, "séance", CHAMPS_SEANCE, OBLIGATOIRES_SEANCE);
  if (doc.format !== 1) throw new DonInvalide("format : 1 attendu");
  if (doc.licence !== "CC0-1.0") throw new DonInvalide("licence : CC0-1.0 obligatoire");
  texte(doc.contributeur, "contributeur", RE_CONTRIBUTEUR);
  if (doc.outil !== "stylet" && doc.outil !== "doigt") throw new DonInvalide("outil : stylet ou doigt");
  if ("version_app" in doc) texte(doc.version_app, "version_app", RE_VERSION);
  if ("debut" in doc) texte(doc.debut, "debut", RE_DEBUT, 40);
  if ("appareil" in doc) {
    const app = doc.appareil;
    champs(app, "appareil", CHAMPS_APPAREIL, []);
    if ("modele" in app) texte(app.modele, "appareil.modele", RE_MODELE);
    for (const cle of ["largeur_dp", "hauteur_dp"]) if (cle in app) nombre(app[cle], `appareil.${cle}`, 1, 20_000);
    if ("densite" in app) nombre(app.densite, "appareil.densite", 0.1, 10);
  }
  const echantillons = doc.echantillons;
  if (!Array.isArray(echantillons) || !echantillons.length) throw new DonInvalide("echantillons : liste non vide attendue");
  if (echantillons.length > ECHANTILLONS_MAX) throw new DonInvalide(`echantillons : plus de ${ECHANTILLONS_MAX}`);
  let total = 0;
  echantillons.forEach((e, i) => {
    const c = `echantillons[${i}]`;
    champs(e, c, CHAMPS_ECHANTILLON, OBLIGATOIRES_ECHANTILLON);
    if ("id" in e) texte(e.id, `${c}.id`, RE_ID);
    const attendu = latex(e.attendu, `${c}.attendu`);
    if (e.type === "signe") {
      if (!("classe" in e)) throw new DonInvalide(`${c}.classe : obligatoire pour un signe`);
      if (typeof e.classe !== "string" || !classes.has(e.classe)) throw new DonInvalide(`${c}.classe : signe inconnu de classes.txt`);
      if (classes.get(e.classe) !== attendu) throw new DonInvalide(`${c}.attendu : ne correspond pas à la classe`);
    } else if (e.type === "expression") {
      if ("classe" in e) throw new DonInvalide(`${c}.classe : réservé aux signes`);
    } else {
      throw new DonInvalide(`${c}.type : signe ou expression`);
    }
    if ("rejete" in e && typeof e.rejete !== "boolean") throw new DonInvalide(`${c}.rejete : booléen attendu`);
    if ("case" in e) {
      const k = e.case;
      if (!Array.isArray(k) || k.length !== 4) throw new DonInvalide(`${c}.case : 4 nombres attendus`);
      nombre(k[0], `${c}.case`, -COORD_MAX, COORD_MAX);
      nombre(k[1], `${c}.case`, -COORD_MAX, COORD_MAX);
      nombre(k[2], `${c}.case`, 1e-3, COORD_MAX);
      nombre(k[3], `${c}.case`, 1e-3, COORD_MAX);
    }
    const traits = e.traits;
    if (!Array.isArray(traits) || traits.length > TRAITS_MAX) throw new DonInvalide(`${c}.traits : liste de ${TRAITS_MAX} traits au plus`);
    traits.forEach((t, j) => {
      if (!Array.isArray(t) || t.length > POINTS_MAX) throw new DonInvalide(`${c}.traits[${j}] : liste de ${POINTS_MAX} points au plus`);
      total += t.length;
      for (const p of t) {
        if (!Array.isArray(p) || p.length !== 4) throw new DonInvalide(`${c}.traits[${j}] : point [x, y, t, p] attendu`);
        nombre(p[0], `${c}.traits[${j}].x`, -COORD_MAX, COORD_MAX);
        nombre(p[1], `${c}.traits[${j}].y`, -COORD_MAX, COORD_MAX);
        nombre(p[2], `${c}.traits[${j}].t`, 0, TEMPS_MAX);
        nombre(p[3], `${c}.traits[${j}].p`, 0, 1);
      }
    });
    if (total > POINTS_TOTAL_MAX) throw new DonInvalide(`séance : plus de ${POINTS_TOTAL_MAX} points`);
  });
  return echantillons.length;
}
