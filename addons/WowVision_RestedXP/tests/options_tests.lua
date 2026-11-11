return function(runner, env)
local loadAddon = env.loadAddon

-- A small options table in the shape RestedXP's has: root get/set reading the profile by the option's key,
-- tab groups, toggles, ranges, selects, executes with confirm, hidden/disabled functions.
local function newWorld()
    local world = {
        profile = { showEnabled = true, lockFrames = false, arrowScale = 1, theme = "blue", comms = true },
        calls = {},
    }
    local function get(info)
        return world.profile[info[#info]]
    end
    local function set(info, value)
        tinsert(world.calls, { "set", info[#info], value })
        world.profile[info[#info]] = value
    end
    world.options = {
        type = "group",
        name = "RestedXP Guides - v4",
        get = get,
        set = set,
        childGroups = "tab",
        args = {
            discord = { order = 1.0, name = "Join Discord", type = "execute", func = function(info)
                tinsert(world.calls, { "func", info[#info] })
            end },
            reset = {
                order = 1.3,
                name = "Reset Guide Progress",
                desc = "Clear guide progress",
                type = "execute",
                func = function(info)
                    tinsert(world.calls, { "func", info[#info] })
                end,
                confirm = function()
                    return "Clear guide progress for current character"
                end,
            },
            hiddenButton = { order = 1.4, name = "Never", type = "execute", hidden = true, func = function() end },
            general = {
                type = "group",
                name = "General",
                order = 2,
                args = {
                    showEnabled = { name = "Show all frames", desc = "Toggles all frames", type = "toggle", order = 1.1 },
                    lockFrames = { name = "|cffffd100Lock|r Frames", type = "toggle", order = 1.2 },
                    standby = { name = "Standby", type = "toggle", order = 1.3, hidden = function() return not world.advanced end },
                    header = { name = "Features", type = "header", order = 2 },
                    note = { name = "A long note\nover two lines", type = "description", order = 2.1 },
                    locked = { name = "Locked option", type = "toggle", order = 2.2, disabled = function() return world.profile.lockFrames end },
                    comms = { name = "Comms", type = "toggle", order = 2.3, guiHidden = true },
                    arrowScale = { name = "Arrow scale", type = "range", min = 0.5, max = 2, step = 0.1, order = 3 },
                    percent = { name = "Opacity", type = "range", min = 0, max = 1, step = 0.05, isPercent = true, order = 3.1 },
                    softOnly = { name = "Soft", type = "range", softMin = 1, softMax = 9, order = 3.2 },
                    theme = {
                        name = "Theme",
                        type = "select",
                        order = 4,
                        values = function()
                            return { blue = "RXP Blue", dark = "Dark", custom = "|cffff0000Custom|r" }
                        end,
                    },
                    sorted = {
                        name = "Sorted list",
                        type = "select",
                        order = 4.1,
                        values = { a = "Alpha", b = "Beta", c = "Gamma" },
                        sorting = { "c", "a", "b" },
                    },
                    numbers = { name = "Numbers", type = "select", order = 4.2, values = { [10] = "ten", [2] = "two", [5] = "five" } },
                },
            },
            -- orders: negative ones go last, equal ones by name
            zlast = { order = -1, name = "Last", type = "toggle" },
            beta = { order = 5, name = "beta", type = "toggle" },
            alpha = { order = 5, name = "Alpha", type = "toggle" },
        },
    }
    return world
end

runner:addSuite("Options: reading", {
    ["the entries come in AceConfig's order, without the hidden ones"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        local ctx = ns.Options.context(world.options, "RXP")
        local keys = {}
        for _, entry in ipairs(ns.Options.entries(ctx, {})) do
            tinsert(keys, entry.key)
        end
        t:assertEqual(table.concat(keys, ","), "discord,reset,general,alpha,beta,zlast")
    end,
    ["a hidden function is evaluated now"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        local ctx = ns.Options.context(world.options, "RXP")
        local function count()
            return #ns.Options.entries(ctx, { "general" })
        end
        local before = count()
        world.advanced = true
        t:assertEqual(count(), before + 1)
    end,
    ["guiHidden hides an option"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        local ctx = ns.Options.context(world.options, "RXP")
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            t:assertTrue(entry.key ~= "comms", "comms is guiHidden")
        end
    end,
    ["labels are plain text; descriptions too"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        local ctx = ns.Options.context(world.options, "RXP")
        local entries = ns.Options.entries(ctx, { "general" })
        local byKey = {}
        for _, entry in ipairs(entries) do
            byKey[entry.key] = entry
        end
        t:assertEqual(byKey.lockFrames.label(), "Lock Frames")
        t:assertEqual(byKey.showEnabled.description(), "Toggles all frames")
        t:assertNil(byKey.lockFrames.description())
        t:assertEqual(byKey.note.label(), "A long note over two lines")
        t:assertEqual(byKey.note.type, "description")
        t:assertEqual(byKey.header.type, "header")
    end,
    ["values come from the inherited get"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        local ctx = ns.Options.context(world.options, "RXP")
        local byKey = {}
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            byKey[entry.key] = entry
        end
        t:assertEqual(byKey.showEnabled.get(), true)
        t:assertEqual(byKey.arrowScale.get(), 1)
        world.profile.arrowScale = 1.5
        t:assertEqual(byKey.arrowScale.get(), 1.5)
    end,
    ["disabled is evaluated now"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        local ctx = ns.Options.context(world.options, "RXP")
        local byKey = {}
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            byKey[entry.key] = entry
        end
        t:assertFalse(byKey.locked.disabled())
        world.profile.lockFrames = true
        t:assertTrue(byKey.locked.disabled())
        t:assertFalse(byKey.showEnabled.disabled())
    end,
    ["a failing option function does not break the reading"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        world.options.args.general.args.showEnabled.get = function()
            error("boom")
        end
        world.options.args.general.args.lockFrames.name = function()
            error("boom")
        end
        world.options.args.general.args.locked.disabled = function()
            error("boom")
        end
        local ctx = ns.Options.context(world.options, "RXP")
        local byKey = {}
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            byKey[entry.key] = entry
        end
        t:assertNil(byKey.showEnabled.get())
        t:assertEqual(byKey.lockFrames.label(), "lockFrames")
        t:assertFalse(byKey.locked.disabled())
    end,
    ["a path that no longer exists gives nothing"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local ctx = ns.Options.context(newWorld().options, "RXP")
        t:assertEqual(#ns.Options.entries(ctx, { "nowhere" }), 0)
        t:assertEqual(#ns.Options.entries(ctx, { "discord" }), 0)
        t:assertNil(ns.Options.groupAt(ctx, { "nowhere", "deeper" }))
    end,
})

runner:addSuite("Options: lists and sliders", {
    ["a list with a function of values is sorted by label"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        local ctx = ns.Options.context(world.options, "RXP")
        local byKey = {}
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            byKey[entry.key] = entry
        end
        local choices = byKey.theme.choices()
        t:assertEqual(#choices, 3)
        t:assertEqual(choices[1].label, "Custom")
        t:assertEqual(choices[2].label, "Dark")
        t:assertEqual(choices[3].label, "RXP Blue")
        t:assertEqual(choices[3].value, "blue")
    end,
    ["a list with a sorting uses it"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local ctx = ns.Options.context(newWorld().options, "RXP")
        local byKey = {}
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            byKey[entry.key] = entry
        end
        local labels = {}
        for _, choice in ipairs(byKey.sorted.choices()) do
            tinsert(labels, choice.label)
        end
        t:assertEqual(table.concat(labels, ","), "Gamma,Alpha,Beta")
    end,
    ["a list with numeric keys is ordered by key"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local ctx = ns.Options.context(newWorld().options, "RXP")
        local byKey = {}
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            byKey[entry.key] = entry
        end
        local labels = {}
        for _, choice in ipairs(byKey.numbers.choices()) do
            tinsert(labels, choice.label)
        end
        t:assertEqual(table.concat(labels, ","), "two,five,ten")
    end,
    ["slider limits follow AceConfigDialog's defaults"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local ctx = ns.Options.context(newWorld().options, "RXP")
        local byKey = {}
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            byKey[entry.key] = entry
        end
        local min, max, step, bigStep, isPercent = byKey.arrowScale.range()
        t:assertEqual(min, 0.5)
        t:assertEqual(max, 2)
        t:assertEqual(step, 0.1)
        t:assertNil(bigStep)
        t:assertFalse(isPercent)
        t:assertTrue(select(5, byKey.percent.range()))
        local softMin, softMax = byKey.softOnly.range()
        t:assertEqual(softMin, 1)
        t:assertEqual(softMax, 9)
    end,
    ["a slider with no limits at all gets 0 to 100"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local options = { type = "group", args = { x = { type = "range", name = "X" } } }
        local entry = ns.Options.entries(ns.Options.context(options, "A"), {})[1]
        local min, max = entry.range()
        t:assertEqual(min, 0)
        t:assertEqual(max, 100)
    end,
})

runner:addSuite("Options: changing", {
    ["setting goes through the inherited set with the option's key"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        local ctx = ns.Options.context(world.options, "RXP")
        local byKey = {}
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            byKey[entry.key] = entry
        end
        t:assertTrue(byKey.lockFrames.commit(true))
        t:assertTrue(world.profile.lockFrames)
        t:assertEqual(world.calls[1][2], "lockFrames")
    end,
    ["a button runs its func"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        local ctx = ns.Options.context(world.options, "RXP")
        local entries = ns.Options.entries(ctx, {})
        t:assertTrue(entries[1].commit())
        t:assertEqual(world.calls[1][1], "func")
        t:assertEqual(world.calls[1][2], "discord")
    end,
    ["a failing set returns the error"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local world = newWorld()
        world.options.args.general.args.lockFrames.set = function()
            error("refused")
        end
        local ctx = ns.Options.context(world.options, "RXP")
        local byKey = {}
        for _, entry in ipairs(ns.Options.entries(ctx, { "general" })) do
            byKey[entry.key] = entry
        end
        local ok, err = byKey.lockFrames.commit(true)
        t:assertFalse(ok)
        t:assertMatch(err, "refused")
    end,
    ["a confirm function asks with its text"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local ctx = ns.Options.context(newWorld().options, "RXP")
        local entries = ns.Options.entries(ctx, {})
        t:assertEqual(entries[2].confirmText(), "Clear guide progress for current character")
        t:assertNil(entries[1].confirmText())
    end,
    ["confirm = true asks with the name and the description"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local options = {
            type = "group",
            args = { go = { type = "execute", name = "Go", desc = "Really go", func = function() end, confirm = true } },
        }
        local entry = ns.Options.entries(ns.Options.context(options, "A"), {})[1]
        t:assertEqual(entry.confirmText(), "Go - Really go")
        options.args.go.confirmText = "Sure?"
        t:assertEqual(entry.confirmText(), "Sure?")
    end,
    ["a group's confirm is inherited"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local options = {
            type = "group",
            args = {
                sub = {
                    type = "group",
                    confirm = true,
                    args = { go = { type = "execute", name = "Go", func = function() end } },
                },
            },
        }
        local entry = ns.Options.entries(ns.Options.context(options, "A"), { "sub" })[1]
        t:assertEqual(entry.confirmText(), "Go")
    end,
    ["a pattern refuses what does not match and says what was expected"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local options = {
            type = "group",
            args = { code = { type = "input", name = "Code", pattern = "^%d+$", usage = "digits only", set = function() end, get = function() return "" end } },
        }
        local entry = ns.Options.entries(ns.Options.context(options, "A"), {})[1]
        t:assertTrue(entry.check("123"))
        local ok, message = entry.check("abc")
        t:assertFalse(ok)
        t:assertEqual(message, "Code: digits only")
    end,
    ["a validate function can refuse with a message"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local options = {
            type = "group",
            validate = function(info, value)
                if value == "bad" then
                    return "That one is bad"
                end
                return true
            end,
            args = { name = { type = "input", name = "Name", set = function() end } },
        }
        local entry = ns.Options.entries(ns.Options.context(options, "A"), {})[1]
        t:assertTrue(entry.check("good"))
        local ok, message = entry.check("bad")
        t:assertFalse(ok)
        t:assertEqual(message, "That one is bad")
    end,
    ["a validate returning false gives the generic message"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local options = {
            type = "group",
            validate = function()
                return false
            end,
            args = { name = { type = "input", name = "Name", set = function() end } },
        }
        local entry = ns.Options.entries(ns.Options.context(options, "A"), {})[1]
        local ok, message = entry.check("x")
        t:assertFalse(ok)
        t:assertEqual(message, "Name: Invalid Value")
    end,
})

runner:addSuite("Options: handlers and plugins", {
    ["a method name is called on the nearest handler"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local handler = { stored = 7 }
        function handler:GetValue(info)
            return self.stored, info[#info]
        end
        function handler:SetValue(info, value)
            self.stored = value
        end
        local options = {
            type = "group",
            handler = handler,
            get = "GetValue",
            set = "SetValue",
            args = { n = { type = "range", name = "N", min = 0, max = 10 } },
        }
        local entry = ns.Options.entries(ns.Options.context(options, "A"), {})[1]
        t:assertEqual(entry.get(), 7)
        t:assertTrue(entry.commit(3))
        t:assertEqual(handler.stored, 3)
    end,
    ["a subgroup's handler replaces the root's"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local rootHandler = { Get = function() return "root" end }
        local subHandler = { Get = function() return "sub" end }
        local options = {
            type = "group",
            handler = rootHandler,
            get = "Get",
            args = {
                sub = { type = "group", handler = subHandler, args = { x = { type = "input", name = "X" } } },
                y = { type = "input", name = "Y" },
            },
        }
        local ctx = ns.Options.context(options, "A")
        t:assertEqual(ns.Options.entries(ctx, { "sub" })[1].get(), "sub")
        local rootEntries = ns.Options.entries(ctx, {})
        for _, entry in ipairs(rootEntries) do
            if entry.key == "y" then
                t:assertEqual(entry.get(), "root")
            end
        end
    end,
    ["a missing method is an error for a set but only nil for a get"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local options = {
            type = "group",
            handler = {},
            get = "Nope",
            set = "Nope",
            args = { x = { type = "toggle", name = "X" } },
        }
        local entry = ns.Options.entries(ns.Options.context(options, "A"), {})[1]
        t:assertNil(entry.get())
        local ok = entry.commit(true)
        t:assertFalse(ok)
    end,
    ["a subgroup's own get and set win over the root's"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local store = {}
        local options = {
            type = "group",
            get = function() return "root" end,
            set = function() store.root = true end,
            args = {
                sub = {
                    type = "group",
                    get = function() return "sub" end,
                    set = function() store.sub = true end,
                    args = { x = { type = "toggle", name = "X" } },
                },
            },
        }
        local entry = ns.Options.entries(ns.Options.context(options, "A"), { "sub" })[1]
        t:assertEqual(entry.get(), "sub")
        entry.commit(true)
        t:assertTrue(store.sub)
        t:assertNil(store.root)
    end,
    ["plugins add options to a group"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local options = {
            type = "group",
            args = { a = { type = "toggle", name = "A", order = 1 } },
            plugins = { extra = { b = { type = "toggle", name = "B", order = 2 } } },
        }
        local entries = ns.Options.entries(ns.Options.context(options, "A"), {})
        t:assertEqual(#entries, 2)
        t:assertEqual(entries[2].key, "b")
    end,
    ["the info table carries the key path, the argument and the option"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local seen
        local options = {
            type = "group",
            get = function(info)
                seen = info
            end,
            args = { sub = { type = "group", args = { x = { type = "toggle", name = "X", arg = "extra" } } } },
        }
        local entry = ns.Options.entries(ns.Options.context(options, "App"), { "sub" })[1]
        entry.get()
        t:assertEqual(seen[1], "sub")
        t:assertEqual(seen[2], "x")
        t:assertEqual(#seen, 2)
        t:assertEqual(seen.arg, "extra")
        t:assertEqual(seen.option.name, "X")
        t:assertEqual(seen.type, "toggle")
        t:assertEqual(seen.appName, "App")
        t:assertEqual(seen.options, options)
    end,
})

runner:addSuite("Options: finding the table", {
    ["found through AceConfigRegistry for the dialog"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        local root = { type = "group", args = {} }
        local seen
        local saved = rawget(_G, "LibStub")
        _G.LibStub = function(name)
            t:assertEqual(name, "AceConfigRegistry-3.0")
            return {
                GetOptionsTable = function(_, appName, uiType, uiName)
                    seen = { appName, uiType, uiName }
                    return root
                end,
            }
        end
        local ok, err = pcall(function()
            local ctx = ns.Options.find("RestedXP Guides")
            t:assertEqual(ctx.root, root)
            t:assertEqual(ctx.appName, "RestedXP Guides")
            t:assertEqual(seen[2], "dialog")
        end)
        _G.LibStub = saved
        if not ok then
            error(err, 0)
        end
    end,
    ["nothing without the library or the table"] = function(t)
        local ns = loadAddon({ "Locale", "Text", "Options" })
        t:assertNil(ns.Options.find("X"))
        local saved = rawget(_G, "LibStub")
        _G.LibStub = function()
            return {
                GetOptionsTable = function()
                    error("not registered")
                end,
            }
        end
        local ok, err = pcall(function()
            t:assertNil(ns.Options.find("X"))
        end)
        _G.LibStub = function()
            return { GetOptionsTable = function() return "not a table" end }
        end
        local ok2, err2 = pcall(function()
            t:assertNil(ns.Options.find("X"))
        end)
        _G.LibStub = saved
        if not ok then
            error(err, 0)
        end
        if not ok2 then
            error(err2, 0)
        end
    end,
})

end
