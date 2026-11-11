# WowVision Localized Names

Extension de [WowVision](https://github.com/wow-vision/WowVision) pour WoW: Forever (aussi en anglais plus bas).

## Le problème

La navigation de WowVision (la liste F10, les trajets WowNav, F10 depuis le journal de quêtes) nomme les PNJ, les monstres et les objets avec les données de WowNav. Ces données n'ont que **l'anglais et l'allemand** : sur un client français, « Lazy Peon » est dit en anglais, alors que les phrases autour (« Entrée de donjon : … », « Passage vers … ») sont déjà en français.

## Ce que fait l'extension

Chaque cible de WowNav porte l'identifiant du PNJ ou de l'objet. Questie (QuestieDB) contient les mêmes PNJ et objets par identifiant, avec leur nom dans la langue du jeu. L'extension demande ce nom à Questie et l'utilise à la place de l'anglais :

- dans la liste F10 (le nom lu et le texte de recherche : on peut chercher en français, et toujours en anglais) ;
- dans les annonces de trajet (« Arrivé : … ») ;
- partout où WowNav nomme une cible, y compris F10 depuis le journal de quêtes.

Concerne les PNJ, monstres, objets, plantes, minerais et boîtes aux lettres. Les noms bâtis sur un modèle (entrées de donjon, portails, quais, passages) sont déjà traduits par WowVision et ne sont pas touchés. Ce que WowNav ajoute autour d'un nom (le numéro ou « (haut) » qui distingue deux cibles semblables) est conservé.

**Si Questie ne connaît pas l'identifiant, le nom de WowNav reste.** Questie ne contient pas tous les PNJ du jeu : les plus courants (donneurs de quêtes, marchands, monstres de quêtes) y sont, des créatures rares peuvent manquer et resteront en anglais.

Les clients anglais et allemands ne sont pas touchés (WowNav a déjà ces deux langues). Les autres langues que Questie connaît (espagnol, italien, portugais, russe, coréen, chinois) en profitent aussi.

## Conditions

- **Questie** doit être installé et actif (c'est déjà le cas chez vous).
- La langue de Questie doit être sur **Auto** (réglage par défaut) ou la même que celle du jeu. Si vous avez forcé Questie dans une autre langue, ou tant que Questie n'a pas fini de démarrer, l'extension ne l'utilise pas et les noms restent ceux de WowNav, puis passent en français dès que Questie est prêt.

## Commande

| Commande | Effet |
|---|---|
| `/wvnames` | dit si les noms localisés sont activés |
| `/wvnames off` / `/wvnames on` | désactive / active (réglage conservé) |

## Installation

Dossier `Interface\AddOns\WowVision_LocalizedNames`, à côté de `WowVision`. Tapez `/reload` en jeu. Aucun fichier de WowVision n'est modifié : l'extension enveloppe `WowVision.wownavText.targetName`, la fonction par laquelle WowNav demande tous ses noms. Une mise à jour de WowVision ne l'efface donc pas.

## Tests

```
lua tests/run.lua
```

Les tests simulent le jeu et Questie mais chargent le vrai `camelot/wownav/text.lua` de WowVision. L'un d'eux vérifie aussi que le code de WowNav demande bien ses noms à travers cette fonction.

---

## English

WoW: Forever extension. WowNav's catalogues name creatures and objects in English and German only, so a client in another language hears English names in WowVision's navigation list (F10) and route announcements. Each target carries its creature or object ID; this extension asks Questie's database (`NpcDB` / `ObjectDB`) for the name in the game's language and uses it, keeping WowNav's name when Questie does not know the ID. Questie's language must be Auto (or the game's). English and German clients are left alone. `/wvnames [on|off]` switches it.

## Deutsch

Erweiterung für WoW: Forever. Die Kataloge von WowNav nennen Kreaturen und Objekte nur auf Englisch und Deutsch; ein Client in einer anderen Sprache hört deshalb in der Navigationsliste von WowVision (F10) und in den Routenansagen englische Namen. Jedes Ziel trägt die ID seiner Kreatur oder seines Objekts; diese Erweiterung fragt die Datenbank von Questie (`NpcDB` / `ObjectDB`) nach dem Namen in der Spielsprache und verwendet ihn, und behält den Namen von WowNav, wenn Questie die ID nicht kennt. Die Sprache von Questie muss auf Auto (oder auf der des Spiels) stehen. Englische und deutsche Clients bleiben unberührt, denn WowNav nennt dort schon alles in der eigenen Sprache. `/wvnames [on|off]` schaltet sie, auch mit `ja`/`nein`/`an`/`aus`.

Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft.

## Statut / Status

**Français** : cette fonction a été intégrée à WowVision (pull request wow-vision/WowVision#113, réglage « Names in Your Language »). Avec un WowVision récent, cet addon se met en retrait et ne fait rien, pour que le réglage de WowVision soit le seul qui compte ; il reste utile avec une version plus ancienne.

**English**: this feature was merged into WowVision (pull request wow-vision/WowVision#113, the "Names in Your Language" setting). With a recent WowVision this addon steps aside and does nothing, so that WowVision's own setting is the only one that counts; it stays useful with an older version.

**Deutsch**: Diese Funktion wurde in WowVision übernommen (Pull Request wow-vision/WowVision#113, Einstellung „Names in Your Language“). Mit einem aktuellen WowVision hält sich dieses Addon zurück und tut nichts, damit nur die Einstellung von WowVision zählt; mit einer älteren Version bleibt es nützlich.
