return function(runner, env)
local loadAddon = env.loadAddon

local FILES = { "Locale", "Text", "Menu" }

-- A list in the shape RestedXP's GenerateMenuTable gives.
local function guideList(calls)
    local function onClick(self, ...)
        tinsert(calls, { "load", ... })
    end
    return {
        { text = "Available Guides", isTitle = 1, notCheckable = 1 },
        {
            text = "RestedXP Guide Forever (H)",
            notCheckable = 1,
            hasArrow = true,
            menuList = {
                { text = "|cffffd1001-6 Durotar|r", notCheckable = 1, func = onClick, arg1 = "Forever (H)", arg2 = "01-06 Durotar" },
                {
                    text = "Speedrun",
                    notCheckable = 1,
                    hasArrow = true,
                    menuList = {
                        { text = "6-10 Durotar", notCheckable = 1, func = onClick, arg1 = "Forever (H)", arg2 = "06-10 Durotar" },
                        { text = "Disabled guide", notCheckable = 1, isTitle = 1 },
                    },
                },
            },
        },
        { text = "", notCheckable = 1, isTitle = 1 },
        {
            text = "Display Tips",
            func = function(self, arg1)
                tinsert(calls, { "tips", arg1 })
            end,
            arg1 = "toggle",
            checked = function()
                return calls.tipsShown
            end,
        },
        { text = "Options...", notCheckable = 1, func = function() tinsert(calls, { "options" }) end },
        { text = "Greyed", notCheckable = 1, func = function() tinsert(calls, { "greyed" }) end, disabled = 1 },
        { text = "Nothing", notCheckable = 1 },
        { text = "Close", notCheckable = 1, func = function(self) self:Hide() end },
    }
end

runner:addSuite("Menu: reading", {
    ["items keep the kinds of the game's menus"] = function(t)
        local ns = loadAddon(FILES)
        local items = ns.Menu.items(guideList({}))
        t:assertEqual(items[1].kind, "title")
        t:assertEqual(items[1].text, "Available Guides")
        t:assertEqual(items[2].kind, "submenu")
        t:assertEqual(items[3].kind, "toggle")
        t:assertEqual(items[4].kind, "button")
    end,
    ["a separator is left out"] = function(t)
        local ns = loadAddon(FILES)
        local items = ns.Menu.items(guideList({}))
        for _, item in ipairs(items) do
            t:assertTrue(item.text ~= "")
        end
        t:assertEqual(#items, 7)
    end,
    ["a submenu builds its children when asked, to any depth"] = function(t)
        local ns = loadAddon(FILES)
        local items = ns.Menu.items(guideList({}))
        local guides = items[2].children()
        t:assertEqual(#guides, 2)
        t:assertEqual(guides[1].text, "1-6 Durotar")
        t:assertEqual(guides[2].kind, "submenu")
        local speedrun = guides[2].children()
        t:assertEqual(speedrun[1].text, "6-10 Durotar")
        t:assertEqual(speedrun[2].kind, "title")
    end,
    ["a box reads its state live"] = function(t)
        local ns = loadAddon(FILES)
        local calls = {}
        local toggle = ns.Menu.items(guideList(calls))[3]
        t:assertFalse(toggle.checked())
        calls.tipsShown = true
        t:assertTrue(toggle.checked())
    end,
    ["a plain checked value counts, and a failing function is not checked"] = function(t)
        local ns = loadAddon(FILES)
        local items = ns.Menu.items({
            { text = "A", checked = true, func = function() end },
            { text = "B", checked = function() error("boom") end, func = function() end },
            { text = "C", func = function() end },
        })
        t:assertTrue(items[1].checked())
        t:assertFalse(items[2].checked())
        t:assertFalse(items[3].checked())
    end,
    ["disabled and titles"] = function(t)
        local ns = loadAddon(FILES)
        local items = ns.Menu.items(guideList({}))
        t:assertEqual(items[5].text, "Greyed")
        t:assertTrue(items[5].disabled)
        t:assertFalse(items[4].disabled)
    end,
    ["a nil or malformed list gives nothing"] = function(t)
        local ns = loadAddon(FILES)
        t:assertEqual(#ns.Menu.items(nil), 0)
        t:assertEqual(#ns.Menu.items("no"), 0)
        t:assertEqual(#ns.Menu.items({ "bad", 3, { text = "ok", notCheckable = 1 } }), 1)
    end,
})

runner:addSuite("Menu: running an item", {
    ["a guide item calls func with its two arguments"] = function(t)
        local ns = loadAddon(FILES)
        local calls = {}
        local guide = ns.Menu.items(guideList(calls))[2].children()[1]
        t:assertTrue(ns.Menu.canActivate(guide))
        t:assertTrue(ns.Menu.activate(guide))
        t:assertEqual(calls[1][1], "load")
        t:assertEqual(calls[1][2], "Forever (H)")
        t:assertEqual(calls[1][3], "01-06 Durotar")
    end,
    ["a box gets its state as the fourth argument"] = function(t)
        local ns = loadAddon(FILES)
        local calls = {}
        local seen
        local items = ns.Menu.items({
            { text = "Box", checked = function() return true end, func = function(self, a, b, checked) seen = checked end },
        })
        ns.Menu.activate(items[1])
        t:assertEqual(seen, true)
    end,
    ["a submenu, a title, a greyed item and an item with no func do nothing"] = function(t)
        local ns = loadAddon(FILES)
        local calls = {}
        local items = ns.Menu.items(guideList(calls))
        t:assertEqual(items[5].text, "Greyed")
        t:assertEqual(items[6].text, "Nothing")
        t:assertFalse(ns.Menu.canActivate(items[1]))
        t:assertFalse(ns.Menu.canActivate(items[2]))
        t:assertFalse(ns.Menu.canActivate(items[5]))
        t:assertFalse(ns.Menu.canActivate(items[6]))
        t:assertFalse(ns.Menu.activate(items[5]))
        t:assertEqual(#calls, 0)
    end,
    ["a notClickable item does nothing"] = function(t)
        local ns = loadAddon(FILES)
        local items = ns.Menu.items({ { text = "A", notCheckable = 1, notClickable = 1, func = function() end } })
        t:assertFalse(ns.Menu.canActivate(items[1]))
    end,
    ["the Close item's self:Hide() works on the stand-in button"] = function(t)
        local ns = loadAddon(FILES)
        local items = ns.Menu.items(guideList({}))
        t:assertTrue(ns.Menu.activate(items[7]))
    end,
    ["a failing func is reported, not thrown"] = function(t)
        local ns = loadAddon(FILES)
        local items = ns.Menu.items({ { text = "Bad", notCheckable = 1, func = function() error("boom") end } })
        local ok, err = ns.Menu.activate(items[1])
        t:assertFalse(ok)
        t:assertMatch(err, "boom")
    end,
    ["keepShownOnClick keeps the menu open"] = function(t)
        local ns = loadAddon(FILES)
        local items = ns.Menu.items({
            { text = "Keep", keepShownOnClick = 1, func = function() end },
            { text = "Close after", func = function() end },
        })
        t:assertTrue(ns.Menu.keepsOpen(items[1]))
        t:assertFalse(ns.Menu.keepsOpen(items[2]))
    end,
})

end
