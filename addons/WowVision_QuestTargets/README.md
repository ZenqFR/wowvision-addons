# WowVision Quest Targets (WowVision - Cibles de quête)

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais plus bas). Elle ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface pas.

Une seule touche pour cibler les créatures proches **dont vos quêtes ont encore besoin**, de la plus proche à la plus lointaine : un monstre à tuer, ou un monstre qui laisse tomber un objet que vous n'avez pas encore en quantité suffisante. Une créature dont l'objectif est terminé n'est plus proposée.

## Les touches

Elles sont dans le menu de WowVision : `/wv` ou Maj+F1, Interface, Raccourcis. Vous pouvez les changer comme les autres.

| Touche | Effet |
|---|---|
| Alt+Q (« Cibler la cible de quête suivante ») | cible la plus proche. Appuyez encore : la suivante, de plus en plus loin, puis on recommence par la plus proche |
| Alt+Maj+Q (« Cibler la cible de quête précédente ») | cible la plus lointaine, puis la précédente |
| Ctrl+Alt+Q (« Dire les cibles de quête proches ») | dit combien il y en a, avec pour chacune son nom, sa distance et ce qu'il reste à faire (« Vermine kobold tuée : 3/8 »). Cinq au plus |

Quand vous ciblez, WowVision annonce la cible comme d'habitude (avec les « Noms de cible » que vous avez réglés), puis l'extension ajoute sa place dans la liste : « 2 sur 3 ». Rien n'est ajouté s'il n'y a qu'une créature. S'il n'y en a aucune, elle dit pourquoi : « Aucune cible de quête à proximité. »

## Ce qui compte comme cible de quête

