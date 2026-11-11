-- The glue to WowVision, in four small hooks. None of them changes a WowVision file: each wraps a function that
-- WowVision looks up again every time it is used (a field of a module or of a class), so the wrapper is reached
-- from everywhere that function is. Each hook installs on its own, and one that cannot (WowVision changed what it
-- hooks) is reported once and leaves the others working.
local _, ns = ...
local L = ns.L

local reported = {}

-- An error here must never break the bags, and must not repeat on every key press either: report each distinct
-- message once.
function ns.report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_Bags: " .. err)
end
local report = ns.report

local function containersModule()
    local windows = WowVision ~= nil and WowVision.base ~= nil and WowVision.base.windows or nil
    return windows ~= nil and windows.containers or nil
end

-- The bags' own way to read an item button's bag and slot id.
function ns.locate(itemButton)
    return containersModule().slotLocation(itemButton)
end

-- ----------------------------------------------------------- 1. the slots

-- How many of the bags' slot renderings are under way: only the item slots they draw are tagged and decorated
-- (the bag slot buttons, which use the same node function, are not).
local decorating = 0

function ns.withDecoration(fn, ...)
    decorating = decorating + 1
    local ok, a, b = pcall(fn, ...)
    decorating = decorating - 1
    if not ok then
        error(a, 0)
    end
    return a, b
end

-- Every item slot of the bags and the bank says its marks ahead of its name ("[Favorite] [Junk] Linen Cloth") and
-- carries the marking keys and menu entries. WowVision builds an item slot in containers.itemSlotNode and draws the
-- slots of a bag in containers.renderSlots; both are looked up on the module at the time, so both can be wrapped.
function ns.installSlots()
    local containers = containersModule()
    if containers == nil or type(containers.itemSlotNode) ~= "function" or type(containers.renderSlots) ~= "function" then
        return false
    end
    if containers.bagsExtensionSlots then
        return true
    end
    containers.bagsExtensionSlots = true

    local nodeOriginal = containers.itemSlotNode
    containers.itemSlotNode = function(itemButton, label, clickLabels, ...)
        if decorating == 0 then
            return nodeOriginal(itemButton, label, clickLabels, ...)
        end
        local function locate()
            return containers.slotLocation(itemButton)
        end
        local function tagged()
            local text = label
            if type(label) == "function" then
                text = label()
            end
            -- the last part's tag goes on first, so the first part's is the first said
            for index = #ns.parts, 1, -1 do
                text = ns.parts[index]:tagLabel(text, locate())
            end
            return text
        end
        local vtable = nodeOriginal(itemButton, tagged, clickLabels, ...)
        for _, part in ipairs(ns.parts) do
            local ok, decorated = pcall(part.decorateSlot, part, vtable, locate)
            if ok then
                vtable = decorated
            else
                report(decorated)
            end
        end
        return vtable
    end

    local renderOriginal = containers.renderSlots
    containers.renderSlots = function(...)
        return ns.withDecoration(renderOriginal, ...)
    end
    return true
end

-- ----------------------------------------------------- 2. the Item Lists stop

local function shownContainerFrames()
    local frames = {}
    if ContainerFrameUtil_EnumerateContainerFrames == nil then
        return frames
    end
    for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
        if frame ~= nil and frame:IsShown() then
            tinsert(frames, frame)
        end
    end
    return frames
end

-- The backpack of an account without an authenticator draws four extra slots that cannot hold anything (the
-- client marks them extended); they are not slots.
local function usableSlot(itemButton)
    if not itemButton:IsShown() then
        return false
    end
    return not (itemButton.IsExtended ~= nil and itemButton:IsExtended())
end

local function bagIdOf(itemButton)
    return itemButton.GetBagID ~= nil and itemButton:GetBagID() or 0
end

-- A slot as the bags read it, with the tags and keys of the marks.
local function listSlotNode(containers, itemButton)
    return ns.withDecoration(containers.itemSlotNode, itemButton, function()
        return containers.getBagItemLabel(itemButton)
    end, containers.itemClickLabels(itemButton))
end

