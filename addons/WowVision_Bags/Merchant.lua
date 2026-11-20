-- The category "For sale to a merchant" of the bags' Item Lists stop (Lists.lua): the slots of the carried bags
-- that a vendor buys and that are NOT in the auction house tab of WowVision_AuctionHints, so that each item that can
-- be sold is in one place or the other, never in both.
--
-- It is not worked out here. WowVision_AuctionHints decides where every slot belongs with ONE function (a slot is for
-- the auction house, for a vendor, or for neither) and offers the answer through the global WowVisionAuctionHints; this
-- list takes the "for a vendor" half. So it holds, in the order of the bags: the items that are bound (never
-- auctionable), those with no known auction house price, those under the auction house threshold (10 percent above
-- what a vendor pays) and the damaged ones, as long as a vendor pays something for them. It does not hold what is in
-- the auction house tab, nor what a vendor will not buy.
--
-- A favorite is not in it: a favorite is never sold (the sale of junk keeps it, whatever else is marked), so offering
-- it as "to sell" would be wrong. This holds while the favorites are switched off too, as it does for the sale.
--
-- One line per ITEM, however many stacks hold it (the user's choice, 2026-11-20): "Linen Cloth, 14 in 3 stacks:
-- vendor 2 Silver each, 28 Silver in all". The line is the slot of the item's first stack (Enter, the right click and
-- the menu act on it; when it is gone the next stack leads). The grouping and the sentence come from
-- WowVision_AuctionHints, as the classification does; the marks' tags ([Junk], ...) are put ahead by the bags.
--
-- Without WowVision_AuctionHints (not installed, not enabled, or in combat) the category is empty: there is no
-- auction house tab to be the other half of, and nothing here knows prices.
local _, ns = ...
local L = ns.L
local store = ns.store

local function hints()
    local api = rawget(_G, "WowVisionAuctionHints")
    if type(api) == "table" and type(api.partition) == "function" and (api.version or 0) >= 2 then
        return api
    end
    return nil
end

-- The line of each first-stack button, as of the last time the category was worked out.
local lineOf = {}

-- The buttons of the lines of the category: the first stack of each item (bag by bag, as given).
local function select(buttons)
    lineOf = {}
    local api = hints()
    if api == nil then
        return {}
    end
    local carried = {}
    for _, bag in ipairs(ns.carriedBags()) do
        carried[bag] = true
    end
    -- read even while the favorites are switched off: switching them off hides them, it does not make them sellable.
    -- A favorite's slots are left out before the question, so that none of them is in a line.
    local kept = ns.favorites:section().marks
    local positions = {}
    for _, itemButton in ipairs(buttons) do
        local bag, slot = ns.locate(itemButton)
        if carried[bag] then
            local _, key = ns.favorites:itemAt(bag, slot)
            if not store.isMarked(kept, key) then
                tinsert(positions, { bag = bag, slot = slot, button = itemButton })
            end
        end
    end
    local answer = api.partition(positions)
    if answer == nil or answer.merchantLines == nil then
        return {}
    end
    local selected = {}
    for _, line in ipairs(answer.merchantLines) do
        lineOf[line.button] = line
        tinsert(selected, line.button)
    end
    return selected
end
ns.merchantList = select

-- What is said for the line of a first-stack button: the line's sentence while every stack of the item still holds the
-- same item and count, the bags' own label of that slot when the bags changed under it (the screen is drawn again
-- soon after).
local function describe(itemButton)
    local line = lineOf[itemButton]
    if line == nil then
        return nil
    end
    return function()
        for _, pile in ipairs(line.piles) do
            local info = ns.favorites:itemAt(pile.bag, pile.slot)
            if info == nil or info.itemID ~= line.itemID or info.stackCount ~= pile.count then
                return ns.bagLabel(itemButton)
            end
        end
        return line.text
    end
end

ns.lists.register({
    key = "merchant",
    label = L["For sale to a merchant"],
    order = 20,
    select = select,
    describe = describe,
    -- named just "For sale to a merchant", without a count (the user's wish, 2026-11-20)
    hideCount = true,
})
