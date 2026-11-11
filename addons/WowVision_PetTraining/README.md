# WowVision Pet Training (WowVision - Dressage du familier)

Extension de [WowVision](https://github.com/wow-vision/WowVision) (aussi en anglais plus bas). Elle ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface pas.

Sur WoW: Forever, le sort **Dressage de bête** du chasseur ouvre les compétences du familier dans la fenêtre des entraîneurs de classe, mais sans entraîneur en face de vous : WowVision n'en lisait rien. Avec cette extension, la fenêtre se lit comme celle d'un entraîneur, dans cet ordre (Tab passe d'un arrêt à l'autre) :

1. **les points d'entraînement** qu'il reste, lus en direct ;
2. **le filtre** (disponibles, indisponibles, déjà connues) ;
3. **la liste des compétences**, chacune avec son rang, son coût **en points d'entraînement** (pas en pièces) et ses conditions ;
4. **les détails** de la compétence choisie ;
5. **le bouton Entraîner**.

Le titre est le nom du familier. Quand un vrai entraîneur est ouvert, c'est la fenêtre habituelle de WowVision qui parle, pas celle-ci. Rien à régler, pas de commande.

## Comment elle s'accroche à WowVision

Elle enregistre une fenêtre `beastTraining` auprès du gestionnaire de fenêtres de WowVision (`WowVision.UIHost.windowManager`), ouverte tant que la fenêtre du familier est affichée, et dont l'écran est une copie du code de WowVision pour les entraîneurs avec les trois différences ci-dessus. Si WowVision intègre un jour sa propre fenêtre de dressage (`WowVision.petTraining`), l'extension le voit et ne fait plus rien.

## Tests

```
lua tests/run.lua
```

Depuis le dossier de l'extension, avec n'importe quel Lua 5.1 ou plus récent. Le jeu et WowVision sont simulés ; les fichiers de l'extension sont chargés pour de vrai.

---

## English

Extension for WowVision; it changes none of WowVision's files. On WoW: Forever the hunter's Beast Training spell opens the pet's skills in the class trainer window with no trainer to talk to, which WowVision did not read. This adds a window for it: the training points left, the filter, the skills (each with its cost in training points), the details and the Train button. Run the tests with `lua tests/run.lua` from this folder.

## Deutsch

Erweiterung für WowVision; sie ändert keine Datei von WowVision. Auf WoW: Forever öffnet der Jäger-Zauber „Tiertraining“ die Fähigkeiten des Tiers im Klassenlehrerfenster, ohne dass ein Lehrer zum Ansprechen da ist; das las WowVision nicht. Diese Erweiterung fügt dafür ein Fenster hinzu: die verbleibenden Trainingspunkte, den Filter, die Fähigkeiten (jede mit ihren Kosten in Trainingspunkten), die Details und die Schaltfläche „Trainieren“. Tests: `lua tests/run.lua` in diesem Ordner. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft.

## Statut / Status

**Français** : cette fonction a été intégrée à WowVision (pull request wow-vision/WowVision#121). Avec un WowVision récent (qui a `WowVision.petTraining`), cet addon se met en retrait et ne fait rien ; il reste utile avec une version plus ancienne.

**English**: this feature was merged into WowVision (pull request wow-vision/WowVision#121). With a recent WowVision (the one that has `WowVision.petTraining`) this addon steps aside and does nothing; it stays useful with an older version.

**Deutsch**: Diese Funktion wurde in WowVision übernommen (Pull Request wow-vision/WowVision#121). Mit einem aktuellen WowVision (dem mit `WowVision.petTraining`) hält sich dieses Addon zurück und tut nichts; mit einer älteren Version bleibt es nützlich.
