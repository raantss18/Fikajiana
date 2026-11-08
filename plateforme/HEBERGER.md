# Où héberger le récepteur des dons

Trois façons concrètes et peu coûteuses. **Rien n'est choisi ni installé** : la décision revient à
Antsa et à ses amis (ADR 0042). Pages consultées le **2026-11-08** ; les prix changent, les relire
avant de payer. Prix hors taxes sauf mention contraire.

Ce qu'il faut au récepteur : un conteneur de ~230 Mo (176 Mo sans S3), quelques requêtes par minute,
quelques Go de fichiers JSON au fil des mois, et HTTPS.

## Option retenue : Worker Cloudflare + R2 (en service depuis le 2026-11-08)

Choix d'Antsa après le refus de sa carte par Google (option B ci-dessous abandonnée). ADR 0045,
mode d'emploi : `worker/LISEZMOI.md`. Adresse : <https://fikajiana-dons.fikajiana-dons-worker.workers.dev>.

**Vérifié le 2026-11-08, sur le vrai service** (depuis l'ordinateur d'Antsa) : `/v1/sante` 200 ; un don
201 `{"recu":2}` ; un don avec `auteur` 400 ; un corps de 2,2 Mo 413 ; l'export sans jeton 401, avec
jeton la liste des dons ; `/v1/mon-ip` rend l'adresse de l'appelant ; retrait 202 puis don refusé 410 ;
`recuperer_dons.py` lit l'export et applique le retrait ; 150 requêtes rapides depuis une même IP : 53
acceptées puis 97 refusées (429), la limite est bien approximative. Le seau a été vidé après l'essai.
Le certificat HTTPS du sous-domaine `workers.dev` a mis environ 2 minutes à être prêt.
Coût : 0 € (offre gratuite Workers ; R2 sous ses limites gratuites, carte enregistrée chez Cloudflare).

**Reste à tester** : l'envoi depuis l'app ; le temps de calcul des plus gros envois (10 ms permis).

## Comparaison

| | A. Petit VPS + Docker | B. Conteneur gratuit + stockage objet | C. Chez soi + tunnel |
|---|---|---|---|
| Exemple | Hetzner CX23 ou OVHcloud VPS-1 | Google Cloud Run + Cloudflare R2 | Vieux PC ou Raspberry Pi + Tailscale Funnel |
| Coût | 3,81 € HT (4,57 € TTC) à 5,99 € HT par mois | 0 € dans les limites gratuites | 0 € (électricité) |
| Dons stockés | Disque du VPS (volume Docker) | R2 (S3), le disque de Cloud Run s'efface | Disque de la machine |
| HTTPS | Caddy (`compose.yaml`), automatique | Fourni par Cloud Run | Fourni par Funnel, chiffré jusqu'à la machine |
| Qui voit les dons en clair | L'hébergeur du disque (comme tout VPS) | Google (calcul) et Cloudflare (stockage) | Personne d'autre (Funnel) |
| Entretien | Mises à jour du système, sauvegardes | Presque rien ; compte de facturation Google obligatoire | La machine doit rester allumée |
| Pas-à-pas ici | **Oui** (le plus simple) | **Oui** (choisi par Antsa le 2026-11-08) | Non (à écrire si choisi) |

## Vérifié (sources primaires)

**A. VPS**
- Hetzner « Cost-Optimized » : **CX23** (x86) 2 vCPU, 4 Go, 40 Go NVMe, « € 5.99 per month, excl. VAT » ;
  **CAX11** (Arm) 2 vCPU, 4 Go, 40 Go, « € 6.49 per month, excl. VAT » ; 20 To de trafic ; Nuremberg et Helsinki
  (UE). ⚠ Le 2026-11-08 la page portait « This product is currently unavailable ». <https://www.hetzner.com/cloud/cost-optimized/>
- OVHcloud **VPS-1** : « 3,81 € HT/mois soit 4,57 € TTC/mois », 2 vCores, 4 Go, 40 Go NVMe, trafic illimité,
  500 Mbit/s. <https://www.ovhcloud.com/fr/vps/>
- Caddy obtient et renouvelle seul le certificat : « By default, Caddy serves all sites over HTTPS »
  (Let's Encrypt, ZeroSSL). <https://caddyserver.com/docs/automatic-https>
- Caddy n'écrit un journal des requêtes que si la directive `log` est présente ; le `Caddyfile` fourni n'en
  a pas. <https://caddyserver.com/docs/caddyfile/directives/log> — Constaté aussi à l'essai (aucune IP dans
  `docker compose logs caddy`).
