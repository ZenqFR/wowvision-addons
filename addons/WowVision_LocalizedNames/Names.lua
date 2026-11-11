-- The name of a WowNav target in the game's language.
--
-- WowNav's catalogues carry each creature and object with its game ID and two
-- names: English and German. On any other client the navigation list (F10)
-- and the route announcements therefore read English. Questie's database
-- (QuestieDB) holds the same creatures and objects by ID with their names in
-- the client's language, so the ID is enough to find the right one.
--
-- Questie's own globals are the public door: NpcDB.Get(id, "name") and
-- ObjectDB.Get(id, "name") answer in the active language, GetRaw in English.
local _, ns = ...

local Names = {}
ns.Names = Names

-- Locales WowNav's data already names: left alone.
local OWN_LOCALES = { enUS = true, enGB = true, deDE = true }

-- Which of Questie's tables an ID of a WowNav target kind belongs to.
local DATABASE_OF_KIND = {
    npc = "NpcDB",
    mob = "NpcDB",
    creature = "NpcDB",
    gameobject = "ObjectDB",
    herb = "ObjectDB",
    mining = "ObjectDB",
    mailbox = "ObjectDB",
}

local function newCache()
    return { NpcDB = { name = {}, subName = {} }, ObjectDB = { name = {}, subName = {} } }
end
local cache = newCache()

-- Read through the global every time: the saved-variable table can be handed
-- over after load on WoW: Forever.
function Names.isEnabled()
    local db = _G.WowVisionLocalizedNamesDB
    if type(db) == "table" and db.enabled ~= nil then
        return db.enabled == true
    end
    return true
end

function Names.setEnabled(enabled)
    if type(_G.WowVisionLocalizedNamesDB) ~= "table" then
        _G.WowVisionLocalizedNamesDB = {}
    end
    _G.WowVisionLocalizedNamesDB.enabled = enabled == true
end

function Names.appliesToLocale()
    local locale = GetLocale ~= nil and GetLocale() or "enUS"
    return not OWN_LOCALES[locale]
end

local function isSecret(value)
    if WowVision ~= nil and WowVision.isSecret ~= nil then
        return WowVision.isSecret(value) == true
    end
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Questie answers in its own language setting ("auto" follows the game, but
-- it can be forced), and until its start-up has run it still says English.
-- Its names are used only while that language is the client's. When Questie
-- cannot be asked, it is taken to agree.
local function questieSpeaksClientLanguage()
    if QuestieLoader == nil or type(QuestieLoader.ImportModule) ~= "function" then
        return true
    end
    local ok, l10n = pcall(QuestieLoader.ImportModule, QuestieLoader, "l10n")
    if not ok or type(l10n) ~= "table" or type(l10n.GetUILocale) ~= "function" then
        return true
    end
    local asked, uiLocale = pcall(l10n.GetUILocale, l10n)
    return not asked or uiLocale == nil or uiLocale == GetLocale()
end

-- A text field ("name", "subName") Questie gives an ID, or nil. A miss is
-- remembered, but only when Questie could be asked properly: a lookup before
-- its table exists, or before it speaks the client's language, must be able to
-- succeed later.
local function lookup(databaseName, id, field)
    local database = _G[databaseName]
    if type(database) ~= "table" or type(database.Get) ~= "function" then
        return nil
    end
    local remembered = cache[databaseName][field]
    local known = remembered[id]
    if known ~= nil then
        return known or nil
    end
    if not questieSpeaksClientLanguage() then
        return nil
    end
    local ok, value = pcall(database.Get, id, field)
    if ok and type(value) == "string" and not isSecret(value) and value ~= "" then
        remembered[id] = value
        return value
    end
    remembered[id] = false
    return nil
end

-- WowNav writes the title an NPC carries under its name in parentheses:
-- "Innkeeper Grosk (Innkeeper)", "Pyall Silentstride (Cook)". Players search
-- by it ("cook"), so the localized name keeps one: Questie's title for the NPC
-- in the same place.
local function hasTitle(nameEn)
    return type(nameEn) == "string" and nameEn:find("%b()%s*$") ~= nil
end

-- target: a class or a row of WowNav's catalogue (kind, entry, nameKey...).
-- Returns the localized name, or nil when the target is not a creature or an
-- object with an ID, is named by a template (dungeon entrances, docks), or
-- Questie does not know it.
function Names.localName(target)
    if type(target) ~= "table" or target.nameKey ~= nil then
        return nil
    end
    local entry = target.entry
    if type(entry) ~= "number" or isSecret(entry) then
        return nil
    end
    local databaseName = DATABASE_OF_KIND[target.kind]
    if databaseName == nil then
        return nil
    end
    local name = lookup(databaseName, entry, "name")
    if name ~= nil and databaseName == "NpcDB" and hasTitle(target.nameEn) then
        local title = lookup(databaseName, entry, "subName")
        if title ~= nil then
            name = name .. " (" .. title .. ")"
        end
    end
    return name
end

function Names.clearCache()
    cache = newCache()
end

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

-- A target as WowNav's own naming should see it: both names replaced by the
-- localized one, so everything WowNav adds around a name (the suffix that
-- tells two alike targets apart) still comes from WowNav. A copy: the class
-- rows are shared and must not be changed.
function Names.localized(target)
    local name = Names.localName(target)
    if name == nil then
        return target
    end
    local copy = shallowCopy(target)
    copy.nameEn = name
    copy.nameDe = name
    return copy
end
