-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. The names of the two groups are WowVision's own words for them in its Aura buffer
-- (French "Améliorations du joueur" / "Affaiblissements du joueur", German "Spieler-Buffs" / "Spieler-Debuffs"),
-- read from its locale files, so that what is heard here is what the Aura buffer says. The sentences around them are
-- the author's own wording; German has not been checked by a native speaker.
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        ["Player Buffs"] = "Améliorations du joueur",
        ["Player Debuffs"] = "Affaiblissements du joueur",
        ["{label}: {count}"] = "{label} : {count}",
        ["unavailable"] = "indisponible",
        ["Auras are not available."] = "Les auras ne sont pas disponibles.",
        ["WowVision's windows are not available."] = "Les fenêtres de WowVision ne sont pas disponibles.",

        -- the keys, in WowVision's Bindings screen
        ["Say the player's buffs and debuffs"] = "Dire les améliorations et affaiblissements du joueur",
        ["Open the list of the player's buffs and debuffs"] = "Ouvrir la liste des améliorations et affaiblissements du joueur",

        -- /wvauras
        ["Use /wvauras to open the list, /wvauras say to hear them all, /wvauras count for the numbers."] = "Utilisez /wvauras pour ouvrir la liste, /wvauras dire pour tout entendre, /wvauras nombre pour les nombres.",
    },

    deDE = {
        ["Player Buffs"] = "Spieler-Buffs",
        ["Player Debuffs"] = "Spieler-Debuffs",
        ["{label}: {count}"] = "{label}: {count}",
        ["unavailable"] = "nicht verfügbar",
        ["Auras are not available."] = "Auren sind nicht verfügbar.",
        ["WowVision's windows are not available."] = "Die Fenster von WowVision sind nicht verfügbar.",

        ["Say the player's buffs and debuffs"] = "Buffs und Debuffs des Spielers sagen",
        ["Open the list of the player's buffs and debuffs"] = "Liste der Buffs und Debuffs des Spielers öffnen",

        ["Use /wvauras to open the list, /wvauras say to hear them all, /wvauras count for the numbers."] = "Mit /wvauras öffnen Sie die Liste, mit /wvauras sagen hören Sie alles, mit /wvauras anzahl die Anzahlen.",
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

-- "{label}" and the like replaced by the values of the table; a name the table does not have stays as it is. The
-- values go in as they are: never a value that is a secret string (those are only ever joined with "..").
function ns.fill(template, values)
    return (template:gsub("{(%w+)}", function(name)
        local value = values[name]
        if value == nil then
            return nil
        end
        return tostring(value)
    end))
end

ns.TRANSLATIONS = TRANSLATIONS