- Caddy ignore les en-têtes `X-Forwarded-For` envoyés par le client, sauf depuis des `trusted_proxies`,
  et met l'adresse qu'il voit. <https://caddyserver.com/docs/caddyfile/directives/reverse_proxy>
  Le récepteur lit l'adresse la plus à droite (`FIKA_DERRIERE_PROXY=1`) : essai fait, 30 dons acceptés
  puis 429.

**B. Conteneur gratuit**
- Cloud Run, offre gratuite : « 2 million requests per month », « 360,000 GB-seconds of memory, 180,000
  vCPU-seconds ». <https://docs.cloud.google.com/free/docs/free-cloud-features>
- Le disque d'un conteneur Cloud Run est en mémoire et s'efface : « Data written to the file system doesn't
  persist ». <https://docs.cloud.google.com/run/docs/container-contract> — d'où `FIKA_S3_SEAU`.
- Cloudflare R2, gratuit : « 10 GB-month / month », 1 million d'opérations de classe A et 10 millions de
  classe B par mois, sortie gratuite. <https://developers.cloudflare.com/r2/pricing/>
  « R2 implements the S3 API » (avec des écarts). <https://developers.cloudflare.com/r2/api/s3/api/>
- Pas d'offre gratuite avec disque qui dure chez : Fly.io (« New organizations don't have a free tier »,
  <https://docs.fly.io/about/pricing>), Render (« Free web services have an ephemeral filesystem »,
  <https://render.com/docs/free>), Koyeb (instance gratuite sans volume,
  <https://www.koyeb.com/docs/reference/instances>).

**C. Chez soi**
- Tailscale Funnel publie un service de la machine sur Internet ; « available for all plans » ; ports 443,
  8443 ou 10000 ; la machine « terminates the TLS connection » et les relais « do not decrypt the traffic » ;
  débit limité, valeur non publiée. <https://tailscale.com/kb/1223/funnel> — plan Personal à 0 $ :
  <https://tailscale.com/pricing>
- Cloudflare Tunnel : « Available on all plans », mais il faut un domaine chez Cloudflare
  (<https://developers.cloudflare.com/tunnel/>,
  <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/>).
  Cloudflare termine HTTPS chez lui (deux connexions, <https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/>) :
  il verrait les dons en clair. Funnel est donc préféré pour cette option.

## Supposé / Reste à vérifier

- **Supposé** : Cloudflare déchiffre le trafic d'un Tunnel (déduit des modes SSL) ; Funnel gratuit pour un
  usage personnel (page de prix lue en partie) ; Cloud Run demande un compte de facturation.
- **Reste à vérifier** : disponibilité réelle et prix TTC chez Hetzner ; débit permis par Funnel ;
  options B et C jamais essayées ici ; sauvegardes (non prévues par le récepteur).

## Pas-à-pas : option A (VPS + Docker + Caddy)

