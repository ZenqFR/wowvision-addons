-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- The game and WowVision are mocked (creatures with tooltips, nameplates, secure buttons that run their PreClick
-- before the targeting action, the binding registry), but the addon's own files are loaded for real, in the order
-- of the .toc. No other addon is needed.

local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."

tinsert = table.insert

-- ----------------------------------------------------------------- harness

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
function runner:assertNil(value, message)
    if value ~= nil then
        error((message or "expected nil") .. ", got " .. tostring(value), 2)
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

local FILES = { "Locale", "Targets", "Game", "Main" }

local function loadAddon()
    local ns = {}
    for _, name in ipairs(FILES) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_QuestTargets", ns)
    end
    return ns
end

-- ------------------------------------------------------------ the world

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

-- A creature: id (the same id is the same creature), name, and what the game says about it. lines are the
-- tooltip's: { type = 8, text = "Kobold Vermin slain: 3/8", completed = false }.
local function creature(id, name, extra)
    local info = {
        id = id,
        name = name,
        player = false,
        attack = true,
        dead = false,
        related = true,
        range = { 0, 20 },
    }
    for key, value in pairs(extra or {}) do
        info[key] = value
    end
    if info.lines == nil then
        info.lines = { { type = 8, text = tostring(name) .. " slain: 3/8", completed = false } }
    end
    return info
end

