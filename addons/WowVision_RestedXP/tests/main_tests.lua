return function(runner, env)
local loadAddon = env.loadAddon
local fakeRxp = env.fake.rxp
local fakeHbd = env.fake.hbd

local FILES = { "Locale", "Text", "Perf", "Source", "Options", "Menu", "Guidance", "Import", "Game", "Screens", "Main" }

local function pack(...)
    return { n = select("#", ...), ... }
end

-- The game, WowVision's input manager and windows, RestedXP and the libraries Main reaches, as doubles. Everything
-- is set before the addon loads, as it is in the game; teardown() puts the globals back.
local GLOBALS = {
    "WowVision", "RXP", "LibStub", "C_Timer", "GetTime", "GetPlayerFacing", "UnitLevel", "InCombatLockdown",
    "SlashCmdList", "SLASH_WVRESTEDXP1", "SLASH_WVRESTEDXP2", "hooksecurefunc", "geterrorhandler", "CreateFrame",
    "WowVisionDB", "WowVisionRestedXPDB", "unpack", "print", "GetLocale",
}

local function newWorld(config)
    config = config or {}
    local saved = {}
    for _, name in ipairs(GLOBALS) do
        saved[name] = rawget(_G, name)
    end
    local w = {
        spoken = {},
        errors = {},
        timers = {},
        tickers = {},
        messages = {},
        windows = {},
        opened = {},
        closed = {},
        bindingsByKey = {},
        bindingOrder = {},
        applied = 0,
        combat = false,
        time = 100,
        facing = 0,
        mapsCalls = {},
    }
    function w.teardown()
        for _, name in ipairs(GLOBALS) do
            rawset(_G, name, saved[name])
        end
    end
    function w.runTimers()
        local queue = w.timers
        w.timers = {}
        for _, timer in ipairs(queue) do
            timer.fn()
        end
    end
    function w.tick()
        for _, ticker in ipairs(w.tickers) do
            ticker()
        end
    end

    rawset(_G, "unpack", unpack or table.unpack)
    rawset(_G, "print", function() end)
    rawset(_G, "GetLocale", config.locale ~= nil and function()
        return config.locale
    end or nil)
    rawset(_G, "geterrorhandler", function()
        return function(err)
            tinsert(w.errors, tostring(err))
        end
    end)
    rawset(_G, "GetTime", function()
        return w.time
    end)
    rawset(_G, "GetPlayerFacing", function()
        return w.facing
    end)
    rawset(_G, "UnitLevel", function()
        return 12
    end)
    rawset(_G, "InCombatLockdown", function()
        return w.combat
    end)
    rawset(_G, "C_Timer", {
        After = function(seconds, fn)
            tinsert(w.timers, { seconds = seconds, fn = fn })
        end,
        NewTicker = function(seconds, fn)
            tinsert(w.tickers, fn)
            return {}
        end,
    })
    rawset(_G, "hooksecurefunc", function(target, name, hook)
        local original = target[name]
        target[name] = function(...)
            local result = pack(original(...))
            hook(...)
            return unpack(result, 1, result.n)
        end
    end)
    rawset(_G, "SlashCmdList", {})
    rawset(_G, "CreateFrame", nil)
    rawset(_G, "WowVisionDB", {})
    rawset(_G, "WowVisionRestedXPDB", nil)

    -- RestedXP
    w.rxp = fakeRxp(config.rxp or {
        name = "1-12 Durotar",
        current = 2,
        steps = {
            { lines = { { text = "Done already", done = true } } },
            { lines = { { text = "Accept |cRXP_FRIENDLY_Ailee::123|r's quest" }, { text = "Go to the hut" } } },
            { lines = { { text = "Third step line" } } },
        },
        active = { 2 },
        menuList = { { text = "Guides", notCheckable = 1, hasArrow = true, menuList = { { text = "A guide", notCheckable = 1, func = function() end } } } },
    })
    w.rxp.title = "RestedXP Guides"
    w.rxp.CloseMenu = function() end
    if config.importer then
        w.importer = env.fake.withImporter(w.rxp, config.importer)
    end
    w.rxp.arrowFrame.element = { wx = 10.5, wy = 20.25, title = "Talk to Ailee", instance = 1 }
    w.shownMenus = {}
    w.rxp.ShowMenu = function(self, menu, frame, anchor)
        tinsert(w.shownMenus, { self = self, menu = menu, frame = frame, anchor = anchor })
        return "shown", 2
    end
    if not config.noRxp then
        rawset(_G, "RXP", w.rxp)
    else
        rawset(_G, "RXP", nil)
    end

    -- WowVision's maps
    w.maps = {
        guiding = false,
        directTo = function(self, x, y, name)
            tinsert(w.mapsCalls, { "directTo", x, y, name })
            self.guiding = true
        end,
        goToDestination = function(self, destination, direct)
            tinsert(w.mapsCalls, { "goToDestination", destination, direct })
            self.guiding = true
            return true
        end,
        isGuiding = function(self)
            return self.guiding
        end,
        cancelNavigation = function(self)
            tinsert(w.mapsCalls, { "cancel" })
            self.guiding = false
        end,
    }

    -- WowVision's input manager, store and windows
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
        tinsert(w.bindingOrder, binding)
        return binding
    end
    w.registeredWindows = {}
    local manager = {
        openWindows = {},
        RegisterWindow = function(_, window)
            w.registeredWindows[window.config.name] = window
        end,
        getWindow = function(_, name)
            return w.registeredWindows[name]
        end,
    }
    local host = {
        windowManager = manager,
        openTemporaryWindow = function(_, windowConfig)
            w.windows[windowConfig.name] = windowConfig.graphScreen
            tinsert(w.opened, windowConfig.name)
            tinsert(manager.openWindows, { name = windowConfig.name })
        end,
        closeWindow = function(_, name)
            w.windows[name] = nil
            tinsert(w.closed, name)
            for i, instance in ipairs(manager.openWindows) do
                if instance.name == name then
                    table.remove(manager.openWindows, i)
                    break
                end
            end
        end,
    }
    rawset(_G, "WowVision", {
        input = input,
        UIHost = host,
        WindowManager = {
            CreateWindow = function(_, kind, windowConfig)
                if config.windowError then
                    error("no windows today")
                end
                return { kind = kind, config = windowConfig }
            end,
        },
        base = { navigation = { maps = (not config.noMaps) and w.maps or nil } },
        globalDb = {},
        dbManager = {
            resolveBindings = function()
                return {}
            end,
        },
        applyBindingStore = function()
            w.applied = w.applied + 1
        end,
        speak = function(_, text)
            tinsert(w.spoken, text)
        end,
    })

    -- libraries
    w.hbd = fakeHbd({ 0, 0 }, 3 * math.pi / 2, 35)
    rawset(_G, "LibStub", function(name)
        if name == "HereBeDragons-2.0" then
            return w.hbd
        elseif name == "AceEvent-3.0" then
            return {
                Embed = function(_, target)
                    target.RegisterMessage = function(_, message, fn)
                        w.messages[message] = fn
                    end
                end,
            }
        end
        return nil
    end)

    w.ns = loadAddon(FILES)
    return w
