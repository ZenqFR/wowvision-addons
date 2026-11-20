-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. French is the author's own wording; German is a translation by the author and has
-- not been checked by a native speaker.
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        ["Gear Judge's verdict on the item up for a roll"] = "Avis de Gear Judge sur l'objet proposé au jet",
        ["Gear Judge's verdict on every item up for a roll"] = "Avis de Gear Judge sur tous les objets proposés au jet",
        ["No loot."] = "Pas de butin.",
        ["The item is loading."] = "L'objet se charge.",
        ["Item %d of %d"] = "Objet %d sur %d",
        ["upgrade of %s percent"] = "amélioration de %s pour cent",
        ["downgrade of %s percent"] = "régression de %s pour cent",
        ["no change"] = "aucun changement",
        ["an upgrade"] = "une amélioration",
        ["a downgrade"] = "une régression",
        ["instead of %s"] = "à la place de %s",
        ["empty slot"] = "emplacement vide",
        ["you already wear it"] = "vous le portez déjà",
        ["your class cannot use it"] = "votre classe ne peut pas l'utiliser",
        ["it is not equipment"] = "ce n'est pas un équipement",
        ["Gear Judge is not ready yet"] = "Gear Judge n'est pas encore prêt",
        ["the item is not loaded yet"] = "l'objet n'est pas encore chargé",
        ["Gear Judge cannot read that item"] = "Gear Judge ne peut pas lire cet objet",
        ["Gear Judge reported an error"] = "Gear Judge a signalé une erreur",
        ["Gear Judge gave no figure"] = "Gear Judge n'a pas donné de chiffre",
        ["Gear Judge is not installed or not enabled."] = "Gear Judge n'est pas installé ou n'est pas activé.",
        ["Gear Judge is too old: version 3.2.7 or later is needed."] = "Gear Judge est trop ancien : il faut la version 3.2.7 ou plus récente.",
        ["Roll judge: the key says what Sharpie's Gear Judge thinks of the item up for a roll, whether it improves what you wear and by how many percent. /wvjuge says it too, /wvjuge all says it for every item up for a roll."] = "Avis sur les jets : la touche dit ce que Sharpie's Gear Judge pense de l'objet proposé au jet, s'il améliore ce que vous portez et de combien de pour cent. /wvjuge le dit aussi, /wvjuge tout le dit pour tous les objets proposés.",
    },
    deDE = {
        ["Gear Judge's verdict on the item up for a roll"] = "Urteil von Gear Judge zum Gegenstand, um den gewürfelt wird",
        ["Gear Judge's verdict on every item up for a roll"] = "Urteil von Gear Judge zu jedem Gegenstand, um den gewürfelt wird",
        ["No loot."] = "Keine Beute.",
        ["The item is loading."] = "Der Gegenstand lädt.",
        ["Item %d of %d"] = "Gegenstand %d von %d",
        ["upgrade of %s percent"] = "Verbesserung um %s Prozent",
        ["downgrade of %s percent"] = "Verschlechterung um %s Prozent",
        ["no change"] = "keine Veränderung",
        ["an upgrade"] = "eine Verbesserung",
        ["a downgrade"] = "eine Verschlechterung",
        ["instead of %s"] = "statt %s",
        ["empty slot"] = "Platz ist leer",
        ["you already wear it"] = "du trägst ihn schon",
        ["your class cannot use it"] = "deine Klasse kann ihn nicht benutzen",
        ["it is not equipment"] = "das ist keine Ausrüstung",
        ["Gear Judge is not ready yet"] = "Gear Judge ist noch nicht bereit",
        ["the item is not loaded yet"] = "der Gegenstand ist noch nicht geladen",
        ["Gear Judge cannot read that item"] = "Gear Judge kann diesen Gegenstand nicht lesen",
        ["Gear Judge reported an error"] = "Gear Judge hat einen Fehler gemeldet",
        ["Gear Judge gave no figure"] = "Gear Judge hat keine Zahl genannt",
        ["Gear Judge is not installed or not enabled."] = "Gear Judge ist nicht installiert oder nicht aktiviert.",
        ["Gear Judge is too old: version 3.2.7 or later is needed."] = "Gear Judge ist zu alt: Version 3.2.7 oder neuer wird gebraucht.",
        ["Roll judge: the key says what Sharpie's Gear Judge thinks of the item up for a roll, whether it improves what you wear and by how many percent. /wvjuge says it too, /wvjuge all says it for every item up for a roll."] = "Urteil zu Würfen: Die Taste sagt, was Sharpie's Gear Judge vom Gegenstand hält, um den gewürfelt wird, ob er verbessert, was du trägst, und um wie viel Prozent. /wvjuge sagt es auch, /wvjuge alle sagt es für jeden Gegenstand, um den gewürfelt wird.",
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
