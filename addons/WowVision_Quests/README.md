# WowVision Quests (WowVision - Quêtes)

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais plus bas). Elle ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface pas.

Dans le scanner (F9), catégorie Quêtes, **En cours** :

- chaque quête dit **son niveau** après son titre : « Une menace venue de l'intérieur, Niveau 5 ». Le niveau vient du journal de quêtes, il peut être celui d'une quête adaptée : il est approximatif. Une quête sans niveau dans le journal garde son titre seul ;
- les quêtes sont classées **de la plus proche à la plus lointaine**, d'après l'endroit où Entrée vous emmènerait (le prochain objectif ouvert, ou le rendu de la quête une fois terminée). Une quête sans lieu connu, ou sur un autre continent, passe après les autres ; à distance égale, l'ordre du journal est gardé. Une quête presque terminée dont le rendu est tout près passe donc avant les autres.

La catégorie « À proximité » ne change pas.

## Commande

| Commande | Effet |
|---|---|
| `/wvquests` | dit si le tri par proximité est activé |
| `/wvquests on`, `/wvquests off` | active ou désactive le tri par proximité (activé par défaut, pour tous vos personnages) |

Le niveau est toujours dit.

## Comment elle s'accroche à WowVision

Elle enveloppe la construction de la catégorie Quêtes du scanner (`provider.build`, dans `WowVision.base.scanner.providers`) et la liste *En cours* qu'elle renvoie. Si WowVision intègre un jour son propre tri par proximité (`WowVision.quests.Adapter.sortByProximity`), l'extension le voit et ne fait plus rien.

## Tests

```
lua tests/run.lua
```

Depuis le dossier de l'extension, avec n'importe quel Lua 5.1 ou plus récent. Le jeu et WowVision sont simulés ; les fichiers de l'extension sont chargés pour de vrai.

---

## English

Extension for WowVision; it changes none of WowVision's files. In the scanner (F9), Quests, In Progress: each quest says its level after its title ("A Threat Within, Level 5") and the list comes nearest first, by where Enter would take you. `/wvquests on|off` switches the sorting (on by default). Run the tests with `lua tests/run.lua` from this folder.

## Deutsch

Erweiterung für WowVision; sie ändert keine Datei von WowVision. Im Scanner (F9), Quests, In Bearbeitung: Jede Quest nennt ihre Stufe nach dem Titel („A Threat Within, Stufe 5“), und die Liste kommt von der nächsten zur entferntesten, danach, wohin die Eingabetaste dich bringen würde. `/wvquests on|off` schaltet die Sortierung (standardmäßig an), auch mit `ja`/`nein`/`an`/`aus`. Tests: `lua tests/run.lua` in diesem Ordner. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft.

## Statut / Status

**Français** : cette fonction a été intégrée à WowVision (pull request wow-vision/WowVision#112, réglage « Sort Quests by Proximity »). Avec un WowVision récent, cet addon se met en retrait et ne fait rien ; il reste utile avec une version plus ancienne.

**English**: this feature was merged into WowVision (pull request wow-vision/WowVision#112, the "Sort Quests by Proximity" setting). With a recent WowVision this addon steps aside and does nothing; it stays useful with an older version.

**Deutsch**: Diese Funktion wurde in WowVision übernommen (Pull Request wow-vision/WowVision#112, Einstellung „Sort Quests by Proximity“). Mit einem aktuellen WowVision hält sich dieses Addon zurück und tut nichts; mit einer älteren Version bleibt es nützlich.
