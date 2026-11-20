-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- AtlasLoot's REAL ItemDB (ItemDB/ItemDB.lua) holds a small loot module written for these tests, and WowVision's REAL
-- graph framework (Builder, KeyGraph, node factories) builds and walks the screens; the game is mocked. They need
-- AtlasLootClassic or AtlasLootContinued and WowVision next to this addon (../AtlasLootClassic, ../WowVision), or
-- ATLASLOOT_DIR / WOWVISION_DIR pointing to the folders that hold them.
local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local root = os.getenv("ATLASLOOT_DIR") or (addonDir .. "/..")
local wowVision = os.getenv("WOWVISION_DIR") or (addonDir .. "/../WowVision")

local stub = dofile(testsDir .. "/atlas_stub.lua")(root)
local graphEnv = dofile(testsDir .. "/graph_env.lua")

local itemDbPath
for _, name in ipairs({ "AtlasLootClassic", "AtlasLootContinued" }) do
    if stub.exists(root .. "/" .. name .. "/ItemDB/ItemDB.lua") then
        itemDbPath = root .. "/" .. name .. "/ItemDB/ItemDB.lua"
        break
    end
end
assert(itemDbPath, "no AtlasLoot ItemDB found (set ATLASLOOT_DIR)")

-- ----------------------------------------------------------------- harness

local passed, failed = 0, 0

