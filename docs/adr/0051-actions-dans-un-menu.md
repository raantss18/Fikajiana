# ADR 0051 — Un seul bouton par ligne, une seule liste

- **Date** : 2026-11-08, revu le 2026-11-09 · **Statut** : accepté
- **Contexte** : sur le téléphone d'Antsa, la rangée de mots proposés passait sur les lignes voisines ; avec un bouton d'actions rangé près de 👍/👎, les pouces se chevauchaient encore. Antsa : « dans la même liste déroulante, même l'option de modification ».
- **Décision** : chaque ligne écrite a un seul bouton de 48 dp, dessiné à la main (flèche « écrire dessous », trois points « au choix »), nommé pour TalkBack avec son état et ses entrées. Il ouvre une liste (`showMenu`) : juste, faux (ouvre la correction), corriger, les autres lectures, tracer/voir ou placer, puis les actions proposées (résoudre, dériver…), chacune écrite à la main, avec en petit la ligne qu'elle posera. Plus de 👍/👎, de crayon ni de mot posé à côté de la ligne. Une ligne tapée garde sa formule écrite, le bouton à côté.
- **État** : « à confirmer » reste un pointillé sous la ligne ; jugée juste, le bouton porte une coche, jugée fausse une croix (forme et couleur, règle 9).
- **Placement** : `placesJugement` cherche une place de 48 dp à gauche, dessous, dessus ou après le résultat, sans encre, résultat, ligne tapée ni autre bouton ; sinon plus bas puis plus haut, jusqu'à en trouver une : chaque ligne a son bouton.
- **Écarté** : réduire les mots (illisibles) ; un panneau plein écran (cache la ligne).
- **Vérifié / Reste** : voir `docs/TODO.md` § 0.
