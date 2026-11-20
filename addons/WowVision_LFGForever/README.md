# WowVision LFG Forever (WowVision - LFG Forever)

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais et en allemand plus bas) pour l'addon **LFG Forever** (la recherche de groupe avancée de WoW: Forever, `/lfg`). Elle ne modifie aucun fichier de WowVision ni de LFG Forever : une mise à jour de l'un ou de l'autre ne l'efface pas.

## À quoi ça sert

LFG Forever est une fenêtre à lui : filtres par rôle et classe, liste des groupes et des joueurs trouvés, chuchotements, notes des joueurs. WowVision ne la connaissait pas. Cette extension en fait un **écran WowVision** : quand la fenêtre de LFG Forever s'ouvre (`/lfg`, sa touche, son bouton de minicarte, ou **Alt+Ctrl+G**), WowVision lit son écran ; quand elle se ferme, il se ferme. Chaque contrôle est le vrai de LFG Forever (Entrée clique dessus, comme WowVision le fait pour les fenêtres du jeu) : rien ne change dans le fonctionnement de LFG Forever, et **tous les mots viennent de lui** (noms des filtres, des activités, des langues, dans la langue où LFG Forever est affiché).

## L'écran : les arrêts (Tab passe de l'un à l'autre)

| Arrêt | Ce qu'il contient |
|---|---|
| **Onglets** | Filtres, Chuchotements, Notes des joueurs (les onglets de la colonne de droite) ; dit lequel est ouvert. Flèches gauche et droite, Entrée. |
| **Recherche** | le menu de **catégorie** (« Catégorie, Donjons »), le menu d'**activité**, le bouton **Recherche**, « Vérification des rôles » quand il est là. C'est là que le curseur arrive à l'ouverture. Entrée sur un menu l'ouvre. |
| **Résultats de la recherche** | « Recherche en cours » pendant la recherche, puis les deux parties, **Groupes** et **Joueurs** (Entrée les replie ou les déplie ; elles disent combien de lignes elles contiennent), et une ligne par groupe ou joueur. |
| **Filtres** (onglet Filtres) | quatre arrêts, un par section : **Groupes** (rôles cherchés, classes à exclure, Réinitialiser les filtres, Enregistrer un filtre, Mes filtres), **Joueurs** (rôles, niveau minimum et maximum), **Classes** (une case par classe, Tout sélectionner, Tout désélectionner), **Divers** (style de jeu, langues). L'en-tête de chaque section se replie et se déplie avec Entrée (il le dit, et dit « des filtres sont modifiés » quand une section repliée n'est pas à ses valeurs par défaut). |
| **Chuchotements** (onglet Chuchotements) | le journal des chuchotements reçus, une ligne chacun : « Aragorn, niveau 30 Guerrier : Salut ». Effacer le journal. |
| **Notes des joueurs** (onglet Notes) | les derniers compagnons de groupe, une ligne chacun avec la note qu'ils ont (« noté 2 étoiles sur 3 » ou « pas noté »). |
| **Réglages** | l'engrenage de LFG Forever. |

### Une ligne de résultat

- **Un groupe** : le chef, ce pour quoi il cherche, le nombre de membres et ce qu'ils sont (« 3 membres (1 Tank, 2 Dégâts) »), le style de jeu, la note, et si c'est votre annonce, si elle est retirée, si elle accueille les nouveaux joueurs.
- **Un joueur** : le nom, « niveau 17 Mage », ses rôles, ce pour quoi il cherche, la zone où il est, le style de jeu, la note.
- Ce que le jeu garde secret (instance, combat) est **laissé de côté, jamais deviné** ; une ligne dont rien n'est lisible dit « Groupe, détails indisponibles ».

