-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. French is the author's own wording; German is a translation by the author and has
-- not been checked by a native speaker.
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        ["Say Health Percent"] = "Dire la vie en pourcentage",
        ["Say Power Percent"] = "Dire la mana ou la ressource en pourcentage",

        ["Health"] = "Vie",
        ["Resource"] = "Ressource",
        ["%s %d percent"] = "%s %d pour cent",
        ["%s and %s"] = "%s. %s",
        ["The game hides this value."] = "Le jeu cache cette valeur.",
        ["No resource to read."] = "Aucune ressource à lire.",
        ["Nothing to read."] = "Rien à lire.",
    },

    deDE = {
        ["Say Health Percent"] = "Leben in Prozent ansagen",
        ["Say Power Percent"] = "Mana oder Ressource in Prozent ansagen",

        ["Health"] = "Leben",
        ["Resource"] = "Ressource",
        ["%s %d percent"] = "%s %d Prozent",
        ["%s and %s"] = "%s. %s",
        ["The game hides this value."] = "Das Spiel verbirgt diesen Wert.",
        ["No resource to read."] = "Keine Ressource zum Ablesen.",
        ["Nothing to read."] = "Nichts zum Ablesen.",
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
