# WowVision RestedXP (WowVision - RestedXP)

Extension de [WowVision](https://github.com/wow-vision/WowVision) pour utiliser le guide de niveau **RestedXP** (l'addon « RestedXP Guides », dossier `RXPGuides`) avec un lecteur d'écran. Aussi en anglais plus bas. Elle ne modifie aucun fichier de WowVision ni de RestedXP : une mise à jour de l'un ou de l'autre ne l'efface pas.

**Rien de tout cela n'a été essayé en jeu** : les tests simulent le jeu, RestedXP et WowVision (voir « Tests »). Dites ce que vous entendez, je corrigerai.

## Les touches

| Touche | Effet |
|---|---|
| **Maj+F2** | ouvre (ou ferme) le menu RestedXP, l'écran principal |
| Alt+F2 | dit l'étape en cours |
| Ctrl+F2 | dit où pointe la flèche : « Parlez à Ailee, à 2 heures, à droite, 35 mètres » |
| Ctrl+Maj+F2 | **balise sonore** vers la destination de la flèche (appuyer encore l'arrête) |
| Alt+Maj+F2 | **itinéraire WowVision** vers la destination de la flèche (appuyer encore l'arrête) |
| Alt+Ctrl+F2 | le menu du clic droit de RestedXP (les guides, les conseils...) |

Sans touche par défaut, à régler dans WowVision (`/wv`, Interface, Raccourcis) : arrêter le guidage, passer l'étape, étape suivante, étape précédente. Toutes les touches de la liste se changent là aussi.

Les commandes : `/wvrxp` ouvre le menu, `/wvrxp etape`, `/wvrxp fleche`, `/wvrxp balise`, `/wvrxp itineraire`, `/wvrxp stop`, `/wvrxp temps` (voir « Si le jeu rame »).

## Le menu RestedXP (Maj+F2)

Un écran de WowVision, comme son propre menu : flèches haut et bas pour parcourir, Tab pour passer d'une partie à la suivante, Entrée pour agir, flèche droite pour ouvrir un groupe, flèche gauche pour le fermer, Échap pour sortir, une lettre pour sauter à l'entrée qui commence par elle. Les parties, dans l'ordre :

1. **Guide** : le nom du guide et « Étape 12 sur 340 », puis les étapes actives. Chaque ligne à faire est une case : Entrée la coche (c'est la case « passer » de la fenêtre RestedXP), encore une fois la décoche. Une ligne cochée par RestedXP lui-même est grisée : elle se lit « terminé » et ne se change pas. Les lignes d'information (sans case) se lisent simplement. Les conseils (« Conseil ») sont là aussi.
2. **Flèche** : où pointe la flèche, mis à jour en direct pendant que vous marchez ; « Balise sonore vers la destination » ; « Itinéraire WowVision vers la destination » ; « Arrêter le guidage » (présent seulement quand un guidage tourne) ; la case « Recalculer le guidage quand la flèche change de destination » (cochée par défaut) et la case « Ignorer les petits déplacements de la flèche (moins de 10 mètres) » (décochée par défaut), voir « La flèche ».
3. **Se déplacer dans le guide** : passer l'étape affichée, étape précédente, étape suivante, aller à l'étape numéro (flèches gauche et droite pour changer de numéro, Entrée pour taper le numéro), « Étapes à venir » (les cinq suivantes).
4. **Objets à utiliser**, **Ennemis à cibler**, **Personnages amis à cibler** (seulement quand RestedXP en propose) : Entrée utilise l'objet ou cible la créature, comme un clic sur la case de la fenêtre RestedXP.
5. **Menu RestedXP** : le menu du clic droit. Les guides sont rangés en groupes (groupe, sous-groupe, guide) ; Entrée sur un guide le charge. « Afficher les conseils » et les autres cases du menu y sont aussi.
6. **Réglages de RestedXP** : tous ses réglages, avec les mêmes onglets, cases, curseurs, listes, champs et boutons que sa fenêtre de réglages.
7. **Aide parlée** : les réglages de cette extension (dire chaque nouvelle étape ; dire où pointe la flèche quand elle change).

Ce que cette extension laisse de côté, parce que RestedXP l'ouvre dans ses propres fenêtres inutilisables au clavier : le rapport de niveau, l'assistant de configuration, le formulaire de commentaires, la fenêtre « Options... » (les réglages sont dans l'écran principal). L'import d'un guide, lui, a son écran (voir plus bas).

### Importer un guide

L'entrée **Importer un guide** du menu RestedXP (celle qui s'appelle « Import guide » chez RestedXP, à la même place) ouvre un écran de WowVision à deux parties. Il se ferme avec Échap, et la fenêtre d'import de RestedXP, qu'il a dû montrer pour se servir de sa zone de collage, disparaît avec lui.

1. **Coller et importer** : une première ligne dit où en est l'import (« Rien de collé pour le moment », « 52000 caractères collés, prêt à importer », « Import : 3 guides chargés sur 12 »). Puis **Coller une chaîne de guide** : Entrée, puis **Ctrl+V** (Échap annule) avec le texte du guide copié avant, depuis le site de RestedXP par exemple. Le texte est pris par la zone de collage de RestedXP elle-même, qui le reçoit caractère par caractère, ce qui évite de geler le jeu sur un texte très long ; l'extension dit « 52000 caractères collés. Vous pouvez maintenant les importer ». Puis **Importer les guides collés** : RestedXP charge les guides petit à petit, et l'extension le dit (« Import de 12 guides », puis à chaque quart, puis le message de fin de RestedXP, dans la langue du jeu), ou dit l'erreur (« Erreur d'import : ... »). Une ligne « Dernier message » garde le dernier message de RestedXP pour qui l'aurait manqué. RestedXP vérifie Battle.net avant d'importer ; s'il n'a pas de réponse, l'extension le dit.
2. **Gérer les guides importés** : « Guides importés » (un groupe ; Entrée sur un guide demande confirmation puis le retire), « Retirer tous les guides importés » (le bouton Purger de RestedXP, avec confirmation : il oublie aussi les quêtes que vous aviez passées ou mises en premier), « Recharger l'interface » (avec confirmation).

Les guides importés se choisissent ensuite comme les autres, dans le menu RestedXP.

### Les options du jeu (Options, AddOns, RestedXP Guides)

La page de RestedXP dans la fenêtre des options du jeu est faite de petits éléments qu'aucun lecteur d'écran ne lit. WowVision sait déjà parcourir la fenêtre des options (les onglets, la recherche, la liste des catégories) ; quand vous choisissez « RestedXP Guides » dans la liste de l'onglet AddOns, **une seconde fenêtre WowVision s'ouvre toute seule avec tous les réglages de RestedXP**, les mêmes que dans le menu Maj+F2 : les onglets sont des groupes (flèche droite pour ouvrir, gauche pour fermer), les cases se cochent avec Entrée, les curseurs se règlent avec les flèches gauche et droite (Entrée pour taper une valeur), les listes s'ouvrent avec Entrée, les champs aussi, les boutons qui demandent confirmation la demandent. Ctrl+Tab passe de cette fenêtre à celle des options et inversement. Échap ferme la fenêtre des options du jeu, et celle-ci avec. La commande `/rxp` ouvre aussi cette page. Un réglage changé ici se voit tout de suite sur la page pour qui la voit.

### Le clic droit

Faire un clic droit sur la fenêtre RestedXP (à la souris, par exemple avec un ami qui voit) ouvre aussi, à côté du menu déroulant, un écran WowVision avec les mêmes entrées. Pour vous, Alt+Ctrl+F2 fait la même chose sans souris. Échap ferme l'écran et le menu déroulant.

## La flèche : dire, balise sonore, itinéraire

RestedXP montre une flèche qui tourne vers la prochaine destination du guide. Trois façons de l'utiliser :

- **Dire** (Ctrl+F2) : le nom de la destination, sa direction comme sur un cadran d'horloge (« devant vous », « à 2 heures, à droite », « derrière vous ») et la distance en mètres (le jeu français dit mètres pour ce que le client anglais appelle yards).
- **Balise sonore** (Ctrl+Maj+F2) : c'est la balise de WowVision. Elle tique depuis la direction de la destination, plus vite quand vous lui faites face, avec un clic quand vous êtes aligné, un autre quand vous vous en écartez, et la distance est dans le son. Tournez-vous jusqu'à entendre le clic d'alignement, puis avancez. Elle va en ligne droite.
- **Itinéraire WowVision** (Alt+Maj+F2) : WowVision calcule un chemin par son réseau (WowNav) quand il en a un ici, et vous guide point par point ; sans réseau il retombe sur la balise en ligne droite.

Pendant qu'un guidage tourne, il **suit la flèche** : quand RestedXP la fait passer à une autre destination, la balise ou l'itinéraire est refait vers elle, tout seul. Maj+F12 (« annuler la navigation » de WowVision) l'arrête, ainsi que « Arrêter le guidage ». À l'arrivée, WowVision le dit.

**Ignorer les petits déplacements de la flèche (option, désactivée par défaut)** : par défaut, la moindre bougeotte de la flèche refait le guidage. La flèche de RestedXP peut bouger de quelques mètres sans cesse (une créature qui marche, un point calculé d'après votre position), ce qui pour certains revient à un recalcul permanent. La case **Ignorer les petits déplacements de la flèche (moins de 10 mètres)** (écran Maj+F2, partie Flèche, juste sous la case de recalcul) y met fin : cochée, une destination ne compte comme une autre que si elle est à **plus de 10 mètres** de celle que le guidage vise (ou si elle est dans une autre instance). La comparaison se fait avec le point visé, pas avec la dernière position vue : plusieurs petits déplacements qui s'additionnent finissent par dépasser les 10 mètres, et le guidage est alors refait une fois. Le seuil est fixe (10 mètres, `Guidance.smallMove` dans le code). La case vaut aussi pour « Dire où pointe la flèche quand elle change » : une dérive de quelques mètres n'est pas redite.

La case **Recalculer le guidage quand la flèche change de destination** (écran Maj+F2, partie Flèche, cochée par défaut) règle ce suivi. **Cochée**, c'est ce qui vient d'être dit. **Décochée**, la balise ou l'itinéraire garde la destination du moment où vous l'avez lancé et n'est plus jamais refait quand la flèche change : plus de recalcul permanent. La touche garde son rôle (une pression arrête, une autre relance), donc pour viser la flèche telle qu'elle est maintenant, appuyez deux fois sur la touche (arrêt, puis départ). Ce que la case ne change pas : un itinéraire que WowVision refait lui-même n'est pas de ce ressort ; elle ne règle que ce que fait cette extension quand la flèche de RestedXP bouge. Si « Dire où pointe la flèche quand elle change » est coché, la nouvelle destination est dite même pendant un guidage quand la case est décochée (cochée, c'est WowVision qui la dit).

## Les nouvelles étapes sont lues

Quand RestedXP passe à une nouvelle étape, ou charge un guide, l'extension lit l'étape (une demi-seconde après, le temps que la fenêtre se mette à jour), sans la répéter deux fois de suite. Se coupe dans le menu (« Dire chaque nouvelle étape »). « Dire où pointe la flèche quand elle change » est coupé par défaut.

## Si le jeu rame : `/wvrxp temps`

Cette extension ne fait presque rien quand vous ne l'utilisez pas : un minuteur qui revient tout de suite deux fois par seconde, et, à chaque image, un coup d'œil pour savoir si la page des options est affichée. Les écrans ne travaillent que pendant qu'ils sont ouverts, et ne relisent pas ce qu'ils ont lu il y a moins d'un quart de seconde (les lignes du guide, deux secondes). Pour savoir ce qui prend du temps :

- `/wvrxp temps` dit, pour chaque chose mesurée (écran principal, écran de menu, page des options, surveillance de la page, construction du menu, lecture des réglages, lecture des étapes, suivi de la flèche, ouverture des menus, touches), le nombre d'appels, le temps total et le pire, puis les appels les plus lents, puis la mémoire prise par RestedXP, par WowVision, par cette extension et par tout Lua.
- `/wvrxp temps zéro` remet les mesures à zéro. Faites-le, jouez jusqu'au ralentissement, puis redemandez.

Un appel de cette extension qui dépasse quelques dizaines de millisecondes y apparaît. S'il n'y en a pas, le ralentissement vient d'ailleurs (RestedXP lui-même, WowVision, le jeu).

## Limites

- En combat, WowVision n'actualise pas ses écrans : les touches qui parlent (étape, flèche, balise, itinéraire) marchent, pas le menu.
- La destination de la flèche n'a pas de hauteur : WowNav prend l'étage le plus bas là où il y en a plusieurs.
- Ce qui est dit en français est de moi. L'allemand est ma traduction, non vérifiée par un germanophone.
- La nouvelle interface « v2 » de RestedXP (option bêta, désactivée par défaut) n'est pas prise en charge pour la case à cocher des étapes ; le texte des étapes se lit quand même.

## Comment elle s'accroche

- À RestedXP : son objet se trouve par `RXP` (variable globale qu'il laisse) ou par AceAddon sous le nom `RXPGuides`. L'extension lit ses étapes actives (`RXPFrame.activeSteps`), sa flèche (`arrowFrame.element`), son menu (`RXPFrame.GenerateMenuTable`, `RXPFrame.menuList`) et ses réglages (la table AceConfig enregistrée sous son titre, lue avec les règles de AceConfigDialog), écoute ses messages `RXP_STEP_ACTIVATED` et `RXP_GUIDE_LOADED`, et enveloppe `addon:ShowMenu` pour ouvrir un écran à côté de chaque menu qu'il montre. Pour l'import, elle lit son module `guideImporter` (état, messages, liste des guides), prend le clavier pour sa zone de collage (`widgets.importBox`), lance son bouton Importer par `Validate()`, et enveloppe `UpdateImportStatusHistory` et `ProcessBuffer` pour dire ce qu'il rapporte.
- À WowVision : les écrans sont des écrans du « graphe » (`WowVision.graph`, fenêtres temporaires de `UIHost:openTemporaryWindow`), les touches sont des raccourcis du gestionnaire d'entrées (`WowVision.input:createBinding`), le guidage utilise le module `maps` (`directTo`, `goToDestination`, `cancelNavigation`).
- Les coordonnées de la flèche sont celles de HereBeDragons ; WowVision utilise les mêmes deux nombres dans l'autre ordre (HereBeDragons lit `UnitPosition` comme y, x), l'extension les échange.

## Tests

```
lua tests/run.lua        # tests hors jeu (RestedXP et le jeu sont simulés, le moteur d'écrans de WowVision est le vrai)
lua tests/real_core.lua  # les touches avec le vrai gestionnaire d'entrées de WowVision
```

Depuis le dossier de l'extension, avec Lua 5.1 ou plus récent ; le dossier `WowVision` doit être à côté (ou `WOWVISION_DIR` doit le désigner).

---

## English

Extension for WowVision that makes the **RestedXP** leveling guide (the "RestedXP Guides" addon, folder `RXPGuides`) usable with a screen reader. It changes no file of WowVision or RestedXP.

**Nothing here has been tried in the game**: the tests simulate the game, RestedXP and WowVision.

| Key | Effect |
|---|---|
| **Shift+F2** | opens (or closes) the RestedXP menu, the main screen |
| Alt+F2 | says the current step |
| Ctrl+F2 | says where the arrow points: clock position and distance |
| Ctrl+Shift+F2 | **sound beacon** to the arrow's destination (again stops it) |
| Alt+Shift+F2 | **WowVision route** to the arrow's destination (again stops it) |
| Alt+Ctrl+F2 | RestedXP's right-click menu (the guides, the tips...) |

Without a default key (set them in WowVision's Bindings screen): stop guiding, skip the step, next step, previous step. `/wvrxp` opens the menu; `/wvrxp step|arrow|beacon|route|stop`.

The main screen holds, in tab order: the guide and its active steps (each line to do is a check box, the same as RestedXP's "skip" box), the arrow (live reading, beacon, route, stop, and two check boxes: recalculate when the arrow changes, ignore small moves), moving in the guide (skip, previous, next, go to step number, the next five steps), the items to use and creatures to target when RestedXP offers them, RestedXP's right-click menu (guides in groups; Enter on a guide loads it), all of RestedXP's settings, and this addon's own two settings. RestedXP's page in the game's options window (Options, AddOns, RestedXP Guides) is made of widgets nothing can read: when you pick it in WowVision's options window, a second WowVision window opens by itself with the same settings (Ctrl+Tab goes between the two, Escape closes the game's window and this one with it; `/rxp` opens the page too). A menu RestedXP shows (right click on its window, its cog, the minimap button) also opens a WowVision screen with the same entries. RestedXP's report, wizard and feedback windows cannot be used from the keyboard and are left out. Its import window has a screen of its own: the "Import a guide" entry of the menu (where RestedXP's "Import guide" was) opens it. "Paste a guide string" then Ctrl+V puts the text in RestedXP's own paste box (which takes it character by character, so even a very long text does not freeze the game); "Import the pasted guides" loads them while the addon says the progress, the end or the error; imported guides can be removed one by one or all at once (each asks first), and the interface can be reloaded from there.

A guidance toward the arrow follows it when RestedXP moves it to another destination: the beacon or the route is redone toward the new point. By default any move of the arrow redoes it. RestedXP's arrow can drift by a few yards all the time, which some players feel as constant recalculation: the check box "Ignore small moves of the arrow (under 10 yards)" (the arrow part of the Shift+F2 screen, just under the recalculation box, unticked by default) puts an end to it. Ticked, a destination counts as another only when it is more than 10 yards from the one the guidance aims at (or in another instance); small drifts that add up are measured against the aimed point, so they trigger one redo once they pass 10 yards. The same limit then applies to saying the arrow's change. The distance is fixed (`Guidance.smallMove`). The check box "Recalculate the guidance when the arrow changes destination" (in the arrow part of the Shift+F2 screen, ticked by default) turns that off: unticked, the beacon or the route keeps the destination it was started with and is never redone when the arrow changes (press the key twice, stop then start, to aim at the arrow as it is now; with "say where the arrow points when it changes" on, the new destination is then spoken even while guiding). New steps are read out half a second after RestedXP changes them (a setting in the menu turns this off). In combat WowVision does not update its screens: the keys that speak work, the menu does not.

German is the author's own translation, unchecked by a native speaker. Tests: `lua tests/run.lua` and `lua tests/real_core.lua` from this folder.

---

## Deutsch

Erweiterung für WowVision, die den Levelguide **RestedXP** (das Addon „RestedXP Guides“, Ordner `RXPGuides`) mit einem Screenreader nutzbar macht. Sie ändert keine Datei von WowVision oder RestedXP. **Nichts davon wurde im Spiel ausprobiert**: die Tests simulieren das Spiel, RestedXP und WowVision.

| Taste | Wirkung |
|---|---|
| **Umschalt+F2** | öffnet (oder schließt) das RestedXP-Menü, den Hauptbildschirm |
| Alt+F2 | sagt den aktuellen Schritt |
| Strg+F2 | sagt, wohin der Pfeil zeigt: Uhrzeigerrichtung und Entfernung |
| Strg+Umschalt+F2 | **Klangsignal** zum Ziel des Pfeils (nochmal drücken beendet es) |
| Alt+Umschalt+F2 | **WowVision-Route** zum Ziel des Pfeils (nochmal drücken beendet sie) |
| Alt+Strg+F2 | das Rechtsklick-Menü von RestedXP (die Guides, die Tipps …) |

Ohne Standardtaste (in WowVisions Tastenbelegung einstellbar): Führung beenden, Schritt überspringen, nächster Schritt, vorheriger Schritt. `/wvrxp` öffnet das Menü; `/wvrxp schritt|pfeil|signal|route|stopp|zeit`.

Der Hauptbildschirm enthält in Tab-Reihenfolge: den Guide und seine aktiven Schritte (jede Zeile zum Erledigen ist ein Kästchen, dasselbe wie das „Überspringen“-Kästchen von RestedXP), den Pfeil (Live-Ansage, Klangsignal, Route, Stopp, und die Kästchen **„Führung neu berechnen, wenn der Pfeil das Ziel wechselt“** und **„Kleine Verschiebungen des Pfeils ignorieren“**), das Bewegen im Guide (überspringen, zurück, weiter, zu Schritt Nummer, die nächsten fünf Schritte), die zu benutzenden Gegenstände und anzuvisierenden Kreaturen, das Rechtsklick-Menü von RestedXP (Guides in Gruppen; Eingabe auf einem Guide lädt ihn), alle Einstellungen von RestedXP und die beiden eigenen Einstellungen dieses Addons. Die Einstellungsseite von RestedXP im Optionsfenster des Spiels (Optionen, AddOns, RestedXP Guides) wird ebenfalls lesbar: Ein zweites WowVision-Fenster öffnet sich von selbst mit denselben Einstellungen.

**Einen Guide importieren**: Der Eintrag „Guide importieren“ des Menüs öffnet einen eigenen Bildschirm. „Guide-Text einfügen“, dann Strg+V (Esc bricht ab) legt den Text in das eigene Einfügefeld von RestedXP, das ihn Zeichen für Zeichen aufnimmt, sodass selbst ein sehr langer Text das Spiel nicht einfrieren lässt. „Eingefügte Guides importieren“ lädt sie, während das Addon den Fortschritt, das Ende oder den Fehler ansagt. Importierte Guides lassen sich einzeln oder alle auf einmal entfernen (jedes Mal mit Rückfrage), und die Oberfläche kann von dort neu geladen werden.

**Führung neu berechnen**: Folgt die Führung dem Pfeil, wird das Klangsignal oder die Route neu auf das neue Ziel gerichtet, sobald RestedXP den Pfeil verschiebt. Das Kästchen „Kleine Verschiebungen des Pfeils ignorieren (unter 10 Metern)“ (Pfeil-Teil, direkt unter dem Kästchen zur Neuberechnung, standardmäßig nicht angekreuzt) beendet das ständige Neuberechnen: Angekreuzt gilt ein Ziel erst als anderes, wenn es mehr als 10 Meter vom angepeilten entfernt ist (oder in einer anderen Instanz); mehrere kleine Verschiebungen werden gegen den angepeilten Punkt gemessen und lösen ab 10 Metern einmal eine Neuausrichtung aus. Das Kästchen „Führung neu berechnen, wenn der Pfeil das Ziel wechselt“ ist standardmäßig angekreuzt; ohne Kreuz behält Signal oder Route das Ziel vom Start, und zum Neuausrichten drückt man die Taste zweimal (stopp, dann start).

Neue Schritte werden eine halbe Sekunde nach RestedXP vorgelesen (abschaltbar im Menü). Im Kampf aktualisiert WowVision seine Bildschirme nicht: Die sprechenden Tasten funktionieren, das Menü nicht. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft. Tests: `lua tests/run.lua` und `lua tests/real_core.lua` in diesem Ordner.
