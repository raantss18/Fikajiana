# ADR 0043 — Récepteur de référence des dons d'écriture

- **Date** : 2026-11-08 · **Statut** : accepté (réversible ; l'hébergement reste à choisir par Antsa et ses amis)
- **Contexte** : l'ADR 0042 envoie les lignes jugées vers une plateforme ; il faut un récepteur libre, petit, sûr et facile à héberger.
- **Décision** : Python + Waitress (ZPL 2.1), application WSGI en bibliothèque standard (`plateforme/`), un fichier JSON par don dans `dons/<identifiant>/`, sur disque ou stockage S3 (boto3, facultatif). Pas de base de données. `compose.yaml` avec Caddy pour HTTPS.
- **Schéma** : `collecte/FORMAT.md` réduit à une liste blanche (`plateforme/schema.py`) ; `auteur` est **refusé** (prénom), `contributeur` (16–64 caractères au hasard) obligatoire, `version_app` permis. Tout champ inconnu fait refuser le don.
- **Vie privée** : IP en mémoire le temps de la fenêtre de débit seulement ; journal sans IP ni contenu ; Caddy sans journal d'accès. Un identifiant retiré est refusé ensuite (410) : l'app en tire un nouveau.
- **Entraînement** : `entrainement/recuperer_dons.py` (export à jeton, retraits, tri) range dans `donnees/ecriture/dons/`, lu sans changement par `entrainer.py`.
- **Écarté** : Go (un binaire, mais une seconde langue à relire) ; `http.server` (« not recommended for production ») ; SQLite (inutile pour des fichiers ajoutés puis effacés par préfixe).
- **Sources** : `plateforme/HEBERGER.md`, `plateforme/LISEZMOI.md`.
