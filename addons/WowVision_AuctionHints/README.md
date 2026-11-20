# WowVision AuctionHints (WowVision - À vendre à l'hôtel des ventes)

Extension de [WowVision](https://github.com/wow-vision/WowVision) et de **Life on Azeroth Market** (aussi en anglais et en allemand plus bas). Elle ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface pas.

## Ce qu'elle fait

Elle ajoute **un dernier arrêt** à l'écran des sacs de WowVision, que l'on atteint avec **Tab**, nommé **« À vendre à l'hôtel des ventes »**. Il liste les objets de vos sacs **qui se vendraient au moins 10 pour cent plus cher à l'hôtel des ventes que chez un marchand**, d'après le dernier relevé de prix de Life on Azeroth Market.

- C'est **le tout dernier arrêt** de l'écran des sacs (après les commandes, la recherche, les sacs, la barre des sacs, les « Listes d'objets » de WowVision_Bags, et même après la banque quand elle est ouverte). Maj+Tab depuis le premier arrêt y arrive donc d'un coup, et Tab depuis lui revient au premier.
- Le premier élément de l'arrêt est un **résumé**, dit en entrant : combien d'objets, le **gain total estimé**, **la date et l'ancienneté du relevé de prix**. Puis, dans une liste, **une ligne par objet** (même s'il est réparti sur plusieurs piles), le plus gros gain d'abord.
- L'arrêt est **toujours là** quand les sacs sont ouverts (hors combat) : s'il n'y a rien, il le dit ; sans Life on Azeroth Market, il dit pourquoi.

### Ce que dit une ligne

Le nom de l'objet, la **quantité totale** (et « en 3 piles » quand il y en a plusieurs), le **prix marchand** à l'unité, le **prix à l'hôtel des ventes** à l'unité **et en tout**, l'**écart en pour cent**, le **gain estimé** :

> Toile de lin, 14 au total en 3 piles : marchand 2 Argent l'unité, hôtel des ventes 50 Argent l'unité, 7 Or en tout, plus 2400 pour cent, gain estimé 6 Or 72 Argent

Un objet seul : « Anneau d'argent : marchand 5 Argent, hôtel des ventes 10 Argent, plus 100 pour cent, gain estimé 5 Argent ». Les sommes sont dites par le jeu comme le fait WowVision dans les sacs (Or, Argent, Cuivre).

**Action d'une ligne** : Entrée, le clic droit et le menu (Maj+F10) agissent sur **la première pile** de l'objet (le plus petit sac, puis le plus petit emplacement), comme sur la case dans les sacs : prendre l'objet, et, hôtel des ventes ouvert, le clic droit le met aux enchères. Quand cette pile est partie (vendue, mise aux enchères), la ligne passe à la pile suivante et garde sa place. Si les sacs changent pendant que vous êtes sur la ligne, elle est lue avec le libellé habituel des sacs jusqu'au prochain redessin.

## Les règles (toutes voulues)

1. **Le prix de l'hôtel des ventes** est le **« prix typique »** de Life on Azeroth Market, par objet (celui que montre son infobulle : le prix du milieu de tout ce qui est en vente, la moitié des offres est moins chère). C'est le dernier relevé, lu dans les données que l'application compagnon de Life on Azeroth écrit (`LOA_DATA`). L'hôtel des ventes est **celui de votre personnage** (type de royaume d'après son nom + faction) ; à défaut, celui que vous avez choisi dans Market, sinon le premier qu'il a. Si ce n'est pas le vôtre, le résumé le dit.
2. **Le prix marchand** est ce que le marchand **vous paie** quand vous lui vendez : le prix de vente du jeu (`GetItemInfo`), à l'unité.
3. Un objet est dans la liste si **le prix à l'hôtel des ventes, après la commission, est au moins 10 pour cent au-dessus du prix marchand** : prix hôtel × (100 − commission) ≥ prix marchand × 110, en cuivres entiers (exactement 10 pour cent est dedans, un cuivre de moins est dehors). Le **gain** est (prix hôtel après commission − prix marchand) × quantité, et l'écart en pour cent est lui aussi après commission. Les prix dits restent ceux de Market.
4. **Une pile vaut son prix à l'unité × sa quantité.** Les piles d'un même objet sont **additionnées** sur une seule ligne ; seules les piles qui peuvent aller à l'hôtel des ventes comptent (une pile liée n'est jamais comptée). Le seuil se juge sur le prix à l'unité : il est le même pour toutes les piles d'un objet.
5. **La commission de l'hôtel des ventes est déduite** (depuis le 20 novembre 2026, à la demande de l'utilisateur) : **5 pour cent**, **15 pour cent** à l'hôtel de Blackwater (les chiffres de Market). Le **dépôt n'est pas compté** : il revient quand l'objet se vend. Le résumé le dit à chaque fois (« après la commission de 5 pour cent de l'hôtel des ventes »), et chaque ligne dit « après commission » après son pourcentage. **Réglage** : `/wvhdv frais non` compare les prix tels quels, comme avant, `/wvhdv frais oui` redéduit la commission, `/wvhdv frais` bascule ; le réglage est retenu (variable `WowVisionAuctionHintsDB`) et la catégorie « À vendre au marchand » de WowVision_Bags le suit, puisqu'elle vient du même classement.
6. **Aucun objet lié n'est jamais listé.** Détection, la plus sûre possible, **plusieurs contrôles qui doivent tous dire « pas lié »** : (a) l'indicateur de la case lui-même, `C_Container.GetContainerItemInfo(...).isBound`, doit valoir exactement `false` (absent ou autre chose = lié) ; (b) le contrôle qu'Auctionator fait sur l'emplacement, `C_Item.IsBound(ItemLocation)`, ne doit pas dire vrai ; (c) le type de lien de l'objet (`GetItemInfo`, 14e valeur) doit être « aucun », « lié quand équipé » ou « lié quand utilisé » (la liste qu'Auctionator utilise : « lié quand ramassé », quête, lié au compte, etc. sont donc exclus) ; (d) un objet « lié au compte jusqu'à l'équiper » est exclu aussi. Le texte de l'infobulle (« lié à l'âme ») n'est **pas** lu : il dépend de la langue et se charge en retard, c'est la méthode la moins sûre. Un « lié quand équipé » **déjà porté** (donc lié) est exclu par (a). Au moindre doute, l'objet est exclu.
7. **Un objet abîmé** (durabilité pas au maximum) est exclu : l'hôtel des ventes le refuse tant qu'il n'est pas réparé.
8. **Un objet sans prix à l'hôtel des ventes n'est jamais listé.** Un objet **qu'aucun marchand ne rachète** (prix 0) **mais qui a un prix à l'hôtel des ventes** est listé, sans pourcentage (« le marchand ne le rachète pas ») : n'importe quel prix est plus que rien. C'est une décision, pas une évidence : dites-le si vous préférez qu'ils n'y soient pas.
9. **Un objet que le jeu n'a pas encore chargé** (prix marchand inconnu) n'est pas jugé ; le résumé dit combien il y en a.
10. **Relevé ancien** : le résumé donne toujours la date (« le 19 novembre à 23 h 00 ») et l'ancienneté (« il y a 3 heures »). Au-delà de **24 heures**, il commence par « Attention, ces prix sont anciens ». La date est celle du fichier de prix (comme « Prices 3 hours ago » de Market).
11. Un objet « du Singe / de l'Aigle » (même numéro d'objet, caractéristiques aléatoires) a le prix de son numéro d'objet : Market ne distingue pas les variantes.

