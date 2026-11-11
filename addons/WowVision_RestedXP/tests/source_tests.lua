return function(runner, env)
local loadAddon = env.loadAddon
local fakeRxp = env.fake.rxp
local fakeHbd = env.fake.hbd

runner:addSuite("Source: the steps", {
    ["the active steps read their lines in the window's text"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = {
                { lines = { { text = "|cffffd100Accept|r |cRXP_FRIENDLY_Ailee::123|r" }, { text = "Go to the hut", done = true } } },
            },
            active = { 1 },
        })
        local steps = ns.Source.activeSteps(rxp)
        t:assertEqual(#steps, 1)
        t:assertEqual(steps[1].title, "Step 1")
        t:assertEqual(steps[1].lines[1].text, "Accept Ailee")
        t:assertFalse(steps[1].lines[1].done)
        t:assertTrue(steps[1].lines[2].done)
    end,
    ["the text goes through RestedXP's translation first"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = { { lines = { { text = "Kill wolves" } } } },
            active = { 1 },
            translate = { ["Kill wolves"] = "Tuez des loups" },
        })
        t:assertEqual(ns.Source.activeSteps(rxp)[1].lines[1].text, "Tuez des loups")
    end,
    ["a step the guide hides is not shown"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = {
                { hidewindow = true, lines = { { text = "secret" } } },
                { hidetip = true, lines = { { text = "hidden tip" } } },
                { lines = { { text = "shown" } } },
            },
            active = { 1, 2, 3 },
        })
        local steps = ns.Source.activeSteps(rxp)
        t:assertEqual(#steps, 1)
        t:assertEqual(steps[1].lines[1].text, "shown")
    end,
    ["a step with nothing to read is not shown"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = {
                { lines = { { noText = true }, { text = " " }, { text = "|cff00ff00|r" } } },
                { lines = { { text = "real" } } },
            },
            active = { 1, 2 },
        })
        local steps = ns.Source.activeSteps(rxp)
        t:assertEqual(#steps, 1)
        t:assertEqual(steps[1].index, 2)
    end,
    ["titles: the step's own, a sticky step's empty one, a tip's"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = {
                { title = "|cffffd100Durotar|r", lines = { { text = "a" } } },
                { sticky = true, lines = { { text = "b" } } },
                { tip = true, lines = { { text = "c" } } },
                { tip = true, title = "Advice", lines = { { text = "d" } } },
                { lines = { { text = "e" } } },
            },
            active = { 1, 2, 3, 4, 5 },
        })
        local steps = ns.Source.activeSteps(rxp)
        t:assertEqual(steps[1].title, "Durotar")
        t:assertNil(steps[2].title)
        t:assertEqual(steps[3].title, "Tip")
        t:assertTrue(steps[3].tip)
        t:assertEqual(steps[4].title, "Advice")
        t:assertEqual(steps[5].title, "Step 5")
    end,
    ["a text-only line informs and is never done"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = { { lines = { { text = "Careful here", textOnly = true, done = true } } } },
            active = { 1 },
        })
        local line = ns.Source.activeSteps(rxp)[1].lines[1]
        t:assertTrue(line.info)
        t:assertFalse(line.done)
    end,
    ["skip counts as done"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "x", skip = true } } } }, active = { 1 } })
        t:assertTrue(ns.Source.activeSteps(rxp)[1].lines[1].done)
    end,
    ["without the window's list nothing is active"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({})
        rxp.RXPFrame.activeSteps = nil
        t:assertEqual(#ns.Source.activeSteps(rxp), 0)
        rxp.RXPFrame = nil
        t:assertEqual(#ns.Source.activeSteps(rxp), 0)
    end,
    ["a step is read with its title and lines"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = { { lines = { { text = "Accept A" }, { text = "Go to B", done = true } } } },
            active = { 1 },
        })
        t:assertEqual(ns.Source.activeSpeech(rxp), "Step 1. Accept A. Go to B, done")
    end,
    ["two active steps are read one after the other"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = { { sticky = true, title = "Always", lines = { { text = "Sell junk" } } }, { lines = { { text = "Talk" } } } },
            active = { 1, 2 },
        })
        t:assertEqual(ns.Source.activeSpeech(rxp), "Always. Sell junk. Step 2. Talk")
    end,
})

