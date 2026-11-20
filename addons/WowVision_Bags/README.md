# WowVision Bags (WowVision - Sacs)

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais plus bas). Elle ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface pas.

Elle ajoute aux sacs (et à la banque) :

1. **un arrêt « Listes d'objets »**, **juste après les sacs** (ouvrir les sacs arrive donc sur leurs objets ; Tab passe ensuite à la barre des sacs, puis aux listes, puis à la recherche et aux commandes), avec deux catégories : *Nouveaux objets* (ouverte au début) et *À vendre au marchand*. *Nouveaux objets* reprend ce que le jeu signale comme nouveau **et** ce que l'extension voit arriver dans vos sacs (butin, achat, courrier, **récompense de quête**…) : le jeu ne signale pas tout, la récompense d'une quête en tête. L'extension compte ce que les sacs contiennent de chaque objet après chaque changement ; un objet dont il y a maintenant plus qu'avant est nouveau, sur toutes les cases qui le contiennent. Déplacer, trier ou scinder des objets n'en fait pas des nouveaux. Ils restent dans la liste tant que les sacs n'ont pas été ouverts puis refermés, même s'ils sont fermés au moment de l'arrivée. Une catégorie vide n'apparaît pas, et s'il n'y en a aucune l'arrêt n'existe pas. Droite ouvre une catégorie, gauche la ferme, comme dans le scanner. Chaque objet y est lu comme dans les sacs (avec ses étiquettes « [Camelote] » et « [Favori] »).

   **À vendre au marchand** (depuis le 20 novembre 2026 ; elle remplace les catégories *Camelote* et *Favoris*, qui n'existent plus : les marques, les étiquettes, les touches et la vente automatique, elles, n'ont pas changé) : les objets de vos sacs **que le marchand rachète** (prix de rachat supérieur à zéro) et qui **ne sont pas dans l'onglet « À vendre à l'hôtel des ventes »** de l'extension WowVision_AuctionHints. Y entrent donc les objets **liés** (jamais vendables à l'hôtel des ventes), ceux **sans prix connu** à l'hôtel des ventes, ceux dont le prix à l'hôtel des ventes est **à moins de 10 pour cent** au-dessus du prix marchand, et les objets **abîmés** (l'hôtel des ventes les refuse tant qu'ils ne sont pas réparés). N'y entrent ni ce que l'hôtel des ventes paierait au moins 10 pour cent de plus, ni ce qu'aucun marchand ne rachète. **Un favori n'y figure pas** : un favori n'est jamais vendu, le proposer « à vendre » serait faux (cela reste vrai quand les favoris sont désactivés). Un objet marqué camelote y est, comme les autres. Les deux listes viennent **de la même fonction de classement** (dans WowVision_AuctionHints) : un objet est dans l'une ou dans l'autre, jamais dans les deux. Les objets sont dans l'ordre des sacs, **une ligne par objet** même s'il est réparti sur plusieurs piles (« Toile de lin, 14 au total en 3 piles : marchand 2 Argent l'unité, 28 Argent en tout » ; le regroupement et la phrase viennent de WowVision_AuctionHints). Entrée, le clic droit et le menu agissent sur la **première pile** (le plus petit sac, puis le plus petit emplacement) ; quand elle est partie, la suivante prend la tête. Les piles d'un favori ne sont jamais dans une ligne. La commission de l'hôtel des ventes est déduite (réglage de WowVision_AuctionHints, `/wvhdv frais`) avant de décider qu'un objet est « pour l'hôtel des ventes » : un objet à peine au-dessus de 10 pour cent hors commission est donc ici. **Sans WowVision_AuctionHints (non installé ou désactivé), cette catégorie reste vide**, donc n'apparaît pas ; sans relevé de prix de Life On Azeroth Market, elle contient tout ce qu'un marchand rachète.
2. **la camelote** : sur un objet, **Maj+Entrée** le marque (ou retire la marque). L'objet est dit avec « [Camelote] » devant son nom. Chez un marchand, la camelote marquée est **vendue toute seule** à l'ouverture de la fenêtre, et ce qui a été vendu est dit (noms et somme).
3. **les favoris** : sur un objet, **Maj+Retour arrière** le marque (ou retire la marque). L'objet est dit avec « [Favori] » devant son nom. **Un favori n'est jamais vendu**, même s'il est aussi marqué camelote.

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

