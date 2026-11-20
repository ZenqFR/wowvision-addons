-- The two things a player can mark in their bags -- junk and favorites -- with their key bindings and the sale of
-- junk at a merchant. The game's side (the hooks) is in Hooks.lua. (They no longer have a category of their own in
-- the Item Lists stop: what is for a merchant is the category of Merchant.lua.)
local _, ns = ...
local L = ns.L
local store = ns.store

-- ----------------------------------------------------------------------- junk

-- Junk: the player marks the item they stand on in the bags (Shift+Enter by default, or the slot's menu), the bag
-- says "[Junk]" ahead of its name, and the merchant window sells every marked item by itself when it opens.
-- Marking again takes the mark off.
local junk = ns.Marks.new({
    name = "junk",
    word = "Junk",
    bindingKey = "junk/toggle",
    markLabel = "Mark as Junk",
    unmarkLabel = "Unmark as Junk",
    markedText = "%s: marked as junk",
    unmarkedText = "%s: no longer junk",
    cannotText = "This item cannot be marked as junk.",
    -- An item no vendor buys is not marked (the mark would promise a sale that never comes), but a mark already
    -- there can always be taken off.
    refuse = function(info, name)
        if info.hasNoValue == true then
            return string.format(L["%s cannot be sold to a vendor."], name)
        end
        return nil
    end,
})
ns.junk = junk

-- Whether the marked junk is sold at merchants (/wvbags sell).
function junk:sellsAtMerchants()
    return ns.section("junk").autoSell ~= false
end

function junk:setSellsAtMerchants(enabled)
    ns.section("junk").autoSell = enabled == true
end

-- ------------------------------------------------------------------ favorites

-- Favorites: the same, for the items the player wants to find again easily. Nothing is ever sold because of a
-- mark here: a favorite is even kept out of the sale of junk.
local favorites = ns.Marks.new({
    name = "favorites",
    word = "Favorite",
    bindingKey = "favorite/toggle",
    markLabel = "Mark as Favorite",
    unmarkLabel = "Unmark as Favorite",
    markedText = "%s: marked as favorite",
    unmarkedText = "%s: no longer a favorite",
    cannotText = "This item cannot be marked as a favorite.",
})
ns.favorites = favorites

-- The parts, in the order their tags are said ahead of a slot: "[Favorite] [Junk] Linen Cloth".
ns.parts = { favorites, junk }

-- The key bindings of the parts, as WowVision's input manager takes them. The keys are the ones the Bindings
-- screen lists and saves the player's own choice under. "dorment" keys do nothing until a slot that carries them
-- has the focus.
ns.bindings = {
    {
        type = "Flexible",
        key = "junk/toggle",
        dorment = true,
        label = "Select Junk",
        inputs = { "SHIFT-ENTER" },
    },
    {
        type = "Flexible",
        key = "favorite/toggle",
        dorment = true,
        label = "Select Favorite",
        -- The key above Enter that erases a letter (Backspace) with Shift held.
        inputs = { "SHIFT-BACKSPACE" },
    },
}

-- ------------------------------------------------------------ the sale

-- The bags the player carries: the backpack, the bag slots and, where the game has one, the reagent bag. Never
-- the bank.
local function carriedBags()
    local bags = {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
        tinsert(bags, bag)
    end
    return bags
end
ns.carriedBags = carriedBags

-- Vendor sell price for a bag item, in copper; nil when the item isn't cached yet or has none.
local function getSellPrice(itemID)
    local getInfo = C_Item ~= nil and C_Item.GetItemInfo or GetItemInfo
    if getInfo == nil or itemID == nil then
        return nil
    end
    local ok, price = pcall(function()
        return select(11, getInfo(itemID))
    end)
    if ok and price ~= nil and price > 0 then
        return price
    end
    return nil
end

-- One pass over the carried bags that sells the items marked as junk, nothing else, and says what went and for
-- how much. UseContainerItem sells the slot directly, the same action a manual right click performs while a
-- merchant is open. What is sold is decided slot by slot in Store.lua.
--
-- leavePoorAlone: WowVision sells the poor quality (grey) items itself when its own setting says so, right
-- after this pass; a marked grey item is left to it so that nothing is sold twice.
-- Returns what the pass did (Store.lua's result), or nil when it had nothing to do.
function ns.sellJunk(leavePoorAlone)
    if not junk:isEnabled() or not junk:sellsAtMerchants() then
        return nil
    end
    local marks = junk:getMarks()
    if marks == nil or next(marks) == nil then
        return nil
    end
    -- read even while the favorites are switched off: switching them off hides them, it does not make the
    -- items sellable
    local kept = favorites:section().marks
    local result = store.sell({
        bags = carriedBags(),
        numSlots = C_Container.GetContainerNumSlots,
        getInfo = function(bag, slot)
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info == nil then
                return nil
            end
            if leavePoorAlone and info.quality == 0 then
                return nil
            end
            -- a favorite is never sold, whatever else is marked on it
            if store.isMarked(kept, store.keyFromLink(info.hyperlink)) then
                return nil
            end
            return info
        end,
        sellPrice = getSellPrice,
        sell = C_Container.UseContainerItem,
        marks = marks,
        sellPoor = false,
    })
    local text = store.summary(result, L, C_CurrencyInfo.GetCoinText)
    if text ~= nil then
        WowVision:speak(text)
    end
    return result
end
