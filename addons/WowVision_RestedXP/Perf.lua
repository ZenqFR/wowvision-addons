-- How long this addon's own work takes, so that a slowdown can be told from what the game, WowVision or RestedXP
-- do. The entry points that can run often (the screens, the window poll, the announcements, the follower, the keys)
-- are timed; /wvrxp temps says the totals and the slowest single calls. It costs two clock reads per call.
local _, ns = ...
local L = ns.L

local Perf = {}
ns.Perf = Perf

local stats = {}
local slowest = {}
local KEEP = 5

-- A single call at least this long (milliseconds) is remembered by name.
Perf.slowFrom = 10

-- Milliseconds, from the game's profiling clock; replaceable (the tests give it a fake one).
function Perf.clock()
    if debugprofilestop ~= nil then
        return debugprofilestop()
    end
    if GetTime ~= nil then
        return GetTime() * 1000
    end
    return 0
end

local function record(name, ms)
    local entry = stats[name]
    if entry == nil then
        entry = { calls = 0, total = 0, max = 0 }
        stats[name] = entry
    end
    entry.calls = entry.calls + 1
    entry.total = entry.total + ms
    if ms > entry.max then
        entry.max = ms
    end
    if ms >= Perf.slowFrom then
        slowest[#slowest + 1] = { name = name, ms = ms }
        table.sort(slowest, function(a, b)
            return a.ms > b.ms
        end)
        while #slowest > KEEP do
            slowest[#slowest] = nil
        end
    end
end

local function finish(name, start, ...)
    record(name, Perf.clock() - start)
    return ...
end

-- Runs fn(...) and counts its time under name; gives back what fn gives back. A call that fails is not counted.
function Perf.time(name, fn, ...)
    local start = Perf.clock()
    return finish(name, start, fn(...))
end

function Perf.reset()
    stats = {}
    slowest = {}
end

-- The measures, the longest in all first: { name, calls, total, max }.
function Perf.rows()
    local rows = {}
    for name, entry in pairs(stats) do
        rows[#rows + 1] = { name = name, calls = entry.calls, total = entry.total, max = entry.max }
    end
    table.sort(rows, function(a, b)
        if a.total == b.total then
            return a.name < b.name
        end
        return a.total > b.total
    end)
    return rows
end

function Perf.slowestCalls()
    local copy = {}
    for i, entry in ipairs(slowest) do
        copy[i] = { name = entry.name, ms = entry.ms }
    end
    return copy
end

-- What the measures are called when said.
local function displayName(name)
    local names = {
        ["main screen"] = L["main screen"],
        ["menu screen"] = L["menu screen"],
        ["options screen"] = L["options screen"],
        ["import screen"] = L["import screen"],
        ["window poll"] = L["window poll"],
        ["menu build"] = L["menu build"],
        ["options table"] = L["options table"],
        ["step announcement"] = L["step announcement"],
        ["arrow follower"] = L["arrow follower"],
        ["menu hook"] = L["menu hook"],
        ["key"] = L["key"],
    }
    return names[name] or name
end

-- A number of milliseconds as it is said: one decimal, with the language's decimal separator.
function Perf.ms(value)
    local text = string.format("%.1f", value)
    return (text:gsub("%.", L["."]))
end

-- The addons whose memory is said: the guide, WowVision, and this one.
local MEMORY_OF = { "RXPGuides", "WowVision", "WowVision_RestedXP" }

-- The memory each of them holds, and what Lua holds in all, in megabytes: { { name, mb }... }, total. Nil when the
-- game does not tell (profiling is not always on for addons).
function Perf.memory()
    local get = rawget(_G, "GetAddOnMemoryUsage")
    if get == nil and rawget(_G, "C_AddOns") ~= nil then
        get = _G.C_AddOns.GetAddOnMemoryUsage
    end
    local list = {}
    if get ~= nil then
        local update = rawget(_G, "UpdateAddOnMemoryUsage")
        if update ~= nil then
            pcall(update)
        end
        for _, name in ipairs(MEMORY_OF) do
            local ok, kilobytes = pcall(get, name)
            if ok and type(kilobytes) == "number" then
                list[#list + 1] = { name = name, mb = kilobytes / 1024 }
            end
        end
    end
    local total = nil
    if collectgarbage ~= nil then
        local ok, kilobytes = pcall(collectgarbage, "count")
        if ok and type(kilobytes) == "number" then
            total = kilobytes / 1024
        end
    end
    if #list == 0 and total == nil then
        return nil
    end
    return list, total
end

local function memoryText()
    local list, total = Perf.memory()
    if list == nil then
        return nil
    end
    local parts = {}
    for _, entry in ipairs(list) do
        parts[#parts + 1] = entry.name .. " " .. string.format(L["%s MB"], Perf.ms(entry.mb))
    end
    if total ~= nil then
        parts[#parts + 1] = L["all of Lua"] .. " " .. string.format(L["%s MB"], Perf.ms(total))
    end
    return L["Memory"] .. ": " .. table.concat(parts, ", ")
end

-- The report, in sentences. Only the six longest measures, then the slowest single calls, then the memory.
function Perf.text()
    local rows = Perf.rows()
    local memory = memoryText()
    if #rows == 0 then
        if memory ~= nil then
            return L["Nothing measured yet."] .. " " .. memory
        end
        return L["Nothing measured yet."]
    end
    local parts = {}
    for i = 1, math.min(#rows, 6) do
        local row = rows[i]
        parts[#parts + 1] = string.format(
            L["%s: %d calls, %s ms in all, %s ms at worst"],
            displayName(row.name),
            row.calls,
            Perf.ms(row.total),
            Perf.ms(row.max)
        )
    end
    if #slowest > 0 then
        local calls = {}
        for _, entry in ipairs(slowest) do
            calls[#calls + 1] = displayName(entry.name) .. " " .. Perf.ms(entry.ms) .. " ms"
        end
        parts[#parts + 1] = L["Slowest calls"] .. ": " .. table.concat(calls, ", ")
    end
    if memory ~= nil then
        parts[#parts + 1] = memory
    end
    return table.concat(parts, ". ")
end