Une créature est proposée quand : elle est vivante, vous pouvez l'attaquer, le jeu dit qu'elle sert à une de vos quêtes en cours (la même information que l'icône de quête sur sa barre de vie), et son infobulle ne liste pas que des objectifs déjà terminés. Les joueurs, les personnages amicaux et les cadavres ne sont pas proposés.

Ne sont pas couverts : les objets de quête (caisses, plantes... ce ne sont pas des créatures), et les personnages à qui il faut parler.

## Pourquoi les barres de vie des ennemis

Un addon ne peut pas demander au jeu « quelles créatures sont autour de moi ». Les barres de vie en sont le seul moyen : chacune donne une créature à part, et c'est ce qui permet de vérifier pour chacune qu'elle est vivante, qu'elle sert à une quête et que l'objectif n'est pas terminé. Un simple `/target nom` ne sait pas faire ça : il peut viser un cadavre, ou un monstre qui ne sert pas à vos quêtes.

Si les barres de vie des ennemis sont désactivées, l'extension les **active toute seule** (hors combat) à la première pression et le dit : « Appuyez encore ». Elles couvrent à peu près 40 mètres autour de vous. `/wvqt auto non` retire cette activation automatique (alors elle dit seulement comment faire), `/wvqt plaques` les active tout de suite.

## Une créature morte n'est jamais ciblée

Seules les créatures vivantes sont proposées. Si la plus proche est un cadavre, il est ignoré et c'est la plus proche vivante qui est ciblée.

## Hors combat

Cibler passe par un bouton sécurisé du jeu, dont le choix ne peut être fait qu'hors combat. En combat l'extension le dit et ne fait rien. Et en combat le jeu cache l'identité des ennemis (WowVision le sait aussi) : « En combat, le jeu cache les cibles de quête ».

## Si une créature n'est pas proposée : `/wvqt pourquoi`

Tapez `/wvqt pourquoi` (ou `/wvqt why`, `/wvqt diagnostic`) près de la créature. L'extension dit combien de créatures elle voit et combien elle en propose, puis lit les six plus proches avec, pour chacune, pourquoi elle est proposée ou écartée :

« Créatures vues : 3. Proposées : 1. Vermine kobold, à moins de 8 mètres : proposée. Loup, à moins de 12 mètres : ne sert à aucune de vos quêtes. Garde, à moins de 15 mètres : pas attaquable. »

Les raisons possibles : proposée, un joueur, pas attaquable, morte, ne sert à aucune de vos quêtes (le jeu le dit lui-même), aucun objectif en cours dans son infobulle, objectifs déjà terminés, valeurs cachées par le jeu (en combat). Elle ajoute aussi ce qui l'empêche de voir : barres de vie des ennemis désactivées, vous êtes en combat, un appel du jeu qui manque. Si elle ne voit aucune créature, elle le dit et rappelle ce qu'elle peut voir : votre cible, la créature sous la souris et les barres de vie des ennemis à portée.

Cette commande ne fait que lire : elle ne cible rien et ne change aucun réglage, pas même les barres de vie. Pour savoir pourquoi une créature précise est écartée, approchez-vous d'elle : ce sont les six plus proches qui sont lues.

## Commandes

| Commande | Effet |
|---|---|
| `/wvqt` | dit les cibles de quête proches (comme Ctrl+Alt+Q) |
| `/wvqt pourquoi` (ou `why`, `warum`, `diagnostic`) | dit ce qu'elle voit et pourquoi chaque créature est proposée ou écartée |
| `/wvqt plaques` (ou `plates`) | active les barres de vie des ennemis |
| `/wvqt auto non` (ou `auto oui`) | retire (ou remet) l'activation automatique des barres de vie |

## Comment elle s'accroche à WowVision

Les touches sont enregistrées auprès du gestionnaire de raccourcis de WowVision (`WowVision.input:createBinding`), comme celles de l'extension des sacs. Alt+Q et Alt+Maj+Q cliquent chacune un bouton sécurisé de type « cible » dont le champ `unit` est écrit juste avant le clic (`PreClick`), hors combat. Pour reconnaître les créatures, elle utilise `C_QuestLog.UnitIsRelatedToActiveQuest` et les lignes d'objectif de l'infobulle (`C_TooltipInfo.GetUnit`, le drapeau `completed`), comme les « Noms de cible » de WowVision, et LibRangeCheck pour les distances. Un appel qui manque dans le jeu ne retire que sa part.

## Tests

```
lua tests/run.lua
```

Depuis le dossier de l'extension, avec n'importe quel Lua 5.1 ou plus récent. Le jeu et WowVision sont simulés ; les fichiers de l'extension sont chargés pour de vrai.

---

## English

Extension for WowVision; it changes none of WowVision's files. One key targets the creatures near you that your quests still need (a kill, or an item they drop that you have not finished), nearest first: Alt+Q next, Alt+Shift+Q previous, Ctrl+Alt+Q says them all with their distance and what is left. The keys are in WowVision's Bindings screen. It needs enemy nameplates, which it turns on by itself out of combat (`/wvqt auto off` stops that; `/wvqt plates` turns them on now); a dead creature is never targeted, works out of combat, and does not cover quest objects or people to talk to. If a creature is not offered, `/wvqt why` reads out the nearest six creatures it sees and why each was kept or left out (dead, not for your quests, objectives complete, hidden by the game...), plus what stops it from seeing (nameplates off, combat, a missing game call); it only reads and changes nothing. Run the tests with `lua tests/run.lua` from this folder.

## Deutsch

Erweiterung für WowVision; sie ändert keine Datei von WowVision. Eine Taste visiert die Kreaturen in deiner Nähe an, die deine Quests noch brauchen (ein Kill oder ein Gegenstand, den sie fallen lassen und den du noch nicht fertig hast), die nächste zuerst: Alt+Q die nächste, Alt+Umschalt+Q die vorherige, Strg+Alt+Q nennt alle mit Entfernung und dem, was noch fehlt. Die Tasten stehen im Tastenbelegungsbildschirm von WowVision. Sie braucht die Namensplaketten der Gegner, die sie außerhalb des Kampfes von selbst einschaltet (`/wvqt auto aus` verhindert das; `/wvqt plaketten` schaltet sie sofort ein); eine tote Kreatur wird nie anvisiert, es funktioniert außerhalb des Kampfes und deckt weder Quest-Objekte noch Personen zum Ansprechen ab. Wird eine Kreatur nicht angeboten, liest `/wvqt warum` die sechs nächsten Kreaturen vor, die es sieht, und warum jede behalten oder ausgelassen wurde (tot, nicht für deine Quests, Ziele erfüllt, vom Spiel verborgen …), dazu, was das Sehen verhindert (Plaketten aus, Kampf, ein fehlender Spielaufruf); es liest nur und ändert nichts. Tests: `lua tests/run.lua` in diesem Ordner. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft.
