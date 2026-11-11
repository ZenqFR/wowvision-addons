# WowVision Bags (WowVision - Sacs)

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais plus bas). Elle ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface pas.

Elle ajoute aux sacs (et à la banque) :

1. **un arrêt « Listes d'objets »**, **juste après les sacs** (ouvrir les sacs arrive donc sur leurs objets ; Tab passe ensuite à la barre des sacs, puis aux listes, puis à la recherche et aux commandes), avec des catégories : *Nouveaux objets* (ouverte au début), *Camelote* et *Favoris*. *Nouveaux objets* reprend ce que le jeu signale comme nouveau **et** ce que l'extension voit arriver dans vos sacs (butin, achat, courrier, **récompense de quête**…) : le jeu ne signale pas tout, la récompense d'une quête en tête. L'extension compte ce que les sacs contiennent de chaque objet après chaque changement ; un objet dont il y a maintenant plus qu'avant est nouveau, sur toutes les cases qui le contiennent. Déplacer, trier ou scinder des objets n'en fait pas des nouveaux. Ils restent dans la liste tant que les sacs n'ont pas été ouverts puis refermés, même s'ils sont fermés au moment de l'arrivée. Une catégorie vide n'apparaît pas, et s'il n'y en a aucune l'arrêt n'existe pas. Droite ouvre une catégorie, gauche la ferme, comme dans le scanner. Chaque objet y est lu comme dans les sacs.
2. **la camelote** : sur un objet, **Maj+Entrée** le marque (ou retire la marque). L'objet est dit avec « [Camelote] » devant son nom. Chez un marchand, la camelote marquée est **vendue toute seule** à l'ouverture de la fenêtre, et ce qui a été vendu est dit (noms et somme).
3. **les favoris** : sur un objet, **Maj+Retour arrière** le marque (ou retire la marque). L'objet est dit avec « [Favori] » devant son nom, et se retrouve dans la catégorie *Favoris*. **Un favori n'est jamais vendu**, même s'il est aussi marqué camelote.

