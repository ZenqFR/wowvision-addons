-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1 or newer). The game and Life on Azeroth
-- Market's data are stand-ins (real files are never read); WowVision's REAL graph framework (Builder, KeyGraph, node
-- factories, loaded by tests/graph_env.lua from the WowVision folder, or WOWVISION_DIR) builds and walks the stop, so
-- the tab order and what is spoken come from WowVision's own code. tests/real_bags.lua goes further and runs
-- WowVision's real bags screen. This addon's files are loaded for real, in the order of the .toc.
local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local wowVisionDir = os.getenv("WOWVISION_DIR") or (addonDir .. "/../WowVision")

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

local function lacks(text, part, label)
    if text ~= nil and tostring(text):find(part, 1, true) then
        error((label or "text differs") .. ": expected it NOT to contain '" .. part .. "', got " .. tostring(text), 2)
    end
end

tinsert = table.insert
tremove = table.remove
unpack = unpack or table.unpack

local env = dofile(testsDir .. "/graph_env.lua")(wowVisionDir)
local graph = env.graph
local nodes = graph.nodes

-- ------------------------------------------------------------------- world

local NOW = 1795140000 -- 2026-11-20 02:00:00 UTC
local FILES = { "Locale", "Game", "Market", "Hints", "Screen", "Main" }

-- Life on Azeroth Market's lines: "itemID,typical,cheapest,listed,auctions,change24h", prices per item in copper.
local PRICES = table.concat({
    "35,5000,4000,10,10,",
    "135,3000,2500,10,10,",
    "1000,330,300,5,5,12.5", -- 10 percent above a vendor price of 300: exactly at the threshold
    "1001,329,300,5,5,", -- one copper short of 10 percent
    "1002,1000,900,4,4,",
    "1003,4000,3500,4,4,",
    "1004,2000,1800,4,4,",
    "1005,2500,2000,4,4,",
    "1006,3300,3000,4,4,",
    "1007,8000,7000,4,4,",
    "1008,9000,8000,4,4,",
    "1009,6000,5000,4,4,",
    "1010,500,400,4,4,",
    "1011,11,",
    "1012,0,0,0,0,",
    "1014,332,300,4,4,", -- 10.67 percent above a vendor price of 300
    "1015,600,500,4,4,",
    "1016,700,600,4,4,",
    "1017,800,700,4,4,",
    "1020,348,300,4,4,", -- after a cut of 5 percent: 330.6, just over 10 percent above a vendor price of 300
    "1021,347,300,4,4,", -- after a cut of 5 percent: 329.65, just under
}, "\n")

local function marketData(extra)
    local data = {
        v = 5,
        built = NOW - 3 * 3600, -- 2026-11-19 23:00 UTC
        latest = NOW - 3 * 3600 - 600,
        region = "eu",
        houses = {
            ["1H"] = { latS = PRICES },
            ["1A"] = { latS = "1000,9999999,1,1,1,\n" },
        },
    }
    for key, value in pairs(extra or {}) do
        data[key] = value
    end
    return data
end

-- items the stand-in game knows: sell price per item, bind type (0 none, 1 when picked up, 2 when equipped, 3 when
-- used, 4 quest)
local ITEMS = {
    [1000] = { name = "Moonwell Herb", sell = 300, bind = 0 },
    [1001] = { name = "Almost Herb", sell = 300, bind = 0 },
    [1002] = { name = "Silver Ring", sell = 500, bind = 2 },
    [1003] = { name = "Bound Blade", sell = 1000, bind = 1 },
    [1004] = { name = "Quest Letter", sell = 100, bind = 4 },
    [1005] = { name = "Heirloom", sell = 100, bind = 7 },
    [1006] = { name = "Used Potion", sell = 1000, bind = 3 },
    [1007] = { name = "Worn Cloak", sell = 2000, bind = 2 },
    [1008] = { name = "Priceless Thing", sell = 0, bind = 0 },
    [1009] = { name = "Account Cape", sell = 1000, bind = 2, accountUntilEquip = true },
    [1010] = { name = "Cheap Dust", sell = 100, bind = 0 },
    [1011] = { name = "Cheap Cloth", sell = 5, bind = 0 },
    [1012] = { name = "Unlisted Junk", sell = 10, bind = 0 },
    [1013] = { name = "Nobody Wants It", sell = 10, bind = 0 }, -- no price in the data at all
    [1014] = { name = "Rounding Herb", sell = 300, bind = 0 },
    [1015] = { name = "Twin Dust", sell = 100, bind = 0 }, -- the same gain per item as the Silver Ring
    [1016] = { name = "Odd Trinket", sell = 0, bind = 0 }, -- no vendor buys it
    [1017] = { name = "Bound Trinket", sell = 0, bind = 1 }, -- no vendor buys it, and it is bound
    [1019] = { name = "Penny Cloth", sell = 1, bind = 1 }, -- a vendor pays one copper: that is a price
    [1020] = { name = "Net Herb", sell = 300, bind = 0 },
    [1021] = { name = "Short Herb", sell = 300, bind = 0 },
    [35] = { name = "Linen Cloth", sell = 200, bind = 0, quality = 1 },
    [135] = { name = "Wool Cloth", sell = 100, bind = 0, quality = 1 },
}

local function link(id)
    return "|cffffffff|Hitem:" .. id .. "::::::::20|h[" .. ITEMS[id].name .. "]|h|r"
end

local function idOf(linkOrID)
    if type(linkOrID) == "number" then
        return linkOrID
    end
    return tonumber(tostring(linkOrID):match("item:(%d+)"))
end

local function newButton(bag, slot)
    local button = { bag = bag, slot = slot, shown = true }
    function button:IsShown()
        return self.shown
    end
    function button:GetBagID()
        return self.bag
    end
    function button:GetID()
        return self.slot
    end
    function button:IsEnabled()
        return true
    end
    function button:HasScript()
        return false
    end
    return button
end

