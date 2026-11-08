# Le récepteur des dons sur Cloudflare (Worker)

C'est la version **en service** de la plateforme (ADR 0045) : un petit programme JavaScript qui tourne
gratuitement chez Cloudflare et range les dons dans le seau R2 `fikajiana-dons`. Il fait exactement ce
que fait le récepteur Python (`../recepteur.py`) : mêmes adresses, mêmes règles, même rangement.
Ce qu'il reçoit et ne reçoit jamais : voir `../LISEZMOI.md`.

- Adresse : **<https://fikajiana-dons.fikajiana-dons-worker.workers.dev>** (à mettre dans l'app).
- Compte Cloudflare : celui d'Antsa. Seau R2 : `fikajiana-dons`. Jeton d'export : secret
  `FIKA_JETON_ADMIN` du Worker ; sa copie est dans `~/.config/fikajiana/cloudrun.env.yaml` sur
  l'ordinateur d'Antsa (jamais dans Git).

## Récupérer les dons

```bash
export FIKA_DONS_ADRESSE=https://fikajiana-dons.fikajiana-dons-worker.workers.dev
export FIKA_JETON_ADMIN=…   # le jeton ci-dessus
uv run entrainement/recuperer_dons.py
uv run entrainement/entrainer.py
```

L'export arrive par pages (au plus 40 dons par appel, limite de l'offre gratuite) ; le script les enchaîne seul.

## Retrait à la main

```bash
curl -X POST https://fikajiana-dons.fikajiana-dons-worker.workers.dev/v1/retrait \
  -H 'Content-Type: application/json' -d '{"contributeur": "SON-IDENTIFIANT"}'
```

## Modifier et republier

```bash
cd plateforme/worker
npm install            # une fois (wrangler, l'outil de Cloudflare)
npm test               # 19 tests, dont les cas communs avec schema.py
npx wrangler login     # une fois par ordinateur
npx wrangler deploy
```

- Si `collecte/classes.txt` change : `npm run classes`, puis republier.
- Si `schema.py` change : refaire `cas_schema.json` (`cd plateforme && uv run python tests/fabriquer_cas.py`),
  reporter le changement dans `src/schema.js`, `npm test`.
- Changer le jeton d'export : `npx wrangler secret put FIKA_JETON_ADMIN` (il est lu au clavier, ou par un tube).
- Voir les requêtes en direct (méthode, route, statut ; ni IP ni contenu) : `npx wrangler tail`.

## Limites de l'offre gratuite (vérifiées le 2026-11-08)

- 100 000 requêtes par jour ; 10 ms de calcul par requête ; 50 sous-requêtes par appel, accès à R2
  compris. <https://developers.cloudflare.com/workers/platform/limits/>
- R2 : 10 Go stockés, 1 million d'écritures et 10 millions de lectures par mois.
  <https://developers.cloudflare.com/r2/pricing/>
- Limite de débit : 30 requêtes par minute et par IP, « approximate and apply separately in each
  Cloudflare location ». <https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/>

## Vérifié / Supposé / Reste à tester

- **Vérifié** : voir `../HEBERGER.md`, section « Option retenue ».
- **Supposé** : une séance de 2 Mo tient dans les 10 ms de calcul (non mesuré ; une séance réelle pèse
  bien moins).
- **Reste à tester** : l'envoi depuis l'app ; le temps de calcul sur les plus gros envois.
