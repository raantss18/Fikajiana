# ADR 0060 — Audit de sécurité et de robustesse (2026-11-14)

- **Date** : 2026-11-14 · **Statut** : accepté (demande d'Antsa : « tests de robustesse, vulnérabilités et CVE, puis corrige »)
- **CVE** : 240 dépendances (105 Dart, 91 npm, 44 Python) passées à la base OSV (https://api.osv.dev/v1/querybatch) : aucune faille connue ; ONNX Runtime 1.28.0 et MPFR 4.2.1 : rien.
  GMP 6.3.0 : CVE-2021-43618 corrigée depuis 6.2.1 ; Giac : CVE-2017-17526 touche l'interface Xcas, non compilée ici (écartées sur le numéro de version et la liste des fichiers compilés).
- **Corrigé** : (H1) entrée démesurée refusée avant Giac (`entreeDemesuree`), factorielle bornée à 2000 et entier de plus de 200 000 bits refusé dans la colle C, moteur
  « occupé » au lieu d'une file bloquée sans fin ; `catch (...)` dans la colle C. (M1) `canRequestPackageInstalls` gardé par l'API 26. (M2) ni sauvegarde dans le nuage ni
  transfert d'appareil (`allowBackup=false`, `dataExtractionRules`, https://developer.android.com/guide/topics/data/autobackup). (M3) Worker : débit par /64 en IPv6,
  200 dons par identifiant et par jour, pas de note de retrait pour un identifiant inconnu. (M4) écritures du magasin en file, ligne de mauvaise forme ignorée.
  (B2) mise à jour bornée en taille et en temps, cache vidé. (B3) `ouvrir` : `https` et `mailto` seulement. (B4) un seul `enregistrer` à la fois.
- **Laissé à Antsa** (consentement, ADR 0042) : le retour système sur la feuille de consentement applique la case cochée ; les lignes jugées avant le oui partent après le oui ;
  `debut` porte le décalage horaire ; l'identifiant de contributeur est gardé quand l'adresse de la plateforme change.
- **Reste** : redéployer le Worker (`npx wrangler deploy`, compte d'Antsa) ; mêmes quotas dans `plateforme/recepteur.py` ; actions GitHub épinglées par SHA ;
  exports d'écriture effacés avec « Effacer » ; essai des bornes de Giac sur appareil (`9999999!` → « trop grand »).
