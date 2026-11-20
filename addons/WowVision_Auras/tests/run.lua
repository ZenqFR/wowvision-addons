-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1 or newer). WowVision's REAL graph framework
-- (Builder, KeyGraph, node factories) and its REAL Aura buffer (core/buffers: Buffer, BufferItem, MessageItem,
-- types/AuraBuffer.lua, with the real component registry and class system) are loaded from the WowVision folder (or
-- WOWVISION_DIR); only the game is a stand-in: the auras, the game's refusal to list them in combat (the read by
-- index that raises), its tooltip, and the secret strings. This addon's files are loaded for real, in the order of the
-- .toc. tests/real_core.lua runs the keys against WowVision's real input manager.
local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local wowVisionDir = os.getenv("WOWVISION_DIR") or (addonDir .. "/../WowVision")

-- ----------------------------------------------------------------- harness

local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        io.write("FAIL  ", name, "\n      ", tostring(err), "\n")
    end
end

local function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function check(value, label)
    if not value then
        error(label or "expected a true value", 2)
    end
end

local function contains(text, part, label)
    if text == nil or not tostring(text):find(part, 1, true) then
        error((label or "text differs") .. ": expected it to contain '" .. part .. "', got " .. tostring(text), 2)
    end
end

tinsert = table.insert
tremove = table.remove
unpack = unpack or table.unpack
wipe = wipe or function(t)
    for key in pairs(t) do
        t[key] = nil
    end
    return t
end

local env = dofile(testsDir .. "/graph_env.lua")(wowVisionDir)
local graph = env.graph
local nodes = graph.nodes

local function loadWowVision(path, ...)
    local chunk, err = loadfile(wowVisionDir .. "/" .. path)
    if chunk == nil then
        error(err)
    end
    return chunk(...)
end

-- the field types of WowVision's class system that the Aura buffer's fields use (Array, Choice...), registered once
loadWowVision("core/fieldTypes.lua", nil, { classes = WowVision.classes })

local FILES = { "Locale", "Game", "Auras", "Screen", "Main" }

-- ------------------------------------------------------------------- world

-- An aura of the stand-in game.
local function aura(name, fields)
    local data = { name = name, applications = 0, duration = 0, dispelName = nil, description = "About " .. name }
    for key, value in pairs(fields or {}) do
        data[key] = value
    end
    return data
end

-- A secret string, as the game hands them to addons: it can be joined with ".." (the result is a plain string here, a
-- secret one in the game) and nothing else: no pattern, no table.concat, no comparing, no measuring.
local SECRET = {}
local secretMeta = {
    __concat = function(a, b)
        local left = type(a) == "table" and a.text or a
        local right = type(b) == "table" and b.text or b
        return left .. right
    end,
    __eq = function()
        error("a secret string cannot be compared")
    end,
    __len = function()
        error("a secret string cannot be measured")
    end,
}
local function secretString(text)
    return setmetatable({ text = text, secret = SECRET }, secretMeta)
end

