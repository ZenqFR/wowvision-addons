-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- The game and WowVision are mocked (the player's health and resource, a binding registry that refuses two bindings
-- on one key like WowVision's, the stores the player's keys are saved in), but the addon's own files are loaded for
-- real, in the order of the .toc. No other addon is needed.

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

local FILES = { "Locale", "Vitals", "Game", "Main" }

local function loadAddon()
    local ns = {}
    for _, name in ipairs(FILES) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_Vitals", ns)
    end
    return ns
end

-- ------------------------------------------------------------ the world

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = deepCopy(inner)
    end
    return copy
end

-- WowVision's own keys that the addon's keys take: the buffer navigation (and a group key that is none of its
-- business).
local function defaultHolders()
    return {
        { key = "buffers/previousBuffer", label = "Previous Buffer", inputs = { "ALT-LEFT" } },
        { key = "buffers/nextBuffer", label = "Next Buffer", inputs = { "ALT-RIGHT" } },
        { key = "buffers/previousGroup", label = "Previous Buffer Group", inputs = { "ALT-CTRL-LEFT" } },
        { key = "buffers/nextGroup", label = "Next Buffer Group", inputs = { "ALT-CTRL-RIGHT" } },
    }
end

-- A fake WowVision (a binding registry like the real one, with the stores) and a fake game around the real addon.
-- config.holders: the bindings WowVision already has. config.globalDb / config.charDB: the saved stores of an
-- earlier session. config.noStore: WowVision has not set the stores up. config.noInput: there is no input manager.
local function newWorld(config)
    config = config or {}
    local world = {
        spoken = {},
        errors = {},
        locale = config.locale or "enUS",
        applied = 0,
        reactivations = 0,
        shared = {},
        keyMap = {},
        health = { 85, 100 },
        power = { 72, 100, "MANA" },
        globalDb = config.globalDb or {},
        charDB = config.charDB or {},
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
    MANA = "Mana"
    RAGE = "Rage"
    UnitHealth = function()
        if world.failing then
            error("boom")
        end
        return world.health[1]
    end
    UnitHealthMax = function()
        return world.health[2]
    end
    UnitPowerType = function()
        return 0, world.power[3]
    end
    UnitPower = function()
        return world.power[1]
    end
    UnitPowerMax = function()
        return world.power[2]
    end

    -- the binding registry: one binding per key, no two bindings on one input
    local input = { bindings = { orderedBindings = {} }, bindingRefs = {} }
    local function conflicts(inputs, except)
        for _, binding in ipairs(input.bindings.orderedBindings) do
            if binding ~= except then
                for _, bound in ipairs(binding.inputs) do
                    for _, key in ipairs(inputs) do
                        if bound == key then
                            return key
                        end
                    end
                end
            end
        end
        return nil
    end
    function input:createBinding(info)
        local clash = conflicts(info.inputs or {})
        if clash ~= nil then
            error("Conflicting input: " .. clash .. ".")
        end
        local binding = { activations = 0 }
        for key, value in pairs(info) do
            binding[key] = value
        end
        binding.inputs = {}
        for _, key in ipairs(info.inputs or {}) do
            tinsert(binding.inputs, key)
        end
        function binding:getLabel()
            return self.label
        end
        function binding:addInput(key)
            local other = conflicts({ key }, self)
            if other ~= nil then
                error("Conflicting input: " .. other .. ".")
            end
            tinsert(self.inputs, key)
        end
        function binding:removeInput(key)
            for index, bound in ipairs(self.inputs) do
                if bound == key then
                    table.remove(self.inputs, index)
                    return
                end
            end
        end
        function binding:activate()
            self.activations = self.activations + 1
        end
        tinsert(input.bindings.orderedBindings, binding)
        input.bindingRefs[binding.key] = binding
        return binding
    end
    function input:getBinding(key)
        return input.bindingRefs[key]
    end
    function input:getDefaultDB()
        local defaults = {}
        for _, binding in ipairs(input.bindings.orderedBindings) do
            defaults[binding.key] = { inputs = deepCopy(binding.inputs) }
        end
        return defaults
    end

    local dbManager = {}
    -- stored keys win over the defaults, missing ones are added from them
    function dbManager.resolveBindings(_, defaults, charDB, globalDB)
        charDB.bindings = charDB.bindings or {}
        globalDB.bindings = globalDB.bindings or {}
        for key, default in pairs(defaults) do
            if charDB.bindings[key] == nil then
                charDB.bindings[key] = deepCopy(default)
            end
            if globalDB.bindings[key] == nil then
                globalDB.bindings[key] = deepCopy(default)
            end
        end
        if charDB.bindingScope == "char" then
            return charDB.bindings
        end
        return globalDB.bindings
    end

    WowVisionDB = world.charDB
    WowVision = {
        speak = function(_, text)
            tinsert(world.spoken, text)
        end,
        isSecret = function(value)
            return value == SECRET
        end,
        input = input,
        dbManager = dbManager,
        globalDb = world.globalDb,
    }
    -- every binding is switched on again for the keys it holds (a key two bindings hold is left to the last one, and
    -- noted in world.shared)
    function input.bindings:reactivateAll()
        world.reactivations = world.reactivations + 1
        world.keyMap = {}
        world.shared = {}
        for _, binding in ipairs(input.bindings.orderedBindings) do
            for _, key in ipairs(binding.inputs) do
                if world.keyMap[key] ~= nil then
                    world.shared[key] = true
                end
                world.keyMap[key] = binding.key
            end
        end
    end
    -- the stores bind their keys to the bindings, then every binding is switched on again
    function WowVision:applyBindingStore(store)
        world.applied = world.applied + 1
        for _, binding in ipairs(input.bindings.orderedBindings) do
            local saved = store[binding.key]
            if saved ~= nil then
                binding.inputs = saved.inputs
            end
        end
        input.bindings:reactivateAll()
    end
    -- WoW: Forever hands the account's saved keys over after the addons have loaded: WowVision binds that store
    function world.rebind(globalDb)
        world.globalDb = globalDb
        WowVision.globalDb = globalDb
        WowVision:applyBindingStore(dbManager:resolveBindings(input:getDefaultDB(), world.charDB, globalDb))
    end
    if config.noInput then
        WowVision.input = nil
    end

    -- WowVision's own start: its bindings exist, then the stores are set up
    for _, info in ipairs(config.holders or defaultHolders()) do
        input:createBinding({ type = "Function", key = info.key, label = info.label, inputs = info.inputs })
    end
    if not config.noStore and not config.noInput then
        local store = dbManager:resolveBindings(input:getDefaultDB(), world.charDB, world.globalDb)
        WowVision:applyBindingStore(store)
        world.applied = 0
    end
    world.ns = loadAddon()
    function world.said()
        return world.spoken[#world.spoken]
    end
    function world.store()
        return world.globalDb.bindings
    end
    return world
end

local function contains(text, part)
    return text:find(part, 1, true) ~= nil
end

-- ------------------------------------------------------------------ tests

runner:addSuite("Percent", {
    ["a plain percentage"] = function(t)
        local world = newWorld()
        local percent = world.ns.Vitals.percent
        t:assertEqual(percent(85, 100), 85)
        t:assertEqual(percent(1, 3), 33)
        t:assertEqual(percent(2, 3), 67)
        t:assertEqual(percent(8500, 10000), 85)
    end,

    ["empty and full are exact"] = function(t)
        local percent = newWorld().ns.Vitals.percent
        t:assertEqual(percent(0, 100), 0)
        t:assertEqual(percent(100, 100), 100)
    end,

    ["it never says 0 while there is something left"] = function(t)
        local percent = newWorld().ns.Vitals.percent
        t:assertEqual(percent(1, 1000), 1)
        t:assertEqual(percent(4, 1000), 1)
    end,

    ["it never says 100 while something is missing"] = function(t)
        local percent = newWorld().ns.Vitals.percent
        t:assertEqual(percent(999, 1000), 99)
        t:assertEqual(percent(996, 1000), 99)
    end,

    ["more than the maximum reads as 100"] = function(t)
        local percent = newWorld().ns.Vitals.percent
        t:assertEqual(percent(1200, 1000), 100)
    end,

    ["a negative value reads as 0"] = function(t)
        local percent = newWorld().ns.Vitals.percent
        t:assertEqual(percent(-5, 100), 0)
    end,

    ["no maximum, or something that is not a number, is nothing"] = function(t)
        local percent = newWorld().ns.Vitals.percent
        t:assertNil(percent(10, 0))
        t:assertNil(percent(10, -1))
        t:assertNil(percent(nil, 100))
        t:assertNil(percent(10, nil))
        t:assertNil(percent("10", 100))
    end,
})

runner:addSuite("Texts", {
    ["the health in percent"] = function(t)
        local world = newWorld()
        world.ns.say("health")
        t:assertEqual(world.said(), "Health 85 percent")
    end,

    ["the mana in percent, with the game's name for it"] = function(t)
        local world = newWorld()
        world.ns.say("power")
        t:assertEqual(world.said(), "Mana 72 percent")
    end,

    ["another resource is named by the game too"] = function(t)
        local world = newWorld()
        world.power = { 30, 100, "RAGE" }
        world.ns.say("power")
        t:assertEqual(world.said(), "Rage 30 percent")
    end,

    ["a resource the game has no name for is called a resource"] = function(t)
        local world = newWorld()
        world.power = { 50, 200, "STRANGE_POWER" }
        world.ns.say("power")
        t:assertEqual(world.said(), "Resource 25 percent")
        world.power = { 50, 200, nil }
        world.ns.say("power")
        t:assertEqual(world.said(), "Resource 25 percent")
    end,

    ["a character with no resource gets a plain sentence"] = function(t)
        local world = newWorld()
        world.power = { 0, 0, "MANA" }
        world.ns.say("power")
        t:assertEqual(world.said(), "No resource to read.")
    end,

    ["a value the game hides is said as hidden"] = function(t)
        local world = newWorld()
        world.health = { SECRET, 100 }
        world.ns.say("health")
        t:assertEqual(world.said(), "The game hides this value.")
        world.health = { 50, SECRET }
        world.ns.say("health")
        t:assertEqual(world.said(), "The game hides this value.")
        world.power = { SECRET, 100, "MANA" }
        world.ns.say("power")
        t:assertEqual(world.said(), "The game hides this value.")
        world.power = { 50, SECRET, "MANA" }
        world.ns.say("power")
        t:assertEqual(world.said(), "The game hides this value.")
    end,

    ["a hidden resource name is said as hidden, and is not looked up"] = function(t)
        local world = newWorld()
        world.power = { 50, 100, SECRET }
        world.ns.say("power")
        t:assertEqual(world.said(), "The game hides this value.")
        t:assertEqual(#world.errors, 0)
    end,

    ["both, for the command"] = function(t)
        local world = newWorld()
        world.ns.say()
        t:assertEqual(world.said(), "Health 85 percent and Mana 72 percent")
    end,

    ["a failure in the game's calls is reported once and the player hears something"] = function(t)
        local world = newWorld()
        world.failing = true
        world.ns.say("health")
        world.ns.say("health")
        t:assertEqual(world.said(), "Nothing to read.")
        t:assertEqual(#world.spoken, 2)
        t:assertEqual(#world.errors, 1)
    end,

    ["French and German"] = function(t)
        local fr = newWorld({ locale = "frFR" })
        fr.ns.say("health")
        t:assertEqual(fr.said(), "Vie 85 pour cent")
        fr.ns.say("power")
        t:assertEqual(fr.said(), "Mana 72 pour cent")
        fr.ns.say()
        t:assertEqual(fr.said(), "Vie 85 pour cent. Mana 72 pour cent")
        fr.power = { 0, 0, "MANA" }
        fr.ns.say("power")
        t:assertEqual(fr.said(), "Aucune ressource à lire.")
        fr.health = { SECRET, 100 }
        fr.ns.say("health")
        t:assertEqual(fr.said(), "Le jeu cache cette valeur.")
        local de = newWorld({ locale = "deDE" })
        de.ns.say("health")
        t:assertEqual(de.said(), "Leben 85 Prozent")
        de.ns.say("power")
        t:assertEqual(de.said(), "Mana 72 Prozent")
    end,
})

runner:addSuite("Keys", {
    ["two bindings are registered, on Alt+Left and Alt+Right"] = function(t)
        local world = newWorld()
        local health, power = world.store()["vitals/health"], world.store()["vitals/power"]
        t:assertEqual(health.inputs[1], "ALT-LEFT")
        t:assertEqual(power.inputs[1], "ALT-RIGHT")
        local input = WowVision.input
        t:assertEqual(input:getBinding("vitals/health").type, "Function")
        t:assertEqual(input:getBinding("vitals/health").interruptSpeech, true)
        t:assertEqual(input:getBinding("vitals/power").type, "Function")
        t:assertEqual(input:getBinding("vitals/health").label, "Say Health Percent")
        t:assertEqual(input:getBinding("vitals/power").label, "Say Power Percent")
    end,

    ["the keys say the health and the mana"] = function(t)
        local world = newWorld()
        WowVision.input:getBinding("vitals/health").func()
        t:assertEqual(world.said(), "Health 85 percent")
        WowVision.input:getBinding("vitals/power").func()
        t:assertEqual(world.said(), "Mana 72 percent")
    end,

    ["the names are in the player's language"] = function(t)
        newWorld({ locale = "frFR" })
        t:assertEqual(WowVision.input:getBinding("vitals/health").label, "Dire la vie en pourcentage")
        t:assertEqual(WowVision.input:getBinding("vitals/power").label, "Dire la mana ou la ressource en pourcentage")
        newWorld({ locale = "deDE" })
        t:assertEqual(WowVision.input:getBinding("vitals/health").label, "Leben in Prozent ansagen")
    end,

    ["the first time, the buffer keys move to Alt+Shift+Left and Alt+Shift+Right"] = function(t)
        local world = newWorld()
        t:assertEqual(world.keyMap["ALT-LEFT"], "vitals/health")
        t:assertEqual(world.keyMap["ALT-RIGHT"], "vitals/power")
        t:assertEqual(world.keyMap["ALT-SHIFT-LEFT"], "buffers/previousBuffer")
        t:assertEqual(world.keyMap["ALT-SHIFT-RIGHT"], "buffers/nextBuffer")
        t:assertEqual(#world.errors, 0)
    end,

    ["the move is saved with the player's keys"] = function(t)
        local world = newWorld()
        t:assertEqual(world.store()["buffers/previousBuffer"].inputs[1], "ALT-SHIFT-LEFT")
        t:assertEqual(#world.store()["buffers/previousBuffer"].inputs, 1)
        t:assertEqual(world.store()["buffers/nextBuffer"].inputs[1], "ALT-SHIFT-RIGHT")
        t:assertEqual(#world.store()["buffers/nextBuffer"].inputs, 1)
    end,

    ["the other buffer keys are left alone"] = function(t)
        local world = newWorld()
        t:assertEqual(world.keyMap["ALT-CTRL-LEFT"], "buffers/previousGroup")
        t:assertEqual(world.keyMap["ALT-CTRL-RIGHT"], "buffers/nextGroup")
        t:assertEqual(world.store()["buffers/previousGroup"].inputs[1], "ALT-CTRL-LEFT")
    end,

    ["the keys are switched on once, after the stores have told the player's keys"] = function(t)
        local world = newWorld()
        t:assertEqual(WowVision.input:getBinding("vitals/health").activations, 1)
        t:assertEqual(WowVision.input:getBinding("vitals/power").activations, 1)
        t:assertEqual(world.applied, 1)
        world.ns.installBindings()
        t:assertEqual(WowVision.input:getBinding("vitals/health").activations, 1, "a second install adds nothing")
        t:assertEqual(world.applied, 1)
    end,

    ["the next start finds everything where it was left, and moves nothing again"] = function(t)
        local first = newWorld()
        local second = newWorld({ globalDb = first.globalDb, charDB = first.charDB })
        t:assertEqual(#second.errors, 0)
        t:assertEqual(second.keyMap["ALT-LEFT"], "vitals/health")
        t:assertEqual(second.keyMap["ALT-RIGHT"], "vitals/power")
        t:assertEqual(second.keyMap["ALT-SHIFT-LEFT"], "buffers/previousBuffer")
        t:assertEqual(second.keyMap["ALT-SHIFT-RIGHT"], "buffers/nextBuffer")
        t:assertEqual(#second.store()["buffers/previousBuffer"].inputs, 1)
    end,

    ["a player who gave Alt+Left back to the buffers keeps it, with no error"] = function(t)
        local first = newWorld()
        -- in the Bindings screen: the key is taken off the health key and given back to the previous buffer
        local store = first.store()
        store["vitals/health"].inputs = {}
        store["buffers/previousBuffer"].inputs = { "ALT-LEFT" }
        local second = newWorld({ globalDb = first.globalDb, charDB = first.charDB })
        t:assertEqual(#second.errors, 0, second.errors[1])
        t:assertEqual(second.keyMap["ALT-LEFT"], "buffers/previousBuffer")
        t:assertEqual(#second.store()["vitals/health"].inputs, 0)
        t:assertEqual(second.keyMap["ALT-RIGHT"], "vitals/power")
    end,

    ["a key another binding holds is not taken, and it is reported"] = function(t)
        local world = newWorld({
            holders = {
                { key = "other/thing", label = "Other Thing", inputs = { "ALT-LEFT" } },
                { key = "buffers/nextBuffer", label = "Next Buffer", inputs = { "ALT-RIGHT" } },
            },
        })
        t:assertEqual(world.keyMap["ALT-LEFT"], "other/thing")
        t:assertEqual(#world.store()["vitals/health"].inputs, 0)
        t:assertEqual(#world.errors, 1)
        t:assertTrue(contains(world.errors[1], "Other Thing already has ALT-LEFT"), world.errors[1])
        t:assertEqual(world.keyMap["ALT-RIGHT"], "vitals/power", "the other key is still taken")
    end,

    ["when the place the buffer key would move to is taken, nothing moves"] = function(t)
        local world = newWorld({
            holders = {
                { key = "buffers/previousBuffer", label = "Previous Buffer", inputs = { "ALT-LEFT" } },
                { key = "some/thing", label = "Some Thing", inputs = { "ALT-SHIFT-LEFT" } },
            },
        })
        t:assertEqual(world.keyMap["ALT-LEFT"], "buffers/previousBuffer")
        t:assertEqual(world.keyMap["ALT-SHIFT-LEFT"], "some/thing")
        t:assertEqual(#world.store()["vitals/health"].inputs, 0)
        t:assertEqual(#world.errors, 1)
    end,

    ["a key held by some other binding than the buffers' own is not moved either"] = function(t)
        local world = newWorld({
            holders = {
                { key = "buffers/nextBuffer", label = "Next Buffer", inputs = { "ALT-LEFT" } },
            },
        })
        t:assertEqual(world.keyMap["ALT-LEFT"], "buffers/nextBuffer")
        t:assertEqual(#world.store()["vitals/health"].inputs, 0)
    end,

    ["a character with keys of its own is judged by those"] = function(t)
        local charDB = { bindingScope = "char", bindings = {} }
        -- the character's keys already hold the addon's keys, the account's do not
        charDB.bindings["vitals/health"] = { inputs = {} }
        charDB.bindings["vitals/power"] = { inputs = {} }
        local world = newWorld({ charDB = charDB })
        t:assertEqual(world.keyMap["ALT-LEFT"], "buffers/previousBuffer", "not moved: not the first time")
        t:assertEqual(world.keyMap["ALT-RIGHT"], "buffers/nextBuffer")
        t:assertEqual(world.charDB.bindings["buffers/previousBuffer"].inputs[1], "ALT-LEFT")
        t:assertEqual(#world.errors, 0)
    end,

    ["with no store to save the move in, nothing moves"] = function(t)
        local world = newWorld({ noStore = true })
        t:assertEqual(world.keyMap["ALT-LEFT"], "buffers/previousBuffer")
        local holder = WowVision.input:getBinding("buffers/previousBuffer")
        t:assertEqual(holder.inputs[1], "ALT-LEFT")
        t:assertEqual(#WowVision.input:getBinding("vitals/health").inputs, 0)
        t:assertEqual(#world.errors, 2)
    end,

    ["without WowVision's input manager nothing is installed and nothing breaks"] = function(t)
        local world = newWorld({ noInput = true })
        t:assertFalse(world.ns.installed)
        t:assertEqual(#world.errors, 0)
    end,
})

-- The account's saved keys, as they are before this addon was ever there.
local function accountKeys()
    return {
        bindings = {
            ["buffers/previousBuffer"] = { inputs = { "ALT-LEFT" } },
            ["buffers/nextBuffer"] = { inputs = { "ALT-RIGHT" } },
            ["buffers/previousGroup"] = { inputs = { "ALT-CTRL-LEFT" } },
            ["buffers/nextGroup"] = { inputs = { "ALT-CTRL-RIGHT" } },
        },
    }
end

runner:addSuite("Late store", {
    ["the account's keys handed over after login do not leave two bindings on one key"] = function(t)
        local world = newWorld()
        local adopted = accountKeys()
        world.rebind(adopted)
        t:assertEqual(next(world.shared), nil, "no key is held twice")
        t:assertEqual(world.keyMap["ALT-LEFT"], "vitals/health")
        t:assertEqual(world.keyMap["ALT-RIGHT"], "vitals/power")
        t:assertEqual(world.keyMap["ALT-SHIFT-LEFT"], "buffers/previousBuffer")
        t:assertEqual(world.keyMap["ALT-SHIFT-RIGHT"], "buffers/nextBuffer")
        t:assertEqual(adopted.bindings["buffers/previousBuffer"].inputs[1], "ALT-SHIFT-LEFT", "and it is saved there")
        t:assertEqual(#adopted.bindings["buffers/previousBuffer"].inputs, 1)
        t:assertEqual(adopted.bindings["vitals/health"].inputs[1], "ALT-LEFT")
        t:assertEqual(#world.errors, 0)
    end,

    ["a key the player gave back to the buffers stays with them when the account's keys arrive"] = function(t)
        local world = newWorld()
        local adopted = accountKeys()
        adopted.bindings["vitals/health"] = { inputs = {} }
        world.rebind(adopted)
        t:assertEqual(world.keyMap["ALT-LEFT"], "buffers/previousBuffer")
        t:assertEqual(adopted.bindings["buffers/previousBuffer"].inputs[1], "ALT-LEFT")
        t:assertEqual(next(world.shared), nil)
        t:assertEqual(#world.errors, 0)
    end,

    ["keys that are already in order are left as they are"] = function(t)
        local world = newWorld()
        local adopted = accountKeys()
        adopted.bindings["buffers/previousBuffer"].inputs = { "ALT-SHIFT-LEFT" }
        adopted.bindings["buffers/nextBuffer"].inputs = { "ALT-SHIFT-RIGHT" }
        adopted.bindings["vitals/health"] = { inputs = { "ALT-LEFT" } }
        adopted.bindings["vitals/power"] = { inputs = { "ALT-RIGHT" } }
        local before = world.reactivations
        world.rebind(adopted)
        t:assertEqual(world.reactivations, before + 1, "one reactivation, the store's own")
        t:assertEqual(world.keyMap["ALT-LEFT"], "vitals/health")
        t:assertEqual(world.keyMap["ALT-SHIFT-LEFT"], "buffers/previousBuffer")
    end,

    ["the store is bound once per hand-over: the wrapper does not stack"] = function(t)
        local world = newWorld()
        local before = world.applied
        t:assertFalse(world.ns.watchStores(), "a second call wraps nothing")
        world.rebind(accountKeys())
        t:assertEqual(world.applied, before + 1)
    end,

    ["another binding on the key is not moved, and the clash is reported once"] = function(t)
        local world = newWorld({
            holders = {
                { key = "other/thing", label = "Other Thing", inputs = { "ALT-LEFT" } },
                { key = "buffers/nextBuffer", label = "Next Buffer", inputs = { "ALT-RIGHT" } },
            },
        })
        local adopted = {
            bindings = {
                ["other/thing"] = { inputs = { "ALT-LEFT" } },
                ["vitals/health"] = { inputs = { "ALT-LEFT" } },
            },
        }
        world.rebind(adopted)
        world.rebind(adopted)
        t:assertEqual(adopted.bindings["other/thing"].inputs[1], "ALT-LEFT")
        local clashes = 0
        for _, err in ipairs(world.errors) do
            if contains(err, "Other Thing and Say Health Percent both have ALT-LEFT") then
                clashes = clashes + 1
            end
        end
        t:assertEqual(clashes, 1)
    end,

    ["when the place to move to is taken, nothing moves and the clash is reported"] = function(t)
        local world = newWorld({
            holders = {
                { key = "buffers/previousBuffer", label = "Previous Buffer", inputs = { "ALT-LEFT" } },
                { key = "some/thing", label = "Some Thing", inputs = { "ALT-SHIFT-LEFT" } },
            },
        })
        local adopted = {
            bindings = {
                ["buffers/previousBuffer"] = { inputs = { "ALT-LEFT" } },
                ["some/thing"] = { inputs = { "ALT-SHIFT-LEFT" } },
                ["vitals/health"] = { inputs = { "ALT-LEFT" } },
            },
        }
        world.rebind(adopted)
        t:assertEqual(adopted.bindings["buffers/previousBuffer"].inputs[1], "ALT-LEFT")
        t:assertEqual(world.keyMap["ALT-SHIFT-LEFT"], "some/thing")
        local found = false
        for _, err in ipairs(world.errors) do
            if contains(err, "both have ALT-LEFT") then
                found = true
            end
        end
        t:assertTrue(found)
    end,

    ["a failure in the repair is reported, and the store is bound all the same"] = function(t)
        local world = newWorld()
        local adopted = accountKeys()
        WowVision.input:getBinding("buffers/previousBuffer").removeInput = function()
            error("boom")
        end
        local before = world.applied
        world.rebind(adopted)
        t:assertEqual(world.applied, before + 1)
        t:assertEqual(#world.errors, 1)
        t:assertTrue(contains(world.errors[1], "boom"), world.errors[1])
    end,

    ["the moved keys work: the key says the health"] = function(t)
        local world = newWorld()
        world.rebind(accountKeys())
        t:assertEqual(world.keyMap["ALT-LEFT"], "vitals/health")
        WowVision.input:getBinding(world.keyMap["ALT-LEFT"]).func()
        t:assertEqual(world.said(), "Health 85 percent")
    end,
})

runner:addSuite("Command", {
    ["/wvvitals says the health and the mana"] = function(t)
        local world = newWorld()
        SlashCmdList.WVVITALS()
        t:assertEqual(world.said(), "Health 85 percent and Mana 72 percent")
        t:assertEqual(SLASH_WVVITALS1, "/wvvitals")
        t:assertEqual(SLASH_WVVITALS2, "/wvvie")
    end,
})

SlashCmdList = {}
runner:run()
