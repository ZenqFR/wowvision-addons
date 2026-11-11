"""Writes README.md (French, English, German) from tools/catalog.json, so the README and the page never disagree."""
import os

STATUS = {
    "en": {"active": "active", "merged": "merged into WowVision", "tool": "tool", "retired": "retired, do not install"},
    "fr": {"active": "actif", "merged": "intégré à WowVision", "tool": "outil", "retired": "retiré, ne pas installer"},
    "de": {"active": "aktiv", "merged": "in WowVision übernommen", "tool": "Werkzeug", "retired": "eingestellt, nicht installieren"},
}

TEXT = {
    "en": {
        "name": "English",
        "lead": "Free addons for blind and visually impaired players of **World of Warcraft: Forever**, made to work with the [WowVision](https://github.com/wow-vision/WowVision) screen reader addon: follow the RestedXP leveling guide, handle bags, target quest creatures and more, by ear.",
        "site": "**Download, preview and hear what each one says:** {site} (the page picks French, English or German by itself).",
        "table": ["Addon", "State", "What it does"],
        "all": "Everything in one archive (without the retired addon): [wowvision-forever-addons.zip]({base}downloads/wowvision-forever-addons.zip). Checksums: [SHA256SUMS.txt]({base}downloads/SHA256SUMS.txt).",
        "install_h": "Install",
        "install": [
            "Install [WowVision](https://github.com/wow-vision/WowVision) first: all these addons work through it.",
            "Download the addons you want (the page, or the table above), or the archive with all of them.",
            "Unzip into `World of Warcraft\\_forever_\\Interface\\AddOns`, so that each addon keeps its own folder, then type `/reload` in the game.",
        ],
        "notes_h": "Good to know",
        "notes": [
            "Each addon changes none of WowVision's files, so a WowVision update never removes it.",
            "Four of them were merged into WowVision itself (pull requests 112, 113, 114 and 121); with a recent WowVision they step aside and do nothing, and stay useful with an older version.",
            "Honest status: several addons were used in the game before they were published; others, and the newest changes, are checked by offline tests only. Each addon's README says where it stands.",
            "French and English are the author's own wording; German is a translation by the author and has not been checked by a native speaker.",
            "Released under the MIT licence (see [LICENSE](LICENSE); a copy is in every archive). A few addons adapt parts of WowVision's own code, which declares no licence; those parts stay under its authors' terms.",
        ],
        "dev_h": "For people who work on the addons",
        "dev": [
            "`python tools/build.py` rebuilds the archives in `docs/downloads/` and the catalogue the page reads (`docs/js/data.js`) from `tools/catalog.json` and the `.toc` files. The archives are reproducible.",
            "Each addon has offline tests: `lua tests/run.lua` from its folder. Most need a WowVision folder next to the addon (or `WOWVISION_DIR` pointing to one). Test counts in the catalogue are as of {tests}.",
            "The page is plain HTML, CSS and JavaScript in `docs/` (GitHub Pages), with no library and no request leaving the page.",
        ],
        "legal": "Not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment, Inc. This repository uses no Blizzard artwork.",
    },
    "fr": {
        "name": "Français",
        "lead": "Addons gratuits pour les joueurs aveugles et malvoyants de **World of Warcraft: Forever**, faits pour fonctionner avec l'addon lecteur d'écran [WowVision](https://github.com/wow-vision/WowVision) : suivre le guide de niveau RestedXP, gérer ses sacs, cibler les créatures de ses quêtes et plus, à l'oreille.",
        "site": "**Télécharger, prévisualiser et écouter ce que dit chacun :** {site} (la page choisit seule le français, l'anglais ou l'allemand).",
        "table": ["Addon", "État", "Ce qu'il fait"],
        "all": "Tout dans une seule archive (sans l'addon retiré) : [wowvision-forever-addons.zip]({base}downloads/wowvision-forever-addons.zip). Sommes de contrôle : [SHA256SUMS.txt]({base}downloads/SHA256SUMS.txt).",
        "install_h": "Installer",
        "install": [
            "Installez d'abord [WowVision](https://github.com/wow-vision/WowVision) : tous ces addons passent par lui.",
            "Téléchargez les addons voulus (la page, ou le tableau ci-dessus), ou l'archive qui les contient tous.",
            "Décompressez dans `World of Warcraft\\_forever_\\Interface\\AddOns`, pour que chaque addon garde son propre dossier, puis tapez `/reload` dans le jeu.",
        ],
        "notes_h": "Bon à savoir",
        "notes": [
            "Chaque addon ne modifie aucun fichier de WowVision : une mise à jour de WowVision ne l'efface jamais.",
            "Quatre d'entre eux ont été intégrés à WowVision lui-même (pull requests 112, 113, 114 et 121) ; avec un WowVision récent ils se mettent en retrait et ne font rien, et restent utiles avec une version plus ancienne.",
            "État honnête : plusieurs addons ont été utilisés en jeu avant d'être publiés ; les autres, et les changements les plus récents, ne sont vérifiés que par des tests hors jeu. Le README de chaque addon dit où il en est.",
            "Le français et l'anglais sont de l'auteur ; l'allemand est une traduction de l'auteur, non vérifiée par un germanophone.",
            "Publié sous licence MIT (voir [LICENSE](LICENSE) ; une copie est dans chaque archive). Quelques addons reprennent des parties du code de WowVision, qui ne déclare aucune licence ; ces parties restent sous les conditions de ses auteurs.",
        ],
        "dev_h": "Pour celles et ceux qui travaillent sur les addons",
        "dev": [
            "`python tools/build.py` reconstruit les archives dans `docs/downloads/` et le catalogue que lit la page (`docs/js/data.js`) à partir de `tools/catalog.json` et des fichiers `.toc`. Les archives sont reproductibles.",
            "Chaque addon a des tests hors jeu : `lua tests/run.lua` depuis son dossier. La plupart ont besoin d'un dossier WowVision à côté de l'addon (ou de `WOWVISION_DIR` qui le désigne). Les nombres de tests du catalogue sont ceux du {tests}.",
            "La page est du HTML, du CSS et du JavaScript simples dans `docs/` (GitHub Pages), sans bibliothèque et sans requête qui sorte de la page.",
        ],
        "legal": "Sans lien avec Blizzard Entertainment et non approuvé par elle. World of Warcraft est une marque de Blizzard Entertainment, Inc. Ce dépôt n'utilise aucune illustration de Blizzard.",
    },
    "de": {
        "name": "Deutsch",
        "lead": "Kostenlose Addons für blinde und sehbehinderte Spielerinnen und Spieler von **World of Warcraft: Forever**, gemacht für das Screenreader-Addon [WowVision](https://github.com/wow-vision/WowVision): dem RestedXP-Levelguide folgen, Taschen verwalten, Quest-Kreaturen anvisieren und mehr, nach Gehör.",
        "site": "**Herunterladen, ansehen und anhören, was jedes sagt:** {site} (die Seite wählt Deutsch, Englisch oder Französisch von selbst).",
        "table": ["Addon", "Stand", "Was es tut"],
        "all": "Alles in einem Archiv (ohne das eingestellte Addon): [wowvision-forever-addons.zip]({base}downloads/wowvision-forever-addons.zip). Prüfsummen: [SHA256SUMS.txt]({base}downloads/SHA256SUMS.txt).",
        "install_h": "Installieren",
        "install": [
            "Installiere zuerst [WowVision](https://github.com/wow-vision/WowVision): alle diese Addons arbeiten darüber.",
            "Lade die Addons herunter, die du willst (die Seite oder die Tabelle oben), oder das Archiv mit allen.",
            "Entpacke in `World of Warcraft\\_forever_\\Interface\\AddOns`, sodass jedes Addon seinen eigenen Ordner behält, und gib dann im Spiel `/reload` ein.",
        ],
        "notes_h": "Gut zu wissen",
        "notes": [
            "Jedes Addon ändert keine Datei von WowVision, ein Update von WowVision entfernt es also nie.",
            "Vier davon wurden in WowVision selbst übernommen (Pull Requests 112, 113, 114 und 121); mit einem aktuellen WowVision halten sie sich zurück und tun nichts, mit einer älteren Version bleiben sie nützlich.",
            "Ehrlicher Stand: Mehrere Addons wurden im Spiel benutzt, bevor sie veröffentlicht wurden; andere und die neuesten Änderungen sind nur durch Tests außerhalb des Spiels geprüft. Die README jedes Addons sagt, wo es steht.",
            "Französisch und Englisch stammen vom Autor; das Deutsche ist eine Übersetzung des Autors und nicht von Muttersprachlern geprüft.",
            "Veröffentlicht unter der MIT-Lizenz (siehe [LICENSE](LICENSE); eine Kopie liegt in jedem Archiv). Einige Addons übernehmen Teile des Codes von WowVision, das keine Lizenz angibt; diese Teile bleiben unter den Bedingungen seiner Autoren.",
        ],
        "dev_h": "Für alle, die an den Addons arbeiten",
        "dev": [
            "`python tools/build.py` baut die Archive in `docs/downloads/` und den Katalog, den die Seite liest (`docs/js/data.js`), aus `tools/catalog.json` und den `.toc`-Dateien neu. Die Archive sind reproduzierbar.",
            "Jedes Addon hat Tests außerhalb des Spiels: `lua tests/run.lua` in seinem Ordner. Die meisten brauchen einen WowVision-Ordner neben dem Addon (oder `WOWVISION_DIR`, der darauf zeigt). Die Testzahlen im Katalog gelten für den {tests}.",
            "Die Seite besteht aus schlichtem HTML, CSS und JavaScript in `docs/` (GitHub Pages), ohne Bibliothek und ohne Anfrage, die die Seite verlässt.",
        ],
        "legal": "Nicht mit Blizzard Entertainment verbunden und nicht von ihr unterstützt. World of Warcraft ist eine Marke von Blizzard Entertainment, Inc. Dieses Repository verwendet keine Grafiken von Blizzard.",
    },
}


