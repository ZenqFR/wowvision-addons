-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. French is the author's own wording; German is a translation by the author and has
-- not been checked by a native speaker.
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        ["Beacon Toward Your Target"] = "Balise sonore vers votre cible",
        ["Target"] = "Cible",
        ["You have no target."] = "Vous n'avez pas de cible.",
        ["You are targeting yourself."] = "Vous vous ciblez vous-même.",
        ["Position unavailable."] = "Position indisponible.",
        ["Your target's position is not known."] = "La position de votre cible n'est pas connue.",
        ["WowVision cannot find the position of a target here."] = "WowVision ne peut pas trouver la position d'une cible ici.",
        ["Guidance stopped."] = "Guidage arrêté.",
        ["Target direction: /wvtarget starts a sound beacon toward your target (again on the same target stops it), /wvtarget say only says where it is, /wvtarget stop ends it."] = "Direction de la cible : /wvtarget lance une balise sonore vers votre cible (encore une fois sur la même cible, l'arrête), /wvtarget dire dit seulement où elle est, /wvtarget stop l'arrête.",
    },
    deDE = {
        ["Beacon Toward Your Target"] = "Klangsignal zu deinem Ziel",
        ["Target"] = "Ziel",
        ["You have no target."] = "Du hast kein Ziel.",
        ["You are targeting yourself."] = "Du hast dich selbst anvisiert.",
        ["Position unavailable."] = "Position nicht verfügbar.",
        ["Your target's position is not known."] = "Die Position deines Ziels ist nicht bekannt.",
        ["WowVision cannot find the position of a target here."] = "WowVision kann hier die Position eines Ziels nicht finden.",
        ["Guidance stopped."] = "Führung beendet.",
        ["Target direction: /wvtarget starts a sound beacon toward your target (again on the same target stops it), /wvtarget say only says where it is, /wvtarget stop ends it."] = "Richtung des Ziels: /wvtarget startet ein Klangsignal zu deinem Ziel (nochmal auf dasselbe Ziel beendet es), /wvtarget sagen sagt nur, wo es ist, /wvtarget stopp beendet es.",
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
