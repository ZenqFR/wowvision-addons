return function(runner, env)
local loadAddon = env.loadAddon
local fakeRxp = env.fake.rxp
local fakeHbd = env.fake.hbd

local FILES = { "Locale", "Text", "Perf", "Source", "Options", "Menu", "Guidance", "Import", "Game", "Screens" }
local WOWVISION = env.wowvision
local graphEnv = dofile(env.testsDir .. "/graph_env.lua")

-- The labels the player hears first on a node.
local function label(g, node)
    return g.graph.resolveText(node.vtable.announcements[1])
end

-- A shown frame the way a Blizzard button looks to the proxy nodes.
local function frame(name)
    local f = { name = name }
    function f:IsShown()
        return true
    end
    function f:IsEnabled()
        return true
    end
    function f:GetText()
        return name
    end
    function f:GetObjectType()
        return "Button"
    end
    return f
end

-- RestedXP's drop-down list the way GenerateMenuTable builds it.
local function guideMenu(calls)
    local function load(self, group, name)
        tinsert(calls, { "load", group, name })
    end
    return {
        { text = "Available Guides", isTitle = 1, notCheckable = 1 },
        {
            text = "RestedXP Guide Forever (H)",
            notCheckable = 1,
            hasArrow = true,
            menuList = {
                { text = "1-6 Durotar", notCheckable = 1, func = load, arg1 = "Forever (H)", arg2 = "01-06 Durotar" },
                {
                    text = "Speedrun",
                    notCheckable = 1,
                    hasArrow = true,
                    menuList = { { text = "1-6 Durotar", notCheckable = 1, func = load, arg1 = "Forever (H)", arg2 = "speedrun" } },
                },
            },
        },
        { text = "", notCheckable = 1, isTitle = 1 },
        {
            text = "Display Tips",
            func = function(self, arg1)
                tinsert(calls, { "tips", arg1 })
                calls.tips = not calls.tips
            end,
            arg1 = "toggle",
            checked = function()
                return calls.tips and true or false
            end,
        },
        { text = "Import guide", notCheckable = 1, func = function() tinsert(calls, { "import" }) end },
        { text = "Options...", notCheckable = 1, func = function() tinsert(calls, { "options" }) end },
        { text = "Leveling report", notCheckable = 1, func = function() tinsert(calls, { "report" }) end },
        { text = "Greyed entry", notCheckable = 1, func = function() tinsert(calls, { "greyed" }) end, disabled = 1 },
        { text = "Close", notCheckable = 1, func = function(self) self:Hide() end },
    }
end