La marque est sur **l'objet** (pas sur la case) : si vous en avez un deuxième exemplaire, ailleurs, il est marqué aussi. Les marques sont retenues **par personnage**. Un objet qui n'a pas de prix chez les marchands ne peut pas être marqué camelote (la marque promettrait une vente qui n'aura pas lieu), mais peut être favori. Un objet à la fois favori et camelote se dit « [Favori] [Camelote] ».

Le menu contextuel d'un objet (Maj+F10) propose aussi « Marquer comme camelote » et « Marquer comme favori ».

## Les touches

Les deux touches sont dans le menu de WowVision : `/wv` ou Maj+F1, Interface, Raccourcis (« Sélectionner camelote » et « Sélectionner favori »). Vous pouvez les changer comme les autres.

## Commandes

| Commande | Effet |
|---|---|
| `/wvbags` | dit l'état des trois options |
| `/wvbags nouveaux` (ou `new`) | dit les noms des nouveaux objets que l'extension a vus arriver et que vous n'avez pas encore regardés (pour vérifier le suivi) |
| `/wvbags camelote` (ou `junk`) | active ou désactive les marques de camelote |
| `/wvbags vente` (ou `sell`) | active ou désactive la vente de la camelote marquée chez les marchands |
| `/wvbags favoris` (ou `favorites`) | active ou désactive les favoris |
| `/wvbags favoris off`, `/wvbags vente on` | force un état |
| `/wvbags oublier camelote` (ou `forget junk`) | retire toutes les marques de camelote |
| `/wvbags oublier favoris` (ou `forget favorites`) | retire tous les favoris |

Désactiver une option cache ses marques et sa touche, mais ne les efface pas. Un favori reste protégé de la vente même si les favoris sont désactivés.

## Ce qui reste à WowVision

- Les objets de qualité médiocre (gris) : si le réglage « Vendre automatiquement les objets médiocres » de WowVision est activé, c'est WowVision qui les vend, comme avant. Cette extension ne vend que ce que vous avez marqué, et laisse à WowVision un objet marqué qui est aussi gris.
- La réparation automatique.

## Comment elle s'accroche à WowVision

Quatre accroches, indépendantes : l'une qui ne peut pas être posée (WowVision a changé) est signalée une fois et les autres continuent.

| Accroche | Ce qu'elle enveloppe |
|---|---|
| cases d'objets | `containers.itemSlotNode` et `containers.renderSlots` (le module des sacs de WowVision) |
| arrêt Listes d'objets | `renderGraph` et `isOpen` du composant `RetailBags` (registre `containers`). L'arrêt est inséré avant le premier arrêt « recherche » ou « commandes » (sacs combinés), ou après le dernier sac (un cadre par sac) |
| vente | `onEvent` du module `merchant` (événement `MERCHANT_SHOW`) |
| touches | `WowVision.input:createBinding` (le registre des raccourcis que lit l'écran Raccourcis) |

Si WowVision intègre un jour ses propres listes d'objets (`WowVision.bagLists` ou un module `junk`), l'extension le voit et ne fait plus rien.

Les marques sont dans `WowVisionBagsDB` (par personnage). À la première utilisation, les marques de camelote que la version modifiée de WowVision gardait dans ses propres données sont recopiées une fois.

## Tests

```
lua tests/run.lua
```

Depuis le dossier de l'extension, avec n'importe quel Lua 5.1 ou plus récent. Le jeu et WowVision sont simulés ; les fichiers de l'extension sont chargés pour de vrai. Aucun autre addon n'est nécessaire.

---

## English

Extension for WowVision; it changes none of WowVision's files, so a WowVision update does not remove it.

It adds to the bags and the bank: an **Item Lists** stop (right after the bags, so opening them lands on their items; categories New Items, Junk, Favorites, empty ones hidden; New Items holds what the game flags as new and what the addon sees arrive in the bags by counting each item after every change, such as a quest's reward, which the game does not flag; `/wvbags new` names them), **junk marks** (Shift+Enter marks the item under the cursor, "[Junk]" is said ahead of its name, and marked junk is sold by itself when a merchant window opens) and **favorites** (Shift+Backspace, "[Favorite]", listed under Favorites, never sold). Marks belong to the item, not the slot, and are kept per character in `WowVisionBagsDB`. Both keys are in WowVision's Bindings screen. `/wvbags` switches each part on or off and forgets marks (see the table above). Poor quality (grey) items and repairs stay WowVision's own business.

Run the tests with `lua tests/run.lua` from this folder.

## Deutsch

Erweiterung für WowVision; sie ändert keine Datei von WowVision, ein Update von WowVision entfernt sie also nicht.

Sie ergänzt Taschen und Bank um einen Halt **Gegenstandslisten** (direkt nach den Taschen, sodass man beim Öffnen bei den Gegenständen landet; Kategorien Neue Gegenstände, Plunder, Favoriten, leere werden ausgeblendet; „Neue Gegenstände“ enthält, was das Spiel als neu markiert, und was das Addon ankommen sieht, indem es nach jeder Änderung die Gegenstände in den Taschen zählt, etwa die Belohnung einer Quest, die das Spiel nicht markiert; `/wvbags new` nennt sie), um **Plundermarkierungen** (Umschalt+Eingabe markiert den Gegenstand unter dem Cursor, „[Plunder]“ wird vor seinem Namen gesagt, und markierter Plunder wird von selbst verkauft, sobald ein Händlerfenster aufgeht) und um **Favoriten** (Umschalt+Rücktaste, „[Favorit]“, unter „Favoriten“ aufgelistet, nie verkauft). Die Markierungen gehören zum Gegenstand, nicht zum Platz, und werden pro Charakter in `WowVisionBagsDB` gespeichert. Beide Tasten stehen im Tastenbelegungsbildschirm von WowVision. `/wvbags` schaltet jeden Teil an oder aus und vergisst Markierungen (siehe die Tabelle oben). Graue Gegenstände und Reparaturen bleiben Sache von WowVision.

Tests: `lua tests/run.lua` in diesem Ordner. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft.
