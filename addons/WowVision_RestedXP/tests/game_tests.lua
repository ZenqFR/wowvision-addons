return function(runner, env)
local loadAddon = env.loadAddon

local FILES = { "Locale", "Text", "Source", "Game" }

-- Runs fn with some globals set (nil removes one), and always puts them back.
local function withGlobals(values, fn)
    local saved = {}
    for key in pairs(values) do
        saved[key] = rawget(_G, key)
    end
    for key, value in pairs(values) do
        rawset(_G, key, value)
    end
    local ok, err = pcall(fn)
    for key in pairs(values) do
        rawset(_G, key, saved[key])
    end
    if not ok then
        error(err, 0)
    end
end

runner:addSuite("Game: the settings", {
    ["defaults when nothing is saved"] = function(t)
        local ns = loadAddon(FILES)
        withGlobals({ WowVisionRestedXPDB = false }, function()
            rawset(_G, "WowVisionRestedXPDB", nil)
            t:assertEqual(ns.Game.getSetting("announceSteps"), true)
            t:assertEqual(ns.Game.getSetting("announceDestination"), false)
            t:assertEqual(ns.Game.getSetting("recalculate"), true)
            t:assertEqual(ns.Game.getSetting("ignoreSmallMoves"), false)
            t:assertNil(ns.Game.getSetting("unknown"))
        end)
    end,
    ["a saved value, false included, wins over the default"] = function(t)
        local ns = loadAddon(FILES)
        withGlobals({ WowVisionRestedXPDB = { announceSteps = false, announceDestination = true, recalculate = false, ignoreSmallMoves = true } }, function()
            t:assertEqual(ns.Game.getSetting("announceSteps"), false)
            t:assertEqual(ns.Game.getSetting("announceDestination"), true)
            t:assertEqual(ns.Game.getSetting("recalculate"), false)
            t:assertEqual(ns.Game.getSetting("ignoreSmallMoves"), true)
        end)
    end,
    ["setting one creates the saved table"] = function(t)
        local ns = loadAddon(FILES)
        withGlobals({ WowVisionRestedXPDB = false }, function()
            rawset(_G, "WowVisionRestedXPDB", nil)
            ns.Game.setSetting("announceSteps", false)
            t:assertEqual(ns.Game.getSetting("announceSteps"), false)
            t:assertEqual(type(rawget(_G, "WowVisionRestedXPDB")), "table")
        end)
    end,
    ["the table the client hands over late is the one that is read"] = function(t)
        local ns = loadAddon(FILES)
        withGlobals({ WowVisionRestedXPDB = {} }, function()
            ns.Game.setSetting("announceSteps", false)
            -- the client replaces the saved variable after the addon loaded
            rawset(_G, "WowVisionRestedXPDB", { announceSteps = true })
            t:assertEqual(ns.Game.getSetting("announceSteps"), true)
            ns.Game.setSetting("announceDestination", true)
            t:assertEqual(rawget(_G, "WowVisionRestedXPDB").announceDestination, true)
        end)
    end,
})

