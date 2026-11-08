# Où héberger le récepteur des dons

Trois façons concrètes et peu coûteuses. **Rien n'est choisi ni installé** : la décision revient à
Antsa et à ses amis (ADR 0042). Pages consultées le **2026-11-08** ; les prix changent, les relire
avant de payer. Prix hors taxes sauf mention contraire.

Ce qu'il faut au récepteur : un conteneur de ~230 Mo (176 Mo sans S3), quelques requêtes par minute,
quelques Go de fichiers JSON au fil des mois, et HTTPS.

## Comparaison

| | A. Petit VPS + Docker | B. Conteneur gratuit + stockage objet | C. Chez soi + tunnel |
|---|---|---|---|
| Exemple | Hetzner CX23 ou OVHcloud VPS-1 | Google Cloud Run + Cloudflare R2 | Vieux PC ou Raspberry Pi + Tailscale Funnel |
| Coût | 3,81 € HT (4,57 € TTC) à 5,99 € HT par mois | 0 € dans les limites gratuites | 0 € (électricité) |
| Dons stockés | Disque du VPS (volume Docker) | R2 (S3), le disque de Cloud Run s'efface | Disque de la machine |
| HTTPS | Caddy (`compose.yaml`), automatique | Fourni par Cloud Run | Fourni par Funnel, chiffré jusqu'à la machine |
| Qui voit les dons en clair | L'hébergeur du disque (comme tout VPS) | Google (calcul) et Cloudflare (stockage) | Personne d'autre (Funnel) |
| Entretien | Mises à jour du système, sauvegardes | Presque rien ; carte bancaire demandée (non vérifié) | La machine doit rester allumée |
| Pas-à-pas ici | **Oui** (le plus simple) | Non (à écrire si choisi) | Non (à écrire si choisi) |

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
