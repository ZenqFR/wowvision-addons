-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- The game and Questie are mocked; WowVision's own naming code
-- (camelot/wownav/text.lua) is loaded for real, so the tests exercise the
-- function the destination list and the route announcements actually call.
-- They need WowVision installed next to this addon (../WowVision).

local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local wowVision = os.getenv("WOWVISION_DIR") or (addonDir .. "/../WowVision")

-- ----------------------------------------------------------------- harness

local passed, failed = 0, 0

local function out(text)
    io.write(text, "\n")
end

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        out("FAIL  " .. name .. "\n      " .. tostring(err))
    end
end

local function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "") .. "\n    expected " .. tostring(expected) .. "\n    got      " .. tostring(actual), 2)
    end
end

-- ------------------------------------------------------------------ mocks

local locale = "frFR"
GetLocale = function()
    return locale
end

local spoken = {}
WowVision = {
    isSecret = function() return false end,
}
function WowVision:getLocale()
    return setmetatable({}, { __index = function(_, key) return key end })
end
function WowVision:speak(message)
    spoken[#spoken + 1] = message
end

local function load(path, ...)
    local chunk = assert(loadfile(path))
    return chunk(...)
end

-- WowNav's naming as it was before WowVision learned to name targets in the game's language itself: the
-- table this addon wraps. (The real, newer file is loaded further down, for the test that checks the addon
-- leaves it alone.)
local text = {
    targetName = function(target, german)
        -- WowNav names in German for a German client, or when the caller asks for it
        local name = (german == true or GetLocale() == "deDE") and target.nameDe or target.nameEn
        if target.nameKey ~= nil then
            name = "template " .. tostring(target.nameParam)
        end
        if target.nameSuffix ~= nil and target.nameSuffix.key == "number" then
            name = name .. " (" .. tostring(target.nameSuffix.value) .. ")"
        end
        return name
    end,
}
WowVision.wownavText = text
function WowVisionNavigationTargetName(target)
    return WowVision.wownavText.targetName(target)
end
local originalTargetName = text.targetName

-- Questie's two databases, as the game exposes them: Get answers in the
-- client's language.
local lookups
local function database(names, titles)
    return {
        Get = function(id, key)
            assert(key == "name" or key == "subName")
            if key == "subName" then
                return titles and titles[id] or nil
            end
            lookups[#lookups + 1] = id
            local value = names[id]
            if value == "error" then
                error("boom")
            end
            return value
        end,
    }
end

local function resetQuestie()
    lookups = {}
    NpcDB = database({
        [5893] = "Manifestation de feu mineure",
        [10556] = "Péon fainéant",
        [3294] = "Ophek",
        [6607] = "Harroc",
        [7000] = "error",
    })
    ObjectDB = database({
        [1618] = "Pacifique",
        [1617] = "Feuillargent",
        [3314] = "Les Tarides",
        [104555] = "Enclume",
    })
end

local ns = {}
load(addonDir .. "/Locale.lua", "WowVision_LocalizedNames", ns)
load(addonDir .. "/Names.lua", "WowVision_LocalizedNames", ns)
load(addonDir .. "/Main.lua", "WowVision_LocalizedNames", ns)
local Names = ns.Names

local function reset()
    locale = "frFR"
    ns.useLocale("frFR")
    WowVisionLocalizedNamesDB = nil
    spoken = {}
    Names.clearCache()
    resetQuestie()
end

local function class(kind, entry, nameEn, nameDe, extra)
    local target = { kind = kind, entry = entry, nameEn = nameEn, nameDe = nameDe or nameEn }
    for key, value in pairs(extra or {}) do
        target[key] = value
    end
    return target
end

-- ------------------------------------------------------------------ tests

test("the hook is installed once, in front of WowNav's own naming", function()
    reset()
    eq(ns.installed, true)
    assert(text.targetName ~= originalTargetName, "targetName was not wrapped")
    eq(text.localizedNamesInstalled, true)
end)

test("an NPC reads its French name", function()
    reset()
    eq(text.targetName(class("npc", 10556, "Lazy Peon", "Fauler Peon")), "Péon fainéant")
end)

test("mobs and creatures use the creature database too", function()
    reset()
    eq(text.targetName(class("mob", 5893, "Minor Manifestation of Fire", "Schwache Feuermanifestation")),
        "Manifestation de feu mineure")
    eq(text.targetName(class("creature", 6607, "Harroc")), "Harroc")
end)

test("objects, herbs and ores use the object database", function()
    reset()
    eq(text.targetName(class("herb", 1618, "Peacebloom", "Friedensblume")), "Pacifique")
    eq(text.targetName(class("gameobject", 104555, "Anvil", "Amboss")), "Enclume")
    eq(text.targetName(class("gameobject", 3314, "The Barrens")), "Les Tarides")
    eq(text.targetName(class("mining", 1617, "Silverleaf")), "Feuillargent")
end)

test("a creature ID is not looked up among objects, nor the reverse", function()
    reset()
    -- 1618 is a herb; as a creature it is unknown, so the English name stays.
    eq(text.targetName(class("npc", 1618, "Not A Peacebloom")), "Not A Peacebloom")
    eq(text.targetName(class("herb", 10556, "Not A Peon")), "Not A Peon")
end)

test("an ID Questie does not know keeps WowNav's own name", function()
    reset()
    eq(text.targetName(class("npc", 99999, "Mystery Man", "Raetselmann")), "Mystery Man")
end)

test("no ID, no lookup", function()
    reset()
    eq(text.targetName(class("npc", nil, "Nameless")), "Nameless")
    eq(#lookups, 0)
end)

test("what WowNav adds around a name is kept (the suffix for two alike targets)", function()
    reset()
    local row = class("npc", 10556, "Lazy Peon", "Fauler Peon", { nameSuffix = { key = "number", value = 2 } })
    eq(text.targetName(row), "Péon fainéant (2)")
end)

test("names built from a template are left to WowNav", function()
    reset()
    local entrance = class("gameobject", 3314, "Ragefire Chasm", "Flammenschlund", {
        nameKey = "dungeon_entrance", nameParam = "Ragefire Chasm",
    })
    eq(text.targetName(entrance), originalTargetName(entrance))
    eq(#lookups, 0)
end)

test("a title in parentheses stays, in French: the cook is found by 'cuisinier'", function()
    reset()
    NpcDB = database({ [3191] = "Pyall Pas-Silencieux", [6928] = "Aubergiste Grosk" },
        { [3191] = "Cuisinier", [6928] = "Aubergiste" })
    eq(text.targetName(class("npc", 3191, "Pyall Silentstride (Cook)", "Pyall Leisetritt (Koch)")),
        "Pyall Pas-Silencieux (Cuisinier)")
    eq(text.targetName(class("npc", 6928, "Innkeeper Grosk (Innkeeper)")), "Aubergiste Grosk (Aubergiste)")
end)

test("no title in the English name: none is added (Questie's titles are not WowNav's)", function()
    reset()
    NpcDB = database({ [3294] = "Ophek" }, { [3294] = "Donneur de quêtes" })
    eq(text.targetName(class("npc", 3294, "Ophek")), "Ophek")
end)

test("a title Questie has no French for is left out, not left in English", function()
    reset()
    NpcDB = database({ [3191] = "Pyall Pas-Silencieux" }, {})
    eq(text.targetName(class("npc", 3191, "Pyall Silentstride (Cook)")), "Pyall Pas-Silencieux")
end)

test("objects never take a title", function()
    reset()
    ObjectDB = database({ [1618] = "Pacifique" }, { [1618] = "Ne devrait pas apparaître" })
    eq(text.targetName(class("herb", 1618, "Peacebloom (Herb)")), "Pacifique")
end)

test("the shared class row is never changed", function()
    reset()
    local shared = class("npc", 10556, "Lazy Peon", "Fauler Peon")
    text.targetName(shared)
    eq(shared.nameEn, "Lazy Peon")
    eq(shared.nameDe, "Fauler Peon")
end)

test("an English or German client is left alone", function()
    reset()
    locale = "enUS"
    eq(text.targetName(class("npc", 10556, "Lazy Peon", "Fauler Peon")), "Lazy Peon")
    locale = "deDE"
    eq(text.targetName(class("npc", 10556, "Lazy Peon", "Fauler Peon")), "Fauler Peon")
    eq(#lookups, 0)
end)

test("a caller that asks for German on purpose gets German", function()
    reset()
    eq(text.targetName(class("npc", 10556, "Lazy Peon", "Fauler Peon"), true), "Fauler Peon")
end)

test("other languages use Questie's answer as well", function()
    reset()
    locale = "esES"
    NpcDB = database({ [10556] = "Peón perezoso" })
    eq(text.targetName(class("npc", 10556, "Lazy Peon", "Fauler Peon")), "Peón perezoso")
end)

test("WowNav's global naming function reaches the French name", function()
    reset()
    eq(WowVisionNavigationTargetName(class("npc", 10556, "Lazy Peon", "Fauler Peon")), "Péon fainéant")
end)

test("Questie missing: English, and French as soon as it is there", function()
    reset()
    NpcDB, ObjectDB = nil, nil
    eq(text.targetName(class("npc", 10556, "Lazy Peon")), "Lazy Peon")
    resetQuestie()
    eq(text.targetName(class("npc", 10556, "Lazy Peon")), "Péon fainéant")
end)

test("Questie set to another language than the game is not used, until it agrees", function()
    reset()
    local uiLocale = "enUS"
    QuestieLoader = {
        ImportModule = function(_, name)
            assert(name == "l10n")
            return { GetUILocale = function() return uiLocale end }
        end,
    }
    eq(text.targetName(class("npc", 10556, "Lazy Peon")), "Lazy Peon", "Questie still says English")
    eq(#lookups, 0, "Questie was not asked")
    uiLocale = "frFR"
    eq(text.targetName(class("npc", 10556, "Lazy Peon")), "Péon fainéant", "the refusal was not remembered")
    QuestieLoader = nil
end)

test("a failing Questie lookup does not break naming", function()
    reset()
    eq(text.targetName(class("npc", 7000, "Broken One")), "Broken One")
end)

test("a secret name from the game is ignored", function()
    reset()
    WowVision.isSecret = function(value) return value == "Péon fainéant" end
    eq(text.targetName(class("npc", 10556, "Lazy Peon")), "Lazy Peon")
    WowVision.isSecret = function() return false end
end)

test("each ID is asked of Questie once", function()
    reset()
    for _ = 1, 5 do
        text.targetName(class("npc", 10556, "Lazy Peon"))
        text.targetName(class("npc", 99999, "Mystery Man"))
    end
    eq(#lookups, 2)
end)

test("/wvnames switches it off and on, and says so", function()
    reset()
    ns.handleCommand("off")
    eq(spoken[#spoken], "Noms localisés de la navigation : désactivés")
    eq(text.targetName(class("npc", 10556, "Lazy Peon")), "Lazy Peon")
    ns.handleCommand("on")
    eq(spoken[#spoken], "Noms localisés de la navigation : activés")
    eq(text.targetName(class("npc", 10556, "Lazy Peon")), "Péon fainéant")
    ns.handleCommand("")
    eq(spoken[#spoken], "Noms localisés de la navigation : activés", "no argument only reports")
end)

test("a saved-variable table replaced after load is still honoured", function()
    reset()
    Names.setEnabled(false)
    WowVisionLocalizedNamesDB = { enabled = true }
    eq(Names.isEnabled(), true)
end)

-- ------------------------------------------------------------- the languages

test("/wvnames speaks in French, German and English", function()
    reset()
    ns.useLocale("deDE")
    ns.handleCommand("nein")
    eq(spoken[#spoken], "Lokalisierte Namen in der Navigation: aus")
    ns.handleCommand("ja")
    eq(spoken[#spoken], "Lokalisierte Namen in der Navigation: an")
    ns.handleCommand("aus")
    eq(spoken[#spoken], "Lokalisierte Namen in der Navigation: aus")
    ns.handleCommand("an")
    eq(spoken[#spoken], "Lokalisierte Namen in der Navigation: an")
    ns.useLocale("enUS")
    ns.handleCommand("off")
    eq(spoken[#spoken], "Localized navigation names: off")
    ns.handleCommand("on")
    eq(spoken[#spoken], "Localized navigation names: on")
    ns.useLocale("frFR")
    ns.handleCommand("non")
    eq(spoken[#spoken], "Noms localisés de la navigation : désactivés")
    ns.handleCommand("oui")
    eq(spoken[#spoken], "Noms localisés de la navigation : activés")
    -- a language with no translation reads English
    ns.useLocale("esES")
    ns.handleCommand("")
    eq(spoken[#spoken], "Localized navigation names: on")
    ns.useLocale("frFR")
end)

test("every sentence the code says has a French and a German translation", function()
    local handle = assert(io.open(addonDir .. "/Main.lua", "rb"))
    local source = handle:read("a")
    handle:close()
    local keys = {}
    for key in source:gmatch('L%["(.-)"%]') do
        keys[key] = true
    end
    local count = 0
    for key in pairs(keys) do
        count = count + 1
        for _, locale in ipairs({ "frFR", "deDE" }) do
            local translated = ns.translations[locale][key]
            assert(translated ~= nil, locale .. " has no translation of: " .. key)
            assert(translated ~= key, locale .. " says it in English: " .. key)
        end
    end
    assert(count >= 3, "the keys were not found")
    for _, locale in ipairs({ "frFR", "deDE" }) do
        for key in pairs(ns.translations[locale]) do
            assert(keys[key], locale .. " translates something nothing says: " .. key)
        end
    end
end)

-- ---------------------------------------------- when WowVision does it

-- The newer WowVision names targets in the game's language itself (WowVision.wownavText.localName). Its real file is
-- loaded here, so the day it changes this fails instead of the addon silently doubling up.
local function newerWowVisionText()
    local path = wowVision .. "/camelot/wownav/text.lua"
    local handle = io.open(path, "rb")
    if handle == nil then
        return nil
    end
    local source = handle:read("a")
    handle:close()
    if not source:find("function text.localName", 1, true) then
        return nil
    end
    local saved = WowVision.wownavText
    local chunk = assert(loadfile(path))
    chunk()
    local newer = WowVision.wownavText
    WowVision.wownavText = saved
    return newer
end

test("a WowVision that names targets itself is left alone", function()
    reset()
    local newer = newerWowVisionText()
    if newer == nil then
        out("      (this WowVision has no localName: skipped)")
        return
    end
    local before = newer.targetName
    local saved = WowVision.wownavText
    WowVision.wownavText = newer
    local other = {}
    load(addonDir .. "/Locale.lua", "WowVision_LocalizedNames", other)
    load(addonDir .. "/Names.lua", "WowVision_LocalizedNames", other)
    load(addonDir .. "/Main.lua", "WowVision_LocalizedNames", other)
    WowVision.wownavText = saved
    eq(other.installed, true)
    eq(other.standsAside, true)
    assert(newer.targetName == before, "targetName was wrapped")
    eq(newer.localizedNamesInstalled, nil)
end)

test("the command then says WowVision does it, in three languages, and changes nothing", function()
    reset()
    ns.standsAside = true
    ns.useLocale("enUS")
    ns.handleCommand("off")
    eq(spoken[#spoken], "WowVision now names creatures and objects in your language itself, with its own setting; this addon does nothing.")
    ns.useLocale("frFR")
    ns.handleCommand("")
    eq(spoken[#spoken], "WowVision nomme maintenant lui-même les créatures et les objets dans votre langue, avec son propre réglage ; cet addon ne fait rien.")
    ns.useLocale("deDE")
    ns.handleCommand("")
    eq(spoken[#spoken], "WowVision benennt Kreaturen und Objekte jetzt selbst in deiner Sprache, mit eigener Einstellung; dieses Addon tut nichts.")
    ns.standsAside = nil
    ns.useLocale("frFR")
    eq(WowVisionLocalizedNamesDB, nil, "the setting was touched")
end)
out(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
