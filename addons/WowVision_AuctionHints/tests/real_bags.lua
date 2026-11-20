-- Runs this addon's stop against WowVision's REAL bags screen: the real containers module (core/windows/containers.lua,
-- retail/containers/containers.lua and Bags.lua, the code that draws the bag controls, the search box, the grid and the
-- bag slot bar), the real component registry, the real Window class (which copies the screen's configuration when it
-- opens), the real graph Builder and KeyGraph, and the real WowVision_Bags extension (its Item Lists stop). Only the
-- game's frames are stand-ins, and the bank, whose real file is far too heavy to stand up here: its component is a
-- stand-in that draws two stops after the bags, as the real one does.
-- Usage, from the addon folder: lua tests/real_bags.lua   (prints "all ok" when every check passes).
local script = arg and arg[0] or "tests/real_bags.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local wv = os.getenv("WOWVISION_DIR") or (addonDir .. "/../WowVision")
local bagsExtensionDir = os.getenv("WOWVISION_BAGS_DIR") or (addonDir .. "/../WowVision_Bags")

tinsert = table.insert
tremove = table.remove
unpack = unpack or table.unpack
wipe = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

local failures = 0
local function check(label, ok, extra)
    if not ok then
        failures = failures + 1
    end
    print((ok and "ok    " or "FAIL  ") .. label .. (extra ~= nil and ("  " .. tostring(extra)) or ""))
end

local env = dofile(testsDir .. "/graph_env.lua")(wv)
local graph = env.graph

local function loadWowVision(path, ...)
    local chunk, err = loadfile(wv .. "/" .. path)
    if chunk == nil then
        error(err)
    end
    return chunk(...)
end

local identity = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})

-- ------------------------------------------------------------- the game

local NOW = 1795140000
local ITEMS = {
    [35] = { name = "Linen Cloth", sell = 200, bind = 0 },
    [1002] = { name = "Silver Ring", sell = 500, bind = 2 },
    [1003] = { name = "Bound Blade", sell = 1000, bind = 1 },
    [1010] = { name = "Cheap Dust", sell = 100, bind = 0 },
    [1001] = { name = "Almost Herb", sell = 300, bind = 0 },
    [1013] = { name = "Nobody Wants It", sell = 10, bind = 0 },
    [1018] = { name = "Plain Herb", sell = 300, bind = 0 },
}
local PRICES = "35,5000,4000,10,10,\n1001,329,300,4,4,\n1018,329,300,4,4,\n1002,1000,900,4,4,\n1003,9000,8000,4,4,\n1010,500,400,4,4,\n"

local function link(id)
    return "|cffffffff|Hitem:" .. id .. "::::::::20|h[" .. ITEMS[id].name .. "]|h|r"
end

local function fakeFrame(extra)
    local frame = { shown = true }
    function frame:IsShown()
        return self.shown
    end
    function frame:IsEnabled()
        return true
    end
    function frame:HasScript()
        return false
    end
    function frame:GetParent()
        return self.parent
    end
    function frame:GetText()
        return self.text or ""
    end
    function frame:SetScript() end
    function frame:SetFocus() end
    function frame:ClearFocus() end
    for key, value in pairs(extra or {}) do
        frame[key] = value
    end
    return frame
end

local function newButton(bag, slot)
    local button = fakeFrame({ bag = bag, slot = slot })
    function button:GetBagID()
        return self.bag
    end
    function button:GetID()
        return self.slot
    end
    function button:GetTop()
        return nil
    end
    return button
end

