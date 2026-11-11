-- Spoken strings. Every line this addon adds is a complete sentence on its
-- own, because Shift+Down reads them one at a time.
--
-- Amounts are spelled out ("5 de plus", "3 de moins") instead of "+5" and
-- "-3": speech engines read a bare minus sign inconsistently.
local _, ns = ...

local STRINGS = {
    enUS = {
        -- Pawn summary: "Pawn: <scale>, <amount>[, over <item>]"
        pawnLine = "Pawn: %s, %s",
        pawnPercent = "upgrade of %d percent",
        pawnBig = "big upgrade",
        pawnOver = "over %s",

        -- Comparison with the equipped item
        header = "Compared to equipped: %s",
        slotOf = "Slot %d of %d:",
        emptySlot = "Nothing equipped in this slot",
        unknownItem = "unknown item",
        alsoOffHand = "Also takes off the off hand: %s",
        itemLevel = "Item level",
        same = "same",
        more = "%s more",
        less = "%s less",
        statLine = "%s: %s",
        noStatDifference = "No difference in stats",

        -- /wvcompare
        pawnName = "Pawn summary",
        equippedName = "Comparison with equipped item",
        on = "on",
        off = "off",
        status = "%s: %s",
        usage = "Use /wvcompare pawn or /wvcompare equipped to switch one on or off.",
        pawnMissing = "Pawn is not loaded, so there is no Pawn summary.",

        -- when WowVision does it itself, or cannot be hooked
        standsAside = "WowVision now compares items itself, with its own settings; this addon does nothing.",
        hookMissing = "WowVision's item tooltip hook was not found; nothing will be added.",
    },

    frFR = {
        pawnLine = "Pawn : %s, %s",
        pawnPercent = "amélioration de %d pour cent",
        pawnBig = "grosse amélioration",
        pawnOver = "par rapport à %s",

        header = "Comparé à l'objet équipé : %s",
        slotOf = "Emplacement %d sur %d :",
        emptySlot = "Rien d'équipé à cet emplacement",
        unknownItem = "objet inconnu",
        alsoOffHand = "Retire aussi l'objet de la main gauche : %s",
        itemLevel = "Niveau d'objet",
        same = "identique",
        more = "%s de plus",
        less = "%s de moins",
        statLine = "%s : %s",
        noStatDifference = "Aucune différence de statistiques",

        pawnName = "Résumé Pawn",
        equippedName = "Comparaison avec l'objet équipé",
        on = "activé",
        off = "désactivé",
        status = "%s : %s",
        usage = "Tapez /wvcompare pawn ou /wvcompare equipped pour activer ou désactiver l'un des deux.",
        pawnMissing = "Pawn n'est pas chargé, il n'y a donc pas de résumé Pawn.",

        standsAside = "WowVision compare maintenant les objets lui-même, avec ses propres réglages ; cet addon ne fait rien.",
        hookMissing = "Le point d'accroche des infobulles d'objets de WowVision est introuvable ; rien ne sera ajouté.",
    },

    -- German is the author's own translation, unchecked by a native speaker.
    deDE = {
        pawnLine = "Pawn: %s, %s",
        pawnPercent = "Verbesserung um %d Prozent",
        pawnBig = "große Verbesserung",
        pawnOver = "gegenüber %s",

        header = "Verglichen mit dem angelegten Gegenstand: %s",
        slotOf = "Platz %d von %d:",
        emptySlot = "An diesem Platz ist nichts angelegt",
        unknownItem = "unbekannter Gegenstand",
        alsoOffHand = "Legt auch die Nebenhand ab: %s",
        itemLevel = "Gegenstandsstufe",
        same = "gleich",
        more = "%s mehr",
        less = "%s weniger",
        statLine = "%s: %s",
        noStatDifference = "Kein Unterschied bei den Werten",

        pawnName = "Pawn-Zusammenfassung",
        equippedName = "Vergleich mit dem angelegten Gegenstand",
        on = "an",
        off = "aus",
        status = "%s: %s",
        usage = "Mit /wvcompare pawn oder /wvcompare equipped schaltest du einen der beiden an oder aus.",
        pawnMissing = "Pawn ist nicht geladen, deshalb gibt es keine Pawn-Zusammenfassung.",

        standsAside = "WowVision vergleicht Gegenstände jetzt selbst, mit eigenen Einstellungen; dieses Addon tut nichts.",
        hookMissing = "Der Tooltip-Haken für Gegenstände von WowVision wurde nicht gefunden; es wird nichts hinzugefügt.",
    },
}

-- Locales that write 1,5 rather than 1.5; the speech engine reads the comma
-- as a decimal mark, and the point as the word "point".
local DECIMAL_COMMA = { frFR = true, deDE = true, esES = true, itIT = true, ptBR = true, ruRU = true }

local active = STRINGS.enUS
local activeLocale = "enUS"

-- L behaves like a table of strings for the active locale. A locale with no
-- translation here reads English; a missing key reads as the key itself.
ns.L = setmetatable({}, {
    __index = function(_, key)
        local value = active[key]
        if value == nil then
            value = STRINGS.enUS[key]
        end
        if value == nil then
            return key
        end
        return value
    end,
})

function ns.useLocale(locale)
    activeLocale = locale or "enUS"
    active = STRINGS[activeLocale] or STRINGS.enUS
end

function ns.usesDecimalComma()
    return DECIMAL_COMMA[activeLocale] == true
end

if GetLocale ~= nil then
    ns.useLocale(GetLocale())
end
