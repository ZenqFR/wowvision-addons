-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- The game and WowVision are mocked, but the addon's own files are loaded for real, in the order of the .toc, so
-- the tests exercise what the hooks do to the bags: the tags, the keys, the Item Lists stop, the sale. No other
-- addon is needed.

local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."

-- ----------------------------------------------------------------- harness

tinsert = table.insert
tremove = table.remove
unpack = unpack or table.unpack
strtrim = function(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local runner = { suites = {}, order = {}, passed = 0, failed = 0 }

function runner:addSuite(name, suite)
    self.suites[name] = suite
    tinsert(self.order, name)
end

function runner:assertEqual(a, b, message)
    if a ~= b then
        error((message or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end
function runner:assertNotEqual(a, b, message)
    if a == b then
        error((message or "values are equal") .. ": " .. tostring(a), 2)
    end
end
function runner:assertTrue(value, message)
    if value ~= true then
        error((message or "expected true") .. ", got " .. tostring(value), 2)
    end
end
function runner:assertFalse(value, message)
    if value ~= false then
        error((message or "expected false") .. ", got " .. tostring(value), 2)
    end
end
function runner:assertNil(value, message)
    if value ~= nil then
        error((message or "expected nil") .. ", got " .. tostring(value), 2)
    end
end
function runner:assertNotNil(value, message)
    if value == nil then
        error(message or "expected a value", 2)
    end
end
function runner:assertType(value, expected, message)
    if type(value) ~= expected then
        error((message or "wrong type") .. ": expected " .. expected .. ", got " .. type(value), 2)
    end
end
function runner:assertError(fn, message)
    if pcall(fn) then
        error(message or "expected an error", 2)
    end
end

function runner:run()
    for _, name in ipairs(self.order) do
        local names = {}
        for testName in pairs(self.suites[name]) do
            tinsert(names, testName)
        end
        table.sort(names)
        for _, testName in ipairs(names) do
            local ok, err = pcall(self.suites[name][testName], self)
            if ok then
                self.passed = self.passed + 1
            else
                self.failed = self.failed + 1
                io.write("FAIL  ", name, " / ", testName, "\n      ", tostring(err), "\n")
            end
        end
    end
    io.write(string.format("%d passed, %d failed\n", self.passed, self.failed))
    os.exit(self.failed == 0 and 0 or 1)
end

-- ------------------------------------------------------------- the addon

local FILES = { "Locale", "Store", "Lists", "NewItems", "Marks", "Features", "Merchant", "Hooks", "Main" }

-- A fresh copy of the addon: every file loaded in toc order into a new namespace. upTo stops after that file.
local function loadAddon(upTo)
    local ns = {}
    for _, name in ipairs(FILES) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_Bags", ns)
        if name == upTo then
            break
        end
    end
    return ns
end

-- The ported suites of the logic that moved out of WowVision unchanged (they find their subject on WowVision).
local pure = loadAddon("NewItems")
local pureWowVision = {
    testing = { testRunner = runner },
    bagLists = pure.lists,
    junkStore = pure.store,
    newItems = pure.newItems,
}
WowVision = pureWowVision
local firstPure = #runner.order
for _, name in ipairs({ "store", "lists", "newItems" }) do
    dofile(testsDir .. "/" .. name .. ".lua")
end
-- The integration tests below replace WowVision with a fake of their own; each ported test starts from its own.
for index = firstPure + 1, #runner.order do
    local suite = runner.suites[runner.order[index]]
    for testName, fn in pairs(suite) do
        suite[testName] = function(t)
            WowVision = pureWowVision
            return fn(t)
        end
    end
end

-- ------------------------------------------------------------ the world

-- A fake WowVision, game and bags around the real addon. world.items["bag:slot"] = { name, id, quality, ... }.
local function link(id, name)
    return "|cffffffff|Hitem:" .. id .. "::::::::60:::::::::|h[" .. name .. "]|h|r"
end

local function newWorld(config)
    config = config or {}
    local world = {
        spoken = {},
        sold = {},
        items = {},
        flagged = {},
        errors = {},
        bindings = {},
        bindingOrder = {},
        applied = 0,
        merchantEvents = 0,
        open = true,
        mode = config.mode,
        noControls = config.noControls,
        controlsFirst = config.controlsFirst,
        locale = config.locale or "enUS",
        poorSetting = config.poorSetting == true,
    }

    function world.add(bag, slot, id, name, extra)
        local info = {
            itemID = id,
            itemName = name,
            hyperlink = link(id, name),
            quality = 1,
            stackCount = 1,
            hasNoValue = false,
            isLocked = false,
        }
        for key, value in pairs(extra or {}) do
            info[key] = value
        end
        world.items[bag .. ":" .. slot] = info
        return world.button(bag, slot)
    end

    local buttons = {}
    function world.button(bag, slot)
        local key = bag .. ":" .. slot
        if buttons[key] == nil then
            buttons[key] = {
                bag = bag,
                slot = slot,
                GetBagID = function()
                    return bag
                end,
                GetID = function()
                    return slot
                end,
                IsShown = function()
                    return true
                end,
            }
        end
        return buttons[key]
    end

    WowVisionAuctionHints = nil
    -- A stand-in for WowVision_AuctionHints' answer: world.vendor["bag:slot"] = "vendor" or "auction" says where a
    -- slot belongs (anything else: neither). Installed by the tests that need it.
    function world.installHints()
        world.vendor = {}
        world.partitionCalls = 0
        WowVisionAuctionHints = {
            version = 2,
            partition = function(positions)
                world.partitionCalls = world.partitionCalls + 1
                world.partitioned = positions
                if world.partitionNil then
                    return nil
                end
                local answer = { auction = {}, merchant = {}, merchantLines = {} }
                local byItem = {}
                for _, position in ipairs(positions) do
                    local key = position.bag .. ":" .. position.slot
                    local kind = world.vendor[key]
                    if kind == "auction" then
                        tinsert(answer.auction, position)
                    elseif kind == "vendor" then
                        tinsert(answer.merchant, position)
                        -- one line per item, as WowVision_AuctionHints makes them
                        local info = world.items[key]
                        local line = byItem[info.itemID]
                        if line == nil then
                            line = {
                                itemID = info.itemID,
                                name = info.itemName,
                                count = 0,
                                bag = position.bag,
                                slot = position.slot,
                                button = position.button,
                                piles = {},
                            }
                            byItem[info.itemID] = line
                            tinsert(answer.merchantLines, line)
                        end
                        line.count = line.count + info.stackCount
                        tinsert(line.piles, { bag = position.bag, slot = position.slot, count = info.stackCount, button = position.button })
                    end
                end
                for _, line in ipairs(answer.merchantLines) do
                    line.stacks = #line.piles
                    line.text = line.stacks > 1 and (line.name .. ", " .. line.count .. " in " .. line.stacks .. " stacks")
                        or (line.count > 1 and (line.name .. ", " .. line.count) or line.name)
                end
                return answer
            end,
        }
    end

    GetLocale = function()
        return world.locale
    end
    geterrorhandler = function()
        return function(err)
            tinsert(world.errors, tostring(err))
        end
    end
    print = function() end
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
    C_Container = {
        GetContainerItemInfo = function(bag, slot)
            return world.items[bag .. ":" .. slot]
        end,
        GetContainerItemID = function(bag, slot)
            local info = world.items[bag .. ":" .. slot]
            return info ~= nil and info.itemID or nil
        end,
        GetContainerNumSlots = function(bag)
            local count = 0
            for key in pairs(world.items) do
                if tonumber(key:match("^(%d+):")) == bag then
                    count = math.max(count, tonumber(key:match(":(%d+)$")))
                end
            end
            return count
        end,
        UseContainerItem = function(bag, slot)
            tinsert(world.sold, bag .. ":" .. slot)
            world.items[bag .. ":" .. slot] = nil
        end,
    }
    C_NewItems = {
        IsNewItem = function(bag, slot)
            return world.flagged[bag .. ":" .. slot] == true
        end,
    }
    C_CurrencyInfo = {
        GetCoinText = function(copper)
            return copper .. " copper"
        end,
    }
    C_Item = {
        GetItemInfo = function()
            return nil
        end,
    }

    -- WowVision's bags module, as far as the hooks look at it
    local containers = {}
    function containers.itemSlotNode(itemButton, label, clickLabels)
        return { label = label, clickLabels = clickLabels, bindings = {}, button = itemButton }
    end
    function containers.slotLocation(itemButton)
        return itemButton.bag, itemButton.slot
    end
    function containers.getBagItemLabel(itemButton)
        local info = world.items[itemButton.bag .. ":" .. itemButton.slot]
        return info ~= nil and info.itemName or "Empty slot"
    end
    function containers.itemClickLabels()
        return {}
    end
    function containers.renderSlots(builder, slots)
        for _, itemButton in ipairs(slots) do
            builder:addItem(
                { key = "object:" .. itemButton.bag .. ":" .. itemButton.slot },
                containers.itemSlotNode(itemButton, function()
                    return containers.getBagItemLabel(itemButton)
                end, containers.itemClickLabels(itemButton))
            )
        end
        return 1
    end
    world.containers = containers

    -- the frames the game draws the bags in
    world.slots = {}
    local frame = {
        Items = world.slots,
        IsShown = function()
            return world.open
        end,
        -- the combined bag, or one frame per bag (world.mode = "individual")
        IsCombinedBagContainer = function()
            return world.mode ~= "individual"
        end,
    }
    ContainerFrameUtil_EnumerateContainerFrames = function()
        local done = false
        return function()
            if not done then
                done = true
                return 1, frame
            end
        end
    end

    -- the retail bags component
    -- The stops the retail bags draw: the combined bag has its grid, its bag slot bar, then the search box and the
    -- controls; one frame per bag has a stop per bag, with the backpack's controls after the backpack.
    local Bags = {}
    function Bags:renderGraph(builder)
        if world.mode == "individual" then
            builder:beginStop("bag:0")
            containers.renderSlots(builder, world.slots)
            builder:beginStop("frame:ContainerFrame1:controls")
            builder:addItem({ key = "money" }, { label = "Money" })
            builder:beginStop("bag:1")
            builder:addItem({ key = "bagButton:1" }, { label = "Bag Slot 1" })
            return
        end
        -- WowVision may also draw the controls and the search box before the bags
        if world.controlsFirst then
            builder:beginStop("frame:ContainerFrameCombinedBags:controls")
            builder:addItem({ key = "money" }, { label = "Money" })
            builder:beginStop("frame:ContainerFrameCombinedBags:search")
            builder:addItem({ key = "search" }, { label = "Search" })
        end
        builder:beginStop("frame:ContainerFrameCombinedBags:grid")
        containers.renderSlots(builder, world.slots)
        builder:beginStop("frame:ContainerFrameCombinedBags:bagSlots")
        builder:addItem({ key = "bagButton:0" }, { label = "Bag Slot Backpack" })
        if not world.noControls and not world.controlsFirst then
            builder:beginStop("frame:ContainerFrameCombinedBags:search")
            builder:addItem({ key = "search" }, { label = "Search" })
            builder:beginStop("frame:ContainerFrameCombinedBags:controls")
            builder:addItem({ key = "money" }, { label = "Money" })
        end
    end
    function Bags:isOpen()
        return world.open
    end
    world.Bags = Bags

    -- the merchant module
    local merchant = { settings = { autoSellPoorItems = world.poorSetting } }
    function merchant:onEvent(event)
        if event == "MERCHANT_SHOW" then
            world.merchantEvents = world.merchantEvents + 1
        end
    end
    world.merchant = merchant

    -- the input manager and the binding stores
    local input = {}
    function input:createBinding(info)
        world.bindings[info.key] = info
        tinsert(world.bindingOrder, info.key)
        return info
    end
    function input:getBinding(key)
        return world.bindings[key]
    end
    function input:getDefaultDB()
        return {}
    end

    WowVisionDB = config.savedDB or { submodules = {} }
    WowVisionBagsDB = config.bagsDB
    local registries = {}
    function registries:get(key)
        if key == "containers" then
            return {
                types = {
                    get = function(_, typeKey)
                        return typeKey == "RetailBags" and not config.noBags and Bags or nil
                    end,
                },
            }
        end
        return nil
    end

    local graphHost = {
        screen = {},
        focusedScreen = function(self)
            return self.screen
        end,
    }
    world.graphHost = graphHost

    WowVision = {
        speak = function(_, text)
            tinsert(world.spoken, text)
        end,
        base = { windows = { containers = containers, merchant = merchant } },
        graph = {
            ControlId = {
                structural = function(name)
                    return { key = "structural:" .. name }
                end,
            },
            controlTypes = { group = "group" },
            kinds = { label = "label" },
        },
        components = { registries = registries },
        input = input,
        dbManager = {
            resolveBindings = function()
                return {}
            end,
        },
        applyBindingStore = function()
            world.applied = world.applied + 1
        end,
        globalDb = {},
        graphHost = graphHost,
    }
    if config.coreHasLists then
        WowVision.bagLists = {}
    end
    if config.noMerchant then
        WowVision.base.windows.merchant = nil
    end

    -- a graph builder that implements expandable groups the way WowVision's does
    local recorded = {}
    local stack = {}
    local groups = {}
    local builder = { expansion = {} }
    local function suppressed()
        return stack[#stack] ~= nil and stack[#stack].suppressed
    end
    function builder:pushContext(key, label)
        tinsert(recorded, "context " .. key .. ": " .. tostring(label))
    end
    function builder:popContext() end
    function builder:beginStop(key)
        tinsert(recorded, "STOP " .. tostring(key))
    end
    function builder:beginGroup(id, vtable, expanded, defaultExpanded)
        groups[id.key] = vtable
        local isExpanded
        if expanded ~= nil then
            isExpanded = expanded == true
        elseif self.expansion ~= nil then
            isExpanded = self.expansion[id.key] == true
        else
            isExpanded = defaultExpanded == true
        end
        tinsert(recorded, "GROUP " .. vtable.announcements[1].text .. (isExpanded and " [open]" or " [closed]"))
        tinsert(stack, { suppressed = suppressed() or not isExpanded })
    end
    function builder:endGroup()
        stack[#stack] = nil
    end
    function builder:addItem(id, vtable)
        if vtable == nil or suppressed() then
            return
        end
        local label = vtable.label
        if type(label) == "function" then
            label = label()
        end
        tinsert(recorded, "item " .. id.key .. " = " .. tostring(label))
        world.lastNodes = world.lastNodes or {}
        world.lastNodes[id.key] = vtable
    end
    world.builder = builder
    world.recorded = recorded

    function world.render()
        for index = #recorded, 1, -1 do
            recorded[index] = nil
        end
        stack = {}
        world.lastNodes = {}
        world.Bags:renderGraph(builder)
        return table.concat(recorded, "\n")
    end

    -- the addon, loaded into the world
    world.ns = loadAddon()
    return world
end

local function bindingFunc(node, key)
    for _, entry in ipairs(node.bindings) do
        if entry.binding == key then
            return entry.func
        end
    end
    return nil
end

local function lines(text)
    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        tinsert(out, line)
    end
    return out
end

local function contains(text, part)
    return text:find(part, 1, true) ~= nil
end

-- The index of the first line that is exactly this one.
local function stopIndex(out, line)
    for index, candidate in ipairs(out) do
        if candidate == line then
            return index
        end
    end
    return nil
end

-- The keys of the stops, in order: "grid,bagSlots,lists".
local function stops(out)
    local keys = {}
    for _, line in ipairs(out) do
        local key = line:match("^STOP (.*)$")
        if key ~= nil then
            tinsert(keys, key)
        end
    end
    return table.concat(keys, ",")
end

-- ------------------------------------------------------------------ tests

runner:addSuite("Toc", {
    ["the .toc lists the files the tests load, in the same order"] = function(t)
        local file = assert(io.open(addonDir .. "/WowVision_Bags.toc", "rb"))
        local listed = {}
        for line in file:read("a"):gmatch("[^\r\n]+") do
            local name = line:match("^([%w_]+)%.lua$")
            if name ~= nil then
                tinsert(listed, name)
            end
        end
        file:close()
        t:assertEqual(table.concat(listed, ","), table.concat(FILES, ","))
    end,
})

runner:addSuite("Install", {
    ["the four hooks install"] = function(t)
        local world = newWorld()
        t:assertTrue(world.ns.installed)
        for _, hook in ipairs({ "installSlots", "installLists", "installMerchant", "installBindings" }) do
            t:assertTrue(world.ns.hooks[hook], hook)
        end
        t:assertEqual(#world.errors, 0, table.concat(world.errors, "; "))
    end,

    ["a WowVision with its own bag lists is left alone"] = function(t)
        local world = newWorld({ coreHasLists = true })
        t:assertNil(world.ns.hooks)
        t:assertNil(world.bindings["junk/toggle"])
    end,

    ["without the retail bags the other hooks still install"] = function(t)
        local world = newWorld({ noBags = true })
        t:assertFalse(world.ns.hooks.installLists)
        t:assertTrue(world.ns.hooks.installSlots)
        t:assertTrue(world.ns.hooks.installMerchant)
        t:assertTrue(world.ns.hooks.installBindings)
    end,

    ["installing twice wraps once"] = function(t)
        local world = newWorld()
        local node = world.containers.itemSlotNode
        t:assertTrue(world.ns.installSlots())
        t:assertEqual(world.containers.itemSlotNode, node)
        local render = world.Bags.renderGraph
        t:assertTrue(world.ns.installLists())
        t:assertEqual(world.Bags.renderGraph, render)
    end,
})

runner:addSuite("Key bindings", {
    ["both keys are registered with their defaults"] = function(t)
        local world = newWorld()
        local junk, favorite = world.bindings["junk/toggle"], world.bindings["favorite/toggle"]
        t:assertEqual(junk.inputs[1], "SHIFT-ENTER")
        t:assertEqual(junk.label, "Select Junk")
        t:assertEqual(junk.dorment, true)
        t:assertEqual(favorite.inputs[1], "SHIFT-BACKSPACE")
        t:assertEqual(favorite.label, "Select Favorite")
        t:assertEqual(favorite.dorment, true)
        t:assertEqual(favorite.type, "Flexible")
    end,

    ["WowVision's binding stores are told once"] = function(t)
        local world = newWorld()
        t:assertEqual(world.applied, 1)
        world.ns.installBindings()
        t:assertEqual(world.applied, 1, "nothing new to tell")
    end,

    ["the labels are in the player's language"] = function(t)
        local world = newWorld({ locale = "frFR" })
        t:assertEqual(world.bindings["junk/toggle"].label, "Sélectionner camelote")
        t:assertEqual(world.bindings["favorite/toggle"].label, "Sélectionner favori")
    end,
})

runner:addSuite("Slots", {
    ["a bag item slot says nothing extra until it is marked"] = function(t)
        local world = newWorld()
        local button = world.add(0, 1, 2589, "Linen Cloth")
        tinsert(world.slots, button)
        local text = world.render()
        t:assertTrue(contains(text, "item object:0:1 = Linen Cloth"), text)
    end,

    ["the junk key marks the item, says so, and tags the label"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        local node = world.lastNodes["object:0:1"]
        bindingFunc(node, "junk/toggle")()
        t:assertEqual(world.spoken[#world.spoken], "Linen Cloth: marked as junk")
        t:assertTrue(contains(world.render(), "item object:0:1 = [Junk] Linen Cloth"))
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        t:assertEqual(world.spoken[#world.spoken], "Linen Cloth: no longer junk")
        t:assertTrue(contains(world.render(), "item object:0:1 = Linen Cloth"))
    end,

    ["the favorite key marks the item the same way"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        t:assertEqual(world.spoken[#world.spoken], "Linen Cloth: marked as favorite")
        t:assertTrue(contains(world.render(), "item object:0:1 = [Favorite] Linen Cloth"))
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        t:assertEqual(world.spoken[#world.spoken], "Linen Cloth: no longer a favorite")
    end,

    ["both marks read favorite first"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        t:assertTrue(contains(world.render(), "item object:0:1 = [Favorite] [Junk] Linen Cloth"))
    end,

    ["the mark belongs to the item, not the slot"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        tinsert(world.slots, world.add(1, 4, 2589, "Linen Cloth"))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        local text = world.render()
        t:assertTrue(contains(text, "item object:1:4 = [Favorite] Linen Cloth"), text)
        t:assertTrue(contains(text, "item object:0:2 = Wool Cloth"), text)
    end,

    ["an item no vendor buys is not marked as junk, but can be a favorite"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 6948, "Hearthstone", { hasNoValue = true }))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        t:assertEqual(world.spoken[#world.spoken], "Hearthstone cannot be sold to a vendor.")
        t:assertFalse(contains(world.render(), "[Junk]"))
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        t:assertEqual(world.spoken[#world.spoken], "Hearthstone: marked as favorite")
    end,

    ["an empty slot says it is empty"] = function(t)
        local world = newWorld()
        local button = world.add(0, 1, 2589, "Linen Cloth")
        tinsert(world.slots, button)
        world.render()
        local node = world.lastNodes["object:0:1"]
        world.items["0:1"] = nil
        bindingFunc(node, "favorite/toggle")()
        t:assertEqual(world.spoken[#world.spoken], "Empty")
    end,

    ["marking silences the live label watch"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        world.graphHost.screen._liveKey = "stale"
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        t:assertNil(world.graphHost.screen._liveKey)
    end,

    ["the slot's menu offers the mark and then the unmark"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        local function entries()
            local out = {}
            world.lastNodes["object:0:1"].contextActions(function(entry)
                tinsert(out, entry)
            end, {})
            return out
        end
        local before = entries()
        t:assertEqual(#before, 2)
        t:assertEqual(before[1].label, "Mark as Favorite")
        t:assertEqual(before[2].label, "Mark as Junk")
        before[1].onActivate()
        t:assertEqual(world.spoken[#world.spoken], "Linen Cloth: marked as favorite")
        t:assertEqual(entries()[1].label, "Unmark as Favorite")
    end,

    ["a bag slot button outside the item slots is left alone"] = function(t)
        local world = newWorld()
        local button = world.add(0, 1, 2589, "Linen Cloth")
        local node = world.containers.itemSlotNode(button, "Bag Slot Backpack", {})
        t:assertEqual(#node.bindings, 0)
        t:assertEqual(node.label, "Bag Slot Backpack")
    end,

    ["switching a part off removes its tag and key"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        world.ns.handleCommand("favorites off")
        local text = world.render()
        t:assertTrue(contains(text, "item object:0:1 = Linen Cloth"), text)
        t:assertNil(bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle"))
        world.ns.handleCommand("favorites on")
        t:assertTrue(contains(world.render(), "[Favorite] Linen Cloth"), "the mark is still there")
    end,

    ["in French the tags and the speech are French"] = function(t)
        local world = newWorld({ locale = "frFR" })
        tinsert(world.slots, world.add(0, 1, 2589, "Toile de lin"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        t:assertEqual(world.spoken[#world.spoken], "Toile de lin : marqué comme camelote")
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        t:assertEqual(world.spoken[#world.spoken], "Toile de lin : marqué comme favori")
        t:assertTrue(contains(world.render(), "[Favori] [Camelote] Toile de lin"))
    end,
})

runner:addSuite("Item Lists", {
    ["nothing to list means no stop"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        local text = world.render()
        t:assertFalse(contains(text, "STOP lists"), text)
    end,

    ["the stop has a category per list that has something: the new items, then what is for a merchant"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        tinsert(world.slots, world.add(1, 1, 4306, "Silk Cloth"))
        world.vendor["0:1"] = "vendor"
        world.flagged["0:2"] = true
        local out = lines(world.render())
        local start = stopIndex(out, "STOP lists")
        t:assertEqual(out[start + 1], "context lists: Item Lists")
        t:assertEqual(out[start + 2], "GROUP New Items (1) [open]")
        t:assertEqual(out[start + 3], "item structural:list:new:0:2 = Wool Cloth")
        t:assertEqual(out[start + 4], "GROUP For sale to a merchant [closed]", "named just so, without a count")
        t:assertEqual(out[start + 5], "STOP frame:ContainerFrameCombinedBags:search", "no other category: none for the junk, none for the favorites")
    end,

    ["the merchant category is named without a count, the others keep theirs"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        tinsert(world.slots, world.add(1, 1, 4306, "Silk Cloth"))
        world.vendor["0:1"] = "vendor"
        world.vendor["1:1"] = "vendor"
        world.flagged["0:2"] = true
        world.ns.lists.register({ key = "plain", label = "Plain", order = 30, select = function(buttons)
            return { buttons[1], buttons[2] }
        end })
        local text = world.render()
        t:assertTrue(contains(text, "GROUP New Items (1) [open]"), text)
        t:assertTrue(contains(text, "GROUP For sale to a merchant [closed]"), text)
        t:assertFalse(contains(text, "For sale to a merchant ("), text)
        t:assertTrue(contains(text, "GROUP Plain (2) [closed]"), "a list that does not ask keeps its count: " .. text)
    end,

    ["the junk and the favorites have no category of their own any more, whatever is marked"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        tinsert(world.slots, world.add(1, 1, 4306, "Silk Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        bindingFunc(world.lastNodes["object:1:1"], "favorite/toggle")()
        world.flagged["0:1"] = true
        local text = world.render()
        t:assertFalse(contains(text, "GROUP Junk"), text)
        t:assertFalse(contains(text, "GROUP Favorites"), text)
        t:assertFalse(contains(text, "list:junk"), text)
        t:assertFalse(contains(text, "list:favorites"), text)
        -- the marks are still there, said ahead of the names in the bags
        t:assertTrue(contains(text, "item object:0:1 = [Junk] Linen Cloth"), text)
        t:assertTrue(contains(text, "item object:1:1 = [Favorite] Silk Cloth"), text)
        local keys = {}
        for _, list in ipairs(world.ns.lists.lists) do
            tinsert(keys, list.key)
        end
        t:assertEqual(table.concat(keys, ","), "new,merchant")
    end,

    ["opening the bags lands on their items: the lists stop is not the first"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.flagged["0:1"] = true
        local out = lines(world.render())
        t:assertEqual(out[1], "STOP frame:ContainerFrameCombinedBags:grid")
        t:assertTrue(stopIndex(out, "STOP lists") > 1)
    end,

    ["in the combined bag the lists come after the items and the bag slots, before the search box"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.flagged["0:1"] = true
        t:assertEqual(
            stops(lines(world.render())),
            "frame:ContainerFrameCombinedBags:grid,frame:ContainerFrameCombinedBags:bagSlots,lists,"
                .. "frame:ContainerFrameCombinedBags:search,frame:ContainerFrameCombinedBags:controls"
        )
    end,

    ["with one frame per bag the lists come after every bag"] = function(t)
        local world = newWorld({ mode = "individual" })
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.flagged["0:1"] = true
        t:assertEqual(stops(lines(world.render())), "bag:0,frame:ContainerFrame1:controls,bag:1,lists")
    end,

    ["a combined bag without a search box or controls gets the lists last"] = function(t)
        local world = newWorld({ noControls = true })
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.flagged["0:1"] = true
        t:assertEqual(
            stops(lines(world.render())),
            "frame:ContainerFrameCombinedBags:grid,frame:ContainerFrameCombinedBags:bagSlots,lists"
        )
    end,

    ["when WowVision draws the controls and the search box before the bags, the lists are still after the bags"] = function(t)
        local world = newWorld({ controlsFirst = true })
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.flagged["0:1"] = true
        t:assertEqual(
            stops(lines(world.render())),
            "frame:ContainerFrameCombinedBags:controls,frame:ContainerFrameCombinedBags:search,"
                .. "frame:ContainerFrameCombinedBags:grid,frame:ContainerFrameCombinedBags:bagSlots,lists"
        )
    end,

    ["the bags' stops are unchanged when there is nothing to list"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        t:assertEqual(
            stops(lines(world.render())),
            "frame:ContainerFrameCombinedBags:grid,frame:ContainerFrameCombinedBags:bagSlots,"
                .. "frame:ContainerFrameCombinedBags:search,frame:ContainerFrameCombinedBags:controls"
        )
    end,

    ["the builder is the way it was after the bags are drawn"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        local before = rawget(world.builder, "beginStop")
        world.render()
        world.flagged["0:1"] = true
        world.render()
        t:assertEqual(rawget(world.builder, "beginStop"), before)
    end,

    ["a bags drawing that fails is passed on and leaves the builder alone"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        local before = rawget(world.builder, "beginStop")
        local ok = pcall(world.ns.withListsAfterBags, world.builder, function()
            error("bags broke")
        end)
        t:assertFalse(ok)
        t:assertEqual(rawget(world.builder, "beginStop"), before)
    end,

    ["a closed category opens with its items tagged, in the bags' order"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(1, 1, 4306, "Silk Cloth"))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.vendor["0:1"] = "vendor"
        world.vendor["0:2"] = "vendor"
        world.vendor["1:1"] = "vendor"
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        world.builder.expansion["structural:list:merchant"] = true
        local text = world.render()
        local first = text:find("item structural:list:merchant:0:1 = [Junk] Linen Cloth", 1, true)
        local second = text:find("item structural:list:merchant:0:2 = Wool Cloth", 1, true)
        local third = text:find("item structural:list:merchant:1:1 = Silk Cloth", 1, true)
        t:assertTrue(first ~= nil and second ~= nil and third ~= nil, text)
        t:assertTrue(first < second and second < third, "bag by bag")
    end,

    ["the merchant category is in French and in German"] = function(t)
        local world = newWorld({ locale = "frFR" })
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 4306, "Soie"))
        world.vendor["0:1"] = "vendor"
        local text = world.render()
        t:assertTrue(contains(text, "context lists: Listes d'objets"), text)
        t:assertTrue(contains(text, "GROUP À vendre au marchand [closed]"), text)
        world = newWorld({ locale = "deDE" })
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 4306, "Seide"))
        world.vendor["0:1"] = "vendor"
        text = world.render()
        t:assertTrue(contains(text, "GROUP Zum Verkauf beim Händler [closed]"), text)
    end,

    ["what is in the auction house tab is not in the merchant category"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        tinsert(world.slots, world.add(0, 3, 4306, "Silk Cloth"))
        world.vendor["0:1"] = "auction"
        world.vendor["0:2"] = "vendor"
        -- (0, 3) is neither: nothing a vendor buys
        world.builder.expansion["structural:list:merchant"] = true
        local text = world.render()
        t:assertTrue(contains(text, "GROUP For sale to a merchant [open]"), text)
        t:assertTrue(contains(text, "list:merchant:0:2 = Wool Cloth"), text)
        t:assertFalse(contains(text, "list:merchant:0:1"), "an auction house item")
        t:assertFalse(contains(text, "list:merchant:0:3"), "nothing a vendor buys")
    end,

    ["a favorite is not offered for sale, even with the favorites switched off"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        world.vendor["0:1"] = "vendor"
        world.vendor["0:2"] = "vendor"
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        world.builder.expansion["structural:list:merchant"] = true
        local text = world.render()
        t:assertTrue(contains(text, "GROUP For sale to a merchant [open]"), text)
        t:assertFalse(contains(text, "list:merchant:0:1"), text)
        t:assertTrue(contains(text, "list:merchant:0:2"), text)
        world.ns.favorites:setEnabled(false)
        text = world.render()
        t:assertFalse(contains(text, "list:merchant:0:1"), "still kept out with the favorites off")
        t:assertTrue(contains(text, "list:merchant:0:2"))
        -- taking the favorite off puts it back
        world.ns.favorites:setEnabled(true)
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        t:assertTrue(contains(world.render(), "list:merchant:0:1"))
    end,

    ["one line per item in the merchant category, however many stacks, on the first stack"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(1, 1, 2589, "Linen Cloth", { stackCount = 2 }))
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { stackCount = 5 }))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        world.vendor["0:1"] = "vendor"
        world.vendor["1:1"] = "vendor"
        world.vendor["0:2"] = "vendor"
        world.builder.expansion["structural:list:merchant"] = true
        local text = world.render()
        t:assertTrue(contains(text, "GROUP For sale to a merchant [open]"), text)
        t:assertFalse(contains(text, "GROUP For sale to a merchant ("), "no count: " .. text)
        t:assertTrue(contains(text, "item structural:list:merchant:0:1 = Linen Cloth, 7 in 2 stacks"), text)
        t:assertTrue(contains(text, "item structural:list:merchant:0:2 = Wool Cloth"), text)
        t:assertFalse(contains(text, "list:merchant:1:1"), "the second stack has no line of its own")
        -- the line is the first stack's slot: the bags' lowest bag and slot
        t:assertEqual(#world.partitioned, 3, "all three slots were asked about")
    end,

    ["a line read after a stack changed is the bags' own label of its first stack"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { stackCount = 5 }))
        tinsert(world.slots, world.add(1, 1, 2589, "Linen Cloth", { stackCount = 2 }))
        world.vendor["0:1"] = "vendor"
        world.vendor["1:1"] = "vendor"
        world.builder.expansion["structural:list:merchant"] = true
        local text = world.render()
        t:assertTrue(contains(text, "list:merchant:0:1 = Linen Cloth, 7 in 2 stacks"), text)
        local label = world.lastNodes["structural:list:merchant:0:1"].label
        t:assertEqual(label(), "Linen Cloth, 7 in 2 stacks")
        world.items["1:1"].stackCount = 3
        local changed = label()
        t:assertFalse(contains(changed, "in 2 stacks"), changed)
        t:assertTrue(contains(changed, "Linen Cloth"), changed)
        world.items["1:1"].stackCount = 2
        t:assertEqual(label(), "Linen Cloth, 7 in 2 stacks", "back as it was")
        world.items["1:1"] = nil
        t:assertFalse(contains(label(), "in 2 stacks"), "a stack gone")
        world.items["1:1"] = { itemID = 4306, itemName = "Silk Cloth", hyperlink = "|cffffffff|Hitem:4306::::::::60:::::::::|h[Silk Cloth]|h|r", quality = 1, stackCount = 2, hasNoValue = false, isLocked = false }
        t:assertFalse(contains(label(), "in 2 stacks"), "another item in the stack")
    end,

    ["the tags of the marks go ahead of a merchant line, and a favorite item has no line"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { stackCount = 5 }))
        tinsert(world.slots, world.add(1, 1, 2589, "Linen Cloth", { stackCount = 2 }))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth", { stackCount = 4 }))
        tinsert(world.slots, world.add(0, 3, 2592, "Wool Cloth", { stackCount = 1 }))
        for _, key in ipairs({ "0:1", "1:1", "0:2", "0:3" }) do
            world.vendor[key] = "vendor"
        end
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        bindingFunc(world.lastNodes["object:0:2"], "favorite/toggle")()
        world.builder.expansion["structural:list:merchant"] = true
        local text = world.render()
        t:assertTrue(contains(text, "list:merchant:0:1 = [Junk] Linen Cloth, 7 in 2 stacks"), text)
        t:assertFalse(contains(text, "Wool Cloth, 5"), "every stack of the favorite is out: " .. text)
        t:assertFalse(contains(text, "list:merchant:0:2"), text)
        t:assertFalse(contains(text, "list:merchant:0:3"), text)
        t:assertTrue(contains(text, "GROUP For sale to a merchant [open]"), text)
        -- none of the favorite's slots was asked about
        for _, position in ipairs(world.partitioned) do
            t:assertFalse(position.bag == 0 and (position.slot == 2 or position.slot == 3), "a favorite's slot was asked about")
        end
    end,

    ["an answer without the merchant lines is no category and no error"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.vendor["0:1"] = "vendor"
        local partition = WowVisionAuctionHints.partition
        WowVisionAuctionHints.partition = function(positions)
            local answer = partition(positions)
            answer.merchantLines = nil
            return answer
        end
        t:assertFalse(contains(world.render(), "For sale to a merchant"))
        t:assertEqual(#world.errors, 0)
    end,

    ["a list's own sentence that fails falls back to the bags' label, once reported"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.ns.lists.register({
            key = "described",
            label = "Described",
            order = 5,
            select = function(buttons)
                return { buttons[1] }
            end,
            describe = function()
                error("describe broke")
            end,
        })
        world.builder.expansion["structural:list:described"] = true
        local text = world.render()
        t:assertTrue(contains(text, "item structural:list:described:0:1 = Linen Cloth"), text)
        world.render()
        t:assertEqual(#world.errors, 1, "once")
        t:assertTrue(contains(world.errors[1], "describe broke"), world.errors[1])
    end,

    ["a list's own sentence is used ahead of the bags' label"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.ns.lists.register({
            key = "described",
            label = "Described",
            order = 5,
            select = function(buttons)
                return { buttons[1] }
            end,
            describe = function()
                return function()
                    return "My own sentence"
                end
            end,
        })
        world.builder.expansion["structural:list:described"] = true
        t:assertTrue(contains(world.render(), "item structural:list:described:0:1 = My own sentence"))
    end,

    ["an older answer without lines (version 1) is not used"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.vendor["0:1"] = "vendor"
        WowVisionAuctionHints.version = 1
        t:assertFalse(contains(world.render(), "For sale to a merchant"))
        WowVisionAuctionHints.version = 2
        WowVisionAuctionHints.version = nil
        t:assertFalse(contains(world.render(), "For sale to a merchant"), "no version")
        WowVisionAuctionHints.version = 2
        t:assertTrue(contains(world.render(), "For sale to a merchant"))
    end,

    ["a junk mark does not take an item out of the merchant category"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.vendor["0:1"] = "vendor"
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        world.builder.expansion["structural:list:merchant"] = true
        t:assertTrue(contains(world.render(), "list:merchant:0:1 = [Junk] Linen Cloth"))
    end,

    ["only the carried bags are asked about"] = function(t)
        local world = newWorld()
        world.installHints()
        world.vendor["6:1"] = "vendor"
        world.vendor["0:1"] = "vendor"
        local asked = {}
        local api = WowVisionAuctionHints.partition
        WowVisionAuctionHints.partition = function(positions)
            for _, position in ipairs(positions) do
                tinsert(asked, position.bag .. ":" .. position.slot)
            end
            return api(positions)
        end
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        tinsert(world.slots, world.add(6, 1, 2592, "Bank Cloth"))
        local selected = world.ns.merchantList(world.slots)
        t:assertEqual(table.concat(asked, ","), "0:1")
        t:assertEqual(#selected, 1)
        t:assertEqual(selected[1], world.slots[1])
    end,

    ["without WowVision_AuctionHints the merchant category is empty and the stop shows what else it has"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        local text = world.render()
        t:assertFalse(contains(text, "STOP lists"), text)
        world.flagged["0:1"] = true
        text = world.render()
        t:assertTrue(contains(text, "GROUP New Items (1)"), text)
        t:assertFalse(contains(text, "For sale to a merchant"), text)
        -- a global without the call is no answer either
        WowVisionAuctionHints = { version = 2 }
        text = world.render()
        t:assertFalse(contains(text, "For sale to a merchant"), text)
        t:assertEqual(#world.errors, 0, "a global without the call is not an error, it is nothing to ask")
        WowVisionAuctionHints = nil
    end,

    ["no answer (in combat) leaves the category empty; an answer that fails is reported once"] = function(t)
        local world = newWorld()
        world.installHints()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.vendor["0:1"] = "vendor"
        world.partitionNil = true
        t:assertFalse(contains(world.render(), "STOP lists"))
        t:assertEqual(#world.errors, 0, "no answer is not an error")
        world.partitionNil = false
        t:assertTrue(contains(world.render(), "GROUP For sale to a merchant [closed]"))
        WowVisionAuctionHints.partition = function()
            error("hints broke")
        end
        local text = world.render()
        t:assertTrue(contains(text, "item object:0:1 = Linen Cloth"), "the bags are fine")
        world.render()
        t:assertEqual(#world.errors, 1, "once")
    end,

    ["a new item stays listed after the game clears its flag, until the bags close"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.flagged["0:1"] = true
        t:assertTrue(contains(world.render(), "GROUP New Items (1)"))
        world.flagged = {}
        t:assertTrue(contains(world.render(), "GROUP New Items (1)"))
        world.open = false
        t:assertFalse(world.Bags:isOpen())
        world.open = true
        t:assertFalse(contains(world.render(), "New Items"), "closing the bags is looking at them")
    end,

    ["a failing list does not take the bags down"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.ns.lists.register({
            key = "bad",
            label = "Bad",
            order = 1,
            select = function()
                error("boom")
            end,
        })
        local text = world.render()
        t:assertTrue(contains(text, "item object:0:1 = Linen Cloth"), text)
        t:assertEqual(#world.errors, 1)
    end,
})

runner:addSuite("Sale", {
    setup = nil,

    ["the merchant sells the marked junk and says what went"] = function(t)
        local world = newWorld()
        world.items["0:1"] = nil
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { stackCount = 5 }))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(table.concat(world.sold, ","), "0:1")
        t:assertEqual(world.spoken[#world.spoken], "Sold marked junk for 0 copper: Linen Cloth.")
        t:assertEqual(world.merchantEvents, 1, "WowVision's own handler still runs")
    end,

    ["a favorite is never sold, even marked as junk too"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(#world.sold, 0)
        world.ns.handleCommand("favorites off")
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(#world.sold, 0, "switched off, it is still kept")
    end,

    ["other events start no sale"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        world.merchant:onEvent("BAG_UPDATE")
        t:assertEqual(#world.sold, 0)
    end,

    ["nothing marked, nothing sold, nothing said"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { quality = 0 }))
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(#world.sold, 0)
        t:assertEqual(#world.spoken, 0)
    end,

    ["selling can be switched off"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        world.ns.handleCommand("sell off")
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(#world.sold, 0)
        world.ns.handleCommand("sell on")
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(#world.sold, 1)
    end,

    ["the German words nein and ja switch selling too"] = function(t)
        local world = newWorld({ locale = "deDE" })
        tinsert(world.slots, world.add(0, 1, 2589, "Leinenstoff"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        world.ns.handleCommand("verkauf nein")
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(#world.sold, 0)
        world.ns.handleCommand("verkauf ja")
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(#world.sold, 1)
    end,

    ["a marked grey item is left to WowVision when it sells grey items itself"] = function(t)
        local world = newWorld({ poorSetting = true })
        tinsert(world.slots, world.add(0, 1, 2589, "Torn Rag", { quality = 0 }))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        bindingFunc(world.lastNodes["object:0:2"], "junk/toggle")()
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(table.concat(world.sold, ","), "0:2")
    end,

    ["bags the player does not carry are not sold from"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        world.add(9, 1, 2589, "Linen Cloth")
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(table.concat(world.sold, ","), "0:1")
    end,

    ["a failing sale is reported and the merchant window still works"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "junk/toggle")()
        C_Container.UseContainerItem = function()
            error("no merchant")
        end
        world.merchant:onEvent("MERCHANT_SHOW")
        t:assertEqual(#world.errors, 1)
        t:assertEqual(world.merchantEvents, 1)
    end,
})

runner:addSuite("Marks", {
    ["marks from the old WowVision module are brought over once"] = function(t)
        local world = newWorld({
            savedDB = {
                submodules = {
                    windows = { submodules = { junk = { data = { marks = { ["2589"] = "Linen Cloth" } } } } },
                },
            },
        })
        t:assertEqual(world.ns.section("junk").marks["2589"], "Linen Cloth")
        t:assertTrue(WowVisionBagsDB.imported)
        -- forgotten, they do not come back
        world.ns.junk:forget()
        local again = loadfile(addonDir .. "/Main.lua")
        again("WowVision_Bags", world.ns)
        t:assertNil(world.ns.section("junk").marks["2589"])
    end,

    ["the marks are kept per character in WowVisionBagsDB"] = function(t)
        local saved = { favorites = { marks = { ["2589"] = "Linen Cloth" } }, imported = true }
        local world = newWorld({ bagsDB = saved })
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        t:assertTrue(contains(world.render(), "[Favorite] Linen Cloth"))
    end,

    ["the table the client hands over later is the one used"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        WowVisionBagsDB = { favorites = { marks = {} }, imported = true }
        t:assertFalse(contains(world.render(), "[Favorite]"))
    end,

    ["forgetting takes every mark off"] = function(t)
        local world = newWorld()
        tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
        tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
        world.render()
        bindingFunc(world.lastNodes["object:0:1"], "favorite/toggle")()
        bindingFunc(world.lastNodes["object:0:2"], "favorite/toggle")()
        world.ns.handleCommand("forget favorites")
        t:assertEqual(world.spoken[#world.spoken], "Favorites forgotten")
        t:assertFalse(contains(world.render(), "[Favorite]"))
    end,

    ["/wvbags says where things stand"] = function(t)
        local world = newWorld()
        world.ns.handleCommand("")
        local said = world.spoken[#world.spoken]
        t:assertTrue(contains(said, "Junk marks: on"), said)
        t:assertTrue(contains(said, "Selling marked junk at merchants: on"), said)
        t:assertTrue(contains(said, "Favorites marks: on"), said)
    end,

    ["/wvbags understands French"] = function(t)
        local world = newWorld({ locale = "frFR" })
        world.ns.handleCommand("favoris non")
        t:assertEqual(world.spoken[#world.spoken], "Marques de favoris : désactivé")
        world.ns.handleCommand("oublier camelote")
        t:assertEqual(world.spoken[#world.spoken], "Marques de camelote oubliées")
    end,
})


-- ------------------------------------------------- the items that arrive

-- Runs body(world, clock) with a game clock the test moves. The addon's own state is wiped around it.
local function withClock(config, body)
    local world = newWorld(config)
    local savedClock, savedFrame, savedItem = GetTime, CreateFrame, C_Item
    local clock = { now = 100 }
    GetTime = function()
        return clock.now
    end
    local newItems = world.ns.newItems
    newItems.restart()
    local ok, err = pcall(body, world, clock, newItems)
    newItems.restart()
    GetTime, CreateFrame, C_Item = savedClock, savedFrame, savedItem
    if not ok then
        error(err, 0)
    end
end

local function login(newItems, clock)
    newItems.onEvent("PLAYER_ENTERING_WORLD", true, false)
    clock.now = clock.now + 10 -- past the time the game takes to fill the bags in
end

-- Gets an item into the bags and tells the addon, as the game would.
local function receive(world, newItems, clock, bag, slot, id, name, extra)
    local itemButton = world.add(bag, slot, id, name, extra)
    local known = false
    for _, existing in ipairs(world.slots) do
        if existing == itemButton then
            known = true
        end
    end
    if not known then
        tinsert(world.slots, itemButton)
    end
    clock.now = clock.now + 1
    newItems.onEvent("BAG_UPDATE_DELAYED")
    return itemButton
end

runner:addSuite("Arrivals", {
    ["a quest reward the game does not flag is a new item"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            receive(world, newItems, clock, 0, 2, 6948, "Quest Sword")
            local text = world.render()
            t:assertTrue(contains(text, "GROUP New Items (1) [open]"), text)
            t:assertTrue(contains(text, "item structural:list:new:0:2 = Quest Sword"), text)
            t:assertFalse(contains(text, "list:new:0:1"), "what was there before is not new")
        end)
    end,

    ["what the bags held when the game was entered is not new"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            newItems.onEvent("PLAYER_ENTERING_WORLD", true, false)
            -- the game fills in more of the bags just after: still the same bags
            receive(world, newItems, clock, 0, 2, 2592, "Wool Cloth")
            receive(world, newItems, clock, 0, 3, 4306, "Silk Cloth")
            clock.now = clock.now + 10
            newItems.onEvent("BAG_UPDATE_DELAYED")
            t:assertFalse(contains(world.render(), "STOP lists"))
        end)
    end,

    ["a stack that grows is new"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { stackCount = 3 }))
            login(newItems, clock)
            receive(world, newItems, clock, 0, 1, 2589, "Linen Cloth", { stackCount = 5 })
            t:assertTrue(contains(world.render(), "item structural:list:new:0:1 = Linen Cloth"))
        end)
    end,

    ["every slot that holds the new item is listed"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { stackCount = 20 }))
            tinsert(world.slots, world.add(1, 4, 2589, "Linen Cloth", { stackCount = 3 }))
            login(newItems, clock)
            receive(world, newItems, clock, 1, 4, 2589, "Linen Cloth", { stackCount = 4 })
            local text = world.render()
            t:assertTrue(contains(text, "GROUP New Items (2)"), text)
        end)
    end,

    ["moving and sorting items arrive nothing"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { stackCount = 3 }))
            tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
            login(newItems, clock)
            -- swapped, and the first one moved to another bag
            world.items["0:1"], world.items["0:2"] = world.items["0:2"], world.items["0:1"]
            clock.now = clock.now + 1
            newItems.onEvent("BAG_UPDATE_DELAYED")
            world.items["1:3"] = world.items["0:2"]
            world.items["0:2"] = nil
            clock.now = clock.now + 1
            newItems.onEvent("BAG_UPDATE_DELAYED")
            t:assertEqual(#newItems.arrivedIDs(), 0)
        end)
    end,

    ["using or selling part of a stack arrives nothing"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { stackCount = 10 }))
            login(newItems, clock)
            receive(world, newItems, clock, 0, 1, 2589, "Linen Cloth", { stackCount = 4 })
            t:assertEqual(#newItems.arrivedIDs(), 0)
        end)
    end,

    ["splitting a stack arrives nothing"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth", { stackCount = 10 }))
            login(newItems, clock)
            world.items["0:1"].stackCount = 6
            receive(world, newItems, clock, 0, 2, 2589, "Linen Cloth", { stackCount = 4 })
            t:assertEqual(#newItems.arrivedIDs(), 0)
        end)
    end,

    ["an arrival waits while the bags are closed, and goes once they were open and closed"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            world.open = false
            receive(world, newItems, clock, 0, 2, 6948, "Quest Sword")
            -- the window asks whether the bags are open all the time they are not
            world.Bags:isOpen()
            world.Bags:isOpen()
            t:assertEqual(#newItems.arrivedIDs(), 1, "still waiting")
            world.open = true
            t:assertTrue(contains(world.render(), "list:new:0:2"))
            world.open = false
            world.Bags:isOpen()
            world.open = true
            t:assertFalse(contains(world.render(), "STOP lists"), "looked at")
        end)
    end,

    ["an arrival that arrives while the bags are open is listed at once"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            t:assertFalse(contains(world.render(), "STOP lists"))
            receive(world, newItems, clock, 0, 2, 6948, "Quest Sword")
            t:assertTrue(contains(world.render(), "list:new:0:2"))
        end)
    end,

    ["an item that is gone and comes back is a new arrival again"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            receive(world, newItems, clock, 0, 2, 6948, "Quest Sword")
            t:assertEqual(#newItems.arrivedIDs(), 1)
            world.items["0:2"] = nil -- handed in
            clock.now = clock.now + 1
            newItems.onEvent("BAG_UPDATE_DELAYED")
            t:assertEqual(#newItems.arrivedIDs(), 0)
            receive(world, newItems, clock, 0, 2, 6948, "Quest Sword")
            t:assertEqual(#newItems.arrivedIDs(), 1)
        end)
    end,

    ["a loading screen only waits: the bags filling in again are not an arrival"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            newItems.onEvent("PLAYER_ENTERING_WORLD", false, false)
            receive(world, newItems, clock, 0, 2, 2592, "Wool Cloth") -- within the wait
            t:assertEqual(#newItems.arrivedIDs(), 0)
            clock.now = clock.now + 5
            receive(world, newItems, clock, 0, 3, 4306, "Silk Cloth")
            t:assertEqual(#newItems.arrivedIDs(), 1)
        end)
    end,

    ["a loading screen does not wipe what arrived before it"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            receive(world, newItems, clock, 0, 2, 6948, "Quest Sword")
            newItems.onEvent("PLAYER_ENTERING_WORLD", false, false)
            t:assertEqual(#newItems.arrivedIDs(), 1)
        end)
    end,

    ["a reload starts over"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            receive(world, newItems, clock, 0, 2, 6948, "Quest Sword")
            newItems.onEvent("PLAYER_ENTERING_WORLD", false, true)
            t:assertEqual(#newItems.arrivedIDs(), 0)
        end)
    end,

    ["the game's flag still counts, next to the arrivals"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            tinsert(world.slots, world.add(0, 2, 2592, "Wool Cloth"))
            login(newItems, clock)
            world.flagged["0:1"] = true
            receive(world, newItems, clock, 0, 3, 6948, "Quest Sword")
            local text = world.render()
            t:assertTrue(contains(text, "GROUP New Items (2)"), text)
            t:assertFalse(contains(text, "list:new:0:2"))
        end)
    end,

    ["bags that cannot be read arrive nothing and break nothing"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            local info = C_Container.GetContainerItemInfo
            C_Container.GetContainerItemInfo = function()
                error("bags unavailable")
            end
            clock.now = clock.now + 1
            newItems.onEvent("BAG_UPDATE_DELAYED")
            C_Container.GetContainerItemInfo = info
            t:assertEqual(#newItems.arrivedIDs(), 0)
            t:assertEqual(#world.errors, 0)
            C_Container.GetContainerNumSlots = nil
            newItems.onEvent("BAG_UPDATE_DELAYED")
            t:assertEqual(#world.errors, 0)
        end)
    end,

    ["the addon listens to the bags and to entering the world"] = function(t)
        withClock(nil, function(world, clock, newItems)
            local registered, handler = {}, nil
            CreateFrame = function()
                return {
                    RegisterEvent = function(_, event)
                        registered[event] = true
                    end,
                    SetScript = function(_, name, fn)
                        if name == "OnEvent" then
                            handler = fn
                        end
                    end,
                }
            end
            newItems.frame = nil
            t:assertTrue(newItems.watch())
            t:assertTrue(registered.PLAYER_ENTERING_WORLD)
            t:assertTrue(registered.BAG_UPDATE_DELAYED)
            t:assertFalse(newItems.watch(), "once")
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            handler(nil, "PLAYER_ENTERING_WORLD", true, false)
            clock.now = clock.now + 10
            local button = world.add(0, 2, 6948, "Quest Sword")
            tinsert(world.slots, button)
            handler(nil, "BAG_UPDATE_DELAYED")
            t:assertEqual(#newItems.arrivedIDs(), 1)
            newItems.frame = nil
        end)
    end,

    ["events that are not the bags' change arrive nothing"] = function(t)
        withClock(nil, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            world.add(0, 2, 6948, "Quest Sword")
            clock.now = clock.now + 1
            newItems.onEvent("BAG_UPDATE")
            newItems.onEvent("MERCHANT_SHOW")
            t:assertEqual(#newItems.arrivedIDs(), 0)
            newItems.onEvent("BAG_UPDATE_DELAYED")
            t:assertEqual(#newItems.arrivedIDs(), 1)
        end)
    end,

    ["the addon starts listening when it installs, unless WowVision has its own lists"] = function(t)
        local saved = CreateFrame
        local frames = 0
        CreateFrame = function()
            frames = frames + 1
            return { RegisterEvent = function() end, SetScript = function() end }
        end
        local world = newWorld()
        t:assertEqual(frames, 1)
        t:assertNotNil(world.ns.newItems.frame)
        frames = 0
        local own = newWorld({ coreHasLists = true })
        CreateFrame = saved
        t:assertEqual(frames, 0)
        t:assertNil(own.ns.newItems.frame)
    end,

    ["/wvbags new names what arrived"] = function(t)
        withClock(nil, function(world, clock, newItems)
            C_Item = { GetItemNameByID = function(id)
                return ({ [6948] = "Quest Sword", [2592] = "Wool Cloth" })[id]
            end }
            tinsert(world.slots, world.add(0, 1, 2589, "Linen Cloth"))
            login(newItems, clock)
            world.ns.handleCommand("new")
            t:assertEqual(world.spoken[#world.spoken], "No new item followed.")
            receive(world, newItems, clock, 0, 2, 6948, "Quest Sword")
            receive(world, newItems, clock, 0, 3, 2592, "Wool Cloth")
            world.ns.handleCommand("new")
            t:assertEqual(world.spoken[#world.spoken], "New items followed: Wool Cloth, Quest Sword.")
        end)
    end,

    ["/wvbags new speaks French and German, and cuts a long list"] = function(t)
        withClock({ locale = "frFR" }, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Toile de lin"))
            login(newItems, clock)
            world.ns.handleCommand("nouveaux")
            t:assertEqual(world.spoken[#world.spoken], "Aucun nouvel objet suivi.")
            for id = 1, 10 do
                receive(world, newItems, clock, 0, 1 + id, 1000 + id, "Objet " .. id)
            end
            world.ns.handleCommand("nouveaux")
            local said = world.spoken[#world.spoken]
            t:assertTrue(contains(said, "Nouveaux objets suivis : "), said)
            t:assertTrue(contains(said, " et 2 autres"), said)
        end)
        withClock({ locale = "deDE" }, function(world, clock, newItems)
            tinsert(world.slots, world.add(0, 1, 2589, "Leinenstoff"))
            login(newItems, clock)
            world.ns.handleCommand("neue")
            t:assertEqual(world.spoken[#world.spoken], "Kein neuer Gegenstand verfolgt.")
        end)
    end,
})
runner:run()
