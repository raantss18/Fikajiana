// Recopie `collecte/classes.txt` dans `src/classes.js` (un Worker ne lit pas de fichier).
// Lancer après toute modification de classes.txt : npm run classes. Un test vérifie l'égalité.
import { readFileSync, writeFileSync } from "node:fs";

const source = new URL("../../../collecte/classes.txt", import.meta.url);
const cible = new URL("../src/classes.js", import.meta.url);
const texte = readFileSync(source, "utf-8");
writeFileSync(
  cible,
  "// Fichier produit par `npm run classes` depuis collecte/classes.txt : ne pas modifier à la main.\n" +
    `export const CLASSES_TXT = ${JSON.stringify(texte)};\n`,
);