local function test(name, fn)
    -- a test that never ends (AtlasLoot's lookup of a boss with no table does not return) fails instead of hanging
    debug.sethook(function()
        error("took too long (an endless loop?)", 2)
    end, "", 100000000)
    local ok, err = pcall(fn)
    debug.sethook()
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

-- ------------------------------------------------------------------- world

local WORDS = {
    INVTYPE_2HWEAPON = "Two-Hand",
    INVTYPE_CLOAK = "Back",
    INVTYPE_HAND = "Hands",
    INVTYPE_HEAD = "Head",
    INVTYPE_FINGER = "Finger",
}
local QUALITIES = { [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }

-- The items of the test module: what the game says of each.
local function infoTable()
    return {
        [5187] = { name = "Rhahk'Zor's Hammer", quality = 3, level = 19, minLevel = 15, type = "Weapon", subType = "Two-Handed Maces", equipLoc = "INVTYPE_2HWEAPON", classID = 2, subClassID = 5, cached = true },
        [5201] = { name = "Emberstone Cloak", quality = 2, level = 20, minLevel = 16, type = "Armor", subType = "Cloth", equipLoc = "INVTYPE_CLOAK", classID = 4, subClassID = 1, cached = true },
        [5202] = { name = "Plate Gauntlets", quality = 2, level = 18, minLevel = 30, type = "Armor", subType = "Plate", equipLoc = "INVTYPE_HAND", classID = 4, subClassID = 4, cached = true },
        [5203] = { name = "Cloth Gloves", quality = 2, level = 17, minLevel = 12, type = "Armor", subType = "Cloth", equipLoc = "INVTYPE_HAND", classID = 4, subClassID = 1, cached = true },
        [5301] = { name = "Horde Helm", quality = 3, level = 21, minLevel = 18, type = "Armor", subType = "Mail", equipLoc = "INVTYPE_HEAD", classID = 4, subClassID = 3, cached = true },
        [5302] = { name = "Alliance Helm", quality = 3, level = 21, minLevel = 18, type = "Armor", subType = "Mail", equipLoc = "INVTYPE_HEAD", classID = 4, subClassID = 3, cached = true },
        [6001] = { name = "Set Ring", quality = 4, level = 30, minLevel = 25, type = "Armor", subType = "Miscellaneous", equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0, cached = true },
        [6002] = { name = "Set Helm", quality = 4, level = 30, minLevel = 25, type = "Armor", subType = "Plate", equipLoc = "INVTYPE_HEAD", classID = 4, subClassID = 4, cached = true },
        [7001] = { name = "Raid Blade", quality = 4, level = 60, minLevel = 55, type = "Weapon", subType = "Swords", equipLoc = "INVTYPE_2HWEAPON", classID = 2, subClassID = 8, cached = true },
        [8001] = { name = "Heroic Sash", quality = 3, level = 25, minLevel = 20, type = "Armor", subType = "Cloth", equipLoc = "INVTYPE_CLOAK", classID = 4, subClassID = 1, cached = true },
    }
end

-- A fresh world: AtlasLoot's real ItemDB with the test module, the game mocked, WowVision's real graph, the addon's files.
-- config: noAtlas, noModuleList, player = { class, level, faction }, forever (a version 4 module), info (replaces the
-- item facts), unusable = { [id] = true }, locale
local function newWorld(config)
    config = config or {}
    local w = {
        spoken = {},
        errors = {},
        loads = {},
        tooltips = 0,
        opened = nil,
        isOpen = false,
        unusable = config.unusable or { [5202] = true },
        info = config.info or infoTable(),
        player = config.player or { class = "PRIEST", level = 20, faction = "Alliance" },
        settings = {},
    }
    local env = graphEnv(wowVision)
    w.env = env
    geterrorhandler = function()
        return function(err)
            w.errors[#w.errors + 1] = tostring(err)
        end
    end
    GetLocale = function()
        return config.locale or "enUS"
    end
    SlashCmdList = {}
    InCombatLockdown = function()
        return false
    end

    -- AtlasLoot: the real ItemDB and a module of our own
    AtlasLoot = stub.newAtlas(1, config.forever and 4 or nil)
    local atlas = AtlasLoot
    w.atlas = atlas
    stub.read(itemDbPath)("AtlasLootClassic", {})
    local late = {}
    atlas.Loader.GetLootModuleList = function()
        if config.noModuleList then
            return { module = {}, custom = {} }
        end
        return {
            module = {
                { addonName = "TestLoot", name = "|TInterface\\Icons\\X:0|t Test |cff00ff00Loot|r" },
                { addonName = "TestLate", name = "Late loot" },
                { addonName = "TestCombat", name = "Combat loot" },
                { addonName = "TestOff", name = "Off loot" },
                { addonName = "TestGone", name = "Gone loot" },
            },
            custom = { { addonName = "TestBiS", name = "Best in slot" } },
        }
    end
    atlas.Loader.LoadModule = function(_, id)
        w.loads[#w.loads + 1] = id
        if id == "TestCombat" then
            return "InCombat"
        elseif id == "TestOff" then
            return "DISABLED"
        elseif id == "TestLate" and late.define then
            late.define()
        end
        return nil
    end
    atlas.Loader.IsModuleLoaded = function()
        return nil
    end

    local data = atlas.ItemDB:Add("TestLoot", 1, 1)
    local NORMAL = data:AddDifficulty("NORMAL", nil, nil, nil, true)
    local HEROIC = data:AddDifficulty("HEROIC")
    local DUNGEON = data:AddContentType("Dungeons", { 0, 0, 1, 1 })
    local RAID = data:AddContentType("Raids", { 1, 0, 0, 1 })
    local ITEM = data:AddItemTableType("Item", "Item")
    local SET = data:AddItemTableType("Set", "Item")
    w.NORMAL, w.HEROIC = NORMAL, HEROIC
    data["Deadmines"] = {
        name = "The Deadmines|r",
        ContentType = DUNGEON,
        LoadDifficulty = NORMAL,
        LevelRange = { 10, 15, 20 },
        items = {
            {
                name = "Rhahk'Zor",
                npcID = 644,
                [NORMAL] = {
                    { 1, 5187 },
                    { 2, 5201 },
                    { 3, 5202 },
                    { 16, "INV_Box_01", nil, "Forever" },
                    { 17, 5202, 5203 },
                    { 18, 5301, [901] = 5301, [902] = 5302 },
                    { 19, 5301, [902] = false },
                    { 20, "i5203" },
                },
                [HEROIC] = {
                    diffName = "Heroic!",
                    { 1, 8001 },
                },
            },
            {
                name = "Sneed",
                npcID = 643,
                [NORMAL] = {
                    { 2, 5203 },
                    { 1, 5201 },
                },
            },
            {
                name = "Tier sets",
                ExtraList = true,
                TableType = SET,
                [NORMAL] = {
                    { 1, 55 },
                },
            },
            {
                name = "Empty boss",
            },
        },
    }
    data["Stratholme"] = {
        name = "Stratholme",
        ContentType = RAID,
        LoadDifficulty = NORMAL,
        items = {
            { name = "Baron", [NORMAL] = { { 1, 7001 } } },
        },
    }
    data["Lost"] = {
        name = "Lost place",
        ContentType = 0,
        gameVersion = 0,
        items = { { name = "Hidden", [NORMAL] = { { 1, 5203 } } } },
    }
    if config.forever then
        local f = atlas.ItemDB:Add("TestLoot", 1, 4)
        f["ForeverMine"] = { name = "Forever mine", ContentType = DUNGEON, LoadDifficulty = NORMAL, items = { { name = "Forever boss", [NORMAL] = { { 1, 5203 } } } } }
    end
    -- a module that is only there once it is asked for
    late.define = function()
        local late_ = atlas.ItemDB:Add("TestLate", 1, 1)
        local n = late_:AddDifficulty("NORMAL", nil, nil, nil, true)
        local d = late_:AddContentType("Dungeons", { 0, 0, 1, 1 })
        late_:AddItemTableType("Item", "Item")
        late_["LateKeep"] = { name = "Late keep", ContentType = d, LoadDifficulty = n, items = { { name = "Late boss", [n] = { { 1, 5203 } } } } }
    end
    w.atlasData = data

    -- the game as the addon asks it
    local ns = {}
    w.ns = ns
    local function loadAddon(name)
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_AtlasLoot", ns)
    end
    loadAddon("Locale")
    if config.locale then
        ns.useLocale(config.locale)
    end
    loadAddon("Game")
    local Game = ns.Game
    Game.speak = function(text)
        w.spoken[#w.spoken + 1] = text
    end
    Game.itemInfo = function(id)
        return w.info[id] or { id = id, cached = false }
    end
    Game.requestItem = function(id)
        w.requested = w.requested or {}
        w.requested[id] = (w.requested[id] or 0) + 1
    end
    Game.canUse = function(id)
        w.canUseCalls = (w.canUseCalls or 0) + 1
        return not w.unusable[id]
    end
    Game.playerClass = function()
        return w.player.class
    end
    Game.playerLevel = function()
        return w.player.level
    end
    Game.faction = function()
        return w.player.faction
    end
    Game.className = function(token)
        return ({ WARRIOR = "Warrior", PRIEST = "Priest" })[token]
    end
    Game.slotName = function(loc)
        return WORDS[loc]
    end
    Game.qualityName = function(q)
        return QUALITIES[q]
    end
    Game.droprate = function(npcID, id)
        if npcID == 644 and id == 5187 then
            return 12.5
        end
        return nil
    end
    Game.setName = function(id)
        return id == 55 and "Test Set" or nil
    end
    Game.setItems = function(id)
        return id == 55 and { 6001, "item:6002:0:0" } or nil
    end
    Game.getSetting = function(key)
        local value = w.settings[key]
        if value == nil then
            return Game.defaults[key]
        end
        return value
    end
    Game.setSetting = function(key, value)
        w.settings[key] = value
    end
    Game.speakTooltip = function()
        w.tooltips = w.tooltips + 1
        return not w.noTooltip
    end
    -- what the player wears, by equip location: { { id, level } | { empty = true } }; a location not listed is not gear
    w.worn = {}
    w.gear = 0
    w.wornCalls = 0
    Game.gearVersion = function()
        return w.gear
    end
    Game.gearChanged = function()
        w.gear = w.gear + 1
    end
    Game.wornSlots = function(loc)
        w.wornCalls = w.wornCalls + 1
        return w.worn[loc]
    end
    Game.itemLevelOf = function(ref)
        local known = type(ref) == "number" and w.info[ref] or nil
        return known and known.level or nil
    end
    -- the names the game has (none of them asked for), and the items it says it does not know (w.failedItems)
    Game.itemName = function(id)
        local known = w.info[id]
        return known ~= nil and known.name or nil
    end
    Game.itemFailed = function(id)
        return w.failedItems ~= nil and w.failedItems[id] == true
    end
    -- Pawn: w.pawn = function(link) -> nil | false | { percent } | { big = true }; absent unless a test puts it there
    w.pawnCalls = 0
    Game.pawnReady = function()
        return w.pawn ~= nil
    end
    Game.pawnUpgrade = function(link)
        w.pawnCalls = w.pawnCalls + 1
        return w.pawn(link)
    end
    -- the Gear Judge: w.judge = function(link) -> a result table | nil, reason; absent unless a test puts it there
    w.judgeCalls = 0
    Game.judgeReady = function()
        return w.judge ~= nil
    end
    Game.judgeScore = function(link)
        w.judgeCalls = w.judgeCalls + 1
        return w.judge(link)
    end
    Game.locale = function()
        return config.locale or "enUS"
    end
    Game.isOpen = function()
        return w.isOpen
    end
    Game.open = function(screen)
        w.isOpen = true
        w.opened = screen
        return true
    end
    Game.close = function()
        w.isOpen = false
    end
    if config.noAtlas then
        AtlasLoot = nil
    end
    loadAddon("Loot")
    loadAddon("Screen")
    return w
end

-- A world with the screen on a real graph driver.
local function screenWorld(config)
    local w = newWorld(config)
    local ns = w.ns
    local d = w.env.driver(function(builder, screen)
        ns.Screen.render(builder, screen)
    end)
    d.screen.keyGraph = d.kg
    w.d = d
    return w
end

local function readings(d)
    return table.concat(d.dump(), " | ")
end

local function enter(w, text)
    local node = w.d.focus(text)
    check(node ~= nil, "no line starting with '" .. text .. "' in: " .. readings(w.d))
    w.d.enter()
end

-- ------------------------------------------------------------------- Loot

test("clean takes textures, colors and breaks out of a name", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    eq(Loot.clean("|TInterface\\Icons\\X:0|t Test |cff00ff00Loot|r"), "Test Loot")
    eq(Loot.clean("Line|nbreak   here"), "Line break here")
    eq(Loot.clean("|A:atlas:0:0|a Name"), "Name")
    eq(Loot.clean(nil), "")
    eq(Loot.clean(12), "")
end)

test("modules lists the loot modules then the custom ones, with clean names", function()
    local w = newWorld()
    local list = w.ns.Loot.modules(w.atlas)
    eq(#list, 6)
    eq(list[1].id, "TestLoot")
    eq(list[1].name, "Test Loot")
    eq(list[6].id, "TestBiS")
    eq(list[6].name, "Best in slot")
end)

test("modules is empty when AtlasLoot has no module list function", function()
    local w = newWorld()
    w.atlas.Loader.GetLootModuleList = nil
    eq(#w.ns.Loot.modules(w.atlas), 0)
    w.atlas.Loader.GetLootModuleList = function()
        error("boom")
    end
    eq(#w.ns.Loot.modules(w.atlas), 0)
end)

test("open: ready when the tables are there", function()
    local w = newWorld()
    local status, data = w.ns.Loot.open(w.atlas, "TestLoot")
    eq(status, "ready")
    check(data ~= nil)
    eq(#w.loads, 0, "nothing needed loading")
end)

test("open: loads a module on demand, and says why it cannot", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    eq((Loot.open(w.atlas, "TestLate")), "ready")
    eq(w.loads[1], "TestLate")
    eq((Loot.open(w.atlas, "TestCombat")), "combat")
    eq((Loot.open(w.atlas, "TestOff")), "disabled")
    eq((Loot.open(w.atlas, "TestGone")), "missing")
    w.atlas.Loader.LoadModule = function()
        error("boom")
    end
    eq((Loot.open(w.atlas, "TestElse")), "missing")
end)

test("versions, the version shown and its name", function()
    local w = newWorld({ forever = true })
    local Loot = w.ns.Loot
    local data = w.atlas.ItemDB:Get("TestLoot")
    local versions = Loot.versions(data)
    eq(table.concat(versions, ","), "1,4")
    eq(Loot.version(w.atlas, data, 4), 4)
    eq(Loot.version(w.atlas, data, 9), 1, "AtlasLoot's window is on version 1")
    w.atlas.db.GUI.selectedGameVersion = 4
    eq(Loot.version(w.atlas, data, nil), 4)
    eq(Loot.versionName(w.atlas, 1), "Classic")
    eq(Loot.versionName(w.atlas, 2), "The Burning Crusade")
    eq(Loot.versionName(w.atlas, 3), "Wrath of the Lich King")
    eq(Loot.versionName(w.atlas, 4), "WoW: Forever")
    eq(Loot.versionName(w.atlas, 7), "7")
end)

test("the Forever name only applies when AtlasLoot has that version", function()
    local w = newWorld()
    eq(w.ns.Loot.versionName(w.atlas, 4), "4")
end)

test("instances: grouped as AtlasLoot groups them, the ones for every version last, with levels", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    local data = w.atlas.ItemDB:Get("TestLoot")
    local groups = Loot.instances(w.atlas, "TestLoot", data, 1)
    eq(#groups, 3)
    eq(groups[1].name, "Dungeons")
    eq(groups[1].list[1].key, "Deadmines")
    eq(groups[1].list[1].name, "The Deadmines")
    eq(groups[1].list[1].levels, "levels 15 to 20")
    eq(groups[2].name, "Raids")
    eq(groups[2].list[1].name, "Stratholme")
    eq(groups[2].list[1].levels, nil)
    eq(groups[3].name, "Other", "the group of an instance without a type comes last")
    eq(groups[3].list[1].key, "Lost")
end)

test("instances: an instance whose name AtlasLoot cannot work out is listed by its key", function()
    local w = newWorld()
    local data = w.atlas.ItemDB:Get("TestLoot")
    data["Deadmines"].name = nil
    data["Deadmines"].MapID = nil
    local groups = w.ns.Loot.instances(w.atlas, "TestLoot", data, 1)
    eq(groups[1].list[1].name, "Deadmines")
end)

test("instances: only the version asked for", function()
    local w = newWorld({ forever = true })
    local data = w.atlas.ItemDB:Get("TestLoot")
    local forever = w.ns.Loot.instances(w.atlas, "TestLoot", data, 4)
    local keys = {}
    for _, group in ipairs(forever) do
        for _, instance in ipairs(group.list) do
            keys[#keys + 1] = instance.key
        end
    end
    table.sort(keys)
    eq(table.concat(keys, ","), "ForeverMine,Lost", "Forever's own instance, and the one for every version")
end)

test("bosses: the bosses, then the other lists flagged", function()
    local w = newWorld()
    local data = w.atlas.ItemDB:Get("TestLoot")
    local bosses = w.ns.Loot.bosses(data, "Deadmines")
    eq(#bosses, 4)
    eq(bosses[1].name, "Rhahk'Zor")
    eq(bosses[1].npcID, 644)
    eq(bosses[1].extra, false)
    eq(bosses[3].name, "Tier sets")
    eq(bosses[3].extra, true)
    eq(#w.ns.Loot.bosses(data, "Nowhere"), 0)
end)

test("difficulties: the ones a boss has a table for, with AtlasLoot's name or the table's own", function()
    local w = newWorld()
    local data = w.atlas.ItemDB:Get("TestLoot")
    local diffs = w.ns.Loot.difficulties(data, "Deadmines", 1)
    eq(#diffs, 2)
    eq(diffs[1].name, "NORMAL")
    eq(diffs[2].name, "Heroic!")
    eq(#w.ns.Loot.difficulties(data, "Deadmines", 2), 1)
    eq(#w.ns.Loot.difficulties(data, "Deadmines", 4), 0, "a boss without a table")
    eq(#w.ns.Loot.difficulties(data, "Deadmines", 99), 0)
end)

test("pickDifficulty: the one asked for, else the nearest lower one, else the first", function()
    local w = newWorld()
    local pick = w.ns.Loot.pickDifficulty
    local diffs = { { id = 1 }, { id = 3 }, { id = 5 } }
    eq(pick(diffs, 3), 3)
    eq(pick(diffs, 4), 3)
    eq(pick(diffs, 99), 5)
    eq(pick(diffs, 0), 1)
    eq(pick(diffs, nil), 1)
    eq(pick({}, 2), nil)
end)

test("entries: items in AtlasLoot's order, a header, the faction's item, the second item, a string reference", function()
    local w = newWorld()
    local data = w.atlas.ItemDB:Get("TestLoot")
    local entries = w.ns.Loot.table(w.atlas, "TestLoot", "Deadmines", 1, 1, w.ns.Game, 644)
    local ids = {}
    for _, entry in ipairs(entries) do
        ids[#ids + 1] = entry.kind == "header" and ("[" .. entry.name .. "]") or tostring(entry.id)
    end
    -- 1:5187 2:5201 3:5202 | Forever 17: 5202 5203 | 18: Alliance 5302 | 19 hidden from the Alliance | 20: i5203
    eq(table.concat(ids, " "), "5187 5201 5202 [Forever] 5202 5203 5302 5203")
    eq(entries[1].npcID, 644)
    check(data ~= nil)
end)

test("entries: a Horde player gets the Horde item, and the entry hidden from the Alliance", function()
    local w = newWorld({ player = { class = "WARRIOR", level = 20, faction = "Horde" } })
    local entries = w.ns.Loot.table(w.atlas, "TestLoot", "Deadmines", 1, 1, w.ns.Game, 644)
    local ids = {}
    for _, entry in ipairs(entries) do
        if entry.kind == "item" then
            ids[#ids + 1] = entry.id
        end
    end
    eq(table.concat(ids, " "), "5187 5201 5202 5202 5203 5301 5301 5203")
end)

test("entries: a table sorted by the positions, not by how it is written", function()
    local w = newWorld()
    local entries = w.ns.Loot.table(w.atlas, "TestLoot", "Deadmines", 2, 1, w.ns.Game, 643)
    eq(entries[1].id, 5201)
    eq(entries[2].id, 5203)
end)

test("entries: a list of sets becomes the set's name and its items", function()
    local w = newWorld()
    local entries = w.ns.Loot.table(w.atlas, "TestLoot", "Deadmines", 3, 1, w.ns.Game, nil)
    eq(#entries, 3)
    eq(entries[1].kind, "header")
    eq(entries[1].name, "Test Set")
    eq(entries[2].id, 6001)
    eq(entries[3].id, 6002, "an item given as 'item:6002:...' is read")
end)

test("entries: the class header of a table is named after the class", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    local entries = Loot.entries({ { 1, "CLASS_WARRIOR" }, { 2, 5187 } }, { "Item" }, w.ns.Game)
    eq(entries[1].name, "Warrior")
    eq(entries[2].id, 5187)
    eq(#Loot.entries({ { 1, "ICON_X" }, { 2, 5187 } }, { "Item" }, w.ns.Game), 1, "a header without a name says nothing")
end)

test("entries: what is not an item is left out, and an entry AtlasLoot ignores", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    local game = w.ns.Game
    eq(#Loot.entries({ { 1, "s12345" }, { 2, "f529" }, { 3, 0 }, { 4 }, { "x", 5187 }, { 5, 5187, [999] = true } }, { "Item" }, game), 0)
    eq(#Loot.entries({ { 1, 5187 } }, { "Profession" }, game), 0, "a table of another kind")
    eq(#Loot.entries({ { 1, 5187 }, "junk" }, nil, game), 1, "no table type means items")
end)

test("entries: a note comes along, an empty one does not", function()
    local w = newWorld()
    local entries = w.ns.Loot.entries({ { 1, 5187, nil, nil, "From a |cffff0000chest|r" }, { 2, 5201, nil, nil, "" } }, { "Item" }, w.ns.Game)
    eq(entries[1].note, "From a chest")
    eq(entries[2].note, nil)
end)

test("table: no difficulty means no table, and AtlasLoot is not asked", function()
    local w = newWorld()
    w.atlas.ItemDB.GetItemTable = function()
        error("must not be asked")
    end
    eq(#w.ns.Loot.table(w.atlas, "TestLoot", "Deadmines", 4, nil, w.ns.Game), 0)
end)

test("table: a table that lives in a module not loaded yet is 'loading', and the module is asked for", function()
    local w = newWorld()
    w.atlas.ItemDB.GetItemTable = function()
        return "TestLate"
    end
    local entries, problem = w.ns.Loot.table(w.atlas, "TestLoot", "Deadmines", 1, 1, w.ns.Game)
    eq(entries, nil)
    eq(problem, "loading")
    eq(w.loads[#w.loads], "TestLate")
end)

test("table: an AtlasLoot error is returned, not thrown", function()
    local w = newWorld()
    w.atlas.ItemDB.GetItemTable = function()
        error("bad table")
    end
    local entries, problem, message = w.ns.Loot.table(w.atlas, "TestLoot", "Deadmines", 1, 1, w.ns.Game)
    eq(entries, nil)
    eq(problem, "error")
    contains(message, "bad table")
end)

test("visible: the class filter hides what the class cannot use, and a header with nothing under it", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    local entries = Loot.table(w.atlas, "TestLoot", "Deadmines", 1, 1, w.ns.Game, 644)
    local shown, hidden = Loot.visible(entries, { classFilter = true }, w.ns.Game)
    eq(hidden, 2, "5202 twice")
    local ids = {}
    for _, entry in ipairs(shown) do
        ids[#ids + 1] = entry.kind == "header" and "[h]" or tostring(entry.id)
    end
    eq(table.concat(ids, " "), "5187 5201 [h] 5203 5302 5203")
    local all, none = Loot.visible(entries, { classFilter = false }, w.ns.Game)
    eq(none, 0)
    eq(#all, #entries)
    local only = Loot.visible({ { kind = "header", name = "x" }, { kind = "item", id = 5202, pos = 1 } }, { classFilter = true }, w.ns.Game)
    eq(#only, 0, "a header without an item is not shown")
end)

test("visible: the level filter hides what asks for a higher level", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    local entries = Loot.table(w.atlas, "TestLoot", "Deadmines", 1, 1, w.ns.Game, 644)
    local shown, hidden = Loot.visible(entries, { levelFilter = true }, w.ns.Game)
    -- level 20: 5202 asks for 30 (twice); the 7 items are 5187 5201 5202 5202 5203 5302 5203
    eq(hidden, 2)
    eq(Loot.count(shown), 5)
    w.player.level = 10
    local _, hiddenLow = Loot.visible(entries, { levelFilter = true }, w.ns.Game)
    eq(hiddenLow, 7, "at level 10 the game asks for 12 or more everywhere")
end)

test("visible: an item whose level the game has not said yet is kept", function()
    local w = newWorld()
    w.info = { [5187] = { cached = false } }
    local shown, hidden = w.ns.Loot.visible({ { kind = "item", id = 5187, pos = 1 } }, { levelFilter = true }, w.ns.Game)
    eq(#shown, 1)
    eq(hidden, 0)
end)

test("visible: both filters together", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    local entries = { { kind = "item", id = 5202, pos = 1 }, { kind = "item", id = 5301, pos = 2 }, { kind = "item", id = 8001, pos = 3 } }
    local shown, hidden = Loot.visible(entries, { classFilter = true, levelFilter = true }, w.ns.Game)
    eq(#shown, 2)
    eq(hidden, 1)
    w.player.level = 19
    shown, hidden = Loot.visible(entries, { classFilter = true, levelFilter = true }, w.ns.Game)
    eq(#shown, 1, "8001 asks for 20")
    eq(hidden, 2)
end)

test("visible: what the class can use is asked once the game has the item, not again", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    local entries = { { kind = "item", id = 5203, pos = 1 } }
    Loot.visible(entries, { classFilter = true }, w.ns.Game)
    Loot.visible(entries, { classFilter = true }, w.ns.Game)
    Loot.visible(entries, { classFilter = true }, w.ns.Game)
    eq(w.canUseCalls, 1)
end)

test("visible: while the game has not the item, the answer is asked again each time", function()
    local w = newWorld()
    w.info = {}
    local entries = { { kind = "item", id = 5203, pos = 1 } }
    w.ns.Loot.visible(entries, { classFilter = true }, w.ns.Game)
    w.ns.Loot.visible(entries, { classFilter = true }, w.ns.Game)
    eq(w.canUseCalls, 2)
end)

test("count counts items, not headers", function()
    local w = newWorld()
    eq(w.ns.Loot.count({ { kind = "header" }, { kind = "item" }, { kind = "item" } }), 2)
    eq(w.ns.Loot.count({}), 0)
end)

test("describe: name, quality, slot and type, item level, level asked, drop chance", function()
    local w = newWorld()
    local text = w.ns.Loot.describe({ id = 5187, npcID = 644 }, { classFilter = true }, w.ns.Game)
    eq(text, "Rhahk'Zor's Hammer, Rare, Two-Hand, Two-Handed Maces, item level 19, requires level 15, 12.5 percent drop chance")
end)

test("describe: a level above the player's is said", function()
    local w = newWorld()
    local text = w.ns.Loot.describe({ id = 5202 }, { classFilter = true }, w.ns.Game)
    contains(text, "requires level 30, above your level")
end)

test("describe: a note, and a class that cannot use it only when the filter is off", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    local entry = { id = 5202, note = "Quest reward", usable = false }
    contains(Loot.describe(entry, { classFilter = false }, w.ns.Game), "your class cannot use it")
    contains(Loot.describe(entry, { classFilter = false }, w.ns.Game), "Quest reward")
    eq(Loot.describe(entry, { classFilter = true }, w.ns.Game):find("cannot", 1, true), nil)
end)

test("describe: an item the game has not sent yet is said as loading", function()
    local w = newWorld()
    eq(w.ns.Loot.describe({ id = 99999 }, {}, w.ns.Game), "Item 99999, loading")
end)

test("describe: an item without a slot says its type, and no item level", function()
    local w = newWorld()
    w.info[4000] = { name = "Recipe: Soup", quality = 1, level = 5, minLevel = 1, type = "Recipe", subType = "Cooking", equipLoc = "", cached = true }
    eq(w.ns.Loot.describe({ id = 4000 }, {}, w.ns.Game), "Recipe: Soup, Cooking")
    w.info[4001] = { name = "Thing", type = "Miscellaneous", subType = "", equipLoc = "", cached = true }
    eq(w.ns.Loot.describe({ id = 4001 }, {}, w.ns.Game), "Thing, Miscellaneous")
end)

test("describe: a slot that is also the sub type is said once", function()
    local w = newWorld()
    w.info[4002] = { name = "Cloak", quality = 2, level = 10, minLevel = 5, subType = "Back", equipLoc = "INVTYPE_CLOAK", cached = true }
    eq(w.ns.Loot.describe({ id = 4002 }, {}, w.ns.Game), "Cloak, Uncommon, Back, item level 10, requires level 5")
end)

-- ------------------------------------------------------------------ Screen

test("the screen without AtlasLoot says so", function()
    local w = screenWorld({ noAtlas = true })
    contains(readings(w.d), "AtlasLoot is not installed or not enabled.")
end)

test("the first level lists the categories", function()
    local w = screenWorld()
    local text = readings(w.d)
    contains(text, "Test Loot")
    contains(text, "Best in slot")
    contains(text, "Late loot")
    contains(text, "Close")
    eq(text:find("Back", 1, true), nil, "no way back from the top")
end)

test("without any module the screen says so", function()
    local w = screenWorld({ noModuleList = true })
    contains(readings(w.d), "No AtlasLoot module is enabled.")
end)

test("Enter on a category lists its dungeons by group, and stands on the first", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    local text = readings(w.d)
    contains(text, "The Deadmines, levels 15 to 20")
    contains(text, "Stratholme")
    contains(text, "Lost place")
    eq(w.ns.Screen.state.level, "instances")
    contains(w.d.say(), "The Deadmines")
    contains(readings(w.d), "Back")
end)

test("a module that loads on demand opens, one that cannot says why", function()
    local w = screenWorld()
    enter(w, "Late loot")
    contains(readings(w.d), "Late keep")
    w.d.focus("Back")
    w.d.enter()
    enter(w, "Combat loot")
    eq(w.ns.Screen.state.level, "modules")
    eq(w.spoken[#w.spoken], "That module loads after combat.")
    enter(w, "Off loot")
    eq(w.spoken[#w.spoken], "That AtlasLoot module is disabled.")
    enter(w, "Gone loot")
    eq(w.spoken[#w.spoken], "That AtlasLoot module is not installed.")
end)

test("Enter on a dungeon lists its bosses and its other lists", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    local text = readings(w.d)
    contains(text, "Rhahk'Zor")
    contains(text, "Sneed")
    contains(text, "Tier sets")
    contains(text, "Empty boss")
    eq(w.ns.Screen.state.level, "bosses")
    contains(w.d.say(), "Rhahk'Zor")
end)

test("Enter on a boss lists its loot, grouped under the headers, filtered by the class", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    local text = readings(w.d)
    contains(text, "Rhahk'Zor's Hammer, Rare, Two-Hand")
    contains(text, "Emberstone Cloak")
    eq(text:find("Plate Gauntlets", 1, true), nil, "the priest cannot use the plate")
    contains(text, "Alliance Helm")
    eq(text:find("Horde Helm", 1, true), nil)
    contains(text, "Items shown: 5, Hidden by the filters: 2")
    eq(w.ns.Screen.state.level, "items")
    local model = w.ns.Screen.model(w.atlas)
    eq(model.rows[3].group.label, "Forever", "the header of the right column holds what follows it")
    eq(model.rows[1].group, nil, "the first items have no header")
    contains(w.d.say(), "Rhahk'Zor's Hammer")
end)

test("the loot of a boss is asked of the game once, and kept", function()
    local w = screenWorld()
    local calls = 0
    local original = w.atlas.ItemDB.GetItemTable
    w.atlas.ItemDB.GetItemTable = function(...)
        calls = calls + 1
        return original(...)
    end
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    readings(w.d)
    readings(w.d)
    w.d.dump()
    eq(calls, 1)
    check(w.requested[5187] >= 1, "the items were asked of the game")
end)

test("an item carries its tooltip and Enter on it reads the tooltip", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    local found
    for _, node in ipairs(w.d.nodes()) do
        if node.vtable.tooltip ~= nil and node.vtable.tooltip.link == "item:5187" then
            found = node
        end
    end
    check(found ~= nil, "the hammer has a tooltip")
    eq(found.vtable.tooltip.type, "Hyperlink")
    w.d.kg:focus(found.id)
    w.d.enter()
    eq(w.tooltips, 1)
end)

test("Enter on an item reads its line when there is no tooltip to read", function()
    local w = screenWorld()
    w.noTooltip = true
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    w.d.focus("Rhahk'Zor's Hammer")
    w.d.enter()
    contains(w.spoken[#w.spoken], "Rhahk'Zor's Hammer, Rare")
end)

test("the filters stop: the class and level toggles change the list at once", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    w.d.focus("Only what my class can use")
    w.d.enter()
    eq(w.settings.classFilter, false)
    local text = readings(w.d)
    contains(text, "Plate Gauntlets")
    contains(text, "your class cannot use it")
    contains(text, "Items shown: 7")
    eq(text:find("Hidden by the filters", 1, true), nil)
    w.d.focus("Only what my level allows")
    w.d.enter()
    eq(w.settings.levelFilter, true)
    text = readings(w.d)
    eq(text:find("Plate Gauntlets", 1, true), nil, "level 30 is out at level 20")
    contains(text, "Hidden by the filters: 2")
end)

test("the class filter is on and the level filter off until the player says", function()
    local w = screenWorld()
    eq(w.ns.Game.getSetting("classFilter"), true)
    eq(w.ns.Game.getSetting("levelFilter"), false)
    eq(w.ns.Game.getSetting("openWithAl"), true)
end)

test("the difficulty button cycles the boss' difficulties and the list follows", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    contains(readings(w.d), "Difficulty: NORMAL")
    w.d.focus("Difficulty:")
    w.d.enter()
    local text = readings(w.d)
    contains(text, "Difficulty: Heroic!")
    contains(text, "Heroic Sash")
    eq(text:find("Emberstone Cloak", 1, true), nil)
    eq(w.ns.Screen.model(w.atlas).title, "Rhahk'Zor, Heroic!", "the title of the list names the difficulty")
    w.d.focus("Difficulty:")
    w.d.enter()
    contains(readings(w.d), "Difficulty: NORMAL")
end)

test("a boss with one difficulty has no difficulty button", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Sneed")
    eq(readings(w.d):find("Difficulty:", 1, true), nil)
end)

test("a list of sets shows the set's name and its items", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Tier sets")
    local text = readings(w.d)
    contains(text, "Set Ring")
    contains(text, "Set Helm")
    eq(w.ns.Screen.model(w.atlas).rows[1].group.label, "Test Set", "the set's name holds its items")
end)

test("a boss without any table says there is nothing to show", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Empty boss")
    contains(readings(w.d), "No item to show.")
    contains(readings(w.d), "Items shown: 0")
end)

test("everything hidden by the filters says no item, and how many were hidden", function()
    local w = screenWorld({ unusable = { [5187] = true, [5201] = true, [5202] = true, [5203] = true, [5301] = true, [5302] = true } })
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    contains(readings(w.d), "No item to show.")
    contains(readings(w.d), "Hidden by the filters: 7")
end)

test("a loot table that fails is reported once and shows nothing", function()
    local w = screenWorld()
    w.atlas.ItemDB.GetItemTable = function()
        error("bad table")
    end
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    readings(w.d)
    readings(w.d)
    contains(readings(w.d), "No item to show.")
    eq(#w.errors, 1)
    contains(w.errors[1], "bad table")
end)

test("a loot table in a module not loaded yet says it is loading", function()
    local w = screenWorld()
    w.atlas.ItemDB.GetItemTable = function()
        return "TestLate"
    end
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    contains(readings(w.d), "Loading.")
    contains(readings(w.d), "Slot, Dropdown, All slots", "the filters are there, and the slot choice can be heard")
end)


test("Back goes up one level and stands on what the player came from", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "Stratholme")
    enter(w, "Baron")
    eq(w.ns.Screen.state.level, "items")
    w.d.focus("Back")
    w.d.enter()
    eq(w.ns.Screen.state.level, "bosses")
    contains(w.d.say(), "Baron")
    w.d.focus("Back")
    w.d.enter()
    eq(w.ns.Screen.state.level, "instances")
    contains(w.d.say(), "Stratholme")
    w.d.focus("Back")
    w.d.enter()
    eq(w.ns.Screen.state.level, "modules")
    contains(w.d.say(), "Test Loot")
end)

test("Escape goes up a level and, at the top, closes the screen", function()
    local w = screenWorld()
    w.isOpen = true
    local closed = 0
    w.ns.afterClose = function()
        closed = closed + 1
    end
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    local config = w.ns.Screen.config()
    config.onRequestClose()
    eq(w.ns.Screen.state.level, "instances")
    config.onRequestClose()
    eq(w.ns.Screen.state.level, "modules")
    eq(w.isOpen, true)
    config.onRequestClose()
    eq(w.isOpen, false)
    eq(closed, 1)
    eq(config.captureClose, true)
    eq(config.letterNavigation, true)
end)

test("the Close button closes", function()
    local w = screenWorld()
    w.isOpen = true
    w.d.focus("Close")
    w.d.enter()
    eq(w.isOpen, false)
end)

test("the navigation stop says where the player is", function()
    local w = screenWorld()
    check(readings(w.d):find("You are in: Loot categories", 1, true), readings(w.d))
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    contains(readings(w.d), "You are in: Test Loot, The Deadmines, Rhahk'Zor")
end)

test("a game with two versions has a version button that cycles them", function()
    local w = screenWorld({ forever = true })
    w.atlas.db.GUI.selectedGameVersion = 4
    enter(w, "Test Loot")
    local text = readings(w.d)
    contains(text, "Game version: WoW: Forever")
    contains(text, "Forever mine")
    eq(text:find("Stratholme", 1, true), nil)
    w.d.focus("Game version:")
    w.d.enter()
    text = readings(w.d)
    contains(text, "Game version: Classic")
    contains(text, "Stratholme")
    eq(text:find("Forever mine", 1, true), nil)
    contains(w.d.say(), "Game version")
end)

test("a game with one version has no version button", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    eq(readings(w.d):find("Game version", 1, true), nil)
end)

test("the screen stays where it was between two openings", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "Stratholme")
    local again = w.env.driver(function(builder, screen)
        w.ns.Screen.render(builder, screen)
    end)
    again.screen.keyGraph = again.kg
    contains(table.concat(again.dump(), " | "), "Baron")
end)

test("the navigation stop has a switch for opening with AtlasLoot's window", function()
    local w = screenWorld()
    contains(readings(w.d), "Open with AtlasLoot's window (/al), Checkbox, Checked")
    w.d.focus("Open with AtlasLoot's window")
    w.d.enter()
    eq(w.settings.openWithAl, false)
    contains(readings(w.d), "Open with AtlasLoot's window (/al), Checkbox, Unchecked")
end)

test("Screen.open opens the window once", function()
    local w = newWorld()
    eq(w.ns.Screen.open(), true)
    eq(w.opened.key, "atlasloot-browser")
    w.opened = nil
    eq(w.ns.Screen.open(), true)
    eq(w.opened, nil, "already open")
end)

test("Screen.open says so when WowVision has no windows", function()
    local w = newWorld()
    w.ns.Game.open = function()
        return false
    end
    eq(w.ns.Screen.open(), false)
    eq(w.spoken[#w.spoken], "WowVision's windows are not available.")
end)

test("French: the screen and the lines of an item speak French", function()
    local w = screenWorld({ locale = "frFR" })
    contains(readings(w.d), "Fermer")
    enter(w, "Test Loot")
    contains(readings(w.d), "niveaux 15 à 20")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    local text = readings(w.d)
    contains(text, "niveau d'objet 19, niveau 15 requis, 12.5 pour cent de chances de tomber")
    contains(text, "Objets affichés : 5, Masqués par les filtres : 2")
    contains(text, "Seulement ce que ma classe peut utiliser")
end)

test("German: the screen speaks German", function()
    local w = screenWorld({ locale = "deDE" })
    contains(readings(w.d), "Schließen")
    enter(w, "Test Loot")
    contains(readings(w.d), "Stufen 15 bis 20")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    contains(readings(w.d), "Gegenstandsstufe 19, benötigt Stufe 15, 12.5 Prozent Beutechance")
end)

test("every spoken string has a French and a German wording", function()
    local w = newWorld()
    local ns = w.ns
    local missing = {}
    local sources = {}
    for _, file in ipairs({ "Game", "Loot", "Screen", "Main" }) do
        local f = assert(io.open(addonDir .. "/" .. file .. ".lua", "rb"))
        sources[#sources + 1] = f:read("a")
        f:close()
    end
    local text = table.concat(sources, "\n")
    local keys = {}
    for key in text:gmatch('L%["(.-)"%]') do
        keys[key] = true
    end
    for key in text:gmatch('label = "([^"]+)"') do
        keys[key] = true
    end
    for key in text:gmatch('"(That [^"]*%.)"') do
        keys[key] = true
    end
    local count = 0
    for key in pairs(keys) do
        count = count + 1
        for _, locale in ipairs({ "frFR", "deDE" }) do
            if ns.translations[locale][key] == nil then
                missing[#missing + 1] = locale .. ": " .. key
            end
        end
    end
    check(count > 30, "the strings were read (" .. count .. ")")
    eq(#missing, 0, "untranslated: " .. table.concat(missing, "; "))
end)

test("every translation is used by the addon", function()
    local w = newWorld()
    local sources = {}
    for _, file in ipairs({ "Game", "Loot", "Screen", "Main" }) do
        local f = assert(io.open(addonDir .. "/" .. file .. ".lua", "rb"))
        sources[#sources + 1] = f:read("a")
        f:close()
    end
    local text = table.concat(sources, "\n")
    local unused = {}
    for key in pairs(w.ns.translations.frFR) do
        local escaped = key:gsub("\\", "\\\\")
        if not text:find(key, 1, true) and not text:find(escaped, 1, true) then
            unused[#unused + 1] = key
        end
    end
    eq(#unused, 0, "unused: " .. table.concat(unused, "; "))
    for key in pairs(w.ns.translations.frFR) do
        check(w.ns.translations.deDE[key] ~= nil, "no German for " .. key)
    end
    for key in pairs(w.ns.translations.deDE) do
        check(w.ns.translations.frFR[key] ~= nil, "no French for " .. key)
    end
end)

-- -------------------------------------------------------------------- Main

-- The world with Main.lua loaded on top, a fake AtlasLoot window and a fake WowVision input.
local function mainWorld(config)
    config = config or {}
    local w = newWorld(config)
    local ns = w.ns
    w.created = {}
    local bindings = {}
    WowVision = WowVision or {}
    WowVision.input = {
        getBinding = function(_, key)
            return bindings[key]
        end,
        createBinding = function(_, info)
            local binding = { info = info, activated = 0 }
            function binding:activate()
                self.activated = self.activated + 1
            end
            bindings[info.key] = binding
            w.created[#w.created + 1] = binding
            return binding
        end,
        getDefaultDB = function()
            return {}
        end,
    }
    WowVision.dbManager = {
        resolveBindings = function()
            return {}
        end,
    }
    WowVision.applyBindingStore = function()
        w.applied = (w.applied or 0) + 1
    end
    WowVisionDB, WowVision.globalDb = {}, {}
    w.bindings = bindings

    -- AtlasLoot's window
    local scripts = {}
    local frame = { shown = false }
    function frame:HookScript(kind, fn)
        scripts[kind] = scripts[kind] or {}
        table.insert(scripts[kind], fn)
    end
    function frame:IsShown()
        return self.shown
    end
    function frame:Show()
        self.shown = true
        for _, fn in ipairs(scripts.OnShow or {}) do
            fn()
        end
    end
    function frame:Hide()
        self.shown = false
        for _, fn in ipairs(scripts.OnHide or {}) do
            fn()
        end
    end
    w.frame = frame
    if not config.noFrame then
        ns.Game.atlasFrame = function()
            return frame
        end
    end
    local chunk, err = loadfile(addonDir .. "/Main.lua")
    if chunk == nil then
        error(err)
    end
    w.eventFrames = {}
    CreateFrame = function()
        local f = { events = {} }
        function f:RegisterEvent(e)
            self.events[e] = true
        end
        function f:SetScript(_, fn)
            self.onEvent = fn
        end
        w.eventFrames[#w.eventFrames + 1] = f
        return f
    end
    tinsert = table.insert
    chunk("WowVision_AtlasLoot", ns)
    return w
end

test("Main: the key is a binding on Alt+L, named in the player's language", function()
    local w = mainWorld({ locale = "frFR" })
    eq(w.ns.installed, true)
    local binding = w.bindings["atlasloot/open"]
    check(binding ~= nil)
    eq(binding.info.inputs[1], "ALT-L")
    eq(binding.info.label, "Ouvrir le navigateur de butin (AtlasLoot)")
    eq(binding.activated, 1)
    eq(w.applied, 1)
end)

test("Main: a binding that is already there is not made twice", function()
    local w = mainWorld()
    eq(#w.created, 1)
    w.ns.installBindings()
    eq(#w.created, 1)
end)

test("Main: without WowVision's input nothing is installed and nothing breaks", function()
    local w = mainWorld()
    WowVision.input = nil
    eq(w.ns.installBindings(), false)
end)

test("Main: the key opens the screen, and closes it", function()
    local w = mainWorld()
    w.bindings["atlasloot/open"].info.func()
    eq(w.isOpen, true)
    eq(w.opened.key, "atlasloot-browser")
    w.bindings["atlasloot/open"].info.func()
    eq(w.isOpen, false)
    eq(#w.errors, 0)
end)

test("Main: the key without AtlasLoot says so", function()
    local w = mainWorld({ noAtlas = true })
    w.bindings["atlasloot/open"].info.func()
    eq(w.isOpen, false)
    eq(w.spoken[#w.spoken], "AtlasLoot is not installed or not enabled.")
end)

test("Main: /wvloot, /wvbutin and /wvbeute do what the key does", function()
    local w = mainWorld()
    eq(SLASH_WVATLASLOOT1, "/wvloot")
    eq(SLASH_WVATLASLOOT2, "/wvbutin")
    eq(SLASH_WVATLASLOOT3, "/wvbeute")
    SlashCmdList["WVATLASLOOT"]("")
    eq(w.isOpen, true)
    SlashCmdList["WVATLASLOOT"]("")
    eq(w.isOpen, false)
end)

test("Main: /wvloot help tells what it is", function()
    local w = mainWorld()
    SlashCmdList["WVATLASLOOT"]("help")
    contains(w.spoken[#w.spoken], "/wvloot opens or closes the screen")
    eq(w.isOpen, false)
    SlashCmdList["WVATLASLOOT"]("  AIDE")
    contains(w.spoken[#w.spoken], "/wvloot")
end)

test("Main: AtlasLoot's window opening (/al) opens the screen, and closing the screen hides the window", function()
    local w = mainWorld()
    w.ns.hookAtlasFrame()
    w.frame:Show()
    eq(w.isOpen, true)
    eq(w.ns.openedByAl, true)
    w.ns.Screen.close()
    eq(w.isOpen, false)
    eq(w.frame.shown, false, "the window AtlasLoot opened is closed with the screen")
    eq(w.ns.openedByAl, false)
end)

test("Main: AtlasLoot's window closing closes the screen it opened", function()
    local w = mainWorld()
    w.ns.hookAtlasFrame()
    w.frame:Show()
    w.frame:Hide()
    eq(w.isOpen, false)
    eq(w.ns.openedByAl, false)
end)

test("Main: a screen opened by the key is not closed by AtlasLoot's window, nor does it hide it", function()
    local w = mainWorld()
    w.ns.hookAtlasFrame()
    w.bindings["atlasloot/open"].info.func()
    w.frame:Show()
    eq(w.isOpen, true)
    eq(w.ns.openedByAl, false)
    w.frame:Hide()
    eq(w.isOpen, true, "the screen stays")
    w.ns.Screen.close()
    eq(w.isOpen, false)
end)

test("Main: with the option off, AtlasLoot's window does not open the screen", function()
    local w = mainWorld()
    w.settings.openWithAl = false
    w.ns.hookAtlasFrame()
    w.frame:Show()
    eq(w.isOpen, false)
end)

test("Main: the window is hooked once, and only when AtlasLoot has built it", function()
    local w = mainWorld({ noFrame = true })
    eq(w.ns.hookAtlasFrame(), false)
    w.ns.Game.atlasFrame = function()
        return w.frame
    end
    eq(w.ns.hookAtlasFrame(), true)
    eq(w.ns.hookAtlasFrame(), false)
    w.frame:Show()
    eq(w.isOpen, true)
end)

test("Main: the key tries to hook the window too (AtlasLoot builds it late)", function()
    local w = mainWorld({ noFrame = true })
    w.ns.Game.atlasFrame = function()
        return w.frame
    end
    w.bindings["atlasloot/open"].info.func()
    eq(w.ns.frameHooked, true)
end)

test("Main: the game's events try to hook the window, and an error there is reported once", function()
    local w = mainWorld()
    local events = w.eventFrames[#w.eventFrames]
    check(events.events.PLAYER_LOGIN and events.events.PLAYER_ENTERING_WORLD and events.events.ADDON_LOADED)
    events.onEvent()
    eq(w.ns.frameHooked, true)
    w.ns.hookAtlasFrame = function()
        error("hook failed")
    end
    events.onEvent()
    events.onEvent()
    eq(#w.errors, 1)
    contains(w.errors[1], "hook failed")
end)

test("Main: an error in the key is reported once and does not stop the next press", function()
    local w = mainWorld()
    w.ns.Game.open = function()
        error("window failed")
    end
    local func = w.bindings["atlasloot/open"].info.func
    func()
    func()
    eq(#w.errors, 1)
    contains(w.errors[1], "window failed")
end)

-- ------------------------------------------------------------------- Game

-- The real Game.lua against a mocked client.
test("Game: settings come from the saved variable, which may arrive late or not at all", function()
    local w = newWorld()
    local fresh = {}
    local chunk = assert(loadfile(addonDir .. "/Game.lua"))
    chunk("WowVision_AtlasLoot", fresh)
    local Game = fresh.Game
    WowVisionAtlasLootDB = nil
    eq(Game.getSetting("classFilter"), true)
    eq(Game.getSetting("levelFilter"), false)
    Game.setSetting("levelFilter", true)
    eq(WowVisionAtlasLootDB.levelFilter, true)
    eq(Game.getSetting("levelFilter"), true)
    WowVisionAtlasLootDB = { classFilter = false }
    eq(Game.getSetting("classFilter"), false, "a saved false is a value")
    check(w ~= nil)
end)

test("Game: atlas() is AtlasLoot's table, or nil without an ItemDB and a Loader", function()
    newWorld()
    local fresh = {}
    assert(loadfile(addonDir .. "/Game.lua"))("WowVision_AtlasLoot", fresh)
    local Game = fresh.Game
    check(Game.atlas() ~= nil)
    local saved = AtlasLoot
    AtlasLoot = {}
    eq(Game.atlas(), nil)
    AtlasLoot = nil
    eq(Game.atlas(), nil)
    AtlasLoot = saved
end)

test("Game: item facts from the client, and a request when the name is not there", function()
    local fresh = {}
    assert(loadfile(addonDir .. "/Game.lua"))("WowVision_AtlasLoot", fresh)
    local Game = fresh.Game
    local requested = {}
    C_Item = {
        GetItemInfo = function(id)
            if id == 1 then
                return "Sword", "link", 3, 20, 10, "Weapon", "Swords", 1, "INVTYPE_WEAPON"
            end
            return nil
        end,
        GetItemInfoInstant = function(id)
            return id, "Armor", "Cloth", "INVTYPE_HEAD"
        end,
        RequestLoadItemDataByID = function(id)
            requested[#requested + 1] = id
        end,
    }
    local known = Game.itemInfo(1)
    eq(known.name, "Sword")
    eq(known.minLevel, 10)
    eq(known.equipLoc, "INVTYPE_WEAPON")
    eq(known.cached, true)
    local unknown = Game.itemInfo(2)
    eq(unknown.name, nil)
    eq(unknown.cached, false)
    eq(unknown.equipLoc, "INVTYPE_HEAD", "the slot is known at once")
    eq(unknown.subType, "Cloth")
    Game.itemInfo(2)
    eq(#requested, 1, "asked once")
    C_Item = nil
end)

test("Game: canUse is AtlasLoot's class filter, and true when it cannot tell", function()
    local w = newWorld()
    local fresh = {}
    assert(loadfile(addonDir .. "/Game.lua"))("WowVision_AtlasLoot", fresh)
    local Game = fresh.Game
    UnitClassBase = function()
        return "MAGE"
    end
    local asked
    w.atlas.Data.ClassFilter = {
        ClassCanUseItem = function(class, id)
            asked = class .. id
            return id ~= 9
        end,
    }
    eq(Game.canUse(8), true)
    eq(asked, "MAGE8")
    eq(Game.canUse(9), false)
    w.atlas.Data.ClassFilter.ClassCanUseItem = function()
        error("boom")
    end
    eq(Game.canUse(9), true)
    w.atlas.Data.ClassFilter = nil
    eq(Game.canUse(9), true)
    UnitClassBase = nil
end)

test("Game: drop rate, set names and set items come from AtlasLoot's data, safely", function()
    local w = newWorld()
    local fresh = {}
    assert(loadfile(addonDir .. "/Game.lua"))("WowVision_AtlasLoot", fresh)
    local Game = fresh.Game
    w.atlas.Data.Droprate = {
        GetData = function(_, npc, item)
            if npc == 5 and item == 7 then
                return 33
            end
            return ""
        end,
    }
    eq(Game.droprate(5, 7), 33)
    eq(Game.droprate({ 5, 6 }, 7), 33)
    eq(Game.droprate(5, 8), nil)
    eq(Game.droprate(nil, 7), nil)
    w.atlas.Data.ItemSet = {
        GetSetName = function(id)
            return "Set" .. id
        end,
        GetSetItems = function()
            return { 1, 2 }
        end,
    }
    eq(Game.setName(3), "Set3")
    eq(#Game.setItems(3), 2)
    w.atlas.Data.ItemSet.GetSetName = function()
        error("boom")
    end
    w.atlas.Data.ItemSet.GetSetItems = function()
        return "not a table"
    end
    eq(Game.setName(3), nil)
    eq(Game.setItems(3), nil)
    w.atlas.Data = nil
    eq(Game.droprate(5, 7), nil)
    eq(Game.setName(3), nil)
    eq(Game.setItems(3), nil)
end)

test("Game: the game's words for a slot, a quality and a class", function()
    newWorld()
    local fresh = {}
    assert(loadfile(addonDir .. "/Game.lua"))("WowVision_AtlasLoot", fresh)
    local Game = fresh.Game
    INVTYPE_HEAD = "Head"
    ITEM_QUALITY4_DESC = "Epic"
    LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage" }
    eq(Game.slotName("INVTYPE_HEAD"), "Head")
    eq(Game.slotName("INVTYPE_NOPE"), nil)
    eq(Game.slotName(""), nil)
    eq(Game.slotName(nil), nil)
    eq(Game.qualityName(4), "Epic")
    eq(Game.qualityName(nil), nil)
    eq(Game.qualityName(9), nil)
    eq(Game.className("MAGE"), "Mage")
    eq(Game.className("NOBODY"), nil)
    INVTYPE_HEAD, ITEM_QUALITY4_DESC, LOCALIZED_CLASS_NAMES_MALE = nil, nil, nil
end)

test("Game: the window is opened and closed through WowVision's UI host", function()
    newWorld()
    local fresh = {}
    assert(loadfile(addonDir .. "/Game.lua"))("WowVision_AtlasLoot", fresh)
    local Game = fresh.Game
    local calls = {}
    WowVision.UIHost = {
        windowManager = { openWindows = {} },
        openTemporaryWindow = function(_, config)
            calls[#calls + 1] = "open:" .. config.name
            table.insert(WowVision.UIHost.windowManager.openWindows, { name = config.name })
        end,
        closeWindow = function(_, name)
            calls[#calls + 1] = "close:" .. name
            WowVision.UIHost.windowManager.openWindows = {}
        end,
        tooltip = {
            speak = function()
                calls[#calls + 1] = "tooltip"
            end,
        },
    }
    eq(Game.isOpen(), false)
    eq(Game.open({}), true)
    eq(Game.isOpen(), true)
    Game.close()
    eq(Game.isOpen(), false)
    eq(Game.speakTooltip(), true)
    eq(table.concat(calls, ","), "open:atlasloot-browser,close:atlasloot-browser,tooltip")
    WowVision.UIHost = nil
    eq(Game.open({}), false)
    eq(Game.isOpen(), false)
    eq(Game.speakTooltip(), false)
    Game.close()
end)

-- ---------------------------------------------------- what the mutations showed

test("describe: the level asked is above the player's only when it is higher, not equal", function()
    local w = newWorld()
    local text = w.ns.Loot.describe({ id = 8001 }, { classFilter = true }, w.ns.Game)
    contains(text, "requires level 20")
    eq(text:find("above your level", 1, true), nil, "level 20 at level 20")
end)

test("describe: an equipment of item level 1 does not say its item level", function()
    local w = newWorld()
    w.info[4003] = { name = "Shirt", quality = 1, level = 1, minLevel = 1, type = "Armor", subType = "Miscellaneous", equipLoc = "INVTYPE_HEAD", cached = true }
    eq(w.ns.Loot.describe({ id = 4003 }, {}, w.ns.Game), "Shirt, Head, Miscellaneous")
end)

test("entries: an entry hidden from the Horde is hidden from a Horde player, one for the Alliance is kept for them", function()
    local w = newWorld({ player = { class = "WARRIOR", level = 20, faction = "Horde" } })
    local entries = w.ns.Loot.entries({ { 1, 5187, [901] = false }, { 2, 5201, [902] = 5302 }, { 3, 5203, [901] = true } }, { "Item" }, w.ns.Game)
    eq(#entries, 2)
    eq(entries[1].id, 5201, "the Alliance's own item does not replace the Horde's")
    eq(entries[2].id, 5203)
end)

test("an item listed twice at one place is two lines with their own identities", function()
    local w = screenWorld()
    w.atlasData["Deadmines"].items[2][w.NORMAL] = { { 1, 5203 }, { 1, 5203 } }
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Sneed")
    local ids = {}
    for _, node in ipairs(w.d.nodes()) do
        if node.vtable.tooltip ~= nil then
            ids[#ids + 1] = node.id.key
        end
    end
    eq(#ids, 2)
    check(ids[1] ~= ids[2], "the two lines share an identity")
end)

test("choosing another category starts at AtlasLoot's own game version again", function()
    local w = screenWorld({ forever = true })
    w.atlas.db.GUI.selectedGameVersion = 4
    enter(w, "Test Loot")
    w.d.focus("Game version:")
    w.d.enter()
    contains(readings(w.d), "Game version: Classic")
    w.d.focus("Back")
    w.d.enter()
    enter(w, "Test Loot")
    contains(readings(w.d), "Game version: WoW: Forever")
end)

test("choosing a boss asks AtlasLoot to bring in the module its loot lives in", function()
    local w = screenWorld()
    local asked = {}
    w.atlas.ItemDB.CheckForLink = function(_, id, key, boss, load)
        asked[#asked + 1] = id .. "/" .. key .. "/" .. boss .. "/" .. tostring(load)
    end
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Sneed")
    eq(asked[1], "TestLoot/Deadmines/2/true")
end)

test("a boss with nothing to show is where the player lands, and hears it", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Empty boss")
    eq(w.d.say(), "No item to show.")
end)

test("Main: closing a screen the key opened leaves AtlasLoot's window as it is", function()
    local w = mainWorld()
    w.ns.hookAtlasFrame()
    w.bindings["atlasloot/open"].info.func()
    w.frame:Show()
    w.ns.Screen.close()
    eq(w.frame.shown, true)
end)

test("Main: a screen that was closed behind our back does not leave the next one hiding the window", function()
    local w = mainWorld()
    w.ns.hookAtlasFrame()
    w.frame:Show()
    eq(w.ns.openedByAl, true)
    w.isOpen = false
    w.bindings["atlasloot/open"].info.func()
    eq(w.ns.openedByAl, false)
    w.ns.Screen.close()
    eq(w.frame.shown, true)
end)

test("Game: canUse is true when AtlasLoot's filter gives no answer", function()
    local w = newWorld()
    local fresh = {}
    assert(loadfile(addonDir .. "/Game.lua"))("WowVision_AtlasLoot", fresh)
    w.atlas.Data.ClassFilter = {
        ClassCanUseItem = function()
            return nil
        end,
    }
    UnitClassBase = function()
        return "MAGE"
    end
    eq(fresh.Game.canUse(1), true)
    UnitClassBase = nil
end)

-- ----------------------------------------- phase 2: slots, upgrades, sort

local function ids(list)
    local out = {}
    for _, entry in ipairs(list) do
        out[#out + 1] = entry.kind == "header" and "[h]" or tostring(entry.id)
    end
    return table.concat(out, " ")
end

local function items(...)
    local out = {}
    for position, id in ipairs({ ... }) do
        out[#out + 1] = { kind = "item", id = id, pos = position, npcID = 644 }
    end
    return out
end

local function values(choices)
    local out = {}
    for _, choice in ipairs(choices) do
        out[#out + 1] = choice.value
    end
    return table.concat(out, " ")
end

local function labels(choices)
    local out = {}
    for _, choice in ipairs(choices) do
        out[#out + 1] = choice.label
    end
    return table.concat(out, ", ")
end

-- Sets globals for the length of fn, then puts them back (a failure included).
local function withGlobals(wanted, fn)
    local saved = {}
    for key in pairs(wanted) do
        saved[key] = rawget(_G, key)
        rawset(_G, key, wanted[key])
    end
    local ok, err = pcall(fn)
    for key in pairs(wanted) do
        rawset(_G, key, saved[key])
    end
    if not ok then
        error(err, 0)
    end
end

local function freshGame()
    local fresh = {}
    assert(loadfile(addonDir .. "/Game.lua"))("WowVision_AtlasLoot", fresh)
    return fresh.Game
end

local function deadmines(w)
    return w.ns.Loot.table(w.atlas, "TestLoot", "Deadmines", 1, 1, w.ns.Game, 644)
end

test("slotGroup: every equip location has its group, and what is not gear is told apart", function()
    local Loot = newWorld().ns.Loot
    local expected = {
        INVTYPE_HEAD = "head",
        INVTYPE_NECK = "neck",
        INVTYPE_SHOULDER = "shoulder",
        INVTYPE_CLOAK = "cloak",
        INVTYPE_CHEST = "chest",
        INVTYPE_ROBE = "chest",
        INVTYPE_WRIST = "wrist",
        INVTYPE_HAND = "hands",
        INVTYPE_WAIST = "waist",
        INVTYPE_LEGS = "legs",
        INVTYPE_FEET = "feet",
        INVTYPE_FINGER = "finger",
        INVTYPE_TRINKET = "trinket",
        INVTYPE_WEAPON = "weapons",
        INVTYPE_2HWEAPON = "weapons",
        INVTYPE_WEAPONMAINHAND = "weapons",
        INVTYPE_WEAPONOFFHAND = "weapons",
        INVTYPE_SHIELD = "offhand",
        INVTYPE_HOLDABLE = "offhand",
        INVTYPE_RANGED = "ranged",
        INVTYPE_RANGEDRIGHT = "ranged",
        INVTYPE_THROWN = "ranged",
        INVTYPE_RELIC = "ranged",
        INVTYPE_BAG = "otherGear",
        INVTYPE_TABARD = "otherGear",
        INVTYPE_BODY = "otherGear",
        [""] = "notGear",
    }
    for loc, group in pairs(expected) do
        eq(Loot.slotGroup(loc), group, loc)
    end
    eq(Loot.slotGroup(nil), "notGear")
end)

test("slotLabel: the game's word for a slot, our own name for a group of them", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    eq(Loot.slotLabel("head", Game), "Head")
    eq(Loot.slotLabel("cloak", Game), "Back")
    eq(Loot.slotLabel("neck", Game), "neck", "without the game's word, the equip location in lower case")
    eq(Loot.slotLabel("weapons", Game), "Weapons")
    eq(Loot.slotLabel("offhand", Game), "Shields and held in off hand")
    eq(Loot.slotLabel("ranged", Game), "Ranged, thrown and relics")
    eq(Loot.slotLabel("otherGear", Game), "Other equipment")
    eq(Loot.slotLabel("notGear", Game), "Not equipment")
    eq(Loot.slotLabel("nonsense", Game), "nonsense")
    local french = newWorld({ locale = "frFR" })
    eq(french.ns.Loot.slotLabel("weapons", french.ns.Game), "Armes")
end)

test("visible: the slot filter keeps one group, and an item the game has said nothing about", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local shown, hidden = Loot.visible(deadmines(w), { slot = "hands" }, Game)
    eq(ids(shown), "5202 [h] 5202 5203 5203")
    eq(hidden, 3, "the hammer, the cloak and the helm")
    shown, hidden = Loot.visible(deadmines(w), { classFilter = true, slot = "hands" }, Game)
    eq(ids(shown), "[h] 5203 5203")
    eq(hidden, 5, "the class filter and the slot filter both count")
    shown, hidden = Loot.visible(items(99999), { slot = "head" }, Game)
    eq(#shown, 1, "an item the game has not described is kept")
    eq(hidden, 0)
    shown = Loot.visible(deadmines(w), {}, Game)
    eq(#shown, 8, "no slot, no filtering")
end)

test("slotChoices: all the slots, then the groups the lines have, and the one picked", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local lines = Loot.visible(deadmines(w), { classFilter = true }, Game)
    local choices = Loot.slotChoices(lines, nil, Game)
    eq(values(choices), "all head cloak hands weapons", "in the order of the slots, not of the table")
    eq(labels(choices), "All slots, Head, Back, Hands, Weapons")
    eq(values(Loot.slotChoices(lines, "feet", Game)), "all head cloak hands feet weapons", "the picked slot is always offered")
    eq(values(Loot.slotChoices(lines, "hands", Game)), "all head cloak hands weapons", "and not twice")
    eq(values(Loot.slotChoices(items(99999), nil, Game)), "all", "an item the game has not described has no slot yet")
    eq(values(Loot.slotChoices({}, nil, Game)), "all")
end)

test("upgrade: a slot with nothing worn in it is an upgrade", function()
    local w = newWorld()
    w.worn.INVTYPE_CLOAK = { { empty = true } }
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game).how, "empty")
end)

test("upgrade: by item level, only when it is higher than what is worn", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 15 } }
    local up = Loot.upgrade({ kind = "item", id = 5201 }, Game)
    eq(up.how, "level")
    eq(up.more, 5, "5201 is item level 20")
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 20 } }
    eq(Loot.upgrade({ kind = "item", id = 5201 }, Game), false, "the same level is not an upgrade")
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 25 } }
    eq(Loot.upgrade({ kind = "item", id = 5201 }, Game), false)
end)

test("upgrade: with two slots it is judged against the lowest, and a free one wins at once", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    w.worn.INVTYPE_FINGER = { { id = 1, level = 40 }, { id = 2, level = 25 } }
    eq(Loot.upgrade({ kind = "item", id = 6001 }, Game).more, 5, "the ring is item level 30")
    w.worn.INVTYPE_FINGER = { { id = 1, level = 40 }, { id = 2, level = 35 } }
    eq(Loot.upgrade({ kind = "item", id = 6001 }, Game), false)
    w.worn.INVTYPE_FINGER = { { id = 1, level = 40 }, { empty = true } }
    eq(Loot.upgrade({ kind = "item", id = 6001 }, Game).how, "empty")
    w.worn.INVTYPE_FINGER = { { id = 1, level = 40 }, { id = 2 } }
    eq(Loot.upgrade({ kind = "item", id = 6001 }, Game), nil, "what is worn has no level yet")
end)

test("upgrade: what is worn already, what is not gear, and what the game has not said", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    w.worn.INVTYPE_FINGER = { { id = 6001, level = 30 }, { empty = true } }
    eq(Loot.upgrade({ kind = "item", id = 6001 }, Game), false, "it is the ring worn: no news, and the free slot beside it is not either")
    eq(Loot.upgrade({ kind = "item", id = 5302 }, Game), false, "no slot listed: not gear")
    w.info = {}
    local asked = w.wornCalls
    eq(Loot.upgrade({ kind = "item", id = 5201 }, Game), nil, "the game has not sent the item")
    eq(w.wornCalls, asked, "so what is worn is not even asked")
    w.info = infoTable()
    w.info[5201].level = nil
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 10 } }
    eq(Loot.upgrade({ kind = "item", id = 5201 }, Game), nil, "an item without a level cannot be compared")
end)

test("upgrade: the game's own item level count is preferred to the one in the item's facts", function()
    local w = newWorld()
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 40 } }
    w.ns.Game.itemLevelOf = function()
        return 50
    end
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game).more, 10, "50, not the 20 of the item's facts")
end)

test("upgrade: the judgement is kept until what is worn changes, a false one too", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local entry = { kind = "item", id = 5201 }
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 15 } }
    eq(Loot.upgrade(entry, Game).more, 5)
    Loot.upgrade(entry, Game)
    Loot.upgrade(entry, Game)
    eq(w.wornCalls, 1, "asked once")
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 25 } }
    eq(Loot.upgrade(entry, Game).more, 5, "the same answer until the equipment changes")
    w.gear = w.gear + 1
    eq(Loot.upgrade(entry, Game), false)
    eq(w.wornCalls, 2)
    Loot.upgrade(entry, Game)
    eq(w.wornCalls, 2, "a false answer is kept as well")
    -- an answer that is not known yet is not kept
    local pending = { kind = "item", id = 5203 }
    w.worn.INVTYPE_HAND = { { id = 1 } }
    eq(Loot.upgrade(pending, Game), nil)
    eq(Loot.upgrade(pending, Game), nil)
    w.worn.INVTYPE_HAND = { { id = 1, level = 10 } }
    eq(Loot.upgrade(pending, Game).how, "level", "asked again, and answered")
end)

test("upgrade: with Pawn, it is Pawn who says", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    w.info[5201].link = "item:5201"
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 99 } }
    local asked
    w.pawn = function(link)
        asked = link
        return { percent = 0.126 }
    end
    local up = Loot.upgrade({ kind = "item", id = 5201 }, Game)
    eq(asked, "item:5201")
    eq(up.how, "pawn")
    eq(up.percent, 0.126)
    w.pawn = function()
        return { big = true }
    end
    eq(Loot.upgrade({ kind = "item", id = 5201 }, Game).big, true)
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 1 } }
    w.pawn = function()
        return false
    end
    eq(Loot.upgrade({ kind = "item", id = 5201 }, Game), false, "no upgrade for Pawn, whatever the item level says")
    w.pawn = function()
        return nil
    end
    eq(Loot.upgrade({ kind = "item", id = 5201 }, Game), nil, "Pawn has nothing on the item yet")
end)

test("upgrade: Pawn is not asked for what is not gear, for a trinket, or without a link", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    w.pawn = function()
        error("Pawn must not be asked")
    end
    w.info[9001] = { name = "Old Trinket", quality = 3, level = 40, minLevel = 1, type = "Armor", subType = "Miscellaneous", equipLoc = "INVTYPE_TRINKET", cached = true, link = "item:9001" }
    w.worn.INVTYPE_TRINKET = { { id = 1, level = 10 }, { id = 2, level = 50 } }
    local up = Loot.upgrade({ kind = "item", id = 9001 }, Game)
    eq(up.how, "level", "a trinket is judged by item level")
    eq(up.more, 30)
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 15 } }
    eq(Loot.upgrade({ kind = "item", id = 5201 }, Game).how, "level", "an item without a link is judged by item level")
    eq(Loot.upgrade({ kind = "item", id = 5302 }, Game), false, "not gear")
    eq(w.pawnCalls, 0)
end)

test("visible: an item's slot is worked out once, not at every tick", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local asked = 0
    local itemInfo = Game.itemInfo
    Game.itemInfo = function(id)
        asked = asked + 1
        return itemInfo(id)
    end
    local lines = items(5201, 5203, 5302)
    Loot.visible(lines, { slot = "hands" }, Game)
    local first = asked
    check(first >= 3, "each item was asked about")
    Loot.visible(lines, { slot = "hands" }, Game)
    Loot.visible(lines, { slot = "head" }, Game)
    eq(asked, first, "and not again")
end)

test("upgrade: without Pawn the item level judges, whatever the items' links", function()
    local w = newWorld()
    w.info[5201].link = "item:5201"
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 15 } }
    w.pawn = nil
    local up = w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game)
    eq(up.how, "level")
    eq(w.pawnCalls, 0, "Pawn was not asked")
end)

test("upgradeText: what each judgement says", function()
    local Loot = newWorld().ns.Loot
    eq(Loot.upgradeText({ how = "pawn", percent = 0.126 }), "upgrade of 13 percent, judged by Pawn")
    eq(Loot.upgradeText({ how = "pawn", percent = 0.04 }), "upgrade of 4 percent, judged by Pawn")
    eq(Loot.upgradeText({ how = "pawn", big = true }), "big upgrade, judged by Pawn")
    eq(Loot.upgradeText({ how = "pawn" }), "big upgrade, judged by Pawn")
    eq(Loot.upgradeText({ how = "level", more = 7 }), "upgrade, item level 7 higher than what you wear")
    eq(Loot.upgradeText({ how = "empty" }), "upgrade, nothing worn in that slot")
    local french = newWorld({ locale = "frFR" }).ns.Loot
    eq(french.upgradeText({ how = "level", more = 7 }), "amélioration, niveau d'objet supérieur de 7 à ce que vous portez")
end)

test("visible: the upgrades filter hides what is no upgrade and keeps what the game has not said", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    w.worn.INVTYPE_2HWEAPON = { { empty = true } }
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 15 } }
    w.worn.INVTYPE_HAND = { { id = 2, level = 30 } }
    local shown, hidden = Loot.visible(deadmines(w), { upgradesOnly = true }, Game)
    eq(ids(shown), "5187 5201", "the hammer (free slot) and the cloak (5 higher); the gloves, the helm are not")
    eq(hidden, 5, "seven items, two kept")
    w.info[5187] = { cached = false }
    shown = Loot.visible(deadmines(w), { upgradesOnly = true }, Game)
    eq(ids(shown), "5187 5201", "an item the game has not sent is kept")
    eq(#Loot.visible(deadmines(w), { upgradesOnly = false }, Game), 8)
end)

test("describe: an upgrade says so, and what is no upgrade says nothing", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local entry = { id = 5187, npcID = 644 }
    eq(Loot.describe(entry, {}, Game), "Rhahk'Zor's Hammer, Rare, Two-Hand, Two-Handed Maces, item level 19, requires level 15, 12.5 percent drop chance")
    w.worn.INVTYPE_2HWEAPON = { { empty = true } }
    w.gear = w.gear + 1
    eq(Loot.describe(entry, {}, Game), "Rhahk'Zor's Hammer, Rare, Two-Hand, Two-Handed Maces, item level 19, requires level 15, upgrade, nothing worn in that slot, 12.5 percent drop chance")
    w.worn.INVTYPE_2HWEAPON = { { id = 1, level = 15 } }
    w.gear = w.gear + 1
    contains(Loot.describe(entry, {}, Game), "upgrade, item level 4 higher than what you wear")
    w.worn.INVTYPE_2HWEAPON = { { id = 1, level = 60 } }
    w.gear = w.gear + 1
    eq(Loot.describe(entry, {}, Game):find("upgrade", 1, true), nil)
end)

test("sort: item level, highest first, the ones the game has not described last, equal ones in AtlasLoot's order", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    -- levels: 5187 19, 5201 20, 5202 18, 5203 17, 5302 21
    local lines = items(99999, 5203, 5187, 5302, 5203, 5201, 5202)
    eq(ids(Loot.sort(lines, "level", Game)), "5302 5201 5187 5202 5203 5203 99999")
end)

test("sort: each run of items under a header is ordered on its own, the headers stay", function()
    local w = newWorld()
    local lines = w.ns.Loot.visible(deadmines(w), {}, w.ns.Game)
    eq(ids(lines), "5187 5201 5202 [h] 5202 5203 5302 5203")
    eq(ids(w.ns.Loot.sort(lines, "level", w.ns.Game)), "5201 5187 5202 [h] 5302 5202 5203 5203")
end)

test("sort: by slot, in the order of the slots, the higher item level first within one", function()
    local w = newWorld()
    eq(ids(w.ns.Loot.sort(items(5187, 5201, 5202, 5302, 5203), "slot", w.ns.Game)), "5302 5201 5202 5203 5187")
    eq(ids(w.ns.Loot.sort(items(99999, 5302), "slot", w.ns.Game)), "5302 99999", "no slot yet comes last")
end)

test("sort: biggest upgrade first, by item level", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    w.worn.INVTYPE_2HWEAPON = { { empty = true } }
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 10 } }
    w.worn.INVTYPE_HAND = { { id = 2, level = 17 } }
    -- 5187: free slot; 5201: 10 above; 5202: 1 above; 5203: level 17, no upgrade; 5302: not gear
    eq(ids(Loot.sort(items(5203, 5202, 5302, 5201, 5187), "upgrade", Game)), "5187 5201 5202 5203 5302")
end)

test("sort: biggest upgrade first, by Pawn", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    for _, id in ipairs({ 5187, 5201, 5202, 5203 }) do
        w.info[id].link = "item:" .. id
    end
    w.worn.INVTYPE_2HWEAPON = { { id = 1, level = 1 } }
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 1 } }
    w.worn.INVTYPE_HAND = { { id = 2, level = 1 } }
    local answers = {
        ["item:5187"] = { percent = 0.05 },
        ["item:5201"] = { percent = 0.2 },
        ["item:5202"] = { big = true },
        ["item:5203"] = false,
    }
    w.pawn = function(link)
        return answers[link]
    end
    eq(ids(Loot.sort(items(5203, 5187, 5201, 5302, 5202), "upgrade", Game)), "5202 5201 5187 5203 5302")
end)

test("sort: by drop chance, highest first, the unknown ones last", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local rates = { [5201] = "30", [5187] = 12.5, [5203] = 5 }
    Game.droprate = function(_, id)
        return rates[id]
    end
    eq(ids(Loot.sort(items(5203, 5187, 5201, 5302), "drop", Game)), "5201 5187 5203 5302")
end)

test("sort: AtlasLoot's order, or a way that does not exist, leaves the lines as they are", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local lines = items(5203, 5187, 5201)
    eq(Loot.sort(lines, "default", Game), lines)
    eq(Loot.sort(lines, nil, Game), lines)
    eq(Loot.sort(lines, "nonsense", Game), lines)
    eq(#Loot.sort({}, "level", Game), 0)
end)

test("sortChoices: the ways to sort, in the player's language", function()
    local w = newWorld()
    eq(values(w.ns.Loot.sortChoices()), "default level upgrade slot drop")
    eq(labels(w.ns.Loot.sortChoices()), "AtlasLoot's order, Item level, highest first, Biggest upgrade first, By slot, Drop chance, highest first")
    local french = newWorld({ locale = "frFR" })
    eq(labels(french.ns.Loot.sortChoices()), "Ordre d'AtlasLoot, Niveau d'objet, le plus haut d'abord, Plus grosse amélioration d'abord, Par emplacement, Chance de tomber, la plus haute d'abord")
    local german = newWorld({ locale = "deDE" })
    eq(labels(german.ns.Loot.sortChoices()):sub(1, 26), "Reihenfolge von AtlasLoot,")
end)

-- ------------------------------------------------------------ phase 2: Game

test("Game: the equipment version goes up with each change", function()
    newWorld()
    local Game = freshGame()
    local before = Game.gearVersion()
    Game.gearChanged()
    eq(Game.gearVersion(), before + 1)
    Game.gearChanged()
    eq(Game.gearVersion(), before + 2)
end)

test("Game: what is worn where an item goes", function()
    newWorld()
    local Game = freshGame()
    local links = {
        [11] = "|cff0070dd|Hitem:111::::::::20|h[Ring A]|h|r",
        [16] = "|cff0070dd|Hitem:116::::::::20|h[Blade]|h|r",
        [5] = "garbage",
    }
    local levels = { [links[11]] = 33, [links[16]] = 40 }
    withGlobals({
        GetInventoryItemLink = function(unit, slot)
            eq(unit, "player")
            return links[slot]
        end,
        GetDetailedItemLevelInfo = function(ref)
            return levels[ref]
        end,
    }, function()
        local rings = Game.wornSlots("INVTYPE_FINGER")
        eq(#rings, 2)
        eq(rings[1].id, 111)
        eq(rings[1].level, 33)
        eq(rings[2].empty, true)
        local two = Game.wornSlots("INVTYPE_2HWEAPON")
        eq(#two, 1)
        eq(two[1].id, 116)
        eq(two[1].level, 40)
        eq(Game.wornSlots("INVTYPE_ROBE")[1].id, nil, "a robe goes where the chest piece does (the link there is garbage)")
        eq(Game.wornSlots("INVTYPE_ROBE")[1].empty, nil)
        eq(Game.wornSlots("INVTYPE_HEAD")[1].empty, true)
        eq(Game.wornSlots("INVTYPE_BAG"), nil)
        eq(Game.wornSlots(""), nil)
        eq(Game.wornSlots(nil), nil)
    end)
end)

test("Game: WowVision's own slots are used when it has them, ours when it has not or fails", function()
    local w = newWorld()
    local Game = freshGame()
    withGlobals({
        GetInventoryItemLink = function()
            return nil
        end,
    }, function()
        WowVision.items = {
            compareSlots = function(loc)
                if loc == "INVTYPE_WEAPON" then
                    return { 16 }
                end
                return nil
            end,
        }
        eq(#Game.wornSlots("INVTYPE_WEAPON"), 1, "WowVision says the main hand only")
        eq(Game.wornSlots("INVTYPE_HEAD"), nil, "and that a head piece is not gear (WowVision's word)")
        WowVision.items = {
            compareSlots = function()
                error("boom")
            end,
        }
        eq(#Game.wornSlots("INVTYPE_WEAPON"), 2, "a failure falls back to our own table")
        WowVision.items = nil
        eq(#Game.wornSlots("INVTYPE_WEAPON"), 2)
    end)
    WowVision.items = nil
    check(w ~= nil)
end)

test("Game: the ranged slot is the game's, or nothing", function()
    newWorld()
    local Game = freshGame()
    withGlobals({
        GetInventoryItemLink = function(_, slot)
            return slot == 18 and "|Hitem:777::::|h[Bow]|h" or nil
        end,
        GetInventorySlotInfo = function(name)
            return name == "RANGEDSLOT" and 18 or nil
        end,
    }, function()
        local slots = Game.wornSlots("INVTYPE_RANGED")
        eq(#slots, 1)
        eq(slots[1].id, 777)
        eq(Game.wornSlots("INVTYPE_RELIC")[1].id, 777)
    end)
    withGlobals({
        GetInventorySlotInfo = function()
            error("no such slot")
        end,
    }, function()
        eq(Game.wornSlots("INVTYPE_RANGED"), nil)
    end)
    eq(Game.wornSlots("INVTYPE_RANGED"), nil, "no slot function at all")
end)

test("Game: the item level as the game counts it", function()
    newWorld()
    local Game = freshGame()
    withGlobals({
        GetDetailedItemLevelInfo = function(ref)
            if ref == "bad" then
                error("boom")
            end
            return ({ a = 12, zero = 0, text = "x" })[ref]
        end,
    }, function()
        eq(Game.itemLevelOf("a"), 12)
        eq(Game.itemLevelOf("zero"), nil)
        eq(Game.itemLevelOf("text"), nil)
        eq(Game.itemLevelOf("missing"), nil)
        eq(Game.itemLevelOf("bad"), nil)
    end)
    withGlobals({
        C_Item = {
            GetDetailedItemLevelInfo = function()
                return 77
            end,
        },
    }, function()
        eq(Game.itemLevelOf("a"), 77, "C_Item first")
    end)
    eq(Game.itemLevelOf("a"), nil, "no function at all")
    withGlobals({
        GetItemInfo = function(ref)
            if ref == "plain" then
                return "Name", "link", 2, 25
            end
            return nil
        end,
    }, function()
        eq(Game.itemLevelOf("plain"), 25, "without the detailed function, the item's own level")
        eq(Game.itemLevelOf("other"), nil)
    end)
    withGlobals({
        GetDetailedItemLevelInfo = function()
            return nil
        end,
        GetItemInfo = function()
            return "Name", "link", 2, 31
        end,
    }, function()
        eq(Game.itemLevelOf("a"), 31, "when the detailed one has no answer yet")
    end)
    withGlobals({
        C_Item = {
            GetItemInfo = function()
                return "Name", "link", 2, 0
            end,
        },
    }, function()
        eq(Game.itemLevelOf("a"), nil, "a level of 0 is no level")
    end)
end)

test("Game: Pawn is ready when it is there with a scale shown, and asked once per equipment", function()
    newWorld()
    local Game = freshGame()
    local asked = 0
    local pawn = {
        PawnGetItemData = function() end,
        PawnIsItemAnUpgrade = function() end,
        PawnCommon = { Scales = { Mine = {}, Other = {} } },
        PawnIsScaleVisible = function(name)
            asked = asked + 1
            return name == "Mine"
        end,
    }
    withGlobals(pawn, function()
        eq(Game.pawnReady(), true)
        local once = asked
        check(once >= 1)
        eq(Game.pawnReady(), true)
        eq(Game.pawnReady(), true)
        eq(asked, once, "kept")
        Game.gearChanged()
        eq(Game.pawnReady(), true)
        check(asked > once, "asked again after a change of equipment")
    end)
    withGlobals({
        PawnGetItemData = pawn.PawnGetItemData,
        PawnIsItemAnUpgrade = pawn.PawnIsItemAnUpgrade,
        PawnCommon = { Scales = { Hidden = {} } },
        PawnIsScaleVisible = function()
            return false
        end,
    }, function()
        Game.gearChanged()
        eq(Game.pawnReady(), false, "no scale is shown for this player")
    end)
    withGlobals({
        PawnGetItemData = pawn.PawnGetItemData,
        PawnIsItemAnUpgrade = pawn.PawnIsItemAnUpgrade,
        PawnCommon = { Scales = { Any = {} } },
    }, function()
        Game.gearChanged()
        eq(Game.pawnReady(), true, "without the visibility function a scale counts")
    end)
    withGlobals({ PawnCommon = { Scales = {} }, PawnGetItemData = pawn.PawnGetItemData, PawnIsItemAnUpgrade = pawn.PawnIsItemAnUpgrade }, function()
        Game.gearChanged()
        eq(Game.pawnReady(), false, "no scale at all")
    end)
    withGlobals({ PawnCommon = {}, PawnGetItemData = pawn.PawnGetItemData, PawnIsItemAnUpgrade = pawn.PawnIsItemAnUpgrade }, function()
        Game.gearChanged()
        eq(Game.pawnReady(), false, "Pawn without its table of scales")
    end)
    withGlobals({ PawnCommon = { Scales = { A = {} } }, PawnGetItemData = pawn.PawnGetItemData }, function()
        Game.gearChanged()
        eq(Game.pawnReady(), false, "half of Pawn's functions")
    end)
    Game.gearChanged()
    eq(Game.pawnReady(), false, "no Pawn")
end)

test("Game: Pawn's judgement of an item", function()
    local w = newWorld()
    local Game = freshGame()
    local answer
    local data = { ID = 1 }
    local pawn = {
        PawnGetItemData = function(link)
            if link == "nodata" then
                return nil
            elseif link == "broken" then
                error("boom")
            end
            return data
        end,
        PawnIsItemAnUpgrade = function(item)
            eq(item, data)
            if type(answer) == "function" then
                return answer()
            end
            return answer
        end,
    }
    withGlobals(pawn, function()
        eq(Game.pawnUpgrade("nodata"), nil, "Pawn has no data on it yet")
        eq(Game.pawnUpgrade("broken"), nil)
        answer = nil
        eq(Game.pawnUpgrade("item"), false, "no answer: no upgrade")
        answer = {}
        eq(Game.pawnUpgrade("item"), false)
        answer = { { PercentUpgrade = 0.1 }, { PercentUpgrade = 0.3 }, { PercentUpgrade = 0.2 } }
        local best = Game.pawnUpgrade("item")
        eq(best.percent, 0.3, "the best of the scales")
        eq(best.big, nil)
        answer = { { PercentUpgrade = "n/a" } }
        eq(Game.pawnUpgrade("item").big, true, "no number: a big one, as WowVision reads it")
        answer = { { PercentUpgrade = 99 } }
        eq(Game.pawnUpgrade("item").percent, 99, "below the default threshold of 100")
        answer = { { PercentUpgrade = 100 } }
        eq(Game.pawnUpgrade("item").big, true)
        PawnBigUpgradeThreshold = 2
        answer = { { PercentUpgrade = 2.5 } }
        eq(Game.pawnUpgrade("item").big, true, "Pawn's own threshold")
        answer = { { PercentUpgrade = 1.5 } }
        eq(Game.pawnUpgrade("item").percent, 1.5)
        PawnBigUpgradeThreshold = nil
        answer = function()
            error("pawn failed")
        end
        eq(Game.pawnUpgrade("item"), false, "an error in Pawn is no upgrade")
        Game.pawnUpgrade("item")
        eq(#w.errors, 1, "reported once")
        contains(w.errors[1], "pawn failed")
    end)
    eq(Game.pawnUpgrade("item"), nil, "no Pawn")
end)

test("Game: the new settings are off and AtlasLoot's order until the player says", function()
    newWorld()
    local Game = freshGame()
    WowVisionAtlasLootDB = nil
    eq(Game.getSetting("upgradesOnly"), false)
    eq(Game.getSetting("sort"), "default")
    Game.setSetting("sort", "level")
    eq(Game.getSetting("sort"), "level")
    WowVisionAtlasLootDB = nil
end)

-- ---------------------------------------------------------- phase 2: Screen

local function bossScreen(config)
    local w = screenWorld(config)
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    enter(w, "Rhahk'Zor")
    return w
end

-- The options of a pushed choice screen, each one's name only ("Hands", not "Hands, Button, 4 of 5").
local function optionList(options)
    local out = {}
    for _, line in ipairs(options.dump()) do
        out[#out + 1] = line:match("^(.-), Button") or line
    end
    return table.concat(out, " | ")
end

-- Opens the choice node starting with text and picks the option starting with pick, in the child screen it pushes.
local function choose(w, text, pick)
    local before = #w.env.pushed
    w.d.focus(text)
    w.d.enter()
    check(#w.env.pushed == before + 1, "the choice pushed a screen of its options")
    local pushed = w.env.pushed[#w.env.pushed]
    local options = w.env.driver(pushed.render)
    check(options.focus(pick) ~= nil, "no option starting with '" .. pick .. "' in: " .. table.concat(options.dump(), " | "))
    options.enter()
    return options
end

test("the filters stop has the upgrades switch, the slot and the sort", function()
    local w = bossScreen()
    local text = readings(w.d)
    contains(text, "Only upgrades, judged by item level")
    contains(text, "Slot")
    contains(text, "All slots")
    contains(text, "Sort")
    contains(text, "AtlasLoot's order")
    eq(w.ns.Game.getSetting("upgradesOnly"), false)
end)

test("the upgrades switch says who judges: Pawn when it is there, else the item level", function()
    local w = bossScreen()
    contains(readings(w.d), "Only upgrades, judged by item level")
    w.pawn = function()
        return false
    end
    local text = readings(w.d)
    contains(text, "Only upgrades, judged by Pawn")
    eq(text:find("judged by item level", 1, true), nil)
end)

test("the upgrades switch keeps the upgrades, and says how many it hid", function()
    local w = bossScreen()
    w.worn.INVTYPE_2HWEAPON = { { empty = true } }
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 25 } }
    w.worn.INVTYPE_HAND = { { id = 2, level = 30 } }
    w.d.focus("Only upgrades")
    w.d.enter()
    eq(w.settings.upgradesOnly, true)
    local text = readings(w.d)
    contains(text, "Rhahk'Zor's Hammer")
    contains(text, "upgrade, nothing worn in that slot")
    eq(text:find("Emberstone Cloak", 1, true), nil, "20 is not above 25")
    eq(text:find("Cloth Gloves", 1, true), nil)
    contains(text, "Items shown: 1, Hidden by the filters: 6")
    w.d.focus("Only upgrades")
    w.d.enter()
    eq(w.settings.upgradesOnly, false)
    contains(readings(w.d), "Emberstone Cloak")
end)

test("the slot choice lists the slots the loot has, and picking one limits the list", function()
    local w = bossScreen()
    local node = w.d.focus("Slot")
    check(node ~= nil)
    w.d.enter()
    local pushed = w.env.pushed[#w.env.pushed]
    local options = w.env.driver(pushed.render)
    eq(optionList(options), "All slots | Head | Back | Hands | Weapons")
    contains(options.dump()[1], "Selected", "the pick is told")
    eq(options.dump()[2]:find("Selected", 1, true), nil)
    options.focus("Hands")
    options.enter()
    eq(w.ns.Screen.state.slot, "hands")
    eq(w.env.popped, 1, "the options close")
    local text = readings(w.d)
    contains(text, "Cloth Gloves")
    eq(text:find("Rhahk'Zor's Hammer", 1, true), nil)
    eq(text:find("Emberstone Cloak", 1, true), nil)
    contains(text, "Items shown: 2, Hidden by the filters: 5, Slot: Hands")
    -- and back to all of them
    choose(w, "Slot", "All slots")
    eq(w.ns.Screen.state.slot, nil)
    contains(readings(w.d), "Rhahk'Zor's Hammer")
    eq(readings(w.d):find("Slot: ", 1, true), nil)
end)

test("the slot stays when the player goes to another boss, and is still offered when this boss has none of it", function()
    local w = bossScreen()
    choose(w, "Slot", "Hands")
    w.ns.Screen.back()
    enter(w, "Sneed")
    local text = readings(w.d)
    contains(text, "Slot: Hands")
    contains(text, "Cloth Gloves")
    w.ns.Screen.state.slot = "feet"
    text = readings(w.d)
    contains(text, "No item to show.")
    contains(text, "Items shown: 0, Hidden by the filters: 2, Slot: feet")
    w.d.focus("Slot")
    w.d.enter()
    local options = w.env.driver(w.env.pushed[#w.env.pushed].render)
    check(options.focus("feet") ~= nil, "the slot picked is offered, so it can be left")
end)

test("the slots offered follow the other filters", function()
    local w = bossScreen()
    w.d.focus("Only what my class can use")
    w.d.enter()
    w.d.focus("Slot")
    w.d.enter()
    local options = w.env.driver(w.env.pushed[#w.env.pushed].render)
    eq(optionList(options), "All slots | Head | Back | Hands | Weapons", "the gauntlets are hands too")
    w.ns.Game.setSetting("classFilter", true)
    w.ns.Game.setSetting("levelFilter", true)
    w.player.level = 10
    w.d.focus("Slot")
    w.d.enter()
    options = w.env.driver(w.env.pushed[#w.env.pushed].render)
    eq(optionList(options), "All slots", "nothing is left at level 10")
end)

test("the sort choice orders the list", function()
    local w = bossScreen()
    local text = readings(w.d)
    local cloak, hammer = text:find("Emberstone Cloak", 1, true), text:find("Rhahk'Zor's Hammer", 1, true)
    check(hammer < cloak, "AtlasLoot puts the hammer first")
    choose(w, "Sort", "Item level, highest first")
    eq(w.settings.sort, "level")
    text = readings(w.d)
    cloak, hammer = text:find("Emberstone Cloak", 1, true), text:find("Rhahk'Zor's Hammer", 1, true)
    check(cloak < hammer, "the cloak is item level 20, the hammer 19")
    contains(text, "Sort")
    choose(w, "Sort", "AtlasLoot's order")
    eq(w.settings.sort, "default")
end)

test("sorted by slot, each section goes from the head down and the sections stay where they are", function()
    local w = bossScreen()
    choose(w, "Sort", "By slot")
    local text = readings(w.d)
    local function at(name)
        return text:find(name, 1, true)
    end
    check(at("Emberstone Cloak") < at("Rhahk'Zor's Hammer"), "the cloak before the weapon")
    check(at("Rhahk'Zor's Hammer") < at("Alliance Helm"), "the header's items come after the ones above it")
    check(at("Alliance Helm") < at("Cloth Gloves"), "the helm before the gloves")
end)

test("French: the new controls speak French", function()
    local w = bossScreen({ locale = "frFR" })
    local text = readings(w.d)
    contains(text, "Seulement les améliorations, selon le niveau d'objet")
    contains(text, "Emplacement")
    contains(text, "Tous les emplacements")
    contains(text, "Tri")
    contains(text, "Ordre d'AtlasLoot")
    choose(w, "Emplacement", "Armes")
    contains(readings(w.d), "Emplacement : Armes")
    choose(w, "Emplacement", "Tous les emplacements")
    eq(readings(w.d):find("Emplacement :", 1, true), nil)
end)

test("German: the new controls speak German", function()
    local w = bossScreen({ locale = "deDE" })
    local text = readings(w.d)
    contains(text, "Nur Verbesserungen, nach Gegenstandsstufe")
    contains(text, "Alle Plätze")
    contains(text, "Sortierung")
end)

test("opening the screen makes the upgrades be judged again", function()
    local w = screenWorld()
    local before = w.gear
    w.ns.Screen.open()
    eq(w.gear, before + 1)
    w.ns.Screen.open()
    eq(w.gear, before + 1, "not when it is open already")
end)

test("Main: a change of equipment makes the upgrades be judged again, and nothing else", function()
    local w = mainWorld()
    local events = w.eventFrames[#w.eventFrames]
    check(events.events.PLAYER_EQUIPMENT_CHANGED)
    local before = w.gear
    events.onEvent(nil, "PLAYER_EQUIPMENT_CHANGED")
    eq(w.gear, before + 1)
    eq(w.ns.frameHooked, nil, "that event does not look for AtlasLoot's window")
    events.onEvent(nil, "PLAYER_LOGIN")
    eq(w.gear, before + 1)
    eq(w.ns.frameHooked, true)
end)

-- ------------------------------------- phase 3: a whole instance, search

-- The index of the test module, read to the end (budget = bosses at a time).
local function buildIndex(w, budget)
    local index = w.ns.Loot.index(w.atlas, "TestLoot", w.atlas.ItemDB:Get("TestLoot"), 1)
    for _ = 1, 200 do
        if index:step(w.ns.Game, budget or 1000) then
            break
        end
    end
    return index
end

local function recordList(index)
    local out = {}
    for _, record in ipairs(index.records) do
        out[#out + 1] = record.entry.id .. "@" .. record.boss
    end
    table.sort(out)
    return table.concat(out, " ")
end

-- An index of made-up records, one boss each, for the tests of the search itself.
local function fakeIndex(...)
    local records = {}
    for position, id in ipairs({ ... }) do
        records[#records + 1] = {
            entry = { kind = "item", id = id, pos = position },
            instance = "Inst",
            instanceKey = "I",
            boss = "Boss" .. position,
            bossIndex = position,
            diffs = {},
            bossDiffs = 1,
        }
    end
    return { records = records }
end

local FULL = "5187@Rhahk'Zor 5201@Rhahk'Zor 5201@Sneed 5202@Rhahk'Zor 5203@Hidden 5203@Rhahk'Zor 5203@Sneed 5302@Rhahk'Zor 6001@Tier sets 6002@Tier sets 7001@Baron 8001@Rhahk'Zor"

test("fold: accents, case and curly quotes taken out", function()
    local Loot = newWorld().ns.Loot
    eq(Loot.fold("Épée"), "epee")
    eq(Loot.fold("ÉPÉE DU ROI"), "epee du roi")
    eq(Loot.fold("Größe"), "grosse")
    eq(Loot.fold("Œuf Æther"), "oeuf aether")
    eq(Loot.fold("Où ça là"), "ou ca la")
    eq(Loot.fold("Île, Ñandú, Ýñ"), "ile, nandu, yn")
    eq(Loot.fold("l’épée"), "l'epee")
    eq(Loot.fold("Rhahk'Zor's Hammer"), "rhahk'zor's hammer")
    eq(Loot.fold(nil), "")
    eq(Loot.fold(12), "")
end)

test("words: the folded words of a search, and a search needs two letters in all", function()
    local Loot = newWorld().ns.Loot
    eq(table.concat(Loot.words("  Épée   du ROI "), "|"), "epee|du|roi")
    eq(#Loot.words(""), 0)
    eq(#Loot.words("   "), 0)
    eq(Loot.searchable(Loot.words("")), false)
    eq(Loot.searchable(Loot.words("a")), false)
    eq(Loot.searchable(Loot.words("a b")), true)
    eq(Loot.searchable(Loot.words("ab")), true)
    eq(Loot.searchable(Loot.words("É")), false)
end)

test("instanceBosses: the bosses, not the other lists, unless there is nothing else", function()
    local w = newWorld()
    local Loot, data = w.ns.Loot, w.atlas.ItemDB:Get("TestLoot")
    local names = {}
    for _, boss in ipairs(Loot.instanceBosses(data, "Deadmines")) do
        names[#names + 1] = boss.name
    end
    eq(table.concat(names, "|"), "Rhahk'Zor|Sneed|Empty boss", "the tier sets are another list")
    eq(#Loot.instanceBosses(data, "Stratholme"), 1)
    local lists = { Only = { items = { { ExtraList = true }, { ExtraList = true } } } }
    eq(#Loot.instanceBosses(lists, "Only"), 2, "an instance with only other lists reads them all")
    eq(#Loot.instanceBosses(lists, "Missing"), 0)
end)

test("mergeDifficulties: every difficulty any boss has, once, in order", function()
    local w = newWorld()
    local data = w.atlas.ItemDB:Get("TestLoot")
    local Loot = w.ns.Loot
    local diffs = Loot.mergeDifficulties(data, "Deadmines", Loot.instanceBosses(data, "Deadmines"))
    eq(#diffs, 2)
    eq(diffs[1].id, 1)
    eq(diffs[1].name, "NORMAL")
    eq(diffs[2].id, 2)
    eq(diffs[2].name, "Heroic!")
    eq(#Loot.mergeDifficulties(data, "Deadmines", {}), 0)
    -- the first boss has only the second difficulty: they still come in order
    local fake = {
        GetDifficultys = function()
            return { { name = "Normal" }, { name = "Heroic" } }
        end,
        Place = { items = { { [2] = { { 1, 1 } } }, { [1] = { { 1, 1 } } } } },
    }
    local merged = Loot.mergeDifficulties(fake, "Place", { { index = 1 }, { index = 2 } })
    eq(#merged, 2)
    eq(merged[1].id, 1)
    eq(merged[1].name, "Normal")
    eq(merged[2].name, "Heroic")
    eq(#Loot.mergeDifficulties(data, "Stratholme", Loot.bosses(data, "Stratholme")), 1)
end)

test("isSorted: only the ways that order the lines", function()
    local Loot = newWorld().ns.Loot
    eq(Loot.isSorted("level"), true)
    eq(Loot.isSorted("upgrade"), true)
    eq(Loot.isSorted("slot"), true)
    eq(Loot.isSorted("drop"), true)
    eq(Loot.isSorted("default"), false)
    eq(Loot.isSorted("nonsense"), false)
    eq(Loot.isSorted(nil), false)
end)

test("describe: where an item drops comes after the rest, before what the class cannot use", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    eq(Loot.describe({ id = 5203 }, {}, Game, "Sneed, The Deadmines"), "Cloth Gloves, Uncommon, Hands, Cloth, item level 17, requires level 12, from Sneed, The Deadmines")
    eq(Loot.describe({ id = 5203 }, {}, Game), "Cloth Gloves, Uncommon, Hands, Cloth, item level 17, requires level 12")
    local text = Loot.describe({ id = 5202, usable = false, note = "Quest" }, { classFilter = false }, Game, "Sneed")
    contains(text, "Quest, from Sneed, your class cannot use it")
    eq(Loot.describe({ id = 5203 }, {}, newWorld({ locale = "frFR" }).ns.Game, nil), Loot.describe({ id = 5203 }, {}, Game), "same without a place")
    local french = newWorld({ locale = "frFR" })
    contains(french.ns.Loot.describe({ id = 5203 }, {}, french.ns.Game, "Sneed"), "vient de Sneed")
end)

test("index: every item of the module with where it drops, once per boss, with the difficulties it is in", function()
    local w = newWorld()
    local index = buildIndex(w)
    eq(index.done, true)
    eq(recordList(index), FULL, "the hammer twice listed (positions 3 and 17) is one item")
    local byKey = {}
    for _, record in ipairs(index.records) do
        byKey[record.entry.id .. "@" .. record.boss] = record
    end
    eq(w.ns.Loot.where(byKey["8001@Rhahk'Zor"]), "Rhahk'Zor, The Deadmines, Heroic!", "only in the heroic table")
    eq(w.ns.Loot.where(byKey["5187@Rhahk'Zor"]), "Rhahk'Zor, The Deadmines, NORMAL", "not in all the boss's difficulties")
    eq(w.ns.Loot.where(byKey["5201@Sneed"]), "Sneed, The Deadmines", "a boss with one difficulty")
    eq(w.ns.Loot.where(byKey["7001@Baron"]), "Baron, Stratholme")
    eq(w.ns.Loot.where(byKey["5203@Hidden"]), "Hidden, Lost place")
    eq(byKey["5187@Rhahk'Zor"].instanceKey, "Deadmines")
    eq(byKey["5187@Rhahk'Zor"].bossIndex, 1)
    eq(byKey["6001@Tier sets"].bossIndex, 3, "the other lists are in the index too")
end)

test("index: read a few bosses at a time", function()
    local w = newWorld()
    local index = w.ns.Loot.index(w.atlas, "TestLoot", w.atlas.ItemDB:Get("TestLoot"), 1)
    eq(#index.records, 0, "nothing is read before the first step")
    local calls = 0
    local previous = 0
    local grew = 0
    repeat
        calls = calls + 1
        local done = index:step(w.ns.Game, 1)
        if #index.records > previous then
            grew = grew + 1
            previous = #index.records
        end
        if done then
            break
        end
    until calls > 50
    eq(calls, 7, "six bosses, then the step that sees the end")
    check(grew >= 4, "the records came in a few at a time (" .. grew .. ")")
    eq(recordList(index), FULL)
    eq(index:step(w.ns.Game, 1), true, "a complete index stays complete")
    eq(#index.records, 12)
end)

test("index: a list that is not loaded yet is asked for again, a few times", function()
    local w = newWorld()
    local real = w.atlas.ItemDB.GetItemTable
    local calls = 0
    w.atlas.ItemDB.GetItemTable = function(self, ...)
        calls = calls + 1
        if calls <= 8 then
            return "TestLate"
        end
        return real(self, ...)
    end
    local index = buildIndex(w)
    eq(index.done, true)
    eq(index.skipped, 0)
    eq(recordList(index), FULL, "everything is there in the end, and nothing twice")
    check(#w.loads > 0 and w.loads[1] == "TestLate", "the module was asked for")
end)

test("index: a list that never loads is left out after a few tries", function()
    local w = newWorld()
    w.atlas.ItemDB.GetItemTable = function()
        return "TestLate"
    end
    local index = buildIndex(w)
    eq(index.done, true)
    eq(index.skipped, 5, "every boss that has a table")
    eq(#index.records, 0)
end)

test("index: an error in a table is reported once and the rest is read", function()
    local w = newWorld()
    local real = w.atlas.ItemDB.GetItemTable
    w.atlas.ItemDB.GetItemTable = function(self, id, key, boss, ...)
        if key == "Deadmines" and boss == 2 then
            error("bad table")
        end
        return real(self, id, key, boss, ...)
    end
    local index = buildIndex(w)
    eq(index.done, true)
    eq(#w.errors, 1)
    contains(w.errors[1], "bad table")
    eq(recordList(index), "5187@Rhahk'Zor 5201@Rhahk'Zor 5202@Rhahk'Zor 5203@Hidden 5203@Rhahk'Zor 5302@Rhahk'Zor 6001@Tier sets 6002@Tier sets 7001@Baron 8001@Rhahk'Zor")
end)

test("index: item names are asked of the game a few at a time, the ones it has are skipped", function()
    local w = newWorld()
    local index = buildIndex(w)
    local asked = {}
    w.ns.Game.requestItem = function(id)
        asked[#asked + 1] = id
    end
    w.info = {}
    index:request(w.ns.Game, 5)
    eq(#asked, 5)
    index:request(w.ns.Game, 5)
    eq(#asked, 10)
    index:request(w.ns.Game, 5)
    eq(#asked, 12, "twelve items, asked once each")
    index:request(w.ns.Game, 5)
    eq(#asked, 12, "and not again")
    -- the ones the game has are not asked about
    w.info = infoTable()
    local second = buildIndex(w)
    asked = {}
    second:request(w.ns.Game, 100)
    eq(#asked, 0, "the game has the names")
end)

test("find: the items whose name holds every word, accents and case aside", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    w.info[9100] = { name = "Épée du Roi", quality = 4, level = 30, minLevel = 20, type = "Weapon", subType = "Swords", equipLoc = "INVTYPE_WEAPON", cached = true }
    local index = fakeIndex(5187, 5201, 5203, 9100)
    local function names(words)
        local out = {}
        for _, entry in ipairs(Loot.find(index, Loot.words(words), {}, Game).found) do
            out[#out + 1] = w.info[entry.id].name
        end
        return table.concat(out, "|")
    end
    eq(names("gloves"), "Cloth Gloves")
    eq(names("GLOVES"), "Cloth Gloves")
    eq(names("cloth glov"), "Cloth Gloves")
    eq(names("glov cloth"), "Cloth Gloves", "the words in any order")
    eq(names("cloth hammer"), "", "all the words")
    eq(names("o"), "Rhahk'Zor's Hammer|Emberstone Cloak|Cloth Gloves|Épée du Roi", "any name with an o")
    eq(names("epee"), "Épée du Roi")
    eq(names("EPEE roi"), "Épée du Roi")
    eq(names("zor's"), "Rhahk'Zor's Hammer")
    eq(names("xyz"), "")
    local result = Loot.find(index, Loot.words("gloves"), {}, Game)
    eq(result.recordOf[result.found[1]].boss, "Boss3", "each found item knows its record")
end)

test("find: the filters hide what they hide, and say how many", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local index = fakeIndex(5201, 5202, 5203)
    local words = Loot.words("l")
    local all = Loot.find(index, words, {}, Game)
    eq(#all.found, 3, "Emberstone Cloak, Plate Gauntlets, Cloth Gloves")
    eq(all.hidden, 0)
    local classed = Loot.find(index, words, { classFilter = true }, Game)
    eq(#classed.found, 2)
    eq(classed.hidden, 1, "the gauntlets")
    local slotted = Loot.find(index, words, { classFilter = true, slot = "hands" }, Game)
    eq(#slotted.found, 1)
    eq(slotted.hidden, 2, "the gauntlets by the class, the cloak by the slot")
    eq(#slotted.passing, 2, "what the other filters keep, for the slot choices")
    eq(values(Loot.slotChoices(slotted.passing, nil, Game)), "all cloak hands")
    w.player.level = 10
    local leveled = Loot.find(index, words, { levelFilter = true }, Game)
    eq(#leveled.found, 0, "everything asks for level 12 or more")
    eq(leveled.hidden, 3)
end)

test("find: names the game has not sent are counted, the ones it says it does not know are not", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local index = fakeIndex(5203, 5187, 6001)
    w.info[5187], w.info[6001] = nil, nil
    local result = Loot.find(index, { "gloves" }, {}, Game)
    eq(#result.found, 1)
    eq(result.unknown, 2)
    w.failedItems = { [6001] = true }
    eq(Loot.find(index, { "gloves" }, {}, Game).unknown, 1, "the server does not know 6001")
    w.info[5187] = { name = "Rhahk'Zor's Hammer", cached = true }
    eq(Loot.find(index, { "hammer" }, {}, Game).unknown, 0)
end)

test("find: it stops after a number of matches and says there are more", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local index = fakeIndex(5203, 5203, 5203, 5203, 5203)
    check(Loot.SEARCH_SCAN >= 100, "a real limit")
    local before = Loot.SEARCH_SCAN
    Loot.SEARCH_SCAN = 3
    local result = Loot.find(index, { "gloves" }, {}, Game)
    Loot.SEARCH_SCAN = before
    eq(#result.found, 3)
    eq(result.more, true)
    result = Loot.find(index, { "gloves" }, {}, Game)
    eq(#result.found, 5)
    eq(result.more, false)
end)

test("find: a name is folded once, not at every rebuild of the screen", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local index = fakeIndex(5203, 5187)
    local asked = 0
    local itemName = Game.itemName
    Game.itemName = function(id)
        asked = asked + 1
        return itemName(id)
    end
    Loot.find(index, { "gloves" }, {}, Game)
    eq(asked, 2)
    Loot.find(index, { "gloves" }, {}, Game)
    Loot.find(index, { "hammer" }, {}, Game)
    eq(asked, 2, "the names are kept")
end)

test("Game: an item's name comes only when the game has it, and a failed item is remembered", function()
    newWorld()
    local Game = freshGame()
    local infoCalls = 0
    withGlobals({
        C_Item = {
            IsItemDataCachedByID = function(id)
                return id ~= 2
            end,
            GetItemInfo = function(id)
                infoCalls = infoCalls + 1
                if id == 1 then
                    return "Sword"
                elseif id == 3 then
                    return ""
                end
                return nil
            end,
        },
    }, function()
        eq(Game.itemName(1), "Sword")
        eq(Game.itemName(2), nil, "not cached: nothing is asked")
        eq(infoCalls, 1)
        eq(Game.itemName(3), nil, "an empty name is no name")
        eq(Game.itemName(4), nil)
    end)
    withGlobals({
        C_Item = {
            IsItemDataCachedByID = function()
                error("boom")
            end,
            GetItemInfo = function()
                return "Axe"
            end,
        },
    }, function()
        eq(Game.itemName(1), "Axe", "a failing check falls back on the name")
    end)
    withGlobals({
        GetItemInfo = function()
            return "Plain"
        end,
    }, function()
        eq(Game.itemName(1), "Plain", "a client without C_Item")
    end)
    eq(Game.itemName(1), nil, "no function at all")
    eq(Game.itemFailed(7), false)
    Game.itemReceived(7, true)
    eq(Game.itemFailed(7), false, "a success is no failure")
    Game.itemReceived(7, nil)
    eq(Game.itemFailed(7), false)
    Game.itemReceived(nil, false)
    Game.itemReceived(7, false)
    eq(Game.itemFailed(7), true)
    eq(Game.itemFailed(8), false)
end)

test("Main: the server saying it does not know an item is passed on", function()
    local w = mainWorld()
    local events = w.eventFrames[#w.eventFrames]
    check(events.events.GET_ITEM_INFO_RECEIVED)
    local received
    w.ns.Game.itemReceived = function(id, success)
        received = { id, success }
    end
    events.onEvent(nil, "GET_ITEM_INFO_RECEIVED", 5203, false)
    eq(received[1], 5203)
    eq(received[2], false)
    eq(w.ns.frameHooked, nil, "that event does not look for AtlasLoot's window")
end)

-- ----------------------------------------------------- a whole instance

-- "group: name" for each line of the screen's list.
local function groupedLines(w)
    local out = {}
    for _, row in ipairs(w.ns.Screen.model(w.atlas).rows) do
        local label = type(row.label) == "function" and row.label() or row.label
        out[#out + 1] = (row.group and row.group.label or "-") .. ": " .. label:match("^[^,]*")
    end
    return out
end

local function deadminesScreen(config)
    local w = screenWorld(config)
    enter(w, "Test Loot")
    enter(w, "The Deadmines")
    return w
end

test("the bosses of an instance with several bosses have a line for all of them together, the player lands on the first boss", function()
    local w = deadminesScreen()
    local text = readings(w.d)
    contains(text, "All bosses together")
    contains(w.d.say(), "Rhahk'Zor", "the special line is not where the player lands")
    w.d.up()
    contains(w.d.say(), "All bosses together", "but it is one arrow up")
end)

test("an instance with one boss has no line for all of them", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    enter(w, "Stratholme")
    eq(readings(w.d):find("All bosses together", 1, true), nil)
    contains(w.d.say(), "Baron")
end)

test("all the bosses together: grouped by boss, a table's own header kept after the boss's name", function()
    local w = deadminesScreen()
    enter(w, "All bosses together")
    eq(w.ns.Screen.state.level, "items")
    eq(w.ns.Screen.state.whole, true)
    eq(table.concat(groupedLines(w), "\n"), table.concat({
        "Rhahk'Zor: Rhahk'Zor's Hammer",
        "Rhahk'Zor: Emberstone Cloak",
        "Rhahk'Zor, Forever: Cloth Gloves",
        "Rhahk'Zor, Forever: Alliance Helm",
        "Rhahk'Zor, Forever: Cloth Gloves",
        "Sneed: Emberstone Cloak",
        "Sneed: Cloth Gloves",
    }, "\n"), "the empty boss and the tier sets are not there")
    local model = w.ns.Screen.model(w.atlas)
    eq(model.title, "All bosses together, NORMAL")
    contains(readings(w.d), "Items shown: 7, Hidden by the filters: 2")
    contains(w.d.say(), "Rhahk'Zor's Hammer", "the player lands on the first item")
end)

test("all the bosses together: the filters apply to every boss", function()
    local w = deadminesScreen()
    enter(w, "All bosses together")
    w.d.focus("Only what my class can use")
    w.d.enter()
    contains(readings(w.d), "Items shown: 9")
    contains(readings(w.d), "Plate Gauntlets")
    w.d.focus("Only what my class can use")
    w.d.enter()
    choose(w, "Slot", "Back")
    eq(table.concat(groupedLines(w), "\n"), "Rhahk'Zor: Emberstone Cloak\nSneed: Emberstone Cloak", "the cloak of each boss, under its boss")
    contains(readings(w.d), "Slot: Back")
end)

test("all the bosses together: the difficulty is any boss's, each boss shows the nearest it has", function()
    local w = deadminesScreen()
    enter(w, "All bosses together")
    contains(readings(w.d), "Difficulty: NORMAL")
    w.d.focus("Difficulty:")
    w.d.enter()
    contains(readings(w.d), "Difficulty: Heroic!")
    eq(table.concat(groupedLines(w), "\n"), "Rhahk'Zor: Heroic Sash\nSneed: Emberstone Cloak\nSneed: Cloth Gloves", "Sneed has no heroic table: its normal one")
    eq(w.ns.Screen.model(w.atlas).title, "All bosses together, Heroic!")
end)

test("all the bosses together, sorted: one list, and each item says its boss", function()
    local w = deadminesScreen()
    enter(w, "All bosses together")
    choose(w, "Sort", "Item level, highest first")
    local lines = groupedLines(w)
    eq(table.concat(lines, "\n"), table.concat({
        "-: Alliance Helm",
        "-: Emberstone Cloak",
        "-: Emberstone Cloak",
        "-: Rhahk'Zor's Hammer",
        "-: Cloth Gloves",
        "-: Cloth Gloves",
        "-: Cloth Gloves",
    }, "\n"))
    local rows = w.ns.Screen.model(w.atlas).rows
    contains(rows[2].label(), "from Rhahk'Zor")
    contains(rows[3].label(), "from Sneed")
    contains(rows[1].label(), "from Rhahk'Zor")
    choose(w, "Sort", "AtlasLoot's order")
    eq(w.ns.Screen.model(w.atlas).rows[1].label():find("from ", 1, true), nil, "grouped again, no need to say it")
end)

test("all the bosses together: a list that is not loaded yet is said, and comes when it is", function()
    local w = deadminesScreen()
    enter(w, "All bosses together")
    local real = w.atlas.ItemDB.GetItemTable
    w.atlas.ItemDB.GetItemTable = function(self, id, key, boss, ...)
        if boss == 2 then
            return "TestLate"
        end
        return real(self, id, key, boss, ...)
    end
    w.ns.Screen.state.cache = {}
    local text = readings(w.d)
    contains(text, "Still loading: 1")
    contains(text, "Items shown: 5")
    w.atlas.ItemDB.GetItemTable = real
    text = readings(w.d)
    eq(text:find("Still loading", 1, true), nil)
    contains(text, "Items shown: 7")
end)

test("all the bosses together: nothing yet but lists loading says loading", function()
    local w = deadminesScreen()
    w.atlas.ItemDB.GetItemTable = function()
        return "TestLate"
    end
    enter(w, "All bosses together")
    local text = readings(w.d)
    contains(text, "Loading.")
    contains(text, "Still loading: 2")
end)

test("all the bosses together: Back goes to the bosses, on the line for all of them", function()
    local w = deadminesScreen()
    enter(w, "All bosses together")
    contains(w.ns.Screen.where(), "Test Loot, The Deadmines, All bosses together")
    contains(readings(w.d), "You are in: Test Loot, The Deadmines, All bosses together")
    w.d.focus("Back")
    w.d.enter()
    eq(w.ns.Screen.state.level, "bosses")
    contains(w.d.say(), "All bosses together")
    enter(w, "Sneed")
    eq(w.ns.Screen.state.whole, false, "choosing a boss leaves the whole view")
    contains(w.ns.Screen.where(), "Test Loot, The Deadmines, Sneed")
    w.d.focus("Back")
    w.d.enter()
    contains(w.d.say(), "Sneed", "back on the boss, not on the line for all")
end)

test("all the bosses together asks AtlasLoot to bring in the lists that live elsewhere, for every boss", function()
    local w = deadminesScreen()
    local asked = {}
    local real = w.atlas.ItemDB.CheckForLink
    w.atlas.ItemDB.CheckForLink = function(self, id, key, boss, load)
        if load then
            asked[#asked + 1] = boss
        end
        return real(self, id, key, boss, load)
    end
    enter(w, "All bosses together")
    table.sort(asked)
    eq(table.concat(asked, ","), "1,2,4", "the three bosses, not the tier sets")
end)

-- ------------------------------------------------------------- search

local function searchScreen(config)
    local w = screenWorld(config)
    w.ns.Screen.INDEX_BOSSES = 1000
    w.ns.Screen.REQUESTS = 1000
    enter(w, "Test Loot")
    enter(w, "Search by name")
    return w
end

local function typeQuery(w, text)
    w.d.focus("Search by name")
    local before = #w.env.entries
    w.d.enter()
    check(#w.env.entries == before + 1, "the box opened the typed entry")
    w.env.entries[#w.env.entries].onCommit(text)
end

test("a category has a line to search by name, the player lands on the first dungeon", function()
    local w = screenWorld()
    enter(w, "Test Loot")
    contains(readings(w.d), "Search by name")
    contains(w.d.say(), "The Deadmines")
    w.d.up()
    contains(w.d.say(), "Search by name")
end)

test("the search level: a box, a hint, the filters, and where the player is", function()
    local w = searchScreen()
    eq(w.ns.Screen.state.level, "search")
    local text = readings(w.d)
    contains(text, "Search by name, EditBox, nothing typed yet")
    contains(text, "Type at least two letters to search.")
    contains(text, "Matches shown: 0")
    contains(text, "Only what my class can use")
    contains(text, "Slot")
    contains(text, "Sort")
    eq(text:find("Difficulty", 1, true), nil, "a search reads every difficulty")
    contains(w.d.say(), "Search by name", "the player lands on the box")
    contains(readings(w.d), "You are in: Test Loot, Search by name")
end)

test("typing a name lists the items with where they drop, one per boss", function()
    local w = searchScreen()
    typeQuery(w, "gloves")
    eq(w.ns.Screen.state.query, "gloves")
    local text = readings(w.d)
    contains(text, "Search by name, EditBox, gloves")
    contains(text, "Matches shown: 3")
    contains(text, "Cloth Gloves, Uncommon, Hands, Cloth, item level 17, requires level 12, from Rhahk'Zor, The Deadmines, NORMAL")
    contains(text, "from Sneed, The Deadmines")
    contains(text, "from Hidden, Lost place")
    eq(text:find("Plate Gauntlets", 1, true), nil)
    contains(w.env.spoken[#w.env.spoken], "gloves", "the box says what was typed")
end)

test("a search is accent and case blind, and needs every word", function()
    local w = searchScreen()
    w.info[9100] = { name = "Épée du Roi", quality = 4, level = 30, minLevel = 20, type = "Weapon", subType = "Swords", equipLoc = "INVTYPE_WEAPON", cached = true }
    typeQuery(w, "HELM set")
    local text = readings(w.d)
    contains(text, "Matches shown: 1")
    contains(text, "Set Helm")
    eq(text:find("Alliance Helm", 1, true), nil)
end)

test("a search that finds nothing says so, and the filters' hidden count is said", function()
    local w = searchScreen()
    typeQuery(w, "plate")
    local text = readings(w.d)
    contains(text, "No match.")
    contains(text, "Matches shown: 0, Hidden by the filters: 1")
    w.d.focus("Only what my class can use")
    w.d.enter()
    text = readings(w.d)
    contains(text, "Plate Gauntlets")
    contains(text, "Matches shown: 1")
    typeQuery(w, "qqq")
    contains(readings(w.d), "No match.")
    typeQuery(w, "g")
    contains(readings(w.d), "Type at least two letters to search.")
end)

test("the index is read a few bosses at a time, and the summary says so until it is done", function()
    local w = screenWorld()
    local Screen = w.ns.Screen
    Screen.INDEX_BOSSES = 1
    Screen.REQUESTS = 1000
    Screen.state.level, Screen.state.module, Screen.state.moduleName, Screen.state.query = "search", "TestLoot", "Test Loot", "gloves"
    local first = Screen.model(w.atlas)
    eq(first.reading, true)
    contains(Screen.summary(first), "Still reading the lists")
    local calls, model = 1, first
    while model.reading and calls < 30 do
        model = Screen.model(w.atlas)
        calls = calls + 1
    end
    eq(model.reading, false)
    eq(calls, 7)
    eq(model.shown, 3)
    eq(Screen.summary(model):find("Still reading", 1, true), nil)
    local same = Screen.state.index
    Screen.model(w.atlas)
    eq(Screen.state.index, same, "the index is kept")
end)

test("item names the game has not sent are asked a few at a time, and counted", function()
    local w = screenWorld()
    local Screen = w.ns.Screen
    Screen.INDEX_BOSSES = 1000
    Screen.REQUESTS = 5
    Screen.state.level, Screen.state.module, Screen.state.moduleName, Screen.state.query = "search", "TestLoot", "Test Loot", "gloves"
    w.requested = {}
    local function asked()
        local total = 0
        for _, count in pairs(w.requested) do
            total = total + count
        end
        return total
    end
    local known = w.info
    w.info = {}
    local model = Screen.model(w.atlas)
    eq(asked(), 5)
    eq(model.unknown, 12)
    contains(Screen.summary(model), "Item names still arriving: 12")
    eq(model.rows[2].label, "Loading.", "nothing is found yet, and it is not 'no match'")
    Screen.model(w.atlas)
    eq(asked(), 10)
    w.info = known
    model = Screen.model(w.atlas)
    eq(model.unknown, 0)
    eq(model.shown, 3)
    eq(Screen.summary(model):find("arriving", 1, true), nil)
    w.info = {}
    w.failedItems = {}
    for id = 1, 9999 do
        w.failedItems[id] = true
    end
    for _, entry in ipairs(Screen.state.index.records) do
        entry.entry.folded = nil
    end
    model = Screen.model(w.atlas)
    eq(model.unknown, 0, "the server knows none of them: no waiting")
    eq(model.rows[2].label, "No match.")
end)

test("more matches than lines are said, and the best ones are the ones shown when the list is sorted", function()
    local w = searchScreen()
    w.ns.Screen.RESULTS = 2
    typeQuery(w, "e")
    contains(readings(w.d), "Matches shown: 0")
    typeQuery(w, "cloth")
    local text = readings(w.d)
    contains(text, "Matches shown: 2, more matches exist, refine the search")
    local rows = w.ns.Screen.model(w.atlas).rows
    eq(#rows, 3, "the box and two results")
end)

test("the slot and the sort work in the search", function()
    local w = searchScreen()
    typeQuery(w, "set")
    local options = choose(w, "Slot", "Head")
    check(options ~= nil)
    local text = readings(w.d)
    contains(text, "Set Helm")
    eq(text:find("Set Ring", 1, true), nil)
    contains(text, "Matches shown: 1, Hidden by the filters: 1, Slot: Head")
    choose(w, "Slot", "All slots")
    typeQuery(w, "helm")
    local rows = w.ns.Screen.model(w.atlas).rows
    contains(rows[2].label(), "Alliance Helm")
    contains(rows[3].label(), "Set Helm")
    choose(w, "Sort", "Item level, highest first")
    rows = w.ns.Screen.model(w.atlas).rows
    contains(rows[2].label(), "Set Helm")
    contains(rows[3].label(), "Alliance Helm")
end)

test("the slots offered in a search are the ones the matches have", function()
    local w = searchScreen()
    typeQuery(w, "set")
    w.d.focus("Slot")
    w.d.enter()
    local options = w.env.driver(w.env.pushed[#w.env.pushed].render)
    eq(optionList(options), "All slots | Head | Finger")
end)

test("Enter on a result reads its tooltip", function()
    local w = searchScreen()
    typeQuery(w, "hammer")
    w.d.focus("Rhahk'Zor's Hammer")
    w.d.enter()
    eq(w.tooltips, 1)
    w.noTooltip = true
    w.d.enter()
    contains(w.spoken[#w.spoken], "from Rhahk'Zor, The Deadmines, NORMAL", "without a tooltip, the line is read")
end)

test("the upgrades filter applies to the search", function()
    local w = searchScreen()
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 99 } }
    w.worn.INVTYPE_HAND = { { empty = true } }
    typeQuery(w, "cl")
    contains(readings(w.d), "Matches shown: 5", "the cloak twice, the gloves three times")
    w.d.focus("Only upgrades")
    w.d.enter()
    local text = readings(w.d)
    eq(text:find("Emberstone Cloak", 1, true), nil, "no upgrade over item level 99")
    contains(text, "Cloth Gloves")
    contains(text, "Matches shown: 3, Hidden by the filters: 2")
end)

test("Back from the search goes to the category, on the search line, and the search is kept", function()
    local w = searchScreen()
    typeQuery(w, "gloves")
    w.d.focus("Back")
    w.d.enter()
    eq(w.ns.Screen.state.level, "instances")
    contains(w.d.say(), "Search by name")
    enter(w, "Search by name")
    contains(readings(w.d), "Matches shown: 3")
end)

test("Escape in the search goes up one level like everywhere", function()
    local w = searchScreen()
    w.ns.Screen.config().onRequestClose()
    eq(w.ns.Screen.state.level, "instances")
    eq(w.isOpen, false, "the screen is not closed, it went up a level")
end)

test("another game version searches its own items", function()
    local w = screenWorld({ forever = true })
    w.ns.Screen.INDEX_BOSSES = 1000
    enter(w, "Test Loot")
    enter(w, "Search by name")
    typeQuery(w, "gloves")
    local first = w.ns.Screen.state.index
    eq(first.version, 1)
    contains(readings(w.d), "Matches shown: 3")
    w.ns.Screen.back()
    w.d.focus("Game version")
    w.d.enter()
    enter(w, "Search by name")
    local second = w.ns.Screen.state.index
    check(second ~= first, "a new index for the other version")
    eq(second.version, 4)
    local text = readings(w.d)
    contains(text, "Matches shown: 2", "the Forever mine, and the place that is for every version")
    contains(text, "from Forever boss, Forever mine")
    contains(text, "from Hidden, Lost place")
    eq(text:find("The Deadmines", 1, true), nil, "the Classic dungeons are not in the Forever index")
end)

test("a module that cannot be read says why in the search", function()
    local w = screenWorld()
    local Screen = w.ns.Screen
    Screen.state.level, Screen.state.module, Screen.state.moduleName = "search", "TestCombat", "Combat loot"
    local model = Screen.model(w.atlas)
    eq(model.rows[2].label, "That module loads after combat.")
    contains(readings(w.d), "Item type, Dropdown, All types", "the filters are there, with their choices, even then")
    contains(readings(w.d), "Slot, Dropdown, All slots")
end)

test("French: the new lines speak French", function()
    local w = screenWorld({ locale = "frFR" })
    w.ns.Screen.INDEX_BOSSES = 1000
    enter(w, "Test Loot")
    contains(readings(w.d), "Rechercher par nom")
    enter(w, "The Deadmines")
    contains(readings(w.d), "Tous les boss ensemble")
    enter(w, "Tous les boss ensemble")
    contains(readings(w.d), "Vous êtes dans : Test Loot, The Deadmines, Tous les boss ensemble")
    w.ns.Screen.back()
    w.ns.Screen.back()
    enter(w, "Rechercher par nom")
    local text = readings(w.d)
    contains(text, "rien de tapé")
    contains(text, "Tapez au moins deux lettres pour chercher.")
    w.d.focus("Rechercher par nom")
    w.d.enter()
    w.env.entries[#w.env.entries].onCommit("gloves")
    text = readings(w.d)
    contains(text, "Résultats affichés : 3")
    contains(text, "vient de Sneed, The Deadmines")
    w.ns.Screen.RESULTS = 1
    contains(readings(w.d), "d'autres résultats existent, précisez la recherche")
end)

test("German: the new lines speak German", function()
    local w = screenWorld({ locale = "deDE" })
    w.ns.Screen.INDEX_BOSSES = 1000
    enter(w, "Test Loot")
    contains(readings(w.d), "Nach Namen suchen")
    enter(w, "Nach Namen suchen")
    w.d.focus("Nach Namen suchen")
    w.d.enter()
    w.env.entries[#w.env.entries].onCommit("gloves")
    local text = readings(w.d)
    contains(text, "Angezeigte Treffer: 3")
    contains(text, "stammt von Sneed, The Deadmines")
end)

-- ------------------------------ armor by level, and the kinds of items

test("armorWearable: the armor each class wears, and from which level", function()
    local Game = freshGame()
    local cases = {
        -- class, level, armor sub class (1 cloth, 2 leather, 3 mail, 4 plate), expected
        { "SHAMAN", 30, 1, true }, { "SHAMAN", 30, 2, true }, { "SHAMAN", 30, 3, false }, { "SHAMAN", 39, 3, false },
        { "SHAMAN", 40, 3, true }, { "SHAMAN", 60, 4, false },
        { "HUNTER", 1, 2, true }, { "HUNTER", 39, 3, false }, { "HUNTER", 40, 3, true }, { "HUNTER", 70, 4, false },
        { "WARRIOR", 1, 3, true }, { "WARRIOR", 39, 4, false }, { "WARRIOR", 40, 4, true }, { "WARRIOR", 1, 1, true },
        { "PALADIN", 1, 2, true }, { "PALADIN", 39, 4, false }, { "PALADIN", 40, 4, true }, { "PALADIN", 20, 3, true },
        { "ROGUE", 1, 1, true }, { "ROGUE", 1, 2, true }, { "ROGUE", 60, 3, false }, { "ROGUE", 60, 4, false },
        { "DRUID", 10, 2, true }, { "DRUID", 60, 3, false }, { "DRUID", 1, 1, true },
        { "MAGE", 1, 1, true }, { "MAGE", 60, 2, false },
        { "PRIEST", 1, 1, true }, { "PRIEST", 60, 2, false },
        { "WARLOCK", 1, 1, true }, { "WARLOCK", 60, 3, false },
        { "DEATHKNIGHT", 1, 4, true }, { "DEATHKNIGHT", 1, 3, true },
        { "SHAMAN", 40, 6, false, "not an armor type of the table" },
    }
    for _, case in ipairs(cases) do
        eq(Game.armorWearable(case[1], case[2], case[3]), case[4], case[1] .. " " .. case[2] .. " " .. case[3])
    end
    eq(Game.armorWearable("MONK", 40, 2), nil, "a class this addon has no rule for")
    eq(Game.armorWearable("SHAMAN", nil, 2), nil, "no level")
    eq(Game.armorWearable("SHAMAN", "40", 3), nil, "a level that is not a number")
    eq(Game.armorWearable(nil, 40, 3), nil)
end)

-- A world where the real Game asks a stand-in AtlasLoot and a stand-in game about armor.
-- facts: id -> { classID, subClassID }; atlasSays: id -> what AtlasLoot's own class filter answers
local function armorWorld(class, level, facts, atlasSays, extra)
    local w = newWorld()
    local Game = freshGame()
    extra = extra or {}
    w.atlas.Data.ClassFilter = {
        ClassCanUseItem = function(requestedClass, id)
            eq(requestedClass, class)
            local answer = atlasSays[id]
            if answer == nil then
                return true
            end
            return answer
        end,
    }
    w.atlas.Data.Requirements = extra.requirements
    w.atlas.db = extra.db
    local globals = {
        UnitClassBase = function()
            return class
        end,
        UnitLevel = function()
            return level
        end,
        GetItemInfoInstant = function(id)
            local fact = facts[id]
            if fact == nil then
                return nil
            end
            return id, "Type", "Sub", "", 0, fact[1], fact[2]
        end,
        GetItemStats = extra.stats,
    }
    return w, Game, globals
end

local ARMOR_FACTS = {
    [1001] = { 4, 2 }, -- leather chest
    [1002] = { 4, 3 }, -- mail chest
    [1003] = { 4, 1 }, -- cloth robe
    [1004] = { 4, 4 }, -- plate chest
    [1005] = { 2, 7 }, -- a sword
    [1006] = { 4, 6 }, -- a shield
    [1007] = { 4, 0 }, -- a ring
}

test("canUse: a shaman below level 40 wears leather and cloth, not the mail AtlasLoot lists for him", function()
    -- AtlasLoot knows only the mail a shaman ends with
    local says = { [1001] = false, [1002] = true, [1003] = false, [1004] = false, [1005] = true, [1006] = true, [1007] = true }
    local _, Game, globals = armorWorld("SHAMAN", 30, ARMOR_FACTS, says)
    withGlobals(globals, function()
        eq(Game.canUse(1001), true, "leather")
        eq(Game.canUse(1003), true, "cloth")
        eq(Game.canUse(1002), false, "mail is for level 40")
        eq(Game.canUse(1004), false, "plate never")
        eq(Game.canUse(1005), true, "a weapon: AtlasLoot's answer")
        eq(Game.canUse(1006), true, "a shield: AtlasLoot's answer")
        eq(Game.canUse(1007), true, "a ring: AtlasLoot's answer")
    end)
end)

test("canUse: at level 40 the shaman wears mail as well, and at 39 not yet", function()
    local says = { [1001] = false, [1002] = true, [1003] = false, [1004] = false }
    local _, Game, globals = armorWorld("SHAMAN", 39, ARMOR_FACTS, says)
    withGlobals(globals, function()
        eq(Game.canUse(1002), false)
    end)
    _, Game, globals = armorWorld("SHAMAN", 40, ARMOR_FACTS, says)
    withGlobals(globals, function()
        eq(Game.canUse(1002), true)
        eq(Game.canUse(1001), true)
        eq(Game.canUse(1003), true)
        eq(Game.canUse(1004), false)
    end)
end)

test("canUse: a warrior wears mail before level 40 and plate after it; a mage only cloth", function()
    local plateOnly = { [1001] = false, [1002] = false, [1003] = false, [1004] = true }
    local _, Game, globals = armorWorld("WARRIOR", 25, ARMOR_FACTS, plateOnly)
    withGlobals(globals, function()
        eq(Game.canUse(1004), false, "plate at 25")
        eq(Game.canUse(1002), true, "mail at 25")
        eq(Game.canUse(1001), true)
        eq(Game.canUse(1003), true)
    end)
    _, Game, globals = armorWorld("WARRIOR", 40, ARMOR_FACTS, plateOnly)
    withGlobals(globals, function()
        eq(Game.canUse(1004), true)
    end)
    local clothOnly = { [1001] = false, [1002] = false, [1003] = true, [1004] = false }
    _, Game, globals = armorWorld("MAGE", 60, ARMOR_FACTS, clothOnly)
    withGlobals(globals, function()
        eq(Game.canUse(1003), true)
        eq(Game.canUse(1001), false)
        eq(Game.canUse(1002), false)
        eq(Game.canUse(1004), false)
    end)
end)

test("canUse: a class this addon has no rule for, or a level it does not know, keeps AtlasLoot's answer", function()
    local says = { [1001] = false, [1002] = true }
    local _, Game, globals = armorWorld("MONK", 30, ARMOR_FACTS, says)
    withGlobals(globals, function()
        eq(Game.canUse(1001), false)
        eq(Game.canUse(1002), true)
    end)
    _, Game, globals = armorWorld("SHAMAN", nil, ARMOR_FACTS, says)
    withGlobals(globals, function()
        eq(Game.canUse(1001), false, "no level, AtlasLoot's answer")
        eq(Game.canUse(1002), true)
    end)
end)

test("canUse: a weapon whose sub class number looks like an armor type is still a weapon", function()
    -- a gun is weapon sub class 3, like mail is armor sub class 3
    local facts = { [3001] = { 2, 3 }, [3002] = { 2, 1 } }
    local _, Game, globals = armorWorld("HUNTER", 30, facts, { [3001] = true, [3002] = true })
    withGlobals(globals, function()
        eq(Game.canUse(3001), true, "the gun, at level 30 when mail is not worn yet")
        eq(Game.canUse(3002), true)
    end)
end)

test("canUse: a stat key that is not text does not break the check", function()
    local says = { [1001] = false }
    local _, Game, globals = armorWorld("SHAMAN", 30, ARMOR_FACTS, says, {
        db = { ClassFilter = { SHAMAN = { ITEM_MOD_STRENGTH_SHORT = false } } },
        stats = function()
            return { [1] = 5, ITEM_MOD_STAMINA = 3 }
        end,
    })
    withGlobals(globals, function()
        eq(Game.canUse(1001), true)
    end)
end)

test("canUse: an item the game says nothing about keeps AtlasLoot's answer", function()
    local says = { [2000] = false }
    local _, Game, globals = armorWorld("SHAMAN", 30, ARMOR_FACTS, says)
    withGlobals(globals, function()
        eq(Game.canUse(2000), false)
        eq(Game.canUse(2001), true)
    end)
end)

test("canUse: the lower armor type still obeys the class written on the item and the stats the class does not want", function()
    local says = { [1001] = false, [1003] = false }
    local statsOf = {
        [1001] = { ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_STAMINA_SHORT = 3 },
        [1003] = { ITEM_MOD_STAMINA_SHORT = 3 },
    }
    local restricted = {}
    local _, Game, globals = armorWorld("SHAMAN", 30, ARMOR_FACTS, says, {
        requirements = {
            ClassCanUseItem = function(class, id)
                eq(class, "SHAMAN")
                return not restricted[id]
            end,
        },
        db = { ClassFilter = { SHAMAN = { ITEM_MOD_INTELLECT_SHORT = false } } },
        stats = function(link)
            return statsOf[tonumber(link:match("item:(%d+)"))]
        end,
    })
    withGlobals(globals, function()
        eq(Game.canUse(1001), false, "intellect, which the class does not want")
        eq(Game.canUse(1003), true)
        restricted[1003] = true
        eq(Game.canUse(1003), false, "an item for another class")
    end)
end)

test("canUse: the stats AtlasLoot knows under another spelling are matched, and a missing option or API hides nothing", function()
    local says = { [1001] = false }
    local statsOf = { [1001] = { ITEM_MOD_SPELL_DAMAGE = 4 } }
    local build = function(settings, stats)
        return armorWorld("SHAMAN", 30, ARMOR_FACTS, says, {
            db = settings,
            stats = stats,
        })
    end
    local stats = function(link)
        return statsOf[tonumber(link:match("item:(%d+)"))]
    end
    local _, Game, globals = build({ ClassFilter = { SHAMAN = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = false } } }, stats)
    withGlobals(globals, function()
        eq(Game.canUse(1001), false, "SPELL_DAMAGE is SPELL_DAMAGE_DONE_SHORT in the options")
    end)
    statsOf[1001] = { ITEM_MOD_SPELL_HEALING = 4 }
    _, Game, globals = build({ ClassFilter = { SHAMAN = { ITEM_MOD_SPELL_HEALING_DONE_SHORT = false } } }, stats)
    withGlobals(globals, function()
        eq(Game.canUse(1001), false, "SPELL_HEALING too")
    end)
    statsOf[1001] = { ITEM_MOD_STRENGTH = 4 }
    _, Game, globals = build({ ClassFilter = { SHAMAN = { ITEM_MOD_STRENGTH_SHORT = false } } }, stats)
    withGlobals(globals, function()
        eq(Game.canUse(1001), false, "the other stats get _SHORT")
    end)
    _, Game, globals = build({ ClassFilter = { SHAMAN = { ITEM_MOD_STRENGTH = false } } }, stats)
    withGlobals(globals, function()
        eq(Game.canUse(1001), false, "an option written without _SHORT")
    end)
    _, Game, globals = build({ ClassFilter = { SHAMAN = { ITEM_MOD_STAMINA_SHORT = false } } }, stats)
    withGlobals(globals, function()
        eq(Game.canUse(1001), true, "another stat is off, not this one")
    end)
    _, Game, globals = build(nil, stats)
    withGlobals(globals, function()
        eq(Game.canUse(1001), true, "no options")
    end)
    _, Game, globals = build({ ClassFilter = {} }, stats)
    withGlobals(globals, function()
        eq(Game.canUse(1001), true, "no options for the class")
    end)
    _, Game, globals = build({ ClassFilter = { SHAMAN = { ITEM_MOD_STRENGTH_SHORT = false } } }, nil)
    withGlobals(globals, function()
        eq(Game.canUse(1001), true, "no GetItemStats")
    end)
    statsOf[1001] = { ITEM_MOD_STRENGTH = 4 }
    _, Game, globals = build({ ClassFilter = { SHAMAN = { ITEM_MOD_STRENGTH_SHORT = false } } }, function()
        error("boom")
    end)
    withGlobals(globals, function()
        eq(Game.canUse(1001), true, "GetItemStats failing")
    end)
    _, Game, globals = build({ ClassFilter = { SHAMAN = { ITEM_MOD_STRENGTH_SHORT = false } } }, function()
        return "not a table"
    end)
    withGlobals(globals, function()
        eq(Game.canUse(1001), true, "GetItemStats answering something else")
    end)
end)

test("canUse: AtlasLoot failing keeps the item, and a failing Requirements call hides nothing", function()
    local w, Game, globals = armorWorld("SHAMAN", 30, ARMOR_FACTS, {}, {
        requirements = {
            ClassCanUseItem = function()
                error("boom")
            end,
        },
    })
    w.atlas.Data.ClassFilter.ClassCanUseItem = function()
        error("AtlasLoot failed")
    end
    withGlobals(globals, function()
        eq(Game.canUse(1001), true)
        eq(Game.canUse(1002), false, "the level still decides the armor")
    end)
    w.atlas.Data.ClassFilter.ClassCanUseItem = function()
        return false
    end
    withGlobals(globals, function()
        eq(Game.canUse(1001), true, "a Requirements that fails says nothing against the item")
    end)
end)

test("Game: an item's type and sub type numbers come with the game's answer, or with the instant one", function()
    newWorld()
    local Game = freshGame()
    local asked = 0
    withGlobals({
        C_Item = {
            GetItemInfo = function(id)
                if id == 1 then
                    return "Sword", "link", 3, 20, 10, "Weapon", "Swords", 1, "INVTYPE_WEAPON", 0, 0, 2, 7
                elseif id == 3 then
                    return "Mail Helm", "link", 3, 20, 10, "Armor", "Mail", 1, "INVTYPE_HEAD", 0, 0
                end
                return nil
            end,
            GetItemInfoInstant = function(id)
                return id, "Armor", "Mail", "INVTYPE_HEAD", 0, 4, 3
            end,
            RequestLoadItemDataByID = function()
                asked = asked + 1
            end,
        },
    }, function()
        local known = Game.itemInfo(1)
        eq(known.classID, 2)
        eq(known.subClassID, 7)
        local older = Game.itemInfo(3)
        eq(older.classID, 4, "a client whose GetItemInfo gives no numbers: the instant answer")
        eq(older.subClassID, 3)
        eq(older.cached, true)
        local unknown = Game.itemInfo(2)
        eq(unknown.cached, false)
        eq(unknown.classID, 4, "known at once")
        eq(unknown.subClassID, 3)
        eq(unknown.type, "Armor")
    end)
    withGlobals({ C_Item = { GetItemInfo = function() return nil end } }, function()
        local nothing = Game.itemInfo(9)
        eq(nothing.classID, nil)
        eq(nothing.cached, false)
    end)
end)

test("usable: the answer is kept, and asked again when the level or the equipment changes", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local entries = { { kind = "item", id = 5203, pos = 1 } }
    Loot.visible(entries, { classFilter = true }, Game)
    Loot.visible(entries, { classFilter = true }, Game)
    eq(w.canUseCalls, 1)
    w.gear = w.gear + 1
    Loot.visible(entries, { classFilter = true }, Game)
    eq(w.canUseCalls, 2, "the level went up: asked again")
    Loot.visible(entries, { classFilter = true }, Game)
    eq(w.canUseCalls, 2)
end)

test("Main: a level up makes what the class wears be asked again", function()
    local w = mainWorld()
    local events = w.eventFrames[#w.eventFrames]
    check(events.events.PLAYER_LEVEL_UP)
    local before = w.gear
    events.onEvent(nil, "PLAYER_LEVEL_UP")
    eq(w.gear, before + 1)
    eq(w.ns.frameHooked, nil, "that event does not look for AtlasLoot's window")
end)

-- ---------------------------------------------------------- kinds of items

test("kindChoices: the types and sub types the lines have, in the game's words, armor and weapons first", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local lines = Loot.visible(deadmines(w), { classFilter = true }, Game)
    eq(values(Loot.kindChoices(lines, nil, Game)), "all c4 c4s1 c4s3 c2s5", "armor, its cloth and mail, then the weapon (one sub type: no line for the type)")
    eq(labels(Loot.kindChoices(lines, nil, Game)), "All types, Armor, Armor, Cloth, Armor, Mail, Weapon, Two-Handed Maces")
    eq(values(Loot.kindChoices({}, nil, Game)), "all")
    eq(values(Loot.kindChoices(items(99999), nil, Game)), "all", "an item the game says nothing about has no kind")
    w.info[7777] = { name = "Potion", type = "Consumable", subType = "Potion", classID = 0, subClassID = 1, cached = true }
    w.info[7778] = { name = "Quiver", type = "Quiver", subType = "Quiver", classID = 11, subClassID = 2, cached = true }
    w.info[7779] = { name = "Weapon 2", type = "Weapon", subType = "Daggers", classID = 2, subClassID = 15, cached = true }
    local more = Loot.kindChoices(items(7778, 7777, 5187, 7779, 5201), nil, Game)
    eq(values(more), "all c4s1 c2 c2s5 c2s15 c0s1 c11s2", "armor first, weapons second, then by number")
end)

test("kindChoices: a sub type named like its type, or not named, is said once; a type with no sub type is still a line", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    w.info[7001] = { name = "Quiver A", type = "Quiver", subType = "Quiver", classID = 11, subClassID = 2, cached = true }
    w.info[7002] = { name = "Thing", type = "Miscellaneous", subType = "", classID = 15, subClassID = 4, cached = true }
    w.info[7003] = { name = "Odd", type = "Strange", classID = 20, cached = true }
    local choices = Loot.kindChoices(items(7001, 7002, 7003), nil, Game)
    eq(values(choices), "all c11s2 c15s4 c20")
    eq(labels(choices), "All types, Quiver, Miscellaneous, Strange")
    local plain = Loot.kindChoices({ { kind = "header", name = "x" }, { kind = "item", id = 99999 } }, nil, Game)
    eq(#plain, 1, "headers are not items")
end)

test("kindChoices: the kind picked is always offered, and keeps its name", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local lines = Loot.visible(deadmines(w), { classFilter = true }, Game)
    Loot.kindChoices(lines, nil, Game)
    eq(values(Loot.kindChoices(lines, "c4s3", Game)), "all c4 c4s1 c4s3 c2s5", "not twice")
    local few = Loot.kindChoices(items(5187), "c4s3", Game)
    eq(values(few), "all c2s5 c4s3", "a kind the lines do not have comes last")
    eq(few[3].label, "Armor, Mail", "and keeps the name it had when it was seen")
    eq(Loot.kindLabel("c9s9"), "c9s9", "a kind never seen is named by its code")
end)

test("visible: the kind filter keeps a type or a sub type, and what the game has said nothing about", function()
    local w = newWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    local shown, hidden = Loot.visible(deadmines(w), { kind = "c4s3" }, Game)
    eq(ids(shown), "[h] 5302", "the mail helm only")
    eq(hidden, 6, "seven items, one kept")
    shown, hidden = Loot.visible(deadmines(w), { kind = "c4" }, Game)
    eq(ids(shown), "5201 5202 [h] 5202 5203 5302 5203", "every armor, the hammer is out")
    eq(hidden, 1)
    shown = Loot.visible(deadmines(w), { kind = "c2" }, Game)
    eq(ids(shown), "5187")
    shown = Loot.visible(deadmines(w), { kind = "c2s5" }, Game)
    eq(ids(shown), "5187")
    shown = Loot.visible(deadmines(w), { kind = "c2s6" }, Game)
    eq(#shown, 0, "a sub type nothing has")
    shown, hidden = Loot.visible(items(99999), { kind = "c4s3" }, Game)
    eq(#shown, 1, "an item the game has said nothing about is kept")
    eq(hidden, 0)
    shown = Loot.visible(deadmines(w), { kind = "nonsense" }, Game)
    eq(#shown, 0, "a code nobody understands matches nothing")
    shown, hidden = Loot.visible(deadmines(w), { classFilter = true, slot = "hands", kind = "c4s1" }, Game)
    eq(ids(shown), "[h] 5203 5203", "all three filters together")
    eq(hidden, 5)
end)

test("the item type control lists the kinds, and picking one limits the list and the summary says it", function()
    local w = bossScreen()
    w.d.focus("Item type")
    w.d.enter()
    local options = w.env.driver(w.env.pushed[#w.env.pushed].render)
    eq(optionList(options), "All types | Armor | Armor, Cloth | Armor, Mail | Weapon, Two-Handed Maces")
    contains(options.dump()[1], "Selected")
    options.focus("Armor, Mail")
    options.enter()
    eq(w.ns.Screen.state.kind, "c4s3")
    local text = readings(w.d)
    contains(text, "Alliance Helm")
    eq(text:find("Rhahk'Zor's Hammer", 1, true), nil)
    eq(text:find("Cloth Gloves", 1, true), nil)
    contains(text, "Items shown: 1, Hidden by the filters: 6, Item type: Armor, Mail")
    choose(w, "Item type", "All types")
    eq(w.ns.Screen.state.kind, nil)
    eq(readings(w.d):find("Item type:", 1, true), nil)
    choose(w, "Item type", "Armor")
    eq(w.ns.Screen.state.kind, "c4")
    contains(readings(w.d), "Items shown: 4, Hidden by the filters: 3, Item type: Armor")
end)

test("the slots and the kinds offered follow each other", function()
    local w = bossScreen()
    choose(w, "Slot", "Hands")
    w.d.focus("Item type")
    w.d.enter()
    local options = w.env.driver(w.env.pushed[#w.env.pushed].render)
    eq(optionList(options), "All types | Armor, Cloth", "only what the hands have")
    options.focus("Armor, Cloth")
    options.enter()
    choose(w, "Slot", "All slots")
    w.ns.Screen.state.kind = "c4s3"
    w.d.focus("Slot")
    w.d.enter()
    options = w.env.driver(w.env.pushed[#w.env.pushed].render)
    eq(optionList(options), "All slots | Head", "with mail picked, the slots that have mail")
end)

test("the kind stays when the player goes to another boss, and is still offered when this boss has none of it", function()
    local w = bossScreen()
    choose(w, "Item type", "Armor, Mail")
    w.ns.Screen.back()
    enter(w, "Sneed")
    local text = readings(w.d)
    contains(text, "Item type: Armor, Mail")
    contains(text, "No item to show.")
    w.d.focus("Item type")
    w.d.enter()
    local options = w.env.driver(w.env.pushed[#w.env.pushed].render)
    check(options.focus("Armor, Mail") ~= nil, "the kind picked is offered, so it can be left")
end)

test("the item type control also works in the loading state and in the search", function()
    local w = bossScreen()
    w.atlas.ItemDB.GetItemTable = function()
        return "TestLate"
    end
    w.ns.Screen.state.cache = {}
    contains(readings(w.d), "Item type, Dropdown, All types")
    local s = searchScreen()
    typeQuery(s, "er")
    contains(readings(s.d), "Rhahk'Zor's Hammer")
    choose(s, "Item type", "Armor, Cloth")
    eq(s.ns.Screen.state.kind, "c4s1")
    local text = readings(s.d)
    contains(text, "Emberstone Cloak")
    eq(text:find("Rhahk'Zor's Hammer", 1, true), nil, "the hammer is a weapon")
    contains(text, "Item type: Armor, Cloth")
end)

-- ------------------------------------------------- the Gear Judge judges upgrades

-- Sets what the Gear Judge says of items, by link; every item the tests use gets a link and a worn item in its slot.
local function judgeWorld(config)
    local w = newWorld(config)
    for id, info in pairs(w.info) do
        info.link = "item:" .. id
    end
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 99 } }
    w.worn.INVTYPE_HAND = { { id = 2, level = 99 } }
    w.worn.INVTYPE_HEAD = { { id = 3, level = 99 } }
    w.worn.INVTYPE_2HWEAPON = { { id = 4, level = 99 } }
    w.says = {}
    w.judge = function(link)
        local answer = w.says[link]
        if answer == nil then
            return nil, "BAD_LINK"
        end
        return answer.result, answer.reason
    end
    return w
end

local function says(w, id, pct, extra)
    local result = { upgradePct = pct, equipped = false, equippedLink = "|Hitem:9::::|h[Old]|h" }
    for key, value in pairs(extra or {}) do
        result[key] = value
    end
    w.says["item:" .. id] = { result = result }
end

test("upgradeMeasure: the judge chosen, or the best there is", function()
    local w = newWorld()
    local Game = w.ns.Game
    local function measure(wanted, judge, pawn)
        w.settings.measure = wanted
        w.judge = judge and function() end or nil
        w.pawn = pawn and function() end or nil
        return Game.upgradeMeasure()
    end
    eq(measure("auto", false, false), "level")
    eq(measure("auto", false, true), "pawn")
    eq(measure("auto", true, false), "judge")
    eq(measure("auto", true, true), "judge", "the Gear Judge first")
    eq(measure("judge", true, true), "judge")
    eq(measure("judge", false, true), "pawn", "no Gear Judge: the next one")
    eq(measure("judge", false, false), "level")
    eq(measure("pawn", true, true), "pawn", "the player wants Pawn")
    eq(measure("pawn", true, false), "level", "Pawn is not there: the item level, not the Gear Judge")
    eq(measure("level", true, true), "level")
    eq(measure("weird", true, true), "judge", "a value nobody understands is automatic")
    eq(measure(nil, false, true), "pawn", "the default is automatic")
    eq(measure(nil, true, true), "judge", "automatic takes the Gear Judge first")
end)

test("Game: the Gear Judge is ready when it is there and says so, asked once per equipment", function()
    newWorld()
    local Game = freshGame()
    local asked = 0
    local api = {
        ScoreItem = function() end,
        IsReady = function()
            asked = asked + 1
            return true
        end,
    }
    withGlobals({ SharpiesGearJudgeAPI = api }, function()
        eq(Game.judgeReady(), true)
        Game.judgeReady()
        Game.judgeReady()
        eq(asked, 1, "kept")
        Game.gearChanged()
        Game.judgeReady()
        eq(asked, 2, "asked again after a change")
        api.IsReady = function()
            return false
        end
        Game.gearChanged()
        eq(Game.judgeReady(), false, "not ready yet")
        api.IsReady = function()
            error("boom")
        end
        Game.gearChanged()
        eq(Game.judgeReady(), true, "a failing IsReady does not stop it")
        api.IsReady = nil
        Game.gearChanged()
        eq(Game.judgeReady(), true, "a Judge without IsReady")
        api.ScoreItem = nil
        Game.gearChanged()
        eq(Game.judgeReady(), false, "a Judge too old to score")
    end)
    withGlobals({ SharpiesGearJudgeAPI = "not a table" }, function()
        Game.gearChanged()
        eq(Game.judgeReady(), false)
    end)
    Game.gearChanged()
    eq(Game.judgeReady(), false, "no Gear Judge")
end)

test("Game: the Gear Judge's judgement of an item", function()
    local w = newWorld()
    local Game = freshGame()
    local answer
    withGlobals({
        SharpiesGearJudgeAPI = {
            ScoreItem = function(link)
                eq(link, "item:1")
                if type(answer) == "function" then
                    return answer()
                end
                return answer.result, answer.reason
            end,
        },
    }, function()
        answer = { result = { upgradePct = 3 } }
        eq(Game.judgeScore("item:1").upgradePct, 3)
        answer = { result = nil, reason = "NOT_USABLE" }
        local result, reason = Game.judgeScore("item:1")
        eq(result, nil)
        eq(reason, "NOT_USABLE")
        answer = { result = "text", reason = nil }
        eq(select(2, Game.judgeScore("item:1")), "ERROR", "an answer that is not a table, and no reason")
        answer = { result = false, reason = "NOT_CACHED" }
        eq(select(2, Game.judgeScore("item:1")), "NOT_CACHED")
        answer = function()
            error("judge failed")
        end
        result, reason = Game.judgeScore("item:1")
        eq(result, nil)
        eq(reason, "ERROR")
        Game.judgeScore("item:1")
        eq(#w.errors, 1, "reported once")
        contains(w.errors[1], "judge failed")
    end)
    local missing, why = Game.judgeScore("item:1")
    eq(missing, nil)
    eq(why, "MISSING")
    withGlobals({ SharpiesGearJudgeAPI = {} }, function()
        eq(select(2, Game.judgeScore("item:1")), "MISSING", "no ScoreItem")
    end)
end)

test("Game.locale: the game's language, English without it", function()
    newWorld()
    local Game = freshGame()
    GetLocale = function()
        return "frFR"
    end
    eq(Game.locale(), "frFR")
    GetLocale = nil
    eq(Game.locale(), "enUS")
    GetLocale = function()
        return "enUS"
    end
end)

test("number: one decimal at most, no .0, no minus sign, a decimal comma where the language writes one", function()
    local Loot = newWorld().ns.Loot
    eq(Loot.number(4.2, "enUS"), "4.2")
    eq(Loot.number(4.0, "enUS"), "4")
    eq(Loot.number(100, "enUS"), "100")
    eq(Loot.number(-3.14, "enUS"), "3.1")
    eq(Loot.number(4.2, "frFR"), "4,2")
    eq(Loot.number(12.5, "deDE"), "12,5")
    eq(Loot.number(4.2, nil), "4.2")
end)

test("upgrade by the Gear Judge: an upgrade says how much better the character gets", function()
    local w = judgeWorld()
    says(w, 5201, 4.2)
    local up = w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game)
    eq(up.how, "judge")
    eq(up.percent, 4.2)
    says(w, 5201, 0.06)
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game).how, "judge", "a tenth of a percent counts")
    says(w, 5201, 0.04)
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false, "less than that does not")
    says(w, 5201, 0)
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false)
    says(w, 5201, -2.5)
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false, "a downgrade")
end)

test("upgrade by the Gear Judge: worn already, not for this class, not gear", function()
    local w = judgeWorld()
    says(w, 5201, 5, { equipped = true })
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false, "the Judge says it is the one worn")
    w.says["item:5201"] = { result = nil, reason = "NOT_USABLE" }
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false)
    w.says["item:5201"] = { result = nil, reason = "NOT_EQUIPPABLE" }
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false)
    local asked = w.judgeCalls
    w.worn.INVTYPE_CLOAK = { { id = 5201, level = 20 } }
    says(w, 5201, 9)
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false, "worn: the Judge is not asked")
    eq(w.judgeCalls, asked)
    eq(w.ns.Loot.upgrade({ kind = "item", id = 6001 }, w.ns.Game), false, "no slot listed for a ring: not gear here")
    eq(w.judgeCalls, asked, "and the Judge is not asked about it either")
end)

test("upgrade by the Gear Judge: what it cannot say yet is unknown, and asked again", function()
    local w = judgeWorld()
    for _, reason in ipairs({ "NOT_CACHED", "NOT_READY", "ERROR", "BAD_LINK" }) do
        w.says["item:5201"] = { result = nil, reason = reason }
        local entry = { kind = "item", id = 5201 }
        eq(w.ns.Loot.upgrade(entry, w.ns.Game), nil, reason)
        local calls = w.judgeCalls
        w.ns.Loot.upgrade(entry, w.ns.Game)
        eq(w.judgeCalls, calls + 1, reason .. ": asked again, not kept")
    end
end)

test("upgrade by the Gear Judge: points only when it gives no percentage, nothing when it gives nothing", function()
    local w = judgeWorld()
    says(w, 5201, nil, { upgrade = 12 })
    local up = w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game)
    eq(up.how, "judge")
    eq(up.percent, nil)
    says(w, 5201, nil, { upgrade = 0 })
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false)
    says(w, 5201, nil, { upgrade = -4 })
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false)
    says(w, 5201, nil, { upgrade = "lots" })
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false, "points that are not a number")
    says(w, 5201, nil, { upgrade = math.huge })
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false, "infinite points are not trusted")
    says(w, 5201, nil)
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false, "an answer without any figure is no upgrade")
    says(w, 5201, math.huge)
    eq(w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game), false, "an infinite percentage is not trusted")
end)

test("upgrade by the Gear Judge: an item without a link is judged by item level, and the answer follows the judge chosen", function()
    local w = judgeWorld()
    w.info[5201].link = nil
    w.worn.INVTYPE_CLOAK = { { id = 1, level = 15 } }
    says(w, 5201, 9)
    local up = w.ns.Loot.upgrade({ kind = "item", id = 5201 }, w.ns.Game)
    eq(up.how, "level", "no link, no Judge")
    eq(w.judgeCalls, 0)
    w.info[5201].link = "item:5201"
    local entry = { kind = "item", id = 5201 }
    eq(w.ns.Loot.upgrade(entry, w.ns.Game).how, "judge")
    w.settings.measure = "level"
    eq(w.ns.Loot.upgrade(entry, w.ns.Game).how, "level", "the player picked the item level: the kept answer is not used")
    w.settings.measure = "auto"
    eq(w.ns.Loot.upgrade(entry, w.ns.Game).how, "judge")
    local calls = w.judgeCalls
    w.ns.Loot.upgrade(entry, w.ns.Game)
    eq(w.judgeCalls, calls, "and kept again")
end)

test("upgradeText: the Gear Judge's percentage, with a decimal comma where it is written so", function()
    local w = newWorld()
    local Loot = w.ns.Loot
    eq(Loot.upgradeText({ how = "judge", percent = 4.2 }, w.ns.Game), "upgrade of 4.2 percent, judged by Gear Judge")
    eq(Loot.upgradeText({ how = "judge", percent = 4.2 }), "upgrade of 4.2 percent, judged by Gear Judge", "no game: English")
    eq(Loot.upgradeText({ how = "judge" }, w.ns.Game), "an upgrade, judged by Gear Judge")
    local french = newWorld({ locale = "frFR" })
    eq(french.ns.Loot.upgradeText({ how = "judge", percent = 4.2 }, french.ns.Game), "amélioration de 4,2 pour cent selon Gear Judge")
    eq(french.ns.Loot.upgradeText({ how = "judge" }, french.ns.Game), "une amélioration selon Gear Judge")
    local german = newWorld({ locale = "deDE" })
    eq(german.ns.Loot.upgradeText({ how = "judge", percent = 12.5 }, german.ns.Game), "Verbesserung um 12,5 Prozent nach Gear Judge")
end)

test("describe: an upgrade by the Gear Judge says so in the item's line", function()
    local w = judgeWorld()
    says(w, 5187, 6.5)
    local text = w.ns.Loot.describe({ id = 5187, npcID = 644 }, {}, w.ns.Game)
    contains(text, "requires level 15, upgrade of 6.5 percent, judged by Gear Judge, 12.5 percent drop chance")
    says(w, 5187, -1)
    w.gear = w.gear + 1
    eq(w.ns.Loot.describe({ id = 5187, npcID = 644 }, {}, w.ns.Game):find("judged by", 1, true), nil, "no upgrade, nothing said")
end)

test("describe: the Gear Judge's percentage is spoken with a comma in French", function()
    local w = judgeWorld({ locale = "frFR" })
    says(w, 5187, 4.2)
    contains(w.ns.Loot.describe({ id = 5187, npcID = 644 }, {}, w.ns.Game), "amélioration de 4,2 pour cent selon Gear Judge")
end)

test("the upgrades filter and the sort follow the Gear Judge", function()
    local w = judgeWorld()
    local Loot, Game = w.ns.Loot, w.ns.Game
    says(w, 5187, 2.5)
    says(w, 5201, -1)
    says(w, 5203, 9)
    w.says["item:5202"] = { result = nil, reason = "NOT_USABLE" }
    w.says["item:5302"] = { result = nil, reason = "NOT_EQUIPPABLE" }
    local shown, hidden = Loot.visible(deadmines(w), { upgradesOnly = true }, Game)
    eq(ids(shown), "5187 [h] 5203 5203", "only what the Judge calls an upgrade")
    eq(hidden, 4, "the cloak (a downgrade), the gauntlets twice (not usable) and the helm (not equipment)")
    eq(ids(Loot.sort(items(5187, 5201, 5203, 5302), "upgrade", Game)), "5203 5187 5201 5302", "the biggest percentage first")
end)

test("the filters stop says who judges, and the judge can be chosen", function()
    local s = bossScreen()
    s.judge = function() end
    s.ns.Game.judgeReady = function()
        return true
    end
    contains(readings(s.d), "Only upgrades, judged by Gear Judge")
    contains(readings(s.d), "Judge of upgrades, Dropdown, Automatic")
    s.d.focus("Judge of upgrades")
    s.d.enter()
    local options = s.env.driver(s.env.pushed[#s.env.pushed].render)
    eq(optionList(options), "Automatic | Gear Judge | Pawn | Item level")
    contains(options.dump()[1], "Selected")
    s.pawn = function() end
    options.focus("Pawn")
    options.enter()
    eq(s.settings.measure, "pawn")
    local text = readings(s.d)
    contains(text, "Only upgrades, judged by Pawn")
    contains(text, "Judge of upgrades, Dropdown, Pawn")
    choose(s, "Judge of upgrades", "Item level")
    contains(readings(s.d), "Only upgrades, judged by item level")
    choose(s, "Judge of upgrades", "Automatic")
    contains(readings(s.d), "Only upgrades, judged by Gear Judge")
end)

test("measureChoices: the judges, in the player's language", function()
    local w = newWorld()
    eq(labels(w.ns.Loot.measureChoices()), "Automatic, Gear Judge, Pawn, Item level")
    eq(values(w.ns.Loot.measureChoices()), "auto judge pawn level")
    local french = newWorld({ locale = "frFR" })
    eq(labels(french.ns.Loot.measureChoices()), "Automatique, Gear Judge, Pawn, Niveau d'objet")
    local german = newWorld({ locale = "deDE" })
    eq(labels(german.ns.Loot.measureChoices()), "Automatisch, Gear Judge, Pawn, Gegenstandsstufe")
end)

test("French: the judge of upgrades speaks French", function()
    local w = bossScreen({ locale = "frFR" })
    w.ns.Game.judgeReady = function()
        return true
    end
    local text = readings(w.d)
    contains(text, "Seulement les améliorations, selon Gear Judge")
    contains(text, "Juge des améliorations")
    contains(text, "Automatique")
end)

test("Tab goes from the loot list to the filters, then to the navigation, and back to the list", function()
    local w = bossScreen()
    w.d.focus("Rhahk'Zor's Hammer")
    local stops = {}
    for _ = 1, 4 do
        w.d.tab()
        stops[#stops + 1] = w.d.say()
    end
    contains(stops[1], "Items shown", "the first Tab lands on the filters' summary")
    contains(stops[1], "1 of 9", "which is the first of the nine filter controls")
    contains(stops[2], "You are in", "the second one on the navigation")
    contains(stops[3], "Rhahk'Zor's Hammer", "the third one wraps to the list")
end)

test("French: the new control speaks French", function()
    local w = bossScreen({ locale = "frFR" })
    contains(readings(w.d), "Type d'objet")
    contains(readings(w.d), "Tous les types")
    choose(w, "Type d'objet", "Armor, Mail")
    contains(readings(w.d), "Type d'objet : Armor, Mail")
    local german = bossScreen({ locale = "deDE" })
    contains(readings(german.d), "Gegenstandsart")
    contains(readings(german.d), "Alle Arten")
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
