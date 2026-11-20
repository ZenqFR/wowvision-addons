-- Everything this addon asks of the game, of Life on Azeroth Market's data and of WowVision, in one table, so the
-- tests can replace it. Nothing here decides anything: the rules are in Hints.lua.
local _, ns = ...
local L = ns.L

local Game = {}
ns.Game = Game

-- An error here must never break the bags, and must not repeat on every rebuild either: each distinct message once.
local reported = {}
function Game.report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_AuctionHints: " .. err)
end

function Game.guarded(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            Game.report(err)
        end
    end
end

-- Values the game can hand over as secrets (Forever runs the engine that has them): nothing can be compared or
-- measured, so a secret is as good as missing. Outside a fight the bags give none; this is for the day they do.
function Game.isSecret(value)
    local wowVision = rawget(_G, "WowVision")
    if wowVision ~= nil and type(wowVision.isSecret) == "function" then
        return wowVision.isSecret(value) == true
    end
    local check = rawget(_G, "issecretvalue")
    return check ~= nil and check(value) == true
end

local function usable(value)
    return value ~= nil and not Game.isSecret(value)
end
Game.usable = usable

function Game.speak(text)
    if text == nil or text == "" then
        return
    end
    local wowVision = rawget(_G, "WowVision")
    if wowVision ~= nil and wowVision.speak ~= nil then
        wowVision:speak(text)
    else
        print(text)
    end
end

-- ---------------------------------------------------------- settings

local DEFAULTS = {
    fees = true, -- the auction house's cut is taken off its price before the 10 percent is judged
}

-- The saved variable arrives after the files are read, so it is reached when it is used, never kept.
local function store()
    local saved = rawget(_G, "WowVisionAuctionHintsDB")
    if type(saved) ~= "table" then
        saved = {}
        _G.WowVisionAuctionHintsDB = saved
    end
    return saved
end

function Game.getSetting(key)
    local value = store()[key]
    if value == nil then
        return DEFAULTS[key]
    end
    return value
end

function Game.setSetting(key, value)
    store()[key] = value
end

function Game.inCombat()
    return InCombatLockdown ~= nil and InCombatLockdown() == true
end

function Game.time()
    return time()
end

-- { day, month, hour, min } of a moment, in the player's own time (the clock the game shows).
function Game.dateParts(moment)
    return date("*t", moment)
end

-- ------------------------------------------------------ the market's data

-- The table the companion app writes into LifeOnAzeroth_Data; nil when that addon is not installed or not enabled.
function Game.market()
    local data = rawget(_G, "LOA_DATA")
    return type(data) == "table" and data or nil
end

-- Life on Azeroth Market's own saved variables (the auction house the player picked there); nil before it loaded.
function Game.marketSettings()
    local saved = rawget(_G, "LifeOnAzeroth_MarketDB")
    return type(saved) == "table" and saved or nil
end

function Game.realmName()
    if GetRealmName == nil then
        return nil
    end
    local ok, name = pcall(GetRealmName)
    return ok and type(name) == "string" and name or nil
end

-- "Alliance" or "Horde" (nil for anything else).
function Game.faction()
    if UnitFactionGroup == nil then
        return nil
    end
    local ok, faction = pcall(UnitFactionGroup, "player")
    return ok and type(faction) == "string" and faction or nil
end

-- ------------------------------------------------------------- the bags

-- The carried bags: the backpack, the four bags and the reagent bag.
function Game.bagIds()
    local last = rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS") or rawget(_G, "NUM_BAG_SLOTS") or 4
    local ids = {}
    for bag = 0, last do
        tinsert(ids, bag)
    end
    return ids
end

function Game.numSlots(bag)
    local ok, count = pcall(C_Container.GetContainerNumSlots, bag)
    return ok and type(count) == "number" and count or 0
end

-- What a slot holds: nil when it is empty, { unreadable = true } when the game hides what it holds, else
-- { itemID, link, count, bound, hasNoValue }. bound is the game's own flag as it comes (true or false): the rules
-- read anything but false as bound.
function Game.slotInfo(bag, slot)
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not ok or info == nil then
        return nil
    end
    local itemID, count, bound = info.itemID, info.stackCount, info.isBound
    if not usable(itemID) or not usable(count) or Game.isSecret(bound) or not usable(info.hyperlink) then
        return { unreadable = true }
    end
    return {
        itemID = itemID,
        link = info.hyperlink,
        count = count,
        bound = bound,
        hasNoValue = info.hasNoValue == true,
    }
end

-- The second opinion on a bound item, the one Auctionator asks (C_Item.IsBound on the slot's item location): true
-- or false, nil when the game cannot say.
function Game.locationBound(bag, slot)
    local location = rawget(_G, "ItemLocation")
    if location == nil or C_Item == nil or C_Item.IsBound == nil then
        return nil
    end
    local made, where = pcall(location.CreateFromBagAndSlot, location, bag, slot)
    if not made or where == nil then
        return nil
    end
    local ok, bound = pcall(C_Item.IsBound, where)
    if ok and usable(bound) then
        return bound == true
    end
    return nil
end

-- { name, quality, sellPrice, bindType } of an item, nil while the game has not loaded it.
function Game.itemInfo(linkOrID)
    local get = C_Item ~= nil and C_Item.GetItemInfo or rawget(_G, "GetItemInfo")
    if get == nil then
        return nil
    end
    local ok, name, _, quality, _, _, _, _, _, _, _, sellPrice, _, _, bindType = pcall(get, linkOrID)
    if not ok or not usable(name) then
        return nil
    end
    return {
        name = name,
        quality = usable(quality) and quality or nil,
        sellPrice = usable(sellPrice) and sellPrice or nil,
        bindType = usable(bindType) and bindType or nil,
    }
end

-- Items that are bound to the account until they are worn cannot be auctioned either (Auctionator's rule).
function Game.accountBoundUntilEquip(itemID)
    if C_Item == nil or C_Item.IsItemBindToAccountUntilEquip == nil then
        return nil
    end
    local ok, bound = pcall(C_Item.IsItemBindToAccountUntilEquip, itemID)
    if ok and usable(bound) then
        return bound == true
    end
    return nil
end

-- current, maximum durability of the item in a slot; nil for an item that has none.
function Game.durability(bag, slot)
    if C_Container.GetContainerItemDurability == nil then
        return nil, nil
    end
    local ok, current, maximum = pcall(C_Container.GetContainerItemDurability, bag, slot)
    if ok and usable(current) and usable(maximum) then
        return current, maximum
    end
    return nil, nil
end

-- An amount of money as words, the way WowVision says it in the bags ("12 Gold 5 Silver" in the game's language);
-- written out here when the game does not give it.
function Game.coinText(copper)
    copper = math.floor(copper + 0.5)
    local currency = rawget(_G, "C_CurrencyInfo")
    if currency ~= nil and type(currency.GetCoinText) == "function" then
        local ok, text = pcall(currency.GetCoinText, copper, " ")
        if ok and type(text) == "string" and text ~= "" then
            return text
        end
    end
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local rest = copper % 100
    local parts = {}
    if gold > 0 then
        tinsert(parts, gold .. " " .. L["Gold"])
    end
    if silver > 0 then
        tinsert(parts, silver .. " " .. L["Silver"])
    end
    if rest > 0 or #parts == 0 then
        tinsert(parts, rest .. " " .. L["Copper"])
    end
    return table.concat(parts, " ")
end

-- An item's name the way WowVision's bags say it (with the colour of its quality); the bare name without WowVision.
function Game.itemLabel(name, quality)
    local wowVision = rawget(_G, "WowVision")
    local items = wowVision ~= nil and wowVision.items or nil
    if items ~= nil and type(items.formatName) == "function" then
        local ok, label = pcall(items.formatName, name, quality)
        if ok and type(label) == "string" then
            return label
        end
    end
    return name
end

-- ------------------------------------------------------------- WowVision

-- WowVision's bags module (core/windows/containers.lua): it knows where an item button points and builds the slots.
function Game.containers()
    local wowVision = rawget(_G, "WowVision")
    local windows = wowVision ~= nil and wowVision.base ~= nil and wowVision.base.windows or nil
    return windows ~= nil and windows.containers or nil
end

-- The bag frames that are shown now (the combined bags, or one per bag).
function Game.shownFrames()
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

-- The item buttons of the shown bag frames, as WowVision's bags read them: not the four extra backpack slots of an
-- account without an authenticator, which cannot hold anything.
function Game.bagButtons()
    local buttons = {}
    for _, frame in ipairs(Game.shownFrames()) do
        for _, itemButton in ipairs(frame.Items or {}) do
            local usableSlot = itemButton:IsShown() and not (itemButton.IsExtended ~= nil and itemButton:IsExtended())
            if usableSlot then
                tinsert(buttons, itemButton)
            end
        end
    end
    return buttons
end

-- Bag id and slot id an item button points at.
function Game.locate(itemButton)
    return Game.containers().slotLocation(itemButton)
end

-- The WowVision window of the bags, which holds the screen this addon adds a stop to.
function Game.bagsWindow()
    local containers = Game.containers()
    local registered = containers ~= nil and containers.registeredWindows or nil
    local window = registered ~= nil and registered["bags"] or nil
    if window == nil then
        local wowVision = rawget(_G, "WowVision")
        local manager = wowVision ~= nil and wowVision.UIHost ~= nil and wowVision.UIHost.windowManager or nil
        if manager ~= nil and type(manager.getWindow) == "function" then
            window = manager:getWindow("bags")
        end
    end
    return window
end

-- The component of WowVision's containers registry that reads the carried bags.
function Game.bagsComponentType()
    local wowVision = rawget(_G, "WowVision")
    local registries = wowVision ~= nil and wowVision.components ~= nil and wowVision.components.registries or nil
    local registry = registries ~= nil and registries:get("containers") or nil
    return registry ~= nil and registry.types ~= nil and registry.types:get("RetailBags") or nil
end
