# ADR 0066 — Retrait des dons d'écriture et de l'entraînement

- **Date** : 2026-11-14 · **Statut** : accepté (Antsa : « on n'a plus besoin de l'entraînement… juste une façon de mettre à jour le modèle depuis
  l'app » ; puis « Oui, retire-les »). Remplace ADR 0038 (petit modèle par signe), 0039, 0040, 0042 à 0045 pour l'envoi, la plateforme et l'entraînement.
- **Retiré** : la question des dons à l'installation, l'envoi des lignes jugées (`lib/dons/`), la section des dons dans les Réglages et son entrée
  au Guide, le récepteur Python et le Worker Cloudflare (`plateforme/`), l'entraînement (`entrainement/`), `tool/banc/references_rendu.py`,
  et leurs trois contrôles sur GitHub. Les anciens réglages des dons (case, adresse, identifiant) sont effacés de l'appareil au premier lancement.
- **Gardé** : 👍/👎 et les corrections, qui servent à lire la personne **sur l'appareil** (ADR 0041) ; « Exporter mes écritures » et « Effacer »,
  au format `collecte/FORMAT.md` ; le lecteur `ClasseurOnnx`, inactif sans poids (un modèle publié pourra le remplir, ADR 0064).
- **Conséquence** : l'encre ne quitte plus jamais l'appareil (`CLAUDE.md` § 5). Le modèle évolue par sa mise à jour depuis l'app (ADR 0064).
- **Reste pour Antsa** (son compte Cloudflare) : arrêter le Worker `fikajiana-dons` et vider le seau R2 `fikajiana-dons`
  (`npx wrangler delete`, puis le seau depuis le tableau de bord) ; les dons déjà reçus y sont encore.