Pas de liste en **combat** (WowVision y dessine sa propre liste).

## Commande

`/wvhdv` (ou `/wvah`, `/wvauktion`) dit le résumé, puis **où sont allés les emplacements de vos sacs** : combien de lignes dans la liste, sur combien d'emplacements, combien à vendre à un marchand, combien d'emplacements occupés, et pourquoi les autres ne sont pas dans la liste (liés, sans prix, sous le seuil, abîmés, pas encore chargés), puis si la commission est déduite. Elle marche sac fermé. Utile pour comprendre pourquoi un objet manque. `/wvhdv frais oui|non` (ou `fees on|off`, `gebuehren ja|nein`) règle la commission, sans mot elle bascule.

## Avec WowVision_Bags : la catégorie « À vendre au marchand »

Cette extension range **chaque emplacement occupé dans une seule des trois places**, avec **une seule fonction** (`Hints.classify`) : *hôtel des ventes* (cette liste), *marchand* (le marchand rachète, et l'objet n'est pas pour l'hôtel des ventes : lié, sans prix, sous le seuil, abîmé), ou *rien* (le marchand ne le rachète pas et il n'est pas pour l'hôtel des ventes). Elle offre le résultat par le global `WowVisionAuctionHints.partition(positions)`. **WowVision_Bags** s'en sert pour sa catégorie « À vendre au marchand » : l'union des deux listes est donc ce qui peut se vendre, et leur intersection est vide, par construction (testé, y compris sur 600 emplacements tirés au hasard, avec et sans commission, et sur le vrai écran des sacs). La catégorie du marchand est **elle aussi regroupée par objet** (« Toile de lin, 14 au total en 3 piles : marchand 2 Argent l'unité, 28 Argent en tout ») : le regroupement et la phrase viennent d'ici, et `partition` rend ces lignes dans `merchantLines` (version 2 du global).

