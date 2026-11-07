# ADR 0031 — Les mots de commande écrits à la main

- **Date** : 2026-11-07 · **Statut** : accepté
- **Constat** (Pad 7) : Pix2Text-MFR ne lit que des formules. En cursive, `premier(17)` est lu `\wp^{\pi a m^{2}} \O \pi (17)`, `développer(…)` `\alpha \lim_{\log_1 \alpha_2}(…)` ; la partie entre parenthèses, elle, est bien lue.
- **Décision** : quand une ligne n'est pas comprise, on cherche un mot devant une grande parenthèse ouvrante (`mots.dart`). Le mot se reconnaît à sa silhouette dans une liste courte de commandes : hampes, jambages, points et accents, à leur place, et sa longueur. La parenthèse se lit seule par le modèle. Méthode classique des « word shapes » sur petit lexique, réécrite ici, sans dépendance.
- **Sûreté** : le mot n'est retenu que s'il est assez ressemblant et nettement devant le second ; sinon rien n'est choisi, et les trois plus proches sont proposés d'un toucher. Le calcul ne part jamais d'un mot deviné en silence.
- **Même classe** : `((…))` était pris pour une norme `‖…‖` ; une barre de norme doit maintenant être droite.
- **Affichage** (Antsa) : la lecture ne se réécrit plus sur la feuille ; elle se voit en touchant le résultat. `premier(17) = vrai` s'écrit à la main, et un résultat qui sortirait de l'écran passe dessous.
- **Vérifié** : traits réels d'Antsa (`test/fixtures/pad7`), deux mots sur deux. **Reste** : d'autres mains, et apprendre de chaque choix de l'utilisateur.
