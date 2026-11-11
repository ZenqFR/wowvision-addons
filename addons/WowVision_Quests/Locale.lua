-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. The French and German words for "Level" are the ones WowVision already uses for
-- quests; the rest is the author's own wording (German is not checked by a native speaker).
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        ["Level"] = "Niveau",
        ["on"] = "activé",
        ["off"] = "désactivé",
        ["Sort Quests by Proximity"] = "Trier les quêtes par proximité",
        ["Use /wvquests on or /wvquests off to switch the sorting by proximity."] = "Utilisez /wvquests on ou /wvquests off pour activer ou désactiver le tri par proximité.",
        ["%s: %s"] = "%s : %s",
        ["WowVision's quest scanner was not found; nothing will be added."] = "Le scanner de quêtes de WowVision est introuvable ; rien ne sera ajouté.",
    },

    deDE = {
        ["Level"] = "Stufe",
        ["on"] = "an",
        ["off"] = "aus",
        ["Sort Quests by Proximity"] = "Quests nach Entfernung sortieren",
        ["Use /wvquests on or /wvquests off to switch the sorting by proximity."] = "Mit /wvquests on oder /wvquests off schalten Sie die Sortierung nach Entfernung an oder aus.",
        ["%s: %s"] = "%s: %s",
        ["WowVision's quest scanner was not found; nothing will be added."] = "Der Quest-Scanner von WowVision wurde nicht gefunden; es wird nichts hinzugefügt.",
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
