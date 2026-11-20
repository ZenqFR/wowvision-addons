-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- The game and WowVision's maps are mocked; WowVision's own target finder (core/navigation/targetFind.lua) is loaded
-- for real, so the tests run the code that decides where a target stands. They need WowVision next to this addon
-- (../WowVision), or WOWVISION_DIR pointing to it.

local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local wowVision = os.getenv("WOWVISION_DIR") or (addonDir .. "/../WowVision")

unpack = unpack or table.unpack
tinsert = table.insert

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

-- ------------------------------------------------------------------- world

local GUIDS = {
    peon = "Creature-0-1465-0-2105-10556-000043F59F",
    boar = "Creature-0-1465-0-2105-3098-000043F5A0",
    friend = "Player-1465-0A1B2C3D",
}

-- A fresh game, a fresh WowVision and fresh addon files. config:
--   target = { name, guid, unit? (the party unit it is), self? }, none for no target
--   player = { x, y }, noPlayer, catalog = { [creatureId] = row }, noEngine, units = { party1 = { x, y } },
--   locale, noMaps, noTargetFind, noInput, secretGuid
local function newWorld(config)
    config = config or {}
    local w = {
        spoken = {},
        directs = {},
        cancels = 0,
        errors = {},
        tickers = {},
        bindings = {},
        hooks = {},
        units = config.units or {},
        target = config.target,
        player = config.player or { x = 100, y = 200 },
        catalog = config.catalog or {},
    }
    local identity = setmetatable({}, {
        __index = function(_, key)
            return key
        end,
    })

    geterrorhandler = function()
        return function(err)
            tinsert(w.errors, tostring(err))
        end
    end
    GetLocale = function()
        return config.locale or "enUS"
    end
    hooksecurefunc = function(target, name, hook)
        local original = target[name]
        target[name] = function(...)
            local result = original(...)
            hook(...)
            return result
        end
    end
    C_Timer = {
        After = function(_, fn)
            fn()
        end,
        NewTicker = function(_, fn)
            tinsert(w.tickers, fn)
            return {}
        end,
    }
    CreateFrame = nil
    SlashCmdList = {}
    SLASH_WVTARGETDIRECTION1, SLASH_WVTARGETDIRECTION2, SLASH_WVTARGETDIRECTION3 = nil, nil, nil
    WowVisionDB = {}

    -- the game's units
    local function groupUnitOfTarget()
        return w.target ~= nil and w.target.unit or nil
    end
    UnitPosition = function(unit)
        if unit == "player" then
            if config.noPlayer then
                return nil
            end
            return w.player.x, w.player.y, 0, 1
        end
        local at = w.units[unit]
        if at ~= nil then
            return at.x, at.y, 0, 1
        end
        return nil
    end
    UnitExists = function(unit)
        if unit == "target" then
            return w.target ~= nil
        end
        return w.units[unit] ~= nil
    end
    UnitIsUnit = function(a, b)
        if a == "target" and b == "player" then
            return w.target ~= nil and w.target.self == true
        end
        if b == "target" then
            return a == groupUnitOfTarget()
        end
        return a == b
    end
    UnitName = function()
        return w.target ~= nil and w.target.name or nil
    end
    UnitGUID = function()
        if config.secretGuid then
            return "<secret>"
        end
        return w.target ~= nil and w.target.guid or nil
    end
    IsInRaid = function()
        return false
    end
    GetNumGroupMembers = function()
        local count = 0
        for _ in pairs(w.units) do
            count = count + 1
        end
        return count
    end

    -- WowVision
    local engine = {
        unitTarget = function(_, creatureId)
            return w.catalog[creatureId]
        end,
        startAt = function()
            return {}
        end,
    }
    w.maps = {
        guiding = false,
        activeRouteEngine = function()
            if config.noEngine then
                return nil
            end
            return engine
        end,
        currentWaypoints = function()
            return {}
        end,
        directTo = function(self, x, y, label)
            tinsert(w.directs, { x, y, label })
            self.guiding = true
        end,
        whereText = function(_, x, y)
            local dx, dy = x - w.player.x, y - w.player.y
            return string.format("%d yards, ahead left", math.floor(math.sqrt(dx * dx + dy * dy) + 0.5))
        end,
        isGuiding = function(self)
            return self.guiding
        end,
        cancelNavigation = function(self)
            w.cancels = w.cancels + 1
            self.guiding = false
        end,
    }
    local input = { byKey = {} }
    function input:getBinding(key)
        return self.byKey[key]
    end
    function input:getDefaultDB()
        return {}
    end
    function input:createBinding(info)
        local binding = { info = info, activated = 0 }
        function binding:activate()
            self.activated = self.activated + 1
        end
        self.byKey[info.key] = binding
        tinsert(w.bindings, binding)
        return binding
    end
    WowVision = {
        isSecret = function(value)
            return value == "<secret>"
        end,
        speak = function(_, text)
            tinsert(w.spoken, text)
        end,
        getLocale = function()
            return identity
        end,
        utils = {
            foldCase = function(text)
                return text:lower()
            end,
        },
        Router = {
            nearest = function()
                return {}
            end,
        },
        dbManager = {
            resolveBindings = function()
                return {}
            end,
        },
        applyBindingStore = function() end,
        globalDb = {},
        base = { navigation = { maps = (not config.noMaps) and w.maps or nil } },
        input = (not config.noInput) and input or nil,
    }
    if not config.noTargetFind then
        assert(loadfile(wowVision .. "/core/navigation/targetFind.lua"))()
    end

    -- the addon
    local ns = {}
    for _, name in ipairs({ "Locale", "Target", "Main" }) do
        assert(loadfile(addonDir .. "/" .. name .. ".lua"))("WowVision_TargetDirection", ns)
    end
    w.ns = ns
    function w.tick()
        for _, ticker in ipairs(w.tickers) do
            ticker()
        end
    end
    function w.said()
        return w.spoken[#w.spoken]
    end
    function w.press()
        return w.bindings[1].info.func()
    end
    return w
end

local function creature(name, guid)
    return { name = name, guid = guid }
end

local PEON_ROW = { x = 130, y = 240, z = 0, n = "Lazy Peon" }

-- ------------------------------------------------------------------- tests

test("the key is registered: Ctrl+C, labelled, activated, in the Bindings screen", function()
    local w = newWorld()
    eq(w.ns.installed, true)
    local binding = w.bindings[1]
    eq(binding.info.key, "targetdirection/toggle")
    eq(binding.info.type, "Function")
    eq(binding.info.inputs[1], "CTRL-C")
    eq(binding.info.label, "Beacon Toward Your Target")
    eq(binding.activated, 1)
    eq(#w.bindings, 1)
end)

test("the key is not registered twice", function()
    local w = newWorld()
    w.ns.installBindings()
    eq(#w.bindings, 1)
end)

test("without WowVision's input manager there is no key, and no error", function()
    local w = newWorld({ noInput = true })
    eq(w.ns.installed, false)
    eq(#w.errors, 0)
end)

test("no target: it says so", function()
    local w = newWorld()
    w.press()
    eq(w.said(), "You have no target.")
    eq(#w.directs, 0)
end)

test("the player as target: it says so", function()
    local w = newWorld({ target = { name = "Me", guid = GUIDS.friend, self = true } })
    w.press()
    eq(w.said(), "You are targeting yourself.")
    eq(#w.directs, 0)
end)

test("no position for the player: it says so", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), noPlayer = true })
    w.press()
    eq(w.said(), "Position unavailable.")
end)

test("a creature WowNav knows: it says where, and aims the beacon at the spot WowNav has", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    w.press()
    eq(w.spoken[1], "Lazy Peon, 50 yards, ahead left")
    eq(#w.directs, 1)
    eq(w.directs[1][1], 130)
    eq(w.directs[1][2], 240)
    eq(w.directs[1][3], "Lazy Peon")
    check(w.ns.following ~= nil)
end)

test("a creature WowNav does not know: its position is not known, no beacon", function()
    local w = newWorld({ target = creature("Wild Boar", GUIDS.boar), catalog = { [10556] = PEON_ROW } })
    w.press()
    eq(w.said(), "Your target's position is not known.")
    eq(#w.directs, 0)
    eq(w.ns.following, nil)
end)

test("without a route engine, WowVision's route data stand in, as for its own route key", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), noEngine = true })
    w.press()
    eq(w.said(), "Your target's position is not known.")
end)

test("a group member: the live position, and the unit is kept", function()
    local w = newWorld({
        target = { name = "Friend", guid = GUIDS.friend, unit = "party1" },
        units = { party1 = { x = 110, y = 230 } },
    })
    w.press()
    eq(w.spoken[1], "Friend, 32 yards, ahead left")
    eq(w.directs[1][1], 110)
    eq(w.directs[1][2], 230)
    eq(w.ns.following.unit, "party1")
end)

test("pressed again on the same target it ends, and says so", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    w.press()
    w.press()
    eq(w.cancels, 1)
    eq(w.said(), "Guidance stopped.")
    eq(w.ns.following, nil)
    eq(#w.directs, 1)
end)

test("pressed with no target while it guides, it ends", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    w.press()
    w.target = nil
    w.press()
    eq(w.cancels, 1)
    eq(w.said(), "Guidance stopped.")
end)

test("pressed on another target it aims at that one instead", function()
    local w = newWorld({
        target = creature("Lazy Peon", GUIDS.peon),
        catalog = { [10556] = PEON_ROW, [3098] = { x = 90, y = 160, n = "Wild Boar" } },
    })
    w.press()
    w.target = creature("Wild Boar", GUIDS.boar)
    w.press()
    eq(w.cancels, 0)
    eq(#w.directs, 2)
    eq(w.directs[2][3], "Wild Boar")
    eq(w.spoken[2], "Wild Boar, 41 yards, ahead left")
    eq(w.ns.following.n, "Wild Boar")
end)

test("a group member whose GUID the game keeps back is still the same target: pressed again it ends", function()
    local w = newWorld({
        target = { name = "Friend", guid = GUIDS.friend, unit = "party1" },
        units = { party1 = { x = 110, y = 230 } },
        secretGuid = true,
    })
    w.press()
    eq(#w.directs, 1)
    w.press()
    eq(w.cancels, 1)
    eq(w.said(), "Guidance stopped.")
end)

test("a group member with a secret GUID, then another one: the beacon goes to the other", function()
    local w = newWorld({
        target = { name = "Friend", guid = GUIDS.friend, unit = "party1" },
        units = { party1 = { x = 110, y = 230 }, party2 = { x = 50, y = 50 } },
        secretGuid = true,
    })
    w.press()
    w.target = { name = "Other", guid = GUIDS.friend, unit = "party2" }
    w.press()
    eq(w.cancels, 0)
    eq(#w.directs, 2)
    eq(w.directs[2][1], 50)
end)

test("a secret GUID is never taken for the same target", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW }, secretGuid = true })
    w.press()
    -- the creature cannot be told from its GUID: nothing starts
    eq(#w.directs, 0)
    eq(w.said(), "Your target's position is not known.")
end)

test("WowVision's own cancel (Shift+F12) ends the following", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    w.press()
    w.maps:cancelNavigation()
    eq(w.ns.following, nil)
    -- and the next press starts again instead of stopping
    w.press()
    eq(#w.directs, 2)
end)

test("the follower aims again at a group member who walked far, not for a few steps", function()
    local w = newWorld({
        target = { name = "Friend", guid = GUIDS.friend, unit = "party1" },
        units = { party1 = { x = 110, y = 230 } },
    })
    w.press()
    eq(#w.directs, 1)
    w.units.party1 = { x = 114, y = 230 }
    w.tick()
    eq(#w.directs, 1, "four yards")
    w.units.party1 = { x = 118, y = 230 }
    w.tick()
    eq(#w.directs, 1, "eight yards is still near")
    w.units.party1 = { x = 125, y = 230 }
    w.tick()
    eq(#w.directs, 2, "fifteen yards")
    eq(w.directs[2][1], 125)
    -- from there a small step is small again
    w.units.party1 = { x = 128, y = 230 }
    w.tick()
    eq(#w.directs, 2)
end)

test("the follower does nothing for a creature, or when nothing guides", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    w.tick()
    eq(#w.directs, 0)
    w.press()
    w.tick()
    w.tick()
    eq(#w.directs, 1)
end)

test("the follower started once, and a failing tick is reported, not thrown", function()
    local w = newWorld({
        target = { name = "Friend", guid = GUIDS.friend, unit = "party1" },
        units = { party1 = { x = 110, y = 230 } },
    })
    eq(#w.tickers, 1)
    eq(w.ns.startFollower(), false)
    w.press()
    w.maps.directTo = function()
        error("beacon broke")
    end
    w.units.party1 = { x = 300, y = 300 }
    w.tick()
    check(w.errors[1] ~= nil and w.errors[1]:find("beacon broke", 1, true) ~= nil, w.errors[1])
end)

test("a beacon that fails is reported and nothing is followed", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    w.maps.directTo = function()
        error("no beacon")
    end
    w.press()
    check(w.errors[1]:find("no beacon", 1, true) ~= nil)
    eq(w.ns.following, nil)
end)

test("a key that fails is reported once, not on every press", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    w.maps.whereText = function()
        error("words broke")
    end
    w.press()
    w.press()
    eq(#w.errors, 1)
end)

test("without WowVision's maps or its target finder it says so", function()
    local a = newWorld({ noMaps = true })
    a.press()
    eq(a.said(), "WowVision cannot find the position of a target here.")
    local b = newWorld({ noTargetFind = true })
    b.press()
    eq(b.said(), "WowVision cannot find the position of a target here.")
    -- and the same for an older WowVision whose maps cannot say where a point lies
    local c = newWorld()
    c.maps.whereText = nil
    c.press()
    eq(c.said(), "WowVision cannot find the position of a target here.")
    -- or aim a beacon at one
    local d = newWorld()
    d.maps.directTo = nil
    d.press()
    eq(d.said(), "WowVision cannot find the position of a target here.")
    -- or know which route engine it has
    local e = newWorld()
    e.maps.activeRouteEngine = nil
    e.press()
    eq(e.said(), "WowVision cannot find the position of a target here.")
end)

test("a position the words cannot give is said as unavailable", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    w.maps.whereText = function()
        return nil
    end
    w.press()
    eq(w.spoken[1], "Lazy Peon, Position unavailable.")
    eq(#w.directs, 1)
end)

test("/wvtarget alone is the key; say only says; stop ends; any other word gives the help", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    SlashCmdList["WVTARGETDIRECTION"]("say")
    eq(w.said(), "Lazy Peon, 50 yards, ahead left")
    eq(#w.directs, 0)
    SlashCmdList["WVTARGETDIRECTION"]("")
    eq(#w.directs, 1)
    SlashCmdList["WVTARGETDIRECTION"]("stop")
    eq(w.cancels, 1)
    eq(w.said(), "Guidance stopped.")
    local spoken = #w.spoken
    SlashCmdList["WVTARGETDIRECTION"]("stop")
    eq(w.cancels, 1, "nothing guided: no second cancel")
    eq(#w.spoken, spoken, "and nothing said")
    SlashCmdList["WVTARGETDIRECTION"]("banana")
    check(w.said():find("/wvtarget", 1, true) ~= nil)
    eq(SLASH_WVTARGETDIRECTION1, "/wvtarget")
    eq(SLASH_WVTARGETDIRECTION2, "/wvcible")
    eq(SLASH_WVTARGETDIRECTION3, "/wvziel")
end)

test("the command words, in three languages", function()
    for _, word in ipairs({ "say", "dire", "sagen", "SAY", "Sagen" }) do
        local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
        SlashCmdList["WVTARGETDIRECTION"](word)
        eq(#w.spoken, 1, word)
        eq(#w.directs, 0, word)
    end
    for _, word in ipairs({ "stop", "arret", "arrêt", "ARRÊT", "stopp" }) do
        local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
        w.press()
        SlashCmdList["WVTARGETDIRECTION"](word)
        eq(w.cancels, 1, word)
    end
end)

test("French", function()
    local w = newWorld({ locale = "frFR" })
    w.press()
    eq(w.said(), "Vous n'avez pas de cible.")
    eq(w.bindings[1].info.label, "Balise sonore vers votre cible")
    w.target = { name = "Moi", guid = GUIDS.friend, self = true }
    w.press()
    eq(w.said(), "Vous vous ciblez vous-même.")
    w.target = creature("Péon fainéant", GUIDS.boar)
    w.press()
    eq(w.said(), "La position de votre cible n'est pas connue.")
    w.target = creature("Péon fainéant", GUIDS.peon)
    w.catalog[10556] = PEON_ROW
    w.press()
    w.press()
    eq(w.said(), "Guidage arrêté.")
    SlashCmdList["WVTARGETDIRECTION"]("banana")
    check(w.said():find("Direction de la cible", 1, true) ~= nil)
end)

test("German", function()
    local w = newWorld({ locale = "deDE" })
    w.press()
    eq(w.said(), "Du hast kein Ziel.")
    eq(w.bindings[1].info.label, "Klangsignal zu deinem Ziel")
    w.target = { name = "Ich", guid = GUIDS.friend, self = true }
    w.press()
    eq(w.said(), "Du hast dich selbst anvisiert.")
    w.target = creature("Fauler Peon", GUIDS.boar)
    w.press()
    eq(w.said(), "Die Position deines Ziels ist nicht bekannt.")
    w.target = creature("Fauler Peon", GUIDS.peon)
    w.catalog[10556] = PEON_ROW
    w.press()
    w.press()
    eq(w.said(), "Führung beendet.")
    SlashCmdList["WVTARGETDIRECTION"]("banana")
    check(w.said():find("Richtung des Ziels", 1, true) ~= nil)
end)

test("a language with no translation reads English", function()
    local w = newWorld({ locale = "esES" })
    w.press()
    eq(w.said(), "You have no target.")
end)

test("every sentence the code says has a French and a German translation", function()
    local ns = newWorld().ns
    local keys = {}
    for _, name in ipairs({ "Target", "Main" }) do
        local handle = assert(io.open(addonDir .. "/" .. name .. ".lua", "rb"))
        local source = handle:read("a")
        handle:close()
        for key in source:gmatch('L%["(.-)"%]') do
            keys[key] = true
        end
    end
    -- the binding label is looked up as L[info.label]
    keys["Beacon Toward Your Target"] = true
    local count = 0
    for key in pairs(keys) do
        count = count + 1
        for _, locale in ipairs({ "frFR", "deDE" }) do
            local translated = ns.translations[locale][key]
            check(translated ~= nil, locale .. " has no translation of: " .. key)
            check(translated ~= key, locale .. " says it in English: " .. key)
        end
    end
    check(count >= 8, "the keys were not found")
    for _, locale in ipairs({ "frFR", "deDE" }) do
        for key in pairs(ns.translations[locale]) do
            check(keys[key], locale .. " translates something nothing says: " .. key)
        end
    end
end)

test("the plan, pure: what WowVision's finder is asked and what comes back", function()
    local w = newWorld({ target = creature("Lazy Peon", GUIDS.peon), catalog = { [10556] = PEON_ROW } })
    local api = w.ns.Game.api(w.maps)
    local plan = w.ns.Target.plan(api, WowVision.targetFind)
    eq(plan.say, nil)
    eq(plan.target.x, 130)
    eq(plan.target.n, "Lazy Peon")
    eq(plan.target.guid, GUIDS.peon)
    eq(plan.target.unit, nil)
    check(w.ns.Target.moved({ x = 0, y = 0 }, 9, 0))
    check(not w.ns.Target.moved({ x = 0, y = 0 }, 8, 0))
    check(w.ns.Target.moved({ x = 0, y = 0 }, 6, 6))
    check(not w.ns.Target.moved({ x = 0, y = 0 }, 5, 5))
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
