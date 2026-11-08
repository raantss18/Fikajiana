# La plateforme des dons d'écriture

Quand une personne l'accepte dans Fikajiana, les lignes qu'elle a jugées (👍, ou 👎 puis corrigées)
partent ici. Elles servent à entraîner le petit modèle qui lit les signes écrits à la main
(ADR 0038, ADR 0042). Ce dossier contient le **récepteur** : un petit programme qui reçoit ces dons,
les vérifie et les range. Il est libre (GPL-3.0-or-later), comme le reste du dépôt.

## Ce que la plateforme reçoit

Pour chaque ligne donnée, et rien d'autre :
- les **traits** : la position de la pointe (en dp), le temps depuis le début du signe, la pression ;
- le **LaTeX juste** de ce qui était écrit ;
- le **modèle de l'appareil** (ex. `2410CRP4CG`), sa taille d'écran, la **version de l'app**,
  **stylet ou doigt** ;
- un **identifiant tiré au hasard** sur le téléphone, qui sert seulement au retrait ;
- la licence **CC0** : la personne a accepté que ses dons soient libres de tout droit.

## Ce qu'elle ne reçoit jamais

Ni nom, ni prénom, ni adresse e-mail, ni compte, ni position, ni le reste de la feuille.
Ce n'est pas qu'une promesse : le récepteur **refuse tout le don** s'il contient un champ qu'il ne
connaît pas (`auteur`, `position`…). La liste exacte des champs permis est dans `schema.py`.

Le récepteur ne garde pas les adresses IP : il les compte en mémoire pendant une minute pour limiter
le débit (30 envois par minute et par adresse, réglable), puis les oublie. Son journal ne contient
que « POST /v1/dons 201 3 ms » : ni IP, ni contenu. Caddy, devant lui, n'écrit pas de journal d'accès.

## Installer

Voir `HEBERGER.md` : trois options comparées, et deux pas-à-pas : **Cloud Run + Cloudflare R2**
(gratuit, choisi par Antsa le 2026-11-08) et un petit serveur loué (`docker compose up -d --build`).

Pour essayer sur son ordinateur, sans Docker :

```bash
cd plateforme
FIKA_JETON_ADMIN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))") uv run recepteur.py
```

Les dons arrivent alors dans `plateforme/dons-recus/` (hors Git).