runner:addSuite("Source: reading a line only now and then", {
    -- RestedXP resolves the creature names of a line through the game's tooltip; a screen rebuilt every frame
    -- must not ask again each time.
    ["a line read twice within two seconds is worked out once"] = function(t)
        local ns = loadAddon()
        local now = 100
        local saved = rawget(_G, "GetTime")
        rawset(_G, "GetTime", function() return now end)
        local ok, err = pcall(function()
            local rxp = fakeRxp({ steps = { { lines = { { text = "Kill wolves" } } } }, active = { 1 } })
            local asked = 0
            local original = rxp.ReplaceNpcIds
            rxp.ReplaceNpcIds = function(text)
                asked = asked + 1
                return original(text)
            end
            local element = rxp.currentGuide.steps[1].elements[1]
            t:assertEqual(ns.Source.elementText(rxp, element), "Kill wolves")
            now = 101.9
            t:assertEqual(ns.Source.elementText(rxp, element), "Kill wolves")
            t:assertEqual(asked, 1)
            now = 102.1
            ns.Source.elementText(rxp, element)
            t:assertEqual(asked, 2)
        end)
        rawset(_G, "GetTime", saved)
        if not ok then
            error(err, 0)
        end
    end,
    ["a line whose text changed is read again at once"] = function(t)
        local ns = loadAddon()
        local saved = rawget(_G, "GetTime")
        rawset(_G, "GetTime", function() return 100 end)
        local ok, err = pcall(function()
            local rxp = fakeRxp({ steps = { { lines = { { text = "Kill wolves (0/8)" } } } }, active = { 1 } })
            local element = rxp.currentGuide.steps[1].elements[1]
            t:assertEqual(ns.Source.elementText(rxp, element), "Kill wolves (0/8)")
            element.text = "Kill wolves (3/8)"
            t:assertEqual(ns.Source.elementText(rxp, element), "Kill wolves (3/8)")
        end)
        rawset(_G, "GetTime", saved)
        if not ok then
            error(err, 0)
        end
    end,
    ["a line with nothing to say is remembered as nothing"] = function(t)
        local ns = loadAddon()
        local saved = rawget(_G, "GetTime")
        rawset(_G, "GetTime", function() return 100 end)
        local ok, err = pcall(function()
            local rxp = fakeRxp({ steps = { { lines = { { text = "|cff00ff00|r" } } } }, active = { 1 } })
            local element = rxp.currentGuide.steps[1].elements[1]
            t:assertNil(ns.Source.elementText(rxp, element))
            t:assertNil(ns.Source.elementText(rxp, element))
        end)
        rawset(_G, "GetTime", saved)
        if not ok then
            error(err, 0)
        end
    end,
    ["without the game's clock a line is worked out every time"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "Kill wolves" } } } }, active = { 1 } })
        local asked = 0
        local original = rxp.ReplaceNpcIds
        rxp.ReplaceNpcIds = function(text)
            asked = asked + 1
            return original(text)
        end
        local element = rxp.currentGuide.steps[1].elements[1]
        ns.Source.elementText(rxp, element)
        ns.Source.elementText(rxp, element)
        t:assertEqual(asked, 2)
    end,
})

runner:addSuite("Source: the guide", {
    ["the guide's name, step and length"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "a" } } }, { lines = { { text = "b" } } } }, current = 2, subgroup = "Speedrun" })
        local info = ns.Source.guide(rxp)
        t:assertEqual(info.name, "1-12 Durotar")
        t:assertEqual(info.subgroup, "Speedrun")
        t:assertEqual(info.steps, 2)
        t:assertEqual(info.step, 2)
    end,
    ["a guide title wins over its name"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "a" } } } }, guideTitle = "Special" })
        t:assertEqual(ns.Source.guide(rxp).name, "Special")
    end,
    ["no guide, or the empty placeholder, gives nil"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "a" } } } }, empty = true })
        t:assertNil(ns.Source.guide(rxp))
        t:assertFalse(ns.Source.hasGuide(rxp))
        rxp.currentGuide = nil
        t:assertNil(ns.Source.guide(rxp))
        rxp.currentGuide = { steps = {} }
        t:assertNil(ns.Source.guide(rxp))
    end,
    ["a failing progress call leaves step 1"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "a" } } } } })
        rxp.GetGuideProgress = function()
            error("boom")
        end
        t:assertEqual(ns.Source.guide(rxp).step, 1)
    end,
    ["upcoming steps skip hidden, optional, tips and levels not reached"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = {
                { lines = { { text = "now" } } },
                { hidewindow = true, lines = { { text = "hidden" } } },
                { optional = true, lines = { { text = "optional" } } },
                { tip = true, lines = { { text = "tip" } } },
                { level = 20, lines = { { text = "too high" } } },
                { lines = { { text = "next one" } } },
                { lines = { { text = "after" } } },
                { lines = { { text = "far" } } },
            },
            current = 1,
        })
        local list = ns.Source.upcoming(rxp, 2, 12)
        t:assertEqual(#list, 2)
        t:assertEqual(list[1].index, 6)
        t:assertEqual(list[1].lines[1].text, "next one")
        t:assertEqual(list[2].index, 7)
    end,
    ["upcoming steps stop at the end of the guide"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "a" } } }, { lines = { { text = "b" } } } }, current = 2 })
        t:assertEqual(#ns.Source.upcoming(rxp, 5, 12), 0)
    end,
    ["go to a step clamps to the guide"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "a" } } }, { lines = { { text = "b" } } }, { lines = { { text = "c" } } } } })
        t:assertEqual(ns.Source.goToStep(rxp, 2), 2)
        t:assertEqual(ns.Source.goToStep(rxp, 0), 1)
        t:assertEqual(ns.Source.goToStep(rxp, 99), 3)
        t:assertEqual(ns.Source.goToStep(rxp, 2.7), 2)
        t:assertEqual(table.concat(rxp.calls.setStep, ","), "2,1,3,2")
    end,
    ["go to a step needs a guide"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "a" } } } }, empty = true })
        t:assertNil(ns.Source.goToStep(rxp, 1))
        t:assertEqual(#rxp.calls.setStep, 0)
    end,
})