-- Item Lists: a stop of its own right after the bags, with one category per list (the items the game marks as new,
-- the junk, the favorites...; see Lists.lua). A category reads its name and how many items it holds, opens with
-- Right and closes with Left like the scanner's, and lists the slots the way the bags read them. The same slots
-- are also in the bags where they sit; here they have control ids of their own. The stop is only there while some
-- list has something in it.
function ns.renderLists(builder)
    local containers = containersModule()
    local graph = WowVision.graph
    local ControlId = graph.ControlId
    local buttons = {}
    for _, frame in ipairs(shownContainerFrames()) do
        for _, itemButton in ipairs(frame.Items or {}) do
            if usableSlot(itemButton) then
                tinsert(buttons, itemButton)
            end
        end
    end
    local collected = ns.lists.collect(ns.lists.sorted(buttons))
    if #collected == 0 then
        return
    end
    builder:beginStop("lists")
    builder:pushContext("lists", L["Item Lists"])
    for _, entry in ipairs(collected) do
        local list = entry.list
        local id = ControlId.structural("list:" .. list.key)
        -- A list that starts open does so once per time the bags are open: the player may close it, and a
        -- rebuild must not open it again. The builder's expansion set is the screen's own state.
        if list.expanded and not ns.lists.seeded[list.key] and builder.expansion ~= nil then
            builder.expansion[id.key] = true
            ns.lists.seeded[list.key] = true
        end
        builder:beginGroup(id, {
            controlType = graph.controlTypes.group,
            announcements = {
                { text = list.label .. " (" .. #entry.buttons .. ")", kind = graph.kinds.label },
            },
        }, nil, list.expanded)
        for _, itemButton in ipairs(entry.buttons) do
            builder:addItem(
                ControlId.structural("list:" .. list.key .. ":" .. bagIdOf(itemButton) .. ":" .. itemButton:GetID()),
                listSlotNode(containers, itemButton)
            )
        end
        builder:endGroup()
    end
    builder:popContext()
end

local function hasCombinedFrame()
    for _, frame in ipairs(shownContainerFrames()) do
        if frame.IsCombinedBagContainer ~= nil and frame:IsCombinedBagContainer() then
            return true
        end
    end
    return false
end

-- Runs render() -- the bags' own rendering -- and puts the Item Lists stop right after the bags, so that opening
-- the bags lands on their items. The bags draw their stops one after the other. The combined bag ends with its bag
-- slot bar ("...:bagSlots"): the lists go in front of whatever stop comes next (the search box and the controls
-- when they follow the bags, as they do now), or last when nothing does (when WowVision puts them before the
-- bags). With one frame per bag the backpack's controls sit between the bags, so the lists go after everything.
function ns.withListsAfterBags(builder, render)
    local injected = false
    local function inject()
        if injected then
            return
        end
        injected = true
        local ok, err = pcall(ns.renderLists, builder)
        if not ok then
            report(err)
        end
    end

    local watching = hasCombinedFrame()
    local own = rawget(builder, "beginStop")
    if watching then
        local beginStop = builder.beginStop
        local afterBagSlots = false
        builder.beginStop = function(self, key, ...)
            if afterBagSlots then
                inject()
            end
            afterBagSlots = type(key) == "string" and key:find(":bagSlots$") ~= nil and not injected
            return beginStop(self, key, ...)
        end
    end
    local ok, a, b = pcall(render)
    if watching then
        builder.beginStop = own
    end
    if not ok then
        error(a, 0)
    end
    inject()
    return a, b
end

-- The retail bags are one component of WowVision's containers registry; the window asks every component to
-- render itself and to say whether it is open, looking both up on the component each time.
function ns.installLists()
    local registries = WowVision ~= nil and WowVision.components ~= nil and WowVision.components.registries or nil
    local registry = registries ~= nil and registries:get("containers") or nil
    local Bags = registry ~= nil and registry.types ~= nil and registry.types:get("RetailBags") or nil
    if Bags == nil or type(Bags.renderGraph) ~= "function" or type(Bags.isOpen) ~= "function" then
        return false
    end
    if Bags.bagsExtensionLists then
        return true
    end
    Bags.bagsExtensionLists = true

    local renderOriginal = Bags.renderGraph
    Bags.renderGraph = function(self, builder, ...)
        local extra = { ... }
        return ns.withListsAfterBags(builder, function()
            return renderOriginal(self, builder, unpack(extra))
        end)
    end

    local isOpenOriginal = Bags.isOpen
    Bags.isOpen = function(self, ...)
        local open = isOpenOriginal(self, ...)
        if not open then
            -- what was new has been looked at once the bags close
            ns.lists.reset()
        end
        return open
    end
    return true
end

-- --------------------------------------------------------- 3. the merchant

-- The merchant window sells the poor quality items itself when its setting says so, in onEvent on MERCHANT_SHOW.
-- The junk goes first, in a pass of its own; the grey items are left to WowVision's pass.
function ns.installMerchant()
    local windows = WowVision ~= nil and WowVision.base ~= nil and WowVision.base.windows or nil
    local merchant = windows ~= nil and windows.merchant or nil
    if merchant == nil or type(merchant.onEvent) ~= "function" then
        return false
    end
    if merchant.bagsExtensionSale then
        return true
    end
    merchant.bagsExtensionSale = true

    local original = merchant.onEvent
    local selling = false
    merchant.onEvent = function(self, event, ...)
        -- One pass per opening of the window and no more: only MERCHANT_SHOW starts a sale (the bag updates the
        -- sale causes start nothing), and the pass looks at each slot once.
        if event == "MERCHANT_SHOW" and not selling then
            selling = true
            local ok, err = pcall(function()
                local poorIsWowVisions = false
                local settings = self.settings
                if settings ~= nil then
                    local read, value = pcall(function()
                        return settings.autoSellPoorItems
                    end)
                    poorIsWowVisions = read and value == true
                end
                local result = ns.sellJunk(poorIsWowVisions)
                if result ~= nil and result.error ~= nil then
                    geterrorhandler()(result.error)
                end
            end)
            selling = false
            if not ok then
                report(err)
            end
        end
        return original(self, event, ...)
    end
    return true
end

-- ------------------------------------------------------- 4. the key bindings

-- The marking keys are bindings like WowVision's own: they are listed, and can be changed, in the Bindings screen
-- (/wv, then Interface, then Bindings). WowVision keeps every binding in one registry that the screen reads, and
-- stores the player's keys by the binding's key, so a binding added now is picked up like the ones it loaded
-- with.
function ns.installBindings()
    local input = WowVision ~= nil and WowVision.input or nil
    if input == nil or type(input.createBinding) ~= "function" or type(input.getBinding) ~= "function" then
        return false
    end
    local added = false
    for _, info in ipairs(ns.bindings) do
        if input:getBinding(info.key) == nil then
            local copy = {}
            for key, value in pairs(info) do
                copy[key] = value
            end
            copy.label = L[info.label]
            input:createBinding(copy)
            added = true
        end
    end
    if added then
        -- the keys saved earlier for them, or their defaults, join WowVision's binding stores
        local resolved = WowVision.dbManager:resolveBindings(input:getDefaultDB(), WowVisionDB, WowVision.globalDb)
        WowVision:applyBindingStore(resolved)
    end
    return true
end
