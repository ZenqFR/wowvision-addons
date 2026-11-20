-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. Only the words this addon adds are here: everything LFG Forever itself writes (the names
-- of the filters, of the tabs, of the buttons, the activities, the languages) is read from LFG Forever's own windows, so
-- it comes in the language LFG Forever shows (it has language packs, French and German among them). The class and role
-- names are the game's own words. French and German are the author's own wording; German has not been checked by a
-- native speaker.
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        ["Tabs"] = "Onglets",
        ["Category"] = "Catégorie",
        ["Activity"] = "Activité",
        ["Search"] = "Recherche",
        ["Search results"] = "Résultats de la recherche",
        ["Searching"] = "Recherche en cours",
        ["Groups"] = "Groupes",
        ["Players"] = "Joueurs",
        ["Group"] = "Groupe",
        ["Player"] = "Joueur",
        ["collapsed"] = "replié",
        ["expanded"] = "déplié",
        ["{label}, {count}"] = "{label}, {count}",
        ["{count} members"] = "{count} membres",
        ["{count} members ({roles})"] = "{count} membres ({roles})",
        ["{count} {role}"] = "{count} {role}",
        ["roles: {roles}"] = "rôles : {roles}",
        ["level {level} {class}"] = "niveau {level} {class}",
        ["level {level}"] = "niveau {level}",
        ["in {zone}"] = "à {zone}",
        ["{count} activities"] = "{count} activités",
        ["your own listing"] = "votre annonce",
        ["listing removed"] = "annonce retirée",
        ["welcomes new players"] = "accueille les nouveaux joueurs",
        ["details unavailable"] = "détails indisponibles",
        ["message unavailable"] = "message indisponible",
        ["already asked"] = "déjà demandé",
        ["rated {count} of 3 stars"] = "noté {count} étoiles sur 3",
        ["not rated"] = "pas noté",
        ["has changed filters"] = "des filtres sont modifiés",
        ["Tank"] = "Tank",
        ["Healer"] = "Soigneur",
        ["Damage"] = "Dégâts",

        -- what Enter does on a line, and the extra actions of its context menu
        ["Ask to join"] = "Demander à rejoindre",
        ["Invite"] = "Inviter",
        ["Right click menu"] = "Menu du clic droit",
        ["Remove"] = "Retirer",
        ["Where is this player"] = "Où est ce joueur",
        ["Rate {count} stars"] = "Noter {count} étoiles",
        ["Rate 1 star"] = "Noter 1 étoile",

        -- the level range boxes
        ["{label}, minimum"] = "{label}, minimum",
        ["{label}, maximum"] = "{label}, maximum",
        ["Settings"] = "Réglages",

        -- the keys, in WowVision's Bindings screen
        ["Open or close LFG Forever"] = "Ouvrir ou fermer LFG Forever",

        -- /wvlfg
        ["LFG Forever is not loaded."] = "LFG Forever n'est pas chargé.",
        ["Use /wvlfg to open or close LFG Forever."] = "Utilisez /wvlfg pour ouvrir ou fermer LFG Forever.",
    },

    deDE = {
        ["Tabs"] = "Reiter",
        ["Category"] = "Kategorie",
        ["Activity"] = "Aktivität",
        ["Search"] = "Suche",
        ["Search results"] = "Suchergebnisse",
        ["Searching"] = "Suche läuft",
        ["Groups"] = "Gruppen",
        ["Players"] = "Spieler",
        ["Group"] = "Gruppe",
        ["Player"] = "Spieler",
        ["collapsed"] = "eingeklappt",
        ["expanded"] = "ausgeklappt",
        ["{label}, {count}"] = "{label}, {count}",
        ["{count} members"] = "{count} Mitglieder",
        ["{count} members ({roles})"] = "{count} Mitglieder ({roles})",
        ["{count} {role}"] = "{count} {role}",
        ["roles: {roles}"] = "Rollen: {roles}",
        ["level {level} {class}"] = "Stufe {level} {class}",
        ["level {level}"] = "Stufe {level}",
        ["in {zone}"] = "in {zone}",
        ["{count} activities"] = "{count} Aktivitäten",
        ["your own listing"] = "Ihr eigener Eintrag",
        ["listing removed"] = "Eintrag entfernt",
        ["welcomes new players"] = "neulingsfreundlich",
        ["details unavailable"] = "Details nicht verfügbar",
        ["message unavailable"] = "Nachricht nicht verfügbar",
        ["already asked"] = "schon angefragt",
        ["rated {count} of 3 stars"] = "mit {count} von 3 Sternen bewertet",
        ["not rated"] = "nicht bewertet",
        ["has changed filters"] = "Filter sind geändert",
        ["Tank"] = "Tank",
        ["Healer"] = "Heiler",
        ["Damage"] = "Schaden",

        ["Ask to join"] = "Beitritt anfragen",
        ["Invite"] = "Einladen",
        ["Right click menu"] = "Rechtsklick-Menü",
        ["Remove"] = "Entfernen",
        ["Where is this player"] = "Wo ist dieser Spieler",
        ["Rate {count} stars"] = "Mit {count} Sternen bewerten",
        ["Rate 1 star"] = "Mit 1 Stern bewerten",

        ["{label}, minimum"] = "{label}, Minimum",
        ["{label}, maximum"] = "{label}, Maximum",
        ["Settings"] = "Einstellungen",

        ["Open or close LFG Forever"] = "LFG Forever öffnen oder schließen",

        ["LFG Forever is not loaded."] = "LFG Forever ist nicht geladen.",
        ["Use /wvlfg to open or close LFG Forever."] = "Mit /wvlfg öffnen oder schließen Sie LFG Forever.",
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
