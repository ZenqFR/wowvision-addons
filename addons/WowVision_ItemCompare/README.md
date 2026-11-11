# WowVision Item Compare

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais plus bas).

Quand vous êtes sur un équipement (sac, banque, marchand, butin, lien dans le chat…), la lecture de l'infobulle de WowVision contient en plus :

1. **le résumé de Pawn**, quand Pawn trouve que l'objet est une amélioration ;
2. **la comparaison avec l'objet que vous portez** à cet emplacement.

Les touches ne changent pas, ce sont celles de WowVision :

| Touche | Effet |
|---|---|
| Shift+Bas | ligne suivante, une ligne à la fois |
| Shift+Haut | ligne précédente (la première fois : la dernière ligne) |
| Espace | tout lire d'un coup |

Les lignes ajoutées viennent **à la fin** de l'infobulle, dans cet ordre.

## Ce que vous entendez

Exemple dans le sac, sur un casque meilleur que celui que vous portez :

```
Casque neuf
Tête
Inhabituel
Niveau d'objet 55
Armure 130
…
Pawn : Chasseur : Précision, amélioration de 12 pour cent, par rapport à Casque ancien, Vert
Comparé à l'objet équipé : Casque ancien, Vert
Niveau d'objet : 5 de plus
Armure : 10 de plus
Endurance : 2 de plus
Intelligence : 4 de moins
Critique : 8 de plus
```

- **Une ligne Pawn par échelle** pour laquelle l'objet est une amélioration, avec le pourcentage, et l'objet qu'il remplacerait. « Grosse amélioration » remplace le pourcentage quand Pawn n'en donne pas (emplacement vide, gain énorme). Rien n'est dit si Pawn ne voit pas d'amélioration.
- **La comparaison** donne le niveau d'objet puis chaque statistique qui change : armure, dégâts par seconde, force, agilité, endurance, intelligence, esprit, puis les autres par ordre alphabétique. Les écarts sont dits en mots (« 5 de plus », « 3 de moins »), jamais avec « + » ou « − », que les voix lisent mal.
- **Bagues, bijoux** : comparés avec les deux emplacements (« Emplacement 1 sur 2 : … »).
- **Armes à une main** : comparées à la main gauche seulement si elle tient une arme (pas pour un bouclier).
- **Armes à deux mains** : ajoutent « Retire aussi l'objet de la main gauche : … ».
- **Emplacement vide** : « Rien d'équipé à cet emplacement ».
- L'objet que vous portez déjà n'est pas comparé à lui-même.
- Les lignes d'amélioration que Pawn écrit lui-même dans l'infobulle sont remplacées par celles-ci, pour ne pas entendre deux fois la même chose. Les autres lignes de Pawn (« le meilleur », valeurs…) ne sont pas touchées.

Français et anglais sont fournis ; les autres langues lisent l'anglais pour le texte ajouté (les noms de statistiques viennent du jeu, donc restent dans votre langue).

## Commandes

| Commande | Effet |
|---|---|
| `/wvcompare` | dit l'état des deux options |
| `/wvcompare pawn` | active ou désactive le résumé Pawn |
| `/wvcompare equipped` | active ou désactive la comparaison |
| `/wvcompare pawn off`, `/wvcompare equipped on` | force un état |

Les deux sont activés par défaut, pour tous vos personnages.

## Installation

Dossier `Interface\AddOns\WowVision_ItemCompare`, à côté de `WowVision`. Il faut WowVision ; Pawn est facultatif (sans lui, seule la comparaison est ajoutée). Tapez `/reload` en jeu.

L'extension ne modifie aucun fichier de WowVision : elle s'accroche à `WowVision.items.augmentTooltipLines`, que WowVision relit à chaque lecture d'infobulle. Une mise à jour de WowVision ne l'efface donc pas. Si WowVision supprime cette fonction, un message le dit dans le chat au chargement et rien n'est ajouté. Si elle change de forme sans disparaître, l'erreur est signalée une fois (BugSack) et l'infobulle reste intacte.

## Limites

- Les statistiques viennent de `C_Item.GetItemStats`, c'est-à-dire de l'objet lui-même (suffixes et bonus compris). Elles ne comprennent ni les enchantements ni les gemmes posées.
- Le pourcentage de Pawn est celui de Pawn : il dépend de vos échelles visibles et de ses réglages.

## Tests

```
lua tests/run.lua
```

Les tests simulent le jeu mais chargent le vrai code d'infobulle de WowVision (`../WowVision`), donc ils vérifient ce que Espace et Shift+Bas font réellement des lignes ajoutées.

---

## English

An extension for WowVision. When you are on a piece of gear (bags, bank, vendor, loot, chat link…), WowVision's tooltip reading also includes **Pawn's upgrade summary** (when Pawn says the item is an upgrade) and **a comparison with what you currently wear in that slot**. The keys are WowVision's own: Shift+Down reads one line at a time, Space reads everything. The added lines come last.

Each Pawn line names the scale, the upgrade percentage and the item it would replace. The comparison gives the item level difference, then every stat that changes, in words ("5 more", "3 less"). Rings and trinkets are compared with both slots; one-hand weapons with the off hand only when it holds a weapon; two-handers also say they take off the off hand. `/wvcompare`, `/wvcompare pawn` and `/wvcompare equipped` show or switch each part. Install by dropping the folder next to `WowVision` and typing `/reload`.

## Deutsch

Eine Erweiterung für WowVision. Wenn du auf einem Ausrüstungsgegenstand stehst (Taschen, Bank, Händler, Beute, Chat-Link …), umfasst das Vorlesen des Tooltips durch WowVision auch die **Pawn-Verbesserungszusammenfassung** (wenn Pawn sagt, dass der Gegenstand eine Verbesserung ist) und **einen Vergleich mit dem, was du an diesem Platz gerade trägst**. Die Tasten sind die von WowVision: Umschalt+Runter liest eine Zeile nach der anderen, Leertaste liest alles. Die hinzugefügten Zeilen kommen zuletzt.

Jede Pawn-Zeile nennt das Profil, die Verbesserung in Prozent und den Gegenstand, den er ersetzen würde. Der Vergleich nennt den Unterschied der Gegenstandsstufe, dann jeden Wert, der sich ändert, in Worten („5 mehr“, „3 weniger“). Ringe und Schmuckstücke werden mit beiden Plätzen verglichen; Einhandwaffen mit der Nebenhand nur, wenn sie eine Waffe hält; Zweihänder sagen auch, dass sie die Nebenhand ablegen. `/wvcompare`, `/wvcompare pawn` und `/wvcompare equipped` zeigen oder schalten jeden Teil. Installation: den Ordner neben `WowVision` legen und `/reload` eingeben.

Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft.

## Statut / Status

**Français** : cette fonction a été intégrée à WowVision (pull request wow-vision/WowVision#114). Avec un WowVision récent, cet addon se met en retrait et ne fait rien (sinon chaque ligne serait lue deux fois) ; il reste utile avec une version plus ancienne.

**English**: this feature was merged into WowVision (pull request wow-vision/WowVision#114). With a recent WowVision this addon steps aside and does nothing (otherwise every line would be read twice); it stays useful with an older version.

**Deutsch**: Diese Funktion wurde in WowVision übernommen (Pull Request wow-vision/WowVision#114). Mit einem aktuellen WowVision hält sich dieses Addon zurück und tut nichts (sonst würde jede Zeile doppelt vorgelesen); mit einer älteren Version bleibt es nützlich.
