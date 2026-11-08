# ADR 0045 — Récepteur des dons sur un Worker Cloudflare

- **Date** : 2026-11-08 · **Statut** : accepté (choix d'Antsa : « Oui, Worker Cloudflare »)
- **Contexte** : Cloud Run (ADR 0043, `HEBERGER.md`) exige un compte de facturation Google ; la carte d'Antsa y a été refusée. Le compte Cloudflare a déjà le seau R2 `fikajiana-dons`.
- **Décision** : le récepteur tourne sur un Worker Cloudflare gratuit (`plateforme/worker/`, JavaScript), lié au seau R2. Même API, même rangement (`dons/<id>/<horodatage>-<hasard>.json`, `retraits/<id>.json`) que le récepteur Python, qui reste la référence pour un serveur ou une machine à soi.
- **Égalité des deux** : `plateforme/tests/cas_schema.json`, fabriqué par `schema.py`, est relu par les tests du Worker (même verdict). Écarts connus de `JSON.parse` (clé répétée, `1.0`) sans effet : le Worker réécrit le JSON lu.
- **Limites de l'offre gratuite** : 100 000 requêtes par jour, 10 ms de calcul et 50 sous-requêtes (dont R2) par appel. L'export est donc **par pages** (`{"type": "suite", "apres": …}`), suivies par `recuperer_dons.py`.
- **Débit** : liaison Rate Limiting de Cloudflare, 30 par minute et par IP (`CF-Connecting-IP`), approximative et comptée par centre. Ni IP ni contenu dans le journal ; observabilité coupée.
- **Contrepartie** : Cloudflare voit les dons en clair (comme tout hébergeur qui termine HTTPS).
- **Sources** : `plateforme/HEBERGER.md` (limites citées), `plateforme/worker/LISEZMOI.md`.