It adds to the bags and the bank: an **Item Lists** stop (right after the bags, so opening them lands on their items; categories New Items and For sale to a merchant, empty ones hidden; New Items holds what the game flags as new and what the addon sees arrive in the bags by counting each item after every change, such as a quest's reward, which the game does not flag; `/wvbags new` names them), **junk marks** (Shift+Enter marks the item under the cursor, "[Junk]" is said ahead of its name, and marked junk is sold by itself when a merchant window opens) and **favorites** (Shift+Backspace, "[Favorite]", never sold). Marks belong to the item, not the slot, and are kept per character in `WowVisionBagsDB`. Both keys are in WowVision's Bindings screen. `/wvbags` switches each part on or off and forgets marks (see the table above). Poor quality (grey) items and repairs stay WowVision's own business.

**For sale to a merchant** (since 2026-11-20; it replaces the Junk and Favorites categories, which are gone, while the marks, the tags, the keys and the automatic sale are unchanged): the items in your bags that **a vendor buys** (sell price above zero) and that are **not in the "For sale at the auction house" tab** of WowVision_AuctionHints. So it holds the **bound** items (never auctionable), those with **no known auction house price**, those whose auction house price is **less than 10 percent** above the vendor price, and **damaged** items (the auction house refuses them until repaired); it does not hold what the auction house would pay at least 10 percent more for, nor what no vendor buys. **A favorite is not in it** (a favorite is never sold, so offering it "for sale" would be wrong, even with the favorites switched off); an item marked as junk is, like any other. Both lists come from **the same classification function** (in WowVision_AuctionHints): an item is in one or the other, never both. Items are in bag order, **one line per item** however many stacks hold it ("Linen Cloth, 14 in 3 stacks: vendor 2 Silver each, 28 Silver in all"; the grouping and the sentence come from WowVision_AuctionHints). Enter, the right click and the menu act on the **first stack** (lowest bag, then lowest slot); when it is gone the next one leads. The stacks of a favorite are never in a line. The auction house's cut is taken off (a setting of WowVision_AuctionHints, `/wvhdv fees`) before an item is called "for the auction house": an item just over 10 percent before the cut is therefore here. **Without WowVision_AuctionHints (not installed or not enabled) the category stays empty**, so it does not show; without price data from Life on Azeroth Market it holds everything a vendor buys.

Run the tests with `lua tests/run.lua` from this folder.

## Deutsch

Erweiterung für WowVision; sie ändert keine Datei von WowVision, ein Update von WowVision entfernt sie also nicht.

Sie ergänzt Taschen und Bank um einen Halt **Gegenstandslisten** (direkt nach den Taschen, sodass man beim Öffnen bei den Gegenständen landet; Kategorien Neue Gegenstände und Zum Verkauf beim Händler, leere werden ausgeblendet; „Neue Gegenstände“ enthält, was das Spiel als neu markiert, und was das Addon ankommen sieht, indem es nach jeder Änderung die Gegenstände in den Taschen zählt, etwa die Belohnung einer Quest, die das Spiel nicht markiert; `/wvbags new` nennt sie), um **Plundermarkierungen** (Umschalt+Eingabe markiert den Gegenstand unter dem Cursor, „[Plunder]“ wird vor seinem Namen gesagt, und markierter Plunder wird von selbst verkauft, sobald ein Händlerfenster aufgeht) und um **Favoriten** (Umschalt+Rücktaste, „[Favorit]“, nie verkauft). Die Markierungen gehören zum Gegenstand, nicht zum Platz, und werden pro Charakter in `WowVisionBagsDB` gespeichert. Beide Tasten stehen im Tastenbelegungsbildschirm von WowVision. `/wvbags` schaltet jeden Teil an oder aus und vergisst Markierungen (siehe die Tabelle oben). Graue Gegenstände und Reparaturen bleiben Sache von WowVision.

**Zum Verkauf beim Händler** (seit dem 20.11.2026; ersetzt die Kategorien Plunder und Favoriten, die es nicht mehr gibt; Markierungen, Zusätze, Tasten und automatischer Verkauf sind unverändert): die Gegenstände in Ihren Taschen, die **ein Händler kauft** (Verkaufspreis über null) und die **nicht im Reiter „Zum Verkauf im Auktionshaus“** von WowVision_AuctionHints stehen. Also **gebundene** Gegenstände (nie auktionierbar), solche **ohne bekannten Auktionshauspreis**, solche mit einem Auktionshauspreis **unter 10 Prozent** über dem Händlerpreis und **beschädigte** (das Auktionshaus lehnt sie bis zur Reparatur ab); nicht dabei sind Gegenstände, für die das Auktionshaus mindestens 10 Prozent mehr zahlt, und solche, die kein Händler kauft. **Ein Favorit ist nicht dabei** (ein Favorit wird nie verkauft, ihn „zum Verkauf“ anzubieten wäre falsch, auch bei ausgeschalteten Favoriten); als Plunder markierte Gegenstände sind dabei wie alle anderen. Beide Listen kommen **aus derselben Einordnungsfunktion** (in WowVision_AuctionHints): ein Gegenstand steht in der einen oder der anderen, nie in beiden. Reihenfolge der Taschen, **eine Zeile pro Gegenstand**, egal auf wie viele Stapel er verteilt ist („Linen Cloth, 14 insgesamt in 3 Stapeln: Händler 2 Silber pro Stück, 28 Silber insgesamt“; Zusammenfassung und Satz kommen von WowVision_AuctionHints). Eingabe, Rechtsklick und Menü wirken auf den **ersten Stapel** (kleinste Tasche, dann kleinster Platz); ist er weg, rückt der nächste nach. Die Stapel eines Favoriten stehen nie in einer Zeile. Die Provision des Auktionshauses wird abgezogen (Einstellung von WowVision_AuctionHints, `/wvhdv gebuehren`), bevor ein Gegenstand „fürs Auktionshaus“ heißt: ein Gegenstand knapp über 10 Prozent vor der Provision steht daher hier. **Ohne WowVision_AuctionHints (nicht installiert oder nicht aktiviert) bleibt die Kategorie leer** und wird nicht angezeigt; ohne Preisdaten von Life on Azeroth Market enthält sie alles, was ein Händler kauft. Das Deutsche ist meine eigene Übersetzung.

Tests: `lua tests/run.lua` in diesem Ordner. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft.