-- The settings, in the shape of RestedXP's: root get/set on a profile, tabs, every control type.
local function settingsTable(world)
    local profile = world.profile
    local function get(info)
        return profile[info[#info]]
    end
    local function set(info, value)
        tinsert(world.settingCalls, { info[#info], value })
        profile[info[#info]] = value
    end
    return {
        type = "group",
        name = "RestedXP Guides - v4",
        get = get,
        set = set,
        childGroups = "tab",
        args = {
            reset = {
                order = 1,
                name = "Reset Guide Progress",
                desc = "Clear guide progress",
                type = "execute",
                func = function(info)
                    tinsert(world.settingCalls, { "reset" })
                end,
                confirm = function()
                    return "Clear guide progress for current character"
                end,
            },
            general = {
                type = "group",
                name = "General",
                order = 2,
                args = {
                    showEnabled = { name = "Show all frames", type = "toggle", order = 1 },
                    lockFrames = { name = "Lock Frames", type = "toggle", order = 2 },
                    header = { name = "Features", type = "header", order = 3 },
                    note = { name = "Some note", type = "description", order = 4 },
                    arrowScale = { name = "Arrow scale", type = "range", min = 0.5, max = 2, step = 0.1, order = 5 },
                    opacity = { name = "Opacity", type = "range", min = 0, max = 1, step = 0.05, isPercent = true, order = 6 },
                    theme = {
                        name = "Theme",
                        type = "select",
                        order = 7,
                        values = { blue = "RXP Blue", dark = "Dark" },
                    },
                    code = {
                        name = "Code",
                        type = "input",
                        order = 8,
                        pattern = "^%d+$",
                        usage = "digits only",
                    },
                    tint = { name = "Tint", type = "color", order = 9, hasAlpha = true,
                        get = function() return 1, 0.5, 0, 0.8 end,
                        set = function(info, r, g, b, a) tinsert(world.settingCalls, { "tint", r, g, b, a }) end },
                    pick = {
                        name = "Pick some",
                        type = "multiselect",
                        order = 10,
                        values = { a = "Alpha", b = "Beta" },
                        get = function(info, key) return world.picks[key] end,
                        set = function(info, key, value) world.picks[key] = value end,
                    },
                    locked = { name = "Locked option", type = "toggle", order = 11, disabled = function() return profile.lockFrames end },
                },
            },
        },
    }
end

-- Everything around the screens: RestedXP, WowVision's graph, the game's pieces, replaced by doubles.
local function newWorld(config)
    config = config or {}
    local w = {
        spoken = {},
        errors = {},
        windows = {},
        opened = {},
        closed = {},
        settings = {},
        settingCalls = {},
        picks = {},
        menuCalls = {},
        profile = { showEnabled = true, lockFrames = false, arrowScale = 1, opacity = 0.35, theme = "blue", code = "12" },
        combat = false,
        facing = 0,
    }
    w.g = graphEnv(WOWVISION)
    w.ns = loadAddon(FILES)
    local ns = w.ns

    geterrorhandler = function()
        return function(err)
            tinsert(w.errors, tostring(err))
        end
    end
    unpack = unpack or table.unpack

    w.rxp = fakeRxp(config.rxp or {
        name = "1-12 Durotar",
        current = 2,
        steps = {
            { lines = { { text = "Done already", done = true } } },
            {
                lines = {
                    { text = "Accept |cRXP_FRIENDLY_Ailee::123|r's quest" },
                    { text = "Greyed line", done = true },
                    { text = "Careful here", textOnly = true },
                },
            },
            { lines = { { text = "Third step line" } } },
            { lines = { { text = "Fourth step line" } } },
        },
        active = { 2 },
        menuList = guideMenu(w.menuCalls),
    })
    w.rxp.title = "RestedXP Guides"
    -- RestedXP's importer (config.import tells how it behaves), and Battle.net's answer
    w.importer = env.fake.withImporter(w.rxp, config.import or {})
    w.savedData = rawget(_G, "RXPData")
    rawset(_G, "RXPData", config.offline and {} or { cache = true })
    w.rxp.CloseMenu = function()
        w.menuCalls.closedMenu = (w.menuCalls.closedMenu or 0) + 1
    end
    if config.rxp == nil then
        -- the second line's box was ticked by the game itself: greyed out
        w.rxp.currentGuide.steps[2].elements[2].frame.button.enabled = false
        w.rxp.arrowFrame.element = { wx = 10.5, wy = 20.25, title = "Talk to Ailee", instance = 1 }
    end
    w.hbd = fakeHbd({ 0, 0 }, 3 * math.pi / 2, 35)
    w.maps = {
        calls = {},
        guiding = false,
        directTo = function(self, x, y, name)
            tinsert(self.calls, { "directTo", x, y, name })
            self.guiding = true
        end,
        goToDestination = function(self, destination, direct)
            tinsert(self.calls, { "goToDestination", destination, direct })
            self.guiding = true
            return true
        end,
        isGuiding = function(self)
            return self.guiding
        end,
        cancelNavigation = function(self)
            tinsert(self.calls, { "cancel" })
            self.guiding = false
        end,
    }
    w.options = settingsTable(w)

    local Game = ns.Game
    Game.rxp = function()
        return w.rxp
    end
    Game.hbd = function()
        return w.hbd
    end
    Game.facing = function()
        return w.facing
    end
    Game.playerLevel = function()
        return 12
    end
    Game.inCombat = function()
        return w.combat
    end
    Game.maps = function()
        return w.maps
    end
    Game.speak = function(text)
        tinsert(w.spoken, text)
    end
    Game.defer = function(fn)
        fn()
    end
    Game.isOpen = function(name)
        return w.windows[name] ~= nil
    end
    Game.open = function(name, screen)
        w.windows[name] = screen
        tinsert(w.opened, name)
        return true
    end
    Game.close = function(name)
        w.windows[name] = nil
        tinsert(w.closed, name)
    end
    w.reloads = 0
    Game.reload = function()
        w.reloads = w.reloads + 1
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
    -- the options table, found the way Options.find looks for it
    rawset(_G, "LibStub", function()
        return {
            GetOptionsTable = function()
                return w.options
            end,
        }
    end)

    w.driver = w.g.driver(function(builder, screen)
        ns.Screens.renderMain(builder, screen)
    end)
    w.importDriver = w.g.driver(function(builder, screen)
        ns.Screens.renderImport(builder, screen)
    end)
    function w.finish()
        rawset(_G, "LibStub", nil)
        rawset(_G, "RXPData", w.savedData)
    end
    return w
end

-- Runs fn(world) and always cleans the globals the world set.
local function withWorld(config, fn)
    local w = newWorld(config)
    local ok, err = pcall(fn, w)
    w.finish()
    if not ok then
        error(err, 0)
    end
end

local function stops(d)
    local result, seen = {}, {}
    for _, node in ipairs(d.nodes()) do
        if not seen[node.stopKey] then
            seen[node.stopKey] = true
            tinsert(result, node.stopKey)
        end
    end
    return table.concat(result, ",")
end

-- The first node whose first part starts with text, focused; errors when there is none.
local function go(t, d, text)
    local node = d.focus(text)
    if node == nil then
        error("no node reads '" .. text .. "'; the screen reads: " .. table.concat(d.dump(), " | "), 2)
    end
    return node
end

runner:addSuite("Screens: the main screen", {
    ["without RestedXP it says so"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.rxp = function()
                return nil
            end
            local lines = w.driver.dump()
            t:assertEqual(#lines, 1)
            t:assertMatch(lines[1], "RestedXP is not loaded")
        end)
    end,
    ["the stops come in the order a player needs them"] = function(t)
        withWorld(nil, function(w)
            t:assertEqual(stops(w.driver), "steps,arrow,navigation,menu,settings,own")
        end)
    end,
    ["the guide line gives the name and the step"] = function(t)
        withWorld(nil, function(w)
            local node = w.driver.nodes()[1]
            t:assertEqual(label(w.g, node), "1-12 Durotar. Step 2 of 4")
        end)
    end,
    ["a line to do is a box, a line done by the game, an optional and an info line are text"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local accept = go(t, d, "Accept Ailee's quest")
            t:assertEqual(accept.vtable.controlType, w.g.graph.controlTypes.toggle)
            local greyed = go(t, d, "Greyed line")
            t:assertEqual(greyed.vtable.controlType, w.g.graph.controlTypes.text)
            t:assertMatch(d.say(greyed), "Greyed line, done")
            local info = go(t, d, "Careful here")
            t:assertEqual(info.vtable.controlType, w.g.graph.controlTypes.text)
            t:assertNil(info.vtable.onActivate)
        end)
    end,
    ["Enter ticks a box, and the box reads done"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "Accept Ailee's quest")
            t:assertMatch(d.say(), "to do")
            t:assertTrue(d.enter())
            local element = w.rxp.currentGuide.steps[2].elements[1]
            t:assertTrue(element.skip)
            t:assertEqual(w.rxp.calls.postClick, 1)
            t:assertMatch(d.say(), "done")
            -- and again unticks it
            d.enter()
            t:assertFalse(element.skip)
            t:assertMatch(d.say(), "to do")
        end)
    end,
    ["each step is a level of its own, named by its title"] = function(t)
        withWorld({
            rxp = {
                name = "Guide",
                steps = {
                    { title = "Durotar", lines = { { text = "a" } } },
                    { sticky = true, lines = { { text = "b" } } },
                    { tip = true, lines = { { text = "c" } } },
                },
                active = { 1, 2, 3 },
            },
        }, function(w)
            local d = w.driver
            local a = go(t, d, "a")
            local b = go(t, d, "b")
            local c = go(t, d, "c")
            t:assertEqual(a.parent.vtable.announcements[1].text, "Durotar")
            t:assertEqual(b.parent.vtable.announcements[1].text, "Ongoing step")
            t:assertEqual(c.parent.vtable.announcements[1].text, "Tip")
        end)
    end,
    ["two active steps with the same line number keep distinct identities"] = function(t)
        withWorld({
            rxp = {
                name = "Guide",
                steps = {
                    { lines = { { text = "same" } } },
                    { lines = { { text = "same" } } },
                },
                active = { 1, 2 },
            },
        }, function(w)
            local count = 0
            for _, node in ipairs(w.driver.nodes()) do
                if label(w.g, node) == "same" then
                    count = count + 1
                end
            end
            t:assertEqual(count, 2)
        end)
    end,
    ["no guide: it says so and offers the rest"] = function(t)
        withWorld({ rxp = { name = "x", steps = { { lines = { { text = "a" } } } }, empty = true } }, function(w)
            w.rxp.RXPFrame.GenerateMenuTable = function()
                w.rxp.RXPFrame.menuList = guideMenu(w.menuCalls)
            end
            local d = w.driver
            t:assertEqual(label(w.g, d.nodes()[1]), "No guide chosen. Open the menu to choose one.")
            t:assertEqual(stops(d), "steps,arrow,menu,settings,own")
        end)
    end,
    ["a guide whose steps are all done shows no step"] = function(t)
        withWorld({ rxp = { name = "x", steps = { { lines = { { text = "a" } } } }, active = {} } }, function(w)
            local lines = w.driver.dump()
            t:assertMatch(lines[1], "x")
            t:assertMatch(lines[2], "No step to show right now")
        end)
    end,
})

runner:addSuite("Screens: the arrow", {
    ["the arrow reads its destination, direction and distance"] = function(t)
        withWorld(nil, function(w)
            local node = go(t, w.driver, "Talk to Ailee")
            t:assertEqual(w.driver.say(node), "Talk to Ailee, at 3 o'clock, to your right, 35 yards, 1 of 5")
        end)
    end,
    ["the arrow reads again as the player walks"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local node = go(t, d, "Talk to Ailee")
            w.hbd = fakeHbd({ 0, 0 }, 0, 12)
            w.ns.Game.hbd = function()
                return w.hbd
            end
            t:assertMatch(d.say(node), "ahead of you, 12 yards")
        end)
    end,
    ["without the facing there is no direction"] = function(t)
        withWorld(nil, function(w)
            w.facing = nil
            local node = go(t, w.driver, "Talk to Ailee")
            t:assertMatch(w.driver.say(node), "^Talk to Ailee, 35 yards")
        end)
    end,
    ["without a destination it says so"] = function(t)
        withWorld(nil, function(w)
            w.rxp.arrowFrame.element = nil
            local node = go(t, w.driver, "No destination")
            t:assertNotNil(node)
        end)
    end,
    ["a failing position read is spoken as hidden"] = function(t)
        withWorld(nil, function(w)
            w.hbd = {
                GetPlayerWorldPosition = function()
                    error("secret")
                end,
            }
            local node = go(t, w.driver, "The game hides the position")
            t:assertNotNil(node)
        end)
    end,
    ["the sound beacon asks WowVision for a straight beacon at the swapped point"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "Sound beacon toward the destination")
            t:assertTrue(d.enter())
            t:assertEqual(w.maps.calls[1][1], "directTo")
            t:assertEqual(w.maps.calls[1][2], 20.25)
            t:assertEqual(w.maps.calls[1][3], 10.5)
            t:assertEqual(w.maps.calls[1][4], "Talk to Ailee")
            t:assertMatch(d.say(go(t, d, "Sound beacon")), "selected")
        end)
    end,
    ["the route asks WowVision to go to the destination"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "WowVision route to the destination")
            d.enter()
            t:assertEqual(w.maps.calls[1][1], "goToDestination")
            t:assertFalse(w.maps.calls[1][3])
            t:assertEqual(w.maps.calls[1][2].x, 20.25)
        end)
    end,
    ["a box says whether the guidance is recalculated when the arrow moves: ticked to start with"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local node = go(t, d, "Recalculate the guidance when the arrow changes destination")
            t:assertEqual(node.vtable.controlType, w.g.graph.controlTypes.toggle)
            t:assertMatch(d.say(node), "Checked")
        end)
    end,
    ["Enter unticks it and ticks it again, and the setting follows"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local node = go(t, d, "Recalculate the guidance")
            d.enter()
            t:assertEqual(w.settings.recalculate, false)
            t:assertMatch(d.say(node), "Unchecked")
            d.enter()
            t:assertEqual(w.settings.recalculate, true)
            t:assertMatch(d.say(node), "Checked")
        end)
    end,
    ["a second box ignores small moves of the arrow: unticked to start with, and it says how far"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local node = go(t, d, "Ignore small moves of the arrow")
            t:assertEqual(node.vtable.controlType, w.g.graph.controlTypes.toggle)
            t:assertMatch(d.say(node), "^Ignore small moves of the arrow %(under 10 yards%), Checkbox, Unchecked")
        end)
    end,
    ["Enter ticks it and unticks it again, and the setting follows"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local node = go(t, d, "Ignore small moves of the arrow")
            d.enter()
            t:assertEqual(w.settings.ignoreSmallMoves, true)
            t:assertMatch(d.say(node), "Checked")
            t:assertFalse(d.say(node):find("Unchecked", 1, true) ~= nil)
            d.enter()
            t:assertEqual(w.settings.ignoreSmallMoves, false)
            t:assertMatch(d.say(node), "Unchecked")
        end)
    end,
    ["that box says metres in French and Meter in German"] = function(t)
        withWorld(nil, function(w)
            w.ns.useLocale("frFR")
            t:assertMatch(w.driver.say(go(t, w.driver, "Ignorer les petits déplacements de la flèche")), "moins de 10 mètres")
            w.ns.useLocale("deDE")
            t:assertMatch(w.driver.say(go(t, w.driver, "Kleine Verschiebungen des Pfeils ignorieren")), "unter 10 Meter")
            w.ns.useLocale("enUS")
        end)
    end,
    ["the box sits in the arrow part, after the guiding items and the stop"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local lines = d.dump()
            local beacon, route, box
            for index, line in ipairs(lines) do
                if line:find("^Sound beacon") then
                    beacon = index
                elseif line:find("^WowVision route") then
                    route = index
                elseif line:find("^Recalculate the guidance") then
                    box = index
                end
            end
            t:assertTrue(beacon < route and route < box)
            go(t, d, "Sound beacon toward the destination")
            d.enter()
            local stop, after
            for index, line in ipairs(d.dump()) do
                if line:find("^Stop guiding") then
                    stop = index
                elseif line:find("^Recalculate the guidance") then
                    after = index
                end
            end
            t:assertTrue(stop < after)
        end)
    end,
    ["stop guiding appears while guided and ends it"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            t:assertNil(d.focus("Stop guiding"))
            go(t, d, "Sound beacon toward the destination")
            d.enter()
            go(t, d, "Stop guiding")
            d.enter()
            t:assertEqual(w.maps.calls[2][1], "cancel")
            t:assertNil(d.focus("Stop guiding"))
        end)
    end,
    ["a message says why guiding could not start"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.maps = function()
                return nil
            end
            local d = w.driver
            go(t, d, "Sound beacon toward the destination")
            d.enter()
            t:assertEqual(w.spoken[#w.spoken], "WowVision's navigation is not available.")
        end)
        withWorld(nil, function(w)
            w.rxp.arrowFrame.element = nil
            local d = w.driver
            go(t, d, "WowVision route to the destination")
            d.enter()
            t:assertEqual(w.spoken[#w.spoken], "No destination in the guide right now.")
        end)
    end,
})

runner:addSuite("Screens: moving in the guide", {
    ["next and previous go to the neighbouring steps"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "Next step")
            d.enter()
            go(t, d, "Previous step")
            d.enter()
            t:assertEqual(table.concat(w.rxp.calls.setStep, ","), "3,2")
        end)
    end,
    ["a number node goes to the step it is set to"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local node = go(t, d, "Go to step number")
            t:assertMatch(d.say(node), "Step 2 of 4")
            t:assertTrue(d.adjust(1))
            t:assertEqual(w.rxp.calls.setStep[1], 3)
            t:assertTrue(d.adjust(1, true))
            t:assertEqual(w.rxp.calls.setStep[2], 4)
        end)
    end,
    ["skipping ticks the boxes of the step now shown"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "Skip the step now shown")
            d.enter()
            t:assertTrue(w.rxp.currentGuide.steps[2].elements[1].skip)
            t:assertEqual(#w.spoken, 0)
            d.enter()
            t:assertEqual(w.spoken[#w.spoken], "Nothing to skip.")
        end)
    end,
    ["the steps to come open as a list"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "Steps to come")
            t:assertEqual(d.right().kind, "expanded")
            local lines = d.dump()
            local found = {}
            for _, line in ipairs(lines) do
                if line:find("Step 3. Third step line") or line:find("Step 4. Fourth step line") then
                    tinsert(found, line)
                end
            end
            t:assertEqual(#found, 2)
            t:assertEqual(d.left().kind, "collapsed")
        end)
    end,
    ["with no step to come it says so"] = function(t)
        withWorld({ rxp = { name = "x", current = 1, steps = { { lines = { { text = "only" } } } }, active = { 1 } } }, function(w)
            local d = w.driver
            go(t, d, "Steps to come")
            d.right()
            t:assertNotNil(d.focus("No step to come"))
        end)
    end,
})

runner:addSuite("Screens: items and targets", {
    ["the active items and creatures are buttons that click the real ones"] = function(t)
        local item = frame("Linen Bandage")
        local enemy = frame("Kobold Vermin")
        item.name = "Linen Bandage"
        enemy.targetData = { name = "Kobold Vermin" }
        rawset(_G, "RXPItemFrameButton1", item)
        rawset(_G, "RXPTargetFrame_EnemyButton1", enemy)
        local ok, err = pcall(function()
            withWorld(nil, function(w)
                local d = w.driver
                t:assertEqual(stops(d), "steps,arrow,navigation,items,enemies,menu,settings,own")
                local bandage = go(t, d, "Linen Bandage")
                local click = bandage.vtable.bindings[1]
                t:assertEqual(click.type, "Click")
                t:assertEqual(click.target, item)
                local creature = go(t, d, "Kobold Vermin")
                t:assertEqual(creature.vtable.bindings[1].target, enemy)
            end)
        end)
        rawset(_G, "RXPItemFrameButton1", nil)
        rawset(_G, "RXPTargetFrame_EnemyButton1", nil)
        if not ok then
            error(err, 0)
        end
    end,
})

runner:addSuite("Screens: RestedXP's menu", {
    ["the menu hides what cannot be used here"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            t:assertNotNil(d.focus("Available Guides"))
            t:assertNotNil(d.focus("Display Tips"))
            t:assertNil(d.focus("Import guide"))
            t:assertNil(d.focus("Options..."))
            t:assertNil(d.focus("Leveling report"))
            t:assertNil(d.focus("Close"))
        end)
    end,
    ["a disabled entry reads as unavailable"] = function(t)
        withWorld(nil, function(w)
            local node = go(t, w.driver, "Greyed entry")
            t:assertMatch(w.driver.say(node), "Greyed entry, unavailable")
            t:assertNil(node.vtable.onActivate)
        end)
    end,
    ["guides open as groups, to any depth, and a guide loads and closes the window"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "RestedXP Guide Forever (H)")
            t:assertEqual(d.right().kind, "expanded")
            go(t, d, "Speedrun")
            t:assertEqual(d.right().kind, "expanded")
            -- two guides share a name in different groups: both are there, told apart by their place
            local both = 0
            for _, line in ipairs(d.dump()) do
                if line:find("^1%-6 Durotar") then
                    both = both + 1
                end
            end
            t:assertEqual(both, 2)
            local nodes = d.nodes()
            local speedrunGuide
            for _, node in ipairs(nodes) do
                if label(w.g, node) == "1-6 Durotar" and node.parent ~= nil and label(w.g, node.parent) == "Speedrun" then
                    speedrunGuide = node
                end
            end
            t:assertNotNil(speedrunGuide)
            w.driver.kg:focus(speedrunGuide.id)
            d.enter()
            t:assertEqual(w.menuCalls[1][1], "load")
            t:assertEqual(w.menuCalls[1][3], "speedrun")
            t:assertEqual(w.closed[#w.closed], "restedxp")
            t:assertEqual(w.menuCalls.closedMenu, 1)
        end)
    end,
    ["a box in the menu runs its function and closes the window"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local node = go(t, d, "Display Tips")
            t:assertEqual(node.vtable.controlType, w.g.graph.controlTypes.toggle)
            d.enter()
            t:assertEqual(w.menuCalls[1][1], "tips")
            t:assertEqual(w.menuCalls[1][2], "toggle")
            t:assertEqual(w.closed[#w.closed], "restedxp")
        end)
    end,
    ["a menu that keeps itself open stays open"] = function(t)
        withWorld(nil, function(w)
            local calls = w.menuCalls
            w.rxp.RXPFrame.menuList = {
                { text = "Stay", keepShownOnClick = 1, func = function() tinsert(calls, { "stay" }) end, checked = function() return false end },
            }
            w.rxp.RXPFrame.GenerateMenuTable = function() end
            local d = w.driver
            go(t, d, "Stay")
            d.enter()
            t:assertEqual(calls[1][1], "stay")
            t:assertEqual(#w.closed, 0)
        end)
    end,
    ["a failing entry is reported and spoken, and the window still closes"] = function(t)
        withWorld(nil, function(w)
            w.rxp.RXPFrame.menuList = { { text = "Bad", notCheckable = 1, func = function() error("boom") end } }
            w.rxp.RXPFrame.GenerateMenuTable = function() end
            local d = w.driver
            go(t, d, "Bad")
            d.enter()
            t:assertEqual(w.closed[#w.closed], "restedxp")
            t:assertEqual(w.spoken[#w.spoken], "That entry failed.")
            t:assertMatch(w.errors[1], "boom")
        end)
    end,
    ["the menu is read once when the screen opens"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            d.nodes()
            d.nodes()
            d.nodes()
            t:assertEqual(w.rxp.calls.menu, 1)
        end)
    end,
})

runner:addSuite("Screens: RestedXP's settings", {
    ["the tabs are groups, closed to start with"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            t:assertNotNil(d.focus("Reset Guide Progress"))
            local general = go(t, d, "General")
            t:assertTrue(general.expandable)
            t:assertFalse(general.expanded)
            t:assertNil(d.focus("Show all frames"))
        end)
    end,
    ["a toggle shows its state and flips it through the option's own set"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            local node = go(t, d, "Lock Frames")
            t:assertMatch(d.say(node), "Unchecked")
            d.enter()
            t:assertTrue(w.profile.lockFrames)
            t:assertEqual(w.settingCalls[1][1], "lockFrames")
            t:assertMatch(d.say(), "Checked")
        end)
    end,
    ["a slider adjusts by its step and clamps to its limits"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            go(t, d, "Arrow scale")
            d.adjust(1)
            t:assertTrue(math.abs(w.profile.arrowScale - 1.1) < 1e-9, "got " .. w.profile.arrowScale)
            w.profile.arrowScale = 2
            d.adjust(1)
            t:assertEqual(w.profile.arrowScale, 2)
            w.profile.arrowScale = 0.5
            d.adjust(-1)
            t:assertEqual(w.profile.arrowScale, 0.5)
        end)
    end,
    ["a percent slider speaks percent and moves by points"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            local node = go(t, d, "Opacity")
            t:assertMatch(d.say(node), "35 percent")
            d.adjust(1)
            t:assertTrue(math.abs(w.profile.opacity - 0.4) < 1e-9, "got " .. w.profile.opacity)
            t:assertMatch(d.say(), "40 percent")
        end)
    end,
    ["a percent slider is typed in percent too"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            go(t, d, "Opacity")
            d.enter()
            t:assertEqual(#w.g.entries, 1)
            t:assertEqual(w.g.entries[1].text, "35")
            w.g.entries[1].onCommit("40")
            t:assertTrue(math.abs(w.profile.opacity - 0.4) < 1e-9, "got " .. w.profile.opacity)
            -- and a value past the end is held to it
            w.g.entries[1].onCommit("250")
            t:assertEqual(w.profile.opacity, 1)
        end)
    end,
    ["a list opens its choices and sets the picked value"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            local node = go(t, d, "Theme")
            t:assertMatch(d.say(node), "RXP Blue")
            d.enter()
            t:assertEqual(#w.g.pushed, 1)
            -- the pushed screen lists the values
            local choices = w.g.driver(w.g.pushed[1].render)
            local lines = choices.dump()
            t:assertMatch(lines[1], "Dark")
            choices.focus("Dark")
            choices.enter()
            t:assertEqual(w.profile.theme, "dark")
        end)
    end,
    ["typed input is checked against the option's pattern"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            local node = go(t, d, "Code")
            d.enter()
            t:assertEqual(#w.g.entries, 1)
            w.g.entries[1].onCommit("abc")
            t:assertEqual(w.profile.code, "12")
            t:assertEqual(w.spoken[#w.spoken], "Code: digits only")
            w.g.entries[1].onCommit("345")
            t:assertEqual(w.profile.code, "345")
        end)
    end,
    ["a colour is read and set as six hex digits"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            local node = go(t, d, "Tint")
            t:assertMatch(d.say(node), "#FF8000")
            d.enter()
            w.g.entries[1].onCommit("00ff00")
            local call = w.settingCalls[#w.settingCalls]
            t:assertEqual(call[1], "tint")
            t:assertEqual(call[2], 0)
            t:assertEqual(call[3], 1)
            t:assertEqual(call[4], 0)
            t:assertEqual(call[5], 0.8)
            w.g.entries[1].onCommit("nonsense")
            t:assertMatch(w.spoken[#w.spoken], "six hexadecimal digits")
        end)
    end,
    ["a list of boxes is a group of toggles"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            go(t, d, "Pick some")
            t:assertEqual(d.right().kind, "expanded")
            go(t, d, "Beta")
            d.enter()
            t:assertTrue(w.picks.b)
            t:assertMatch(d.say(), "Checked")
        end)
    end,
    ["headers and descriptions read as text"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            t:assertEqual(go(t, d, "Features").vtable.controlType, w.g.graph.controlTypes.text)
            t:assertEqual(go(t, d, "Some note").vtable.controlType, w.g.graph.controlTypes.text)
        end)
    end,
    ["a disabled option says unavailable and does nothing"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "General")
            d.right()
            local node = go(t, d, "Locked option")
            w.profile.lockFrames = true
            t:assertMatch(d.say(node), "unavailable")
            d.enter()
            t:assertEqual(w.spoken[#w.spoken], "unavailable")
            t:assertEqual(#w.settingCalls, 0)
        end)
    end,
    ["a button that asks to confirm opens a confirmation first"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            go(t, d, "Reset Guide Progress")
            d.enter()
            t:assertEqual(#w.settingCalls, 0)
            t:assertEqual(#w.g.pushed, 1)
            local confirm = w.g.driver(w.g.pushed[1].render)
            t:assertMatch(confirm.dump()[1], "Clear guide progress for current character")
            confirm.focus("Yes")
            confirm.enter()
            t:assertEqual(w.settingCalls[1][1], "reset")
        end)
    end,
    ["a failing setting is reported and spoken"] = function(t)
        withWorld(nil, function(w)
            w.options.args.general.args.lockFrames.set = function()
                error("refused")
            end
            local d = w.driver
            go(t, d, "General")
            d.right()
            go(t, d, "Lock Frames")
            d.enter()
            t:assertEqual(w.spoken[#w.spoken], "That setting could not be changed.")
            t:assertMatch(w.errors[1], "refused")
        end)
    end,
    ["without the options table there are no settings stop"] = function(t)
        withWorld(nil, function(w)
            rawset(_G, "LibStub", nil)
            t:assertEqual(stops(w.driver), "steps,arrow,navigation,menu,own")
        end)
    end,
})

runner:addSuite("Screens: RestedXP's page in the game's options window", {
    ["it shows the same settings while the page is on screen"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.optionsShown = function()
                return true
            end
            local d = w.g.driver(w.ns.Screens.renderOptions)
            local lines = d.dump()
            t:assertMatch(lines[1], "Reset Guide Progress")
            go(t, d, "General")
            d.right()
            go(t, d, "Lock Frames")
            d.enter()
            t:assertTrue(w.profile.lockFrames)
        end)
    end,
    ["it is empty, so the screen goes away, when the page is not shown"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.optionsShown = function()
                return false
            end
            local d = w.g.driver(w.ns.Screens.renderOptions)
            t:assertFalse(d.kg:rerender())
        end)
    end,
    ["it is empty without RestedXP or without its options"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.optionsShown = function()
                return true
            end
            w.ns.Game.rxp = function()
                return nil
            end
            t:assertFalse(w.g.driver(w.ns.Screens.renderOptions).kg:rerender())
        end)
        withWorld(nil, function(w)
            w.ns.Game.optionsShown = function()
                return true
            end
            rawset(_G, "LibStub", nil)
            t:assertFalse(w.g.driver(w.ns.Screens.renderOptions).kg:rerender())
        end)
    end,
    ["it is registered as a window that follows the page"] = function(t)
        withWorld(nil, function(w)
            local registered
            w.ns.Game.registerWindow = function(name, isOpenFunc, screen)
                registered = { name = name, isOpenFunc = isOpenFunc, screen = screen }
                return true
            end
            t:assertTrue(w.ns.Screens.registerOptionsWindow())
            t:assertEqual(registered.name, "restedxp-settings")
            t:assertEqual(type(registered.screen.render), "function")
            t:assertTrue(registered.screen.letterNavigation)
            -- no Escape of its own: the game closes its window and the page goes with it
            t:assertNil(registered.screen.captureClose)
            local shown = false
            w.ns.Game.optionsShown = function()
                return shown
            end
            t:assertFalse(registered.isOpenFunc())
            shown = true
            t:assertTrue(registered.isOpenFunc())
        end)
    end,
    ["a change tells AceConfig so the page drawn for sighted players follows"] = function(t)
        withWorld(nil, function(w)
            local told = {}
            w.ns.Game.notifyOptionsChanged = function(appName)
                tinsert(told, appName)
            end
            local d = w.driver
            go(t, d, "General")
            d.right()
            go(t, d, "Lock Frames")
            d.enter()
            t:assertEqual(told[1], "RestedXP Guides")
            -- a refused change does not
            w.options.args.general.args.showEnabled.set = function()
                error("refused")
            end
            go(t, d, "Show all frames")
            d.enter()
            t:assertEqual(#told, 1)
        end)
    end,
})

runner:addSuite("Screens: not reading the settings again every frame", {
    -- a hidden function stands for what the options table has to work out for a group on every read
    ["a group's options are read once a quarter of a second"] = function(t)
        withWorld(nil, function(w)
            local now = 50
            w.ns.Game.now = function()
                return now
            end
            local reads = 0
            w.options.args.general.args.showEnabled.hidden = function()
                reads = reads + 1
                return false
            end
            local d = w.driver
            go(t, d, "General")
            d.right()
            d.nodes()
            local first = reads
            t:assertTrue(first >= 1)
            d.nodes()
            d.nodes()
            d.nodes()
            t:assertEqual(reads, first)
            now = 50.3
            d.nodes()
            t:assertEqual(reads, first + 1)
        end)
    end,
    ["a change is read at once"] = function(t)
        withWorld(nil, function(w)
            local now = 50
            w.ns.Game.now = function()
                return now
            end
            local reads = 0
            w.options.args.general.args.lockFrames.hidden = function()
                reads = reads + 1
                return false
            end
            local d = w.driver
            go(t, d, "General")
            d.right()
            go(t, d, "Lock Frames")
            local before = reads
            d.enter()
            d.nodes()
            t:assertTrue(reads > before)
        end)
    end,
    ["what appears when an option changes shows at once"] = function(t)
        withWorld(nil, function(w)
            local now = 50
            w.ns.Game.now = function()
                return now
            end
            w.options.args.general.args.extra = {
                type = "toggle",
                name = "Only with the lock",
                order = 12,
                hidden = function()
                    return not w.profile.lockFrames
                end,
            }
            local d = w.driver
            go(t, d, "General")
            d.right()
            t:assertNil(d.focus("Only with the lock"))
            go(t, d, "Lock Frames")
            d.enter()
            t:assertNotNil(d.focus("Only with the lock"))
        end)
    end,
    ["each group has its own read"] = function(t)
        withWorld(nil, function(w)
            local now = 50
            w.ns.Game.now = function()
                return now
            end
            w.options.args.other = {
                type = "group",
                name = "Other",
                order = 3,
                args = { thing = { type = "toggle", name = "A thing", order = 1 } },
            }
            local d = w.driver
            go(t, d, "General")
            d.right()
            go(t, d, "Other")
            d.right()
            t:assertNotNil(d.focus("A thing"))
            t:assertNotNil(d.focus("Lock Frames"))
        end)
    end,
    ["without the clock every frame reads again"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.now = function()
                return nil
            end
            local reads = 0
            w.options.args.general.args.showEnabled.hidden = function()
                reads = reads + 1
                return false
            end
            local d = w.driver
            go(t, d, "General")
            d.right()
            d.nodes()
            local first = reads
            d.nodes()
            t:assertTrue(reads > first)
        end)
    end,
})

runner:addSuite("Screens: timed", {
    ["each screen is timed under its own name"] = function(t)
        withWorld(nil, function(w)
            w.ns.Perf.reset()
            w.ns.Game.optionsShown = function()
                return true
            end
            local main = w.g.driver(w.ns.Screens.mainConfig().render)
            main.nodes()
            local options = w.g.driver(w.ns.Screens.optionsConfig().render)
            options.nodes()
            local menu = w.g.driver(w.ns.Screens.menuConfig(guideMenu({})).render)
            menu.nodes()
            local names = {}
            for _, row in ipairs(w.ns.Perf.rows()) do
                names[row.name] = row.calls
            end
            t:assertTrue((names["main screen"] or 0) >= 1)
            t:assertTrue((names["options screen"] or 0) >= 1)
            t:assertTrue((names["menu screen"] or 0) >= 1)
            t:assertTrue((names["options table"] or 0) >= 1)
            t:assertTrue((names["menu build"] or 0) >= 1)
        end)
    end,
    ["the page poll is timed"] = function(t)
        withWorld(nil, function(w)
            w.ns.Perf.reset()
            local registered
            w.ns.Game.registerWindow = function(name, isOpenFunc, screen)
                registered = isOpenFunc
                return true
            end
            w.ns.Screens.registerOptionsWindow()
            registered()
            registered()
            local calls
            for _, row in ipairs(w.ns.Perf.rows()) do
                if row.name == "window poll" then
                    calls = row.calls
                end
            end
            t:assertEqual(calls, 2)
        end)
    end,
})

runner:addSuite("Screens: this addon's own settings", {
    ["the toggles read and write this addon's settings"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            local node = go(t, d, "Say each new step")
            t:assertMatch(d.say(node), "Checked")
            d.enter()
            t:assertEqual(w.settings.announceSteps, false)
            local other = go(t, d, "Say where the arrow points")
            t:assertMatch(d.say(other), "Unchecked")
            d.enter()
            t:assertEqual(w.settings.announceDestination, true)
        end)
    end,
})

runner:addSuite("Screens: the windows", {
    ["Shift+F2 opens the main screen and closes it again"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.toggleMain()
            t:assertEqual(w.opened[1], "restedxp")
            t:assertTrue(w.windows.restedxp.captureClose)
            t:assertTrue(w.windows.restedxp.letterNavigation)
            w.ns.Screens.toggleMain()
            t:assertEqual(w.closed[1], "restedxp")
            t:assertNil(w.windows.restedxp)
        end)
    end,
    ["in combat it says so instead of opening"] = function(t)
        withWorld(nil, function(w)
            w.combat = true
            w.ns.Screens.toggleMain()
            t:assertEqual(#w.opened, 0)
            t:assertEqual(w.spoken[1], "Not available in combat.")
        end)
    end,
    ["Escape closes the main screen"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.toggleMain()
            w.windows.restedxp.onRequestClose()
            t:assertEqual(w.closed[1], "restedxp")
        end)
    end,
    ["a menu RestedXP shows opens its own screen"] = function(t)
        withWorld(nil, function(w)
            local calls = {}
            local list = guideMenu(calls)
            w.ns.Screens.openMenu(list)
            t:assertEqual(w.opened[1], "restedxp-menu")
            local config = w.windows["restedxp-menu"]
            local d = w.g.driver(config.render)
            t:assertNotNil(d.focus("Available Guides"))
            t:assertNil(d.focus("Import guide"))
            go(t, d, "Display Tips")
            d.enter()
            t:assertEqual(calls[1][1], "tips")
            t:assertEqual(w.closed[#w.closed], "restedxp-menu")
            t:assertEqual(w.menuCalls.closedMenu, 1)
        end)
    end,
    ["Options... in a menu opens the settings, which are in the main screen"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.openMenu(guideMenu({}))
            local d = w.g.driver(w.windows["restedxp-menu"].render)
            t:assertNil(d.focus("Options..."))
            go(t, d, "RestedXP settings")
            d.enter()
            t:assertEqual(w.closed[1], "restedxp-menu")
            t:assertEqual(w.opened[#w.opened], "restedxp")
            -- and the menu of the main screen does not offer Options... a second time
            local main = w.g.driver(w.windows.restedxp.render)
            t:assertNil(main.focus("Options..."))
        end)
    end,
    ["Escape on that screen closes it and RestedXP's drop-down"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.openMenu(guideMenu({}))
            w.windows["restedxp-menu"].onRequestClose()
            t:assertEqual(w.closed[1], "restedxp-menu")
            t:assertEqual(w.menuCalls.closedMenu, 1)
        end)
    end,
    ["a second menu replaces the first, and none opens over the main screen or in combat"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.openMenu(guideMenu({}))
            w.ns.Screens.openMenu(guideMenu({}))
            t:assertEqual(#w.opened, 2)
            t:assertEqual(w.closed[1], "restedxp-menu")
            w.windows.restedxp = {}
            w.ns.Screens.openMenu(guideMenu({}))
            t:assertEqual(#w.opened, 2)
            w.windows.restedxp = nil
            w.combat = true
            w.ns.Screens.openMenu(guideMenu({}))
            t:assertEqual(#w.opened, 2)
        end)
    end,
    ["a menu with nothing usable opens an empty screen that closes by itself"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.openMenu({ { text = "Close", notCheckable = 1, func = function() end } })
            local d = w.g.driver(w.windows["restedxp-menu"].render)
            t:assertFalse(d.kg:rerender())
        end)
    end,
})

local IMPORT_GUIDES = {
    { key = "RXP Leveling||01-10 Durotar", imported = true, group = "RXP Leveling", version = 7 },
    { key = "Mine|Alts|Alt run", cache = true, group = "Mine" },
}

runner:addSuite("Screens: importing a guide", {
    ["RestedXP's Import guide entry becomes one that opens the import screen"] = function(t)
        withWorld(nil, function(w)
            local d = w.driver
            t:assertNil(d.focus("Import guide"))
            local node = go(t, d, "Import a guide")
            t:assertEqual(node.vtable.controlType, w.g.graph.controlTypes.button)
            d.enter()
            t:assertEqual(w.closed[#w.closed], "restedxp")
            t:assertEqual(w.opened[#w.opened], "restedxp-import")
            t:assertTrue(w.windows["restedxp-import"].captureClose)
            t:assertTrue(w.windows["restedxp-import"].letterNavigation)
            -- the entry has not run RestedXP's own function (its window)
            for _, call in ipairs(w.menuCalls) do
                t:assertTrue(call[1] ~= "import")
            end
        end)
    end,
    ["the entry keeps the place of RestedXP's in the menu"] = function(t)
        withWorld(nil, function(w)
            local lines = w.driver.dump()
            local tips, import, report
            for index, line in ipairs(lines) do
                if line:find("^Display Tips") then
                    tips = index
                elseif line:find("^Import a guide") then
                    import = index
                elseif line:find("^Greyed entry") then
                    report = index
                end
            end
            t:assertTrue(tips < import and import < report)
        end)
    end,
    ["the same entry in a menu RestedXP shows opens the import screen as well"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.openMenu(guideMenu({}))
            local d = w.g.driver(w.windows["restedxp-menu"].render)
            t:assertNil(d.focus("Import guide"))
            go(t, d, "Import a guide")
            d.enter()
            t:assertEqual(w.closed[1], "restedxp-menu")
            t:assertEqual(w.opened[#w.opened], "restedxp-import")
        end)
    end,
    ["RestedXP's entry is found in the game's language too"] = function(t)
        withWorld(nil, function(w)
            w.rxp.locale.Get = function(text)
                return text == "Import guide" and "Importer un guide" or text
            end
            local list = guideMenu(w.menuCalls)
            list[5].text = "Importer un guide"
            w.rxp.RXPFrame.GenerateMenuTable = function()
                w.rxp.RXPFrame.menuList = list
            end
            local d = w.g.driver(function(builder, screen)
                w.ns.Screens.renderMain(builder, screen)
            end)
            t:assertNil(d.focus("Importer un guide"))
            t:assertNotNil(d.focus("Import a guide"))
        end)
    end,
    ["the screen has two stops: paste and import, and the guides already there"] = function(t)
        withWorld(nil, function(w)
            t:assertEqual(stops(w.importDriver), "paste,manage")
            local lines = w.importDriver.dump()
            t:assertMatch(lines[1], "^Nothing pasted yet%.")
            t:assertMatch(lines[2], "^Paste a guide string")
            t:assertMatch(lines[3], "^Import the pasted guides")
        end)
    end,
    ["the first line follows the import as it goes"] = function(t)
        withWorld(nil, function(w)
            local d = w.importDriver
            local status = d.nodes()[1]
            t:assertMatch(d.say(status), "^Nothing pasted yet%.")
            w.importer:paste("12345")
            t:assertMatch(d.say(status), "^5 characters pasted, ready to import%.")
            w.rxp.workerFrame.shown = true
            w.importer.gui.progressMessage = "Total guides loaded: 2/9"
            t:assertMatch(d.say(status), "^Importing: 2 of 9 guides loaded%.")
        end)
    end,
    ["a last message shows once RestedXP has given one"] = function(t)
        withWorld(nil, function(w)
            local d = w.importDriver
            t:assertNil(d.focus("Last message"))
            w.importer:UpdateImportStatusHistory("Guides Loaded Successfully", false)
            local node = go(t, d, "Last message")
            t:assertMatch(d.say(node), "^Last message: Guides Loaded Successfully")
            w.importer:UpdateImportStatusHistory("Something else", true)
            t:assertMatch(d.say(node), "^Last message: Something else")
        end)
    end,
    ["Paste puts the keyboard in RestedXP's box and says how to paste"] = function(t)
        withWorld(nil, function(w)
            go(t, w.importDriver, "Paste a guide string")
            w.importDriver.enter()
            t:assertTrue(w.importer.widgets.importBox.editBox.focused)
            t:assertEqual(w.spoken[#w.spoken], "Press Ctrl+V to paste the guide string, or Escape to cancel.")
        end)
    end,
    ["Paste says why it cannot while an import runs"] = function(t)
        withWorld(nil, function(w)
            w.rxp.workerFrame.shown = true
            go(t, w.importDriver, "Paste a guide string")
            w.importDriver.enter()
            t:assertEqual(w.spoken[#w.spoken], "An import is already running.")
        end)
    end,
    ["Import with nothing pasted says so"] = function(t)
        withWorld(nil, function(w)
            go(t, w.importDriver, "Import the pasted guides")
            w.importDriver.enter()
            t:assertEqual(w.spoken[#w.spoken], "Nothing has been pasted yet. Paste a guide string first.")
            t:assertEqual(w.importer.calls.validate, 0)
        end)
    end,
    ["Import after a paste starts the import, and RestedXP reports the rest"] = function(t)
        withWorld(nil, function(w)
            go(t, w.importDriver, "Paste a guide string")
            w.importDriver.enter()
            w.importer:paste("12|345:abc|678")
            local before = #w.spoken
            go(t, w.importDriver, "Import the pasted guides")
            w.importDriver.enter()
            t:assertEqual(w.importer.calls.validate, 1)
            t:assertEqual(#w.spoken, before)
            t:assertMatch(w.importDriver.dump()[1], "^Importing: ")
        end)
    end,
    ["a text RestedXP refuses is not said twice: RestedXP's report is the voice"] = function(t)
        withWorld({ import = { importError = "Failed integrity check" } }, function(w)
            w.importer:Open()
            w.importer:paste("garbage")
            local before = #w.spoken
            go(t, w.importDriver, "Import the pasted guides")
            w.importDriver.enter()
            t:assertEqual(#w.spoken, before)
            t:assertEqual(#w.errors, 0)
        end)
    end,
    ["a failure inside RestedXP is reported and spoken"] = function(t)
        withWorld({ import = { validateRaises = true } }, function(w)
            w.importer:Open()
            w.importer:paste("garbage")
            go(t, w.importDriver, "Import the pasted guides")
            w.importDriver.enter()
            t:assertEqual(w.spoken[#w.spoken], "That entry failed.")
            t:assertMatch(w.errors[1], "validation blew up")
        end)
    end,
    ["Battle.net out of reach is said, on the line and when importing"] = function(t)
        withWorld({ offline = true }, function(w)
            w.importer:paste("12|345:abc|678")
            t:assertMatch(w.importDriver.dump()[1], "cannot reach Battle%.net")
            go(t, w.importDriver, "Import the pasted guides")
            w.importDriver.enter()
            t:assertMatch(w.spoken[#w.spoken], "restart Battle%.net")
        end)
    end,
    ["the imported guides are a section that opens, each guide with its place and version"] = function(t)
        withWorld({ import = { guides = IMPORT_GUIDES } }, function(w)
            local d = w.importDriver
            t:assertNil(d.focus("Alt run"))
            go(t, d, "Imported guides")
            t:assertEqual(d.right().kind, "expanded")
            t:assertNotNil(d.focus("Alt run, in Mine/Alts"))
            t:assertNotNil(d.focus("01-10 Durotar, in RXP Leveling, version 7"))
        end)
    end,
    ["an empty section says so"] = function(t)
        withWorld(nil, function(w)
            local d = w.importDriver
            go(t, d, "Imported guides")
            d.right()
            t:assertNotNil(d.focus("No imported guides."))
        end)
    end,
    ["a guide asks before it is removed, and removing says so"] = function(t)
        withWorld({ import = { guides = IMPORT_GUIDES, saved = { ["Mine|Alts|Alt run|1"] = { key = "Mine|Alts|Alt run" } } } }, function(w)
            local d = w.importDriver
            go(t, d, "Imported guides")
            d.right()
            go(t, d, "Alt run")
            d.enter()
            t:assertEqual(#w.rxp.removed, 0)
            t:assertEqual(#w.g.pushed, 1)
            local confirm = w.g.driver(w.g.pushed[1].render)
            t:assertMatch(confirm.dump()[1], "Remove Alt run%?")
            confirm.focus("Yes")
            confirm.enter()
            t:assertEqual(w.rxp.removed[1], "Mine|Alts|Alt run")
            t:assertNil(w.rxp.db.profile.guides["Mine|Alts|Alt run|1"])
            t:assertEqual(w.spoken[#w.spoken], "The guide was removed.")
        end)
    end,
    ["saying no removes nothing"] = function(t)
        withWorld({ import = { guides = IMPORT_GUIDES } }, function(w)
            local d = w.importDriver
            go(t, d, "Imported guides")
            d.right()
            go(t, d, "Alt run")
            d.enter()
            local confirm = w.g.driver(w.g.pushed[1].render)
            confirm.focus("No")
            confirm.enter()
            t:assertEqual(#w.rxp.removed, 0)
        end)
    end,
    ["a guide that cannot be removed says so"] = function(t)
        withWorld({ import = { guides = IMPORT_GUIDES } }, function(w)
            w.rxp.RemoveGuide = function()
                return nil
            end
            local d = w.importDriver
            go(t, d, "Imported guides")
            d.right()
            go(t, d, "Alt run")
            d.enter()
            local confirm = w.g.driver(w.g.pushed[1].render)
            confirm.focus("Yes")
            confirm.enter()
            t:assertEqual(w.spoken[#w.spoken], "That guide could not be removed.")
        end)
    end,
    ["removing all asks first, saying what goes with them"] = function(t)
        withWorld({ import = { guides = IMPORT_GUIDES, saved = { a = {}, b = {} } } }, function(w)
            local d = w.importDriver
            go(t, d, "Remove all imported guides")
            d.enter()
            t:assertNotNil(next(w.rxp.db.profile.guides))
            local confirm = w.g.driver(w.g.pushed[1].render)
            t:assertMatch(confirm.dump()[1], "ALL imported guides")
            t:assertMatch(confirm.dump()[1], "skipped")
            confirm.focus("Yes")
            confirm.enter()
            t:assertNil(next(w.rxp.db.profile.guides))
            t:assertEqual(w.spoken[#w.spoken], "All imported guides were removed.")
        end)
    end,
    ["removing all, when it cannot be done, says so"] = function(t)
        withWorld({ import = { guides = IMPORT_GUIDES } }, function(w)
            w.rxp.db = nil
            go(t, w.importDriver, "Remove all imported guides")
            w.importDriver.enter()
            local confirm = w.g.driver(w.g.pushed[1].render)
            confirm.focus("Yes")
            confirm.enter()
            t:assertEqual(w.spoken[#w.spoken], "The guides could not be removed.")
        end)
    end,
    ["reloading asks first"] = function(t)
        withWorld(nil, function(w)
            go(t, w.importDriver, "Reload the interface")
            w.importDriver.enter()
            t:assertEqual(w.reloads, 0)
            local confirm = w.g.driver(w.g.pushed[1].render)
            t:assertMatch(confirm.dump()[1], "Reload the interface now%?")
            confirm.focus("Yes")
            confirm.enter()
            t:assertEqual(w.reloads, 1)
        end)
    end,
    ["without RestedXP, or without its importer, the screen says so"] = function(t)
        withWorld(nil, function(w)
            w.rxp.guideImporter = nil
            local lines = w.importDriver.dump()
            t:assertEqual(#lines, 1)
            t:assertMatch(lines[1], "RestedXP has no guide importer")
            w.ns.Game.rxp = function()
                return nil
            end
            lines = w.importDriver.dump()
            t:assertEqual(#lines, 1)
            t:assertMatch(lines[1], "RestedXP is not loaded")
        end)
    end,
    ["the screen opens from the menu entry, and replaces one that is open"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.openImport()
            w.ns.Screens.openImport()
            t:assertEqual(#w.opened, 2)
            t:assertEqual(w.closed[1], "restedxp-import")
            t:assertEqual(w.opened[2], "restedxp-import")
        end)
    end,
    ["in combat, without RestedXP or without its importer, it says so instead of opening"] = function(t)
        withWorld(nil, function(w)
            w.combat = true
            w.ns.Screens.openImport()
            t:assertEqual(w.spoken[#w.spoken], "Not available in combat.")
            w.combat = false
            w.rxp.guideImporter = nil
            w.ns.Screens.openImport()
            t:assertEqual(w.spoken[#w.spoken], "RestedXP has no guide importer.")
            w.ns.Game.rxp = function()
                return nil
            end
            w.ns.Screens.openImport()
            t:assertEqual(w.spoken[#w.spoken], "RestedXP is not loaded.")
            t:assertEqual(#w.opened, 0)
        end)
    end,
    ["when WowVision has no window, it says so"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.open = function()
                return false
            end
            w.ns.Screens.openImport()
            t:assertEqual(w.spoken[#w.spoken], "WowVision's windows are not available.")
        end)
    end,
    ["Escape closes the screen and puts RestedXP's window away"] = function(t)
        withWorld(nil, function(w)
            go(t, w.importDriver, "Paste a guide string")
            w.importDriver.enter()
            t:assertTrue(w.importer.widgets.import.shown)
            w.ns.Screens.openImport()
            w.windows["restedxp-import"].onRequestClose()
            t:assertEqual(w.closed[#w.closed], "restedxp-import")
            t:assertFalse(w.importer.widgets.import.shown)
        end)
    end,
    ["closing without RestedXP just closes"] = function(t)
        withWorld(nil, function(w)
            w.ns.Game.rxp = function()
                return nil
            end
            w.ns.Screens.closeImport()
            t:assertEqual(w.closed[#w.closed], "restedxp-import")
        end)
    end,
    ["the screen is timed"] = function(t)
        withWorld(nil, function(w)
            w.ns.Screens.openImport()
            local d = w.g.driver(w.windows["restedxp-import"].render)
            d.nodes()
            local found = false
            for _, row in ipairs(w.ns.Perf.rows()) do
                if row.name == "import screen" then
                    found = true
                end
            end
            t:assertTrue(found)
        end)
    end,
})

runner:addSuite("Screens: helpers", {
    ["hex colours"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Source", "Options", "Menu", "Guidance", "Game" })
        -- Screens needs WowVision's graph only when rendering; loading it is enough for the pure helpers
        graphEnv(WOWVISION)
        ns = loadAddon(FILES)
        t:assertEqual(ns.Screens.hexOf(1, 0.5, 0), "#FF8000")
        t:assertNil(ns.Screens.hexOf(nil, 0, 0))
        local r, g, b = ns.Screens.parseHex("#00ff80")
        t:assertEqual(r, 0)
        t:assertEqual(g, 1)
        t:assertTrue(math.abs(b - 128 / 255) < 1e-9)
        t:assertNil(ns.Screens.parseHex("12345"))
        t:assertNil(ns.Screens.parseHex("GGGGGG"))
        t:assertNotNil(ns.Screens.parseHex(" ABCDEF "))
    end,
})

end