-- A fresh world: the game's functions, the market's data, WowVision's bags module and window, then the addon.
-- config: locale, data (false for none), settings, realm, faction, noWindow, noComponent, bank, frames
local function newWorld(config)
    config = config or {}
    local w = {
        bank = config.bank,
        errors = {},
        combat = false,
        now = NOW,
        slots = {}, -- [bag][slot] = spec
        uncached = {},
        frames = {},
        calls = {},
    }
    geterrorhandler = function()
        return function(err)
            w.errors[#w.errors + 1] = tostring(err)
        end
    end
    GetLocale = function()
        return config.locale or "enUS"
    end
    InCombatLockdown = function()
        return w.combat
    end
    time = function()
        return w.now
    end
    date = function(format, moment)
        return os.date("!" .. format, moment)
    end
    GetRealmName = function()
        return config.realm or "Testrealm"
    end
    UnitFactionGroup = function()
        return config.faction or "Horde"
    end
    NUM_BAG_SLOTS = 4
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
    C_CurrencyInfo = nil
    C_Container = {
        GetContainerNumSlots = function(bag)
            local size = w.size and w.size[bag]
            if size ~= nil then
                return size
            end
            return bag <= 1 and 8 or 0
        end,
        GetContainerItemInfo = function(bag, slot)
            local spec = w.slots[bag] and w.slots[bag][slot]
            if spec == nil then
                return nil
            end
            local item = ITEMS[spec.id]
            return {
                itemID = spec.id,
                stackCount = spec.count or 1,
                isBound = spec.boundUnknown and "maybe" or spec.bound,
                hyperlink = link(spec.id),
                itemName = item.name,
                quality = item.quality or 1,
                hasNoValue = spec.hasNoValue or item.sell == 0,
            }
        end,
        GetContainerItemDurability = function(bag, slot)
            local spec = w.slots[bag] and w.slots[bag][slot]
            if spec ~= nil and spec.durability ~= nil then
                return spec.durability[1], spec.durability[2]
            end
            return nil, nil
        end,
    }
    C_Item = {
        GetItemInfo = function(linkOrID)
            local id = idOf(linkOrID)
            local item = ITEMS[id]
            if item == nil or w.uncached[id] then
                return nil
            end
            return item.name, link(id), item.quality or 1, 20, 0, "", "", 20, "", 1, item.sell, 0, 0, item.bind
        end,
        IsBound = function(where)
            local spec = w.slots[where.bag] and w.slots[where.bag][where.slot]
            return spec ~= nil and spec.locationBound == true
        end,
        IsItemBindToAccountUntilEquip = function(id)
            return ITEMS[id] ~= nil and ITEMS[id].accountUntilEquip == true
        end,
    }
    ItemLocation = {
        CreateFromBagAndSlot = function(_, bag, slot)
            return { bag = bag, slot = slot }
        end,
    }
    if config.data ~= false then
        LOA_DATA = config.data or marketData()
    else
        LOA_DATA = nil
    end
    LifeOnAzeroth_MarketDB = config.settings
    SlashCmdList = {}
    if config.freshSettings then
        WowVisionAuctionHintsDB = nil
    else
        WowVisionAuctionHintsDB = { fees = config.fees == true }
    end
    ContainerFrameUtil_EnumerateContainerFrames = function()
        local index = 0
        return function()
            index = index + 1
            local frame = w.frames[index]
            if frame ~= nil then
                return index, frame
            end
        end
    end

    -- WowVision's bags module: only what this addon calls; the item node is the real proxy button.
    local containers = {}
    function containers.slotLocation(button)
        return button:GetBagID(), button:GetID()
    end
    function containers.itemSlotNode(button, label, clickLabels, isEmpty)
        local vtable = nodes.proxyButton({ target = button, label = label, clickLabels = clickLabels })
        if vtable == nil then
            return nil
        end
        vtable.announcements[1].live = "focus"
        vtable.isEmpty = isEmpty
        return vtable
    end
    function containers.itemClickLabels()
        return {}
    end
    function containers.slotIsEmpty()
        return function()
            return false
        end
    end
    function containers.getBagItemLabel(button)
        return "bag label " .. button:GetBagID() .. "." .. button:GetID()
    end
    w.containers = containers

    -- The window's render, as WowVision 1.0.4 draws it: the controls and the search box first, then the bags grid
    -- and the bag slots bar, then the bank when it is open.
    local function render(builder)
        builder:pushContext("bags", "Bags")
        builder:beginStop("frame:combined:controls")
        builder:addItem(graph.ControlId.structural("controls"), nodes.text({ label = "Sort Bags" }))
        builder:beginStop("frame:combined:search")
        builder:addItem(graph.ControlId.structural("search"), nodes.text({ label = "Search" }))
        builder:beginStop("frame:combined:grid")
        for _, frame in ipairs(w.frames) do
            for _, button in ipairs(frame.Items) do
                builder:addItem(graph.ControlId.structural("grid:" .. button.bag .. ":" .. button.slot), containers.itemSlotNode(button, function()
                    return containers.getBagItemLabel(button)
                end))
            end
        end
        builder:beginStop("frame:combined:bagSlots")
        builder:addItem(graph.ControlId.structural("bagSlots"), nodes.text({ label = "Bag slot" }))
        if w.bank then
            builder:beginStop("bank:tab")
            builder:addItem(graph.ControlId.structural("bank"), nodes.text({ label = "Bank" }))
        end
        builder:popContext()
    end
    w.originalRender = render
    w.window = { name = "bags", graphScreen = { render = render, background = true } }
    containers.registeredWindows = { bags = w.window }

    -- the carried bags as a component type with its own renderGraph
    w.Bags = {
        renderGraph = function(_, builder)
            w.calls[#w.calls + 1] = "component"
            builder:beginStop("component:grid")
            builder:addItem(graph.ControlId.structural("component"), nodes.text({ label = "Component" }))
        end,
        isOpen = function()
            return true
        end,
    }

    WowVision.base = { windows = { containers = containers } }
    WowVision.components = {
        registries = {
            get = function()
                if config.noComponent then
                    return nil
                end
                return {
                    types = {
                        get = function(_, name)
                            if name == "RetailBags" then
                                return w.Bags
                            end
                            return nil
                        end,
                    },
                }
            end,
        },
    }
    WowVision.items = nil
    WowVision.isSecret = nil
    env.spoken = {}
    WowVision.speak = function(_, text)
        tinsert(env.spoken, text)
    end
    if config.noWindow then
        containers.registeredWindows = nil
    end

    -- the addon
    local ns = {}
    for _, name in ipairs(FILES) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_AuctionHints", ns)
    end
    w.ns = ns
    if config.locale ~= nil then
        ns.useLocale(config.locale)
    end

    -- helpers for the tests
    function w:put(bag, slot, id, fields)
        self.slots[bag] = self.slots[bag] or {}
        local spec = { id = id, count = 1, bound = false }
        for key, value in pairs(fields or {}) do
            spec[key] = value
        end
        self.slots[bag][slot] = spec
        return spec
    end
    -- one shown bag frame holding a button for every slot of the backpack and the first bag
    function w:openBags()
        local frame = { Items = {}, shown = true }
        function frame:IsShown()
            return self.shown
        end
        for bag = 0, 1 do
            for slot = 1, 8 do
                tinsert(frame.Items, newButton(bag, slot))
            end
        end
        self.frames = { frame }
        return frame
    end
    function w:driver()
        return env.driver(self.window.graphScreen.render)
    end
    -- every node of the screen: { stop, text }
    function w:walk()
        local d = self:driver()
        local out = {}
        for _, node in ipairs(d.nodes()) do
            out[#out + 1] = { stop = node.stopKey, text = d.say(node), node = node }
        end
        return out, d
    end
    return w
end

local function lines(rows, stop)
    local out = {}
    for _, row in ipairs(rows) do
        if stop == nil or row.stop == stop then
            out[#out + 1] = row.text
        end
    end
    return out
end

local function stopsOf(d)
    return table.concat(d.kg:_stopOrder(), ",")
end

local function say(w)
    local text = w.ns.Hints.summaryText(w.ns.Hints.compute(w.ns.Hints.allPositions()), w.now)
    return text
end

test("toc: the .toc lists the files the tests load, in the same order", function()
    local file = assert(io.open(addonDir .. "/WowVision_AuctionHints.toc", "rb"))
    local listed = {}
    for line in file:read("a"):gmatch("[^\r\n]+") do
        local name = line:match("^([%w_]+)%.lua$")
        if name ~= nil then
            listed[#listed + 1] = name
        end
    end
    file:close()
    eq(table.concat(listed, ","), table.concat(FILES, ","))
end)

-- ================================================================== locale

test("locale: every sentence the addon says has a French and a German version, with the same places", function()
    local w = newWorld()
    local keys = {}
    for _, name in ipairs(FILES) do
        local file = assert(io.open(addonDir .. "/" .. name .. ".lua", "rb"))
        local source = file:read("a")
        file:close()
        for key in source:gmatch('L%["(.-)"%]') do
            if not key:find('" ..', 1, true) then
                keys[key] = true
            end
        end
    end
    -- the ones built from pieces
    for _, unit in ipairs({ "minute", "hour", "day" }) do
        keys["{count} " .. unit .. " ago"] = true
        keys["{count} " .. unit .. "s ago"] = true
    end
    for _, month in ipairs({ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }) do
        keys[month] = true
    end
    local missing = {}
    for key in pairs(keys) do
        for _, locale in ipairs({ "frFR", "deDE" }) do
            local value = w.ns.TRANSLATIONS[locale][key]
            if value == nil then
                missing[#missing + 1] = locale .. ": " .. key
            elseif key:find("{", 1, true) then
                for place in key:gmatch("{(%w+)}") do
                    if not value:find("{" .. place .. "}", 1, true) then
                        missing[#missing + 1] = locale .. " lacks {" .. place .. "}: " .. key
                    end
                end
            end
        end
    end
    table.sort(missing)
    eq(#missing, 0, "untranslated: " .. table.concat(missing, " | "))
    -- and nothing translated that is not said: the key is written, quoted, in one of the files
    local sources = {}
    for _, name in ipairs(FILES) do
        if name ~= "Locale" then
            local file = assert(io.open(addonDir .. "/" .. name .. ".lua", "rb"))
            sources[#sources + 1] = file:read("a")
            file:close()
        end
    end
    local all = table.concat(sources, "\n")
    for _, locale in ipairs({ "frFR", "deDE" }) do
        for key in pairs(w.ns.TRANSLATIONS[locale]) do
            local said = keys[key] or all:find('"' .. key .. '"', 1, true)
            check(said, locale .. " has a sentence nothing says: " .. key)
        end
    end
end)

test("locale: fill replaces named places and leaves unknown ones", function()
    local w = newWorld()
    eq(w.ns.fill("{a} and {b} and {a}", { a = 1, b = "x" }), "1 and x and 1")
    eq(w.ns.fill("{a} {zzz}", { a = 1 }), "1 {zzz}")
end)

test("locale: English reads as the keys, an unknown language too", function()
    local w = newWorld({ locale = "enUS" })
    eq(w.ns.L["For sale at the auction house"], "For sale at the auction house")
    w.ns.useLocale("koKR")
    eq(w.ns.L["For sale at the auction house"], "For sale at the auction house")
    w.ns.useLocale("frFR")
    eq(w.ns.L["For sale at the auction house"], "À vendre à l'hôtel des ventes")
    w.ns.useLocale("deDE")
    eq(w.ns.L["For sale at the auction house"], "Zum Verkauf im Auktionshaus")
end)

-- =================================================================== market

test("market: the house is the player's own: realm kind and faction", function()
    local cases = {
        { "Testrealm", "Horde", "1H" },
        { "Testrealm", "Alliance", "1A" },
        { "Some-PvP-Realm", "Horde", "0H" },
        { "Realm RP", "Alliance", "2A" },
        { "Realm Roleplay", "Alliance", "2A" },
        { "RPPvP Land", "Horde", "3H" },
        { "Realm rp-pvp", "Horde", "3H" },
        { "Realm RP PvP", "Alliance", "3A" },
    }
    for _, case in ipairs(cases) do
        local w = newWorld({ realm = case[1], faction = case[2] })
        eq(w.ns.Market.ownHouse(), case[3], case[1] .. " " .. case[2])
    end
    local w = newWorld({ faction = "Neutral" })
    eq(w.ns.Market.ownHouse(), nil, "a pandaren before choosing")
    w = newWorld({ realm = "" })
    eq(w.ns.Market.ownHouse(), nil, "no realm name")
end)

test("market: house names as Market writes them", function()
    local w = newWorld()
    eq(w.ns.Market.houseName("1H"), "Normal Horde")
    eq(w.ns.Market.houseName("0A"), "PvP Alliance")
    eq(w.ns.Market.houseName("3B"), "Roleplay PvP Blackwater")
    eq(w.ns.Market.houseName("9Z"), "? ?")
    eq(w.ns.Market.houseName(nil), nil)
end)

test("market: own house first, then Market's pick, then the first it has", function()
    local data = marketData({ houses = { ["1H"] = { latS = "1,1,1,1,1,\n" }, ["0A"] = { latS = "1,2,1,1,1,\n" }, ["2H"] = { latS = "1,3,1,1,1,\n" } } })
    local w = newWorld({ data = data })
    local key, own = w.ns.Market.chooseHouse(data)
    eq(key, "1H")
    eq(own, true)
    -- own house missing: Market's saved pick
    w = newWorld({ data = data, faction = "Alliance", settings = { house = "2H" } })
    key, own = w.ns.Market.chooseHouse(data)
    eq(key, "2H")
    eq(own, false)
    -- pick "auto" or unknown: the first house in Market's order
    w = newWorld({ data = data, faction = "Alliance", settings = { house = "auto" } })
    eq((w.ns.Market.chooseHouse(data)), "0A")
    w = newWorld({ data = data, faction = "Alliance", settings = { house = "3A" } })
    eq((w.ns.Market.chooseHouse(data)), "0A")
    w = newWorld({ data = data, faction = "Alliance" })
    eq((w.ns.Market.chooseHouse(data)), "0A")
    -- no houses at all
    eq((w.ns.Market.chooseHouse({})), nil)
    -- Market's order when it has to take the first: PvP before Normal, Alliance before Horde
    local both = { houses = { ["1A"] = {}, ["0A"] = {}, ["0H"] = {} } }
    w = newWorld({ faction = "Neutral" })
    eq((w.ns.Market.chooseHouse(both)), "0A")
    both = { houses = { ["1H"] = {}, ["1A"] = {} } }
    eq((w.ns.Market.chooseHouse(both)), "1A")
    both = { houses = { ["3H"] = {}, ["2H"] = {}, ["3A"] = {} } }
    eq((w.ns.Market.chooseHouse(both)), "2H")
end)

test("market: prices from the text of the lines, even for ids that are the end of other ids", function()
    local w = newWorld()
    local snapshot = w.ns.Market.snapshot()
    eq(snapshot.price(35), 5000)
    eq(snapshot.price(135), 3000)
    eq(snapshot.price(5), nil, "5 is the end of 35 and 135")
    eq(snapshot.price(1000), 330)
    eq(snapshot.price(1011), 11, "a line with the typical price only")
    eq(snapshot.price(1012), nil, "a typical price of 0 is no price")
    eq(snapshot.price(99999), nil)
    eq(snapshot.house, "1H")
    eq(snapshot.houseName, "Normal Horde")
    eq(snapshot.own, true)
    eq(snapshot.built, NOW - 3 * 3600)
end)

test("market: prices from the table Market has parsed already", function()
    local data = marketData({ houses = { ["1H"] = { lat = { [35] = { 777, 1, 1, 1 }, [36] = { 0, 0 }, [37] = {} } } } })
    local w = newWorld({ data = data })
    local snapshot = w.ns.Market.snapshot()
    eq(snapshot.price(35), 777)
    eq(snapshot.price(36), nil, "typical 0")
    eq(snapshot.price(37), nil, "no typical price")
    eq(snapshot.price(38), nil)
end)

test("market: the data is not changed (Market parses it itself later)", function()
    local data = marketData()
    local text = data.houses["1H"].latS
    local w = newWorld({ data = data })
    w.ns.Market.snapshot().price(35)
    eq(data.houses["1H"].latS, text)
    eq(data.houses["1H"].lat, nil)
    eq(data.ready, nil)
end)

test("market: no houses, the region's prices", function()
    local data = { built = NOW - 60, region = "eu", latS = { eu = "35,111,1,1,1,\n", us = "35,222,1,1,1,\n" } }
    local w = newWorld({ data = data })
    local snapshot = w.ns.Market.snapshot()
    eq(snapshot.price(35), 111)
    eq(snapshot.house, nil)
    eq(snapshot.own, false)
    data = { built = NOW - 60, region = "eu", lat = { eu = { [35] = { 333 } } } }
    w = newWorld({ data = data, locale = "enUS" })
    eq(w.ns.Market.snapshot().price(35), 333)
    lacks(say(w), "another auction house", "no house, nothing to say about it")
end)

test("market: no data, or data without prices", function()
    local w = newWorld({ data = false })
    local snapshot, problem = w.ns.Market.snapshot()
    eq(snapshot, nil)
    eq(problem, "nomarket")
    w = newWorld({ data = { built = NOW, region = "eu", houses = { ["1H"] = {} } } })
    snapshot, problem = w.ns.Market.snapshot()
    eq(snapshot, nil)
    eq(problem, "noprices")
    w = newWorld({ data = { built = NOW, region = "eu" } })
    snapshot, problem = w.ns.Market.snapshot()
    eq(problem, "noprices")
end)

test("market: compute passes the reason on", function()
    local w = newWorld({ data = false })
    eq(w.ns.Hints.compute({}).problem, "nomarket")
    w = newWorld({ data = { built = NOW, region = "eu", houses = { ["1H"] = {} } } })
    eq(w.ns.Hints.compute({}).problem, "noprices")
    w = newWorld()
    eq(w.ns.Hints.compute({}).problem, nil)
end)

test("market: the date is when the file was built, else the last snapshot", function()
    local data = marketData()
    local w = newWorld({ data = data })
    eq(w.ns.Market.snapshot().built, NOW - 3 * 3600)
    data.built = nil
    eq(w.ns.Market.snapshot().built, NOW - 3 * 3600 - 600)
    data.latest = nil
    eq(w.ns.Market.snapshot().built, nil)
end)

-- ==================================================================== rules

-- The slot's result when it is for the auction house; else nil, why (the reason it is not placed, or the reason it is
-- not for the auction house) and its whole classification.
local function evaluate(w, bag, slot)
    local snapshot = w.ns.Market.snapshot()
    local result, reason = w.ns.Hints.classify(bag, slot, snapshot)
    if result == nil then
        return nil, reason
    end
    if result.kind == "auction" then
        return result
    end
    return nil, result.why, result
end

test("rules: an unbound item at least 10 percent above the vendor is listed, with its numbers", function()
    local w = newWorld()
    w:put(0, 1, 35, { count = 20 })
    local entry = evaluate(w, 0, 1)
    check(entry, "listed")
    eq(entry.itemID, 35)
    eq(entry.count, 20)
    eq(entry.vendorUnit, 200)
    eq(entry.auctionUnit, 5000)
    eq(entry.gain, (5000 - 200) * 20)
    eq(entry.percent, 2400)
    eq(entry.name, "Linen Cloth")
end)

test("rules: exactly 10 percent is listed, one copper short is not", function()
    local w = newWorld()
    w:put(0, 1, 1000)
    w:put(0, 2, 1001)
    local entry = evaluate(w, 0, 1)
    check(entry, "330 against 300 is 10 percent")
    eq(entry.percent, 10)
    local none, reason = evaluate(w, 0, 2)
    eq(none, nil)
    eq(reason, "below")
end)

test("rules: below the threshold, or the same price, is not listed", function()
    local w = newWorld()
    w:put(0, 1, 1010, {}) -- 500 against 100: listed
    w:put(0, 2, 1002, {}) -- 1000 against 500: listed
    check(evaluate(w, 0, 1))
    check(evaluate(w, 0, 2))
    ITEMS[1010].sell = 500 -- 500 against 500
    local _, reason = evaluate(w, 0, 1)
    ITEMS[1010].sell = 100
    eq(reason, "below")
    ITEMS[1010].sell = 600 -- the auction house pays less than the vendor
    _, reason = evaluate(w, 0, 1)
    ITEMS[1010].sell = 100
    eq(reason, "below")
end)

test("rules: nothing bound is ever listed, whatever it is worth", function()
    local w = newWorld()
    w:put(0, 1, 35, { bound = true })
    w:put(0, 2, 35, { boundUnknown = true })
    w:put(0, 3, 35, { locationBound = true })
    w:put(0, 4, 1003) -- bound when picked up
    w:put(0, 5, 1004) -- quest item
    w:put(0, 6, 1005) -- bound to the account
    w:put(0, 7, 1009) -- bound to the account until worn
    for slot = 1, 7 do
        local entry, reason = evaluate(w, 0, slot)
        eq(entry, nil, "slot " .. slot)
        eq(reason, "bound", "slot " .. slot)
    end
end)

test("rules: the whole truth table of boundness: listed only when every check clears", function()
    local w = newWorld()
    local listedCount, total = 0, 0
    for _, flag in ipairs({ false, true, "maybe" }) do
        for _, location in ipairs({ false, true }) do
            for _, bind in ipairs({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, "none" }) do
                for _, account in ipairs({ false, true }) do
                    ITEMS[1010].bind = bind ~= "none" and bind or nil
                    ITEMS[1010].accountUntilEquip = account
                    w:put(0, 1, 1010, { locationBound = location, boundUnknown = flag == "maybe", bound = flag == true })
                    local entry, reason = evaluate(w, 0, 1)
                    local clear = flag == false and location == false and (bind == 0 or bind == 2 or bind == 3) and account == false
                    total = total + 1
                    if clear then
                        listedCount = listedCount + 1
                        check(entry ~= nil, "should be listed: flag " .. tostring(flag) .. " location " .. tostring(location) .. " bind " .. tostring(bind) .. " account " .. tostring(account))
                    else
                        eq(entry, nil, "must NOT be listed: flag " .. tostring(flag) .. " location " .. tostring(location) .. " bind " .. tostring(bind) .. " account " .. tostring(account))
                        eq(reason, "bound")
                    end
                end
            end
        end
    end
    ITEMS[1010].bind = 0
    ITEMS[1010].accountUntilEquip = nil
    eq(total, 132)
    eq(listedCount, 3, "none, when equipped, when used")
end)

test("rules: bound to the player when equipped, or when used, is fine while not bound yet", function()
    local w = newWorld()
    w:put(0, 1, 1002) -- bound when equipped, not bound yet
    w:put(0, 2, 1006) -- bound when used
    check(evaluate(w, 0, 1))
    check(evaluate(w, 0, 2))
    w:put(0, 1, 1002, { bound = true }) -- worn once, so bound now
    local entry, reason = evaluate(w, 0, 1)
    eq(entry, nil)
    eq(reason, "bound")
end)

test("rules: the bound checks that are not available do not stop an item the others clear", function()
    local w = newWorld()
    w:put(0, 1, 35)
    ItemLocation = nil
    check(evaluate(w, 0, 1), "no item location API")
    C_Item.IsBound = nil
    ItemLocation = { CreateFromBagAndSlot = function() return {} end }
    check(evaluate(w, 0, 1), "no IsBound")
    C_Item.IsItemBindToAccountUntilEquip = nil
    check(evaluate(w, 0, 1), "no account check")
    C_Container.GetContainerItemDurability = nil
    check(evaluate(w, 0, 1), "no durability")
end)

test("rules: a doubt about boundness leaves the item out", function()
    local w = newWorld()
    w:put(0, 1, 35)
    -- the game's flag is not a boolean (missing): bound
    local original = C_Container.GetContainerItemInfo
    C_Container.GetContainerItemInfo = function(bag, slot)
        local info = original(bag, slot)
        info.isBound = "maybe"
        return info
    end
    local entry, reason = evaluate(w, 0, 1)
    eq(entry, nil)
    eq(reason, "bound")
    C_Container.GetContainerItemInfo = original
    -- the bind type unknown
    ITEMS[35].bind = nil
    entry, reason = evaluate(w, 0, 1)
    ITEMS[35].bind = 0
    eq(entry, nil)
    eq(reason, "bound")
end)

test("rules: a damaged item is left out, a repaired or unbreakable one is not", function()
    local w = newWorld()
    w:put(0, 1, 1002, { durability = { 40, 50 } })
    w:put(0, 2, 1002, { durability = { 50, 50 } })
    w:put(0, 3, 1002)
    local entry, reason = evaluate(w, 0, 1)
    eq(entry, nil)
    eq(reason, "damaged")
    check(evaluate(w, 0, 2))
    check(evaluate(w, 0, 3))
end)

test("rules: no auction house price, no listing", function()
    local w = newWorld()
    w:put(0, 1, 1013)
    w:put(0, 2, 1012) -- a price of 0
    local entry, reason = evaluate(w, 0, 1)
    eq(entry, nil)
    eq(reason, "noprice")
    _, reason = evaluate(w, 0, 2)
    eq(reason, "noprice")
end)

test("rules: an item the vendor does not buy is listed with no percentage, once it has an auction price", function()
    local w = newWorld()
    w:put(0, 1, 1008)
    local entry = evaluate(w, 0, 1)
    check(entry, "listed")
    eq(entry.vendorUnit, 0)
    eq(entry.percent, nil)
    eq(entry.gain, 9000)
end)

test("rules: an item the game has not loaded is not judged, and is counted", function()
    local w = newWorld()
    w:put(0, 1, 35)
    w.uncached[35] = true
    local entry, reason = evaluate(w, 0, 1)
    eq(entry, nil)
    eq(reason, "pending")
    -- loaded, but with no sell price and no word that it has no value
    w.uncached[35] = nil
    ITEMS[35].sell = nil
    entry, reason = evaluate(w, 0, 1)
    ITEMS[35].sell = 200
    eq(entry, nil)
    eq(reason, "pending")
    -- not loaded, and the slot says it has no value: still not judged (bound or not cannot be told)
    w:put(0, 1, 35, { hasNoValue = true })
    w.uncached[35] = true
    entry, reason = evaluate(w, 0, 1)
    w.uncached[35] = nil
    eq(entry, nil)
    eq(reason, "pending")
    -- the slot says it has no value: the vendor pays nothing
    ITEMS[35].sell = nil
    w:put(0, 1, 35, { hasNoValue = true })
    entry = evaluate(w, 0, 1)
    ITEMS[35].sell = 200
    check(entry)
    eq(entry.vendorUnit, 0)
end)

test("rules: secrets are not read", function()
    local w = newWorld()
    w:put(0, 1, 35)
    local secret = {}
    issecretvalue = function(value)
        return value == secret
    end
    local original = C_Container.GetContainerItemInfo
    C_Container.GetContainerItemInfo = function(bag, slot)
        local info = original(bag, slot)
        info.stackCount = secret
        return info
    end
    local entry, reason = evaluate(w, 0, 1)
    C_Container.GetContainerItemInfo = original
    issecretvalue = nil
    eq(entry, nil)
    eq(reason, "unreadable")
    -- WowVision's own check is the one used when it has one
    WowVision.isSecret = function(value)
        return value == 1
    end
    entry, reason = evaluate(w, 0, 1)
    WowVision.isSecret = nil
    eq(reason, "unreadable", "the count 1 is a secret to WowVision")
end)

test("rules: secrets in the slot's other fields are not read either", function()
    local secret = {}
    local fields = { "isBound", "itemID", "hyperlink" }
    for _, field in ipairs(fields) do
        local w = newWorld()
        w:put(0, 1, 35)
        issecretvalue = function(value)
            return value == secret
        end
        local original = C_Container.GetContainerItemInfo
        C_Container.GetContainerItemInfo = function(bag, slot)
            local info = original(bag, slot)
            info[field] = secret
            return info
        end
        local entry, reason = evaluate(w, 0, 1)
        C_Container.GetContainerItemInfo = original
        issecretvalue = nil
        eq(entry, nil, field)
        eq(reason, "unreadable", field)
    end
    -- a secret sell price is no price: pending; a secret durability is no durability
    local w = newWorld()
    w:put(0, 1, 35)
    issecretvalue = function(value)
        return value == secret
    end
    local items = C_Item.GetItemInfo
    C_Item.GetItemInfo = function(...)
        local a, b, c, d, e, f, g, h, i, j, _, m, n, o = items(...)
        return a, b, c, d, e, f, g, h, i, j, secret, m, n, o
    end
    local entry, reason = evaluate(w, 0, 1)
    eq(entry, nil)
    eq(reason, "pending")
    C_Item.GetItemInfo = items
    C_Container.GetContainerItemDurability = function()
        return secret, secret
    end
    check(evaluate(w, 0, 1), "a secret durability does not stop a listing")
    issecretvalue = nil
end)

test("rules: an item location the game cannot make does not stop a listing", function()
    local w = newWorld()
    w:put(0, 1, 35)
    ItemLocation.CreateFromBagAndSlot = function()
        error("no location")
    end
    check(evaluate(w, 0, 1), "raises")
    ItemLocation.CreateFromBagAndSlot = function()
        return nil
    end
    check(evaluate(w, 0, 1), "nothing")
    C_Item.IsBound = function()
        error("no")
    end
    ItemLocation.CreateFromBagAndSlot = function()
        return {}
    end
    check(evaluate(w, 0, 1), "IsBound raises")
    C_Item.IsItemBindToAccountUntilEquip = function()
        error("no")
    end
    check(evaluate(w, 0, 1), "the account check raises")
end)

test("rules: empty slots are not counted; the counts say why items are out", function()
    local w = newWorld()
    w:put(0, 1, 35, { count = 5 }) -- listed
    w:put(0, 2, 1010) -- listed
    w:put(0, 3, 1001) -- below
    w:put(0, 4, 1003) -- bound
    w:put(0, 5, 1013) -- no price
    w:put(0, 6, 1002, { durability = { 1, 2 } }) -- damaged
    w:put(1, 1, 135)
    w.uncached[135] = true -- pending
    local result = w.ns.Hints.compute(w.ns.Hints.allPositions())
    eq(#result.entries, 2)
    local counts = result.counts
    eq(counts.total, 7)
    eq(counts.below, 1)
    eq(counts.bound, 1)
    eq(counts.noprice, 1)
    eq(counts.damaged, 1)
    eq(counts.pending, 1)
    eq(counts.auction, 2)
    eq(counts.vendor, 4, "the ones a vendor buys that are not for the auction house")
    eq(counts.none, 0)
    eq(#result.merchantPositions, 4)
    eq(#result.auctionPositions, 2)
end)

test("rules: the biggest gain first; on a tie the first stack's bag, then slot", function()
    local w = newWorld()
    w:put(1, 1, 35) -- gain 4800
    w:put(0, 3, 135, { count = 5 }) -- gain 14500
    w:put(0, 6, 1002) -- gain 500
    w:put(0, 2, 1010, { count = 2 }) -- gain 800
    local function order(world)
        local names = {}
        for _, entry in ipairs(world.ns.Hints.compute(world.ns.Hints.allPositions()).entries) do
            names[#names + 1] = entry.itemID .. "@" .. entry.bag .. "." .. entry.slot
        end
        return table.concat(names, " ")
    end
    eq(order(w), "135@0.3 35@1.1 1010@0.2 1002@0.6")
    -- the same gain: by the first stack's slot, either way round
    w = newWorld()
    w:put(0, 2, 1015) -- gain 500
    w:put(0, 6, 1002) -- gain 500
    eq(order(w), "1015@0.2 1002@0.6")
    w = newWorld()
    w:put(0, 6, 1015)
    w:put(0, 2, 1002)
    eq(order(w), "1002@0.2 1015@0.6")
    -- and by bag before slot
    w = newWorld()
    w:put(1, 1, 1015)
    w:put(0, 8, 1002)
    eq(order(w), "1002@0.8 1015@1.1")
end)

test("rules: one line per item, however many stacks: the quantity and the prices add up", function()
    local w = newWorld({ locale = "enUS" })
    w:put(1, 2, 35, { count = 2 })
    w:put(0, 4, 35, { count = 7 })
    w:put(0, 1, 35, { count = 5 })
    w:put(0, 2, 1002)
    local result = w.ns.Hints.compute(w.ns.Hints.allPositions())
    eq(#result.entries, 2, "two items")
    local line = result.entries[1]
    eq(line.itemID, 35)
    eq(line.count, 14)
    eq(line.stacks, 3)
    eq(line.auctionTotal, 5000 * 14)
    eq(line.gain, (5000 - 200) * 14)
    eq(line.vendorUnit, 200)
    eq(line.auctionUnit, 5000)
    eq(line.percent, 2400)
    -- the line acts on the first stack: lowest bag, then lowest slot
    eq(line.bag, 0)
    eq(line.slot, 1)
    eq(#line.piles, 3)
    eq(line.piles[1].count, 5)
    eq(line.piles[2].count, 7)
    eq(line.piles[3].count, 2)
    eq(w.ns.Hints.entryText(line), "Linen Cloth, 14 in 3 stacks: vendor 2 Silver each, auction house 50 Silver each, 7 Gold in all, 2400 percent more, estimated gain 6 Gold 72 Silver")
    w.ns.useLocale("frFR")
    eq(w.ns.Hints.entryText(line), "Linen Cloth, 14 au total en 3 piles : marchand 2 Argent l'unité, hôtel des ventes 50 Argent l'unité, 7 Or en tout, plus 2400 pour cent, gain estimé 6 Or 72 Argent")
    w.ns.useLocale("deDE")
    eq(w.ns.Hints.entryText(line), "Linen Cloth, 14 insgesamt in 3 Stapeln: Händler 2 Silber pro Stück, Auktionshaus 50 Silber pro Stück, 7 Gold insgesamt, 2400 Prozent mehr, geschätzter Gewinn 6 Gold 72 Silber")
    -- the counts are of slots
    eq(result.counts.auction, 4)
    -- the summary counts items (lines) and adds their gains
    w.ns.useLocale("enUS")
    contains(w.ns.Hints.summaryText(result, NOW), "2 items sell for")
    contains(w.ns.Hints.summaryText(result, NOW), "Estimated gain 6 Gold 77 Silver,")
end)

test("rules: the first stack is the lowest bag and slot, whatever order the positions come in", function()
    local w = newWorld()
    w:put(1, 2, 35, { count = 2 })
    w:put(0, 4, 35, { count = 7 })
    w:put(0, 1, 35, { count = 5 })
    local result = w.ns.Hints.compute({ { bag = 1, slot = 2 }, { bag = 0, slot = 4 }, { bag = 0, slot = 1 } })
    local line = result.entries[1]
    eq(line.bag .. "." .. line.slot, "0.1")
    eq(line.piles[1].count, 5)
    eq(line.piles[2].count, 7)
    eq(line.piles[3].count, 2)
end)

test("rules: a bound or damaged stack of an item is not added to its line, a single stack is as before", function()
    local w = newWorld({ locale = "enUS" })
    w:put(0, 1, 35, { count = 4, bound = true }) -- never in the list
    w:put(0, 2, 35, { count = 10 })
    w:put(0, 3, 1002, { count = 3, durability = { 1, 2 } }) -- damaged: not in the list
    w:put(0, 4, 1002, { count = 1 })
    w:put(0, 5, 1010, { count = 6 })
    local result = w.ns.Hints.compute(w.ns.Hints.allPositions())
    eq(#result.entries, 3)
    local byItem = {}
    for _, line in ipairs(result.entries) do
        byItem[line.itemID] = line
    end
    eq(byItem[35].count, 10, "the bound stack of 4 is left out")
    eq(byItem[35].stacks, 1)
    eq(byItem[35].bag .. "." .. byItem[35].slot, "0.2", "the line is the unbound stack")
    eq(byItem[1002].count, 1, "the damaged stack of 3 is left out")
    eq(byItem[1002].stacks, 1)
    eq(w.ns.Hints.entryText(byItem[35]), "Linen Cloth, 10: vendor 2 Silver each, auction house 50 Silver each, 5 Gold in all, 2400 percent more, estimated gain 4 Gold 80 Silver")
    eq(w.ns.Hints.entryText(byItem[1002]), "Silver Ring: vendor 5 Silver, auction house 10 Silver, 100 percent more, estimated gain 5 Silver")
    eq(w.ns.Hints.entryText(byItem[1010]), "Cheap Dust, 6: vendor 1 Silver each, auction house 5 Silver each, 30 Silver in all, 400 percent more, estimated gain 24 Silver")
    -- the bound and the damaged stacks are for a merchant
    eq(#result.merchantPositions, 2)
    eq(result.counts.auction, 3)
    eq(result.counts.vendor, 2)
end)

test("rules: a game call that raises is an empty slot, never a listing", function()
    local w = newWorld()
    w:put(0, 1, 35)
    w:put(0, 2, 35)
    local original = C_Container.GetContainerItemInfo
    C_Container.GetContainerItemInfo = function(bag, slot)
        if slot == 1 then
            error("boom")
        end
        return original(bag, slot)
    end
    local result = w.ns.Hints.compute(w.ns.Hints.allPositions())
    C_Container.GetContainerItemInfo = original
    eq(#result.entries, 1)
    eq(result.counts.unreadable, 0, "a game call that raises is no slot at all (pcall in Game)")
    eq(result.counts.total, 1)
end)

test("rules: Hints.classify raising is reported once and the scan goes on", function()
    local w = newWorld()
    w:put(0, 1, 35)
    w:put(0, 2, 35)
    local classifyOriginal = w.ns.Hints.classify
    w.ns.Hints.classify = function(bag, slot, snapshot)
        if bag == 0 and slot == 1 then
            error("rule failure")
        end
        return classifyOriginal(bag, slot, snapshot)
    end
    local result = w.ns.Hints.compute(w.ns.Hints.allPositions())
    eq(#result.entries, 1)
    eq(result.counts.unreadable, 1)
    eq(#w.errors, 1)
    contains(w.errors[1], "rule failure")
    w.ns.Hints.compute(w.ns.Hints.allPositions())
    eq(#w.errors, 1, "reported once")
end)

-- =================================================================== words

test("words: how long ago", function()
    local w = newWorld({ locale = "enUS" })
    local ago = w.ns.Hints.agoText
    eq(ago(0), "just now")
    eq(ago(89), "just now")
    eq(ago(90), "2 minutes ago")
    eq(ago(300), "5 minutes ago")
    eq(ago(3569), "59 minutes ago")
    eq(ago(3570), "1 hour ago")
    eq(ago(3 * 3600), "3 hours ago")
    eq(ago(84599), "23 hours ago")
    eq(ago(84600), "1 day ago")
    eq(ago(86400 * 2), "2 days ago")
    w.ns.useLocale("frFR")
    eq(ago(90), "il y a 2 minutes")
    eq(ago(3570), "il y a 1 heure")
    eq(ago(86400), "il y a 1 jour")
    eq(ago(86400 * 3), "il y a 3 jours")
    eq(ago(10), "à l'instant")
    w.ns.useLocale("deDE")
    eq(ago(3 * 3600), "vor 3 Stunden")
    eq(ago(3570), "vor 1 Stunde")
    eq(ago(86400 * 2), "vor 2 Tagen")
    eq(ago(86400), "vor 1 Tag")
    eq(ago(120), "vor 2 Minuten")
end)

test("words: the date, in the three languages", function()
    local w = newWorld({ locale = "enUS" })
    -- 2026-11-19 23:05 UTC
    local moment = NOW - 3 * 3600 + 5 * 60
    eq(w.ns.Hints.dateText(moment), "November 19 at 23:05")
    w.ns.useLocale("frFR")
    eq(w.ns.Hints.dateText(moment), "19 novembre à 23 h 05")
    w.ns.useLocale("deDE")
    eq(w.ns.Hints.dateText(moment), "19. November um 23:05 Uhr")
    -- single-digit hour and day
    eq(w.ns.Hints.dateText(NOW + 10 * 86400 + 4 * 3600 + 13 * 60), "30. November um 6:13 Uhr")
end)

test("words: an entry, in English, French and German; one item and several", function()
    local w = newWorld({ locale = "enUS" })
    w:put(0, 1, 35, { count = 20 })
    w:put(0, 2, 1002)
    w:put(0, 3, 1008, { count = 4 })
    w:put(0, 4, 1016)
    local entries = w.ns.Hints.compute(w.ns.Hints.allPositions()).entries
    local byslot = {}
    for _, entry in ipairs(entries) do
        byslot[entry.slot] = entry
    end
    eq(w.ns.Hints.entryText(byslot[1]), "Linen Cloth, 20: vendor 2 Silver each, auction house 50 Silver each, 10 Gold in all, 2400 percent more, estimated gain 9 Gold 60 Silver")
    eq(w.ns.Hints.entryText(byslot[2]), "Silver Ring: vendor 5 Silver, auction house 10 Silver, 100 percent more, estimated gain 5 Silver")
    eq(w.ns.Hints.entryText(byslot[3]), "Priceless Thing, 4: the vendor does not buy it, auction house 90 Silver each, 3 Gold 60 Silver in all, estimated gain 3 Gold 60 Silver")
    eq(w.ns.Hints.entryText(byslot[4]), "Odd Trinket: the vendor does not buy it, auction house 7 Silver, estimated gain 7 Silver")
    w.ns.useLocale("frFR")
    eq(w.ns.Hints.entryText(byslot[1]), "Linen Cloth, 20 : marchand 2 Argent l'unité, hôtel des ventes 50 Argent l'unité, 10 Or en tout, plus 2400 pour cent, gain estimé 9 Or 60 Argent")
    eq(w.ns.Hints.entryText(byslot[2]), "Silver Ring : marchand 5 Argent, hôtel des ventes 10 Argent, plus 100 pour cent, gain estimé 5 Argent")
    eq(w.ns.Hints.entryText(byslot[3]), "Priceless Thing, 4 : le marchand ne le rachète pas, hôtel des ventes 90 Argent l'unité, 3 Or 60 Argent en tout, gain estimé 3 Or 60 Argent")
    eq(w.ns.Hints.entryText(byslot[4]), "Odd Trinket : le marchand ne le rachète pas, hôtel des ventes 7 Argent, gain estimé 7 Argent")
    w.ns.useLocale("deDE")
    eq(w.ns.Hints.entryText(byslot[1]), "Linen Cloth, 20: Händler 2 Silber pro Stück, Auktionshaus 50 Silber pro Stück, 10 Gold insgesamt, 2400 Prozent mehr, geschätzter Gewinn 9 Gold 60 Silber")
    eq(w.ns.Hints.entryText(byslot[3]), "Priceless Thing, 4: Der Händler kauft es nicht, Auktionshaus 90 Silber pro Stück, 3 Gold 60 Silber insgesamt, geschätzter Gewinn 3 Gold 60 Silber")
    eq(w.ns.Hints.entryText(byslot[4]), "Odd Trinket: Der Händler kauft es nicht, Auktionshaus 7 Silber, geschätzter Gewinn 7 Silber")
end)

test("words: percent is rounded to the nearest, a pair says its count", function()
    local w = newWorld({ locale = "enUS" })
    w:put(0, 1, 1014)
    w:put(0, 2, 1002, { count = 2 })
    local entries = w.ns.Hints.compute(w.ns.Hints.allPositions()).entries
    local byslot = {}
    for _, entry in ipairs(entries) do
        byslot[entry.slot] = entry
    end
    contains(w.ns.Hints.entryText(byslot[1]), "11 percent more", "10.67 is 11")
    contains(w.ns.Hints.entryText(byslot[2]), "Silver Ring, 2: vendor 5 Silver each")
end)

test("words: the quality of the item goes through WowVision's naming", function()
    local w = newWorld({ locale = "enUS" })
    w:put(0, 1, 35)
    local entries = w.ns.Hints.compute(w.ns.Hints.allPositions()).entries
    WowVision.items = {
        formatName = function(name, quality)
            return name .. ", quality " .. tostring(quality)
        end,
    }
    local text = w.ns.Hints.entryText(entries[1])
    WowVision.items = nil
    contains(text, "Linen Cloth, quality 1: vendor", "the quality the game gave Linen Cloth")
end)

test("words: the threshold said is the threshold used", function()
    local w = newWorld({ locale = "enUS" })
    w.ns.Hints.PERCENT = 25
    w:put(0, 1, 1010) -- 400 percent above
    w:put(0, 2, 1002) -- 100 percent above
    w:put(0, 3, 1000) -- 10 percent above: not enough now
    local result = w.ns.Hints.compute(w.ns.Hints.allPositions())
    eq(#result.entries, 2)
    contains(w.ns.Hints.summaryText(result, NOW), "at least 25 percent more")
end)

test("words: money is said by the game when it can, written out when it cannot", function()
    local w = newWorld({ locale = "enUS" })
    eq(w.ns.Game.coinText(0), "0 Copper")
    eq(w.ns.Game.coinText(5), "5 Copper")
    eq(w.ns.Game.coinText(100), "1 Silver")
    eq(w.ns.Game.coinText(10000), "1 Gold")
    eq(w.ns.Game.coinText(123456), "12 Gold 34 Silver 56 Copper")
    eq(w.ns.Game.coinText(500.4), "5 Silver", "rounded to whole coppers")
    eq(w.ns.Game.coinText(550.6), "5 Silver 51 Copper", "to the nearest")
    C_CurrencyInfo = {
        GetCoinText = function(amount, separator)
            return amount .. separator .. "copper-from-the-game"
        end,
    }
    eq(w.ns.Game.coinText(123), "123 copper-from-the-game")
    C_CurrencyInfo = {
        GetCoinText = function()
            error("no")
        end,
    }
    eq(w.ns.Game.coinText(100), "1 Silver", "a failing game call falls back")
    C_CurrencyInfo = nil
end)

test("words: the item's name carries its quality colour when WowVision gives it", function()
    local w = newWorld({ locale = "enUS" })
    eq(w.ns.Game.itemLabel("Linen Cloth", 1), "Linen Cloth")
    WowVision.items = {
        formatName = function(name, quality)
            return name .. ", quality " .. tostring(quality)
        end,
    }
    eq(w.ns.Game.itemLabel("Linen Cloth", 1), "Linen Cloth, quality 1")
    WowVision.items = {
        formatName = function()
            error("no")
        end,
    }
    eq(w.ns.Game.itemLabel("Linen Cloth", 1), "Linen Cloth")
    WowVision.items = nil
end)

-- ================================================================== summary

test("summary: items, total gain, fees, the date and age of the prices", function()
    local w = newWorld({ locale = "enUS" })
    w:put(0, 1, 35, { count = 20 })
    w:put(0, 2, 1002)
    eq(
        say(w),
        "For sale at the auction house: 2 items sell for at least 10 percent more at the auction house than to a vendor. "
            .. "Estimated gain 9 Gold 65 Silver, auction house fees not deducted. "
            .. "Prices from Life on Azeroth Market, taken November 19 at 23:00, 3 hours ago."
    )
    w.ns.useLocale("frFR")
    eq(
        say(w),
        "À vendre à l'hôtel des ventes : 2 objets se vendent au moins 10 pour cent plus cher à l'hôtel des ventes que chez un marchand. "
            .. "Gain estimé 9 Or 65 Argent, frais de l'hôtel des ventes non déduits. "
            .. "Prix de Life on Azeroth Market relevés le 19 novembre à 23 h 00, il y a 3 heures."
    )
    w.ns.useLocale("deDE")
    eq(
        say(w),
        "Zum Verkauf im Auktionshaus: 2 Gegenstände bringen im Auktionshaus mindestens 10 Prozent mehr als beim Händler. "
            .. "Geschätzter Gewinn 9 Gold 65 Silber, Gebühren des Auktionshauses nicht abgezogen. "
            .. "Preise von Life on Azeroth Market, erfasst am 19. November um 23:00 Uhr, vor 3 Stunden."
    )
end)

test("summary: one item, none, and the three languages", function()
    local w = newWorld({ locale = "frFR" })
    w:put(0, 1, 1002)
    contains(say(w), "À vendre à l'hôtel des ventes : 1 objet se vend au moins 10 pour cent plus cher")
    w.ns.useLocale("deDE")
    contains(say(w), "1 Gegenstand bringt im Auktionshaus mindestens 10 Prozent mehr")
    w.ns.useLocale("enUS")
    contains(say(w), "1 item sells for at least")
    w.slots = {}
    local none = say(w)
    contains(none, "no item in your bags sells for at least 10 percent more")
    lacks(none, "Estimated gain", "no gain line without items")
    w.ns.useLocale("frFR")
    contains(say(w), "aucun objet de vos sacs ne se vend au moins 10 pour cent plus cher")
    w.ns.useLocale("deDE")
    contains(say(w), "Kein Gegenstand in Ihren Taschen")
end)

test("summary: old prices are called old and their date is said", function()
    local w = newWorld({ locale = "enUS" })
    LOA_DATA.built = NOW - 25 * 3600
    local text = say(w)
    contains(text, "Warning, these prices are old. Prices from Life on Azeroth Market, taken November 19 at 1:00, 1 day ago.")
    LOA_DATA.built = NOW - 24 * 3600
    lacks(say(w), "Warning", "exactly a day is not old yet")
    LOA_DATA.built = NOW - 24 * 3600 - 1
    contains(say(w), "Warning, these prices are old.")
    LOA_DATA.built = NOW - 30
    contains(say(w), "taken November 20 at 1:59, just now.")
end)

test("summary: a price list from the future does not say a negative age", function()
    local w = newWorld({ locale = "enUS" })
    LOA_DATA.built = NOW + 7200
    contains(say(w), "just now")
end)

test("summary: no date known", function()
    local w = newWorld({ locale = "enUS" })
    LOA_DATA.built = nil
    LOA_DATA.latest = nil
    contains(say(w), "Prices from Life on Azeroth Market, date unknown.")
    lacks(say(w), "Warning")
    w.ns.useLocale("frFR")
    contains(say(w), "Prix de Life on Azeroth Market, date inconnue.")
end)

test("summary: prices of another house are said so", function()
    local w = newWorld({ locale = "enUS", faction = "Alliance", data = marketData({ houses = { ["0H"] = { latS = PRICES } } }) })
    contains(say(w), "These are the prices of another auction house: PvP Horde.")
    w.ns.useLocale("frFR")
    contains(say(w), "Ce sont les prix d'un autre hôtel des ventes : PvP Horde.")
    w.ns.useLocale("deDE")
    contains(say(w), "Das sind die Preise eines anderen Auktionshauses: PvP Horde.")
    w = newWorld({ locale = "enUS" })
    lacks(say(w), "another auction house", "the player's own house says nothing")
end)

test("summary: items the game has not loaded are said", function()
    local w = newWorld({ locale = "enUS" })
    w:put(0, 1, 35)
    w:put(0, 2, 135)
    w.uncached[135] = true
    contains(say(w), "1 item is not loaded yet, its vendor price is unknown.")
    w:put(0, 3, 1010)
    w.uncached[1010] = true
    contains(say(w), "2 items are not loaded yet, their vendor prices are unknown.")
    w.ns.useLocale("frFR")
    contains(say(w), "2 objets ne sont pas encore chargés, leurs prix marchand sont inconnus.")
    w.ns.useLocale("deDE")
    contains(say(w), "2 Gegenstände sind noch nicht geladen, ihre Händlerpreise sind unbekannt.")
    w.ns.useLocale("frFR")
    w.uncached[1010] = nil
    contains(say(w), "1 objet n'est pas encore chargé, son prix marchand est inconnu.")
    w.ns.useLocale("deDE")
    contains(say(w), "1 Gegenstand ist noch nicht geladen, sein Händlerpreis ist unbekannt.")
end)

test("summary: no market data", function()
    local w = newWorld({ locale = "enUS", data = false })
    eq(say(w), "For sale at the auction house: no prices available. Life on Azeroth Market is not installed, or its companion app has not made a price list yet.")
    w.ns.useLocale("frFR")
    eq(say(w), "À vendre à l'hôtel des ventes : aucun prix disponible. Life on Azeroth Market n'est pas installé, ou son application compagnon n'a pas encore fait de relevé.")
    w.ns.useLocale("deDE")
    contains(say(w), "Zum Verkauf im Auktionshaus: Keine Preise verfügbar.")
end)

-- =================================================================== screen

local function stopOrder(d)
    return d.kg:_stopOrder()
end

test("screen: the stop is the last one, after the bags, the bag slots and the bank; the summary then the items", function()
    local w = newWorld({ locale = "enUS", bank = true })
    w:openBags()
    w:put(0, 1, 35, { count = 20 })
    w:put(0, 2, 1002)
    w:put(0, 3, 1003) -- bound: never
    w:put(0, 4, 1001) -- below
    w:put(1, 5, 1010)
    check(w.ns.hooks.window, "the window hook installed")
    local rows, d = w:walk()
    local order = stopOrder(d)
    eq(table.concat(order, ","), "frame:combined:controls,frame:combined:search,frame:combined:grid,frame:combined:bagSlots,bank:tab,auctionHints")
    eq(order[#order], "auctionHints")
    local mine = lines(rows, "auctionHints")
    eq(#mine, 4, "the summary and three items")
    contains(mine[1], "For sale at the auction house: 3 items sell for at least 10 percent more")
    contains(mine[2], "Linen Cloth, 20: vendor 2 Silver each")
    contains(mine[3], "Silver Ring: vendor 5 Silver")
    contains(mine[4], "Cheap Dust")
    -- what is said at the stop: the summary is a plain read-out (not re-read as the clock moves), with the age of the
    -- prices; the list is introduced by the stop's name; the items keep the bags' pick-up and empty checks
    contains(mine[1], "taken November 19 at 23:00, 3 hours ago.")
    eq(rows[#rows - 3].node.vtable.announcements[1].live, false)
    eq(rows[#rows - 2].node.parent.vtable.announcements[1].text, "For sale at the auction house")
    check(type(rows[#rows - 2].node.vtable.isEmpty) == "function", "the bags' empty check is kept")
    contains(mine[2], "estimated gain 9 Gold 60 Silver, Button", "the sentence is said as it is")
    -- the last nodes of the whole screen are this stop's
    eq(rows[#rows].stop, "auctionHints")
    eq(rows[#rows - 3].stop, "auctionHints")
    eq(rows[#rows - 4].stop, "bank:tab")
end)

test("screen: the bound item is in the bags but not in the stop", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 3, 1003)
    w:put(0, 4, 35, { bound = true })
    w:put(0, 5, 35, { locationBound = true })
    local rows = w:walk()
    local mine = table.concat(lines(rows, "auctionHints"), " | ")
    lacks(mine, "Bound Blade")
    lacks(mine, "Linen Cloth")
    contains(mine, "no item in your bags sells for at least")
    local grid = table.concat(lines(rows, "frame:combined:grid"), " | ")
    contains(grid, "bag label 0.3", "the bags still list it")
end)

test("screen: positions count the items only, not the summary", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35)
    w:put(0, 2, 1002)
    local rows = w:walk()
    local mine = lines(rows, "auctionHints")
    eq(#mine, 3)
    lacks(mine[1], " of ", "the summary has no position")
    contains(mine[2], "1 of 2")
    contains(mine[3], "2 of 2")
end)

test("screen: Tab reaches the stop from the other stops, and goes round to the first", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35)
    local rows, d = w:walk()
    local first = rows[1].node
    d.kg:focus(first.id)
    local seen = {}
    for _ = 1, 6 do
        d.tab()
        seen[#seen + 1] = d.kg:currentNode().stopKey
    end
    eq(table.concat(seen, ","), "frame:combined:search,frame:combined:grid,frame:combined:bagSlots,auctionHints,frame:combined:controls,frame:combined:search")
    -- Shift+Tab from the first stop lands on this one
    d.kg:focus(first.id)
    d.tab(-1)
    eq(d.kg:currentNode().stopKey, "auctionHints")
    contains(d.say(), "For sale at the auction house", "the first thing heard is the summary")
end)

test("screen: nothing listed, the stop is still there and says so", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    local rows, d = w:walk()
    eq(stopOrder(d)[#stopOrder(d)], "auctionHints")
    local mine = lines(rows, "auctionHints")
    eq(#mine, 1)
    contains(mine[1], "no item in your bags")
end)

test("screen: with no market data the stop says why", function()
    local w = newWorld({ locale = "frFR", data = false })
    w:openBags()
    local rows = w:walk()
    local mine = lines(rows, "auctionHints")
    eq(#mine, 1)
    contains(mine[1], "aucun prix disponible")
end)

test("screen: none in combat, none while the bags are closed, none twice", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35)
    w.combat = true
    local _, d = w:walk()
    check(not table.concat(stopOrder(d), ","):find("auctionHints", 1, true), "no stop in combat")
    w.combat = false
    w.frames[1].shown = false
    _, d = w:walk()
    check(not table.concat(stopOrder(d), ","):find("auctionHints", 1, true), "no stop with the bags closed")
    w.frames[1].shown = true
    _, d = w:walk()
    eq(#stopOrder(d), 5)
    -- a builder that already has the stop gets none more
    local builder = graph.Builder:new({})
    w.originalRender(builder)
    check(w.ns.Screen.addStop(builder), "first")
    eq(w.ns.Screen.addStop(builder), false, "second")
end)

test("screen: an item read after the bags changed falls back to the bags' own label", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35, { count = 20 })
    local rows, d = w:walk()
    local node = rows[#rows].node
    contains(d.say(node), "Linen Cloth, 20: vendor")
    w.slots[0][1].count = 19
    contains(d.say(node), "bag label 0.1")
    w.slots[0][1] = nil
    contains(d.say(node), "bag label 0.1")
    w:put(0, 1, 135, { count = 20 })
    contains(d.say(node), "bag label 0.1", "another item in the slot, same count")
end)

test("screen: the slots keep the bags' clicks", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35)
    local rows = w:walk()
    local node = rows[#rows].node
    local clicks = {}
    for _, binding in ipairs(node.vtable.bindings) do
        clicks[binding.binding] = binding.target
    end
    check(clicks.leftClick ~= nil and clicks.rightClick ~= nil, "left and right click")
    eq(clicks.leftClick.bag, 0)
    eq(clicks.leftClick.slot, 1)
end)

test("screen: the same slot has an id of its own, apart from the bags' grid", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35)
    w:put(1, 1, 1002)
    local rows = w:walk()
    eq(#lines(rows, "auctionHints"), 3, "the summary and two items, no clash of ids")
    eq(#w.errors, 0)
    local ids = {}
    for _, row in ipairs(rows) do
        check(not ids[row.node.id.key], "duplicate id " .. tostring(row.node.id.key))
        ids[row.node.id.key] = true
    end
end)

test("screen: the biggest gain is read first", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 1010) -- gain 400
    w:put(0, 2, 35, { count = 20 }) -- gain 96000
    local rows = w:walk()
    local mine = lines(rows, "auctionHints")
    contains(mine[2], "Linen Cloth")
    contains(mine[3], "Cheap Dust")
end)

test("screen: rebuilding gives the same stop key and the same item ids (the focus is kept)", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35)
    local d = w:driver()
    local before = {}
    for _, node in ipairs(d.nodes()) do
        before[#before + 1] = tostring(node.id.key)
    end
    local after = {}
    for _, node in ipairs(d.nodes()) do
        after[#after + 1] = tostring(node.id.key)
    end
    eq(table.concat(after, ","), table.concat(before, ","))
end)

test("game: the extra backpack slots and the hidden buttons are not read", function()
    local w = newWorld({ locale = "enUS" })
    local frame = w:openBags()
    w:put(0, 1, 35)
    w:put(0, 2, 35)
    w:put(0, 3, 35)
    frame.Items[2].IsExtended = function()
        return true
    end
    frame.Items[3].shown = false
    local buttons = w.ns.Game.bagButtons()
    eq(#buttons, 14, "16 buttons, one extended, one hidden")
    local rows = w:walk()
    local mine = lines(rows, "auctionHints")
    eq(#mine, 2, "the summary and the one slot that counts")
    contains(mine[1], "1 item sells")
    -- a frame that is not shown has no buttons
    frame.shown = false
    eq(#w.ns.Game.bagButtons(), 0)
end)

test("screen: only the carried bags are read, not a bank bag or the keyring a frame shows", function()
    local w = newWorld({ locale = "enUS" })
    local frame = w:openBags()
    w:put(0, 1, 35)
    w:put(6, 1, 35) -- a bank bag
    w:put(-2, 1, 35) -- the keyring
    tinsert(frame.Items, newButton(6, 1))
    tinsert(frame.Items, newButton(-2, 1))
    local rows = w:walk()
    local mine = lines(rows, "auctionHints")
    eq(#mine, 2, "the summary and the backpack's item")
    contains(mine[1], "1 item sells")
    contains(mine[2], "Linen Cloth: vendor", "one item, not three stacks of it")
    lacks(mine[2], "stacks")
end)

test("game: the bags window is found through the window manager when the module does not list it", function()
    local w = newWorld()
    local window = w.window
    w.containers.registeredWindows = nil
    eq(w.ns.Game.bagsWindow(), nil)
    WowVision.UIHost = { windowManager = { getWindow = function(_, name)
        return name == "bags" and window or nil
    end } }
    eq(w.ns.Game.bagsWindow(), window)
    w.containers.registeredWindows = {}
    eq(w.ns.Game.bagsWindow(), window, "a module without the window")
    WowVision.UIHost = nil
    eq(w.ns.Game.bagsWindow(), nil)
end)

test("game: the market data is a table or nothing; the settings too", function()
    local w = newWorld()
    LOA_DATA = "not a table"
    eq(w.ns.Game.market(), nil)
    LifeOnAzeroth_MarketDB = 5
    eq(w.ns.Game.marketSettings(), nil)
    GetRealmName = function()
        error("no realm")
    end
    eq(w.ns.Game.realmName(), nil)
    UnitFactionGroup = nil
    eq(w.ns.Game.faction(), nil)
    GetRealmName = nil
    eq(w.ns.Game.realmName(), nil)
end)

test("game: a bag the game cannot count has no slots", function()
    local w = newWorld()
    C_Container.GetContainerNumSlots = function()
        error("no bag")
    end
    eq(w.ns.Game.numSlots(0), 0)
    C_Container.GetContainerNumSlots = function()
        return "x"
    end
    eq(w.ns.Game.numSlots(0), 0)
end)

test("game: speech goes to WowVision, or to the chat window without it", function()
    local w = newWorld()
    w.ns.Game.speak("hello")
    eq(env.spoken[#env.spoken], "hello")
    w.ns.Game.speak("")
    w.ns.Game.speak(nil)
    eq(#env.spoken, 1)
    local saved = WowVision.speak
    WowVision.speak = nil
    local printed = {}
    local realPrint = print
    print = function(text)
        printed[#printed + 1] = text
    end
    w.ns.Game.speak("plain")
    print = realPrint
    WowVision.speak = saved
    eq(printed[1], "plain")
end)

-- ============================================== the share: auction house / vendor

local function positionsOf(w)
    return w.ns.Hints.allPositions()
end

test("share: every slot is for the auction house, or for a vendor, or neither; the two lists never meet", function()
    local w = newWorld({ locale = "enUS" })
    w:put(0, 1, 35, { count = 20 }) -- auction
    w:put(0, 2, 1003) -- bound when picked up: vendor
    w:put(0, 3, 1004) -- quest item: vendor
    w:put(0, 4, 1013) -- no auction price: vendor
    w:put(0, 5, 1001) -- one copper short: vendor
    w:put(0, 6, 1002, { durability = { 1, 2 } }) -- damaged: vendor
    w:put(0, 7, 35, { bound = true }) -- a bound stack of an item that is also listed: vendor
    w:put(0, 8, 1008) -- vendor pays nothing, has a price: auction
    w:put(1, 1, 1017) -- vendor pays nothing, bound: neither
    w:put(1, 2, 1012) -- price 0: vendor
    w:put(1, 5, 1019) -- bound, a vendor pays one copper: vendor
    w:put(1, 3, 135)
    w.uncached[135] = true -- not loaded: neither, for now
    -- (1, 4) is empty
    local result = w.ns.Hints.compute(positionsOf(w))
    local function keys(list)
        local out = {}
        for _, position in ipairs(list) do
            out[#out + 1] = position.bag .. "." .. position.slot
        end
        return table.concat(out, " ")
    end
    eq(keys(result.auctionPositions), "0.1 0.8")
    eq(keys(result.merchantPositions), "0.2 0.3 0.4 0.5 0.6 0.7 1.2 1.5")
    -- no slot in both
    local seen = {}
    for _, position in ipairs(result.auctionPositions) do
        seen[position] = "auction"
    end
    for _, position in ipairs(result.merchantPositions) do
        check(seen[position] == nil, "in both lists: " .. position.bag .. "." .. position.slot)
    end
    eq(result.counts.auction, 2)
    eq(result.counts.vendor, 8)
    eq(result.counts.none, 1)
    eq(result.counts.pending, 1)
    eq(result.counts.total, 12)
    eq(result.counts.auction + result.counts.vendor + result.counts.none + result.counts.pending + result.counts.unreadable, result.counts.total)
end)

local function randomShare(feesOn)
    math.randomseed(20261120)
    local cut = feesOn and 5 or 0
    local prices = {}
    for line in PRICES:gmatch("[^\n]+") do
        local id, typical = line:match("^(%d+),(%d+)")
        prices[tonumber(id)] = tonumber(typical)
    end
    local ids = { 35, 135, 1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010, 1011, 1012, 1013, 1014, 1015, 1016, 1017 }
    local w = newWorld({ fees = feesOn })
    local expected, total = {}, 0
    local wanted = { auction = 0, vendor = 0, none = 0 }
    for round = 1, 12 do
        w.slots = {}
        w.uncached = {}
        expected = {}
        local positions = {}
        for bag = 0, 1 do
            for slot = 1, 8 do
                local id = ids[math.random(#ids)]
                local spec = {
                    count = math.random(1, 20),
                    bound = math.random(5) == 1,
                    locationBound = math.random(8) == 1,
                    durability = math.random(6) == 1 and { 3, 5 } or nil,
                }
                w:put(bag, slot, id, spec)
                local item = ITEMS[id]
                local bindOk = item.bind == 0 or item.bind == 2 or item.bind == 3
                local bound = spec.bound or spec.locationBound or not bindOk or item.accountUntilEquip == true
                local damaged = spec.durability ~= nil
                local price = prices[id]
                if price == 0 then
                    price = nil
                end
                local listable = not bound and not damaged and price ~= nil and (item.sell == 0 or price * (100 - cut) >= item.sell * 110)
                local kind = listable and "auction" or (item.sell > 0 and "vendor" or "none")
                expected[bag .. "." .. slot] = kind
                wanted[kind] = wanted[kind] + 1
                total = total + 1
            end
        end
        local result = w.ns.Hints.compute(positionsOf(w))
        local got = {}
        for _, position in ipairs(result.auctionPositions) do
            got[position.bag .. "." .. position.slot] = "auction"
        end
        for _, position in ipairs(result.merchantPositions) do
            local key = position.bag .. "." .. position.slot
            check(got[key] == nil, "in both lists: " .. key)
            got[key] = "vendor"
        end
        for key, kind in pairs(expected) do
            eq(got[key] or "none", kind, "round " .. round .. " slot " .. key)
        end
        eq(result.counts.auction + result.counts.vendor + result.counts.none, result.counts.total)
        -- the lines hold exactly the auction slots' items and quantities
        local lineCount, slotCount = 0, 0
        for _, line in ipairs(result.entries) do
            lineCount = lineCount + line.count
        end
        for _, position in ipairs(result.auctionPositions) do
            slotCount = slotCount + w.slots[position.bag][position.slot].count
        end
        eq(lineCount, slotCount, "the lines add up to the auction slots' quantities")
    end
    check(wanted.auction > 20 and wanted.vendor > 20 and wanted.none > 5, "the random slots cover all three places: " .. wanted.auction .. "/" .. wanted.vendor .. "/" .. wanted.none)
end

test("share: 600 random slots: each is where the rules say, never in both, nowhere only when nothing can sell it", function()
    randomShare(false)
end)

test("share: the same 600 slots with the auction house's cut taken off", function()
    randomShare(true)
end)

-- ============================================================ the auction house's cut

test("fees: on by default, and the cut is the house's own: 5 percent, 15 at Blackwater", function()
    local w = newWorld({ freshSettings = true })
    eq(w.ns.Game.getSetting("fees"), true)
    eq(w.ns.Hints.cutFor({}), 5, "no figure from the data: 5")
    eq(w.ns.Hints.cutFor({ cut = 15 }), 15)
    eq(w.ns.Market.cutOf("1H"), 5)
    eq(w.ns.Market.cutOf("0A"), 5)
    eq(w.ns.Market.cutOf("1B"), 15)
    eq(w.ns.Market.cutOf("3B"), 15)
    eq(w.ns.Market.cutOf(nil), 5)
    eq(w.ns.Market.snapshot().cut, 5)
    -- the Blackwater house
    w = newWorld({ freshSettings = true, faction = "Neutral", settings = { house = "1B" }, data = marketData({ houses = { ["1B"] = { latS = PRICES } } }) })
    eq(w.ns.Market.snapshot().cut, 15)
    eq(w.ns.Hints.cutFor(w.ns.Market.snapshot()), 15)
    -- switched off: none
    w.ns.Game.setSetting("fees", false)
    eq(w.ns.Hints.cutFor(w.ns.Market.snapshot()), 0)
    eq(WowVisionAuctionHintsDB.fees, false, "kept in the saved variable")
end)

test("fees: the 10 percent is judged after the cut: just over is in, just under is out, exactly 10 gross is out", function()
    local w = newWorld({ fees = true })
    w:put(0, 1, 1020) -- 348 * 95 = 33060 >= 300 * 110 = 33000
    w:put(0, 2, 1021) -- 347 * 95 = 32965 < 33000
    w:put(0, 3, 1000) -- 330, exactly 10 percent above gross: well under after the cut
    local entry = evaluate(w, 0, 1)
    check(entry, "just over")
    eq(entry.cut, 5)
    local out, reason, result = evaluate(w, 0, 2)
    eq(out, nil)
    eq(reason, "below")
    eq(result.kind, "vendor", "and a vendor buys it: the merchant category")
    out, reason = evaluate(w, 0, 3)
    eq(reason, "below")
    -- without the cut the three are what they were
    w.ns.Game.setSetting("fees", false)
    check(evaluate(w, 0, 1))
    check(evaluate(w, 0, 2))
    check(evaluate(w, 0, 3))
end)

test("fees: the gain and the percent are after the cut, the prices said are the data's", function()
    local w = newWorld({ locale = "enUS", fees = true })
    w:put(0, 1, 35, { count = 20 })
    local entry = evaluate(w, 0, 1)
    eq(entry.gain, (5000 * 95 / 100 - 200) * 20)
    eq(entry.percent, (5000 * 95 / 100 - 200) * 100 / 200)
    local line = w.ns.Hints.compute(positionsOf(w)).entries[1]
    eq(w.ns.Hints.entryText(line), "Linen Cloth, 20: vendor 2 Silver each, auction house 50 Silver each, 10 Gold in all, 2275 percent more after the cut, estimated gain 9 Gold 10 Silver")
    w.ns.useLocale("frFR")
    eq(w.ns.Hints.entryText(line), "Linen Cloth, 20 : marchand 2 Argent l'unité, hôtel des ventes 50 Argent l'unité, 10 Or en tout, plus 2275 pour cent après commission, gain estimé 9 Or 10 Argent")
    w.ns.useLocale("deDE")
    eq(w.ns.Hints.entryText(line), "Linen Cloth, 20: Händler 2 Silber pro Stück, Auktionshaus 50 Silber pro Stück, 10 Gold insgesamt, 2275 Prozent mehr nach Provision, geschätzter Gewinn 9 Gold 10 Silber")
    -- one item
    w = newWorld({ locale = "enUS", fees = true })
    w:put(0, 1, 1002)
    line = w.ns.Hints.compute(positionsOf(w)).entries[1]
    eq(w.ns.Hints.entryText(line), "Silver Ring: vendor 5 Silver, auction house 10 Silver, 90 percent more after the cut, estimated gain 4 Silver 50 Copper")
    w.ns.useLocale("frFR")
    eq(w.ns.Hints.entryText(line), "Silver Ring : marchand 5 Argent, hôtel des ventes 10 Argent, plus 90 pour cent après commission, gain estimé 4 Argent 50 Cuivre")
    w.ns.useLocale("deDE")
    eq(w.ns.Hints.entryText(line), "Silver Ring: Händler 5 Silber, Auktionshaus 10 Silber, 90 Prozent mehr nach Provision, geschätzter Gewinn 4 Silber 50 Kupfer")
end)

test("fees: an item no vendor buys is still listed, its gain after the cut", function()
    local w = newWorld({ locale = "enUS", fees = true })
    w:put(0, 1, 1008)
    local entry = evaluate(w, 0, 1)
    check(entry)
    eq(entry.percent, nil)
    eq(entry.gain, 9000 * 95 / 100)
end)

test("fees: the summary says the cut was counted, and the deposit", function()
    local w = newWorld({ locale = "enUS", fees = true })
    w:put(0, 1, 35, { count = 20 })
    contains(say(w), "Estimated gain 9 Gold 10 Silver, after the auction house's cut of 5 percent (the deposit comes back when an item sells).")
    lacks(say(w), "fees not deducted")
    w.ns.useLocale("frFR")
    contains(say(w), "Gain estimé 9 Or 10 Argent, après la commission de 5 pour cent de l'hôtel des ventes (le dépôt revient quand l'objet se vend).")
    w.ns.useLocale("deDE")
    contains(say(w), "Geschätzter Gewinn 9 Gold 10 Silber, nach Abzug der Provision des Auktionshauses von 5 Prozent (die Anzahlung kommt zurück, wenn ein Gegenstand verkauft wird).")
    -- the Blackwater house: 15 percent
    w = newWorld({ locale = "enUS", fees = true, faction = "Neutral", settings = { house = "1B" }, data = marketData({ houses = { ["1B"] = { latS = PRICES } } }) })
    w:put(0, 1, 35, { count = 20 })
    contains(say(w), "Estimated gain 8 Gold 10 Silver, after the auction house's cut of 15 percent")
    -- nothing listed: the cut is still said
    w = newWorld({ locale = "enUS", fees = true })
    contains(say(w), "no item in your bags sells for at least 10 percent more at the auction house than to a vendor. Prices counted after the auction house's cut of 5 percent.")
    w.ns.useLocale("frFR")
    contains(say(w), "Prix comptés après la commission de 5 pour cent de l'hôtel des ventes.")
    w.ns.useLocale("deDE")
    contains(say(w), "Preise nach Abzug der Provision des Auktionshauses von 5 Prozent gerechnet.")
    -- not counted: as before
    w = newWorld({ locale = "enUS", fees = false })
    w:put(0, 1, 35, { count = 20 })
    contains(say(w), "auction house fees not deducted")
    lacks(say(w), "cut of")
end)

test("fees: the merchant side follows the same cut", function()
    local w = newWorld({ fees = true })
    w:put(0, 1, 1021)
    w:put(0, 2, 1020)
    local answer = WowVisionAuctionHints.partition(positionsOf(w))
    eq(#answer.auction, 1)
    eq(answer.auction[1].slot, 2)
    eq(#answer.merchant, 1)
    eq(answer.merchant[1].slot, 1)
    w.ns.Game.setSetting("fees", false)
    answer = WowVisionAuctionHints.partition(positionsOf(w))
    eq(#answer.auction, 2)
    eq(#answer.merchant, 0)
end)

test("fees: /wvhdv fees on|off, frais oui|non, gebuehren ja|nein; no word switches it", function()
    local w = newWorld({ locale = "enUS", freshSettings = true })
    local command = SlashCmdList["WVAUCTIONHINTS"]
    command("fees off")
    eq(env.spoken[#env.spoken], "Auction house cut taken off: no.")
    eq(WowVisionAuctionHintsDB.fees, false)
    command("fees on")
    eq(env.spoken[#env.spoken], "Auction house cut taken off: yes, 5 percent.")
    eq(WowVisionAuctionHintsDB.fees, true)
    command("fees")
    eq(WowVisionAuctionHintsDB.fees, false, "no word: switched")
    command("FEES")
    eq(WowVisionAuctionHintsDB.fees, true, "capitals do not matter")
    w.ns.useLocale("frFR")
    command("frais non")
    eq(env.spoken[#env.spoken], "Commission de l'hôtel des ventes déduite : non.")
    command("frais oui")
    eq(env.spoken[#env.spoken], "Commission de l'hôtel des ventes déduite : oui, 5 pour cent.")
    w.ns.useLocale("deDE")
    command("gebuehren nein")
    eq(env.spoken[#env.spoken], "Provision des Auktionshauses abgezogen: nein.")
    eq(WowVisionAuctionHintsDB.fees, false)
    command("gebuehren ja")
    eq(env.spoken[#env.spoken], "Provision des Auktionshauses abgezogen: ja, 5 Prozent.")
    command("gebühren aus")
    eq(WowVisionAuctionHintsDB.fees, false)
    command("gebühren an")
    eq(WowVisionAuctionHintsDB.fees, true)
    -- every word that means yes sets yes whatever the state was, every word that means no sets no
    for _, word in ipairs({ "on", "1", "oui", "yes", "ja", "an" }) do
        for _, before in ipairs({ true, false }) do
            WowVisionAuctionHintsDB.fees = before
            command("fees " .. word)
            eq(WowVisionAuctionHintsDB.fees, true, "the word " .. word .. " from " .. tostring(before))
        end
    end
    for _, word in ipairs({ "off", "0", "non", "no", "nein", "aus" }) do
        for _, before in ipairs({ true, false }) do
            WowVisionAuctionHintsDB.fees = before
            command("fees " .. word)
            eq(WowVisionAuctionHintsDB.fees, false, "the word " .. word .. " from " .. tostring(before))
        end
    end
    -- a word it does not know switches
    WowVisionAuctionHintsDB.fees = false
    command("fees wat")
    eq(WowVisionAuctionHintsDB.fees, true)
    command("fees wat")
    eq(WowVisionAuctionHintsDB.fees, false)
    -- the three names of the command, from any state
    for _, name in ipairs({ "fees", "frais", "gebuehren", "gebühren", "gebuhren" }) do
        WowVisionAuctionHintsDB.fees = true
        command(name .. " nein")
        eq(WowVisionAuctionHintsDB.fees, false, name)
        command(name .. " ja")
        eq(WowVisionAuctionHintsDB.fees, true, name)
    end
end)

test("fees: the status says the state and how to change it, and the Blackwater cut", function()
    local w = newWorld({ locale = "enUS", fees = true })
    SlashCmdList["WVAUCTIONHINTS"]("")
    contains(env.spoken[#env.spoken], "Auction house cut taken off: yes, 5 percent. Use /wvhdv fees on or off to take the auction house's cut off its prices, or not.")
    w = newWorld({ locale = "enUS", fees = false })
    SlashCmdList["WVAUCTIONHINTS"]("")
    contains(env.spoken[#env.spoken], "Auction house cut taken off: no.")
    w = newWorld({ locale = "enUS", fees = true, faction = "Neutral", settings = { house = "1B" }, data = marketData({ houses = { ["1B"] = { latS = PRICES } } }) })
    SlashCmdList["WVAUCTIONHINTS"]("fees on")
    eq(env.spoken[#env.spoken], "Auction house cut taken off: yes, 15 percent.")
    w = newWorld({ locale = "enUS", fees = true, data = false })
    SlashCmdList["WVAUCTIONHINTS"]("fees on")
    eq(env.spoken[#env.spoken], "Auction house cut taken off: yes, 5 percent.", "no data: the usual 5")
    w.ns.useLocale("frFR")
    SlashCmdList["WVAUCTIONHINTS"]("")
    contains(env.spoken[#env.spoken], "Utilisez /wvhdv frais oui ou non pour déduire ou non la commission de l'hôtel des ventes de ses prix.")
    w.ns.useLocale("deDE")
    SlashCmdList["WVAUCTIONHINTS"]("")
    contains(env.spoken[#env.spoken], "Mit /wvhdv gebuehren ja oder nein ziehen Sie die Provision des Auktionshauses von seinen Preisen ab oder nicht.")
end)

test("share: the answer WowVision_Bags asks for keeps the positions it is given, in order", function()
    local w = newWorld()
    w:put(0, 1, 35)
    w:put(0, 2, 1003)
    w:put(0, 3, 1017)
    local api = WowVisionAuctionHints
    check(api ~= nil and type(api.partition) == "function", "the global is there")
    eq(api.version, 2)
    local positions = { { bag = 0, slot = 3 }, { bag = 0, slot = 2, extra = "kept" }, { bag = 0, slot = 1 }, { bag = 0, slot = 4 } }
    local answer = api.partition(positions)
    eq(#answer.auction, 1)
    eq(answer.auction[1], positions[3], "the same table")
    eq(#answer.merchant, 1)
    eq(answer.merchant[1], positions[2], "the same table")
    eq(answer.merchant[1].extra, "kept")
    eq(answer.problem, nil)
end)

test("share: without prices nothing is for the auction house and a vendor takes what it buys", function()
    local w = newWorld({ data = false })
    w:put(0, 1, 35)
    w:put(0, 2, 1003)
    w:put(0, 3, 1017)
    local answer = WowVisionAuctionHints.partition(positionsOf(w))
    eq(#answer.auction, 0)
    eq(#answer.merchant, 2)
    eq(answer.problem, "nomarket")
    w = newWorld({ data = { built = NOW, region = "eu", houses = { ["1H"] = {} } } })
    w:put(0, 1, 35)
    answer = WowVisionAuctionHints.partition(positionsOf(w))
    eq(answer.problem, "noprices")
    eq(#answer.merchant, 1)
end)

test("share: the merchant lines are one per item, in the order of the bags, with their sentence and first button", function()
    local w = newWorld({ locale = "enUS" })
    w:put(1, 2, 1003, { count = 2 })
    w:put(0, 5, 1003, { count = 3 })
    w:put(0, 1, 1004)
    w:put(0, 7, 35) -- for the auction house: no merchant line
    -- given in any order
    local positions = {
        { bag = 1, slot = 2, button = "B12" },
        { bag = 0, slot = 7, button = "B07" },
        { bag = 0, slot = 5, button = "B05" },
        { bag = 0, slot = 1, button = "B01" },
    }
    local answer = WowVisionAuctionHints.partition(positions)
    eq(#answer.merchantLines, 2)
    local first, second = answer.merchantLines[1], answer.merchantLines[2]
    eq(first.itemID, 1004)
    eq(first.button, "B01")
    eq(first.text, "Quest Letter: vendor 1 Silver")
    eq(first.stacks, 1)
    eq(second.itemID, 1003)
    eq(second.count, 5)
    eq(second.stacks, 2)
    eq(second.bag .. "." .. second.slot, "0.5", "the first stack leads whatever order the positions come in")
    eq(second.button, "B05")
    eq(second.vendorUnit, 1000)
    eq(second.vendorTotal, 5000)
    eq(second.piles[1].button, "B05")
    eq(second.piles[2].button, "B12")
    eq(second.piles[1].count, 3)
    eq(second.text, "Bound Blade, 5 in 2 stacks: vendor 10 Silver each, 50 Silver in all")
    w.ns.useLocale("frFR")
    answer = WowVisionAuctionHints.partition(positions)
    eq(answer.merchantLines[2].text, "Bound Blade, 5 au total en 2 piles : marchand 10 Argent l'unité, 50 Argent en tout")
    eq(answer.merchantLines[1].text, "Quest Letter : marchand 1 Argent")
    w.ns.useLocale("deDE")
    answer = WowVisionAuctionHints.partition(positions)
    eq(answer.merchantLines[2].text, "Bound Blade, 5 insgesamt in 2 Stapeln: Händler 10 Silber pro Stück, 50 Silber insgesamt")
    eq(answer.merchantLines[1].text, "Quest Letter: Händler 1 Silber")
    -- one stack of several items: "name, count"
    w.ns.useLocale("enUS")
    w = newWorld({ locale = "enUS" })
    w:put(0, 1, 1003, { count = 4 })
    answer = WowVisionAuctionHints.partition({ { bag = 0, slot = 1 } })
    eq(answer.merchantLines[1].text, "Bound Blade, 4: vendor 10 Silver each, 40 Silver in all")
    w:put(0, 2, 1004, { count = 2 })
    answer = WowVisionAuctionHints.partition({ { bag = 0, slot = 2 } })
    eq(answer.merchantLines[1].text, "Quest Letter, 2: vendor 1 Silver each, 2 Silver in all", "two items in one stack")
end)

test("share: no answer in combat", function()
    local w = newWorld()
    w:put(0, 1, 35)
    w.combat = true
    eq(WowVisionAuctionHints.partition(positionsOf(w)), nil)
    w.combat = false
    check(WowVisionAuctionHints.partition(positionsOf(w)) ~= nil)
end)

test("share: the screen's lines are the auction slots, and the merchant slots are not among them", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35, { count = 3 })
    w:put(0, 2, 35, { count = 4, bound = true })
    w:put(0, 3, 1003)
    local rows = w:walk()
    local mine = lines(rows, "auctionHints")
    eq(#mine, 2)
    contains(mine[2], "Linen Cloth, 3: vendor")
    lacks(table.concat(mine, "|"), "Bound Blade")
    local answer = WowVisionAuctionHints.partition(w.ns.Hints.allPositions())
    eq(#answer.auction, 1)
    eq(#answer.merchant, 2)
end)

-- ==================================================== the line of an item with stacks

test("stacks: the line is one row for the item, acts on its first stack, and keeps its id when that stack goes", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(1, 3, 35, { count = 2 })
    w:put(0, 4, 35, { count = 7 })
    w:put(0, 2, 35, { count = 5 })
    local rows, d = w:walk()
    local mine = lines(rows, "auctionHints")
    eq(#mine, 2, "the summary and one line for three stacks")
    contains(mine[2], "Linen Cloth, 14 in 3 stacks: vendor 2 Silver each, auction house 50 Silver each, 7 Gold in all")
    contains(mine[1], "1 item sells for")
    local node = rows[#rows].node
    local target
    for _, binding in ipairs(node.vtable.bindings) do
        if binding.binding == "leftClick" then
            target = binding.target
        end
    end
    eq(target.bag, 0)
    eq(target.slot, 2, "the click is on the first stack: lowest bag, lowest slot")
    local idBefore = node.id.key
    eq(idBefore, "auctionHints:item:35")
    -- the first stack goes (sold, or put up for auction): the next one leads and the line keeps its id
    w.slots[0][2] = nil
    rows, d = w:walk()
    local after = rows[#rows].node
    eq(after.id.key, idBefore)
    contains(d.say(after), "Linen Cloth, 9 in 2 stacks")
    for _, binding in ipairs(after.vtable.bindings) do
        if binding.binding == "leftClick" then
            eq(binding.target.slot, 4)
        end
    end
    -- the line read after any of its stacks changed under it: the bags' label of its first stack, until redrawn
    w.slots[1][3].count = 1
    contains(d.say(after), "bag label 0.4")
    w.slots[1][3].count = 2
    contains(d.say(after), "Linen Cloth, 9 in 2 stacks", "back as it was")
end)

test("stacks: the same item in the first stack only gives the plain 'item, count' line", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35, { count = 20 })
    local rows = w:walk()
    local mine = lines(rows, "auctionHints")
    lacks(mine[2], " stacks")
    contains(mine[2], "Linen Cloth, 20: vendor 2 Silver each")
end)

-- ==================================================================== hooks

test("hooks: the window's render is wrapped once, and what it returns is kept", function()
    local w = newWorld()
    check(w.ns.hooks.window)
    check(w.window.graphScreen.auctionHintsWrapped)
    local wrapped = w.window.graphScreen.render
    check(wrapped ~= w.originalRender)
    check(w.ns.installWindow(), "installing again")
    eq(w.window.graphScreen.render, wrapped, "not wrapped twice")
    eq(w.window.graphScreen.background, true, "the rest of the config is untouched")
    local builder = graph.Builder:new({})
    w.window.graphScreen.render = function()
        return "a", "b"
    end
    w.window.graphScreen.auctionHintsWrapped = nil
    w.ns.installWindow()
    local a, b = w.window.graphScreen.render(builder)
    eq(a, "a")
    eq(b, "b")
end)

test("hooks: the component's renderGraph is the fallback when the window cannot be found", function()
    local w = newWorld({ noWindow = true })
    eq(w.ns.hooks.window, false)
    eq(w.ns.hooks.component, true)
    check(w.Bags.auctionHintsWrapped)
    w:openBags()
    w:put(0, 1, 35)
    local builder = graph.Builder:new({})
    w.Bags.renderGraph(w.Bags, builder)
    local nodesList = builder:build().order
    eq(nodesList[#nodesList].stopKey, "auctionHints")
    eq(#w.errors, 0)
    -- installing again does not wrap again
    local wrapped = w.Bags.renderGraph
    check(w.ns.installComponent())
    eq(w.Bags.renderGraph, wrapped)
end)

test("hooks: the component's own render still runs and its result is kept", function()
    local w = newWorld({ noWindow = true })
    w:openBags()
    w.Bags.renderGraph = function()
        return "x"
    end
    w.Bags.auctionHintsWrapped = nil
    w.ns.installComponent()
    local builder = graph.Builder:new({})
    eq(w.Bags.renderGraph(w.Bags, builder), "x")
end)

test("hooks: when neither can be found it is said once and nothing breaks", function()
    local printed = {}
    local realPrint = print
    print = function(text)
        printed[#printed + 1] = text
    end
    local w = newWorld({ noWindow = true, noComponent = true })
    print = realPrint
    eq(w.ns.hooks.window, false)
    eq(w.ns.hooks.component, false)
    eq(#printed, 1)
    contains(printed[1], "WowVision_AuctionHints: WowVision's bags were not found")
end)

test("hooks: an error in the stop is reported once and the bags still draw", function()
    local w = newWorld({ locale = "enUS" })
    w:openBags()
    w:put(0, 1, 35)
    w.ns.Hints.compute = function()
        error("price trouble")
    end
    local rows, d = w:walk()
    eq(#stopOrder(d), 4, "the four stops of the bags, no stop of ours")
    eq(#w.errors, 1)
    contains(w.errors[1], "WowVision_AuctionHints: ")
    contains(w.errors[1], "price trouble")
    w:walk()
    eq(#w.errors, 1, "once")
    eq(#rows > 0, true)
end)

test("hooks: the addon does nothing without WowVision's tables", function()
    local saved = WowVision.base
    WowVision.base = nil
    local w = newWorld()
    WowVision.base = nil
    local ns = {}
    for _, name in ipairs(FILES) do
        assert(loadfile(addonDir .. "/" .. name .. ".lua"))("WowVision_AuctionHints", ns)
    end
    eq(ns.hooks, nil)
    eq(ns.installed, nil)
    WowVision.base = saved
end)

-- =================================================================== command

test("command: /wvhdv says the summary and why items are left out, with the bags closed", function()
    local w = newWorld({ locale = "enUS" })
    w:put(0, 1, 35, { count = 20 }) -- listed: 1
    w:put(0, 2, 1003) -- bound: 2
    w:put(0, 3, 1003)
    w:put(0, 4, 1013) -- no price: 3
    w:put(0, 5, 1013)
    w:put(0, 6, 1013)
    w:put(0, 7, 1001) -- below: 4
    w:put(0, 8, 1001)
    w:put(1, 1, 1001)
    w:put(1, 2, 1001)
    for slot = 3, 7 do -- damaged: 5
        w:put(1, slot, 1002, { durability = { 1, 2 } })
    end
    w:put(1, 2, 35, { count = 3 }) -- a second stack of the item in the list: 2 slots, 1 line (below is 3 then)
    w:put(1, 8, 135) -- not loaded: 1
    w.uncached[135] = true
    check(SlashCmdList["WVAUCTIONHINTS"], "registered")
    SlashCmdList["WVAUCTIONHINTS"]("")
    eq(#env.spoken, 1)
    local text = env.spoken[1]
    contains(text, "1 item sells for at least 10 percent more")
    contains(text, "1 in the list. Slots in the list: 2. Slots to sell to a merchant: 13. Occupied slots in your bags: 16, kept out of the list: 2 bound, 3 without an auction house price, 3 under 10 percent, 5 damaged; 1 not loaded.")
    eq(SLASH_WVAUCTIONHINTS1, "/wvhdv")
    eq(SLASH_WVAUCTIONHINTS2, "/wvah")
    eq(SLASH_WVAUCTIONHINTS3, "/wvauktion")
end)

test("command: in French and German", function()
    local w = newWorld({ locale = "frFR" })
    w:put(0, 1, 35)
    SlashCmdList["WVAUCTIONHINTS"]("")
    contains(env.spoken[1], "1 dans la liste. Emplacements dans la liste : 1. Emplacements à vendre à un marchand : 0. Emplacements occupés de vos sacs : 1, hors de la liste : 0 liés, 0 sans prix à l'hôtel des ventes, 0 en dessous de 10 pour cent, 0 abîmés ; 0 pas encore chargés.")
    w.ns.useLocale("deDE")
    SlashCmdList["WVAUCTIONHINTS"]("")
    contains(env.spoken[2], "1 in der Liste. Plätze in der Liste: 1. Plätze zum Verkauf an einen Händler: 0. Belegte Plätze in Ihren Taschen: 1, nicht in der Liste: 0 gebunden, 0 ohne Auktionshauspreis, 0 unter 10 Prozent, 0 beschädigt; 0 nicht geladen.")
end)

test("command: in combat it only says it is not available; without data it says why", function()
    local w = newWorld({ locale = "enUS" })
    w.combat = true
    SlashCmdList["WVAUCTIONHINTS"]("")
    eq(env.spoken[1], "The list is not available during combat.")
    w.ns.useLocale("frFR")
    SlashCmdList["WVAUCTIONHINTS"]("")
    eq(env.spoken[2], "La liste n'est pas disponible pendant un combat.")
    w.ns.useLocale("deDE")
    SlashCmdList["WVAUCTIONHINTS"]("")
    eq(env.spoken[3], "Die Liste ist im Kampf nicht verfügbar.")
    w.combat = false
    LOA_DATA = nil
    w.ns.useLocale("enUS")
    SlashCmdList["WVAUCTIONHINTS"]("")
    contains(env.spoken[4], "no prices available")
    contains(env.spoken[4], "Slots in the list: 0. Slots to sell to a merchant: 0.")
end)

test("command: an error is reported once, not thrown", function()
    local w = newWorld()
    w.ns.Hints.compute = function()
        error("command trouble")
    end
    SlashCmdList["WVAUCTIONHINTS"]("")
    SlashCmdList["WVAUCTIONHINTS"]("")
    eq(#w.errors, 1)
end)

test("command: the carried bags are read from the game, five bags and the reagent bag", function()
    local w = newWorld({ locale = "enUS" })
    w.size = { [0] = 4, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 3 }
    w:put(5, 3, 35)
    w:put(0, 4, 135)
    local positions = w.ns.Hints.allPositions()
    eq(#positions, 7)
    SlashCmdList["WVAUCTIONHINTS"]("")
    contains(env.spoken[1], "2 items sell for")
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = nil
    NUM_BAG_SLOTS = 3
    eq(#w.ns.Game.bagIds(), 4, "without the reagent bag constant: NUM_BAG_SLOTS + 1")
    NUM_BAG_SLOTS = nil
    eq(#w.ns.Game.bagIds(), 5, "no constants at all: backpack and four bags")
end)

-- ==================================================================== done

io.write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