Il faut : un VPS Debian ou Ubuntu, un nom de domaine (ou un sous-domaine d'un ami) dont on peut régler le DNS.

1. **DNS** : créer un enregistrement `A` (et `AAAA` si IPv6) `dons.votre-domaine.org` → adresse IP du VPS.
2. **Docker** sur le VPS : suivre <https://docs.docker.com/engine/install/debian/> (ou `ubuntu/`).
3. **Pare-feu** : n'ouvrir que 22 (SSH), 80 et 443.
4. **Code** : `git clone https://github.com/raantss18/Fikajiana.git && cd Fikajiana/plateforme`
5. **Réglages** : `cp exemple.env .env`, puis dans `.env` : `FIKA_DOMAINE=dons.votre-domaine.org` et
   `FIKA_JETON_ADMIN=` suivi d'un jeton tiré par
   `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`. Garder ce jeton hors de Git, le
   transmettre à Antsa par un moyen sûr. `chmod 600 .env`.
6. **Lancer** : `docker compose up -d --build`. Caddy obtient le certificat en quelques secondes.
7. **Vérifier** : `curl https://dons.votre-domaine.org/v1/sante` → `{"ok": true}`.
8. **Donner l'adresse** `https://dons.votre-domaine.org` à Antsa pour l'app (réglage « adresse de la plateforme »).
9. **Mettre à jour** : `git pull && docker compose up -d --build`.
10. **Sauvegarder** les dons de temps en temps :
    `docker compose exec recepteur tar -C /donnees -cz . > dons-$(date +%F).tar.gz` (sur une machine sûre).

Les dons sont dans le volume Docker `dons` (`docker volume inspect plateforme_dons`).

## Pas-à-pas : option B (Cloud Run + Cloudflare R2) — abandonnée

> Le 2026-11-08, Google a refusé la carte d'Antsa (« Payment authorization failed ») : sans compte de
> facturation, Cloud Run est impossible. Remplacée par le Worker Cloudflare (ADR 0045). Le projet vide
> `fikajiana-dons-5b2c` a été supprimé le 2026-11-08. Ce pas-à-pas sert encore pour qui aurait une carte acceptée.

Compter une heure la première fois. Il faut : un compte Google, un compte Cloudflare, et sur
l'ordinateur Docker et la Google Cloud CLI (`gcloud`, <https://docs.cloud.google.com/sdk/docs/install>).
Toutes les commandes se lancent depuis la racine du dépôt.

### Ce qui est vérifié pour cette option (le 2026-11-08)

- Offre gratuite Cloud Run (facturation à la requête) : « 2 million requests per month », « 360,000 GB-seconds
  of memory, 180,000 vCPU-seconds », « 1 GB of outbound data transfer from North America per month » ;
  Artifact Registry : « 0.5 GB of storage per month » ; « A Google Cloud billing account is required to
  access the Google Cloud Free Tier ». <https://docs.cloud.google.com/free/docs/free-cloud-features>
- Cloud Run fournit la variable `PORT` (8080 par défaut) ; l'image doit être `linux/amd64`
  (« Cloud Run specifically supports the Linux x86_64 ABI format »). <https://docs.cloud.google.com/run/docs/container-contract>
- Options de `gcloud run deploy` utilisées ci-dessous (`--env-vars-file`, `--max-instances`, `--min-instances`,
  `--allow-unauthenticated`, `--memory`, `--concurrency`, `--cpu-throttling`) :
  <https://docs.cloud.google.com/sdk/gcloud/reference/run/deploy>
- **Cloud Run journalise chaque requête** (« These logs are created automatically », on ne peut pas les couper,
  seulement les exclure : <https://docs.cloud.google.com/run/docs/logging>) et le champ `httpRequest.remoteIp`
  contient l'IP du client (<https://docs.cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry>).
  L'étape 8 les exclut, pour tenir la promesse « on ne garde pas les IP ».
- R2 : jeton « Object Read & Write » limitable à un seau ; adresse S3 `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`
  (`.eu.` pour un seau de juridiction UE) ; « You will not be able to access your Secret Access Key again ».
  <https://developers.cloudflare.com/r2/api/s3/tokens/> — avec boto3, `region_name="auto"` :
  <https://developers.cloudflare.com/r2/examples/aws/boto3/>

**Supposé / reste à vérifier** : la forme de `X-Forwarded-For` sur Cloud Run n'est pas documentée pour
Cloud Run (pour le répartiteur de charge Google : « [SUPPLIED_VALUE,]CLIENT_IP,LOAD_BALANCER_IP »,
<https://docs.cloud.google.com/load-balancing/docs/https>) : l'étape 7 la mesure. Le récepteur n'a pas
encore tourné sur Cloud Run. Le filtre d'exclusion de l'étape 8 est à vérifier dans l'Explorateur
de journaux.

### 1. Cloudflare R2 : le seau et sa clé

**Fait le 2026-11-08** (compte d'Antsa) : abonnement R2 à 0 $ par mois activé — Cloudflare **exige une
carte bancaire** même sans dépasser l'offre gratuite —, seau `fikajiana-dons` (emplacement automatique,
Europe de l'Ouest, classe Standard), jeton de compte `fikajiana-dons-recepteur` (Object Read & Write, ce
seau seulement, sans fin). Ses clés sont dans `plateforme/cloudrun.env.yaml` d'une copie de travail et dans
`~/.config/fikajiana/cloudrun.env.yaml` sur l'ordinateur d'Antsa, jamais dans Git. Essai réel depuis
l'ordinateur avec ces clés : don 201, export, retrait 202 puis don refusé 410 ; le seau est vide ensuite.

1. Tableau de bord Cloudflare › **R2 object storage** › créer un seau `fikajiana-dons` (emplacement
   automatique, ou juridiction UE : l'adresse prend alors `.eu.`).
2. **Overview › Account Details › API Tokens › Manage › Create Account API token** : permission
   **Object Read & Write**, limitée au seau `fikajiana-dons`.
3. Noter tout de suite l'**Access Key ID**, la **Secret Access Key** (montrée une seule fois) et
   l'**Account ID** (dans *Account Details*).

### 2. Google Cloud : le projet

```bash
gcloud auth login
gcloud projects create fikajiana-dons-XXXX        # un nom libre et unique
gcloud config set project fikajiana-dons-XXXX
```

Relier le projet à un compte de facturation (console › Facturation), puis :

```bash
gcloud services enable run.googleapis.com artifactregistry.googleapis.com
gcloud config set run/region us-central1
```

`us-central1` : la sortie gratuite (1 Go par mois) est comptée « from North America ». Les exports
vers l'ordinateur d'entraînement sortent par là ; au-delà de 1 Go par mois, c'est payant (petites sommes).

**Alerte de budget** (conseillé) : console › Facturation › Budgets et alertes › budget de 1 € avec
alerte par courriel (<https://docs.cloud.google.com/billing/docs/how-to/budgets>).

### 3. L'image du récepteur

```bash
gcloud artifacts repositories create fikajiana --repository-format=docker --location=us-central1
gcloud auth configure-docker us-central1-docker.pkg.dev
docker build --platform linux/amd64 -f plateforme/Dockerfile \
  -t us-central1-docker.pkg.dev/fikajiana-dons-XXXX/fikajiana/dons:1 .
docker push us-central1-docker.pkg.dev/fikajiana-dons-XXXX/fikajiana/dons:1
```

L'image fait environ 230 Mo décompressée ; garder une ou deux versions pour rester sous 0,5 Go.

### 4. Les réglages

```bash
cp plateforme/exemple.cloudrun.env.yaml plateforme/cloudrun.env.yaml
chmod 600 plateforme/cloudrun.env.yaml
```

Remplir `FIKA_JETON_ADMIN` (tiré par `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`),
`FIKA_S3_ADRESSE` (avec l'Account ID), `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` (étape 1).
Ce fichier est ignoré par Git ; ne jamais le committer ni l'envoyer en clair.

### 5. Le lancement

```bash
gcloud run deploy fikajiana-dons \
  --image us-central1-docker.pkg.dev/fikajiana-dons-XXXX/fikajiana/dons:1 \
  --allow-unauthenticated --env-vars-file plateforme/cloudrun.env.yaml \
  --max-instances 1 --min-instances 0 --memory 512Mi --concurrency 20 --cpu-throttling
```

- `--max-instances 1` : la limite de débit est comptée en mémoire, dans une seule instance.
- `--min-instances 0` et `--cpu-throttling` : rien ne tourne (ni ne coûte) entre deux envois ; le
  premier envoi après une pause attend le démarrage (quelques secondes, non mesuré).
- La commande affiche l'adresse du service, de la forme `https://fikajiana-dons-….run.app` (HTTPS fourni).

### 6. Vérifier

```bash
curl https://fikajiana-dons-….run.app/v1/sante          # → {"ok": true}
```

### 7. Régler la lecture de l'IP (limite de débit)

```bash
curl -H "Authorization: Bearer LE_JETON" https://fikajiana-dons-….run.app/v1/mon-ip
curl https://ifconfig.me                                   # votre IP vue d'Internet
```

Si `ip` est votre IP : c'est bon. Sinon (une adresse Google), mettre `FIKA_DERRIERE_PROXY: "2"` dans
`cloudrun.env.yaml`, relancer l'étape 5 et revérifier. `/v1/mon-ip` ne garde rien et demande le jeton.

### 8. Ne pas garder les IP dans les journaux de Google

Console › **Logging › Routeur de journaux** › sink `_Default` › Modifier › **Ajouter une exclusion**,
nommée `dons-requetes`, avec le filtre :

```
resource.type="cloud_run_revision" AND log_id("run.googleapis.com/requests")
```

Ensuite, vérifier dans l'Explorateur de journaux qu'un nouvel envoi n'y crée plus d'entrée de requête.
Les journaux du récepteur lui-même (sans IP ni contenu) restent visibles.

### 9. Donner l'adresse et récupérer

- Mettre l'adresse `https://fikajiana-dons-….run.app` dans le réglage « adresse de la plateforme » de l'app.
- Sur l'ordinateur d'entraînement :
  `FIKA_DONS_ADRESSE=https://fikajiana-dons-….run.app FIKA_JETON_ADMIN=… uv run entrainement/recuperer_dons.py`.

### 10. Mettre à jour

Reconstruire avec une nouvelle étiquette (`dons:2`), `docker push`, relancer l'étape 5 avec la nouvelle
image, puis effacer l'ancienne dans Artifact Registry. Les dons sont dans R2 : rien n'est perdu.