runner:addSuite("Game: the game's pieces", {
    ["the way the player faces is a number, else nil"] = function(t)
        local ns = loadAddon(FILES)
        withGlobals({ GetPlayerFacing = function() return 1.5 end }, function()
            t:assertEqual(ns.Game.facing(), 1.5)
        end)
        withGlobals({ GetPlayerFacing = function() return nil end }, function()
            t:assertNil(ns.Game.facing())
        end)
        withGlobals({ GetPlayerFacing = function() return "secret" end }, function()
            t:assertNil(ns.Game.facing())
        end)
        withGlobals({ GetPlayerFacing = function() error("hidden") end }, function()
            t:assertNil(ns.Game.facing())
        end)
        withGlobals({ GetPlayerFacing = false }, function()
            rawset(_G, "GetPlayerFacing", nil)
            t:assertNil(ns.Game.facing())
        end)
    end,
    ["the player's level"] = function(t)
        local ns = loadAddon(FILES)
        withGlobals({ UnitLevel = function(unit) return unit == "player" and 12 or nil end }, function()
            t:assertEqual(ns.Game.playerLevel(), 12)
        end)
        withGlobals({ UnitLevel = function() error("no") end }, function()
            t:assertNil(ns.Game.playerLevel())
        end)
    end,
    ["combat"] = function(t)
        local ns = loadAddon(FILES)
        withGlobals({ InCombatLockdown = function() return true end }, function()
            t:assertTrue(ns.Game.inCombat())
        end)
        withGlobals({ InCombatLockdown = function() return false end }, function()
            t:assertFalse(ns.Game.inCombat())
        end)
        withGlobals({ InCombatLockdown = false }, function()
            rawset(_G, "InCombatLockdown", nil)
            t:assertFalse(ns.Game.inCombat())
        end)
    end,
    ["HereBeDragons through LibStub, nil when absent or failing"] = function(t)
        local ns = loadAddon(FILES)
        local lib = {}
        withGlobals({ LibStub = function(name, silent) return name == "HereBeDragons-2.0" and lib or nil end }, function()
            t:assertEqual(ns.Game.hbd(), lib)
        end)
        withGlobals({ LibStub = function() error("missing") end }, function()
            t:assertNil(ns.Game.hbd())
        end)
        withGlobals({ LibStub = false }, function()
            rawset(_G, "LibStub", nil)
            t:assertNil(ns.Game.hbd())
        end)
    end,
    ["WowVision's maps module, nil when there is none"] = function(t)
        local ns = loadAddon(FILES)
        local maps = {}
        withGlobals({ WowVision = { base = { navigation = { maps = maps } } } }, function()
            t:assertEqual(ns.Game.maps(), maps)
        end)
        withGlobals({ WowVision = { base = {} } }, function()
            t:assertNil(ns.Game.maps())
        end)
        withGlobals({ WowVision = false }, function()
            rawset(_G, "WowVision", nil)
            t:assertNil(ns.Game.maps())
        end)
    end,
    ["speech goes to WowVision, else to print; empty text is not said"] = function(t)
        local ns = loadAddon(FILES)
        local said = {}
        withGlobals({ WowVision = { speak = function(_, text) tinsert(said, text) end } }, function()
            ns.Game.speak("hello")
            ns.Game.speak("")
            ns.Game.speak(nil)
        end)
        t:assertEqual(#said, 1)
        t:assertEqual(said[1], "hello")
        local printed = {}
        withGlobals({ WowVision = false, print = function(text) tinsert(printed, text) end }, function()
            rawset(_G, "WowVision", nil)
            ns.Game.speak("fallback")
        end)
        t:assertEqual(printed[1], "fallback")
    end,
    ["defer and after wait for the game's timer, and run at once without one"] = function(t)
        local ns = loadAddon(FILES)
        local ran, seconds = 0, nil
        withGlobals({ C_Timer = { After = function(s, fn) seconds = s; fn() end } }, function()
            ns.Game.defer(function() ran = ran + 1 end)
            t:assertEqual(seconds, 0)
            ns.Game.after(0.5, function() ran = ran + 1 end)
            t:assertEqual(seconds, 0.5)
        end)
        t:assertEqual(ran, 2)
        withGlobals({ C_Timer = false }, function()
            rawset(_G, "C_Timer", nil)
            ns.Game.defer(function() ran = ran + 1 end)
            ns.Game.after(1, function() ran = ran + 1 end)
        end)
        t:assertEqual(ran, 4)
    end,
})

runner:addSuite("Game: reloading", {
    ["it reloads the interface, and does nothing where there is no such call"] = function(t)
        local ns = loadAddon(FILES)
        local reloads = 0
        withGlobals({ ReloadUI = function() reloads = reloads + 1 end }, function()
            ns.Game.reload()
        end)
        t:assertEqual(reloads, 1)
        withGlobals({ ReloadUI = false }, function()
            rawset(_G, "ReloadUI", nil)
            ns.Game.reload()
        end)
        t:assertEqual(reloads, 1)
    end,
})

runner:addSuite("Game: the windows", {
    ["a window is open while WowVision lists it"] = function(t)
        local ns = loadAddon(FILES)
        local manager = { openWindows = { { name = "other" }, { name = "restedxp" } } }
        withGlobals({ WowVision = { UIHost = { windowManager = manager } } }, function()
            t:assertTrue(ns.Game.isOpen("restedxp"))
            t:assertFalse(ns.Game.isOpen("missing"))
        end)
        withGlobals({ WowVision = false }, function()
            rawset(_G, "WowVision", nil)
            t:assertFalse(ns.Game.isOpen("restedxp"))
        end)
    end,
    ["opening and closing go through WowVision's windows"] = function(t)
        local ns = loadAddon(FILES)
        local opened, closed
        local host = {
            openTemporaryWindow = function(_, config)
                opened = config
            end,
            closeWindow = function(_, name)
                closed = name
            end,
        }
        withGlobals({ WowVision = { UIHost = host } }, function()
            local screen = { render = function() end }
            t:assertTrue(ns.Game.open("restedxp", screen))
            t:assertEqual(opened.name, "restedxp")
            t:assertEqual(opened.graphScreen, screen)
            ns.Game.close("restedxp")
            t:assertEqual(closed, "restedxp")
        end)
        withGlobals({ WowVision = false }, function()
            rawset(_G, "WowVision", nil)
            t:assertFalse(ns.Game.open("restedxp", {}))
            ns.Game.close("restedxp")
        end)
    end,
})

runner:addSuite("Game: the options page", {
    ["the page is shown while RestedXP's canvas frame is visible"] = function(t)
        local ns = loadAddon(FILES)
        local visible = true
        local rxp = { RXPFrame = {}, RXPOptions = { IsVisible = function() return visible end } }
        withGlobals({ RXP = rxp }, function()
            t:assertTrue(ns.Game.optionsShown())
            visible = false
            t:assertFalse(ns.Game.optionsShown())
        end)
    end,
    ["no page without the frame, without RestedXP, or when asking fails"] = function(t)
        local ns = loadAddon(FILES)
        withGlobals({ RXP = { RXPFrame = {} } }, function()
            t:assertFalse(ns.Game.optionsShown())
        end)
        withGlobals({ RXP = false }, function()
            rawset(_G, "RXP", nil)
            t:assertFalse(ns.Game.optionsShown())
        end)
        withGlobals({ RXP = { RXPFrame = {}, RXPOptions = { IsVisible = function() error("gone") end } } }, function()
            t:assertFalse(ns.Game.optionsShown())
        end)
        withGlobals({ RXP = { RXPFrame = {}, RXPOptions = { IsVisible = function() return 1 end } } }, function()
            t:assertFalse(ns.Game.optionsShown())
        end)
    end,
    ["AceConfig is told a setting changed, if it is there"] = function(t)
        local ns = loadAddon(FILES)
        local told
        withGlobals({
            LibStub = function(name)
                t:assertEqual(name, "AceConfigRegistry-3.0")
                return { NotifyChange = function(_, appName) told = appName end }
            end,
        }, function()
            ns.Game.notifyOptionsChanged("RestedXP Guides")
        end)
        t:assertEqual(told, "RestedXP Guides")
        withGlobals({ LibStub = function() error("missing") end }, function()
            ns.Game.notifyOptionsChanged("RestedXP Guides")
        end)
        withGlobals({ LibStub = false }, function()
            rawset(_G, "LibStub", nil)
            ns.Game.notifyOptionsChanged("RestedXP Guides")
        end)
        withGlobals({ LibStub = function() return { NotifyChange = function() error("boom") end } end }, function()
            ns.Game.notifyOptionsChanged("RestedXP Guides")
            ns.Game.notifyOptionsChanged(nil)
        end)
    end,
    ["a polled window is created and registered once"] = function(t)
        local ns = loadAddon(FILES)
        local created, registered = {}, {}
        local manager = {
            RegisterWindow = function(_, window)
                registered[window.config.name] = window
            end,
            getWindow = function(_, name)
                return registered[name]
            end,
        }
        local windows = {
            CreateWindow = function(_, kind, config)
                tinsert(created, kind)
                return { config = config }
            end,
        }
        withGlobals({ WowVision = { UIHost = { windowManager = manager }, WindowManager = windows } }, function()
            local screen = { render = function() end }
            local function open() return true end
            t:assertTrue(ns.Game.registerWindow("restedxp-settings", open, screen))
            t:assertEqual(created[1], "CustomWindow")
            local config = registered["restedxp-settings"].config
            t:assertEqual(config.name, "restedxp-settings")
            t:assertEqual(config.isOpenFunc, open)
            t:assertEqual(config.graphScreen, screen)
            t:assertTrue(ns.Game.registerWindow("restedxp-settings", open, screen))
            t:assertEqual(#created, 1)
        end)
    end,
    ["no window manager, no window"] = function(t)
        local ns = loadAddon(FILES)
        withGlobals({ WowVision = { UIHost = {} } }, function()
            t:assertFalse(ns.Game.registerWindow("x", function() end, {}))
        end)
        withGlobals({ WowVision = false }, function()
            rawset(_G, "WowVision", nil)
            t:assertFalse(ns.Game.registerWindow("x", function() end, {}))
        end)
    end,
})

end