| Touche sur une ligne | Effet |
|---|---|
| **Entrée** | sur un groupe : **« Demander à rejoindre »** (le bouton de LFG Forever : il chuchote au chef le message réglé dans LFG Forever, ou ouvre un chuchotement vide si ce réglage est coupé) ; sur un joueur : **« Inviter »**. La ligne le dit après son texte (« Demander à rejoindre, déjà demandé » si vous l'avez déjà fait). LFG Forever laisse deux secondes entre deux actions de ce genre ; pendant ce temps le bouton est « désactivé ». |
| **Retour arrière** | le menu du clic droit du jeu (chuchoter, ajouter en ami, signaler...). |
| **Maj+F10** (menu contextuel de WowVision) | les actions qui s'appliquent à cette ligne, puis le menu du clic droit. |
| **Espace** | lit l'infobulle de la ligne (le détail du groupe), ligne par ligne avec Maj+flèches, comme partout dans WowVision. |

Dans les **chuchotements** et les **notes des joueurs**, Entrée ouvre le menu de la ligne (le clic droit). Le menu contextuel (Maj+F10) offre : pour un chuchotement **Inviter**, **Où est ce joueur** (quand LFG Forever l'offre) et **Retirer** ; pour une note **Noter 1 étoile**, **2 étoiles**, **3 étoiles**.

## La touche et la commande

| | |
|---|---|
| **Alt+Ctrl+G** | ouvre LFG Forever, ou le ferme (comme `/lfg`) ; dans le menu de WowVision : `/wv` ou Maj+F1, Interface, Raccourcis (« Ouvrir ou fermer LFG Forever »). Ni WowVision ni vos autres extensions ne la prennent (vérifié contre le vrai gestionnaire de touches de WowVision, `tests/real_core.lua`). Les deux touches propres à LFG Forever (Ouvrir, Rechercher) restent dans les Raccourcis du jeu, intactes. |
| `/wvlfg` (ou `/wvgroupe`, `/wvgruppe`) | ouvre ou ferme LFG Forever ; `/wvlfg aide` rappelle la commande. |

## Ce que ça lit, et ses limites

LFG Forever garde son code privé : on n'atteint que sa fenêtre (`LFGForeverFrame`), les panneaux qu'elle porte et leurs contrôles, par les noms que LFG Forever leur donne. `tests/real_lfg.lua` relit les sources du LFG Forever installé et vérifie que chacun de ces noms y est toujours (écrit pour la **version 2.3.0**) ; si une mise à jour de LFG Forever en change un, ce test dit lequel et l'écran concerné se tait plutôt que de dire n'importe quoi (une erreur dans une partie est signalée une fois, le reste continue).

- **Essayé en jeu : ça marche** (retour du joueur, le 20 novembre 2026, après les premiers essais). Tout est en plus testé hors du jeu avec le vrai moteur d'écrans de WowVision et la vraie classe de fenêtres, sur des fenêtres simulées d'après le code de LFG Forever.
- La recherche, « Demander à rejoindre » et « Inviter » sont les **vrais clics** sur les vrais boutons, comme le fait WowVision pour les fenêtres du jeu ; le jeu n'accepte la recherche que d'un vrai clic ou d'une vraie touche : si elle était refusée, c'est à signaler.
- La fenêtre des **réglages** de LFG Forever (l'engrenage) est celle d'Options du jeu.
- Sku, qui a ses propres fenêtres, est laissé tranquille, comme partout dans WowVision.

## Tests

Depuis le dossier de l'extension, avec Lua 5.1 ou plus récent :

```
lua tests/run.lua        les lignes, les phrases, l'écran (le vrai moteur d'écrans de WowVision), les touches, la commande, les traductions
lua tests/real_core.lua  la touche et la fenêtre, avec le vrai gestionnaire de touches et les vraies classes de fenêtres de WowVision
lua tests/real_lfg.lua   les noms que l'extension lit, contre les sources du LFG Forever installé (ignoré s'il n'y est pas)
```

`WOWVISION_DIR` et `LFGFOREVER_DIR` pointent vers d'autres dossiers. Mutations : 135, seuls 7 cas équivalents survivent (des gardes que la suite double, par exemple « caché » vérifié deux fois). Les mots allemands sont ma traduction.

---

## English

Extension for WowVision, for the **LFG Forever** addon (WoW: Forever's advanced group finder, `/lfg`). It changes none of the files of WowVision or LFG Forever.

LFG Forever has a window of its own, which WowVision did not know. This addon makes it a **WowVision screen**: when LFG Forever's window opens (`/lfg`, its key, its minimap button, or **Alt+Ctrl+G**) WowVision reads it, and when it closes the screen closes. Every control is LFG Forever's real one (Enter clicks it, as WowVision does with the game's windows), so nothing changes in how LFG Forever works, and **every word comes from it** (the names of the filters, activities and languages, in the language LFG Forever is shown in).

Tab stops: **Tabs** (Filters, Whispers, Player ratings); **Search** (the category and activity menus, the Search button, Role check; the cursor starts here); **Search results** ("Searching", then the two parts, **Groups** and **Players**, which Enter folds and unfolds, and one line per group or player); then, for the open tab, **Filters** (four stops, one per section: Groups, Players, Classes, Miscellaneous; each header folds and unfolds with Enter and says when a folded section holds changed filters), **Whispers** (the whisper log, one line each) or **Player ratings** (your recent party members with their stars); and **Settings**.

A group's line says its leader, what it is for, how many members and what they are ("3 members (1 Tank, 2 Damage)"), the play style and the note; a player's line says the name, "level 17 Mage", the roles, what for, the zone, the play style and the note. What the game keeps secret (instances, combat) is left out, never guessed. **Enter** on a group is **Ask to join** (LFG Forever's button: it whispers the leader the message set in LFG Forever, or opens an empty whisper if that setting is off), on a player **Invite**; the line says so after its text ("Ask to join, already asked"). LFG Forever leaves two seconds between two such actions, during which the button is "disabled". **Backspace** is the game's right-click menu, **Shift+F10** (WowVision's context menu) the actions that apply to the line, **Space** reads the line's tooltip. On whispers and ratings Enter opens the line's menu; the context menu offers Invite, Where is this player, Remove (whispers) or Rate 1, 2, 3 stars (ratings).

**Alt+Ctrl+G** opens or closes LFG Forever (listed in WowVision's Bindings screen; LFG Forever's own two keys stay in the game's Keybindings, untouched). `/wvlfg` does the same, `/wvlfg help` says so.

It reaches LFG Forever only through the names it gives its frames (it keeps its code private); `tests/real_lfg.lua` reads the installed LFG Forever's source and checks each name (written for **version 2.3.0**). Tests: `lua tests/run.lua` (WowVision's real graph framework), `lua tests/real_core.lua` (the real input manager and window classes), `lua tests/real_lfg.lua`; 135 mutations, 7 equivalent survivors. **Tried in game: it works** (the player's report, 20 November 2026). German is my own translation.

## Deutsch

Erweiterung für WowVision, für das Addon **LFG Forever** (die erweiterte Gruppensuche von WoW: Forever, `/lfg`). Sie ändert keine Datei von WowVision oder LFG Forever.

LFG Forever hat ein eigenes Fenster, das WowVision nicht kannte. Dieses Addon macht daraus einen **WowVision-Bildschirm**: Öffnet sich das Fenster von LFG Forever (`/lfg`, seine Taste, seine Minikarten-Schaltfläche oder **Alt+Strg+G**), liest WowVision es; schließt es sich, schließt sich der Bildschirm. Jedes Bedienelement ist das echte von LFG Forever (Eingabe klickt darauf, wie WowVision es bei den Fenstern des Spiels tut), an der Arbeitsweise von LFG Forever ändert sich also nichts, und **jedes Wort kommt von ihm** (die Namen der Filter, Aktivitäten und Sprachen, in der Sprache, in der LFG Forever angezeigt wird).

Halte: **Reiter** (Filter, Flüstern, Spielerbewertungen); **Suche** (die Menüs für Kategorie und Aktivität, die Schaltfläche Suchen, Rollencheck; hier beginnt der Cursor); **Suchergebnisse** („Suche läuft“, dann die zwei Teile **Gruppen** und **Spieler**, die die Eingabetaste ein- und ausklappt, und eine Zeile pro Gruppe oder Spieler); dann, für den offenen Reiter, **Filter** (vier Halte, einer pro Abschnitt: Gruppen, Spieler, Klassen, Verschiedenes; jede Überschrift klappt mit Eingabe ein und aus und sagt, wenn ein eingeklappter Abschnitt geänderte Filter enthält), **Flüstern** (das Flüsterprotokoll, eine Zeile je Nachricht) oder **Spielerbewertungen** (Ihre letzten Gruppenmitglieder mit ihren Sternen); und **Einstellungen**.

Die Zeile einer Gruppe nennt den Anführer, wofür sie sucht, wie viele Mitglieder und welche („3 Mitglieder (1 Tank, 2 Schaden)“), den Spielstil und die Notiz; die Zeile eines Spielers den Namen, „Stufe 17 Mage“, die Rollen, wofür, die Zone, den Spielstil und die Notiz. Was das Spiel geheim hält (Instanzen, Kampf), wird weggelassen, nie geraten. **Eingabe** bei einer Gruppe ist **Beitritt anfragen** (die Schaltfläche von LFG Forever: sie flüstert dem Anführer die in LFG Forever eingestellte Nachricht oder öffnet ein leeres Flüstern, wenn diese Einstellung aus ist), bei einem Spieler **Einladen**; die Zeile sagt es nach ihrem Text („Beitritt anfragen, schon angefragt“). LFG Forever lässt zwei Sekunden zwischen zwei solchen Aktionen, in denen die Schaltfläche „deaktiviert“ ist. **Rücktaste** ist das Rechtsklick-Menü des Spiels, **Umschalt+F10** (das Kontextmenü von WowVision) die Aktionen, die für die Zeile gelten, die **Leertaste** liest den Tooltip der Zeile. Bei Flüstern und Bewertungen öffnet die Eingabetaste das Menü der Zeile; das Kontextmenü bietet Einladen, Wo ist dieser Spieler, Entfernen (Flüstern) oder Mit 1, 2, 3 Sternen bewerten (Bewertungen).

**Alt+Strg+G** öffnet oder schließt LFG Forever (in der Tastenbelegung von WowVision aufgeführt; die zwei eigenen Tasten von LFG Forever bleiben in der Tastenbelegung des Spiels unberührt). `/wvlfg` tut dasselbe, `/wvlfg hilfe` sagt es.

Es erreicht LFG Forever nur über die Namen, die es seinen Frames gibt (der Code ist privat); `tests/real_lfg.lua` liest den Quelltext des installierten LFG Forever und prüft jeden Namen (geschrieben für **Version 2.3.0**). Tests: `lua tests/run.lua` (das echte Graph-Framework von WowVision), `lua tests/real_core.lua` (der echte Tastenmanager und die echten Fensterklassen), `lua tests/real_lfg.lua`; 135 Mutationen, 7 äquivalente Überlebende. **Im Spiel ausprobiert: es funktioniert** (Rückmeldung des Spielers, 20. November 2026). Das Deutsche ist meine eigene Übersetzung.
