# WowVision Target Direction (WowVision - Direction de la cible)

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais et en allemand plus bas). Elle ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface pas.

**Pas encore essayée en jeu** : les tests simulent le jeu et WowVision (le chercheur de position de WowVision et son gestionnaire de touches, eux, sont les vrais). Dites ce que vous entendez, je corrigerai.

## La touche

| Touche | Effet |
|---|---|
| **Ctrl+C** | dit où est votre cible, par exemple « Péon fainéant, 50 mètres, devant à gauche », et lance une **balise sonore** WowVision vers elle |

- Appuyez **encore** sur la même cible (ou sans cible) : la balise s'arrête (« Guidage arrêté »). Changez de cible et appuyez : la balise va vers la nouvelle. Maj+F12 (« annuler la navigation » de WowVision) l'arrête aussi.
- La touche est dans le menu de WowVision (`/wv`, Interface, Raccourcis, « Balise sonore vers votre cible ») : vous pouvez la changer. Ctrl+C sert aussi à copier dans les petites boîtes de texte de WowVision (« Copie maintenant ») ; là, la boîte a le clavier et la touche copie comme d'habitude.
- WowVision a déjà sa propre touche « Itinéraire vers votre cible » (sans touche par défaut) : elle calcule un trajet à pied avec WowNav. Celle-ci donne la direction à vol d'oiseau, au son.

## Comment la position est connue

Le jeu cache aux addons la vraie position de presque toute créature. L'extension passe donc par le chercheur de WowVision (celui de sa touche « Itinéraire vers votre cible ») :

- **un membre du groupe ou du raid** : sa vraie position, en direct. Quand il marche de plus de 8 mètres, la balise est réorientée (vérifié chaque seconde) ;
- **une créature que WowNav connaît** (sur WoW: Forever) : l'endroit connu le plus proche de cette créature, à moins de 120 mètres de vous. Pour un monstre qui se promène, c'est donc l'endroit où on le trouve d'habitude, pas forcément celui où il est maintenant ;
- **autre chose** (créature inconnue de WowNav, joueur hors groupe, objet) : « La position de votre cible n'est pas connue. » et rien ne démarre.

Les mots « devant à gauche », « derrière », « à droite » et la distance sont ceux de WowVision, dans sa langue.

## Commandes

`/wvtarget` (ou `/wvcible`, `/wvziel`) : comme la touche. `/wvtarget dire` (`say`, `sagen`) dit seulement où est la cible, sans balise. `/wvtarget stop` (`stopp`) arrête la balise.

## Tests

```
lua tests/run.lua        # tests hors jeu (le jeu et les cartes de WowVision sont simulés, son chercheur de cible est le vrai)
lua tests/real_core.lua  # la touche avec le vrai gestionnaire d'entrées de WowVision
```

Depuis le dossier de l'extension, avec Lua 5.1 ou plus récent ; le dossier `WowVision` doit être à côté (ou `WOWVISION_DIR` doit le désigner). L'allemand est ma traduction, non vérifiée par un germanophone.

---

## English

Extension for WowVision; it changes none of WowVision's files. **Not tried in the game yet**: the tests simulate the game and WowVision's maps (WowVision's own target finder and its input manager are the real ones).

**Ctrl+C** says where your target is ("Lazy Peon, 50 yards, ahead left") and starts a WowVision **sound beacon** toward it. Press it again on the same target (or with no target) to stop; change target and press to aim at the new one; Shift+F12 also stops it. The key is in WowVision's Bindings screen, so it can be changed (Ctrl+C also copies in WowVision's small "Copy now" boxes; there the box has the keyboard and the key copies as usual). WowVision already has a "Route to Your Target" key (unbound by default) that works out a walking route with WowNav; this one gives the straight-line direction, by ear.

The game hides the real position of almost every creature from addons, so the position comes from WowVision's own finder: a **group or raid member**'s real position, live (the beacon is aimed again each time they walk more than 8 yards, checked every second); a **creature WowNav knows** (on WoW: Forever), at the nearest spot WowNav has for it within 120 yards of you (for a wandering mob that is where it is usually found, not necessarily where it stands now); anything else: "Your target's position is not known." and nothing starts. The words for the direction and the distance are WowVision's.

`/wvtarget` (or `/wvcible`, `/wvziel`) does what the key does; `/wvtarget say` only says where the target is; `/wvtarget stop` ends the beacon. Tests: `lua tests/run.lua` and `lua tests/real_core.lua` from this folder (WowVision next to it, or `WOWVISION_DIR`).

---

## Deutsch

Erweiterung für WowVision; sie ändert keine Datei von WowVision. **Im Spiel noch nicht ausprobiert**: Die Tests simulieren das Spiel und die Karten von WowVision (der Zielfinder von WowVision und sein Eingabemanager sind die echten).

**Strg+C** sagt, wo dein Ziel ist („Fauler Peon, 50 Meter, voraus links“), und startet ein **Klangsignal** von WowVision dorthin. Nochmal auf dasselbe Ziel (oder ohne Ziel) drücken beendet es; Ziel wechseln und drücken richtet es auf das neue aus; Umschalt+F12 beendet es ebenfalls. Die Taste steht im Tastenbelegungsbildschirm von WowVision und lässt sich ändern (Strg+C kopiert auch in den kleinen „Jetzt kopieren“-Feldern von WowVision; dort hat das Feld die Tastatur, und die Taste kopiert wie gewohnt). WowVision hat schon eine eigene Taste „Route zu deinem Ziel“ (standardmäßig unbelegt), die mit WowNav einen Fußweg berechnet; diese hier gibt die Richtung in Luftlinie, nach Gehör.

Das Spiel verbirgt die echte Position fast jeder Kreatur vor Addons, die Position kommt deshalb vom eigenen Finder von WowVision: die echte Position eines **Gruppen- oder Schlachtzugsmitglieds**, live (das Signal wird neu ausgerichtet, sobald es mehr als 8 Meter läuft, jede Sekunde geprüft); bei einer **Kreatur, die WowNav kennt** (auf WoW: Forever), der nächste von WowNav bekannte Ort innerhalb von 120 Metern um dich (bei einem umherstreifenden Monster ist das, wo man es üblicherweise findet, nicht unbedingt, wo es jetzt steht); alles andere: „Die Position deines Ziels ist nicht bekannt.“, und nichts startet. Die Wörter für Richtung und Entfernung stammen von WowVision.

`/wvtarget` (oder `/wvcible`, `/wvziel`) tut, was die Taste tut; `/wvtarget sagen` sagt nur, wo das Ziel ist; `/wvtarget stopp` beendet das Signal. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft. Tests: `lua tests/run.lua` und `lua tests/real_core.lua` in diesem Ordner (WowVision daneben oder `WOWVISION_DIR`).