-- A fake WowVision, game and secure buttons around the real addon. config.units["nameplate1"] = creature(...).
local function newWorld(config)
    config = config or {}
    local world = {
        spoken = {},
        errors = {},
        units = config.units or {},
        target = nil,
        combat = config.combat == true,
        bindings = {},
        bindingOrder = {},
        applied = 0,
        cvars = {},
        time = 100,
        locale = config.locale or "enUS",
        buttons = {},
    }

    GetLocale = function()
        return world.locale
    end
    geterrorhandler = function()
        return function(err)
            tinsert(world.errors, tostring(err))
        end
    end
    print = function() end
    GetTime = function()
        return world.time
    end
    InCombatLockdown = function()
        return world.combat
    end
    UIParent = {}

    local function creatureOf(unit)
        if unit == "target" then
            return world.target
        end
        return world.units[unit]
    end

    UnitExists = function(unit)
        return creatureOf(unit) ~= nil
    end
    UnitIsUnit = function(a, b)
        local first, second = creatureOf(a), creatureOf(b)
        return first ~= nil and second ~= nil and first.id == second.id
    end
    UnitIsPlayer = function(unit)
        return creatureOf(unit).player
    end
    UnitCanAttack = function(_, unit)
        return creatureOf(unit).attack
    end
    UnitIsDead = function(unit)
        return creatureOf(unit).dead
    end
    UnitName = function(unit)
        return creatureOf(unit).name
    end
    C_QuestLog = {
        UnitIsRelatedToActiveQuest = function(unit)
            return creatureOf(unit).related
        end,
    }
    C_TooltipInfo = {
        GetUnit = function(unit)
            local lines = {}
            for _, line in ipairs(creatureOf(unit).lines or {}) do
                tinsert(lines, { type = line.type, leftText = line.text, completed = line.completed })
            end
            return { lines = lines }
        end,
    }
    if config.noRelated then
        C_QuestLog = {}
    end
    if config.noTooltip then
        C_TooltipInfo = {}
    end
    local rangeCheck = {
        GetRange = function(_, unit)
            local range = creatureOf(unit).range
            if range == nil then
                return nil
            end
            return range[1], range[2]
        end,
    }
    LibStub = function()
        return rangeCheck
    end
    C_CVar = {
        GetCVarBool = function(name)
            if world.cvars[name] == nil then
                return config.platesOff ~= true
            end
            return world.cvars[name] == "1"
        end,
        SetCVar = function(name, value)
            world.cvars[name] = value
        end,
    }

    -- frames: a secure button runs its PreClick, then the secure targeting action, then its PostClick
    CreateFrame = function(_, name)
        local frame = { name = name, attributes = {}, scripts = {}, events = {} }
        function frame:SetAttribute(key, value)
            if world.combat then
                error("SetAttribute on a secure frame in combat")
            end
            self.attributes[key] = value
        end
        function frame:GetAttribute(key)
            return self.attributes[key]
        end
        function frame:SetScript(kind, fn)
            self.scripts[kind] = fn
        end
        function frame:RegisterEvent(event)
            self.events[event] = true
        end
        function frame:GetName()
            return self.name
        end
        function frame:Click()
            if self.scripts.PreClick ~= nil then
                self.scripts.PreClick(self, "LeftButton", false)
            end
            if self.attributes.type == "target" and self.attributes.unit ~= nil then
                local chosen = creatureOf(self.attributes.unit)
                if chosen ~= nil then
                    world.target = chosen
                    world.fireEvent("PLAYER_TARGET_CHANGED")
                end
            end
            if self.scripts.PostClick ~= nil then
                self.scripts.PostClick(self, "LeftButton", false)
            end
        end
        tinsert(world.buttons, frame)
        world.lastFrame = frame
        return frame
    end

    -- the binding registry
    local input = {}
    function input:createBinding(info)
        local binding = {}
        for key, value in pairs(info) do
            binding[key] = value
        end
        binding.activations = 0
        function binding:activate()
            self.activations = self.activations + 1
        end
        world.bindings[info.key] = binding
        tinsert(world.bindingOrder, info.key)
        return binding
    end
    function input:getBinding(key)
        return world.bindings[key]
    end
    function input:getDefaultDB()
        return {}
    end

    WowVisionDB = {}
    WowVision = {
        speak = function(_, text)
            tinsert(world.spoken, text)
        end,
        isSecret = function(value)
            return value == SECRET
        end,
        input = input,
        dbManager = {
            resolveBindings = function()
                return {}
            end,
        },
        applyBindingStore = function()
            world.applied = world.applied + 1
        end,
        globalDb = {},
    }
    if config.noInput then
        WowVision.input = nil
    end

    function world.fireEvent(event, ...)
        for _, frame in ipairs(world.buttons) do
            if frame.events[event] and frame.scripts.OnEvent ~= nil then
                frame.scripts.OnEvent(frame, event, ...)
            end
        end
    end

    world.ns = loadAddon()

    -- a key press: the click the binding forwards to the button
    function world.press(which)
        local button = which == "previous" and world.ns.previousButton or world.ns.nextButton
        button:Click()
    end
    function world.said()
        return world.spoken[#world.spoken]
    end
    return world
end

local function contains(text, part)
    return text:find(part, 1, true) ~= nil
end

local function names(list)
    local out = {}
    for _, candidate in ipairs(list) do
        tinsert(out, candidate.name)
    end
    return table.concat(out, ",")
end

-- A small field of kobolds: three plates at different distances, one of them also the target.
local function field()
    return {
        nameplate1 = creature(1, "Far Kobold", { range = { 20, 30 } }),
        nameplate2 = creature(2, "Near Kobold", { range = { 0, 8 } }),
        nameplate3 = creature(3, "Mid Kobold", { range = { 8, 15 } }),
    }
end

-- ------------------------------------------------------------------ tests

runner:addSuite("Candidates", {
    ["the quest creatures come nearest first"] = function(t)
        local world = newWorld({ units = field() })
        local found = world.ns.lookup()
        t:assertEqual(names(found), "Near Kobold,Mid Kobold,Far Kobold")
    end,

    ["players, friendly creatures and dead ones are left out"] = function(t)
        local units = field()
        units.nameplate4 = creature(4, "A Player", { player = true })
        units.nameplate5 = creature(5, "Friendly Guard", { attack = false })
        units.nameplate6 = creature(6, "Dead Kobold", { dead = true })
        local world = newWorld({ units = units })
        t:assertEqual(names(world.ns.lookup()), "Near Kobold,Mid Kobold,Far Kobold")
    end,

    ["a creature of no quest is left out"] = function(t)
        local units = field()
        units.nameplate4 = creature(4, "Plain Wolf", { related = false, lines = {} })
        local world = newWorld({ units = units })
        t:assertEqual(names(world.ns.lookup()), "Near Kobold,Mid Kobold,Far Kobold")
    end,

    ["a creature whose objectives are all finished is left out"] = function(t)
        local units = field()
        units.nameplate4 = creature(4, "Done Kobold", {
            range = { 0, 3 },
            lines = { { type = 8, text = "Kobold slain: 8/8", completed = true } },
        })
        local world = newWorld({ units = units })
        t:assertEqual(names(world.ns.lookup()), "Near Kobold,Mid Kobold,Far Kobold")
    end,

    ["a creature with one finished and one unfinished objective is kept, with the unfinished one only"] = function(t)
        local units = {
            nameplate1 = creature(1, "Busy Kobold", {
                lines = {
                    { type = 17, text = "Kobold Trouble" },
                    { type = 8, text = "Kobold slain: 8/8", completed = true },
                    { type = 8, text = "Candle collected: 2/6", completed = false },
                },
            }),
        }
        local world = newWorld({ units = units })
        local found = world.ns.lookup()
        t:assertEqual(#found, 1)
        t:assertEqual(#found[1].objectives, 1)
        t:assertEqual(found[1].objectives[1], "Candle collected: 2/6")
    end,

    ["a creature the game relates to a quest, with no objective line, is kept"] = function(t)
        local units = { nameplate1 = creature(1, "Quiet Kobold", { lines = {} }) }
        local world = newWorld({ units = units })
        t:assertEqual(names(world.ns.lookup()), "Quiet Kobold")
    end,

    ["without the related call, an unfinished objective line is what counts"] = function(t)
        local units = {
            nameplate1 = creature(1, "Needed Kobold"),
            nameplate2 = creature(2, "Done Kobold", { lines = { { type = 8, text = "x: 8/8", completed = true } } }),
            nameplate3 = creature(3, "Plain Wolf", { lines = {} }),
        }
        local world = newWorld({ units = units, noRelated = true })
        t:assertEqual(names(world.ns.lookup()), "Needed Kobold")
    end,

    ["a distance that is not known goes last, ties keep the order of the units"] = function(t)
        local units = {
            nameplate1 = creature(1, "Unknown A", { range = false }),
            nameplate2 = creature(2, "Tie B", { range = { 0, 10 } }),
            nameplate3 = creature(3, "Tie A", { range = { 0, 10 } }),
            nameplate4 = creature(4, "Unknown B", { range = false }),
        }
        units.nameplate1.range, units.nameplate4.range = nil, nil
        local world = newWorld({ units = units })
        t:assertEqual(names(world.ns.lookup()), "Tie B,Tie A,Unknown A,Unknown B")
    end,

    ["the same creature seen as the target and on a plate counts once"] = function(t)
        local units = field()
        local world = newWorld({ units = units })
        world.target = units.nameplate2
        local found = world.ns.lookup()
        t:assertEqual(#found, 3)
        t:assertEqual(found[1].unit, "target", "the first token to see it keeps it")
    end,

    ["a secret answer keeps a creature from being judged, and is counted"] = function(t)
        local units = field()
        units.nameplate4 = creature(4, "Hidden", { related = SECRET })
        units.nameplate5 = creature(5, SECRET, { lines = {} })
        units.nameplate6 = creature(6, "Dead Unknown", { dead = SECRET })
        local world = newWorld({ units = units })
        local found, skipped = world.ns.lookup()
        t:assertEqual(#found, 3)
        t:assertEqual(skipped, 3)
    end,

    ["a secret objective line is left out, a secret completed flag counts as unfinished"] = function(t)
        local units = {
            nameplate1 = creature(1, "Odd Kobold", {
                lines = {
                    { type = 8, text = SECRET, completed = false },
                    { type = 8, text = "Candle collected: 2/6", completed = SECRET },
                },
            }),
        }
        local world = newWorld({ units = units })
        local found = world.ns.lookup()
        t:assertEqual(#found, 1)
        t:assertEqual(found[1].objectives[1], "Candle collected: 2/6")
    end,
})

runner:addSuite("Choosing", {
    ["forward goes to the nearest, then the next one, then round"] = function(t)
        local world = newWorld({ units = field() })
        local candidates = world.ns.lookup()
        local current = nil
        local function is(unit)
            return unit == current
        end
        t:assertEqual((world.ns.Targets.choose(candidates, 1, is)), 1)
        current = candidates[1].unit
        t:assertEqual((world.ns.Targets.choose(candidates, 1, is)), 2)
        current = candidates[2].unit
        t:assertEqual((world.ns.Targets.choose(candidates, 1, is)), 3)
        current = candidates[3].unit
        t:assertEqual((world.ns.Targets.choose(candidates, 1, is)), 1)
    end,

    ["back goes to the farthest, then the one before, then round"] = function(t)
        local world = newWorld({ units = field() })
        local candidates = world.ns.lookup()
        local current = nil
        local function is(unit)
            return unit == current
        end
        t:assertEqual((world.ns.Targets.choose(candidates, -1, is)), 3)
        current = candidates[3].unit
        t:assertEqual((world.ns.Targets.choose(candidates, -1, is)), 2)
        current = candidates[1].unit
        t:assertEqual((world.ns.Targets.choose(candidates, -1, is)), 3)
    end,

    ["with nothing to choose from there is no index"] = function(t)
        local world = newWorld()
        t:assertNil(world.ns.Targets.choose({}, 1, function() return false end))
    end,
})

runner:addSuite("Texts", {
    ["a creature is described by name, distance and what it is needed for"] = function(t)
        local world = newWorld({ units = field() })
        local found = world.ns.lookup()
        t:assertEqual(world.ns.Targets.describe(found[1]), "Near Kobold, within 8 yards, Near Kobold slain: 3/8")
    end,

    ["a creature with only a minimum distance is beyond it"] = function(t)
        local world = newWorld()
        local text = world.ns.Targets.describe({ name = "X", minRange = 40, objectives = {} })
        t:assertEqual(text, "X, beyond 40 yards")
    end,

    ["the list says how many there are, at most five of them"] = function(t)
        local units = {}
        for index = 1, 7 do
            units["nameplate" .. index] = creature(index, "Kobold " .. index, { range = { 0, index } })
        end
        local world = newWorld({ units = units })
        local text = world.ns.Targets.listText((world.ns.lookup()))
        t:assertTrue(contains(text, "7 quest targets: Kobold 1, within 1 yards"), text)
        t:assertTrue(contains(text, "Kobold 5"), text)
        t:assertFalse(contains(text, "Kobold 6"), text)
    end,

    ["one creature is 1 quest target, none is a plain sentence"] = function(t)
        local world = newWorld({ units = { nameplate1 = creature(1, "Lone Kobold") } })
        t:assertTrue(contains(world.ns.Targets.listText((world.ns.lookup())), "1 quest target: Lone Kobold"))
        t:assertEqual(world.ns.Targets.listText({}), "No quest target nearby.")
    end,

    ["French and German texts"] = function(t)
        local fr = newWorld({ units = field(), locale = "frFR" })
        t:assertEqual(
            fr.ns.Targets.describe((fr.ns.lookup())[1]),
            "Near Kobold, à moins de 8 mètres, Near Kobold slain: 3/8"
        )
        t:assertEqual(fr.ns.Targets.listText({}), "Aucune cible de quête à proximité.")
        local de = newWorld({ units = field(), locale = "deDE" })
        t:assertTrue(contains(de.ns.Targets.listText((de.ns.lookup())), "3 Questziele: Near Kobold, innerhalb von 8 Metern"))
    end,
})

runner:addSuite("Keys", {
    ["three bindings are registered with their keys and names"] = function(t)
        local world = newWorld()
        t:assertEqual(#world.bindingOrder, 3)
        local next, previous, list = world.bindings["questTarget/next"], world.bindings["questTarget/previous"], world.bindings["questTarget/list"]
        t:assertEqual(next.inputs[1], "ALT-Q")
        t:assertEqual(previous.inputs[1], "ALT-SHIFT-Q")
        t:assertEqual(list.inputs[1], "ALT-CTRL-Q")
        t:assertEqual(next.label, "Target Next Quest Target")
        t:assertEqual(previous.label, "Target Previous Quest Target")
        t:assertEqual(list.label, "Say Quest Targets Nearby")
        t:assertEqual(next.type, "Click")
        t:assertEqual(list.type, "Function")
        t:assertEqual(next.emulatedKey, "LeftButton")
    end,

    ["each key clicks its own secure target button"] = function(t)
        local world = newWorld()
        local next, previous = world.bindings["questTarget/next"], world.bindings["questTarget/previous"]
        t:assertEqual(next.targetFrame, world.ns.nextButton)
        t:assertEqual(previous.targetFrame, world.ns.previousButton)
        t:assertEqual(world.ns.nextButton:GetAttribute("type"), "target")
        t:assertEqual(world.ns.nextButton:GetAttribute("useOnKeyDown"), false)
        t:assertTrue(world.ns.nextButton ~= world.ns.previousButton)
    end,

    ["the keys are switched on once, after the stores have told the player's keys"] = function(t)
        local world = newWorld()
        for _, key in ipairs(world.bindingOrder) do
            t:assertEqual(world.bindings[key].activations, 1, key)
        end
        t:assertEqual(world.applied, 1)
        world.ns.installBindings()
        t:assertEqual(world.bindings["questTarget/next"].activations, 1, "a second install adds nothing")
        t:assertEqual(world.applied, 1)
    end,

    ["the names are in the player's language"] = function(t)
        local fr = newWorld({ locale = "frFR" })
        t:assertEqual(fr.bindings["questTarget/next"].label, "Cibler la cible de quête suivante")
        t:assertEqual(fr.bindings["questTarget/list"].label, "Dire les cibles de quête proches")
        local de = newWorld({ locale = "deDE" })
        t:assertEqual(de.bindings["questTarget/previous"].label, "Vorheriges Questziel anvisieren")
    end,

    ["the list key says the quest targets"] = function(t)
        local world = newWorld({ units = field() })
        world.bindings["questTarget/list"].func()
        t:assertTrue(contains(world.said(), "3 quest targets: Near Kobold"), world.said())
    end,

    ["without WowVision's input manager nothing is installed and nothing breaks"] = function(t)
        local world = newWorld({ noInput = true })
        t:assertFalse(world.ns.installed)
        t:assertEqual(#world.errors, 0)
    end,
})

runner:addSuite("Targeting", {
    ["the next key targets the nearest quest creature"] = function(t)
        local units = field()
        local world = newWorld({ units = units })
        world.press("next")
        t:assertEqual(world.target.name, "Near Kobold")
    end,

    ["pressing again goes outward, and round at the end"] = function(t)
        local world = newWorld({ units = field() })
        world.press("next")
        t:assertEqual(world.target.name, "Near Kobold")
        world.press("next")
        t:assertEqual(world.target.name, "Mid Kobold")
        world.press("next")
        t:assertEqual(world.target.name, "Far Kobold")
        world.press("next")
        t:assertEqual(world.target.name, "Near Kobold")
    end,

    ["the previous key goes the other way, starting with the farthest"] = function(t)
        local world = newWorld({ units = field() })
        world.press("previous")
        t:assertEqual(world.target.name, "Far Kobold")
        world.press("previous")
        t:assertEqual(world.target.name, "Mid Kobold")
    end,

    ["a target that is not a quest creature starts from the nearest"] = function(t)
        local units = field()
        local world = newWorld({ units = units })
        world.target = creature(99, "Some Wolf", { related = false, lines = {} })
        world.press("next")
        t:assertEqual(world.target.name, "Near Kobold")
    end,

    ["the place in the list is said once the target has changed, but not for a single creature"] = function(t)
        local world = newWorld({ units = field() })
        world.ns.eventsFrame = world.lastFrame
        world.press("next")
        t:assertEqual(world.said(), "1 of 3")
        world.press("next")
        t:assertEqual(world.said(), "2 of 3")
        local lone = newWorld({ units = { nameplate1 = creature(1, "Lone Kobold") } })
        lone.press("next")
        t:assertEqual(#lone.spoken, 0)
        t:assertEqual(lone.target.name, "Lone Kobold")
    end,

    ["the button is aimed only for the click: its unit is cleared afterwards"] = function(t)
        local world = newWorld({ units = field() })
        world.press("next")
        t:assertNil(world.ns.nextButton:GetAttribute("unit"))
    end,

    ["with no quest creature the target stays, and the reason is said"] = function(t)
        local world = newWorld({ units = { nameplate1 = creature(1, "Plain Wolf", { related = false, lines = {} }) } })
        local before = creature(50, "Old Target", { related = false, lines = {} })
        world.target = before
        world.press("next")
        t:assertEqual(world.target, before)
        t:assertEqual(world.said(), "No quest target nearby.")
    end,

    ["with the enemy nameplates off, it turns them on by itself and says so"] = function(t)
        local world = newWorld({ platesOff = true })
        world.press("next")
        t:assertEqual(world.cvars.nameplateShowEnemies, "1")
        t:assertEqual(
            world.said(),
            "Enemy nameplates were off: I turned them on to find the enemies near you. Press again."
        )
        -- now that they are on, the same press finds the creatures
        world.units = field()
        world.press("next")
        t:assertEqual(world.target.name, "Near Kobold")
    end,

    ["the same for the list key"] = function(t)
        local world = newWorld({ platesOff = true })
        world.bindings["questTarget/list"].func()
        t:assertEqual(world.cvars.nameplateShowEnemies, "1")
    end,

    ["with the automatic switch off, it only says how to turn them on"] = function(t)
        local world = newWorld({ platesOff = true })
        world.ns.handleCommand("auto off")
        world.press("next")
        t:assertNil(world.cvars.nameplateShowEnemies)
        t:assertTrue(contains(world.said(), "/wvqt plates"), world.said())
        world.ns.handleCommand("auto on")
        world.press("next")
        t:assertEqual(world.cvars.nameplateShowEnemies, "1")
    end,

    ["it does not touch the settings in combat"] = function(t)
        local world = newWorld({ platesOff = true })
        world.combat = true
        world.press("next")
        t:assertNil(world.cvars.nameplateShowEnemies)
    end,

    ["the list key does not touch the settings in combat either"] = function(t)
        local world = newWorld({ platesOff = true })
        world.combat = true
        world.bindings["questTarget/list"].func()
        t:assertNil(world.cvars.nameplateShowEnemies)
        t:assertTrue(contains(world.said(), "/wvqt plates"), world.said())
    end,

    ["it does not touch the settings when the plates are on but nothing is near"] = function(t)
        local world = newWorld()
        world.press("next")
        t:assertNil(world.cvars.nameplateShowEnemies)
        t:assertEqual(world.said(), "No quest target nearby.")
    end,

    ["a dead quest creature is never targeted, even when it is the nearest or the only one"] = function(t)
        local units = {
            nameplate1 = creature(1, "Fresh Corpse", { dead = true, range = { 0, 2 } }),
        }
        local world = newWorld({ units = units })
        local before = creature(50, "Old Target", { related = false, lines = {} })
        world.target = before
        world.press("next")
        t:assertEqual(world.target, before, "the target did not move to the corpse")
        t:assertEqual(world.said(), "No quest target nearby.")
        units.nameplate2 = creature(2, "Living Kobold", { range = { 0, 30 } })
        world.press("next")
        t:assertEqual(world.target.name, "Living Kobold", "the living one farther away is chosen")
        world.press("previous")
        t:assertEqual(world.target.name, "Living Kobold")
    end,

    ["with hidden values it says the game hides quest targets"] = function(t)
        local world = newWorld({ units = { nameplate1 = creature(1, "Hidden", { related = SECRET }) } })
        world.press("next")
        t:assertEqual(world.said(), "The game hides quest targets in combat.")
    end,

    ["a client that cannot tell which creatures are for quests says so"] = function(t)
        local world = newWorld({ units = field(), noRelated = true, noTooltip = true })
        world.press("next")
        t:assertEqual(world.said(), "This game version cannot tell which creatures belong to your quests.")
    end,

    ["in combat the buttons are left alone and it says so"] = function(t)
        local world = newWorld({ units = field() })
        world.combat = true
        world.press("next")
        t:assertNil(world.target)
        t:assertEqual(world.said(), "Quest targets cannot be picked in combat.")
        t:assertEqual(#world.errors, 0, "no write to a secure frame in combat")
    end,

    ["a failure in looking is reported once and the key does nothing"] = function(t)
        local world = newWorld({ units = field() })
        world.ns.Game.api = function()
            error("boom")
        end
        world.press("next")
        world.press("next")
        t:assertNil(world.target)
        t:assertEqual(#world.errors, 1)
    end,
})

runner:addSuite("Command", {
    ["/wvqt says the quest targets nearby"] = function(t)
        local world = newWorld({ units = field() })
        world.ns.handleCommand("")
        t:assertTrue(contains(world.said(), "3 quest targets"), world.said())
    end,

    ["/wvqt plates turns the enemy nameplates on"] = function(t)
        local world = newWorld({ platesOff = true })
        world.ns.handleCommand("plates")
        t:assertEqual(world.cvars.nameplateShowEnemies, "1")
        t:assertEqual(world.said(), "Enemy nameplates turned on.")
        world.ns.handleCommand("plaques")
        t:assertEqual(world.said(), "Enemy nameplates turned on.")
    end,

    ["/wvqt auto says and sets the automatic switch, in French too"] = function(t)
        local world = newWorld()
        world.ns.handleCommand("auto")
        t:assertEqual(world.said(), "Turning on enemy nameplates by itself: on")
        world.ns.handleCommand("auto off")
        t:assertEqual(world.said(), "Turning on enemy nameplates by itself: off")
        t:assertTrue(world.ns.getSetting("autoPlates") == false)
        local fr = newWorld({ locale = "frFR" })
        fr.ns.handleCommand("auto non")
        t:assertEqual(fr.said(), "Activation automatique des barres de vie des ennemis : désactivé")
    end,

    ["/wvqt auto speaks German and understands ja and nein"] = function(t)
        local de = newWorld({ locale = "deDE" })
        de.ns.handleCommand("automatisch nein")
        t:assertTrue(de.ns.getSetting("autoPlates") == false)
        t:assertTrue(contains(de.said(), ": aus"), de.said())
        de.ns.handleCommand("automatisch ja")
        t:assertTrue(de.ns.getSetting("autoPlates") ~= false)
        t:assertTrue(contains(de.said(), ": an"), de.said())
    end,

    ["any other word gets the usage"] = function(t)
        local world = newWorld()
        world.ns.handleCommand("banana")
        t:assertTrue(contains(world.said(), "/wvqt"), world.said())
    end,

    ["the command speaks French"] = function(t)
        local world = newWorld({ locale = "frFR", platesOff = true })
        world.ns.handleCommand("plaques")
        t:assertEqual(world.said(), "Barres de vie des ennemis activées.")
        world.ns.handleCommand("")
        t:assertEqual(world.said(), "Aucune cible de quête à proximité.")
    end,
})

-- One creature of every kind, each farther than the one before.
local function assorted()
    return {
        nameplate1 = creature(1, "Near Kobold", { range = { 0, 8 } }),
        nameplate2 = creature(2, "A Player", { player = true, range = { 8, 12 } }),
        nameplate3 = creature(3, "Friendly Guard", { attack = false, range = { 12, 15 } }),
        nameplate4 = creature(4, "Dead Kobold", { dead = true, range = { 15, 20 } }),
        nameplate5 = creature(5, "Plain Wolf", { related = false, lines = {}, range = { 20, 25 } }),
        nameplate6 = creature(6, "Done Kobold", {
            lines = { { type = 8, text = "Kobold slain: 8/8", completed = true } },
            range = { 25, 30 },
        }),
    }
end

runner:addSuite("Diagnosis", {
    ["every creature is read out, nearest first, with the reason it was kept or left out"] = function(t)
        local world = newWorld({ units = assorted() })
        world.ns.handleCommand("why")
        t:assertEqual(
            world.said(),
            "Creatures seen: 6. Proposed: 1."
                .. " Near Kobold, within 8 yards: proposed."
                .. " A Player, within 12 yards: a player."
                .. " Friendly Guard, within 15 yards: cannot be attacked."
                .. " Dead Kobold, within 20 yards: dead."
                .. " Plain Wolf, within 25 yards: not for any of your quests."
                .. " Done Kobold, within 30 yards: objectives already complete."
        )
    end,

    ["it is sorted by distance whatever the order of the units"] = function(t)
        local units = {
            nameplate1 = creature(1, "Far Wolf", { related = false, lines = {}, range = { 30, 40 } }),
            nameplate2 = creature(2, "Near Kobold", { range = { 0, 5 } }),
        }
        local world = newWorld({ units = units })
        world.ns.handleCommand("why")
        t:assertTrue(contains(world.said(), "Near Kobold, within 5 yards: proposed. Far Wolf"), world.said())
    end,

    ["a value the game hides is said as such, and so is a hidden name"] = function(t)
        local units = {
            nameplate1 = creature(1, "Hidden", { related = SECRET, range = { 0, 5 } }),
            nameplate2 = creature(2, SECRET, { lines = {}, range = { 5, 9 } }),
        }
        local world = newWorld({ units = units })
        world.ns.handleCommand("why")
        t:assertEqual(
            world.said(),
            "Creatures seen: 2. Proposed: 0."
                .. " Hidden, within 5 yards: values hidden by the game."
                .. " a creature with a hidden name, within 9 yards: values hidden by the game."
        )
    end,

    ["a hidden \"is it a player\" or \"can it be attacked\" is said as hidden, not as a player or a friend"] = function(t)
        local units = {
            nameplate1 = creature(1, "Unknown Kind", { player = SECRET, range = { 0, 5 } }),
            nameplate2 = creature(2, "Unknown Side", { attack = SECRET, range = { 5, 9 } }),
        }
        local world = newWorld({ units = units })
        world.ns.handleCommand("why")
        t:assertEqual(
            world.said(),
            "Creatures seen: 2. Proposed: 0."
                .. " Unknown Kind, within 5 yards: values hidden by the game."
                .. " Unknown Side, within 9 yards: values hidden by the game."
        )
    end,

    ["without the quest link, a creature with no objective and one with finished objectives are told apart"] = function(t)
        local units = {
            nameplate1 = creature(1, "Needed Kobold", { range = { 0, 5 } }),
            nameplate2 = creature(2, "Plain Wolf", { lines = {}, range = { 5, 9 } }),
            nameplate3 = creature(3, "Done Kobold", {
                lines = { { type = 8, text = "x: 8/8", completed = true } },
                range = { 9, 12 },
            }),
        }
        local world = newWorld({ units = units, noRelated = true })
        world.ns.handleCommand("why")
        t:assertTrue(contains(world.said(), "Missing game call: quest link."), world.said())
        t:assertTrue(contains(world.said(), "Needed Kobold, within 5 yards: proposed."), world.said())
        t:assertTrue(contains(world.said(), "Plain Wolf, within 9 yards: no unfinished objective in its tooltip."), world.said())
        t:assertTrue(contains(world.said(), "Done Kobold, within 12 yards: objectives already complete."), world.said())
    end,

    ["only the first six are read, then how many are left"] = function(t)
        local units = {}
        for index = 1, 8 do
            units["nameplate" .. index] = creature(index, "Kobold " .. index, { range = { 0, index } })
        end
        local world = newWorld({ units = units })
        world.ns.handleCommand("why")
        t:assertTrue(contains(world.said(), "Creatures seen: 8. Proposed: 8."), world.said())
        t:assertTrue(contains(world.said(), "Kobold 6, within 6 yards: proposed."), world.said())
        t:assertFalse(contains(world.said(), "Kobold 7"), world.said())
        t:assertTrue(world.said():sub(-12) == " And 2 more.", world.said())
    end,

    ["exactly six creatures leave nothing to add"] = function(t)
        local units = {}
        for index = 1, 6 do
            units["nameplate" .. index] = creature(index, "Kobold " .. index, { range = { 0, index } })
        end
        local world = newWorld({ units = units })
        world.ns.handleCommand("why")
        t:assertFalse(contains(world.said(), "more"), world.said())
    end,

    ["nothing around says what can be seen at all"] = function(t)
        local world = newWorld()
        world.ns.handleCommand("why")
        t:assertEqual(
            world.said(),
            "Creatures seen: 0. Proposed: 0."
                .. " Only your target, the creature under the mouse and the enemy nameplates in range can be seen."
        )
    end,

    ["when everything is in order it adds no remark"] = function(t)
        local world = newWorld({ units = field() })
        world.ns.handleCommand("why")
        t:assertFalse(contains(world.said(), "nameplates are off"), world.said())
        t:assertFalse(contains(world.said(), "combat"), world.said())
        t:assertFalse(contains(world.said(), "Missing"), world.said())
        t:assertFalse(contains(world.said(), "cannot tell"), world.said())
        t:assertFalse(contains(world.said(), "Only your target"), world.said())
    end,

    ["it says when the enemy nameplates are off, and does not turn them on"] = function(t)
        local world = newWorld({ platesOff = true })
        world.ns.handleCommand("why")
        t:assertTrue(contains(world.said(), "Enemy nameplates are off: type /wvqt plates."), world.said())
        t:assertNil(world.cvars.nameplateShowEnemies)
    end,

    ["it says when the player is in combat"] = function(t)
        local world = newWorld({ units = field() })
        world.combat = true
        world.ns.handleCommand("why")
        t:assertTrue(contains(world.said(), "You are in combat."), world.said())
        world.combat = false
        world.ns.handleCommand("why")
        t:assertFalse(contains(world.said(), "You are in combat."), world.said())
    end,

    ["it says which game call is missing"] = function(t)
        local both = newWorld({ units = field(), noRelated = true, noTooltip = true })
        both.ns.handleCommand("why")
        t:assertTrue(contains(both.said(), "This game version cannot tell which creatures belong to your quests."), both.said())
        local tooltip = newWorld({ units = field(), noTooltip = true })
        tooltip.ns.handleCommand("why")
        t:assertTrue(contains(tooltip.said(), "Missing game call: tooltip objectives."), tooltip.said())
        t:assertFalse(contains(tooltip.said(), "quest link"), tooltip.said())
    end,

    ["a creature seen as the target and on a plate counts once"] = function(t)
        local units = field()
        local world = newWorld({ units = units })
        world.target = units.nameplate2
        world.ns.handleCommand("why")
        t:assertTrue(contains(world.said(), "Creatures seen: 3. Proposed: 3."), world.said())
    end,

    ["a friendly target is listed with its reason"] = function(t)
        local world = newWorld({ units = field() })
        world.target = creature(77, "Innkeeper", { attack = false, range = { 0, 4 } })
        world.ns.handleCommand("why")
        t:assertTrue(contains(world.said(), "Innkeeper, within 4 yards: cannot be attacked."), world.said())
    end,

    ["reading it out changes nothing: no target, no button aimed, the same candidates after"] = function(t)
        local world = newWorld({ units = assorted() })
        local before = names(world.ns.lookup())
        world.ns.handleCommand("why")
        t:assertNil(world.target)
        t:assertNil(world.ns.nextButton:GetAttribute("unit"))
        t:assertNil(world.ns.previousButton:GetAttribute("unit"))
        t:assertEqual(names(world.ns.lookup()), before)
    end,

    ["the other names of the command, and the French and German texts"] = function(t)
        for _, word in ipairs({ "why", "pourquoi", "warum", "diagnostic", "diagnose", "WHY" }) do
            local world = newWorld({ units = field() })
            world.ns.handleCommand(word)
            t:assertTrue(contains(world.said(), "Creatures seen: 3"), word .. ": " .. tostring(world.said()))
        end
        local fr = newWorld({ units = assorted(), locale = "frFR" })
        fr.ns.handleCommand("pourquoi")
        t:assertEqual(
            fr.said(),
            "Créatures vues : 6. Proposées : 1."
                .. " Near Kobold, à moins de 8 mètres : proposée."
                .. " A Player, à moins de 12 mètres : un joueur."
                .. " Friendly Guard, à moins de 15 mètres : pas attaquable."
                .. " Dead Kobold, à moins de 20 mètres : morte."
                .. " Plain Wolf, à moins de 25 mètres : ne sert à aucune de vos quêtes."
                .. " Done Kobold, à moins de 30 mètres : objectifs déjà terminés."
        )
        local de = newWorld({ units = assorted(), locale = "deDE" })
        de.ns.handleCommand("warum")
        t:assertTrue(contains(de.said(), "Gesehene Kreaturen: 6. Vorgeschlagen: 1."), de.said())
        t:assertTrue(contains(de.said(), "Dead Kobold, innerhalb von 20 Metern: tot."), de.said())
        t:assertTrue(contains(de.said(), "gehört zu keiner deiner Quests"), de.said())
    end,

    ["a failure while looking is reported once and nothing is said"] = function(t)
        local world = newWorld({ units = field() })
        world.ns.Game.api = function()
            error("boom")
        end
        world.ns.handleCommand("why")
        world.ns.handleCommand("why")
        t:assertEqual(#world.spoken, 0)
        t:assertEqual(#world.errors, 1)
    end,

    ["the usage line mentions the command, in French too"] = function(t)
        local world = newWorld()
        world.ns.handleCommand("banana")
        t:assertTrue(contains(world.said(), "/wvqt why"), world.said())
        local fr = newWorld({ locale = "frFR" })
        fr.ns.handleCommand("banana")
        t:assertTrue(contains(fr.said(), "/wvqt pourquoi"), fr.said())
    end,
})

runner:run()
