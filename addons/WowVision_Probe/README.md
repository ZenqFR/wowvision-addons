# WowVision Probe (WowVision - Relevé de fenêtres)

Outil de diagnostic, pas une fonction pour le jeu de tous les jours. Aussi en anglais et en allemand plus bas.

## Français

Quand WowVision ne sait pas encore lire une fenêtre du jeu, il faut savoir ce que le jeu contient vraiment : les noms, les textes, les listes, les boutons. Cette extension l'écrit dans une variable enregistrée, pour construire ensuite dans WowVision une fenêtre d'après ce relevé.

- `/wvprobe` avec la fenêtre ouverte : relève ce qui est à l'écran (le jeu, la langue, quelles fonctions existent, chaque cadre sous l'interface, l'arbre complet des fenêtres qui ressemblent à une fenêtre de dressage ou d'artisanat, ou du cadre dont vous donnez le nom : `/wvprobe NomDuCadre`).
- `/wvprobe watch 20` : surveille pendant 20 secondes et relève chaque grande fenêtre qui s'ouvre pendant ce temps (ouvrez la fenêtre pendant que ça tourne).
- Puis `/reload` : le relevé est enregistré dans `WowVisionProbeDB` (fichier `WTF\...\SavedVariables\WowVision_Probe.lua`).

Il ne fait que lire : aucun clic, aucun script lancé, rien qui puisse « polluer » (taint) les fenêtres du jeu. Les appels qui peuvent échouer ou rendre une valeur secrète sont protégés. Ce qu'il dit à voix haute est en français, en anglais ou en allemand selon le jeu ; le relevé lui-même est un enregistrement technique en anglais.

Test : `lua tests/run.lua` depuis ce dossier. L'allemand est ma traduction, non vérifiée par un germanophone.

## English

A diagnostic tool, not a feature for everyday play. When WowVision cannot read a game window yet, one has to know what the game really holds: names, texts, lists, buttons. This addon writes it to a saved variable, so that a WowVision window can then be built from that record.

- `/wvprobe` with the window open: records what is on screen (the game build and language, which API functions exist, every frame directly under the UI, the full tree of the windows that look like a training or crafting window, or of the frame you name: `/wvprobe FrameName`).
- `/wvprobe watch 20`: watches for 20 seconds and records each large window that opens during that time (open the window while it runs).
- Then `/reload`: the record is saved in `WowVisionProbeDB` (`WTF\...\SavedVariables\WowVision_Probe.lua`).

It only reads: no clicks, no scripts run, nothing the game's windows could be tainted by. Every call that could fail or hand back a secret value is guarded. What it says out loud comes in French, English or German according to the game; the record itself is a technical log in English.

Test: `lua tests/run.lua` from this folder. German is the author's own translation, unchecked by a native speaker.

## Deutsch

Ein Diagnosewerkzeug, keine Funktion für das tägliche Spiel. Wenn WowVision ein Spielfenster noch nicht lesen kann, muss man wissen, was das Spiel wirklich enthält: Namen, Texte, Listen, Schaltflächen. Dieses Addon schreibt es in eine gespeicherte Variable, damit danach in WowVision ein Fenster nach dieser Aufnahme gebaut werden kann.

- `/wvprobe` bei geöffnetem Fenster: nimmt auf, was auf dem Bildschirm ist (Spielversion und Sprache, welche API-Funktionen es gibt, jeden Rahmen direkt unter der Oberfläche, den ganzen Baum der Fenster, die wie ein Trainings- oder Handwerksfenster aussehen, oder des Rahmens, den du nennst: `/wvprobe RahmenName`).
- `/wvprobe watch 20`: beobachtet 20 Sekunden lang und nimmt jedes große Fenster auf, das sich in dieser Zeit öffnet (öffne das Fenster, während es läuft).
- Danach `/reload`: Die Aufnahme wird in `WowVisionProbeDB` gespeichert (`WTF\...\SavedVariables\WowVision_Probe.lua`).

Es liest nur: keine Klicks, keine ausgeführten Skripte, nichts, womit die Fenster des Spiels „verunreinigt“ (Taint) werden könnten. Jeder Aufruf, der fehlschlagen oder einen geheimen Wert liefern könnte, ist abgesichert. Was es laut sagt, kommt je nach Spiel auf Französisch, Englisch oder Deutsch; die Aufnahme selbst ist ein technisches Protokoll auf Englisch.

Test: `lua tests/run.lua` in diesem Ordner. Das Deutsche ist meine eigene Übersetzung, nicht von Muttersprachlern geprüft.