## Comment elle s'accroche à WowVision

| Accroche | Ce qu'elle enveloppe |
|---|---|
| principale | la fonction `render` de l'écran de la fenêtre « bags » (module `containers`, `registeredWindows["bags"].graphScreen`) : l'arrêt est ajouté une fois que tout le reste est dessiné, donc **dernier**, quel que soit l'ordre de chargement des addons. La fenêtre copie sa configuration à l'ouverture ; l'enveloppe est donc dans la copie |
| de secours | si la fenêtre est introuvable : `renderGraph` du composant `RetailBags` (dernier des sacs, mais avant les arrêts de la banque) |

Les données de Life on Azeroth Market sont **lues sans être modifiées** (Market les décode lui-même quelques secondes après la connexion ; les deux états sont gérés). Dépendances : `WowVision` ; facultatifs : `WowVision_Bags` (ordre de chargement du repli), `LifeOnAzeroth_Market`, `LifeOnAzeroth_Data`.

## Tests

Depuis le dossier de l'extension, avec Lua 5.1 ou plus récent :

```
lua tests/run.lua        les règles, les textes, l'arrêt (le vrai Builder et le vrai KeyGraph de WowVision), le partage
lua tests/real_bags.lua  le VRAI écran des sacs de WowVision (containers, Bags.lua, Window, composants) + WowVision_Bags
lua tests/real_data.lua  les VRAIES données de Market, comparées à la lecture de Market lui-même (6684 objets)
```

`WOWVISION_DIR` pointe vers un autre dossier WowVision. **Pas encore essayé dans le jeu.** Les mots allemands sont ma traduction ; le français reprend les termes de WowVision (« Hôtel des ventes », « marchand »).

---

## English

Extension for WowVision and for **Life on Azeroth Market**; it changes none of WowVision's files.

It adds **one last stop** to WowVision's bags screen, reached with **Tab**, named **"For sale at the auction house"**. It lists the items in your bags that **would sell for at least 10 percent more at the auction house than to a vendor**, from Life on Azeroth Market's last price list.