-- config: locale, noBuffers (WowVision without its buffers), restricted (the game refuses the read by index),
-- secrets (the tooltip's lines are secret strings), noUnit (no player yet)
local function newWorld(config)
    config = config or {}
    local w = {
        spoken = {},
        errors = {},
        auras = { HELPFUL = {}, HARMFUL = {} },
        reads = 0,
        restricted = config.restricted == true,
        secrets = config.secrets == true,
        windows = {},
        opened = {},
        closed = {},
    }
    geterrorhandler = function()
        return function(err)
            w.errors[#w.errors + 1] = tostring(err)
        end
    end
    GetLocale = function()
        return config.locale or "enUS"
    end
    GetTime = function()
        return 1000
    end
    UnitExists = function(unit)
        return config.noUnit ~= true and unit == "player"
    end
    AuraUtil = { AuraFilters = {}, AuraFilterNegationPrefix = "!" }
    issecretvalue = function(value)
        return type(value) == "table" and value.secret == SECRET
    end
    C_StringUtil = {
        TruncateWhenZero = function(number)
            return number
        end,
        WrapString = function(text, prefix, suffix)
            return prefix .. text .. suffix
        end,
    }
    C_UnitAuras = {
        GetAuraDataByIndex = function(unit, index, filter)
            w.reads = w.reads + 1
            if w.restricted then
                error("Auras cannot be accessed when secret while tainted")
            end
            local base = filter:match("^(%u+)")
            return w.auras[base][index]
        end,
    }
    -- the frames the Aura buffer makes for its events
    CreateFrame = function()
        local frame = { events = {}, scripts = {} }
        function frame:RegisterEvent(event)
            self.events[event] = true
        end
        function frame:SetScript(kind, fn)
            self.scripts[kind] = fn
        end
        w.frame = frame
        return frame
    end

    WowVision.base = nil
    WowVision.speak = function(_, text)
        w.spoken[#w.spoken + 1] = text
    end
    WowVision.isSecret = function(value)
        return issecretvalue(value)
    end
    -- WowVision's real pieces, fresh each time (they register types, once per start of the game)
    WowVision.buffers = nil
    WowVision.components = nil
    loadWowVision("core/Event.lua")
    loadWowVision("core/Registry.lua")
    loadWowVision("core/ViewList.lua")
    for _, file in ipairs({ "components", "RegistryType", "ClassRegistryType", "ComponentRegistry" }) do
        loadWowVision("core/components/" .. file .. ".lua")
    end
    if not config.noBuffers then
        loadWowVision("core/buffers/Buffer.lua")
        loadWowVision("core/buffers/BufferItem.lua")
        loadWowVision("core/buffers/items/MessageItem.lua")
        loadWowVision("core/buffers/types/AuraBuffer.lua")
        -- the game's tooltip, as the Aura buffer's scanner reads it: lines of an aura, name first, time left last
        WowVision.buffers.AuraBuffer.scanner = {
            fill = function(unit, index, filter)
                local base = filter:match("^(%u+)")
                local data = w.auras[base][index]
                if data == nil then
                    return 0
                end
                w.filled = { unit = unit, index = index, filter = filter }
                local lines = { data.name, data.description }
                if data.duration > 0 then
                    lines[#lines + 1] = data.remainingText
                end
                w.lines = lines
                w.right = base == "HARMFUL" and data.dispelName or nil
                return #lines
            end,
            line = function(index)
                local text = w.lines[index]
                if w.secrets and text ~= nil then
                    return secretString(text)
                end
                return text
            end,
            right = function(index)
                if index ~= 1 or w.right == nil then
                    return nil
                end
                if w.secrets then
                    return secretString(w.right)
                end
                return w.right
            end,
        }
    end

    -- the window machinery of WowVision, as far as this addon asks
    local manager = { openWindows = {} }
    WowVision.UIHost = {
        windowManager = manager,
        openTemporaryWindow = function(_, window)
            manager.openWindows[#manager.openWindows + 1] = { name = window.name, config = window.graphScreen }
            w.opened[#w.opened + 1] = window
        end,
        closeWindow = function(_, name)
            for index = #manager.openWindows, 1, -1 do
                if manager.openWindows[index].name == name then
                    table.remove(manager.openWindows, index)
                end
            end
            w.closed[#w.closed + 1] = name
        end,
    }
    if config.noHost then
        WowVision.UIHost = nil
    end

    -- the keys: a stand-in input manager that records what is created
    w.bindings = {}
    w.input = {
        getBinding = function(_, key)
            return w.bindings[key]
        end,
        createBinding = function(_, info)
            local binding = { info = info, activated = false }
            function binding:activate()
                self.activated = true
            end
            w.bindings[info.key] = binding
            return binding
        end,
        getDefaultDB = function()
            return {}
        end,
    }
    WowVision.input = w.input
    WowVision.dbManager = {
        resolveBindings = function()
            return {}
        end,
    }
    w.applied = 0
    WowVision.applyBindingStore = function()
        w.applied = w.applied + 1
    end
    WowVisionDB = {}
    WowVision.globalDb = {}
    SlashCmdList = {}

    -- the addon
    local ns = {}
    for _, name in ipairs(FILES) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_Auras", ns)
    end
    w.ns = ns
    if config.locale ~= nil then
        ns.useLocale(config.locale)
    end

    -- helpers for the tests
    function w:set(kind, list)
        self.auras[kind] = list
    end
    -- the game says a unit's auras changed; the buffers rebuild on the next frame
    function w:changed()
        local events = self.frame.scripts.OnEvent
        events(self.frame, "UNIT_AURA", "player")
        self.frame.scripts.OnUpdate()
    end
    function w:driver()
        return env.driver(function(builder)
            ns.Screen.render(builder)
        end)
    end
    function w:walk()
        local d = self:driver()
        local out = {}
        for _, node in ipairs(d.nodes()) do
            out[#out + 1] = { stop = node.stopKey, text = d.say(node), node = node }
        end
        return out, d
    end
    return w
end

local function texts(rows, stop)
    local out = {}
    for _, row in ipairs(rows) do
        if stop == nil or row.stop == stop then
            out[#out + 1] = row.text
        end
    end
    return out
end

-- the world most tests start from: two buffs, one debuff
local function usual(config)
    local w = newWorld(config)
    w:set("HELPFUL", {
        aura("Power Word: Fortitude", { duration = 3600, remainingText = "59 minutes remaining" }),
        aura("Renew", { applications = 2, duration = 15, remainingText = "12 seconds remaining" }),
    })
    w:set("HARMFUL", {
        aura("Deadly Poison", { duration = 30, dispelName = "Poison", remainingText = "8 seconds remaining" }),
    })
    return w
end

-- ================================================================== locale

test("locale: every sentence the addon says has a French and a German version", function()
    local w = newWorld()
    local keys = {}
    for _, name in ipairs(FILES) do
        local file = assert(io.open(addonDir .. "/" .. name .. ".lua", "rb"))
        local source = file:read("a")
        file:close()
        for key in source:gmatch('L%["(.-)"%]') do
            keys[key] = true
        end
    end
    -- the key bindings' labels are named in the table of Main.lua and translated when the keys are made, the names of
    -- the groups in the table of Auras.lua and translated when they are read
    for _, info in ipairs(w.ns.bindings) do
        keys[info.label] = true
    end
    for _, group in ipairs(w.ns.Auras.GROUPS) do
        keys[group.label] = true
    end
    local missing = {}
    for key in pairs(keys) do
        for _, locale in ipairs({ "frFR", "deDE" }) do
            local value = w.ns.TRANSLATIONS[locale][key]
            if value == nil then
                missing[#missing + 1] = locale .. ": " .. key
            else
                for place in key:gmatch("{(%w+)}") do
                    if not value:find("{" .. place .. "}", 1, true) then
                        missing[#missing + 1] = locale .. " lacks {" .. place .. "}: " .. key
                    end
                end
            end
        end
    end
    table.sort(missing)
    eq(#missing, 0, "untranslated: " .. table.concat(missing, " | "))
    for _, locale in ipairs({ "frFR", "deDE" }) do
        for key in pairs(w.ns.TRANSLATIONS[locale]) do
            check(keys[key], locale .. " has a sentence nothing says: " .. key)
        end
    end
end)

test("locale: the group names are WowVision's own words", function()
    local function read(path)
        local file = assert(io.open(path, "rb"))
        local text = file:read("a")
        file:close()
        return text
    end
    local w = newWorld()
    for locale, folder in pairs({ frFR = "frFR", deDE = "deDE" }) do
        local buffers = read(wowVisionDir .. "/locale/" .. folder .. "/buffers.lua")
        for _, key in ipairs({ "Player Buffs", "Player Debuffs" }) do
            local theirs = buffers:match('L%["' .. key .. '"%] = "(.-)"')
            eq(w.ns.TRANSLATIONS[locale][key], theirs, locale .. " " .. key)
        end
        eq(w.ns.TRANSLATIONS[locale]["unavailable"], buffers:match('L%["unavailable"%] = "(.-)"'), locale .. " unavailable")
    end
end)

test("locale: English reads as the keys, fill replaces named places and leaves unknown ones", function()
    local w = newWorld({ locale = "enUS" })
    eq(w.ns.L["Player Buffs"], "Player Buffs")
    eq(w.ns.fill("{a} and {b} {zzz}", { a = 1, b = "x" }), "1 and x {zzz}")
    w.ns.useLocale("frFR")
    eq(w.ns.L["Player Buffs"], "Améliorations du joueur")
    w.ns.useLocale("koKR")
    eq(w.ns.L["Player Buffs"], "Player Buffs")
end)

test("toc: the .toc lists the files the tests load, in the same order", function()
    local file = assert(io.open(addonDir .. "/WowVision_Auras.toc", "rb"))
    local listed = {}
    for line in file:read("a"):gmatch("[^\r\n]+") do
        local name = line:match("^([%w_]+)%.lua$")
        if name ~= nil then
            listed[#listed + 1] = name
        end
    end
    file:close()
    eq(table.concat(listed, ","), table.concat(FILES, ","))
end)

-- ================================================================= buffers

test("buffers: one for the buffs and one for the debuffs, made once, private to this addon", function()
    local w = usual()
    local buffs = w.ns.Game.buffer("buffs")
    local debuffs = w.ns.Game.buffer("debuffs")
    check(buffs ~= nil and debuffs ~= nil and buffs ~= debuffs, table.concat(w.errors, " | "))
    eq(buffs.sources[1], "player:HELPFUL")
    eq(debuffs.sources[1], "player:HARMFUL")
    eq(#buffs.sources, 1)
    eq(buffs.speakRemaining, true)
    eq(buffs.speakDescription, false, "the description is for Space")
    eq(w.ns.Game.buffer("buffs"), buffs, "made once")
    -- not registered among WowVision's own buffers: nothing of the player's saved buffers changes
    eq(#WowVision.buffers.registry:getComponents(), 0)
end)

test("buffers: WowVision without an Aura buffer gives none, and nothing breaks", function()
    local w = newWorld({ noBuffers = true })
    eq(w.ns.Game.buffer("buffs"), nil)
    eq(w.ns.Game.items("buffs", true), nil)
    eq(w.ns.Auras.read(true), nil)
end)

test("buffers: a buffer that cannot be made is reported once and is nothing", function()
    local w = usual()
    local registry = WowVision.buffers.registry
    registry.createTemporaryComponent = function()
        error("no buffer for you")
    end
    eq(w.ns.Game.buffer("buffs"), nil)
    eq(w.ns.Game.buffer("buffs"), nil)
    eq(#w.errors, 1)
    contains(w.errors[1], "WowVision_Auras: ")
    contains(w.errors[1], "no buffer for you")
end)

test("buffers: refreshing reads the game again; a failing rebuild is reported", function()
    local w = usual()
    local items = w.ns.Game.items("buffs", false)
    eq(#items, 2)
    w:set("HELPFUL", { aura("Only One", {}) })
    eq(#w.ns.Game.items("buffs", false), 2, "not refreshed: as before")
    eq(#w.ns.Game.items("buffs", true), 1, "refreshed")
    w.ns.Game.buffer("buffs").rebuild = function()
        error("rebuild broke")
    end
    w.ns.Game.items("buffs", true)
    eq(#w.errors, 1)
    contains(w.errors[1], "rebuild broke")
end)

test("buffers: the game says the auras changed, the buffer follows without asking", function()
    local w = usual()
    eq(#w.ns.Game.items("buffs", true), 2)
    w:set("HELPFUL", { aura("A", {}), aura("B", {}), aura("C", {}) })
    w:changed()
    eq(#w.ns.Game.items("buffs", false), 3)
end)

-- =================================================================== lines

test("lines: a line says the name, the stacks, the time left, and for a debuff its dispel type", function()
    local w = usual()
    local groups = w.ns.Auras.read(true)
    eq(#groups, 2)
    eq(groups[1].key, "buffs")
    eq(groups[2].key, "debuffs")
    eq(#groups[1].auras, 2)
    eq(#groups[2].auras, 1)
    eq(w.ns.Game.line(groups[1].auras[1]), "Power Word: Fortitude, 59 minutes remaining")
    eq(w.ns.Game.line(groups[1].auras[2]), "Renew, 2 stacks, 12 seconds remaining")
    eq(w.ns.Game.line(groups[2].auras[1]), "Deadly Poison, 8 seconds remaining, Poison")
end)

test("lines: a buff has no dispel type said, an aura without a duration has no time left", function()
    local w = newWorld()
    w:set("HELPFUL", { aura("Aura Mastery", { dispelName = "Magic" }) })
    w:set("HARMFUL", { aura("Curse of Weakness", { dispelName = "Curse" }) })
    local groups = w.ns.Auras.read(true)
    eq(w.ns.Game.line(groups[1].auras[1]), "Aura Mastery")
    eq(w.ns.Game.line(groups[2].auras[1]), "Curse of Weakness, Curse")
end)

test("lines: the buffs and the debuffs are the player's, nobody else's", function()
    local w = usual()
    w.ns.Auras.read(true)
    for _, kind in ipairs({ "buffs", "debuffs" }) do
        for _, item in ipairs(w.ns.Game.items(kind, false)) do
            eq(item.unit, "player")
        end
    end
end)

test("lines: a line that cannot be read says so, in the language", function()
    local w = usual({ locale = "frFR" })
    local groups = w.ns.Auras.read(true)
    groups[1].auras[1].getFocusString = function()
        error("gone")
    end
    eq(w.ns.Game.line(groups[1].auras[1]), "indisponible")
    groups[1].auras[1].getFocusString = function()
        return nil
    end
    eq(w.ns.Game.line(groups[1].auras[1]), "indisponible")
end)

test("lines: nothing to list gives the buffer's own message, and is not counted as an aura", function()
    local w = newWorld()
    local groups = w.ns.Auras.read(true)
    eq(#groups[1].auras, 0)
    eq(#groups[2].auras, 0)
    check(groups[1].message ~= nil)
    eq(w.ns.Game.line(groups[1].message), "Player Buffs, none")
    eq(w.ns.Game.line(groups[2].message), "Player Debuffs, none")
    -- no player yet
    w = newWorld({ noUnit = true })
    groups = w.ns.Auras.read(true)
    eq(#groups[1].auras, 0)
    contains(w.ns.Game.line(groups[1].message), "Player Buffs")
end)

-- ============================================================ what is said

test("say: the numbers, in the three languages", function()
    local w = usual({ locale = "enUS" })
    local groups = w.ns.Auras.read(true)
    eq(w.ns.Auras.countText(groups), "Player Buffs: 2. Player Debuffs: 1.")
    w.ns.useLocale("frFR")
    groups = w.ns.Auras.read(false)
    eq(w.ns.Auras.countText(groups), "Améliorations du joueur : 2. Affaiblissements du joueur : 1.")
    w.ns.useLocale("deDE")
    groups = w.ns.Auras.read(false)
    eq(w.ns.Auras.countText(groups), "Spieler-Buffs: 2. Spieler-Debuffs: 1.")
    w = newWorld({ locale = "enUS" })
    eq(w.ns.Auras.countText(w.ns.Auras.read(true)), "Player Buffs: 0. Player Debuffs: 0.")
end)

test("say: every buff then every debuff, each group with its number", function()
    local w = usual({ locale = "enUS" })
    local groups = w.ns.Auras.read(true)
    eq(
        w.ns.Auras.allText(groups),
        "Player Buffs: 2. Power Word: Fortitude, 59 minutes remaining. Renew, 2 stacks, 12 seconds remaining. "
            .. "Player Debuffs: 1. Deadly Poison, 8 seconds remaining, Poison"
    )
    w.ns.useLocale("frFR")
    groups = w.ns.Auras.read(false)
    contains(w.ns.Auras.allText(groups), "Améliorations du joueur : 2. Power Word: Fortitude")
    contains(w.ns.Auras.allText(groups), "Affaiblissements du joueur : 1. Deadly Poison")
end)

test("say: a group with none is said by the buffer's words, the other one still is", function()
    local w = newWorld({ locale = "enUS" })
    w:set("HARMFUL", { aura("Deadly Poison", { duration = 30, dispelName = "Poison", remainingText = "8 seconds remaining" }) })
    eq(w.ns.Auras.allText(w.ns.Auras.read(true)), "Player Buffs, none. Player Debuffs: 1. Deadly Poison, 8 seconds remaining, Poison")
    w = newWorld({ locale = "enUS" })
    w:set("HELPFUL", { aura("Mark of the Wild", {}) })
    eq(w.ns.Auras.allText(w.ns.Auras.read(true)), "Player Buffs: 1. Mark of the Wild. Player Debuffs, none")
    w = newWorld({ locale = "enUS" })
    eq(w.ns.Auras.allText(w.ns.Auras.read(true)), "Player Buffs, none. Player Debuffs, none")
end)

test("say: a group that has no message and no aura says its number, 0", function()
    local w = newWorld({ locale = "enUS" })
    local groups = w.ns.Auras.read(true)
    groups[1].message = nil
    eq(w.ns.Auras.allText(groups), "Player Buffs: 0. Player Debuffs, none")
end)

-- ============================================================== restricted

test("restricted: where the game refuses the read by index the tooltip's lines are used, and what is said still is", function()
    local w = usual({ restricted = true, locale = "enUS" })
    local groups = w.ns.Auras.read(true)
    eq(#groups[1].auras, 2, "counted by the tooltip")
    eq(#groups[2].auras, 1)
    local first = w.ns.Game.line(groups[1].auras[1])
    contains(first, "Power Word: Fortitude")
    contains(w.ns.Auras.allText(groups), "Player Debuffs: 1. Deadly Poison")
    contains(w.ns.Auras.allText(groups), "Poison")
end)

test("restricted: the lines are secret strings: only joined, never measured, compared or matched", function()
    local w = usual({ restricted = true, secrets = true, locale = "enUS" })
    local groups = w.ns.Auras.read(true)
    eq(#groups[1].auras, 2)
    local text = w.ns.Auras.allText(groups)
    contains(text, "Player Buffs: 2. ")
    contains(text, "Power Word: Fortitude")
    contains(text, "Deadly Poison")
    -- and the whole of it goes through the key and the screen without an error
    w.ns.sayAll()
    eq(#w.errors, 0, table.concat(w.errors, " | "))
    eq(#w.spoken, 1)
    contains(w.spoken[1], "Deadly Poison")
    local rows = w:walk()
    eq(#texts(rows, "auras:buffs"), 2)
    eq(#w.errors, 0, table.concat(w.errors, " | "))
end)

-- =================================================================== screen

test("screen: two stops, the buffs then the debuffs, a line per aura with its place in the list", function()
    local w = usual({ locale = "enUS" })
    w.ns.Auras.read(true)
    local rows, d = w:walk()
    eq(table.concat(d.kg:_stopOrder(), ","), "auras:buffs,auras:debuffs")
    local buffs = texts(rows, "auras:buffs")
    eq(#buffs, 2)
    contains(buffs[1], "Power Word: Fortitude, 59 minutes remaining")
    contains(buffs[1], "1 of 2")
    contains(buffs[2], "Renew, 2 stacks, 12 seconds remaining")
    contains(buffs[2], "2 of 2")
    local debuffs = texts(rows, "auras:debuffs")
    eq(#debuffs, 1)
    contains(debuffs[1], "Deadly Poison, 8 seconds remaining, Poison")
    -- the names of the groups are said when the focus enters them
    eq(rows[1].node.parent.vtable.announcements[1].text, "Player Buffs")
    eq(rows[3].node.parent.vtable.announcements[1].text, "Player Debuffs")
end)

test("screen: Tab goes from the buffs to the debuffs and round", function()
    local w = usual({ locale = "enUS" })
    w.ns.Auras.read(true)
    local rows, d = w:walk()
    d.kg:focus(rows[1].node.id)
    d.tab()
    eq(d.kg:currentNode().stopKey, "auras:debuffs")
    d.tab()
    eq(d.kg:currentNode().stopKey, "auras:buffs")
end)

test("screen: Space reads the aura's tooltip: each line carries its position for WowVision's Aura tooltip", function()
    local w = usual({ locale = "enUS" })
    w.ns.Auras.read(true)
    local rows = w:walk()
    local first = rows[1].node.vtable.tooltip
    eq(first.type, "Aura")
    eq(first.unit, "player")
    eq(first.index, 1)
    eq(first.filter, "HELPFUL")
    local second = rows[2].node.vtable.tooltip
    eq(second.index, 2)
    eq(second.filter, "HELPFUL")
    local debuff = rows[3].node.vtable.tooltip
    eq(debuff.type, "Aura")
    eq(debuff.index, 1)
    eq(debuff.filter, "HARMFUL")
end)

test("screen: the time left is read when the focus lands, not watched (it would be said again every second)", function()
    local w = usual({ locale = "enUS" })
    w.ns.Auras.read(true)
    local rows = w:walk()
    eq(rows[1].node.vtable.announcements[1].live, false)
end)

test("screen: a group with nothing in it still has its stop, and says it", function()
    local w = newWorld({ locale = "enUS" })
    w:set("HARMFUL", { aura("Deadly Poison", { duration = 30, dispelName = "Poison", remainingText = "8 seconds remaining" }) })
    w.ns.Auras.read(true)
    local rows, d = w:walk()
    eq(table.concat(d.kg:_stopOrder(), ","), "auras:buffs,auras:debuffs")
    local buffs = texts(rows, "auras:buffs")
    eq(#buffs, 1)
    contains(buffs[1], "Player Buffs, none")
    eq(rows[1].node.vtable.tooltip, nil, "nothing to read a tooltip of")
    w = newWorld({ locale = "enUS" })
    rows = w:walk()
    contains(texts(rows, "auras:buffs")[1], "Player Buffs, none")
    contains(texts(rows, "auras:debuffs")[1], "Player Debuffs, none")
end)

test("screen: a group the buffer gives no message for says its number", function()
    local w = newWorld({ locale = "enUS" })
    local original = w.ns.Auras.read
    w.ns.Auras.read = function(refresh)
        local groups = original(refresh)
        groups[1].message = nil
        return groups
    end
    local rows = w:walk()
    contains(texts(rows, "auras:buffs")[1], "Player Buffs: 0")
end)

test("screen: it follows the game: a new aura is a new line at the next drawing", function()
    local w = usual({ locale = "enUS" })
    w.ns.Auras.read(true)
    local d = w:driver()
    eq(#d.nodes(), 3)
    w:set("HELPFUL", { aura("A", {}), aura("B", {}), aura("C", {}), aura("D", {}) })
    eq(#d.nodes(), 3, "the buffer has not been told yet")
    w:changed()
    eq(#d.nodes(), 5)
    w:set("HARMFUL", {})
    w:changed()
    eq(#d.nodes(), 5, "one line fewer, and the debuffs group says none instead")
    local last = d.nodes()[5]
    contains(d.say(last), "Player Debuffs, none")
end)

test("screen: the same ids at every drawing, so the focus stays where it is", function()
    local w = usual({ locale = "enUS" })
    w.ns.Auras.read(true)
    local d = w:driver()
    local before, after = {}, {}
    for _, node in ipairs(d.nodes()) do
        before[#before + 1] = tostring(node.id.key)
    end
    for _, node in ipairs(d.nodes()) do
        after[#after + 1] = tostring(node.id.key)
    end
    eq(table.concat(after, ","), table.concat(before, ","))
    eq(before[1], "auras:buffs:1")
    eq(before[3], "auras:debuffs:1")
end)

test("screen: without the auras the screen says so", function()
    local w = newWorld({ noBuffers = true, locale = "enUS" })
    local rows, d = w:walk()
    eq(#rows, 1)
    contains(rows[1].text, "Auras are not available.")
    eq(table.concat(d.kg:_stopOrder(), ","), "auras:none")
end)

-- ================================================================== opening

test("open: the key opens the screen, again closes it, and the screen asks the game afresh as it opens", function()
    local w = usual({ locale = "enUS" })
    local reads = w.reads
    check(w.ns.Screen.toggle())
    eq(#w.opened, 1)
    eq(w.opened[1].name, "auras")
    check(w.reads > reads, "the game was asked as it opened")
    check(w.ns.Game.isOpen())
    local config = w.opened[1].graphScreen
    eq(type(config.render), "function")
    eq(config.key, "auras")
    eq(config.captureClose, true, "Escape is held by the screen: it is a frameless window")
    -- the screen config draws the same screen
    local d = env.driver(function(builder)
        config.render(builder)
    end)
    eq(#d.nodes(), 3)
    check(w.ns.Screen.toggle())
    eq(#w.closed, 1)
    eq(w.closed[1], "auras")
    check(not w.ns.Game.isOpen())
    -- Escape closes it
    w.ns.Screen.toggle()
    config = w.opened[2].graphScreen
    config.onRequestClose()
    eq(#w.closed, 2)
end)

test("open: without WowVision's windows it says so and does not break", function()
    local w = usual({ locale = "frFR", noHost = true })
    eq(w.ns.Screen.toggle(), false)
    eq(w.spoken[1], "Les fenêtres de WowVision ne sont pas disponibles.")
    check(not w.ns.Game.isOpen())
    w.ns.Game.close()
    eq(#w.errors, 0)
end)

-- ====================================================================== keys

test("keys: the two keys are bindings of WowVision's input manager, with the keys they are named for", function()
    local w = usual({ locale = "enUS" })
    check(w.ns.installed)
    local say, open = w.bindings["auras/say"], w.bindings["auras/open"]
    check(say ~= nil and open ~= nil)
    eq(say.info.inputs[1], "ALT-CTRL-B")
    eq(open.info.inputs[1], "ALT-SHIFT-B")
    eq(say.info.type, "Function")
    eq(say.info.interruptSpeech, true)
    check(say.activated and open.activated, "activated")
    eq(say.info.label, "Say the player's buffs and debuffs")
    eq(open.info.label, "Open the list of the player's buffs and debuffs")
    eq(w.applied, 1)
end)

test("keys: the labels are translated", function()
    local w = usual({ locale = "frFR" })
    eq(w.bindings["auras/say"].info.label, "Dire les améliorations et affaiblissements du joueur")
    eq(w.bindings["auras/open"].info.label, "Ouvrir la liste des améliorations et affaiblissements du joueur")
    w = usual({ locale = "deDE" })
    eq(w.bindings["auras/say"].info.label, "Buffs und Debuffs des Spielers sagen")
end)

test("keys: Alt+Ctrl+B says everything, Alt+Shift+B opens the list", function()
    local w = usual({ locale = "enUS" })
    w.bindings["auras/say"].info.func()
    eq(#w.spoken, 1)
    eq(
        w.spoken[1],
        "Player Buffs: 2. Power Word: Fortitude, 59 minutes remaining. Renew, 2 stacks, 12 seconds remaining. "
            .. "Player Debuffs: 1. Deadly Poison, 8 seconds remaining, Poison"
    )
    w.bindings["auras/open"].info.func()
    eq(#w.opened, 1)
    w.bindings["auras/open"].info.func()
    eq(#w.closed, 1)
end)

test("keys: a key that fails is reported once, never thrown", function()
    local w = usual()
    w.ns.Auras.read = function()
        error("read broke")
    end
    w.bindings["auras/say"].info.func()
    w.bindings["auras/say"].info.func()
    eq(#w.errors, 1)
    contains(w.errors[1], "read broke")
end)

test("keys: installing again makes none twice; no input manager, no keys and no error", function()
    local w = usual()
    local created = 0
    for _ in pairs(w.bindings) do
        created = created + 1
    end
    eq(created, 2)
    check(w.ns.installBindings())
    eq(w.applied, 1, "nothing new to apply")
    WowVision.input = nil
    eq(w.ns.installBindings(), false)
    WowVision.input = { getBinding = function() end }
    eq(w.ns.installBindings(), false, "no createBinding")
    WowVision.input = { createBinding = function() end }
    eq(w.ns.installBindings(), false, "no getBinding")
end)

test("keys: nothing to say without the auras, whichever way it is asked for", function()
    local w = newWorld({ noBuffers = true, locale = "frFR" })
    w.bindings["auras/say"].info.func()
    eq(w.spoken[1], "Les auras ne sont pas disponibles.")
    SlashCmdList["WVAURAS"]("nombre")
    eq(w.spoken[2], "Les auras ne sont pas disponibles.")
    SlashCmdList["WVAURAS"]("dire")
    eq(w.spoken[3], "Les auras ne sont pas disponibles.")
end)

test("keys: each press asks the game afresh, the buffers do not have to have been told", function()
    local w = usual({ locale = "enUS" })
    w.ns.sayAll()
    contains(w.spoken[1], "Player Buffs: 2.")
    w:set("HELPFUL", { aura("Only One", {}) })
    w.ns.sayAll()
    contains(w.spoken[2], "Player Buffs: 1. Only One.")
    w:set("HELPFUL", {})
    w.ns.sayCount()
    eq(w.spoken[3], "Player Buffs: 0. Player Debuffs: 1.")
end)

test("buffers: a game without the aura calls leaves an empty list, not an error", function()
    local w = newWorld({ locale = "enUS" })
    C_UnitAuras = nil
    local groups = w.ns.Auras.read(true)
    eq(#groups, 2)
    eq(#groups[1].auras, 0)
    eq(groups[1].message, nil)
    eq(w.ns.Auras.allText(groups), "Player Buffs: 0. Player Debuffs: 0")
    eq(w.ns.Auras.countText(groups), "Player Buffs: 0. Player Debuffs: 0.")
end)

test("speech: nothing is said for nothing", function()
    local w = newWorld()
    w.ns.Game.speak("")
    w.ns.Game.speak(nil)
    eq(#w.spoken, 0)
    w.ns.Game.speak("hello")
    eq(w.spoken[1], "hello")
    local saved = WowVision.speak
    WowVision.speak = nil
    local printed = {}
    local realPrint = print
    print = function(text)
        printed[#printed + 1] = text
    end
    w.ns.Game.speak("plain")
    print = realPrint
    WowVision.speak = saved
    eq(printed[1], "plain")
end)

-- ================================================================== command

test("command: /wvauras opens the list, say says them all, count says the numbers, help says how", function()
    local w = usual({ locale = "enUS" })
    check(SlashCmdList["WVAURAS"], "registered")
    eq(SLASH_WVAURAS1, "/wvauras")
    eq(SLASH_WVAURAS2, "/wvbuffs")
    eq(SLASH_WVAURAS3, "/wvauren")
    SlashCmdList["WVAURAS"]("")
    eq(#w.opened, 1)
    SlashCmdList["WVAURAS"]("")
    eq(#w.closed, 1)
    SlashCmdList["WVAURAS"]("count")
    eq(w.spoken[#w.spoken], "Player Buffs: 2. Player Debuffs: 1.")
    SlashCmdList["WVAURAS"]("say")
    contains(w.spoken[#w.spoken], "Player Buffs: 2. Power Word: Fortitude")
    SlashCmdList["WVAURAS"]("help")
    eq(w.spoken[#w.spoken], "Use /wvauras to open the list, /wvauras say to hear them all, /wvauras count for the numbers.")
end)

test("command: the words in French and German, capitals and spaces do not matter", function()
    local w = usual({ locale = "frFR" })
    local command = SlashCmdList["WVAURAS"]
    for _, word in ipairs({ "dire", "DIRE", "  dire", "tout", "all", "alle", "sagen" }) do
        local before = #w.spoken
        command(word)
        eq(#w.spoken, before + 1, word)
        contains(w.spoken[#w.spoken], "Améliorations du joueur : 2.", word)
    end
    for _, word in ipairs({ "nombre", "anzahl", "count", "numbers" }) do
        local before = #w.spoken
        command(word)
        eq(#w.spoken, before + 1, word)
        eq(w.spoken[#w.spoken], "Améliorations du joueur : 2. Affaiblissements du joueur : 1.", word)
    end
    for _, word in ipairs({ "aide", "hilfe", "help" }) do
        local before = #w.spoken
        command(word)
        eq(#w.spoken, before + 1, word)
        eq(w.spoken[#w.spoken], "Utilisez /wvauras pour ouvrir la liste, /wvauras dire pour tout entendre, /wvauras nombre pour les nombres.", word)
    end
    eq(#w.opened, 0, "none of those opened the list")
    w.ns.useLocale("deDE")
    command("hilfe")
    contains(w.spoken[#w.spoken], "Mit /wvauras öffnen Sie die Liste")
    command(nil)
    eq(#w.opened, 1, "no word: the list")
end)

test("command: a command that fails is reported once", function()
    local w = usual()
    w.ns.Auras.read = function()
        error("command broke")
    end
    SlashCmdList["WVAURAS"]("say")
    SlashCmdList["WVAURAS"]("say")
    eq(#w.errors, 1)
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