runner:addSuite("Source: acting on lines", {
    ["ticking a box goes through RestedXP's own handler"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "Do it" } } } }, active = { 1 } })
        local line = ns.Source.activeSteps(rxp)[1].lines[1]
        t:assertTrue(ns.Source.setLine(rxp, line, true))
        t:assertTrue(line.element.skip)
        t:assertTrue(line.button.checked)
        t:assertEqual(rxp.calls.postClick, 1)
        t:assertTrue(rxp.updateSteps)
        t:assertEqual(rxp.calls.updateMap, 1)
    end,
    ["unticking works the same way"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "Do it", skip = true } } } }, active = { 1 } })
        local line = ns.Source.activeSteps(rxp)[1].lines[1]
        t:assertTrue(ns.Source.setLine(rxp, line, false))
        t:assertFalse(line.element.skip)
        t:assertFalse(line.button.checked)
    end,
    ["a line already in the wanted state is left alone"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "Do it", skip = true } } } }, active = { 1 } })
        local line = ns.Source.activeSteps(rxp)[1].lines[1]
        t:assertTrue(ns.Source.setLine(rxp, line, true))
        t:assertEqual(rxp.calls.postClick, 0)
    end,
    ["a box RestedXP greyed out cannot be changed"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "Done by itself", done = true } } } }, active = { 1 } })
        local line = ns.Source.activeSteps(rxp)[1].lines[1]
        line.button.enabled = false
        t:assertFalse(ns.Source.setLine(rxp, line, false))
        t:assertTrue(line.button.checked)
        t:assertEqual(rxp.calls.postClick, 0)
    end,
    ["an optional or informative line is never changed"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = { { lines = { { text = "Optional", optional = true }, { text = "Info", textOnly = true } } } },
            active = { 1 },
        })
        local lines = ns.Source.activeSteps(rxp)[1].lines
        t:assertFalse(ns.Source.setLine(rxp, lines[1], true))
        t:assertFalse(ns.Source.setLine(rxp, lines[2], true))
        t:assertEqual(rxp.calls.postClick, 0)
    end,
    ["a line the window does not show is completed through RestedXP"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "Hidden window", noFrame = true } } } }, active = { 1 } })
        local line = ns.Source.activeSteps(rxp)[1].lines[1]
        t:assertTrue(ns.Source.setLine(rxp, line, true))
        t:assertEqual(rxp.calls.setComplete, 1)
        t:assertTrue(line.element.skip)
    end,
    ["a line the window does not show can be unticked"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({ steps = { { lines = { { text = "Hidden window", skip = true, noFrame = true } } } }, active = { 1 } })
        local line = ns.Source.activeSteps(rxp)[1].lines[1]
        t:assertTrue(ns.Source.setLine(rxp, line, false))
        t:assertFalse(line.element.skip)
        t:assertTrue(rxp.updateSteps)
    end,
    ["skipping ticks what is not ticked, tips excepted"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({
            steps = {
                { lines = { { text = "one" }, { text = "two", skip = true }, { text = "three" }, { text = "info", textOnly = true } } },
                { tip = true, lines = { { text = "advice" } } },
            },
            active = { 1, 2 },
        })
        t:assertEqual(ns.Source.skipActive(rxp), 2)
        local steps = ns.Source.activeSteps(rxp)
        t:assertTrue(steps[1].lines[1].done)
        t:assertTrue(steps[1].lines[3].done)
        t:assertFalse(steps[2].lines[1].done)
    end,
})