-- A whole fresh start of the game and of the addons.
-- config: mode ("combined" or "separate"), bank (the bank is open), order ("hints first" loads this addon before
-- WowVision_Bags; default after), bagsExtension (false: not loaded), withoutWindowHook, locale
local function boot(config)
    config = config or {}
    local w = { slots = {}, errors = {}, printed = {} }
    geterrorhandler = function()
        return function(err)
            w.errors[#w.errors + 1] = tostring(err)
        end
    end
    local realPrint = print
    print = function(text)
        w.printed[#w.printed + 1] = text
    end
    GetLocale = function()
        return config.locale or "enUS"
    end
    InCombatLockdown = function()
        return false
    end
    time = function()
        return NOW
    end
    date = function(format, moment)
        return os.date("!" .. format, moment)
    end
    GetRealmName = function()
        return "Testrealm"
    end
    UnitFactionGroup = function()
        return "Horde"
    end
    NUM_BAG_SLOTS = 4
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
    GetMoney = function()
        return 123456
    end
    CursorHasItem = function()
        return false
    end
    IsShiftKeyDown = function()
        return false
    end
    Enum = { BagIndex = { Keyring = -2 } }
    -- one slot the game flags as new: it fills the Item Lists stop of WowVision_Bags, which exists only while some list
    -- has something in it
    C_NewItems = {
        IsNewItem = function(bag, slot)
            return bag == 0 and slot == 5
        end,
    }
    C_CurrencyInfo = {
        GetCoinText = function(amount, separator)
            return amount .. separator .. "copper"
        end,
    }
    CreateFrame = function()
        return fakeFrame({ RegisterEvent = function() end, UnregisterEvent = function() end })
    end
    C_Timer = { After = function() end }
    LOA_DATA = { built = NOW - 3600, region = "eu", houses = { ["1H"] = { latS = PRICES } } }
    LifeOnAzeroth_MarketDB = nil
    WowVisionBagsDB = nil
    SlashCmdList = {}
    WowVisionAuctionHintsDB = { fees = false }
    C_Container = {
        GetBagName = function(bag)
            return bag == 0 and "Backpack" or ("Bag " .. bag)
        end,
        GetContainerNumSlots = function(bag)
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
                isBound = spec.bound == true,
                hyperlink = link(spec.id),
                itemName = item.name,
                quality = 1,
                hasNoValue = item.sell == 0,
            }
        end,
        GetContainerItemDurability = function()
            return nil, nil
        end,
        GetContainerItemQuestInfo = function()
            return nil
        end,
    }
    C_Item = {
        GetItemInfo = function(linkOrID)
            local id = tonumber(tostring(linkOrID):match("item:(%d+)") or linkOrID)
            local item = ITEMS[id]
            if item == nil then
                return nil
            end
            return item.name, link(id), 1, 20, 0, "", "", 20, "", 1, item.sell, 0, 0, item.bind
        end,
        IsBound = function()
            return false
        end,
    }
    ItemLocation = {
        CreateFromBagAndSlot = function(_, bag, slot)
            return { bag = bag, slot = slot }
        end,
    }

    -- WowVision's own pieces, fresh each time (they register types and windows, once per start of the game)
    WowVision.base = nil
    WowVision.items = {
        formatName = function(name)
            return name
        end,
    }
    WowVision.isSecret = function()
        return false
    end
    WowVision.speak = function(_, text)
        env.spoken[#env.spoken + 1] = text
    end
    loadWowVision("core/Registry.lua")
    for _, file in ipairs({ "components", "RegistryType", "ClassRegistryType", "ComponentRegistry" }) do
        loadWowVision("core/components/" .. file .. ".lua")
    end
    loadWowVision("core/ui/WindowManager.lua")
    loadWowVision("core/ui/Window.lua")

    local function newModule(key)
        local module = { key = key, L = identity, registeredWindows = {}, settings = { shape = "list" } }
        function module:setLabel() end
        function module:hasSettings()
            return { add = function() end }
        end
        -- the real Module:createComponentRegistry and Module:registerWindow (core/module/Module.lua), without the rest
        function module:createComponentRegistry(registryConfig)
            local registry = WowVision.components.createRegistry(registryConfig)
            self[registryConfig.key] = registry
            return registry
        end
        function module:registerWindow(windowConfig)
            if windowConfig.type == "CustomWindow" and windowConfig.isOpen then
                windowConfig.isOpenFunc = windowConfig.isOpen
                windowConfig.isOpen = nil
            end
            local window = WowVision.WindowManager:CreateWindow(windowConfig.type, windowConfig)
            self.registeredWindows[window.name] = window
        end
        return module
    end
    WowVision.base = {
        windows = {
            createModule = function(self, key)
                local module = newModule(key)
                self[key] = module
                return module
            end,
        },
    }

    -- the frames
    local frames = {}
    local function addItems(frame, bags)
        frame.Items = {}
        for _, bag in ipairs(bags) do
            for slot = 1, 8 do
                tinsert(frame.Items, newButton(bag, slot))
            end
        end
    end
    local combined
    if config.mode == "separate" then
        for _, bag in ipairs({ 0, 1 }) do
            local frame = fakeFrame({ name = "ContainerFrame" .. (bag + 1), id = bag })
            function frame:GetName()
                return self.name
            end
            function frame:GetID()
                return self.id
            end
            frame.IsCombinedBagContainer = function()
                return false
            end
            addItems(frame, { bag })
            frames[#frames + 1] = frame
        end
    else
        combined = fakeFrame({ name = "ContainerFrameCombinedBags", id = 0 })
        function combined:GetName()
            return self.name
        end
        function combined:GetID()
            return self.id
        end
        combined.IsCombinedBagContainer = function()
            return true
        end
        combined.MoneyFrame = fakeFrame()
        addItems(combined, { 0, 1 })
        frames[#frames + 1] = combined
        BagItemAutoSortButton = fakeFrame({ parent = combined })
        BagItemSearchBox = fakeFrame({ parent = combined })
    end
    w.frames = frames
    ContainerFrameUtil_EnumerateContainerFrames = function()
        local index = 0
        return function()
            index = index + 1
            if frames[index] ~= nil then
                return index, frames[index]
            end
        end
    end
    for _, name in ipairs({ "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot" }) do
        _G[name] = fakeFrame()
    end

    -- the real bags code
    loadWowVision("core/windows/containers.lua")
    loadWowVision("retail/containers/containers.lua")
    loadWowVision("retail/containers/Bags.lua")
    local Bank = WowVision.components.createType("containers", { key = "RetailBank" })
    function Bank:isOpen()
        return w.bankOpen == true
    end
    function Bank:renderGraph(builder)
        builder:beginStop("bank:tabs")
        builder:addItem(graph.ControlId.structural("bank:tabs"), graph.nodes.text({ label = "Bank tabs" }))
        builder:beginStop("bank:slots")
        builder:addItem(graph.ControlId.structural("bank:slots"), graph.nodes.text({ label = "Bank slots" }))
    end
    loadWowVision("retail/containers/instances.lua")
    w.bankOpen = config.bank == true

    -- the addons, in the order given
    local function loadBagsExtension()
        local ns = {}
        for _, name in ipairs({ "Locale", "Store", "Lists", "NewItems", "Marks", "Features", "Merchant", "Hooks", "Main" }) do
            local chunk, err = loadfile(bagsExtensionDir .. "/" .. name .. ".lua")
            if chunk == nil then
                error(err)
            end
            chunk("WowVision_Bags", ns)
        end
        w.bagsNs = ns
    end
    local function loadHints()
        local ns = {}
        for _, name in ipairs({ "Locale", "Game", "Market", "Hints", "Screen", "Main" }) do
            local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
            if chunk == nil then
                error(err)
            end
            chunk("WowVision_AuctionHints", ns)
        end
        w.ns = ns
    end
    if config.order == "hints first" then
        loadHints()
        if config.bagsExtension ~= false then
            loadBagsExtension()
        end
    else
        if config.bagsExtension ~= false then
            loadBagsExtension()
        end
        loadHints()
    end

    print = realPrint

    function w:put(bag, slot, id, fields)
        self.slots[bag] = self.slots[bag] or {}
        local spec = { id = id, count = 1 }
        for key, value in pairs(fields or {}) do
            spec[key] = value
        end
        self.slots[bag][slot] = spec
    end
    -- what the game does when the window opens: the real Window copies its screen configuration, and the screen
    -- is then drawn from the copy
    function w:openScreen()
        local window = WowVision.base.windows.containers.registeredWindows["bags"]
        local opened
        WowVision.graphHost.open = function(_, screenConfig)
            opened = screenConfig
            return {}
        end
        window:openGraph({ notifyOpened = function() end })
        return env.driver(opened.render), opened
    end
    function w:finish() end
    return w
end

local function stopsOf(d)
    d.nodes()
    return table.concat(d.kg:_stopOrder(), ",")
end

local function rowsOf(d)
    local rows = {}
    for _, node in ipairs(d.nodes()) do
        rows[#rows + 1] = { stop = node.stopKey, text = d.say(node) or "?" }
    end
    return rows
end

local function textsOf(rows, stop)
    local texts = {}
    for _, row in ipairs(rows) do
        if row.stop == stop then
            texts[#texts + 1] = row.text
        end
    end
    return texts
end

local function has(text, part)
    return text ~= nil and tostring(text):find(part, 1, true) ~= nil
end

-- ================================================================= scenarios

-- 1. WowVision 1.0.4 with the combined bags: controls and search first, then the grid and the bag slots; with
--    WowVision_Bags loaded before this addon (the order OptionalDeps asks for)
do
    local w = boot({})
    w:put(0, 1, 35, { count = 20 })
    w:put(0, 2, 1002)
    w:put(0, 3, 1003) -- bound when picked up: never
    w:put(0, 4, 1010, { bound = true }) -- bound: never
    w:put(0, 5, 35) -- flagged new: in the Item Lists stop too
    local d = w:openScreen()
    local stops = stopsOf(d)
    print("stops: " .. stops)
    check("1.0.4 combined bags, Item Lists loaded before: this addon's stop is the last one",
        stops:match("auctionHints$") ~= nil, stops)
    check("the bags' real stops are all there before it",
        has(stops, "frame:ContainerFrameCombinedBags:controls,frame:ContainerFrameCombinedBags:search,frame:ContainerFrameCombinedBags:grid,frame:ContainerFrameCombinedBags:bagSlots"), stops)
    local rows = rowsOf(d)
    local mine = textsOf(rows, "auctionHints")
    check("the summary and two lines (the bound ones are not there; the two stacks of Linen Cloth are one line)", #mine == 3, #mine)
    check("summary first", has(mine[1], "For sale at the auction house: 2 items"), mine[1])
    check("biggest gain first, both stacks in it", has(mine[2], "Linen Cloth, 21 in 2 stacks"), mine[2])
    check("second line", has(mine[3], "Silver Ring"), mine[3])
    check("Item Lists is a stop before it, after the bag slots",
        stops:match("bagSlots,lists,auctionHints$") ~= nil, stops)
    check("no Bound Blade, no bound Cheap Dust in the stop", not has(table.concat(mine, "|"), "Bound Blade") and not has(table.concat(mine, "|"), "Cheap Dust"))
    check("the bags still list the bound ones", has(table.concat(textsOf(rows, "frame:ContainerFrameCombinedBags:grid"), "|"), "Bound Blade"))
    check("no error", #w.errors == 0, table.concat(w.errors, " | "))
    check("the window hook is the one used", w.ns.hooks.window == true and w.ns.hooks.component == nil)
    w:finish()
end

-- 2. The same with WowVision_Bags loaded AFTER this addon (what happens without OptionalDeps: A comes before B)
do
    local w = boot({ order = "hints first" })
    w:put(0, 1, 35, { count = 20 })
    w:put(0, 5, 35)
    local d = w:openScreen()
    local stops = stopsOf(d)
    print("stops: " .. stops)
    check("Item Lists loaded after this addon: still last", stops:match("auctionHints$") ~= nil, stops)
    check("Item Lists is there too, before it", stops:match("bagSlots,lists,auctionHints$") ~= nil, stops)
    check("no error", #w.errors == 0, table.concat(w.errors, " | "))
    w:finish()
end

-- 3. Without WowVision_Bags
do
    local w = boot({ bagsExtension = false })
    w:put(0, 1, 35)
    local d = w:openScreen()
    local stops = stopsOf(d)
    check("without the Item Lists extension: last", stops:match("auctionHints$") ~= nil and not has(stops, "lists"), stops)
    w:finish()
end

-- 4. The bank open: the bank's stops come after the bags', and this one is still last
do
    local w = boot({ bank = true })
    w:put(0, 1, 35)
    local d = w:openScreen()
    local stops = stopsOf(d)
    print("stops: " .. stops)
    check("bank open: bank stops, then this one", stops:match("bank:tabs,bank:slots,auctionHints$") ~= nil, stops)
    w:finish()
end

-- 5. One frame per bag: the backpack's controls sit between the bags
do
    local w = boot({ mode = "separate" })
    w:put(0, 1, 35)
    w:put(1, 2, 1002)
    local d = w:openScreen()
    local stops = stopsOf(d)
    print("stops: " .. stops)
    check("one frame per bag: last", stops:match("auctionHints$") ~= nil, stops)
    local mine = textsOf(rowsOf(d), "auctionHints")
    check("items of both bags", #mine == 3, #mine)
    w:finish()
end

-- 6. Tab walks: from the first stop, Shift+Tab lands on this one, Tab from this one goes round to the first
do
    local w = boot({})
    w:put(0, 1, 35)
    local d = w:openScreen()
    local nodes = d.nodes()
    d.kg:focus(nodes[1].id)
    d.tab(-1)
    check("Shift+Tab from the first stop lands on the stop", d.kg:currentNode().stopKey == "auctionHints", d.kg:currentNode().stopKey)
    check("the first thing said is the summary", has(d.say(), "For sale at the auction house"), d.say())
    d.tab()
    check("Tab from the last stop goes round to the first", d.kg:currentNode().stopKey ~= "auctionHints", d.kg:currentNode().stopKey)
    w:finish()
end

-- 7. The real Window copies the screen's configuration when it opens: the wrapper is in the copy
do
    local w = boot({})
    local window = WowVision.base.windows.containers.registeredWindows["bags"]
    check("the window's screen was wrapped before it opened", window.graphScreen.auctionHintsWrapped == true)
    local _, opened = w:openScreen()
    check("the copy used to draw the screen carries the wrapper", opened.auctionHintsWrapped == true)
    check("the window's other settings are kept", opened.background == true and opened.key == "bags")
    w:finish()
end

-- 8. The addon does not change the bags' own rendering of the bags it adds a stop after
do
    local plain = boot({ order = "none", bagsExtension = false })
    local window = WowVision.base.windows.containers.registeredWindows["bags"]
    plain:put(0, 1, 35)
    -- the stops before ours are those the bags draw without this addon: draw once with the original render
    local d = plain:openScreen()
    local before = {}
    d.nodes()
    for _, stop in ipairs(d.kg:_stopOrder()) do
        if stop ~= "auctionHints" then
            before[#before + 1] = stop
        end
    end
    local original = plain.ns and nil
    check("the bags' stops are the real ones: controls, search, grid, bag slots",
        table.concat(before, ",") == "frame:ContainerFrameCombinedBags:controls,frame:ContainerFrameCombinedBags:search,frame:ContainerFrameCombinedBags:grid,frame:ContainerFrameCombinedBags:bagSlots",
        table.concat(before, ","))
    plain:finish()
end

-- 9. In French, with the same screen
do
    local w = boot({ locale = "frFR" })
    w:put(0, 1, 35, { count = 20 })
    local d = w:openScreen()
    local mine = textsOf(rowsOf(d), "auctionHints")
    check("French summary", has(mine[1], "À vendre à l'hôtel des ventes : 1 objet se vend au moins 10 pour cent"), mine[1])
    check("French line", has(mine[2], "Linen Cloth, 20 : marchand 200 copper l'unité"), mine[2])
    w:finish()
end

-- 10. The merchant category of WowVision_Bags and the auction house stop, from the same answer, on the real screen
do
    local w = boot({})
    w:put(0, 1, 35, { count = 20 }) -- auction house
    w:put(0, 2, 1002) -- auction house
    w:put(0, 3, 1003) -- bound when picked up: merchant
    w:put(0, 4, 1010, { bound = true }) -- bound: merchant
    w:put(0, 5, 35) -- auction house (a second stack of the same item)
    w:put(0, 6, 1018) -- under the threshold: merchant
    w:put(1, 2, 1018, { count = 3 }) -- a second stack of the same item: the same merchant line
    w:put(0, 7, 1013) -- no auction house price: merchant
    w:put(1, 1, 1001) -- under the threshold too, but a favorite: never offered for sale
    -- the favorite mark, put the way the bags' own key does
    local store = w.bagsNs.store
    local marks = w.bagsNs.favorites:section().marks
    local key = store.keyFromLink("|cffffffff|Hitem:1001::::::::20|h[Almost Herb]|h|r")
    store.toggle(marks, key, "Almost Herb")
    local d = w:openScreen()
    d.state.expanded["list:merchant"] = true
    d.nodes()
    local rows = rowsOf(d)
    local merchant = {}
    for _, row in ipairs(rows) do
        if row.stop == "lists" then
            merchant[#merchant + 1] = row.text
        end
    end
    local listsText = table.concat(merchant, " | ")
    print(listsText)
    check("the category is there, closed groups opened", has(listsText, "For sale to a merchant"), listsText)
    check("bound by type, bound by the slot, under the threshold and without a price are for a merchant",
        has(listsText, "Bound Blade") and has(listsText, "Cheap Dust") and has(listsText, "Plain Herb") and has(listsText, "Nobody Wants It"), listsText)
    check("one line for the two stacks of Plain Herb, with the total and the price in all", has(listsText, "Plain Herb, 4 in 2 stacks: vendor 300 copper each, 1200 copper in all"), listsText)
    check("four of them (the favorite is not offered)", has(listsText, "For sale to a merchant, ") and not has(listsText, "For sale to a merchant (") and has(listsText, "4 of 4") and not has(listsText, "Almost Herb"), listsText)
    local fromMerchant = listsText:sub((listsText:find("For sale to a merchant", 1, true)) or 1)
    check("nothing of the auction house tab is in it (Linen Cloth is only in New Items, above)", not has(fromMerchant, "Linen Cloth") and not has(fromMerchant, "Silver Ring"), fromMerchant)
    local mine = textsOf(rows, "auctionHints")
    local mineText = table.concat(mine, " | ")
    check("the tab has the two auction house items, the stacks of Linen Cloth added up", #mine == 3 and has(mine[2], "Linen Cloth, 21 in 2 stacks") and has(mine[3], "Silver Ring"), mineText)
    check("nothing of the merchant category is in the tab", not has(mineText, "Bound Blade") and not has(mineText, "Cheap Dust") and not has(mineText, "Plain Herb") and not has(mineText, "Nobody Wants It"), mineText)
    check("both come from the one answer, no error", #w.errors == 0, table.concat(w.errors, " | "))
    check("the tab is still the last stop", stopsOf(d):match("lists,auctionHints$") ~= nil, stopsOf(d))
    w:finish()
end

print(failures == 0 and "all ok" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
