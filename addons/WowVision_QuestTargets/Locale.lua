-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. French is the author's own wording; German is a translation by the author and has
-- not been checked by a native speaker. The French game calls its distance unit "mètres" for what the English
-- client calls yards.
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        ["Target Next Quest Target"] = "Cibler la cible de quête suivante",
        ["Target Previous Quest Target"] = "Cibler la cible de quête précédente",
        ["Say Quest Targets Nearby"] = "Dire les cibles de quête proches",

        ["No quest target nearby."] = "Aucune cible de quête à proximité.",
        ["Quest targets cannot be picked in combat."] = "Impossible de choisir une cible de quête en combat.",
        ["The game hides quest targets in combat."] = "En combat, le jeu cache les cibles de quête.",
        ["Enemy nameplates are off, so nearby enemies cannot be found. Type /wvqt plates to turn them on."] = "Les barres de vie des ennemis sont désactivées : je ne peux pas trouver les ennemis proches. Tapez /wvqt plaques pour les activer.",
        ["Enemy nameplates turned on."] = "Barres de vie des ennemis activées.",
        ["Enemy nameplates were off: I turned them on to find the enemies near you. Press again."] = "Les barres de vie des ennemis étaient désactivées : je les ai activées pour trouver les ennemis proches. Appuyez encore.",
        ["Turning on enemy nameplates by itself"] = "Activation automatique des barres de vie des ennemis",
        ["Enemy nameplates could not be turned on."] = "Impossible d'activer les barres de vie des ennemis.",
        ["This game version cannot tell which creatures belong to your quests."] = "Cette version du jeu ne dit pas quelles créatures servent à vos quêtes.",

        ["on"] = "activé",
        ["off"] = "désactivé",
        ["%s: %s"] = "%s : %s",
        ["%d of %d"] = "%d sur %d",
        ["1 quest target: %s."] = "1 cible de quête : %s.",
        ["%d quest targets: %s."] = "%d cibles de quête : %s.",
        ["within %d yards"] = "à moins de %d mètres",
        ["beyond %d yards"] = "à plus de %d mètres",

        ["Quest targets: /wvqt says the ones near you, /wvqt why says what it sees and why, /wvqt plates turns on enemy nameplates."] = "Cibles de quête : /wvqt dit celles qui sont proches, /wvqt pourquoi dit ce qu'elle voit et pourquoi, /wvqt plaques active les barres de vie des ennemis.",

        -- /wvqt why
        ["Creatures seen: %d. Proposed: %d."] = "Créatures vues : %d. Proposées : %d.",
        ["Enemy nameplates are off: type /wvqt plates."] = "Les barres de vie des ennemis sont désactivées : tapez /wvqt plaques.",
        ["You are in combat."] = "Vous êtes en combat.",
        ["Missing game call: quest link."] = "Appel du jeu manquant : le lien avec les quêtes.",
        ["Missing game call: tooltip objectives."] = "Appel du jeu manquant : les objectifs de l'infobulle.",
        ["Only your target, the creature under the mouse and the enemy nameplates in range can be seen."] = "Je ne peux voir que votre cible, la créature sous la souris et les barres de vie des ennemis à portée.",
        ["And %d more."] = "Et %d de plus.",
        ["a creature with a hidden name"] = "une créature au nom caché",
        ["proposed"] = "proposée",
        ["a player"] = "un joueur",
        ["cannot be attacked"] = "pas attaquable",
        ["dead"] = "morte",
        ["values hidden by the game"] = "valeurs cachées par le jeu",
        ["objectives already complete"] = "objectifs déjà terminés",
        ["not for any of your quests"] = "ne sert à aucune de vos quêtes",
        ["no unfinished objective in its tooltip"] = "aucun objectif en cours dans son infobulle",
    },

    deDE = {
        ["Target Next Quest Target"] = "Nächstes Questziel anvisieren",
        ["Target Previous Quest Target"] = "Vorheriges Questziel anvisieren",
        ["Say Quest Targets Nearby"] = "Questziele in der Nähe ansagen",

        ["No quest target nearby."] = "Kein Questziel in der Nähe.",
        ["Quest targets cannot be picked in combat."] = "Im Kampf kann kein Questziel gewählt werden.",
        ["The game hides quest targets in combat."] = "Im Kampf verbirgt das Spiel die Questziele.",
        ["Enemy nameplates are off, so nearby enemies cannot be found. Type /wvqt plates to turn them on."] = "Die Namensplaketten der Feinde sind aus, daher finde ich keine Feinde in der Nähe. Mit /wvqt plaketten schaltest du sie an.",
        ["Enemy nameplates turned on."] = "Namensplaketten der Feinde eingeschaltet.",
        ["Enemy nameplates were off: I turned them on to find the enemies near you. Press again."] = "Die Namensplaketten der Feinde waren aus: Ich habe sie eingeschaltet, um Feinde in deiner Nähe zu finden. Drücke noch einmal.",
        ["Turning on enemy nameplates by itself"] = "Automatisches Einschalten der Namensplaketten der Feinde",
        ["Enemy nameplates could not be turned on."] = "Die Namensplaketten der Feinde konnten nicht eingeschaltet werden.",
        ["This game version cannot tell which creatures belong to your quests."] = "Diese Spielversion verrät nicht, welche Kreaturen zu deinen Quests gehören.",

        ["on"] = "an",
        ["off"] = "aus",
        ["%s: %s"] = "%s: %s",
        ["%d of %d"] = "%d von %d",
        ["1 quest target: %s."] = "1 Questziel: %s.",
        ["%d quest targets: %s."] = "%d Questziele: %s.",
        ["within %d yards"] = "innerhalb von %d Metern",
        ["beyond %d yards"] = "weiter als %d Meter",

        ["Quest targets: /wvqt says the ones near you, /wvqt why says what it sees and why, /wvqt plates turns on enemy nameplates."] = "Questziele: /wvqt sagt die in deiner Nähe an, /wvqt warum sagt, was es sieht und warum, /wvqt plaketten schaltet die Namensplaketten der Feinde ein.",

        -- /wvqt why
        ["Creatures seen: %d. Proposed: %d."] = "Gesehene Kreaturen: %d. Vorgeschlagen: %d.",
        ["Enemy nameplates are off: type /wvqt plates."] = "Die Namensplaketten der Feinde sind aus: Gib /wvqt plaketten ein.",
        ["You are in combat."] = "Du bist im Kampf.",
        ["Missing game call: quest link."] = "Fehlender Spielaufruf: die Verknüpfung mit Quests.",
        ["Missing game call: tooltip objectives."] = "Fehlender Spielaufruf: die Ziele im Tooltip.",
        ["Only your target, the creature under the mouse and the enemy nameplates in range can be seen."] = "Ich kann nur dein Ziel, die Kreatur unter der Maus und die Namensplaketten der Feinde in Reichweite sehen.",
        ["And %d more."] = "Und %d weitere.",
        ["a creature with a hidden name"] = "eine Kreatur mit verborgenem Namen",
        ["proposed"] = "vorgeschlagen",
        ["a player"] = "ein Spieler",
        ["cannot be attacked"] = "nicht angreifbar",
        ["dead"] = "tot",
        ["values hidden by the game"] = "vom Spiel verborgene Werte",
        ["objectives already complete"] = "Ziele schon erledigt",
        ["not for any of your quests"] = "gehört zu keiner deiner Quests",
        ["no unfinished objective in its tooltip"] = "kein offenes Ziel im Tooltip",
    },
}

local active = {}

ns.L = setmetatable({}, {
    __index = function(_, key)
        local value = active[key]
        if value == nil then
            return key
        end
        return value
    end,
})

function ns.useLocale(locale)
    ns.locale = locale or "enUS"
    active = TRANSLATIONS[ns.locale] or {}
end

if GetLocale ~= nil then
    ns.useLocale(GetLocale())
end
