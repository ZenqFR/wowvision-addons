-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+). The game, Sharpie's Gear Judge and WowVision are
-- stand-ins; tests/real_core.lua runs the keys against WowVision's real input manager.
local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."

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

local function contains(text, part, label)
    if text == nil or not tostring(text):find(part, 1, true) then
        error((label or "text differs") .. ": expected it to contain '" .. part .. "', got " .. tostring(text), 2)
    end
end

-- Sets globals for the length of fn, then puts them back (a failure included).
local function withGlobals(wanted, fn)
    local saved = {}
    for key in pairs(wanted) do
        saved[key] = rawget(_G, key)
        rawset(_G, key, wanted[key])
    end
    local ok, err = pcall(fn)
    for key in pairs(wanted) do
        rawset(_G, key, saved[key])
    end
    if not ok then
        error(err, 0)
    end
end

-- ------------------------------------------------------------------- world

local RING = "|cff0070dd|Hitem:100::::::::20|h[Lion Ring]|h|r"
local OLD = "|cff1eff00|Hitem:200::::::::20|h[Old Ring]|h|r"
local BLADE = "|cffa335ee|Hitem:300::::::::20|h[Raid Blade]|h|r"

-- A fresh world: the addon's files loaded, the game and the Judge replaced by stand-ins.
-- config: locale, input (a fake WowVision input manager), raw (keep the real Game functions).
local function newWorld(config)
    config = config or {}
    local w = {
        spoken = {},
        errors = {},
        timers = {},
        requested = {},
        names = { [RING] = "Lion Ring", [OLD] = "Old Ring", [BLADE] = "Raid Blade" },
        scores = {},
        rolls = {},
        judgeCalls = 0,
    }
    geterrorhandler = function()
        return function(err)
            w.errors[#w.errors + 1] = tostring(err)
        end
    end
    GetLocale = function()
        return config.locale or "enUS"
    end
    SlashCmdList = {}
    SLASH_WVROLLJUDGE1, SLASH_WVROLLJUDGE2, SLASH_WVROLLJUDGE3 = nil, nil, nil
    WowVision = nil
    if config.input then
        w.created = {}
        local bindings = {}
        WowVision = {
            input = {
                getBinding = function(_, key)
                    return bindings[key]
                end,
                createBinding = function(_, info)
                    local binding = { info = info, activated = 0 }
                    function binding:activate()
                        self.activated = self.activated + 1
                    end
                    bindings[info.key] = binding
                    w.created[#w.created + 1] = binding
                    return binding
                end,
                getDefaultDB = function()
                    return {}
                end,
            },
            dbManager = {
                resolveBindings = function()
                    return {}
                end,
            },
            applyBindingStore = function()
                w.applied = (w.applied or 0) + 1
            end,
        }
        WowVisionDB = {}
        WowVision.globalDb = {}
        w.bindings = bindings
    end
    local ns = {}
    w.ns = ns
    for _, name in ipairs({ "Locale", "Judge", "Main" }) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_RollJudge", ns)
    end
    if config.locale then
        ns.useLocale(config.locale)
    end
    local Game = ns.Game
    w.Game = Game
    if not config.raw then
        Game.speak = function(text)
            w.spoken[#w.spoken + 1] = text
        end
        Game.locale = function()
            return config.locale or "enUS"
        end
        Game.judge = function()
            if w.noJudge then
                return nil
            end
            return w.api or {
                IsReady = function()
                    return w.ready ~= false
                end,
                ScoreItem = function(link)
                    w.judgeCalls = w.judgeCalls + 1
                    local answer = w.scores[link]
                    if type(answer) == "function" then
                        return answer(link, w.judgeCalls)
                    elseif answer == nil then
                        return nil, "BAD_LINK"
                    end
                    return answer.result, answer.reason
                end,
            }
        end
        Game.rolls = function()
            return w.rolls
        end
        Game.itemName = function(link)
            return w.names[link]
        end
        Game.requestItem = function(link)
            w.requested[#w.requested + 1] = link
        end
        Game.after = function(seconds, fn)
            if w.noTimers then
                return false
            end
            w.timers[#w.timers + 1] = { seconds = seconds, fn = fn }
            return true
        end
    end
    return w
end

-- Runs the timers that are waiting (and any a run adds), at most `limit` of them.
local function runTimers(w, limit)
    local count = 0
    while #w.timers > 0 and count < (limit or 50) do
        local timer = table.remove(w.timers, 1)
        timer.fn()
        count = count + 1
    end
    return count
end

local function score(pct, replaced, extra)
    local result = { upgradePct = pct, equippedLink = replaced, equipped = false, specName = "Warrior: Leveling", slot = 11 }
    for key, value in pairs(extra or {}) do
        result[key] = value
    end
    return { result = result }
end

-- ---------------------------------------------------------------- numbers

test("number: one decimal at most, no .0, no minus sign, a decimal comma where the language writes one", function()
    local Judge = newWorld().ns.Judge
    eq(Judge.number(4.2, "enUS"), "4.2")
    eq(Judge.number(4.0, "enUS"), "4")
    eq(Judge.number(10, "enUS"), "10")
    eq(Judge.number(100, "enUS"), "100")
    eq(Judge.number(-3.14, "enUS"), "3.1")
    eq(Judge.number(0.04, "enUS"), "0")
    eq(Judge.number(4.2, "frFR"), "4,2")
    eq(Judge.number(-12.5, "deDE"), "12,5")
    eq(Judge.number(4, "frFR"), "4")
    eq(Judge.number(4.2, "esES"), "4,2")
    eq(Judge.number(4.2, "enGB"), "4.2")
    eq(Judge.number(4.2, nil), "4.2")
end)

-- ---------------------------------------------------------------- verdicts

test("verdict: an upgrade says how much and what it replaces", function()
    local w = newWorld()
    w.scores[RING] = score(4.2, OLD)
    local text = w.ns.Judge.line(w.Game, { link = RING })
    eq(text, "Lion Ring, upgrade of 4.2 percent, instead of Old Ring")
end)

test("verdict: a regression says how much, without a minus sign", function()
    local w = newWorld()
    w.scores[RING] = score(-3.1, OLD)
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, downgrade of 3.1 percent, instead of Old Ring")
end)

test("verdict: less than a twentieth of a percent is no change, either way", function()
    local w = newWorld()
    for _, pct in ipairs({ 0, 0.04, -0.04, 0.049 }) do
        w.scores[RING] = score(pct, OLD)
        eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, no change, instead of Old Ring", tostring(pct))
    end
    w.scores[RING] = score(0.05, OLD)
    contains(w.ns.Judge.line(w.Game, { link = RING }), "upgrade of 0.1 percent")
    w.scores[RING] = score(-0.06, OLD)
    contains(w.ns.Judge.line(w.Game, { link = RING }), "downgrade of 0.1 percent")
end)

test("verdict: an item already worn says so, whatever the figure", function()
    local w = newWorld()
    w.scores[RING] = score(5, OLD, { equipped = true })
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, you already wear it")
end)

test("verdict: an empty slot is said instead of what it replaces", function()
    local w = newWorld()
    w.scores[RING] = score(40, nil)
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, upgrade of 40 percent, empty slot")
    w.scores[RING] = score(40, "")
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, upgrade of 40 percent, empty slot")
end)

test("verdict: the replaced item is named by the game, else by its link, else not at all", function()
    local w = newWorld()
    w.scores[RING] = score(2, "|Hitem:999::::|h[Link Only]|h")
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, upgrade of 2 percent, instead of Link Only")
    w.scores[RING] = score(2, "item:999")
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, upgrade of 2 percent", "no name anywhere")
end)

test("verdict: the item's name comes from the game, else from the link, else from the window", function()
    local w = newWorld()
    w.scores[BLADE] = score(7, nil)
    w.names[BLADE] = nil
    eq(w.ns.Judge.line(w.Game, { link = BLADE }), "Raid Blade, upgrade of 7 percent, empty slot", "from the link")
    w.scores["item:1"] = score(7, nil)
    eq(w.ns.Judge.line(w.Game, { link = "item:1", name = "Window Name" }), "Window Name, upgrade of 7 percent, empty slot")
    eq(w.ns.Judge.line(w.Game, { link = "item:1" }), "upgrade of 7 percent, empty slot", "no name at all")
end)

test("verdict: a Judge answer without a usable figure says so", function()
    local w = newWorld()
    for _, pct in ipairs({ "x", math.huge, -math.huge, 0 / 0 }) do
        w.scores[RING] = score(pct, OLD)
        eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, Gear Judge gave no figure", tostring(pct))
    end
    w.scores[RING] = score(nil, OLD)
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, Gear Judge gave no figure")
end)

test("verdict: with no percentage (a character that wears nothing yet) the points still say which way", function()
    local w = newWorld()
    w.scores[RING] = score(nil, nil, { upgrade = 12.5 })
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, an upgrade, empty slot")
    w.scores[RING] = score(nil, OLD, { upgrade = -3 })
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, a downgrade, instead of Old Ring")
    w.scores[RING] = score(nil, OLD, { upgrade = 0 })
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, no change, instead of Old Ring")
    w.scores[RING] = score(nil, OLD, { upgrade = "lots" })
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, Gear Judge gave no figure")
    w.scores[RING] = score(2, OLD, { upgrade = -50 })
    contains(w.ns.Judge.line(w.Game, { link = RING }), "upgrade of 2 percent", "the percentage wins over the points")
    local french = newWorld({ locale = "frFR" })
    french.scores[RING] = score(nil, nil, { upgrade = 5 })
    eq(french.ns.Judge.line(french.Game, { link = RING }), "Lion Ring, une amélioration, emplacement vide")
end)

test("verdict: each reason the Judge cannot score has its words", function()
    local w = newWorld()
    local expected = {
        NOT_USABLE = "your class cannot use it",
        NOT_EQUIPPABLE = "it is not equipment",
        NOT_READY = "Gear Judge is not ready yet",
        NOT_CACHED = "the item is not loaded yet",
        BAD_LINK = "Gear Judge cannot read that item",
        ERROR = "Gear Judge reported an error",
        SOMETHING_NEW = "Gear Judge reported an error",
    }
    for reason, words in pairs(expected) do
        w.scores[RING] = { result = nil, reason = reason }
        eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, " .. words, reason)
    end
    w.scores[RING] = { result = nil, reason = nil }
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, Gear Judge reported an error", "no reason at all")
end)

test("verdict: only an item the game has not loaded is worth asking again", function()
    local w = newWorld()
    w.scores[RING] = { result = nil, reason = "NOT_CACHED" }
    local _, retry = w.ns.Judge.line(w.Game, { link = RING })
    eq(retry, true)
    for _, reason in ipairs({ "NOT_USABLE", "NOT_EQUIPPABLE", "NOT_READY", "BAD_LINK", "ERROR" }) do
        w.scores[RING] = { result = nil, reason = reason }
        local _, again = w.ns.Judge.line(w.Game, { link = RING })
        eq(again == true, false, reason)
    end
    w.scores[RING] = score(3, OLD)
    local _, fine = w.ns.Judge.line(w.Game, { link = RING })
    eq(fine == true, false)
end)

test("verdict: the Judge missing, too old, or not ready", function()
    local w = newWorld()
    w.noJudge = true
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, Gear Judge is not installed or not enabled.")
    w.noJudge = false
    w.api = { IsReady = function() return true end }
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, Gear Judge is too old: version 3.2.7 or later is needed.")
    local asked = 0
    w.api = {
        IsReady = function()
            return false
        end,
        ScoreItem = function()
            asked = asked + 1
        end,
    }
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, Gear Judge is not ready yet")
    eq(asked, 0, "a Judge that is not ready is not asked")
    w.api = {
        IsReady = function()
            error("boom")
        end,
        ScoreItem = function()
            return score(1, OLD).result
        end,
    }
    contains(w.ns.Judge.line(w.Game, { link = RING }), "upgrade of 1 percent", "a failing IsReady does not stop the answer")
    w.api = { ScoreItem = function() return score(1, OLD).result end }
    contains(w.ns.Judge.line(w.Game, { link = RING }), "upgrade of 1 percent", "a Judge with no IsReady")
end)

test("verdict: an error inside the Judge is reported once, and the player hears it", function()
    local w = newWorld()
    w.api = {
        IsReady = function()
            return true
        end,
        ScoreItem = function()
            error("judge failed")
        end,
    }
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, Gear Judge reported an error")
    w.ns.Judge.line(w.Game, { link = RING })
    eq(#w.errors, 1)
    contains(w.errors[1], "judge failed")
end)

test("verdict: a roll window with no link says it cannot read the item", function()
    local w = newWorld()
    eq(w.ns.Judge.line(w.Game, { link = nil, name = "Mystery" }), "Mystery, Gear Judge cannot read that item")
    eq(w.ns.Judge.line(w.Game, { link = nil }), "Gear Judge cannot read that item")
    eq(w.judgeCalls, 0, "the Judge is not asked about a window with no item")
end)

-- -------------------------------------------------------------------- keys

test("the key: no roll window says so", function()
    local w = newWorld()
    w.ns.sayVerdict()
    eq(w.spoken[1], "No loot.")
    eq(#w.spoken, 1)
end)

test("the key: the first window's item, only", function()
    local w = newWorld()
    w.rolls = { { link = RING }, { link = BLADE } }
    w.scores[RING] = score(4.2, OLD)
    w.scores[BLADE] = score(-1, OLD)
    w.ns.sayVerdict()
    eq(#w.spoken, 1)
    eq(w.spoken[1], "Lion Ring, upgrade of 4.2 percent, instead of Old Ring")
    eq(w.judgeCalls, 1, "the second item was not asked about")
end)

test("the key: an item the game has not loaded is asked for, then answered when it comes", function()
    local w = newWorld()
    w.rolls = { { link = RING } }
    w.scores[RING] = function(_, calls)
        if calls < 3 then
            return nil, "NOT_CACHED"
        end
        return score(4.2, OLD).result
    end
    w.ns.sayVerdict()
    eq(table.concat(w.spoken, "|"), "The item is loading.")
    eq(#w.requested, 1)
    eq(w.requested[1], RING)
    eq(#w.timers, 1)
    eq(w.timers[1].seconds, w.ns.RETRY_DELAY)
    runTimers(w)
    eq(table.concat(w.spoken, "|"), "The item is loading.|Lion Ring, upgrade of 4.2 percent, instead of Old Ring")
    eq(#w.requested, 1, "the game is asked once")
    eq(w.judgeCalls, 3)
end)

test("the key: an item that never loads says so after a few tries", function()
    local w = newWorld()
    w.rolls = { { link = RING } }
    w.scores[RING] = { result = nil, reason = "NOT_CACHED" }
    w.ns.sayVerdict()
    runTimers(w)
    eq(table.concat(w.spoken, "|"), "The item is loading.|Lion Ring, the item is not loaded yet")
    eq(w.judgeCalls, w.ns.RETRIES + 1, "the first ask and each retry")
end)

test("the key: a new press cancels the retries of the one before", function()
    local w = newWorld()
    w.rolls = { { link = RING } }
    local loaded = false
    w.scores[RING] = function()
        if not loaded then
            return nil, "NOT_CACHED"
        end
        return score(1, OLD).result
    end
    w.ns.sayVerdict()
    local first = w.timers[1]
    loaded = true
    w.ns.sayVerdict()
    eq(w.spoken[#w.spoken], "Lion Ring, upgrade of 1 percent, instead of Old Ring")
    local count = #w.spoken
    first.fn()
    eq(#w.spoken, count, "the old retry says nothing")
end)

test("the key: without timers the answer comes at once", function()
    local w = newWorld()
    w.noTimers = true
    w.rolls = { { link = RING } }
    w.scores[RING] = { result = nil, reason = "NOT_CACHED" }
    w.ns.sayVerdict()
    eq(table.concat(w.spoken, "|"), "The item is loading.|Lion Ring, the item is not loaded yet")
end)

test("the key: a retry that fails is reported once and does not break the next press", function()
    local w = newWorld()
    w.rolls = { { link = RING } }
    local calls = 0
    w.Game.judge = function()
        return {
            IsReady = function()
                return true
            end,
            ScoreItem = function()
                calls = calls + 1
                if calls == 1 then
                    return nil, "NOT_CACHED"
                end
                return score(2, OLD).result
            end,
        }
    end
    w.Game.after = function(_, fn)
        w.timers[#w.timers + 1] = { fn = fn }
        return true
    end
    w.Game.speak = function(text)
        if text:find("upgrade", 1, true) then
            error("speech failed")
        end
        w.spoken[#w.spoken + 1] = text
    end
    w.ns.sayVerdict()
    local timer = w.timers[1]
    local ok = pcall(timer.fn)
    eq(ok, true, "the timer's own error is caught")
    eq(#w.errors, 1)
    contains(w.errors[1], "speech failed")
end)

test("read all: every window's item, numbered", function()
    local w = newWorld()
    w.rolls = { { link = RING }, { link = BLADE } }
    w.scores[RING] = score(4.2, OLD)
    w.scores[BLADE] = score(-1, nil)
    w.ns.sayAll()
    eq(#w.spoken, 1)
    eq(w.spoken[1], "Item 1 of 2, Lion Ring, upgrade of 4.2 percent, instead of Old Ring. Item 2 of 2, Raid Blade, downgrade of 1 percent, empty slot")
end)

test("read all: no window says so; an item not loaded yet is asked for and said, without waiting", function()
    local w = newWorld()
    w.ns.sayAll()
    eq(w.spoken[1], "No loot.")
    w.rolls = { { link = RING } }
    w.scores[RING] = { result = nil, reason = "NOT_CACHED" }
    w.ns.sayAll()
    eq(w.spoken[2], "Item 1 of 1, Lion Ring, the item is not loaded yet")
    eq(#w.requested, 1)
    eq(#w.timers, 0)
end)

-- ---------------------------------------------------------------- the game

test("Game.rolls: the visible roll windows in WowVision's order, with the item's link and the window's text", function()
    local w = newWorld({ raw = true })
    local function frame(visible, rollID, text)
        return {
            IsVisible = function()
                return visible
            end,
            rollID = rollID,
            Name = { GetText = function() return text end },
        }
    end
    withGlobals({
        GroupLootFrame1 = frame(false, 5, "Hidden"),
        GroupLootFrame2 = frame(true, 7, "Second"),
        GroupLootFrame3 = frame(true, 8, "Third"),
        GroupLootFrame4 = nil,
        GetLootRollItemLink = function(id)
            if id == 7 then
                return RING
            elseif id == 8 then
                error("no link")
            end
            return OLD
        end,
    }, function()
        local rolls = w.Game.rolls()
        eq(#rolls, 2)
        eq(rolls[1].link, RING)
        eq(rolls[1].name, "Second")
        eq(rolls[2].link, nil, "a failing link is no link")
        eq(rolls[2].name, "Third")
    end)
    withGlobals({ GroupLootFrame6 = frame(true, 9, "Sixth"), GetLootRollItemLink = function() return OLD end }, function()
        eq(#w.Game.rolls(), 1, "six windows are looked at, as WowVision does")
    end)
    eq(#w.Game.rolls(), 0, "no window")
end)

test("Game.rolls: a secret link, a missing roll id or no link function are no link", function()
    local w = newWorld({ raw = true })
    local function frame(rollID)
        return {
            IsVisible = function()
                return true
            end,
            rollID = rollID,
        }
    end
    withGlobals({ GroupLootFrame1 = frame(1), GetLootRollItemLink = function() return RING end }, function()
        WowVision = { isSecret = function() return true end }
        eq(w.Game.rolls()[1].link, nil, "a secret link")
        WowVision = nil
        eq(w.Game.rolls()[1].link, RING)
    end)
    withGlobals({ GroupLootFrame1 = frame(nil), GetLootRollItemLink = function() return RING end }, function()
        eq(w.Game.rolls()[1].link, nil, "no roll id")
    end)
    withGlobals({ GroupLootFrame1 = frame(1), GetLootRollItemLink = false }, function()
        eq(w.Game.rolls()[1].link, nil, "no link function")
    end)
    withGlobals({ GroupLootFrame1 = frame(1), GetLootRollItemLink = function() return 42 end }, function()
        eq(w.Game.rolls()[1].link, nil, "a link that is not text")
    end)
end)

test("Game: the item's name, the request for an item, the timer, the Judge, the language", function()
    local w = newWorld({ raw = true })
    local asked = {}
    withGlobals({
        C_Item = {
            GetItemInfo = function(link)
                if link == RING then
                    return "Lion Ring"
                elseif link == "empty" then
                    return ""
                end
                return nil
            end,
            RequestLoadItemDataByID = function(id)
                asked[#asked + 1] = id
            end,
        },
    }, function()
        eq(w.Game.itemName(RING), "Lion Ring")
        eq(w.Game.itemName("empty"), nil)
        eq(w.Game.itemName(OLD), nil)
        w.Game.requestItem(RING)
        w.Game.requestItem("no id here")
        w.Game.requestItem(nil)
        w.Game.requestItem("|Hitem:7::::|h[Seven]|h")
        eq(#asked, 2)
        eq(asked[1], 100)
        eq(asked[2], 7, "an item number of one digit")
    end)
    withGlobals({ GetItemInfo = function() return "Plain" end }, function()
        eq(w.Game.itemName(RING), "Plain", "a client without C_Item")
    end)
    eq(w.Game.itemName(RING), nil, "no function at all")
    eq(w.Game.after(1, function() end), false, "no timer function")
    local fired
    withGlobals({ C_Timer = { After = function(seconds, fn) fired = seconds; fn() end } }, function()
        local ran = false
        eq(w.Game.after(0.5, function() ran = true end), true)
        eq(fired, 0.5)
        eq(ran, true)
    end)
    eq(w.Game.judge(), nil)
    withGlobals({ SharpiesGearJudgeAPI = { ScoreItem = function() end } }, function()
        check(w.Game.judge() ~= nil)
    end)
    withGlobals({ SharpiesGearJudgeAPI = "not a table" }, function()
        eq(w.Game.judge(), nil)
    end)
    eq(w.Game.locale(), "enUS")
    GetLocale = nil
    eq(w.Game.locale(), "enUS", "no GetLocale")
    GetLocale = function() return "enUS" end
end)

test("Game.speak goes through WowVision, or the chat when it is not there", function()
    local w = newWorld({ raw = true })
    local said = {}
    WowVision = { speak = function(_, text) said[#said + 1] = text end }
    w.Game.speak("hello")
    w.Game.speak("")
    w.Game.speak(nil)
    eq(table.concat(said, "|"), "hello")
    WowVision = nil
end)

-- ------------------------------------------------------------ keys and command

test("the keys: Alt+Ctrl+J says the verdict, the other key has no default and says all", function()
    local w = newWorld({ input = true })
    eq(w.ns.installed, true)
    eq(#w.created, 2)
    local verdict, all = w.bindings["rolljudge/verdict"], w.bindings["rolljudge/all"]
    eq(verdict.info.inputs[1], "ALT-CTRL-J")
    eq(verdict.info.interruptSpeech, true)
    eq(#all.info.inputs, 0, "no key by default")
    eq(verdict.info.label, "Gear Judge's verdict on the item up for a roll")
    eq(all.info.label, "Gear Judge's verdict on every item up for a roll")
    eq(verdict.activated, 1)
    eq(all.activated, 1)
    eq(w.applied, 1)
    w.rolls = { { link = RING }, { link = BLADE } }
    w.scores[RING] = score(4.2, OLD)
    w.scores[BLADE] = score(-1, nil)
    verdict.info.func()
    eq(w.spoken[#w.spoken], "Lion Ring, upgrade of 4.2 percent, instead of Old Ring")
    all.info.func()
    contains(w.spoken[#w.spoken], "Item 2 of 2, Raid Blade")
end)

test("the keys: named in the player's language", function()
    local w = newWorld({ input = true, locale = "frFR" })
    eq(w.bindings["rolljudge/verdict"].info.label, "Avis de Gear Judge sur l'objet proposé au jet")
    eq(w.bindings["rolljudge/all"].info.label, "Avis de Gear Judge sur tous les objets proposés au jet")
    local de = newWorld({ input = true, locale = "deDE" })
    eq(de.bindings["rolljudge/verdict"].info.label, "Urteil von Gear Judge zum Gegenstand, um den gewürfelt wird")
end)

test("the keys: a binding that is already there is not made twice", function()
    local w = newWorld({ input = true })
    eq(#w.created, 2)
    w.ns.installBindings()
    eq(#w.created, 2)
end)

test("the keys: without WowVision's input nothing is installed and nothing breaks", function()
    local w = newWorld()
    eq(w.ns.installed, false)
    eq(w.ns.installBindings(), false)
    eq(#w.errors, 0)
end)

test("the keys: an error in a key is reported once and does not stop the next press", function()
    local w = newWorld({ input = true })
    w.Game.rolls = function()
        error("rolls failed")
    end
    local func = w.bindings["rolljudge/verdict"].info.func
    func()
    func()
    eq(#w.errors, 1)
    contains(w.errors[1], "rolls failed")
end)

test("the keys: an error while installing is reported and the addon says it is not installed", function()
    local w = newWorld({ input = true })
    WowVision.input.createBinding = function()
        error("no input manager today")
    end
    WowVision.input.getBinding = function()
        return nil
    end
    local ns = {}
    for _, name in ipairs({ "Locale", "Judge", "Main" }) do
        assert(loadfile(addonDir .. "/" .. name .. ".lua"))("WowVision_RollJudge", ns)
    end
    eq(ns.installed, false)
    eq(#w.errors, 1)
    contains(w.errors[1], "no input manager today")
end)

test("/wvjuge, /wvjudge and /wvurteil do what the key does; all says every item; help says what it is", function()
    local w = newWorld({ input = true })
    eq(SLASH_WVROLLJUDGE1, "/wvjuge")
    eq(SLASH_WVROLLJUDGE2, "/wvjudge")
    eq(SLASH_WVROLLJUDGE3, "/wvurteil")
    local command = SlashCmdList["WVROLLJUDGE"]
    w.rolls = { { link = RING }, { link = BLADE } }
    w.scores[RING] = score(4.2, OLD)
    w.scores[BLADE] = score(-1, nil)
    command("")
    eq(w.spoken[#w.spoken], "Lion Ring, upgrade of 4.2 percent, instead of Old Ring")
    command(nil)
    eq(w.spoken[#w.spoken], "Lion Ring, upgrade of 4.2 percent, instead of Old Ring")
    for _, word in ipairs({ "all", "ALL", "tout", "tous", "alle", "  all  ", "all please" }) do
        command(word)
        contains(w.spoken[#w.spoken], "Item 2 of 2", word)
    end
    for _, word in ipairs({ "help", "aide", "hilfe", "HELP" }) do
        command(word)
        contains(w.spoken[#w.spoken], "Roll judge:", word)
    end
    command("something else")
    eq(w.spoken[#w.spoken], "Lion Ring, upgrade of 4.2 percent, instead of Old Ring")
end)

test("the command: an error is reported once", function()
    local w = newWorld({ input = true })
    w.Game.rolls = function()
        error("rolls failed")
    end
    SlashCmdList["WVROLLJUDGE"]("")
    SlashCmdList["WVROLLJUDGE"]("")
    eq(#w.errors, 1)
end)

-- ---------------------------------------------------------------- languages

test("French: the sentence, with a decimal comma", function()
    local w = newWorld({ locale = "frFR" })
    w.scores[RING] = score(4.2, OLD)
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, amélioration de 4,2 pour cent, à la place de Old Ring")
    w.scores[RING] = score(-3.1, nil)
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, régression de 3,1 pour cent, emplacement vide")
    w.scores[RING] = score(0, OLD)
    contains(w.ns.Judge.line(w.Game, { link = RING }), "aucun changement")
    w.scores[RING] = score(1, OLD, { equipped = true })
    contains(w.ns.Judge.line(w.Game, { link = RING }), "vous le portez déjà")
    w.rolls = {}
    w.ns.sayVerdict()
    eq(w.spoken[1], "Pas de butin.")
end)

test("German: the sentence, with a decimal comma", function()
    local w = newWorld({ locale = "deDE" })
    w.scores[RING] = score(4.2, OLD)
    eq(w.ns.Judge.line(w.Game, { link = RING }), "Lion Ring, Verbesserung um 4,2 Prozent, statt Old Ring")
    w.scores[RING] = score(-3.1, OLD)
    contains(w.ns.Judge.line(w.Game, { link = RING }), "Verschlechterung um 3,1 Prozent")
end)

test("every spoken string has a French and a German wording", function()
    local w = newWorld()
    local sources = {}
    for _, file in ipairs({ "Judge", "Main" }) do
        local f = assert(io.open(addonDir .. "/" .. file .. ".lua", "rb"))
        sources[#sources + 1] = f:read("a")
        f:close()
    end
    local text = table.concat(sources, "\n")
    local keys = {}
    for key in text:gmatch('L%["(.-)"%]') do
        keys[key] = true
    end
    for key in text:gmatch('label = "([^"]+)"') do
        keys[key] = true
    end
    local count, missing = 0, {}
    for key in pairs(keys) do
        count = count + 1
        for _, locale in ipairs({ "frFR", "deDE" }) do
            if w.ns.translations[locale][key] == nil then
                missing[#missing + 1] = locale .. ": " .. key
            end
        end
    end
    check(count > 15, "the strings were read (" .. count .. ")")
    eq(#missing, 0, "untranslated: " .. table.concat(missing, "; "))
end)

test("every translation is used by the addon", function()
    local w = newWorld()
    local sources = {}
    for _, file in ipairs({ "Judge", "Main" }) do
        local f = assert(io.open(addonDir .. "/" .. file .. ".lua", "rb"))
        sources[#sources + 1] = f:read("a")
        f:close()
    end
    local text = table.concat(sources, "\n")
    local unused = {}
    for key in pairs(w.ns.translations.frFR) do
        if not text:find(key, 1, true) then
            unused[#unused + 1] = key
        end
    end
    eq(#unused, 0, "unused: " .. table.concat(unused, "; "))
    for key in pairs(w.ns.translations.frFR) do
        check(w.ns.translations.deDE[key] ~= nil, "no German for " .. key)
    end
    for key in pairs(w.ns.translations.deDE) do
        check(w.ns.translations.frFR[key] ~= nil, "no French for " .. key)
    end
end)

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
