-- Spoken strings. The keys are the English sentences themselves, so English needs no table: a key without a
-- translation reads as itself. Words that WowVision already has in French and German (auction house = "Hôtel des
-- ventes" / "Auktionshaus", merchant = "marchand" / "Händler") are taken from its own locale files; the sentences
-- around them are the author's own wording. German has not been checked by a native speaker.
--
-- A sentence with several parts uses named places, {count}, {percent}..., filled by ns.fill, because the order of the
-- words is not the same in every language.
local _, ns = ...

local TRANSLATIONS = {
    frFR = {
        -- the stop
        ["For sale at the auction house"] = "À vendre à l'hôtel des ventes",

        -- the summary line, said first when Tab reaches the stop
        ["{title}: no item in your bags sells for at least {percent} percent more at the auction house than to a vendor."] = "{title} : aucun objet de vos sacs ne se vend au moins {percent} pour cent plus cher à l'hôtel des ventes que chez un marchand.",
        ["{title}: {count} item sells for at least {percent} percent more at the auction house than to a vendor."] = "{title} : {count} objet se vend au moins {percent} pour cent plus cher à l'hôtel des ventes que chez un marchand.",
        ["{title}: {count} items sell for at least {percent} percent more at the auction house than to a vendor."] = "{title} : {count} objets se vendent au moins {percent} pour cent plus cher à l'hôtel des ventes que chez un marchand.",
        ["Estimated gain {gain}, auction house fees not deducted."] = "Gain estimé {gain}, frais de l'hôtel des ventes non déduits.",
        ["Estimated gain {gain}, after the auction house's cut of {cut} percent (the deposit comes back when an item sells)."] = "Gain estimé {gain}, après la commission de {cut} pour cent de l'hôtel des ventes (le dépôt revient quand l'objet se vend).",
        ["Prices counted after the auction house's cut of {cut} percent."] = "Prix comptés après la commission de {cut} pour cent de l'hôtel des ventes.",
        ["{count} item is not loaded yet, its vendor price is unknown."] = "{count} objet n'est pas encore chargé, son prix marchand est inconnu.",
        ["{count} items are not loaded yet, their vendor prices are unknown."] = "{count} objets ne sont pas encore chargés, leurs prix marchand sont inconnus.",
        ["Warning, these prices are old."] = "Attention, ces prix sont anciens.",
        ["Prices from Life on Azeroth Market, taken {date}, {ago}."] = "Prix de Life on Azeroth Market relevés le {date}, {ago}.",
        ["Prices from Life on Azeroth Market, date unknown."] = "Prix de Life on Azeroth Market, date inconnue.",
        ["These are the prices of another auction house: {house}."] = "Ce sont les prix d'un autre hôtel des ventes : {house}.",
        ["{title}: no prices available. Life on Azeroth Market is not installed, or its companion app has not made a price list yet."] = "{title} : aucun prix disponible. Life on Azeroth Market n'est pas installé, ou son application compagnon n'a pas encore fait de relevé.",

        -- a date and how long ago it was
        ["{month} {day} at {hour}:{minute}"] = "{day} {month} à {hour} h {minute}",
        ["just now"] = "à l'instant",
        ["{count} minute ago"] = "il y a {count} minute",
        ["{count} minutes ago"] = "il y a {count} minutes",
        ["{count} hour ago"] = "il y a {count} heure",
        ["{count} hours ago"] = "il y a {count} heures",
        ["{count} day ago"] = "il y a {count} jour",
        ["{count} days ago"] = "il y a {count} jours",
        ["January"] = "janvier",
        ["February"] = "février",
        ["March"] = "mars",
        ["April"] = "avril",
        ["May"] = "mai",
        ["June"] = "juin",
        ["July"] = "juillet",
        ["August"] = "août",
        ["September"] = "septembre",
        ["October"] = "octobre",
        ["November"] = "novembre",
        ["December"] = "décembre",

        -- one line of the list: the name and quantity, then the prices (the colon is part of the second sentence)
        ["{name}, {count} in {stacks} stacks"] = "{name}, {count} au total en {stacks} piles",
        [": vendor {vendor}, auction house {auction}, {percent} percent more, estimated gain {gain}"] = " : marchand {vendor}, hôtel des ventes {auction}, plus {percent} pour cent, gain estimé {gain}",
        [": vendor {vendor} each, auction house {auction} each, {total} in all, {percent} percent more, estimated gain {gain}"] = " : marchand {vendor} l'unité, hôtel des ventes {auction} l'unité, {total} en tout, plus {percent} pour cent, gain estimé {gain}",
        [": vendor {vendor}, auction house {auction}, {percent} percent more after the cut, estimated gain {gain}"] = " : marchand {vendor}, hôtel des ventes {auction}, plus {percent} pour cent après commission, gain estimé {gain}",
        [": vendor {vendor} each, auction house {auction} each, {total} in all, {percent} percent more after the cut, estimated gain {gain}"] = " : marchand {vendor} l'unité, hôtel des ventes {auction} l'unité, {total} en tout, plus {percent} pour cent après commission, gain estimé {gain}",
        [": vendor {vendor}"] = " : marchand {vendor}",
        [": vendor {vendor} each, {total} in all"] = " : marchand {vendor} l'unité, {total} en tout",
        [": the vendor does not buy it, auction house {auction}, estimated gain {gain}"] = " : le marchand ne le rachète pas, hôtel des ventes {auction}, gain estimé {gain}",
        [": the vendor does not buy it, auction house {auction} each, {total} in all, estimated gain {gain}"] = " : le marchand ne le rachète pas, hôtel des ventes {auction} l'unité, {total} en tout, gain estimé {gain}",

        -- money, when the game cannot say it itself
        ["Gold"] = "Or",
        ["Silver"] = "Argent",
        ["Copper"] = "Cuivre",

        -- /wvhdv
        ["{lines} in the list. Slots in the list: {slots}. Slots to sell to a merchant: {merchant}. Occupied slots in your bags: {total}, kept out of the list: {bound} bound, {noprice} without an auction house price, {below} under {percent} percent, {damaged} damaged; {pending} not loaded."] = "{lines} dans la liste. Emplacements dans la liste : {slots}. Emplacements à vendre à un marchand : {merchant}. Emplacements occupés de vos sacs : {total}, hors de la liste : {bound} liés, {noprice} sans prix à l'hôtel des ventes, {below} en dessous de {percent} pour cent, {damaged} abîmés ; {pending} pas encore chargés.",
        ["The list is not available during combat."] = "La liste n'est pas disponible pendant un combat.",
        ["Auction house cut taken off: {state}."] = "Commission de l'hôtel des ventes déduite : {state}.",
        ["yes, {cut} percent"] = "oui, {cut} pour cent",
        ["no"] = "non",
        ["Use /wvhdv fees on or off to take the auction house's cut off its prices, or not."] = "Utilisez /wvhdv frais oui ou non pour déduire ou non la commission de l'hôtel des ventes de ses prix.",
        ["WowVision's bags were not found; the auction house stop is not available."] = "Les sacs de WowVision sont introuvables ; l'arrêt de l'hôtel des ventes n'est pas disponible.",
    },

    deDE = {
        ["For sale at the auction house"] = "Zum Verkauf im Auktionshaus",

        ["{title}: no item in your bags sells for at least {percent} percent more at the auction house than to a vendor."] = "{title}: Kein Gegenstand in Ihren Taschen bringt im Auktionshaus mindestens {percent} Prozent mehr als beim Händler.",
        ["{title}: {count} item sells for at least {percent} percent more at the auction house than to a vendor."] = "{title}: {count} Gegenstand bringt im Auktionshaus mindestens {percent} Prozent mehr als beim Händler.",
        ["{title}: {count} items sell for at least {percent} percent more at the auction house than to a vendor."] = "{title}: {count} Gegenstände bringen im Auktionshaus mindestens {percent} Prozent mehr als beim Händler.",
        ["Estimated gain {gain}, auction house fees not deducted."] = "Geschätzter Gewinn {gain}, Gebühren des Auktionshauses nicht abgezogen.",
        ["Estimated gain {gain}, after the auction house's cut of {cut} percent (the deposit comes back when an item sells)."] = "Geschätzter Gewinn {gain}, nach Abzug der Provision des Auktionshauses von {cut} Prozent (die Anzahlung kommt zurück, wenn ein Gegenstand verkauft wird).",
        ["Prices counted after the auction house's cut of {cut} percent."] = "Preise nach Abzug der Provision des Auktionshauses von {cut} Prozent gerechnet.",
        ["{count} item is not loaded yet, its vendor price is unknown."] = "{count} Gegenstand ist noch nicht geladen, sein Händlerpreis ist unbekannt.",
        ["{count} items are not loaded yet, their vendor prices are unknown."] = "{count} Gegenstände sind noch nicht geladen, ihre Händlerpreise sind unbekannt.",
        ["Warning, these prices are old."] = "Achtung, diese Preise sind alt.",
        ["Prices from Life on Azeroth Market, taken {date}, {ago}."] = "Preise von Life on Azeroth Market, erfasst am {date}, {ago}.",
        ["Prices from Life on Azeroth Market, date unknown."] = "Preise von Life on Azeroth Market, Datum unbekannt.",
        ["These are the prices of another auction house: {house}."] = "Das sind die Preise eines anderen Auktionshauses: {house}.",
        ["{title}: no prices available. Life on Azeroth Market is not installed, or its companion app has not made a price list yet."] = "{title}: Keine Preise verfügbar. Life on Azeroth Market ist nicht installiert, oder seine Begleit-App hat noch keine Preisliste erstellt.",

        ["{month} {day} at {hour}:{minute}"] = "{day}. {month} um {hour}:{minute} Uhr",
        ["just now"] = "gerade eben",
        ["{count} minute ago"] = "vor {count} Minute",
        ["{count} minutes ago"] = "vor {count} Minuten",
        ["{count} hour ago"] = "vor {count} Stunde",
        ["{count} hours ago"] = "vor {count} Stunden",
        ["{count} day ago"] = "vor {count} Tag",
        ["{count} days ago"] = "vor {count} Tagen",
        ["January"] = "Januar",
        ["February"] = "Februar",
        ["March"] = "März",
        ["April"] = "April",
        ["May"] = "Mai",
        ["June"] = "Juni",
        ["July"] = "Juli",
        ["August"] = "August",
        ["September"] = "September",
        ["October"] = "Oktober",
        ["November"] = "November",
        ["December"] = "Dezember",

        ["{name}, {count} in {stacks} stacks"] = "{name}, {count} insgesamt in {stacks} Stapeln",
        [": vendor {vendor}, auction house {auction}, {percent} percent more, estimated gain {gain}"] = ": Händler {vendor}, Auktionshaus {auction}, {percent} Prozent mehr, geschätzter Gewinn {gain}",
        [": vendor {vendor} each, auction house {auction} each, {total} in all, {percent} percent more, estimated gain {gain}"] = ": Händler {vendor} pro Stück, Auktionshaus {auction} pro Stück, {total} insgesamt, {percent} Prozent mehr, geschätzter Gewinn {gain}",
        [": vendor {vendor}, auction house {auction}, {percent} percent more after the cut, estimated gain {gain}"] = ": Händler {vendor}, Auktionshaus {auction}, {percent} Prozent mehr nach Provision, geschätzter Gewinn {gain}",
        [": vendor {vendor} each, auction house {auction} each, {total} in all, {percent} percent more after the cut, estimated gain {gain}"] = ": Händler {vendor} pro Stück, Auktionshaus {auction} pro Stück, {total} insgesamt, {percent} Prozent mehr nach Provision, geschätzter Gewinn {gain}",
        [": vendor {vendor}"] = ": Händler {vendor}",
        [": vendor {vendor} each, {total} in all"] = ": Händler {vendor} pro Stück, {total} insgesamt",
        [": the vendor does not buy it, auction house {auction}, estimated gain {gain}"] = ": Der Händler kauft es nicht, Auktionshaus {auction}, geschätzter Gewinn {gain}",
        [": the vendor does not buy it, auction house {auction} each, {total} in all, estimated gain {gain}"] = ": Der Händler kauft es nicht, Auktionshaus {auction} pro Stück, {total} insgesamt, geschätzter Gewinn {gain}",

        ["Gold"] = "Gold",
        ["Silver"] = "Silber",
        ["Copper"] = "Kupfer",

        ["{lines} in the list. Slots in the list: {slots}. Slots to sell to a merchant: {merchant}. Occupied slots in your bags: {total}, kept out of the list: {bound} bound, {noprice} without an auction house price, {below} under {percent} percent, {damaged} damaged; {pending} not loaded."] = "{lines} in der Liste. Plätze in der Liste: {slots}. Plätze zum Verkauf an einen Händler: {merchant}. Belegte Plätze in Ihren Taschen: {total}, nicht in der Liste: {bound} gebunden, {noprice} ohne Auktionshauspreis, {below} unter {percent} Prozent, {damaged} beschädigt; {pending} nicht geladen.",
        ["The list is not available during combat."] = "Die Liste ist im Kampf nicht verfügbar.",
        ["Auction house cut taken off: {state}."] = "Provision des Auktionshauses abgezogen: {state}.",
        ["yes, {cut} percent"] = "ja, {cut} Prozent",
        ["no"] = "nein",
        ["Use /wvhdv fees on or off to take the auction house's cut off its prices, or not."] = "Mit /wvhdv gebuehren ja oder nein ziehen Sie die Provision des Auktionshauses von seinen Preisen ab oder nicht.",
        ["WowVision's bags were not found; the auction house stop is not available."] = "Die Taschen von WowVision wurden nicht gefunden; der Halt für das Auktionshaus ist nicht verfügbar.",
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

-- "{count}" and the like replaced by the values of the table; a name the table does not have stays as it is.
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
