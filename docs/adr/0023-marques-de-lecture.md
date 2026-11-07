# ADR 0023 — Lueur et trait ondulé à la place du cercle et du `?`

- **Date** : 2026-11-07 · **Statut** : accepté, à juger par Antsa sur le Pad 7
- **Pourquoi** : Antsa n'aime pas le petit `?` ni le petit cercle : ils ne disent rien et s'ajoutent à côté de l'écriture.
- **Lecture et calcul** : une lueur passe sous ce qui est écrit, comme un surligneur. Sans animation, elle reste posée. « Arrêter » n'apparaît qu'après 1,5 s de calcul, avec son nom.
- **À vérifier** : un trait ondulé sous l'écriture, en forme donc pas seulement en couleur. Il s'écrit une fois. Le toucher ouvre un panneau : ce qui a été lu, « Corriger », « Effacer » (avec Annuler).
- **Stylet** : la lueur et le trait laissent passer le stylet ; un toucher ne laisse pas de point (ADR 0021).
- **Choix écarté** : se taire si la ligne ne finit pas par `=`. Un `=` mal lu n'aurait alors aucun signal.
- **Lecteur d'écran** : le trait est un bouton nommé par son état.