runner:addSuite("Source: the arrow", {
    ["no destination"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({})
        t:assertTrue(ns.Source.arrow(rxp, nil, nil).none)
        rxp.arrowFrame.element = { x = 1 }
        t:assertTrue(ns.Source.arrow(rxp, nil, nil).none)
        -- a destination needs both of its coordinates
        rxp.arrowFrame.element = { wx = 1 }
        t:assertTrue(ns.Source.arrow(rxp, nil, nil).none)
        rxp.arrowFrame.element = { wy = 1 }
        t:assertTrue(ns.Source.arrow(rxp, nil, nil).none)
        rxp.arrowFrame = nil
        t:assertTrue(ns.Source.arrow(rxp, nil, nil).none)
    end,
    ["the destination with distance and direction"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({})
        rxp.arrowFrame.element = { wx = 10, wy = 20, title = "|cffffd100Talk to Ailee|r", instance = 1 }
        local info = ns.Source.arrow(rxp, fakeHbd({ 0, 0 }, 3 * math.pi / 2, 35), 0)
        t:assertEqual(info.title, "Talk to Ailee")
        t:assertEqual(info.distance, 35)
        t:assertTrue(math.abs(info.degrees - 90) < 1e-9)
        t:assertEqual(info.wx, 10)
        t:assertEqual(info.wy, 20)
        t:assertFalse(info.otherContinent)
    end,
    ["the title falls back to the step's arrow text, its title, then its number"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({})
        local hbd = fakeHbd({ 0, 0 }, 0, 5)
        rxp.arrowFrame.element = { wx = 1, wy = 1, step = { index = 4, arrowtext = "Hut", title = "Title" } }
        t:assertEqual(ns.Source.arrow(rxp, hbd, 0).title, "Hut")
        rxp.arrowFrame.element = { wx = 1, wy = 1, step = { index = 4, title = "Title" } }
        t:assertEqual(ns.Source.arrow(rxp, hbd, 0).title, "Title")
        rxp.arrowFrame.element = { wx = 1, wy = 1, step = { index = 4 } }
        t:assertEqual(ns.Source.arrow(rxp, hbd, 0).title, "Step 4")
        rxp.arrowFrame.element = { wx = 1, wy = 1 }
        t:assertNil(ns.Source.arrow(rxp, hbd, 0).title)
    end,
    ["another continent gives no distance"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({})
        rxp.arrowFrame.element = { wx = 1, wy = 1, title = "Boat" }
        rxp.arrowFrame.wrongContinent = true
        local info = ns.Source.arrow(rxp, fakeHbd({ 0, 0 }, 0, 5), 0)
        t:assertTrue(info.otherContinent)
        t:assertNil(info.distance)
        t:assertNil(info.degrees)
    end,
    ["without the player's position there is a destination but no distance"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({})
        rxp.arrowFrame.element = { wx = 1, wy = 1, title = "Hut" }
        local info = ns.Source.arrow(rxp, fakeHbd(nil, nil, nil), 0)
        t:assertEqual(info.title, "Hut")
        t:assertNil(info.distance)
        t:assertNil(info.degrees)
    end,
    ["without the facing there is a distance but no direction"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({})
        rxp.arrowFrame.element = { wx = 1, wy = 1, title = "Hut" }
        local info = ns.Source.arrow(rxp, fakeHbd({ 0, 0 }, 1, 12), nil)
        t:assertEqual(info.distance, 12)
        t:assertNil(info.degrees)
    end,
    ["without HereBeDragons only the title"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({})
        rxp.arrowFrame.element = { wx = 1, wy = 1, title = "Hut" }
        local info = ns.Source.arrow(rxp, nil, 0)
        t:assertEqual(info.title, "Hut")
        t:assertNil(info.distance)
    end,
})

local function shown(value)
    return function()
        return value
    end
end

-- Runs fn with some globals set, and always puts them back.
local function withGlobals(values, fn)
    local saved = {}
    for key in pairs(values) do
        saved[key] = rawget(_G, key)
    end
    for key, value in pairs(values) do
        rawset(_G, key, value)
    end
    local ok, err = pcall(fn)
    for key, value in pairs(saved) do
        rawset(_G, key, value)
    end
    for key in pairs(values) do
        if saved[key] == nil then
            rawset(_G, key, nil)
        end
    end
    if not ok then
        error(err, 0)
    end
end

runner:addSuite("Source: menus and buttons", {
    ["the menu is rebuilt, without self, and read from RestedXP"] = function(t)
        local ns = loadAddon()
        local list = { { text = "Guides" } }
        local rxp = fakeRxp({ menuList = list })
        t:assertEqual(ns.Source.menu(rxp), list)
        t:assertEqual(rxp.calls.menu, 1)
        t:assertEqual(rxp.calls.menuArgs, 0)
    end,
    ["a failing rebuild still gives the last menu"] = function(t)
        local ns = loadAddon()
        local list = { { text = "Old" } }
        local rxp = fakeRxp({})
        rxp.RXPFrame.menuList = list
        rxp.RXPFrame.GenerateMenuTable = function()
            error("boom")
        end
        t:assertEqual(ns.Source.menu(rxp), list)
    end,
    ["no window, no menu"] = function(t)
        local ns = loadAddon()
        local rxp = fakeRxp({})
        rxp.RXPFrame = nil
        t:assertNil(ns.Source.menu(rxp))
    end,
    ["the active items are the shown buttons, named by what they use"] = function(t)
        local ns = loadAddon()
        withGlobals({
            RXPItemFrameButton1 = { IsShown = shown(true), name = "|cff1eff00Linen Bandage|r" },
            RXPItemFrameButton2 = { IsShown = shown(false), name = "hidden" },
            RXPItemFrameButton3 = { IsShown = shown(true), itemId = 5 },
        }, function()
            local items = ns.Source.activeItems()
            t:assertEqual(#items, 2)
            t:assertEqual(items[1].label, "Linen Bandage")
            t:assertEqual(items[1].frame, _G.RXPItemFrameButton1)
            t:assertEqual(items[2].label, "Item 3")
        end)
    end,
    ["an item with an id is named by the game"] = function(t)
        local ns = loadAddon()
        withGlobals({
            RXPItemFrameButton1 = { IsShown = shown(true), itemId = 5 },
            GetItemInfo = function(id)
                return id == 5 and "Wolf Meat" or nil
            end,
        }, function()
            t:assertEqual(ns.Source.activeItems()[1].label, "Wolf Meat")
        end)
    end,
    ["the active targets are named by their creature"] = function(t)
        local ns = loadAddon()
        withGlobals({
            RXPTargetFrame_EnemyButton1 = { IsShown = shown(true), targetData = { name = "Kobold Vermin", kind = "mob" } },
            RXPTargetFrame_EnemyButton2 = { IsShown = shown(true) },
            RXPTargetFrame_FriendlyButton1 = { IsShown = shown(true), targetData = { name = "Ailee" } },
        }, function()
            local enemies = ns.Source.activeTargets("Enemy")
            t:assertEqual(#enemies, 2)
            t:assertEqual(enemies[1].label, "Kobold Vermin")
            t:assertEqual(enemies[2].label, "Target 2")
            t:assertEqual(ns.Source.activeTargets("Friendly")[1].label, "Ailee")
        end)
    end,
    ["no buttons, no entries"] = function(t)
        local ns = loadAddon()
        t:assertEqual(#ns.Source.activeItems(), 0)
        t:assertEqual(#ns.Source.activeTargets("Enemy"), 0)
    end,
    ["the RestedXP table is found as the global RXP"] = function(t)
        local ns = loadAddon()
        t:assertNil(ns.Source.rxp())
        local found = { RXPFrame = {} }
        withGlobals({ RXP = found }, function()
            t:assertEqual(ns.Source.rxp(), found)
        end)
    end,
    ["the RestedXP table is found through AceAddon otherwise"] = function(t)
        local ns = loadAddon()
        local found = { RXPFrame = {} }
        withGlobals({
            LibStub = function(name)
                return {
                    GetAddon = function(_, addonName)
                        if name == "AceAddon-3.0" and addonName == "RXPGuides" then
                            return found
                        end
                    end,
                }
            end,
        }, function()
            t:assertEqual(ns.Source.rxp(), found)
        end)
    end,
    ["a global RXP that is not RestedXP's table is ignored"] = function(t)
        local ns = loadAddon()
        withGlobals({ RXP = { something = true } }, function()
            t:assertNil(ns.Source.rxp())
        end)
    end,
})

end
