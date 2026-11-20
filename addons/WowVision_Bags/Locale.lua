-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. French is the author's own wording of the terms WowVision already uses
-- ("Camelote" for junk); German is a translation by the author and has not been checked by a native speaker.
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        -- the lists of the bags
        ["Item Lists"] = "Listes d'objets",
        ["New Items"] = "Nouveaux objets",
        ["Junk"] = "Camelote",
        ["For sale to a merchant"] = "À vendre au marchand",
        ["Empty"] = "Vide",

        -- said ahead of a slot's name in brackets: [Junk], [Favorite]
        ["Favorite"] = "Favori",

        -- bindings and the slot's menu
        ["Select Junk"] = "Sélectionner camelote",
        ["Mark as Junk"] = "Marquer comme camelote",
        ["Unmark as Junk"] = "Ne plus marquer comme camelote",
        ["Select Favorite"] = "Sélectionner favori",
        ["Mark as Favorite"] = "Marquer comme favori",
        ["Unmark as Favorite"] = "Ne plus marquer comme favori",

        -- what is said when a slot is marked
        ["%s: marked as junk"] = "%s : marqué comme camelote",
        ["%s: no longer junk"] = "%s : n'est plus camelote",
        ["%s cannot be sold to a vendor."] = "%s ne peut pas être vendu à un marchand.",
        ["This item cannot be marked as junk."] = "Cet objet ne peut pas être marqué comme camelote.",
        ["%s: marked as favorite"] = "%s : marqué comme favori",
        ["%s: no longer a favorite"] = "%s : n'est plus favori",
        ["This item cannot be marked as a favorite."] = "Cet objet ne peut pas être marqué comme favori.",

        -- the sale at a merchant
        ["Sold %d poor quality items for %s."] = "%d objets de qualité médiocre vendus pour %s.",
        ["Sold marked junk for %s: %s."] = "Camelote marquée vendue pour %s : %s.",
        ["Sold marked junk and %d poor quality items for %s: %s."] = "Camelote marquée et %d objets de qualité médiocre vendus pour %s : %s.",
        ["%s and %d more"] = "%s et %d autres",

        -- /wvbags
        ["on"] = "activé",
        ["off"] = "désactivé",
        ["Junk marks"] = "Marques de camelote",
        ["Selling marked junk at merchants"] = "Vente de la camelote marquée chez les marchands",
        ["Favorites marks"] = "Marques de favoris",
        ["%s: %s"] = "%s : %s",
        ["Junk marks forgotten"] = "Marques de camelote oubliées",
        ["Favorites forgotten"] = "Favoris oubliés",
        ["No new item followed."] = "Aucun nouvel objet suivi.",
        ["New items followed: %s."] = "Nouveaux objets suivis : %s.",
        ["Use /wvbags junk, sell or favorites to switch one on or off (add on or off), /wvbags forget junk or forget favorites to take every mark off."] = "Utilisez /wvbags camelote, vente ou favoris pour activer ou désactiver (ajoutez on ou off), /wvbags oublier camelote ou oublier favoris pour retirer toutes les marques.",
        ["WowVision already has its own bag lists; WowVision Bags does nothing."] = "WowVision a déjà ses propres listes d'objets ; WowVision Sacs ne fait rien.",
        ["WowVision's bags were not found; the marks are not available."] = "Les sacs de WowVision sont introuvables ; les marques ne sont pas disponibles.",
        ["WowVision's bags were not found; the item lists are not available."] = "Les sacs de WowVision sont introuvables ; les listes d'objets ne sont pas disponibles.",
        ["WowVision's merchant window was not found; marked junk will not be sold."] = "La fenêtre de marchand de WowVision est introuvable ; la camelote marquée ne sera pas vendue.",
        ["WowVision's key bindings were not found; the marking keys are not available."] = "Les raccourcis de WowVision sont introuvables ; les touches de marquage ne sont pas disponibles.",
    },

    deDE = {
        ["Item Lists"] = "Gegenstandslisten",
        ["New Items"] = "Neue Gegenstände",
        ["Junk"] = "Plunder",
        ["For sale to a merchant"] = "Zum Verkauf beim Händler",
        ["Empty"] = "Leer",

        ["Favorite"] = "Favorit",

        ["Select Junk"] = "Plunder auswählen",
        ["Mark as Junk"] = "Als Plunder markieren",
        ["Unmark as Junk"] = "Plundermarkierung entfernen",
        ["Select Favorite"] = "Favorit auswählen",
        ["Mark as Favorite"] = "Als Favorit markieren",
        ["Unmark as Favorite"] = "Favoritenmarkierung entfernen",

        ["%s: marked as junk"] = "%s: als Plunder markiert",
        ["%s: no longer junk"] = "%s: ist kein Plunder mehr",
        ["%s cannot be sold to a vendor."] = "%s kann nicht an einen Händler verkauft werden.",
        ["This item cannot be marked as junk."] = "Dieser Gegenstand kann nicht als Plunder markiert werden.",
        ["%s: marked as favorite"] = "%s: als Favorit markiert",
        ["%s: no longer a favorite"] = "%s: ist kein Favorit mehr",
        ["This item cannot be marked as a favorite."] = "Dieser Gegenstand kann nicht als Favorit markiert werden.",

        ["Sold %d poor quality items for %s."] = "%d schlechte Gegenstände für %s verkauft.",
        ["Sold marked junk for %s: %s."] = "Markierter Plunder für %s verkauft: %s.",
        ["Sold marked junk and %d poor quality items for %s: %s."] = "Markierter Plunder und %d schlechte Gegenstände für %s verkauft: %s.",
        ["%s and %d more"] = "%s und %d weitere",

        ["on"] = "an",
        ["off"] = "aus",
        ["Junk marks"] = "Plundermarkierungen",
        ["Selling marked junk at merchants"] = "Verkauf markierten Plunders beim Händler",
        ["Favorites marks"] = "Favoritenmarkierungen",
        ["%s: %s"] = "%s: %s",
        ["Junk marks forgotten"] = "Plundermarkierungen vergessen",
        ["Favorites forgotten"] = "Favoriten vergessen",
        ["No new item followed."] = "Kein neuer Gegenstand verfolgt.",
        ["New items followed: %s."] = "Verfolgte neue Gegenstände: %s.",
        ["Use /wvbags junk, sell or favorites to switch one on or off (add on or off), /wvbags forget junk or forget favorites to take every mark off."] = "Mit /wvbags junk, sell oder favorites schalten Sie einen Teil an oder aus (on oder off anhängen), mit /wvbags forget junk oder forget favorites entfernen Sie alle Markierungen.",
        ["WowVision already has its own bag lists; WowVision Bags does nothing."] = "WowVision hat bereits eigene Gegenstandslisten; WowVision Bags tut nichts.",
        ["WowVision's bags were not found; the marks are not available."] = "Die Taschen von WowVision wurden nicht gefunden; die Markierungen sind nicht verfügbar.",
        ["WowVision's bags were not found; the item lists are not available."] = "Die Taschen von WowVision wurden nicht gefunden; die Gegenstandslisten sind nicht verfügbar.",
        ["WowVision's merchant window was not found; marked junk will not be sold."] = "Das Händlerfenster von WowVision wurde nicht gefunden; markierter Plunder wird nicht verkauft.",
        ["WowVision's key bindings were not found; the marking keys are not available."] = "Die Tastenbelegung von WowVision wurde nicht gefunden; die Markierungstasten sind nicht verfügbar.",
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