- It is **the very last stop** of the bags screen (after the controls, the search box, the bags, the bag slot bar, WowVision_Bags' Item Lists, and after the bank too when it is open). Shift+Tab from the first stop lands on it at once.
- Its first element is a **summary**: how many items, the **total estimated gain**, and **the date and age of the price list**. Then a list with **one line per item** (however many stacks hold it), biggest gain first. The stop is always there while the bags are open (not in combat); with nothing to list, or without Market, it says so.

A line says the name, the **total quantity** ("in 3 stacks" when there are several), the **vendor price** each, the **auction house price** each **and in all**, the **difference in percent** and the **estimated gain**. Enter, right click and the menu act on the item's **first stack** (lowest bag, then lowest slot), as on the slot in the bags; when that stack is gone the line moves to the next one and keeps its place.

Rules: the auction house price is Market's **typical price** per item (the middle price of the current listings; your own auction house by realm kind and faction, else Market's pick, else its first); the vendor price is what a vendor pays (the game's sell price). An item is listed when the auction price after the auction house's cut is at least 10 percent above the vendor price: auction price × (100 − cut) ≥ vendor price × 110, in whole coppers; the gain and the percentage are after the cut too, the prices said are Market's. A stack is priced per item times its count, the stacks of an item are added up (a bound stack never counts). **The auction house's cut is taken off** (since 2026-11-20, at the user's request): 5 percent, 15 percent at the Blackwater house (Market's figures); the deposit is not counted, it comes back when an item sells. The summary says so every time and each line says "after the cut". Setting: `/wvhdv fees off` compares the prices as they are, `/wvhdv fees on` takes the cut off again, `/wvhdv fees` switches; it is saved (`WowVisionAuctionHintsDB`) and the merchant category of WowVision_Bags follows it, being made by the same classification. **Nothing bound is ever listed**: the slot's `isBound` flag must be exactly false, `C_Item.IsBound` on the item location (what Auctionator uses) must not say true, the item's bind type must be none, bind-on-equip or bind-on-use (Auctionator's list), and account-bound-until-equipped is out; any doubt = out (tooltip text is not read: it depends on the language and loads late). Damaged items are out (the auction house refuses them). No auction price: never listed. An item no vendor buys but that has an auction price is listed with no percentage (a decision, say if you disagree). Items the game has not loaded are not judged and are counted. The summary always gives the date and age of the prices and warns beyond 24 hours.

`/wvhdv` (`/wvah`, `/wvauktion`) says the summary and where the slots of your bags went (see the French section).

**With WowVision_Bags**: every occupied slot goes to exactly one of three places by one function (`Hints.classify`): auction house, vendor (a vendor buys it and it is not for the auction house) or neither; `WowVisionAuctionHints.partition(positions)` offers the result, and WowVision_Bags' "For sale to a merchant" category takes the vendor half, so the two lists never overlap; that category is also grouped by item ("Linen Cloth, 14 in 3 stacks: vendor 2 Silver each, 28 Silver in all"), the grouping and the sentence coming from here (`merchantLines`, version 2 of the global).

Tests: `lua tests/run.lua`, `lua tests/real_bags.lua` (WowVision's real bags screen), `lua tests/real_data.lua` (Market's real data). **Not tried in game yet.** German is my own translation.

## Deutsch

Erweiterung für WowVision und für **Life on Azeroth Market**; sie ändert keine Datei von WowVision.

Sie fügt dem Taschenbildschirm von WowVision **einen letzten Halt** hinzu, erreichbar mit **Tab**, genannt **„Zum Verkauf im Auktionshaus“**. Er listet die Gegenstände in Ihren Taschen auf, die **im Auktionshaus mindestens 10 Prozent mehr bringen würden als beim Händler**, nach der letzten Preisliste von Life on Azeroth Market.

- Es ist **der allerletzte Halt** des Taschenbildschirms (nach Steuerung, Suche, Taschen, Taschenleiste, den Gegenstandslisten von WowVision_Bags und bei geöffneter Bank auch nach der Bank). Umschalt+Tab vom ersten Halt aus führt sofort dorthin.
- Das erste Element ist eine **Zusammenfassung**: Anzahl der Gegenstände, **geschätzter Gesamtgewinn**, **Datum und Alter der Preisliste**. Danach eine Liste mit **einer Zeile pro Gegenstand** (egal auf wie viele Stapel er verteilt ist), größter Gewinn zuerst. Der Halt ist bei geöffneten Taschen immer da (nicht im Kampf); gibt es nichts oder fehlt Market, sagt er es.

Eine Zeile nennt Namen, **Gesamtmenge** („in 3 Stapeln“, wenn es mehrere gibt), **Händlerpreis** pro Stück, **Auktionshauspreis** pro Stück **und insgesamt**, **Unterschied in Prozent** und **geschätzten Gewinn**. Eingabe, Rechtsklick und Menü wirken auf den **ersten Stapel** des Gegenstands (kleinste Tasche, dann kleinster Platz), wie auf dem Platz in den Taschen; ist dieser Stapel weg, rückt die Zeile zum nächsten und behält ihren Platz.

Regeln: Der Auktionshauspreis ist der **typische Preis** von Market pro Gegenstand (Mittelwert der aktuellen Angebote; Ihr eigenes Auktionshaus nach Realmart und Fraktion, sonst Markets Wahl, sonst sein erstes); der Händlerpreis ist, was ein Händler zahlt (Verkaufspreis des Spiels). Ein Gegenstand steht in der Liste, wenn der Auktionspreis nach Abzug der Provision mindestens 10 Prozent über dem Händlerpreis liegt: Auktionspreis × (100 − Provision) ≥ Händlerpreis × 110, in ganzen Kupfer; Gewinn und Prozentwert verstehen sich ebenfalls nach der Provision, die genannten Preise sind die von Market. Ein Stapel zählt pro Stück mal Anzahl, die Stapel eines Gegenstands werden addiert (ein gebundener Stapel zählt nie). **Die Provision des Auktionshauses wird abgezogen** (seit dem 20.11.2026, auf Wunsch des Nutzers): 5 Prozent, 15 Prozent beim Blackwater-Haus (die Zahlen von Market); die Anzahlung wird nicht gezählt, sie kommt zurück, wenn ein Gegenstand verkauft wird. Die Zusammenfassung sagt es jedes Mal, jede Zeile sagt „nach Provision“. Einstellung: `/wvhdv gebuehren nein` vergleicht die Preise unverändert, `/wvhdv gebuehren ja` zieht die Provision wieder ab, `/wvhdv gebuehren` schaltet um; sie wird gespeichert (`WowVisionAuctionHintsDB`), und die Kategorie „Zum Verkauf beim Händler“ von WowVision_Bags folgt ihr, da sie aus derselben Einordnung kommt. **Nichts Gebundenes wird je aufgelistet**: das `isBound`-Flag des Platzes muss genau false sein, `C_Item.IsBound` am Gegenstandsplatz (wie bei Auctionator) darf nicht true sagen, die Bindungsart muss keine, beim Anlegen oder beim Benutzen sein (Auctionators Liste), „accountgebunden bis zum Anlegen“ ist ausgeschlossen; im Zweifel wird ausgeschlossen (Tooltip-Text wird nicht gelesen: sprachabhängig und spät geladen). Beschädigte Gegenstände sind ausgeschlossen (das Auktionshaus lehnt sie ab). Ohne Auktionspreis: nie aufgelistet. Ein Gegenstand, den kein Händler kauft, der aber einen Auktionspreis hat, wird ohne Prozentangabe aufgelistet (eine Entscheidung; sagen Sie Bescheid, wenn Sie es anders wollen). Vom Spiel noch nicht geladene Gegenstände werden nicht beurteilt, aber gezählt. Die Zusammenfassung nennt immer Datum und Alter der Preise und warnt nach 24 Stunden.

`/wvhdv` (`/wvah`, `/wvauktion`) sagt die Zusammenfassung und wohin die Plätze Ihrer Taschen gegangen sind (siehe den französischen Abschnitt).

**Mit WowVision_Bags**: jeder belegte Platz kommt durch eine einzige Funktion (`Hints.classify`) an genau einen von drei Orten: Auktionshaus, Händler (ein Händler kauft ihn und er ist nicht fürs Auktionshaus) oder keinen; `WowVisionAuctionHints.partition(positions)` bietet das Ergebnis an, und die Kategorie „Zum Verkauf beim Händler“ von WowVision_Bags nimmt die Händlerhälfte, sodass sich die beiden Listen nie überschneiden; auch diese Kategorie ist nach Gegenstand zusammengefasst („Linen Cloth, 14 insgesamt in 3 Stapeln: Händler 2 Silber pro Stück, 28 Silber insgesamt“), Zusammenfassung und Satz kommen von hier (`merchantLines`, Version 2 des Globals).

Tests: `lua tests/run.lua`, `lua tests/real_bags.lua` (der echte Taschenbildschirm von WowVision), `lua tests/real_data.lua` (die echten Daten von Market). **Noch nicht im Spiel ausprobiert.** Das Deutsche ist meine eigene Übersetzung.
