return function(runner, env)
local loadAddon = env.loadAddon

local FILES = { "Locale", "Perf" }

-- A clock the test moves by hand: Perf.time reads it before and after the call.
local function newPerf()
    local ns = loadAddon(FILES)
    -- the memory sentence has its own tests; the others read the report without it
    ns.Perf.memory = function()
        return nil
    end
    local clock = { now = 0 }
    ns.Perf.clock = function()
        return clock.now
    end
    return ns, clock
end

-- A function that takes `ms` milliseconds on the fake clock and returns what it is given.
local function slow(clock, ms)
    return function(...)
        clock.now = clock.now + ms
        return ...
    end
end

runner:addSuite("Perf: measuring", {
    ["it gives back what the function gives back, all of it"] = function(t)
        local ns, clock = newPerf()
        local a, b, c = ns.Perf.time("key", slow(clock, 1), "x", nil, 3)
        t:assertEqual(a, "x")
        t:assertNil(b)
        t:assertEqual(c, 3)
    end,
    ["calls, total and the worst are counted by name"] = function(t)
        local ns, clock = newPerf()
        ns.Perf.time("key", slow(clock, 2))
        ns.Perf.time("key", slow(clock, 6))
        ns.Perf.time("key", slow(clock, 1))
        ns.Perf.time("window poll", slow(clock, 3))
        local rows = ns.Perf.rows()
        t:assertEqual(#rows, 2)
        t:assertEqual(rows[1].name, "key")
        t:assertEqual(rows[1].calls, 3)
        t:assertEqual(rows[1].total, 9)
        t:assertEqual(rows[1].max, 6)
        t:assertEqual(rows[2].name, "window poll")
    end,
    ["the rows come with the longest in all first, ties by name"] = function(t)
        local ns, clock = newPerf()
        ns.Perf.time("b", slow(clock, 1))
        ns.Perf.time("a", slow(clock, 1))
        ns.Perf.time("c", slow(clock, 5))
        local names = {}
        for _, row in ipairs(ns.Perf.rows()) do
            names[#names + 1] = row.name
        end
        t:assertEqual(table.concat(names, ","), "c,a,b")
    end,
    ["a call that fails is not counted, and the error goes on"] = function(t)
        local ns = newPerf()
        local ok, err = pcall(ns.Perf.time, "key", function()
            error("boom")
        end)
        t:assertFalse(ok)
        t:assertMatch(err, "boom")
        t:assertEqual(#ns.Perf.rows(), 0)
    end,
    ["the arguments reach the function"] = function(t)
        local ns = newPerf()
        local seen
        ns.Perf.time("key", function(...)
            seen = { ... }
        end, 1, 2, 3)
        t:assertEqual(#seen, 3)
        t:assertEqual(seen[3], 3)
    end,
    ["reset forgets everything"] = function(t)
        local ns, clock = newPerf()
        ns.Perf.time("key", slow(clock, 50))
        ns.Perf.reset()
        t:assertEqual(#ns.Perf.rows(), 0)
        t:assertEqual(#ns.Perf.slowestCalls(), 0)
    end,
    ["the clock falls back to the game's time, then to nothing"] = function(t)
        local ns = loadAddon(FILES)
        local saved = { debugprofilestop = rawget(_G, "debugprofilestop"), GetTime = rawget(_G, "GetTime") }
        rawset(_G, "debugprofilestop", function() return 12.5 end)
        t:assertEqual(ns.Perf.clock(), 12.5)
        rawset(_G, "debugprofilestop", nil)
        rawset(_G, "GetTime", function() return 2 end)
        t:assertEqual(ns.Perf.clock(), 2000)
        rawset(_G, "GetTime", nil)
        t:assertEqual(ns.Perf.clock(), 0)
        rawset(_G, "debugprofilestop", saved.debugprofilestop)
        rawset(_G, "GetTime", saved.GetTime)
    end,
})

runner:addSuite("Perf: the slowest calls", {
    ["only calls from the threshold up are kept, slowest first"] = function(t)
        local ns, clock = newPerf()
        ns.Perf.time("key", slow(clock, 9))
        ns.Perf.time("menu build", slow(clock, 40))
        ns.Perf.time("key", slow(clock, 10))
        ns.Perf.time("window poll", slow(clock, 25))
        local calls = ns.Perf.slowestCalls()
        t:assertEqual(#calls, 3)
        t:assertEqual(calls[1].name, "menu build")
        t:assertEqual(calls[2].name, "window poll")
        t:assertEqual(calls[3].ms, 10)
    end,
    ["at most five are kept"] = function(t)
        local ns, clock = newPerf()
        for i = 1, 8 do
            ns.Perf.time("key", slow(clock, 10 + i))
        end
        local calls = ns.Perf.slowestCalls()
        t:assertEqual(#calls, 5)
        t:assertEqual(calls[1].ms, 18)
        t:assertEqual(calls[5].ms, 14)
    end,
    ["the list handed out is a copy"] = function(t)
        local ns, clock = newPerf()
        ns.Perf.time("key", slow(clock, 30))
        ns.Perf.slowestCalls()[1].ms = 1
        t:assertEqual(ns.Perf.slowestCalls()[1].ms, 30)
    end,
})

runner:addSuite("Perf: the report", {
    ["nothing measured"] = function(t)
        local ns = newPerf()
        t:assertEqual(ns.Perf.text(), "Nothing measured yet.")
    end,
    ["it says each measure, with its calls, total and worst"] = function(t)
        local ns, clock = newPerf()
        ns.Perf.time("main screen", slow(clock, 2))
        ns.Perf.time("main screen", slow(clock, 4))
        t:assertEqual(ns.Perf.text(), "main screen: 2 calls, 6.0 ms in all, 4.0 ms at worst")
    end,
    ["and the slowest single calls after them"] = function(t)
        local ns, clock = newPerf()
        ns.Perf.time("menu build", slow(clock, 85))
        t:assertEqual(
            ns.Perf.text(),
            "menu build: 1 calls, 85.0 ms in all, 85.0 ms at worst. Slowest calls: menu build 85.0 ms"
        )
    end,
    ["only the six longest measures are said"] = function(t)
        local ns, clock = newPerf()
        for _, name in ipairs({ "main screen", "menu screen", "options screen", "window poll", "menu build", "options table", "key", "menu hook" }) do
            ns.Perf.time(name, slow(clock, 1))
        end
        local _, count = ns.Perf.text():gsub("calls", "")
        t:assertEqual(count, 6)
    end,
    ["French names, French decimal comma"] = function(t)
        local ns, clock = newPerf()
        ns.useLocale("frFR")
        ns.Perf.time("arrow follower", slow(clock, 1.5))
        t:assertEqual(ns.Perf.text(), "suivi de la flèche : 1 appels, 1,5 ms en tout, 1,5 ms au pire")
    end,
    ["German"] = function(t)
        local ns, clock = newPerf()
        ns.useLocale("deDE")
        ns.Perf.time("key", slow(clock, 12))
        t:assertMatch(ns.Perf.text(), "^Taste: 1 Aufrufe, 12,0 ms insgesamt, 12,0 ms im schlechtesten Fall")
        t:assertMatch(ns.Perf.text(), "Langsamste Aufrufe: Taste 12,0 ms")
    end,
    ["a measure with no translation is said as it is"] = function(t)
        local ns, clock = newPerf()
        ns.Perf.time("something new", slow(clock, 1))
        t:assertMatch(ns.Perf.text(), "^something new: 1 calls")
    end,
    ["the memory is said after the measures, from the game's own figures"] = function(t)
        local ns, clock = newPerf()
        ns.Perf.memory = loadAddon(FILES).Perf.memory
        ns.Perf.time("key", slow(clock, 2))
        local saved = { get = rawget(_G, "GetAddOnMemoryUsage"), update = rawget(_G, "UpdateAddOnMemoryUsage"), count = collectgarbage }
        local updated = 0
        rawset(_G, "UpdateAddOnMemoryUsage", function() updated = updated + 1 end)
        rawset(_G, "GetAddOnMemoryUsage", function(name)
            if name == "RXPGuides" then
                return 215040
            elseif name == "WowVision" then
                return 51200
            end
            return nil
        end)
        local ok, err = pcall(function()
            local list, total = ns.Perf.memory()
            t:assertEqual(#list, 2)
            t:assertEqual(list[1].name, "RXPGuides")
            t:assertEqual(list[1].mb, 210)
            t:assertEqual(list[2].mb, 50)
            t:assertEqual(updated, 1)
            t:assertTrue(total > 0)
            t:assertMatch(
                ns.Perf.text(),
                "Memory: RXPGuides 210%.0 MB, WowVision 50%.0 MB, all of Lua [%d%.]+ MB$"
            )
        end)
        rawset(_G, "GetAddOnMemoryUsage", saved.get)
        rawset(_G, "UpdateAddOnMemoryUsage", saved.update)
        if not ok then
            error(err, 0)
        end
    end,
    ["Lua's total is said in megabytes"] = function(t)
        local ns = loadAddon(FILES)
        local saved = { get = rawget(_G, "GetAddOnMemoryUsage"), c = rawget(_G, "C_AddOns"), count = collectgarbage }
        rawset(_G, "GetAddOnMemoryUsage", nil)
        rawset(_G, "C_AddOns", nil)
        rawset(_G, "collectgarbage", function(what)
            return what == "count" and 3072 or 0
        end)
        local _, total = ns.Perf.memory()
        rawset(_G, "collectgarbage", saved.count)
        rawset(_G, "GetAddOnMemoryUsage", saved.get)
        rawset(_G, "C_AddOns", saved.c)
        t:assertEqual(total, 3)
    end,
    ["with nothing measured the memory is still said"] = function(t)
        local ns = newPerf()
        ns.Perf.memory = function()
            return { { name = "RXPGuides", mb = 1.5 } }, 4
        end
        t:assertEqual(ns.Perf.text(), "Nothing measured yet. Memory: RXPGuides 1.5 MB, all of Lua 4.0 MB")
    end,
    ["French memory"] = function(t)
        local ns = newPerf()
        ns.useLocale("frFR")
        ns.Perf.memory = function()
            return { { name = "RXPGuides", mb = 1.5 } }, nil
        end
        t:assertEqual(ns.Perf.text(), "Rien n'a encore été mesuré. Mémoire: RXPGuides 1,5 Mo")
    end,
    ["without the game's memory figures, the total of Lua alone"] = function(t)
        local ns = loadAddon(FILES)
        local saved = { get = rawget(_G, "GetAddOnMemoryUsage"), c = rawget(_G, "C_AddOns") }
        rawset(_G, "GetAddOnMemoryUsage", nil)
        rawset(_G, "C_AddOns", nil)
        local list, total = ns.Perf.memory()
        rawset(_G, "GetAddOnMemoryUsage", saved.get)
        rawset(_G, "C_AddOns", saved.c)
        t:assertEqual(#list, 0)
        t:assertTrue(total > 0)
    end,
    ["the figures can also come from C_AddOns"] = function(t)
        local ns = loadAddon(FILES)
        local saved = { get = rawget(_G, "GetAddOnMemoryUsage"), c = rawget(_G, "C_AddOns") }
        rawset(_G, "GetAddOnMemoryUsage", nil)
        rawset(_G, "C_AddOns", { GetAddOnMemoryUsage = function(name) return name == "WowVision" and 2048 or nil end })
        local list = ns.Perf.memory()
        rawset(_G, "GetAddOnMemoryUsage", saved.get)
        rawset(_G, "C_AddOns", saved.c)
        t:assertEqual(#list, 1)
        t:assertEqual(list[1].mb, 2)
    end,
    ["a failing memory read is left out"] = function(t)
        local ns = loadAddon(FILES)
        local saved = rawget(_G, "GetAddOnMemoryUsage")
        rawset(_G, "GetAddOnMemoryUsage", function() error("no profiling") end)
        local list = ns.Perf.memory()
        rawset(_G, "GetAddOnMemoryUsage", saved)
        t:assertEqual(#list, 0)
    end,
    ["milliseconds have one decimal"] = function(t)
        local ns = newPerf()
        t:assertEqual(ns.Perf.ms(0), "0.0")
        t:assertEqual(ns.Perf.ms(12.34), "12.3")
        t:assertEqual(ns.Perf.ms(0.05), "0.1")
    end,
})

end