Réglages (variables d'environnement, voir `exemple.env`) :

| Variable | Rôle |
|---|---|
| `FIKA_JETON_ADMIN` | Jeton secret de l'export (32 caractères au moins). Sans lui, l'export est fermé. |
| `FIKA_DOSSIER` | Dossier des dons (par défaut `dons-recus`, `/donnees` dans Docker). |
| `FIKA_S3_SEAU` (+ `FIKA_S3_ADRESSE`, `FIKA_S3_REGION`, `FIKA_S3_PREFIXE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) | Ranger les dons dans un stockage objet compatible S3 au lieu du disque. |
| `FIKA_DEBIT`, `FIKA_FENETRE` | Envois permis par adresse IP et par fenêtre (30 par 60 s). |
| `FIKA_DERRIERE_PROXY` | Nombre d'adresses ajoutées par les proxys de confiance dans `X-Forwarded-For` : `1` derrière Caddy (déjà dans `compose.yaml`) ; sur Cloud Run, à régler avec `/v1/mon-ip` (`HEBERGER.md`). |

L'app ne contient **aucun secret** : seul le serveur connaît le jeton d'export.

## Récupérer les dons et relancer l'entraînement

Sur l'ordinateur où se fait l'entraînement, à la racine du dépôt :

```bash
export FIKA_DONS_ADRESSE=https://dons.votre-domaine.org
export FIKA_JETON_ADMIN=…   # le jeton du serveur
uv run entrainement/recuperer_dons.py
uv run entrainement/entrainer.py
```

`recuperer_dons.py` télécharge les nouveaux dons (depuis le dernier passage, noté dans
`donnees/dons-etat.json`), applique les retraits, puis **trie** : traits vides, signes impossibles
(trop de traits, point unique, signe hors de sa case ou bien plus grand qu'elle), doublons exacts,
LaTeX qui ne s'analyse pas. Les séances gardées vont dans `donnees/ecriture/dons/<identifiant>/`,
que `entrainer.py` lit sans réglage. Le bilan s'affiche et reste dans `donnees/dons-rapport.md`.
`donnees/` est hors Git.

## Répondre à une demande de retrait

Le plus souvent, il n'y a **rien à faire** : la personne touche « Retirer mes dons » dans l'app, qui
envoie son identifiant à `/v1/retrait`. Le serveur efface aussitôt tous ses dons, note le retrait et
refuse ensuite tout don portant cet identifiant. Au prochain `recuperer_dons.py`, sa copie locale est
effacée aussi.

Si quelqu'un écrit pour demander le retrait (par exemple après avoir désinstallé l'app) :
1. Lui demander son **identifiant** (l'app doit l'afficher dans ses Réglages, à « Aider à améliorer la
   reconnaissance » ; à confirmer avec la branche de l'app). Sans identifiant, impossible de retrouver ses dons : ils ne portent aucun nom.
2. Lancer, depuis n'importe quel ordinateur :

   ```bash
   curl -X POST https://dons.votre-domaine.org/v1/retrait \
     -H 'Content-Type: application/json' -d '{"contributeur": "SON-IDENTIFIANT"}'
   ```

   Réponse `{"retire": 3}` : trois envois effacés.
3. Relancer `uv run entrainement/recuperer_dons.py` sur l'ordinateur d'entraînement.
4. Un modèle déjà entraîné avec ces dons n'est pas « désappris » : le retrait vaut pour les
   entraînements suivants.

## API (pour l'app)

| Requête | Réponse |
|---|---|
| `POST /v1/dons`, corps = une séance au format `collecte/FORMAT.md` (≤ 2 Mio, champs de `schema.py`) | `201 {"recu": n}` (n échantillons) ; `400` format, `410` identifiant retiré, `413` trop gros, `415` pas du JSON, `429` trop d'envois (`Retry-After`) |
| `POST /v1/retrait`, `{"contributeur": "<id>"}` | `202 {"retire": n}` |
| `GET /v1/export?depuis=<date ISO>`, `Authorization: Bearer <jeton>` | `200`, une ligne JSON par élément : en-tête, retraits, dons |
| `GET /v1/sante` | `200 {"ok": true}` |
| `GET /v1/mon-ip`, `Authorization: Bearer <jeton>` | `200 {"ip": …}` : l'adresse comptée pour l'appelant (réglage, rien n'est gardé) |

Écarts avec `collecte/FORMAT.md` : `auteur` est refusé (un prénom), `contributeur` (16 à 64 caractères
`A-Z a-z 0-9 _ -`) est obligatoire, `version_app` est permis.

## Pourquoi Python et Waitress

- Le reste des outils du projet (`entrainement/`) est en Python : une seule langue à relire. Le
  récepteur tient en trois fichiers (`schema.py`, `stockage.py`, `recepteur.py`) et n'utilise que la
  bibliothèque standard ; la récupération réutilise le même `schema.py`.
- Le serveur HTTP de la bibliothèque standard « is not recommended for production »
  (<https://docs.python.org/3/library/http.server.html>) : on lui préfère **Waitress**, serveur WSGI en
  pur Python, sans autre dépendance, licence ZPL 2.1 (<https://pypi.org/project/waitress/>), réglé pour
  refuser tout corps de plus de 2 Mio (`max_request_body_size`,
  <https://docs.pylonsproject.org/projects/waitress/en/stable/arguments.html>).
- **boto3** (Apache-2.0) n'est installé que pour un stockage S3 (`--build-arg S3=0` pour s'en passer).
- Pas de base de données : un fichier JSON par don, dans `dons/<identifiant>/` ; un retrait efface un
  dossier.

## Vérifié / Supposé / Reste à tester

- **Vérifié** (le 2026-11-08) : 70 tests du récepteur (`cd plateforme && uv run pytest`) : schéma
  valide et invalide, champs en trop, JSON strict, taille, débit et oubli des IP, retrait, export
  avec jeton seulement, stockage S3 simulé, Waitress réel (corps en morceaux, corps trop gros).
  Tests de la récupération (`cd entrainement && uv run pytest tests/test_recuperer_dons.py`) : tri,
  retraits, aller-retour avec le récepteur, fichiers lus par `donnees.lire_seances`. Image Docker
  construite et essayée ; `compose.yaml` essayé en local avec Caddy (HTTPS, débit par IP du client,
  aucune IP dans les journaux).
- **Supposé** : les bornes (500 échantillons, 64 traits, 4 000 points par trait) suffisent pour une
  ligne écrite ; les règles des « signes impossibles » n'écartent pas de bons signes (à relire dans
  le rapport du tri sur les premiers vrais dons).
- **Reste à tester** : l'envoi depuis l'app (écrit dans une autre branche) ; un vrai hébergement ;
  un vrai stockage S3 (R2, MinIO) ; le comportement sous une charge réelle.
