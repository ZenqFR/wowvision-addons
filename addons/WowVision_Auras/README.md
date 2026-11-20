# WowVision Auras (WowVision - Améliorations et affaiblissements)

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais et en allemand plus bas). Elle ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface pas. Elle ne touche ni à vos tampons enregistrés, ni à vos touches.

## À quoi ça sert

Consulter **facilement toutes les améliorations (buffs) et tous les affaiblissements (debuffs) de votre personnage**, sans avoir à fabriquer un tampon dans le menu de WowVision. Les mots sont ceux que WowVision emploie déjà dans son tampon d'auras : « Améliorations du joueur » et « Affaiblissements du joueur ».

## Les touches

| Touche | Ce qu'elle fait |
|---|---|
| **Alt+Ctrl+B** | **dit tout** : « Améliorations du joueur : 4. » puis chacune, « Affaiblissements du joueur : 1. » puis chacun. Chaque aura est dite comme dans le tampon d'auras de WowVision : son **nom**, ses **cumuls** (« 2 cumuls »), son **temps restant**, et pour un affaiblissement son **type de dissipation** (Magie, Malédiction, Maladie, Poison). |
| **Alt+Maj+B** | **ouvre la liste** : deux arrêts (Tab passe de l'un à l'autre), les améliorations puis les affaiblissements, une ligne par aura, avec « 1 sur 4 ». **Espace** lit la description complète de l'aura où vous êtes (son infobulle, ligne par ligne avec Maj+flèches, comme partout dans WowVision). **Échap** ferme. Même touche une seconde fois : ferme. |

Une catégorie vide le dit (« Améliorations du joueur, aucun »). Les deux touches sont dans le menu de WowVision : `/wv` ou Maj+F1, Interface, Raccourcis (« Dire les améliorations et affaiblissements du joueur », « Ouvrir la liste des améliorations et affaiblissements du joueur ») ; vous pouvez les changer comme les autres. Aucune des deux n'est prise par WowVision ni par vos autres extensions (vérifié contre le vrai gestionnaire de touches de WowVision, `tests/real_core.lua`).

## La commande

| Commande | Effet |
|---|---|
| `/wvauras` (ou `/wvbuffs`, `/wvauren`) | ouvre la liste, ou la ferme si elle est ouverte |
| `/wvauras dire` (ou `say`, `sagen`, `tout`, `all`, `alle`) | dit tout, comme Alt+Ctrl+B |
| `/wvauras nombre` (ou `count`, `anzahl`) | ne dit que les nombres : « Améliorations du joueur : 4. Affaiblissements du joueur : 1. » |
| `/wvauras aide` (ou `help`, `hilfe`) | rappelle ces commandes |

## Comment ça lit les auras (et en combat)

WowVision sait déjà lire les améliorations et les affaiblissements, **même quand le jeu les cache** : sur WoW: Forever, en combat et en instance, le jeu ferme la liste des auras aux addons et ne donne que des valeurs « secrètes » (on peut les dire à voix haute, mais pas les comparer ni les mesurer). Son tampon d'auras (`core/buffers/types/AuraBuffer.lua`) contourne cela comme le jeu le permet : lecture par numéro quand elle est permise, sinon l'infobulle du jeu, et les cumuls lus sur les boutons d'aura de Blizzard. **Cette extension ne relit rien elle-même** : elle fait faire deux tampons d'auras à WowVision, un pour vos améliorations et un pour vos affaiblissements, **jamais enregistrés** (rien n'est ajouté à vos tampons, aucun fichier de sauvegarde n'est changé), et affiche ce qu'ils listent. Ils se tiennent à jour tout seuls (WowVision les refait quand le jeu dit que les auras du joueur ont changé) ; l'extension relit en plus le jeu à chaque appui sur la touche et à l'ouverture de la liste.

À savoir :
- **En combat**, le temps restant et les cumuls dépendent de ce que le jeu laisse lire (comme dans le tampon d'auras de WowVision) ; une valeur illisible est dite « indisponible » plutôt que devinée. **Non essayé en jeu** : tout est testé hors du jeu avec le vrai code du tampon d'auras de WowVision, des valeurs secrètes simulées et un refus de lecture simulé.
- Ce sont les auras **du joueur**. Celles de la cible, de la focalisation ou du familier restent dans le tampon d'auras de WowVision (Alt+flèches ; à créer dans `/wv`, Tampons, ajouter un tampon d'auras : ses « sources » sont réglables).
- La **description** d'une aura n'est pas dite dans la liste dite d'un coup (trop longue) : elle est sur Espace dans la liste ouverte.
- Le temps restant n'est pas surveillé pendant que vous êtes sur une ligne (il serait redit chaque seconde) : il est dit quand vous arrivez dessus.

