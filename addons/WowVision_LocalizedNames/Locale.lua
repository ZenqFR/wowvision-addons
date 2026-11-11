-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. French is the author's own wording; German is a translation by the author and has
-- not been checked by a native speaker.
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        ["Localized navigation names: on"] = "Noms localisés de la navigation : activés",
        ["Localized navigation names: off"] = "Noms localisés de la navigation : désactivés",
        ["WowVision now names creatures and objects in your language itself, with its own setting; this addon does nothing."] = "WowVision nomme maintenant lui-même les créatures et les objets dans votre langue, avec son propre réglage ; cet addon ne fait rien.",
    },
    deDE = {
        ["Localized navigation names: on"] = "Lokalisierte Namen in der Navigation: an",
        ["Localized navigation names: off"] = "Lokalisierte Namen in der Navigation: aus",
        ["WowVision now names creatures and objects in your language itself, with its own setting; this addon does nothing."] = "WowVision benennt Kreaturen und Objekte jetzt selbst in deiner Sprache, mit eigener Einstellung; dieses Addon tut nichts.",
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

ns.translations = TRANSLATIONS

if GetLocale ~= nil then
    ns.useLocale(GetLocale())
end