def write(catalog, root):
    base = catalog["site"]
    lines = ["# WowVision addons for WoW: Forever", ""]
    lines.append("[Français](#français) · [English](#english) · [Deutsch](#deutsch)")
    lines.append("")
    for lang in ("fr", "en", "de"):
        t = TEXT[lang]
        lines.append("## " + t["name"])
        lines.append("")
        lines.append(t["lead"])
        lines.append("")
        lines.append(t["site"].format(site=base))
        lines.append("")
        lines.append("| " + " | ".join(t["table"]) + " |")
        lines.append("|---|---|---|")
        for name in catalog["order"]:
            entry = catalog["addons"][name]
            title = entry["title"][lang]
            link = "[%s](%s) ([.zip](%sdownloads/%s.zip))" % (title, entry["path"], base, name)
            lines.append("| %s | %s | %s |" % (link, STATUS[lang][entry["group"]], entry["tagline"][lang]))
        lines.append("")
        lines.append(t["all"].format(base=base))
        lines.append("")
        lines.append("### " + t["install_h"])
        lines.append("")
        for number, step in enumerate(t["install"], 1):
            lines.append("%d. %s" % (number, step))
        lines.append("")
        lines.append("### " + t["notes_h"])
        lines.append("")
        for note in t["notes"]:
            lines.append("- " + note)
        lines.append("")
        lines.append("### " + t["dev_h"])
        lines.append("")
        for item in t["dev"]:
            lines.append("- " + item.format(tests=catalog["testsAsOf"]))
        lines.append("")
        lines.append("*" + t["legal"] + "*")
        lines.append("")
    with open(os.path.join(root, "README.md"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines).rstrip() + "\n")