## Tests

Depuis le dossier de l'extension, avec Lua 5.1 ou plus récent :

```
lua tests/run.lua        les lignes, les phrases, l'écran (le vrai moteur d'écrans de WowVision) et le VRAI tampon d'auras de WowVision
lua tests/real_core.lua  les touches, avec le vrai gestionnaire de touches de WowVision et les 87 touches déjà prises
```

`WOWVISION_DIR` pointe vers un autre dossier WowVision. Mutations : 100, seuls 3 cas équivalents survivent. **Pas encore essayé dans le jeu.** Les mots allemands sont ma traduction ; le français reprend ceux de WowVision.

---

## English

Extension for WowVision; it changes none of WowVision's files, none of your saved buffers and none of your keys.

**Hear or browse every buff and debuff on your character**, without building a buffer in WowVision's menu. The words are WowVision's own from its Aura buffer.

- **Alt+Ctrl+B** says everything: "Player Buffs: 4." then each, "Player Debuffs: 1." then each. Each aura is said the way WowVision's Aura buffer says it: name, stacks, time left and, for a debuff, its dispel type.
- **Alt+Shift+B** opens a list: two tab stops (buffs, debuffs), one line per aura with its place ("1 of 4"). **Space** reads the full description of the aura you are on (its tooltip, line by line with the shift-arrow keys, as everywhere in WowVision). Escape, or the same key again, closes it.
- `/wvauras` (or `/wvbuffs`) opens or closes the list, `/wvauras say` says everything, `/wvauras count` only the numbers, `/wvauras help` the commands.

How it reads: WowVision's Aura buffer already reads auras under the game's secret values (combat, instances) and this addon asks WowVision for two such buffers of its own (the player's buffs, the player's debuffs), never saved among your buffers, and shows what they list; they keep themselves up to date and are read again at each key press. In combat the time left and the stacks depend on what the game lets be read; an unreadable value is said as "unavailable" and never guessed. The target's, focus's and pet's auras stay in WowVision's own Aura buffer (Alt+arrows). Tests: `lua tests/run.lua` (with WowVision's real Aura buffer) and `lua tests/real_core.lua` (the real input manager); 100 mutations, 3 equivalent survivors. **Not tried in game yet.** German is my own translation.

## Deutsch

Erweiterung für WowVision; sie ändert keine Datei von WowVision, keine Ihrer gespeicherten Puffer und keine Ihrer Tasten.

**Alle Buffs und Debuffs Ihres Charakters bequem hören oder durchgehen**, ohne im Menü von WowVision erst einen Puffer anlegen zu müssen. Die Wörter sind die, die WowVision in seinem Auren-Puffer selbst benutzt.

- **Alt+Strg+B** sagt alles: „Spieler-Buffs: 4.“ dann jeden, „Spieler-Debuffs: 1.“ dann jeden. Jede Aura wird so gesagt wie im Auren-Puffer von WowVision: Name, Stapel, Restzeit und bei einem Debuff die Bannart.
- **Alt+Umschalt+B** öffnet eine Liste: zwei Halte (Buffs, Debuffs), eine Zeile pro Aura mit ihrer Position („1 von 4“). Die **Leertaste** liest die ganze Beschreibung der gewählten Aura (ihren Tooltip, mit den Umschalt+Pfeiltasten zeilenweise, wie überall in WowVision). Esc oder dieselbe Taste noch einmal schließt.
- `/wvauras` (oder `/wvbuffs`) öffnet oder schließt die Liste, `/wvauras sagen` sagt alles, `/wvauras anzahl` nur die Anzahlen, `/wvauras hilfe` die Befehle.

Wie gelesen wird: Der Auren-Puffer von WowVision liest Auren bereits unter den geheimen Werten des Spiels (Kampf, Instanzen); dieses Addon lässt sich von WowVision zwei solche Puffer geben (Buffs und Debuffs des Spielers), die nie unter Ihren Puffern gespeichert werden, und zeigt, was sie auflisten; sie halten sich selbst aktuell und werden bei jedem Tastendruck neu gelesen. Im Kampf hängen Restzeit und Stapel davon ab, was das Spiel lesen lässt; ein nicht lesbarer Wert wird als „nicht verfügbar“ gesagt, nie geraten. Die Auren von Ziel, Fokus und Begleiter bleiben im Auren-Puffer von WowVision (Alt+Pfeile). Tests: `lua tests/run.lua` (mit dem echten Auren-Puffer von WowVision) und `lua tests/real_core.lua` (der echte Tastenmanager); 100 Mutationen, 3 äquivalente Überlebende. **Noch nicht im Spiel ausprobiert.** Das Deutsche ist meine eigene Übersetzung.
