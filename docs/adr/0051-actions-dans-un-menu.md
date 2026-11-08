# ADR 0051 — Les actions proposées s'ouvrent d'un seul bouton

- **Date** : 2026-11-08 · **Statut** : accepté
- **Contexte** : sur le téléphone d'Antsa, la rangée de mots proposés (« résoudre factoriser dériver limite tracer ») passait à la ligne et s'écrivait sur les lignes et résultats voisins.
- **Décision** : un seul bouton de 48 dp, dessiné à la main (flèche qui descend puis avance : « écrire dessous » ; trois points : « au choix »), nommé pour TalkBack avec la liste des actions. Il ouvre un menu (`showMenu`) où chaque action s'écrit à la main avec, en petit, la ligne qu'elle posera ; le choix pose la ligne dessous comme avant.
- **Placement** : pour une expression écrite, le bouton se range avec 👍 et 👎 ; `placesJugement` leur réserve 48 dp de plus et cherche la place libre (encre, résultats, autres boutons évités). Une courbe aussi (vu sur le Pad 7 en format téléphone : « tracer », le bouton et le crayon passaient à la ligne). Sans place, il reste à droite de la ligne, ou entre « tracer » et le crayon.
- **Courbes et points** : « tracer » ou « placer » et le crayon passent sous la ligne quand le bord est trop près (`rangeeAction`), et comptent comme obstacle pour 👍/👎, qui peuvent se poser sous eux.
- **Écarté** : réduire les mots (illisibles) ; un panneau plein écran (cache la ligne).
- **Vérifié / Reste** : voir `docs/TODO.md` § 0 (tests, essai Pad 7).
