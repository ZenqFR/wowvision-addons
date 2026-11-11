-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. The French and German words are the ones WowVision already uses for the class
-- trainer; the training point cost is the author's own wording (German is not checked by a native speaker).
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        ["Training"] = "Entraînement",
        ["Details"] = "Détails",
        ["Filter"] = "Filtre",
        ["Known"] = "Connu",
        ["Unavailable"] = "Indisponible",
        ["Expanded"] = "Déplié",
        ["Collapsed"] = "Replié",
        ["selected"] = "sélectionné",
        ["Training point cost: %d"] = "Coût en points d'entraînement : %d",
        ["WowVision's training window was not found; the pet training window is not available."] = "La fenêtre d'entraînement de WowVision est introuvable ; la fenêtre de dressage du familier n'est pas disponible.",
    },

    deDE = {
        ["Training"] = "Ausbildung",
        ["Details"] = "Details",
        ["Filter"] = "Filter",
        ["Known"] = "Bekannt",
        ["Unavailable"] = "Nicht verfügbar",
        ["Expanded"] = "Ausgeklappt",
        ["Collapsed"] = "Eingeklappt",
        ["selected"] = "ausgewählt",
        ["Training point cost: %d"] = "Kosten in Trainingspunkten: %d",
        ["WowVision's training window was not found; the pet training window is not available."] = "Das Ausbildungsfenster von WowVision wurde nicht gefunden; das Begleiter-Ausbildungsfenster ist nicht verfügbar.",
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
