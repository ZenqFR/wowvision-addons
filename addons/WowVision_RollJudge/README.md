# WowVision Roll Judge (WowVision - Avis sur les jets de butin)

Extension de [WowVision](https://github.com/wow-vision/WowVision) pour **Sharpie's Gear Judge** (aussi en anglais et en allemand plus bas). Elle ne modifie aucun fichier de WowVision ni du Gear Judge : une mise à jour de l'un ou de l'autre ne l'efface pas.

**Pas encore essayée en jeu** : les tests simulent le jeu, les fenêtres de jet et le Gear Judge (dont j'ai lu l'interface publique et le code, mais que je n'ai pas fait tourner). Dites ce que vous entendez, je corrigerai.

## À quoi ça sert

En donjon, quand un objet est proposé au jet (Besoin, Cupidité, Passer), une touche **dit ce que le Gear Judge pense de cet objet pour votre personnage** : s'il améliore ce que vous portez ou non, de combien de pour cent, et à la place de quel objet. Les chiffres sont ceux de l'infobulle du Gear Judge. Exemples :

- « Bague du lion, amélioration de 4,2 pour cent, à la place de Vieille bague »
- « Lame de raid, régression de 3,1 pour cent, à la place de Épée usée »
- « Bague du lion, aucun changement, à la place de Vieille bague » (moins de 0,05 pour cent)
- « Bague du lion, amélioration de 40 pour cent, emplacement vide »
- « Casque, votre classe ne peut pas l'utiliser »

Le pourcentage est celui du Gear Judge : **de combien le personnage entier s'améliore** avec l'objet (négatif : il recule). Il tient compte de votre classe, de votre spécialité et de votre niveau (poids de statistiques, cap de toucher, talents), comme dans ses infobulles. Pour un personnage qui ne porte encore rien, le Gear Judge ne donne pas de pourcentage : on entend alors seulement « une amélioration » ou « une régression ».

## Les touches

| Touche | Effet |
|---|---|
| **Alt+Ctrl+J** | dit l'avis sur l'objet de la **première fenêtre de jet** ouverte (celle que prennent aussi les touches de WowVision : Alt+Ctrl+Y lit l'infobulle, U Besoin, I Cupidité, O Passer). Une fois cet objet joué, la touche passe au suivant. Sans fenêtre de jet : « Pas de butin. » |
| *(sans touche par défaut)* « Avis de Gear Judge sur tous les objets proposés au jet » | dit l'avis sur tous les objets proposés, numérotés : « Objet 1 sur 3, ... ; Objet 2 sur 3, ... » |
| `/wvjuge` (ou `/wvjudge`, `/wvurteil`) | pareil que la touche ; `/wvjuge tout` pareil que la deuxième touche ; `/wvjuge aide` dit à quoi ça sert |

Les touches se changent dans le menu de WowVision (`/wv`, Interface, Raccourcis).

**Pourquoi pas Alt+T ?** Alt+T est la touche « Ouvrir le menu de la cible » de WowVision (et Alt+Ctrl+T « Accepter l'échange »), et WowVision refuse deux actions sur une même touche. Alt+Ctrl+J est libre et dans la famille des touches de jet. Si vous voulez quand même Alt+T : dans Raccourcis, donnez d'abord une autre touche à « Ouvrir le menu de la cible », puis mettez Alt+T sur « Avis de Gear Judge sur l'objet proposé au jet ». Le test `tests/real_core.lua` vérifie que ce changement marche avec le vrai gestionnaire de touches de WowVision.

Si l'objet n'est pas encore chargé par le jeu, on entend « L'objet se charge. » puis l'avis quelques instants après (quatre essais, toutes les demi-secondes).

## Ce qu'il faut

- **Sharpie's Gear Judge** (version 3.2.7 ou plus récente), installé et **activé sur le personnage**. Sinon : « Gear Judge n'est pas installé ou n'est pas activé. » Sur vos personnages, d'après les fichiers de configuration, il n'était activé que sur Totem-Sansvue et Totem-Térieursansv.
- C'est tout : l'extension n'a pas d'autre réglage.

## Limites

- Elle ne lit que les **fenêtres de jet de groupe** (Besoin, Cupidité, Passer). Pas la fenêtre de butin d'un cadavre, ni un objet des sacs : pour cela, l'infobulle (Espace) montre déjà les lignes du Gear Judge.
- L'avis vaut ce que valent les poids du Gear Judge pour votre spécialité : c'est son jugement, pas une certitude.
- Pas de repli sur Pawn : seule l'opinion du Gear Judge est lue.
- L'allemand est ma traduction, non vérifiée par un germanophone.

## Tests

```
lua tests/run.lua        # tests hors du jeu (le jeu, les fenêtres de jet et le Gear Judge sont simulés)
lua tests/real_core.lua  # les touches avec le vrai gestionnaire d'entrées de WowVision
```

Depuis le dossier de l'extension, avec Lua 5.1 ou plus récent ; le dossier `WowVision` doit être à côté (pour `real_core.lua`).

---

## English

Extension for WowVision that says **what Sharpie's Gear Judge thinks of the item up for a group loot roll**: whether it improves what you wear, by how many percent, and in place of which item. It changes none of WowVision's or the Judge's files. **Not tried in the game yet**: the tests mock the game, the roll windows and the Judge (whose public interface and code I read, but did not run).

**Alt+Ctrl+J** says the verdict on the item in the first open roll window (the one WowVision's own roll keys act on: Alt+Ctrl+Y reads the tooltip, U needs, I greeds, O passes); once you have rolled on it, the next press takes the next item. A second action, "Gear Judge's verdict on every item up for a roll", has no key by default and says all of them, numbered. `/wvjuge` (or `/wvjudge`) does what the key does, `/wvjuge all` what the second action does. Examples: "Lion Ring, upgrade of 4.2 percent, instead of Old Ring"; "Raid Blade, downgrade of 3.1 percent, instead of Old Sword"; "Lion Ring, upgrade of 40 percent, empty slot"; "your class cannot use it". The percentage is the Judge's own: how much better the whole character gets (negative: worse), the same as in its tooltips. For a character that wears nothing yet the Judge gives no percentage, so you only hear "an upgrade" or "a downgrade".

Alt+T cannot be the default: WowVision's "Open Target Menu" has it (and Alt+Ctrl+T is "Accept Trade"), and WowVision refuses two actions on one key. To use it anyway, first give the target menu another key in the Bindings screen (`/wv`, Interface, Bindings), then put Alt+T on this action. If the game has not loaded the item yet you hear "The item is loading." and the verdict a moment later.

Needs Sharpie's Gear Judge 3.2.7 or later, installed and enabled on the character. Only group loot roll windows are read. No fallback on Pawn. Tests: `lua tests/run.lua` and `lua tests/real_core.lua` from this folder (WowVision next to it for the second).

---

## Deutsch

Erweiterung für WowVision, die sagt, **was Sharpie's Gear Judge von dem Gegenstand hält, um den in der Gruppe gewürfelt wird**: ob er verbessert, was du trägst, um wie viel Prozent und anstelle welches Gegenstands. Sie ändert keine Datei von WowVision oder des Gear Judge. **Im Spiel noch nicht ausprobiert**: Die Tests simulieren das Spiel, die Würfelfenster und den Gear Judge (dessen öffentliche Schnittstelle und Code ich gelesen, aber nicht ausgeführt habe).

**Alt+Strg+J** sagt das Urteil zum Gegenstand im ersten offenen Würfelfenster (dem, auf das auch die Würfeltasten von WowVision wirken: Alt+Strg+Y liest den Tooltip, U Bedarf, I Gier, O Passen); wenn du darauf gewürfelt hast, nimmt die nächste Betätigung den nächsten Gegenstand. Eine zweite Aktion, „Urteil von Gear Judge zu jedem Gegenstand, um den gewürfelt wird“, hat standardmäßig keine Taste und nennt alle, nummeriert. `/wvjuge` (oder `/wvurteil`) tut, was die Taste tut, `/wvjuge alle`, was die zweite Aktion tut. Beispiele: „Löwenring, Verbesserung um 4,2 Prozent, statt Alter Ring“; „Raidklinge, Verschlechterung um 3,1 Prozent, statt Altes Schwert“; „Löwenring, Verbesserung um 40 Prozent, Platz ist leer“. Der Prozentwert ist der des Gear Judge: um wie viel der ganze Charakter besser wird (negativ: schlechter), wie in seinen Tooltips. Für einen Charakter, der noch nichts trägt, nennt der Judge keinen Prozentwert, du hörst dann nur „eine Verbesserung“ oder „eine Verschlechterung“.

Alt+T kann nicht die Standardtaste sein: Sie gehört dem „Zielmenü öffnen“ von WowVision (und Alt+Strg+T dem „Handel annehmen“), und WowVision lehnt zwei Aktionen auf einer Taste ab. Um sie trotzdem zu nutzen, gib zuerst dem Zielmenü im Tastenbildschirm (`/wv`, Oberfläche, Tastenbelegung) eine andere Taste und lege dann Alt+T auf diese Aktion. Hat das Spiel den Gegenstand noch nicht geladen, hörst du „Der Gegenstand lädt.“ und kurz darauf das Urteil.

Benötigt Sharpie's Gear Judge ab Version 3.2.7, installiert und für den Charakter aktiviert. Gelesen werden nur die Würfelfenster der Gruppenbeute. Kein Rückgriff auf Pawn. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft. Tests: `lua tests/run.lua` und `lua tests/real_core.lua` in diesem Ordner (für die zweite WowVision daneben).
