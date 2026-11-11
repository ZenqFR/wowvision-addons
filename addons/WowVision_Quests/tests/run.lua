-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- The game and WowVision are mocked (a scanner with the quests provider, a quests module with a log), but the
-- addon's own files are loaded for real, in the order of the .toc.

local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."

tinsert = table.insert

local runner = { suites = {}, order = {}, passed = 0, failed = 0 }

function runner:addSuite(name, suite)
    self.suites[name] = suite
    tinsert(self.order, name)
end
function runner:assertEqual(a, b, message)
    if a ~= b then
        error((message or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end
function runner:assertTrue(value, message)
    if value ~= true then
        error((message or "expected true") .. ", got " .. tostring(value), 2)
    end
end
function runner:assertFalse(value, message)
    if value ~= false then
        error((message or "expected false") .. ", got " .. tostring(value), 2)
    end
end
function runner:assertNotNil(value, message)
    if value == nil then
        error(message or "expected a value", 2)
    end
end

function runner:run()
    for _, name in ipairs(self.order) do
        local names = {}
        for testName in pairs(self.suites[name]) do
            tinsert(names, testName)
        end
        table.sort(names)
        for _, testName in ipairs(names) do
            local ok, err = pcall(self.suites[name][testName], self)
            if ok then
                self.passed = self.passed + 1
            else
                self.failed = self.failed + 1
                io.write("FAIL  ", name, " / ", testName, "\n      ", tostring(err), "\n")
            end
        end
    end
    io.write(string.format("%d passed, %d failed\n", self.passed, self.failed))
    os.exit(self.failed == 0 and 0 or 1)
end

local FILES = { "Locale", "Sort", "Main" }

local function loadAddon()
    local ns = {}
    for _, name in ipairs(FILES) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_Quests", ns)
    end
    return ns
end

-- A fake WowVision with the quests provider as the scanner has it. config.log is the quest log; config.nodes the
-- nodes the In Progress category lists, in the order of the log.
local function newWorld(config)
    config = config or {}
    local world = { spoken = {}, errors = {}, builds = 0 }
    GetLocale = function()
        return config.locale or "enUS"
    end
    geterrorhandler = function()
        return function(err)
            tinsert(world.errors, tostring(err))
        end
    end
    print = function() end
    WowVisionQuestsDB = config.db

    local quests = {
        adapter = {
            _playerContext = function()
                return config.player or { x = 100, y = 100 }
            end,
        },
    }
    function quests:inProgress()
        if config.logFails then
            error("no log")
        end
        return config.log or {}
    end
    world.quests = quests

    local provider = { key = "quests", order = 10 }
    function provider.build()
        world.builds = world.builds + 1
        return {
            { key = "nearby", children = function() return { { key = "n1", label = "Nearby one" } } end },
            { key = "inProgress", children = function() return config.nodes or {} end },
        }
    end
    world.provider = provider

    WowVision = {
        speak = function(_, text)
            tinsert(world.spoken, text)
        end,
        base = { quests = quests, scanner = { providers = { provider } } },
        quests = { Adapter = {} },
    }
    if config.coreSorts then
        WowVision.quests.Adapter.sortByProximity = function() end
    end
    world.ns = loadAddon()
    return world
end

local function keys(list)
    local out = {}
    for _, node in ipairs(list) do
        tinsert(out, node.key)
    end
    return table.concat(out, ",")
end

local function inProgress(world)
    local categories = world.provider.build({})
    return categories[2].children()
end

-- ------------------------------------------------------------------ tests

runner:addSuite("Sorting", {
    ["nodes sort nearest first, unplaced ones last, ties in order"] = function(t)
        local world = newWorld()
        local nodes = {
            { key = "a", x = 500, y = 100 }, -- 400 yards
            { key = "b" }, -- nothing to walk to
            { key = "c", x = 110, y = 100 }, -- 10 yards
            { key = "d", x = 100, y = 600 }, -- 500 yards
            { key = "e" },
            { key = "f", x = 100, y = 500 }, -- 400 yards, like a: a came first
        }
        local sorted = world.ns.sortByProximity(nodes, { x = 100, y = 100 })
        t:assertEqual(keys(sorted), "c,a,f,d,b,e")
        t:assertEqual(keys(nodes), "a,b,c,d,e,f", "the list given is not changed")
    end,

    ["without a player position the order stays"] = function(t)
        local world = newWorld()
        local nodes = { { key = "far", x = 900, y = 900 }, { key = "near", x = 1, y = 1 } }
        t:assertEqual(world.ns.sortByProximity(nodes, nil), nodes)
        t:assertEqual(world.ns.sortByProximity(nodes, {}), nodes)
        t:assertEqual(world.ns.sortByProximity(nodes, { x = 1 }), nodes)
    end,

    ["an empty list sorts to an empty list"] = function(t)
        local world = newWorld()
        t:assertEqual(#world.ns.sortByProximity({}, { x = 0, y = 0 }), 0)
    end,
})

runner:addSuite("Titles", {
    ["a quest says its level after its title"] = function(t)
        local world = newWorld()
        t:assertEqual(world.ns.titleWithLevel("A Threat Within", 5), "A Threat Within, Level 5")
    end,

    ["a quest with no level in the log keeps its bare title"] = function(t)
        local world = newWorld()
        t:assertEqual(world.ns.titleWithLevel("A Threat Within", nil), "A Threat Within")
        t:assertEqual(world.ns.titleWithLevel("A Threat Within", 0), "A Threat Within")
        t:assertEqual(world.ns.titleWithLevel("A Threat Within", -1), "A Threat Within")
    end,

    ["the word is the player's language"] = function(t)
        local fr = newWorld({ locale = "frFR" })
        t:assertEqual(fr.ns.titleWithLevel("Une menace", 5), "Une menace, Niveau 5")
        local de = newWorld({ locale = "deDE" })
        t:assertEqual(de.ns.titleWithLevel("Eine Bedrohung", 5), "Eine Bedrohung, Stufe 5")
    end,
})

runner:addSuite("The scanner", {
    ["the In Progress list says levels and comes nearest first"] = function(t)
        local world = newWorld({
            log = { { questId = 11, level = 5 }, { questId = 22, level = 7 }, { questId = 33 } },
            nodes = {
                { key = "quest:11", label = "Far quest", x = 900, y = 100 },
                { key = "quest:22", label = "Near quest", x = 120, y = 100 },
                { key = "quest:33", label = "Unplaced quest" },
            },
        })
        t:assertTrue(world.ns.installed)
        local nodes = inProgress(world)
        t:assertEqual(keys(nodes), "quest:22,quest:11,quest:33")
        t:assertEqual(nodes[1].label, "Near quest, Level 7")
        t:assertEqual(nodes[2].label, "Far quest, Level 5")
        t:assertEqual(nodes[3].label, "Unplaced quest")
    end,

    ["the Nearby category is left as it is"] = function(t)
        local world = newWorld()
        local categories = world.provider.build({})
        t:assertEqual(categories[1].children()[1].label, "Nearby one")
    end,

    ["the setting off keeps the log's order but still says levels"] = function(t)
        local world = newWorld({
            db = { sort = false },
            log = { { questId = 11, level = 5 }, { questId = 22, level = 7 } },
            nodes = {
                { key = "quest:11", label = "Far quest", x = 900, y = 100 },
                { key = "quest:22", label = "Near quest", x = 120, y = 100 },
            },
        })
        local nodes = inProgress(world)
        t:assertEqual(keys(nodes), "quest:11,quest:22")
        t:assertEqual(nodes[1].label, "Far quest, Level 5")
    end,

    ["a node that is not a quest keeps its label"] = function(t)
        local world = newWorld({
            nodes = { { key = "loading", label = "Loading" }, { key = "quest:5", label = "Quest" } },
            log = { { questId = 5, level = 3 } },
        })
        local nodes = inProgress(world)
        t:assertEqual(nodes[1].label, "Loading")
        t:assertEqual(nodes[2].label, "Quest, Level 3")
    end,

    ["a log that cannot be read leaves the list as it was, and is reported once"] = function(t)
        local world = newWorld({
            logFails = true,
            nodes = { { key = "quest:5", label = "Quest", x = 1, y = 1 } },
        })
        local nodes = inProgress(world)
        t:assertEqual(nodes[1].label, "Quest")
        inProgress(world)
        t:assertEqual(#world.errors, 1)
    end,

    ["a player position that cannot be read keeps the order"] = function(t)
        local world = newWorld({
            log = { { questId = 11, level = 5 }, { questId = 22, level = 7 } },
            nodes = {
                { key = "quest:11", label = "Far quest", x = 900, y = 100 },
                { key = "quest:22", label = "Near quest", x = 120, y = 100 },
            },
        })
        world.quests.adapter = nil
        t:assertEqual(keys(inProgress(world)), "quest:11,quest:22")
    end,

    ["installing twice wraps once"] = function(t)
        local world = newWorld()
        local build = world.provider.build
        t:assertTrue(world.ns.install())
        t:assertEqual(world.provider.build, build)
    end,

    ["a missing quests provider is reported and nothing breaks"] = function(t)
        local world = newWorld()
        WowVision.base.scanner.providers = {}
        t:assertFalse(world.ns.install())
    end,

    ["a WowVision that sorts quests itself is left alone"] = function(t)
        local world = newWorld({ coreSorts = true })
        local build = world.provider.build
        t:assertEqual(world.provider.build, build)
        t:assertEqual(world.provider.levelsAndProximity, nil)
    end,

    ["a scanner without an In Progress category passes through"] = function(t)
        local world = newWorld()
        world.provider.build = function()
            return { { key = "missing", label = "No quest data source" } }
        end
        world.ns.install()
        local categories = world.provider.build({})
        t:assertEqual(categories[1].label, "No quest data source")
    end,
})

runner:addSuite("The command", {
    ["it says where things stand, and switches the sorting"] = function(t)
        local world = newWorld()
        world.ns.handleCommand("")
        t:assertEqual(world.spoken[#world.spoken], "Sort Quests by Proximity: on")
        world.ns.handleCommand("off")
        t:assertEqual(world.spoken[#world.spoken], "Sort Quests by Proximity: off")
        t:assertFalse(world.ns.getSetting("sort"))
        world.ns.handleCommand("on")
        t:assertTrue(world.ns.getSetting("sort"))
    end,

    ["it speaks French"] = function(t)
        local world = newWorld({ locale = "frFR" })
        world.ns.handleCommand("non")
        t:assertEqual(world.spoken[#world.spoken], "Trier les quêtes par proximité : désactivé")
    end,

    ["it speaks German, and understands ja and nein"] = function(t)
        local world = newWorld({ locale = "deDE" })
        world.ns.handleCommand("nein")
        t:assertEqual(world.spoken[#world.spoken], "Quests nach Entfernung sortieren: aus")
        t:assertFalse(world.ns.getSetting("sort"))
        world.ns.handleCommand("ja")
        t:assertEqual(world.spoken[#world.spoken], "Quests nach Entfernung sortieren: an")
        t:assertTrue(world.ns.getSetting("sort"))
        world.ns.handleCommand("aus")
        t:assertFalse(world.ns.getSetting("sort"))
        world.ns.handleCommand("an")
        t:assertTrue(world.ns.getSetting("sort"))
    end,

    ["a word it does not know gets the usage"] = function(t)
        local world = newWorld()
        world.ns.handleCommand("banana")
        t:assertEqual(world.spoken[#world.spoken], "Use /wvquests on or /wvquests off to switch the sorting by proximity.")
        t:assertTrue(world.ns.getSetting("sort"))
    end,
})

runner:run()
