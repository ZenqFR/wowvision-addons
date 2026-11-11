# WowVision Vitals (WowVision - Vie et ressource en pourcentage)

> **RETIRÉ / RETIRED / EINGESTELLT : ne pas installer / do not install / nicht installieren.**
> Sur WoW: Forever, le jeu cache la vie et la ressource du joueur aux addons (valeurs « secrètes ») : cette extension ne peut donc pas les lire, et elle **déplace** en plus les touches de changement de buffer de WowVision (Alt+Gauche/Droite) vers Alt+Maj+Gauche/Droite, ce qu'il faut ensuite défaire à la main. Elle est gardée ici pour mémoire, avec ses tests.
> On WoW: Forever the game hides the player's health and resource from addons ("secret" values), so this addon cannot read them, and it also **moves** WowVision's buffer keys (Alt+Left/Right) to Alt+Shift+Left/Right, which then has to be undone by hand. It is kept here for the record, with its tests.
> Auf WoW: Forever verbirgt das Spiel Leben und Ressource des Spielers vor Addons („geheime“ Werte); dieses Addon kann sie deshalb nicht lesen und **verschiebt** außerdem die Buffer-Tasten von WowVision (Alt+Links/Rechts) auf Alt+Umschalt+Links/Rechts, was man danach von Hand rückgängig machen muss. Es ist nur zur Dokumentation hier, mit seinen Tests.

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais plus bas). Elle ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface pas.

| Touche | Effet |
|---|---|
| Alt+Gauche | dit votre vie en pourcentage : « Vie 85 pour cent » |
| Alt+Droite | dit votre mana, ou votre ressource principale (rage, énergie...), en pourcentage : « Mana 72 pour cent » |

Elles sont dans le menu de WowVision : `/wv` ou Maj+F1, Interface, Raccourcis (« Dire la vie en pourcentage » et « Dire la mana ou la ressource en pourcentage »). Vous pouvez les changer comme les autres.

## Ce que faisaient Alt+Gauche et Alt+Droite dans WowVision

Ils changent de **buffer** : « Buffer précédent » et « Buffer suivant ». Un buffer est une liste d'informations que WowVision vous laisse parcourir. Les buffers sont rangés dans des groupes ; par défaut il n'y a qu'un groupe, « Général », qui ne contient qu'un buffer, « Général » aussi. Alt+Gauche et Alt+Droite passent donc au buffer suivant du groupe... qui est le même, et WowVision relit le nom du buffer et l'élément où vous étiez. D'où l'impression de répétition.

Les autres touches du même ensemble :

- Alt+Haut et Alt+Bas : l'élément précédent ou suivant dans le buffer. Le buffer « Général » contient, dans l'ordre : vie, ressource, expérience, argent, sacs, durabilité, courrier, pierre de foyer, horloge, JcJ. La vie et la ressource y sont lues en points (« 850/1000 Vie »), pas en pourcentage.
- Alt+Ctrl+Gauche et Alt+Ctrl+Droite : le groupe précédent ou suivant.

## Ce que cette extension change

WowVision ne laisse pas une touche faire deux choses. La première fois, l'extension déplace donc le changement de buffer : **Buffer précédent passe sur Alt+Maj+Gauche, Buffer suivant sur Alt+Maj+Droite**. Rien d'autre ne bouge : Alt+Haut, Alt+Bas, Alt+Ctrl+Gauche et Alt+Ctrl+Droite restent comme avant.

Le déplacement est enregistré avec vos touches, comme si vous l'aviez fait dans l'écran Raccourcis. Si vous préférez rendre Alt+Gauche au buffer précédent : dans Raccourcis, ouvrez « Buffer précédent », choisissez Ajouter, tapez Alt+Gauche, et confirmez le remplacement. L'extension respecte ce choix aux démarrages suivants.

Si Alt+Gauche ou Alt+Droite servait déjà à autre chose que le changement de buffer, ou si Alt+Maj+Gauche ou Alt+Maj+Droite est déjà pris, l'extension ne déplace rien : la touche reste libre dans Raccourcis, à vous de l'ajouter.

## Le pourcentage

Il est arrondi, mais jamais « 0 » tant qu'il vous reste de la vie ou de la ressource, jamais « 100 » tant qu'il en manque : ces deux mots veulent dire « mort ou vide » et « plein ». La ressource est la principale de votre forme actuelle : la mana pour un mage, l'énergie pour un druide en félin. Une classe sans ressource entend « Aucune ressource à lire ». En combat, le jeu peut cacher certaines valeurs : « Le jeu cache cette valeur ».

## Commandes

| Commande | Effet |
|---|---|
| `/wvvitals` (ou `/wvvie`) | dit la vie puis la ressource : « Vie 85 pour cent. Mana 72 pour cent » |

## Comment elle s'accroche à WowVision

Les touches sont enregistrées auprès du gestionnaire de raccourcis de WowVision (`WowVision.input:createBinding`), comme celles des autres extensions. Sur WoW: Forever, les touches sauvegardées du compte arrivent après le chargement des addons et WowVision les relit alors ; l'extension surveille cette relecture (`WowVision:applyBindingStore`) et, si une de ses touches se retrouve sur la même touche que le changement de buffer, déplace ce dernier. Sans cela, au premier démarrage, les deux se seraient retrouvés sur Alt+Gauche.

## Tests

```
lua tests/run.lua
```

Depuis le dossier de l'extension, avec n'importe quel Lua 5.1 ou plus récent. Le jeu et WowVision sont simulés ; les fichiers de l'extension sont chargés pour de vrai.

---

## English

Extension for WowVision; it changes none of WowVision's files. Alt+Left says your health in percent, Alt+Right says your mana (or main resource) in percent; both are in WowVision's Bindings screen.

In WowVision, Alt+Left and Alt+Right are "Previous Buffer" and "Next Buffer". With the default single "General" buffer they only re-read the current item, which is why they feel like a repeat (Alt+Up and Alt+Down walk the items, Alt+Ctrl+Left and Right the groups; the General buffer reads health and resource in points, not percent). WowVision lets a key do one thing only, so the first time this extension moves the buffer keys to Alt+Shift+Left and Alt+Shift+Right, saved with your keys like a change made in the Bindings screen; give Alt+Left back to "Previous Buffer" there and it stays that way. It also repairs a clash when WoW: Forever hands the account's saved keys over late. The percentage never says 0 while something is left or 100 while something is missing. `/wvvitals` says both. Run the tests with `lua tests/run.lua` from this folder.

---

## Deutsch

Eingestellte Erweiterung für WowVision (siehe oben). Alt+Links sagte das Leben in Prozent („Leben 85 Prozent“), Alt+Rechts die Mana oder Hauptressource („Mana 72 Prozent“); `/wvvitals` sagte beides. Weil WowVision einer Taste nur eine Funktion erlaubt, verschob sie beim ersten Start „Vorheriger Buffer“ und „Nächster Buffer“ auf Alt+Umschalt+Links/Rechts. Um diese Tasten zurückzugeben: Tastenbelegung von WowVision, „Vorheriger Buffer“ / „Nächster Buffer“ öffnen, Hinzufügen, Alt+Links bzw. Alt+Rechts drücken, den Austausch bestätigen. Auf WoW: Forever sind Leben und Ressource für Addons verborgen, deshalb wurde sie eingestellt. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft.