end

local function withWorld(config, fn)
    local w = newWorld(config)
    local ok, err = pcall(fn, w)
    w.teardown()
    if not ok then
        error(err, 0)
    end
end

local function key(w, name)
    return w.bindingOrder[1] and w.ns and WowVision.input:getBinding(name)
end

runner:addSuite("Main: the keys", {
    ["every key is created once, with its default input, a translated label and a function"] = function(t)
        withWorld(nil, function(w)
            local expected = {
                ["restedxp/menu"] = "SHIFT-F2",
                ["restedxp/guides"] = "ALT-CTRL-F2",
                ["restedxp/step"] = "ALT-F2",
                ["restedxp/arrow"] = "CTRL-F2",
                ["restedxp/beacon"] = "CTRL-SHIFT-F2",
                ["restedxp/route"] = "ALT-SHIFT-F2",
            }
            for name, input in pairs(expected) do
                local binding = WowVision.input:getBinding(name)
                t:assertNotNil(binding, name)
                t:assertEqual(binding.info.inputs[1], input, name)
                t:assertEqual(binding.info.type, "Function")
                t:assertEqual(type(binding.info.func), "function")
                t:assertEqual(binding.activated, 1, name)
            end
            for _, name in ipairs({ "restedxp/stop", "restedxp/skip", "restedxp/next", "restedxp/previous" }) do
                t:assertEqual(#WowVision.input:getBinding(name).info.inputs, 0, name)
            end
            t:assertEqual(#w.bindingOrder, 10)
            t:assertEqual(w.applied, 1)
            t:assertTrue(w.ns.installed)
        end)
    end,
    ["no key is on one of WowVision's or the other extensions' keys"] = function(t)
        withWorld(nil, function(w)
            local taken = {}
            for _, name in ipairs({ "F2", "SHIFT-F1", "SHIFT-F3", "SHIFT-F4", "SHIFT-F10", "SHIFT-F12", "CTRL-F9", "F9", "F10", "ALT-Q", "ALT-SHIFT-Q", "ALT-CTRL-Q", "SHIFT-ENTER", "SHIFT-BACKSPACE", "ALT-LEFT", "ALT-RIGHT" }) do
                taken[name] = true
            end
            for _, binding in ipairs(w.bindingOrder) do
                for _, input in ipairs(binding.info.inputs) do
                    t:assertFalse(taken[input] == true, input .. " is taken")
                end
            end
        end)
    end,
    ["a second load does not create them again"] = function(t)
        withWorld(nil, function(w)
            w.ns.installBindings()
            t:assertEqual(#w.bindingOrder, 10)
            t:assertEqual(w.applied, 1)
        end)
    end,
    ["labels are translated"] = function(t)
        withWorld({ locale = "frFR" }, function(w)
            t:assertEqual(WowVision.input:getBinding("restedxp/menu").info.label, "Menu RestedXP")
            t:assertEqual(WowVision.input:getBinding("restedxp/route").info.label, "Itinéraire WowVision vers la flèche RestedXP")
        end)
        withWorld({ locale = "deDE" }, function(w)
            t:assertEqual(WowVision.input:getBinding("restedxp/menu").info.label, "RestedXP-Menü")
        end)
        withWorld(nil, function(w)
            t:assertEqual(WowVision.input:getBinding("restedxp/menu").info.label, "RestedXP Menu")
        end)
    end,
    ["without WowVision's input manager nothing is installed"] = function(t)
        withWorld(nil, function(w)
            local ns = loadAddon({ "Locale", "Text", "Perf", "Source", "Options", "Menu", "Guidance", "Import", "Game", "Screens" })
            rawset(_G, "WowVision", nil)
            ns.bindings = {}
            local chunk = loadfile(env.addonDir .. "/Main.lua")
            chunk("WowVision_RestedXP", ns)
            t:assertFalse(ns.installed)
        end)
    end,
    ["the menu key opens the main screen and closes it again"] = function(t)
        withWorld(nil, function(w)
            local func = WowVision.input:getBinding("restedxp/menu").info.func
            func()
            t:assertEqual(w.opened[1], "restedxp")
            func()
            t:assertEqual(w.closed[1], "restedxp")
        end)
    end,
    ["a failing key function is reported once, not thrown"] = function(t)
        withWorld(nil, function(w)
            w.rxp.RXPFrame = setmetatable({}, { __index = function() error("boom") end })
            local func = WowVision.input:getBinding("restedxp/step").info.func
            func()
            func()
            t:assertEqual(#w.errors, 1)
            t:assertMatch(w.errors[1], "boom")
        end)
    end,
})

runner:addSuite("Main: what the keys say and do", {
    ["the step key reads the step now shown"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/step").info.func()
            t:assertEqual(w.spoken[1], "Step 2. Accept Ailee's quest. Go to the hut")
        end)
    end,
    ["the step key says there is no guide, or nothing to show"] = function(t)
        withWorld({ rxp = { name = "x", steps = { { lines = { { text = "a" } } } }, empty = true } }, function(w)
            WowVision.input:getBinding("restedxp/step").info.func()
            t:assertEqual(w.spoken[1], "No guide chosen. Open the menu to choose one.")
        end)
        withWorld({ rxp = { name = "x", steps = { { lines = { { text = "a" } } } }, active = {} } }, function(w)
            WowVision.input:getBinding("restedxp/step").info.func()
            t:assertEqual(w.spoken[1], "No step to show right now.")
        end)
    end,
    ["every key says RestedXP is missing when it is"] = function(t)
        withWorld({ noRxp = true }, function(w)
            for _, name in ipairs({ "guides", "step", "arrow", "beacon", "route", "skip", "next", "previous" }) do
                WowVision.input:getBinding("restedxp/" .. name).info.func()
            end
            t:assertEqual(#w.spoken, 8)
            for _, text in ipairs(w.spoken) do
                t:assertEqual(text, "RestedXP is not loaded.")
            end
        end)
    end,
    ["the arrow key says where it points, how far"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/arrow").info.func()
            t:assertEqual(w.spoken[1], "Talk to Ailee, at 3 o'clock, to your right, 35 yards")
        end)
    end,
    ["the beacon key starts a beacon, and again ends it"] = function(t)
        withWorld(nil, function(w)
            local func = WowVision.input:getBinding("restedxp/beacon").info.func
            func()
            t:assertEqual(w.mapsCalls[1][1], "directTo")
            t:assertEqual(w.mapsCalls[1][2], 20.25)
            t:assertEqual(w.ns.Guidance.following, "beacon")
            func()
            t:assertEqual(w.mapsCalls[2][1], "cancel")
            t:assertNil(w.ns.Guidance.following)
            t:assertEqual(w.spoken[#w.spoken], "Guidance stopped.")
        end)
    end,
    ["the route key starts a WowVision route, and again ends it"] = function(t)
        withWorld(nil, function(w)
            local func = WowVision.input:getBinding("restedxp/route").info.func
            func()
            t:assertEqual(w.mapsCalls[1][1], "goToDestination")
            t:assertEqual(w.ns.Guidance.following, "route")
            func()
            t:assertNil(w.ns.Guidance.following)
        end)
    end,
    ["the other key changes the guidance to its mode"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            WowVision.input:getBinding("restedxp/route").info.func()
            t:assertEqual(w.ns.Guidance.following, "route")
            t:assertEqual(w.mapsCalls[#w.mapsCalls][1], "goToDestination")
        end)
    end,
    ["guiding says why it cannot"] = function(t)
        withWorld({ noMaps = true }, function(w)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            t:assertEqual(w.spoken[1], "WowVision's navigation is not available.")
        end)
        withWorld(nil, function(w)
            w.rxp.arrowFrame.element = nil
            WowVision.input:getBinding("restedxp/route").info.func()
            t:assertEqual(w.spoken[1], "No destination in the guide right now.")
        end)
    end,
    ["the stop key ends the guidance"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            WowVision.input:getBinding("restedxp/stop").info.func()
            t:assertEqual(w.mapsCalls[2][1], "cancel")
            t:assertNil(w.ns.Guidance.following)
        end)
    end,
    ["skip, next and previous move in the guide"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/skip").info.func()
            t:assertTrue(w.rxp.currentGuide.steps[2].elements[1].skip)
            WowVision.input:getBinding("restedxp/next").info.func()
            WowVision.input:getBinding("restedxp/previous").info.func()
            t:assertEqual(w.rxp.calls.setStep[1], 3)
            -- the fake RestedXP follows SetStep, so "previous" goes from 3 back to 2
            t:assertEqual(w.rxp.calls.setStep[2], 2)
        end)
    end,
    ["skip with nothing to skip says so"] = function(t)
        withWorld({ rxp = { name = "x", steps = { { lines = { { text = "a", done = true } } } }, active = { 1 } } }, function(w)
            WowVision.input:getBinding("restedxp/skip").info.func()
            t:assertEqual(w.spoken[1], "Nothing to skip.")
        end)
    end,
    ["next without a guide says so"] = function(t)
        withWorld({ rxp = { name = "x", steps = { { lines = { { text = "a" } } } }, empty = true } }, function(w)
            WowVision.input:getBinding("restedxp/next").info.func()
            t:assertEqual(w.spoken[1], "No guide chosen. Open the menu to choose one.")
        end)
    end,
})

runner:addSuite("Main: RestedXP's menus", {
    ["a menu shown by RestedXP also opens a WowVision screen, and the drop-down is untouched"] = function(t)
        withWorld(nil, function(w)
            t:assertTrue(w.ns.menusHooked)
            local list = { { text = "Hello", notCheckable = 1, func = function() end } }
            local frame, anchor = {}, "cursor"
            local a, b = w.rxp:ShowMenu(list, frame, anchor)
            t:assertEqual(a, "shown")
            t:assertEqual(b, 2)
            t:assertEqual(#w.shownMenus, 1)
            t:assertEqual(w.shownMenus[1].menu, list)
            t:assertEqual(w.shownMenus[1].frame, frame)
            t:assertEqual(w.shownMenus[1].self, w.rxp)
            t:assertEqual(w.opened[1], "restedxp-menu")
        end)
    end,
    ["a failing screen does not stop the drop-down"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.openMenu = function()
                error("screen broke")
            end
            local result = w.rxp:ShowMenu({}, nil, nil)
            t:assertEqual(result, "shown")
            t:assertMatch(w.errors[1], "screen broke")
        end)
    end,
    ["the menu is hooked once"] = function(t)
        withWorld(nil, function(w)
            local hooked = w.rxp.ShowMenu
            t:assertFalse(w.ns.hookMenus(w.rxp))
            t:assertEqual(w.rxp.ShowMenu, hooked)
        end)
    end,
    ["no RestedXP, no menu hook, and it is hooked when RestedXP appears"] = function(t)
        withWorld({ noRxp = true }, function(w)
            t:assertNil(w.ns.menusHooked)
            rawset(_G, "RXP", w.rxp)
            w.ns.installRxpHooks()
            t:assertTrue(w.ns.menusHooked)
        end)
    end,
})

runner:addSuite("Main: RestedXP's importer", {
    ["what the importer reports is said out loud, once the addon has loaded"] = function(t)
        withWorld({ importer = {} }, function(w)
            t:assertTrue(w.ns.importHooked)
            w.importer:UpdateImportStatusHistory("Guides Loaded Successfully", false)
            t:assertEqual(w.spoken[#w.spoken], "Guides Loaded Successfully")
            w.importer:paste("abc")
            t:assertEqual(w.spoken[#w.spoken], "3 characters pasted. You can now import them.")
        end)
    end,
    ["it is said in the player's language"] = function(t)
        withWorld({ importer = {}, locale = "frFR" }, function(w)
            w.importer:UpdateImportStatusHistory("Whatever", true)
            t:assertEqual(w.spoken[#w.spoken], "Erreur d'import : Whatever")
        end)
    end,
    ["the importer is hooked once"] = function(t)
        withWorld({ importer = {} }, function(w)
            t:assertFalse(w.ns.hookImport(w.rxp))
            w.importer:UpdateImportStatusHistory("Once", false)
            local count = 0
            for _, text in ipairs(w.spoken) do
                if text == "Once" then
                    count = count + 1
                end
            end
            t:assertEqual(count, 1)
        end)
    end,
    ["a RestedXP with no importer leaves nothing hooked"] = function(t)
        withWorld(nil, function(w)
            t:assertNil(w.ns.importHooked)
            t:assertFalse(w.ns.hookImport(w.rxp))
            t:assertFalse(w.ns.hookImport(nil))
        end)
    end,
    ["it is hooked when RestedXP appears after this addon"] = function(t)
        withWorld({ noRxp = true, importer = {} }, function(w)
            t:assertNil(w.ns.importHooked)
            rawset(_G, "RXP", w.rxp)
            w.ns.installRxpHooks()
            t:assertTrue(w.ns.importHooked)
        end)
    end,
})

runner:addSuite("Main: announcing steps", {
    ["a new step is said once the window is rebuilt"] = function(t)
        withWorld(nil, function(w)
            t:assertNotNil(w.messages["RXP_STEP_ACTIVATED"])
            w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED", {}, {})
            t:assertEqual(#w.spoken, 0)
            t:assertEqual(w.timers[1].seconds, 0.5)
            w.runTimers()
            t:assertEqual(w.spoken[1], "Step 2. Accept Ailee's quest. Go to the hut")
        end)
    end,
    ["several messages in a moment make one announcement"] = function(t)
        withWorld(nil, function(w)
            for _ = 1, 4 do
                w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED")
            end
            t:assertEqual(#w.timers, 1)
            w.runTimers()
            t:assertEqual(#w.spoken, 1)
        end)
    end,
    ["the same text twice in a row within three seconds is not repeated"] = function(t)
        withWorld(nil, function(w)
            w.messages["RXP_GUIDE_LOADED"]("RXP_GUIDE_LOADED")
            w.runTimers()
            w.time = w.time + 1
            w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED")
            w.runTimers()
            t:assertEqual(#w.spoken, 1)
            w.time = w.time + 5
            w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED")
            w.runTimers()
            t:assertEqual(#w.spoken, 2)
        end)
    end,
    ["the setting turns it off"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("announceSteps", false)
            w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED")
            w.runTimers()
            t:assertEqual(#w.spoken, 0)
        end)
    end,
    ["it says nothing without a guide or without steps"] = function(t)
        withWorld({ rxp = { name = "x", steps = { { lines = { { text = "a" } } } }, empty = true } }, function(w)
            w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED")
            w.runTimers()
            t:assertEqual(#w.spoken, 0)
        end)
        withWorld({ rxp = { name = "x", steps = { { lines = { { text = "a" } } } }, active = {} } }, function(w)
            w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED")
            w.runTimers()
            t:assertEqual(#w.spoken, 0)
        end)
    end,
    ["a failing announcement is reported and the next one still works"] = function(t)
        withWorld(nil, function(w)
            local frame = w.rxp.RXPFrame
            w.rxp.RXPFrame = setmetatable({}, { __index = function() error("boom") end })
            w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED")
            w.runTimers()
            t:assertMatch(w.errors[1], "boom")
            w.rxp.RXPFrame = frame
            w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED")
            w.runTimers()
            t:assertEqual(#w.spoken, 1)
        end)
    end,
})

runner:addSuite("Main: following the arrow", {
    ["nothing happens with no guidance and no announcements"] = function(t)
        withWorld(nil, function(w)
            w.tick()
            t:assertEqual(#w.mapsCalls, 0)
            t:assertEqual(#w.spoken, 0)
        end)
    end,
    ["the guidance goes to the new destination when the arrow moves"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            w.tick()
            t:assertEqual(#w.mapsCalls, 1)
            w.rxp.arrowFrame.element = { wx = 99, wy = 98, title = "Next stop", instance = 1 }
            w.tick()
            t:assertEqual(#w.mapsCalls, 2)
            t:assertEqual(w.mapsCalls[2][2], 98)
            t:assertEqual(w.mapsCalls[2][3], 99)
            t:assertEqual(w.mapsCalls[2][4], "Next stop")
            w.tick()
            t:assertEqual(#w.mapsCalls, 2)
        end)
    end,
    ["by default even a small move of the arrow redoes the beacon and the route"] = function(t)
        withWorld(nil, function(w)
            t:assertEqual(w.ns.Game.getSetting("ignoreSmallMoves"), false)
            for _, key in ipairs({ "restedxp/beacon", "restedxp/route" }) do
                w.mapsCalls = {}
                w.ns.Guidance.following = nil
                w.rxp.arrowFrame.element = { wx = 10.5, wy = 20.25, title = "Talk to Ailee", instance = 1 }
                WowVision.input:getBinding(key).info.func()
                t:assertEqual(#w.mapsCalls, 1, key)
                w.rxp.arrowFrame.element = { wx = 14.5, wy = 24.25, title = "Talk to Ailee", instance = 1 }
                w.tick()
                t:assertEqual(#w.mapsCalls, 2, key)
                -- an arrow that did not move is not a new destination
                w.tick()
                t:assertEqual(#w.mapsCalls, 2, key)
            end
        end)
    end,
    ["by default a small move of the arrow is said again, when asked to say it"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("recalculate", false)
            w.ns.Game.setSetting("announceDestination", true)
            w.tick()
            t:assertEqual(#w.spoken, 1)
            w.rxp.arrowFrame.element = { wx = 14, wy = 20.25, title = "Talk to Ailee", instance = 1 }
            w.tick()
            t:assertEqual(#w.spoken, 2)
            w.tick()
            t:assertEqual(#w.spoken, 2)
        end)
    end,
    ["asked to ignore small moves, a small drift of the arrow does not redo the beacon or the route"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("ignoreSmallMoves", true)
            for _, key in ipairs({ "restedxp/beacon", "restedxp/route" }) do
                w.mapsCalls = {}
                w.ns.Guidance.following = nil
                w.rxp.arrowFrame.element = { wx = 10.5, wy = 20.25, title = "Talk to Ailee", instance = 1 }
                WowVision.input:getBinding(key).info.func()
                t:assertEqual(#w.mapsCalls, 1, key)
                w.rxp.arrowFrame.element = { wx = 14.5, wy = 24.25, title = "Talk to Ailee", instance = 1 }
                w.tick()
                w.rxp.arrowFrame.element = { wx = 8, wy = 27, title = "Talk to Ailee", instance = 1 }
                w.tick()
                t:assertEqual(#w.mapsCalls, 1, key)
            end
        end)
    end,
    ["asked to ignore small moves, drifts that add up past ten yards redo it once"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("ignoreSmallMoves", true)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            for _, wx in ipairs({ 14, 18, 20 }) do
                w.rxp.arrowFrame.element = { wx = wx, wy = 20.25, title = "Drifting", instance = 1 }
                w.tick()
            end
            t:assertEqual(#w.mapsCalls, 1)
            w.rxp.arrowFrame.element = { wx = 22, wy = 20.25, title = "Drifting", instance = 1 }
            w.tick()
            w.tick()
            t:assertEqual(#w.mapsCalls, 2)
            t:assertEqual(w.mapsCalls[2][4], "Drifting")
        end)
    end,
    ["asked to ignore small moves, a small drift is not said again either, but drifts that add up are, once"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("ignoreSmallMoves", true)
            w.ns.Game.setSetting("recalculate", false)
            w.ns.Game.setSetting("announceDestination", true)
            w.tick()
            t:assertEqual(#w.spoken, 1)
            for _, wx in ipairs({ 14, 18, 20 }) do
                w.rxp.arrowFrame.element = { wx = wx, wy = 20.25, title = "Talk to Ailee", instance = 1 }
                w.tick()
            end
            t:assertEqual(#w.spoken, 1)
            w.rxp.arrowFrame.element = { wx = 22, wy = 20.25, title = "Talk to Ailee", instance = 1 }
            w.tick()
            w.tick()
            t:assertEqual(#w.spoken, 2)
            -- and from there, a small move is small again
            w.rxp.arrowFrame.element = { wx = 25, wy = 20.25, title = "Talk to Ailee", instance = 1 }
            w.tick()
            t:assertEqual(#w.spoken, 2)
        end)
    end,
    ["turning the recalculation off during a guidance does not repeat where it already goes"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("announceDestination", true)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            w.tick()
            w.rxp.arrowFrame.element = { wx = 99, wy = 98, title = "Next stop", instance = 1 }
            w.tick()
            t:assertEqual(#w.mapsCalls, 2)
            t:assertEqual(#w.spoken, 0)
            w.ns.Game.setSetting("recalculate", false)
            w.tick()
            t:assertEqual(#w.spoken, 0)
            -- and a real change after that is said
            w.rxp.arrowFrame.element = { wx = 1, wy = 2, title = "Elsewhere", instance = 1 }
            w.tick()
            t:assertEqual(#w.spoken, 1)
            t:assertMatch(w.spoken[1], "Elsewhere")
        end)
    end,
    ["a destination that goes away and comes back is said again"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("announceDestination", true)
            w.tick()
            t:assertEqual(#w.spoken, 1)
            w.rxp.arrowFrame.element = nil
            w.tick()
            -- nothing is said while there is no destination
            t:assertEqual(#w.spoken, 1)
            w.rxp.arrowFrame.element = { wx = 10.5, wy = 20.25, title = "Talk to Ailee", instance = 1 }
            w.tick()
            t:assertEqual(#w.spoken, 2)
            t:assertMatch(w.spoken[2], "Talk to Ailee")
        end)
    end,
    ["the route is redone toward the new destination too, by default"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/route").info.func()
            t:assertEqual(#w.mapsCalls, 1)
            w.rxp.arrowFrame.element = { wx = 99, wy = 98, title = "Next stop", instance = 1 }
            w.tick()
            t:assertEqual(#w.mapsCalls, 2)
            t:assertEqual(w.mapsCalls[2][1], "goToDestination")
            t:assertEqual(w.mapsCalls[2][2].n, "Next stop")
        end)
    end,
    ["with the recalculation turned off the beacon and the route keep their destination"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("recalculate", false)
            for _, key in ipairs({ "restedxp/beacon", "restedxp/route" }) do
                w.mapsCalls = {}
                w.ns.Guidance.following = nil
                WowVision.input:getBinding(key).info.func()
                t:assertEqual(#w.mapsCalls, 1, key)
                w.rxp.arrowFrame.element = { wx = 99, wy = 98, title = "Next stop", instance = 1 }
                w.tick()
                w.tick()
                t:assertEqual(#w.mapsCalls, 1, key)
                -- the guidance is still on, so the key still stops it
                t:assertEqual(w.ns.Guidance.following, key == "restedxp/beacon" and "beacon" or "route")
                w.rxp.arrowFrame.element = { wx = 10.5, wy = 20.25, title = "Talk to Ailee", instance = 1 }
            end
        end)
    end,
    ["pressing the key twice then aims at the arrow as it is now"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("recalculate", false)
            WowVision.input:getBinding("restedxp/route").info.func()
            w.rxp.arrowFrame.element = { wx = 99, wy = 98, title = "Next stop", instance = 1 }
            w.tick()
            WowVision.input:getBinding("restedxp/route").info.func()
            t:assertNil(w.ns.Guidance.following)
            WowVision.input:getBinding("restedxp/route").info.func()
            t:assertEqual(w.ns.Guidance.following, "route")
            local last = w.mapsCalls[#w.mapsCalls]
            t:assertEqual(last[1], "goToDestination")
            t:assertEqual(last[2].n, "Next stop")
        end)
    end,
    ["turning the recalculation back on catches up with the arrow at once"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("recalculate", false)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            w.rxp.arrowFrame.element = { wx = 99, wy = 98, title = "Next stop", instance = 1 }
            w.tick()
            t:assertEqual(#w.mapsCalls, 1)
            w.ns.Game.setSetting("recalculate", true)
            w.tick()
            t:assertEqual(#w.mapsCalls, 2)
            t:assertEqual(w.mapsCalls[2][4], "Next stop")
        end)
    end,
    ["with the recalculation off, the new destination is said when asked, even while guided"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("recalculate", false)
            w.ns.Game.setSetting("announceDestination", true)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            w.tick()
            t:assertEqual(#w.spoken, 1)
            t:assertMatch(w.spoken[1], "Talk to Ailee")
            w.tick()
            t:assertEqual(#w.spoken, 1)
            w.rxp.arrowFrame.element = { wx = 1, wy = 2, title = "Elsewhere", instance = 1 }
            w.tick()
            t:assertEqual(#w.spoken, 2)
            t:assertMatch(w.spoken[2], "Elsewhere")
            t:assertEqual(#w.mapsCalls, 1)
        end)
    end,
    ["with the recalculation off and nothing asked, the follower does nothing at all"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("recalculate", false)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            w.tick()
            -- the arrow is not even read: a read would fail here
            w.rxp.arrowFrame = setmetatable({}, { __index = function() error("must not be read") end })
            w.tick()
            t:assertEqual(#w.errors, 0)
            t:assertEqual(#w.mapsCalls, 1)
            t:assertEqual(#w.spoken, 0)
        end)
    end,
    ["the new destination is said when asked, once"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("announceDestination", true)
            w.tick()
            t:assertEqual(#w.spoken, 1)
            t:assertMatch(w.spoken[1], "Talk to Ailee")
            w.tick()
            t:assertEqual(#w.spoken, 1)
            w.rxp.arrowFrame.element = { wx = 1, wy = 2, title = "Elsewhere", instance = 1 }
            w.tick()
            t:assertEqual(#w.spoken, 2)
            t:assertMatch(w.spoken[2], "Elsewhere")
        end)
    end,
    ["while guiding, WowVision says the new destination itself, so this stays quiet"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("announceDestination", true)
            WowVision.input:getBinding("restedxp/beacon").info.func()
            w.rxp.arrowFrame.element = { wx = 1, wy = 2, title = "Elsewhere", instance = 1 }
            w.tick()
            t:assertEqual(#w.spoken, 0)
            t:assertEqual(#w.mapsCalls, 2)
        end)
    end,
    ["WowVision's own cancel ends the following"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/route").info.func()
            t:assertEqual(w.ns.Guidance.following, "route")
            t:assertNotNil(w.ns.Guidance.lastPoint)
            w.maps:cancelNavigation()
            t:assertNil(w.ns.Guidance.following)
            t:assertNil(w.ns.Guidance.lastPoint)
            w.rxp.arrowFrame.element = { wx = 1, wy = 2, title = "Elsewhere", instance = 1 }
            local before = #w.mapsCalls
            w.tick()
            t:assertEqual(#w.mapsCalls, before)
        end)
    end,
    ["the follower is started once"] = function(t)
        withWorld(nil, function(w)
            t:assertEqual(#w.tickers, 1)
            t:assertFalse(w.ns.startFollower())
            t:assertEqual(#w.tickers, 1)
        end)
    end,
    ["a failing follow is reported by the ticker's guard"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.setSetting("announceDestination", true)
            w.rxp.arrowFrame = setmetatable({}, { __index = function() error("boom") end })
            w.tick()
            t:assertMatch(w.errors[1], "boom")
        end)
    end,
})

runner:addSuite("Main: the command", {
    ["/wvrxp opens the menu"] = function(t)
        withWorld(nil, function(w)
            SlashCmdList["WVRESTEDXP"]("")
            t:assertEqual(w.opened[1], "restedxp")
            t:assertEqual(SLASH_WVRESTEDXP1, "/wvrxp")
        end)
    end,
    ["the words, in three languages"] = function(t)
        withWorld(nil, function(w)
            for _, word in ipairs({ "step", "étape", "etape", "ÉTAPE", "Étape", "schritt" }) do
                w.spoken = {}
                SlashCmdList["WVRESTEDXP"](word)
                t:assertEqual(#w.spoken, 1, word)
                t:assertMatch(w.spoken[1], "^Step 2", word)
            end
            for _, word in ipairs({ "arrow", "flèche", "fleche", "FLÈCHE", "pfeil" }) do
                w.spoken = {}
                SlashCmdList["WVRESTEDXP"](word)
                t:assertEqual(#w.spoken, 1, word)
                t:assertMatch(w.spoken[1], "^Talk to Ailee", word)
            end
        end)
    end,
    ["the guidance words, with or without accents or capitals"] = function(t)
        withWorld(nil, function(w)
            for _, word in ipairs({ "beacon", "balise", "signal", "BALISE" }) do
                w.ns.Guidance.following = nil
                SlashCmdList["WVRESTEDXP"](word)
                t:assertEqual(w.ns.Guidance.following, "beacon", word)
            end
            for _, word in ipairs({ "route", "itineraire", "itinéraire", "ITINÉRAIRE" }) do
                w.ns.Guidance.following = nil
                SlashCmdList["WVRESTEDXP"](word)
                t:assertEqual(w.ns.Guidance.following, "route", word)
            end
            for _, word in ipairs({ "stop", "arret", "arrêt", "ARRÊT", "stopp" }) do
                w.ns.Guidance.following = "beacon"
                SlashCmdList["WVRESTEDXP"](word)
                t:assertNil(w.ns.Guidance.following, word)
            end
        end)
    end,
    ["temps says how long the work takes, and temps zéro forgets it"] = function(t)
        withWorld(nil, function(w)
            w.ns.Perf.reset()
            w.ns.Perf.memory = function()
                return nil
            end
            local now = 0
            w.ns.Perf.clock = function()
                now = now + 3
                return now
            end
            WowVision.input:getBinding("restedxp/arrow").info.func()
            w.spoken = {}
            SlashCmdList["WVRESTEDXP"]("temps")
            t:assertMatch(w.spoken[1], "key: 1 calls, 3.0 ms in all, 3.0 ms at worst")
            w.spoken = {}
            SlashCmdList["WVRESTEDXP"]("perf")
            t:assertMatch(w.spoken[1], "^key: 1 calls")
            SlashCmdList["WVRESTEDXP"]("zeit")
            SlashCmdList["WVRESTEDXP"]("temps zéro")
            t:assertEqual(w.spoken[#w.spoken], "Measures cleared.")
            w.spoken = {}
            SlashCmdList["WVRESTEDXP"]("temps")
            t:assertEqual(w.spoken[1], "Nothing measured yet.")
            SlashCmdList["WVRESTEDXP"]("temps reset")
            SlashCmdList["WVRESTEDXP"]("temps raz")
            t:assertEqual(w.spoken[#w.spoken], "Measures cleared.")
        end)
    end,
    ["the keys, the announcements and the follower are timed"] = function(t)
        withWorld(nil, function(w)
            w.ns.Perf.reset()
            WowVision.input:getBinding("restedxp/step").info.func()
            w.messages["RXP_STEP_ACTIVATED"]("RXP_STEP_ACTIVATED")
            w.runTimers()
            w.ns.Game.setSetting("announceDestination", true)
            w.tick()
            w.rxp:ShowMenu({ { text = "Hello", notCheckable = 1, func = function() end } })
            local calls = {}
            for _, row in ipairs(w.ns.Perf.rows()) do
                calls[row.name] = row.calls
            end
            t:assertEqual(calls["key"], 1)
            t:assertEqual(calls["step announcement"], 1)
            t:assertEqual(calls["arrow follower"], 1)
            t:assertEqual(calls["menu hook"], 1)
        end)
    end,
    ["balise, itinéraire and stop"] = function(t)
        withWorld(nil, function(w)
            SlashCmdList["WVRESTEDXP"]("balise")
            t:assertEqual(w.ns.Guidance.following, "beacon")
            SlashCmdList["WVRESTEDXP"]("itinéraire")
            t:assertEqual(w.ns.Guidance.following, "route")
            SlashCmdList["WVRESTEDXP"]("stop")
            t:assertNil(w.ns.Guidance.following)
        end)
    end,
    ["an unknown word explains the command"] = function(t)
        withWorld(nil, function(w)
            SlashCmdList["WVRESTEDXP"]("whatever")
            t:assertMatch(w.spoken[1], "/wvrxp opens the menu")
        end)
    end,
})

runner:addSuite("Main: the options page", {
    ["the window for RestedXP's page is registered and follows the page"] = function(t)
        withWorld(nil, function(w)
            local window = w.registeredWindows["restedxp-settings"]
            t:assertNotNil(window)
            t:assertEqual(window.kind, "CustomWindow")
            t:assertEqual(type(window.config.graphScreen.render), "function")
            t:assertFalse(window.config.isOpenFunc())
            local visible = true
            w.rxp.RXPOptions = { IsVisible = function() return visible end }
            t:assertTrue(window.config.isOpenFunc())
            visible = false
            t:assertFalse(window.config.isOpenFunc())
        end)
    end,
    ["a window that cannot be registered is reported and the keys still work"] = function(t)
        withWorld({ windowError = true }, function(w)
            t:assertMatch(w.errors[1], "no windows today")
            t:assertTrue(w.ns.installed)
            t:assertEqual(#w.bindingOrder, 10)
        end)
    end,
})

runner:addSuite("Main: the right-click key", {
    ["it opens RestedXP's own menu in a screen, rebuilt now"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/guides").info.func()
            t:assertEqual(w.opened[1], "restedxp-menu")
            t:assertEqual(w.rxp.calls.menu, 1)
        end)
    end,
    ["it says so when RestedXP has no menu"] = function(t)
        withWorld(nil, function(w)
            w.rxp.RXPFrame.GenerateMenuTable = function() end
            w.rxp.RXPFrame.menuList = nil
            WowVision.input:getBinding("restedxp/guides").info.func()
            t:assertEqual(#w.opened, 0)
            t:assertEqual(w.spoken[1], "RestedXP has no menu to show.")
        end)
    end,
    ["with the main screen open it points there"] = function(t)
        withWorld(nil, function(w)
            WowVision.input:getBinding("restedxp/menu").info.func()
            WowVision.input:getBinding("restedxp/guides").info.func()
            t:assertEqual(#w.opened, 1)
            t:assertEqual(w.spoken[1], "The RestedXP menu is in the main screen.")
        end)
    end,
    ["in combat it says it is not available"] = function(t)
        withWorld(nil, function(w)
            w.combat = true
            WowVision.input:getBinding("restedxp/guides").info.func()
            t:assertEqual(#w.opened, 0)
            t:assertEqual(w.spoken[1], "Not available in combat.")
        end)
    end,
})

end
