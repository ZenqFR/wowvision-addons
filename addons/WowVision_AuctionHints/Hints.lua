-- The rules: where each item of the bags belongs, and what is said about it. No game calls here but through Game, no
-- prices but through Market.
--
-- ONE function, Hints.classify, puts every occupied slot into exactly one of three places, and everything else
-- (the auction house list, the merchant category WowVision_Bags shows, the counts) is built from its answers, so
-- no slot can be in two places or fall between them:
--   "auction"  the item would sell for at least 10 percent more at the auction house than to a vendor, and it can
--              be auctioned (nothing says it is bound, it is not damaged);
--   "vendor"   a vendor buys it (sell price above 0) and it is not "auction": bound items, items with no auction
--              price, items under the threshold, damaged ones;
--   "none"     neither: a vendor does not buy it and it is not for the auction house.
--
-- The decisions, all of them on purpose:
--  * The auction price is Market's "typical price" per item (what its tooltip shows), the vendor price is what the
--    game says a vendor pays per item (GetItemInfo's sell price). A stack is priced item by item times its count.
--  * An item is "auction" when typical * 100 >= vendor * 110, in whole coppers (no rounding doubt at exactly 10
--    percent).
--  * The auction house's cut and deposit are NOT deducted: the request compares the two prices. The summary says so.
--  * An item with no auction price is never "auction". An item the vendor does not buy at all (price 0) is
--    "auction" as soon as it has an auction price, with no percentage: any price is more than nothing.
--  * An item is NEVER "auction" when anything says it is bound. The slot's own flag must be exactly false; the item
--    location check Auctionator uses (C_Item.IsBound) must not say true; the item's bind type must be none, when
--    equipped or when used (Auctionator's own list of what is not bound); an item bound to the account until worn is
--    out as well. A damaged item is out too (the auction house refuses it until it is repaired). Any doubt = out.
--  * The auction house list has ONE LINE PER ITEM, however many stacks hold it: the count is the total of the
--    stacks that qualify (a bound stack is never in it), the prices are per item and in all. The unit prices are the
--    same for every stack of an item, so the threshold is the same for all of them.
local _, ns = ...
local L = ns.L
local Game = ns.Game

local Hints = {}
ns.Hints = Hints

-- At least this many percent above the vendor price.
Hints.PERCENT = 10

-- The auction house's cut, in percent, that is taken off its price before the threshold is judged: the house's own
-- (5, or 15 at Blackwater) while the setting "fees" is on (it is, by default), else 0.
function Hints.cutFor(snapshot)
    if Game.getSetting("fees") ~= true then
        return 0
    end
    return snapshot.cut or 5
end
-- A price list older than this is called old.
Hints.OLD_SECONDS = 24 * 3600

-- Item.bindType values that are not bound: none, bound when equipped, bound when used.
local NOT_BOUND = { [0] = true, [2] = true, [3] = true }

-- Why a slot is not for the auction house, or nil when it is: "bound", "damaged", "noprice" or "below".
local function auctionBlock(info, item, bag, slot)
    -- bound first, so that nothing that can be bound gets any further
    if info.bound ~= false then
        return "bound"
    end
    if Game.locationBound(bag, slot) == true then
        return "bound"
    end
    if not NOT_BOUND[item.bindType] then
        return "bound"
    end
    if Game.accountBoundUntilEquip(info.itemID) == true then
        return "bound"
    end
    local current, maximum = Game.durability(bag, slot)
    if current ~= nil and maximum ~= nil and current < maximum then
        return "damaged"
    end
    return nil
end

-- Where the item of a slot belongs. Answers nil and why it is not placed ("empty", "unreadable", "pending": the
-- game has not loaded the item), or
--   { kind = "auction" | "vendor" | "none", why = the reason it is not for the auction house (nil for "auction"),
--     bag, slot, itemID, link, name, quality, count, vendorUnit, auctionUnit (nil without a price), gain, percent }
function Hints.classify(bag, slot, snapshot)
    local info = Game.slotInfo(bag, slot)
    if info == nil then
        return nil, "empty"
    end
    if info.unreadable then
        return nil, "unreadable"
    end
    local item = Game.itemInfo(info.link or info.itemID)
    if item == nil then
        return nil, "pending"
    end
    local vendor = item.sellPrice
    if type(vendor) ~= "number" then
        if info.hasNoValue then
            vendor = 0
        else
            return nil, "pending"
        end
    end
    local result = {
        bag = bag,
        slot = slot,
        itemID = info.itemID,
        link = info.link,
        name = item.name,
        quality = item.quality,
        count = info.count,
        vendorUnit = vendor,
    }
    local cut = Hints.cutFor(snapshot)
    local why = auctionBlock(info, item, bag, slot)
    if why == nil then
        local auction = snapshot.price(info.itemID)
        result.auctionUnit = auction
        if auction == nil then
            why = "noprice"
        elseif vendor > 0 and auction * (100 - cut) < vendor * (100 + Hints.PERCENT) then
            -- what the auction house pays after its cut, against what a vendor pays: in whole numbers, so that
            -- exactly 10 percent is in
            why = "below"
        end
    end
    result.why = why
    if why == nil then
        result.kind = "auction"
        -- what the auction house pays after its cut (the price itself when the fees are not counted)
        local net = result.auctionUnit * (100 - cut) / 100
        result.cut = cut
        result.gain = (net - vendor) * info.count
        -- how many percent above the vendor price (after the cut), nil when the vendor pays nothing
        result.percent = vendor > 0 and (net - vendor) * 100 / vendor or nil
    elseif vendor > 0 then
        result.kind = "vendor"
    else
        result.kind = "none"
    end
    return result
end

local function before(a, b)
    if a.bag ~= b.bag then
        return a.bag < b.bag
    end
    return a.slot < b.slot
end

-- One line per item out of a list of slots: the stacks of an item are added up, and the line acts on its first stack
-- (the lowest bag, then the lowest slot). Both the auction house list and the merchant category are made this way.
local function lineOf(slots)
    local byItem, lines = {}, {}
    for _, slot in ipairs(slots) do
        local line = byItem[slot.itemID]
        if line == nil then
            line = {
                itemID = slot.itemID,
                name = slot.name,
                quality = slot.quality,
                vendorUnit = slot.vendorUnit,
                auctionUnit = slot.auctionUnit,
                percent = slot.percent,
                cut = slot.cut,
                count = 0,
                gain = 0,
                piles = {},
            }
            byItem[slot.itemID] = line
            tinsert(lines, line)
        end
        line.count = line.count + slot.count
        line.gain = line.gain + (slot.gain or 0)
        tinsert(line.piles, { bag = slot.bag, slot = slot.slot, count = slot.count, button = slot.button })
    end
    for _, line in ipairs(lines) do
        table.sort(line.piles, before)
        local first = line.piles[1]
        line.bag, line.slot, line.button = first.bag, first.slot, first.button
        line.stacks = #line.piles
    end
    return lines
end

-- The auction house lines: biggest gain first, then the first stack's bag and slot.
local function group(auctionSlots)
    local lines = lineOf(auctionSlots)
    for _, line in ipairs(lines) do
        line.auctionTotal = line.auctionUnit * line.count
    end
    table.sort(lines, function(a, b)
        if a.gain ~= b.gain then
            return a.gain > b.gain
        end
        return before(a, b)
    end)
    return lines
end

-- The merchant lines, in the order of the bags (the first stack's bag, then slot).
local function groupVendor(vendorSlots)
    local lines = lineOf(vendorSlots)
    for _, line in ipairs(lines) do
        line.vendorTotal = line.vendorUnit * line.count
    end
    table.sort(lines, before)
    return lines
end

-- positions: { { bag, slot, button? }, ... }. Answers
--   entries            the auction house lines, one per item, biggest gain first (then bag and slot)
--   merchantLines      the same for the slots a vendor buys: one line per item, in the order of the bags
--   auctionPositions   the positions (as given) whose slot is "auction"
--   merchantPositions  the positions whose slot is "vendor"
--   counts             total (occupied slots), auction, vendor, none, and the slots that are not for the auction
--                      house by reason: bound, damaged, noprice, below; pending and unreadable are in neither place
function Hints.scan(positions, snapshot)
    local counts = { total = 0, auction = 0, vendor = 0, none = 0, bound = 0, damaged = 0, noprice = 0, below = 0, pending = 0, unreadable = 0 }
    local auctionSlots, vendorSlots, auctionPositions, merchantPositions = {}, {}, {}, {}
    for _, position in ipairs(positions) do
        local ok, result, reason = pcall(Hints.classify, position.bag, position.slot, snapshot)
        if not ok then
            Game.report(result)
            result, reason = nil, "unreadable"
        end
        if reason ~= "empty" then
            counts.total = counts.total + 1
        end
        if result == nil then
            if counts[reason] ~= nil then
                counts[reason] = counts[reason] + 1
            end
        else
            counts[result.kind] = counts[result.kind] + 1
            if result.why ~= nil then
                counts[result.why] = counts[result.why] + 1
            end
            if result.kind == "auction" then
                result.button = position.button
                tinsert(auctionSlots, result)
                tinsert(auctionPositions, position)
            elseif result.kind == "vendor" then
                result.button = position.button
                tinsert(vendorSlots, result)
                tinsert(merchantPositions, position)
            end
        end
    end
    return {
        entries = group(auctionSlots),
        merchantLines = groupVendor(vendorSlots),
        auctionPositions = auctionPositions,
        merchantPositions = merchantPositions,
        counts = counts,
    }
end

-- Every slot of the carried bags, read straight from the game (for /wvhdv, which needs no bag window).
function Hints.allPositions()
    local positions = {}
    for _, bag in ipairs(Game.bagIds()) do
        for slot = 1, Game.numSlots(bag) do
            tinsert(positions, { bag = bag, slot = slot })
        end
    end
    return positions
end

-- What the places hold now: Hints.scan's answer, plus snapshot (the prices read) or problem ("nomarket" | "noprices":
-- no prices, so nothing is "auction" and the vendor places hold everything a vendor buys).
function Hints.compute(positions)
    local snapshot, problem = ns.Market.snapshot()
    if snapshot == nil then
        local scanned = Hints.scan(positions, {
            price = function()
                return nil
            end,
        })
        scanned.problem = problem
        return scanned
    end
    local scanned = Hints.scan(positions, snapshot)
    scanned.snapshot = snapshot
    scanned.cut = Hints.cutFor(snapshot)
    return scanned
end

-- ----------------------------------------------------------------- words

local MONTHS = {
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
}

-- "19 novembre à 23 h 05" for a moment, in the player's own time.
function Hints.dateText(moment)
    local parts = Game.dateParts(moment)
    return ns.fill(L["{month} {day} at {hour}:{minute}"], {
        month = L[MONTHS[parts.month]],
        day = parts.day,
        hour = parts.hour,
        minute = string.format("%02d", parts.min),
    })
end

-- How long ago a moment was, in the largest unit that fits ("il y a 4 heures"); a moment to come is "just now".
function Hints.agoText(seconds)
    if seconds < 90 then
        return L["just now"]
    end
    local count, unit
    if seconds < 3570 then
        count, unit = math.floor(seconds / 60 + 0.5), "minute"
    elseif seconds < 84600 then
        count, unit = math.floor(seconds / 3600 + 0.5), "hour"
    else
        count, unit = math.floor(seconds / 86400 + 0.5), "day"
    end
    return ns.fill(L["{count} " .. unit .. (count == 1 and "" or "s") .. " ago"], { count = count })
end

-- A whole number of percent (a line is at least 10 percent above, so it is never 0).
local function percentText(percent)
    return tostring(math.floor(percent + 0.5))
end

-- The name and the quantity of a line: "Linen Cloth", "Linen Cloth, 20" or "Linen Cloth, 20 in 3 stacks".
local function headText(entry, name)
    if entry.stacks > 1 then
        return ns.fill(L["{name}, {count} in {stacks} stacks"], { name = name, count = entry.count, stacks = entry.stacks })
    elseif entry.count > 1 then
        return name .. ", " .. entry.count
    end
    return name
end

-- The sentence of one line of the merchant category: name, quantity, what a vendor pays each and in all.
function Hints.merchantText(line)
    local name = Game.itemLabel(line.name, line.quality)
    local values = { vendor = Game.coinText(line.vendorUnit), total = Game.coinText(line.vendorTotal) }
    local body
    if line.count > 1 then
        body = L[": vendor {vendor} each, {total} in all"]
    else
        body = L[": vendor {vendor}"]
    end
    return headText(line, name) .. ns.fill(body, values)
end

-- The sentence of one line of the list: name, quantity (in all, and in how many stacks when more than one), vendor
-- price, auction house price each and in all, difference in percent, gain.
function Hints.entryText(entry)
    local name = Game.itemLabel(entry.name, entry.quality)
    local values = {
        name = name,
        count = entry.count,
        stacks = entry.stacks,
        vendor = Game.coinText(entry.vendorUnit),
        auction = Game.coinText(entry.auctionUnit),
        total = Game.coinText(entry.auctionTotal),
        percent = entry.percent ~= nil and percentText(entry.percent) or nil,
        gain = Game.coinText(entry.gain),
    }
    local head = headText(entry, name)
    local several = entry.count > 1
    local body
    if entry.vendorUnit == 0 then
        if several then
            body = L[": the vendor does not buy it, auction house {auction} each, {total} in all, estimated gain {gain}"]
        else
            body = L[": the vendor does not buy it, auction house {auction}, estimated gain {gain}"]
        end
    elseif several then
        if entry.cut > 0 then
            body = L[": vendor {vendor} each, auction house {auction} each, {total} in all, {percent} percent more after the cut, estimated gain {gain}"]
        else
            body = L[": vendor {vendor} each, auction house {auction} each, {total} in all, {percent} percent more, estimated gain {gain}"]
        end
    elseif entry.cut > 0 then
        body = L[": vendor {vendor}, auction house {auction}, {percent} percent more after the cut, estimated gain {gain}"]
    else
        body = L[": vendor {vendor}, auction house {auction}, {percent} percent more, estimated gain {gain}"]
    end
    return head .. ns.fill(body, values)
end

-- How old the prices are, and where they come from, as sentences.
local function priceSentences(snapshot, now)
    local sentences = {}
    if snapshot.built == nil then
        tinsert(sentences, L["Prices from Life on Azeroth Market, date unknown."])
    else
        local age = now - snapshot.built
        if age > Hints.OLD_SECONDS then
            tinsert(sentences, L["Warning, these prices are old."])
        end
        tinsert(
            sentences,
            ns.fill(L["Prices from Life on Azeroth Market, taken {date}, {ago}."], {
                date = Hints.dateText(snapshot.built),
                ago = Hints.agoText(age),
            })
        )
    end
    if snapshot.house ~= nil and not snapshot.own then
        tinsert(sentences, ns.fill(L["These are the prices of another auction house: {house}."], { house = snapshot.houseName }))
    end
    return sentences
end

-- The first thing said at the stop: how many items, the total gain (before the auction house's cut), what could not
-- be checked, and how old the prices are.
function Hints.summaryText(result, now)
    local title = L["For sale at the auction house"]
    if result.problem ~= nil then
        return ns.fill(L["{title}: no prices available. Life on Azeroth Market is not installed, or its companion app has not made a price list yet."], { title = title })
    end
    local count = #result.entries
    local values = { title = title, count = count, percent = Hints.PERCENT }
    local sentences = {}
    if count == 0 then
        tinsert(sentences, ns.fill(L["{title}: no item in your bags sells for at least {percent} percent more at the auction house than to a vendor."], values))
        if result.cut > 0 then
            tinsert(sentences, ns.fill(L["Prices counted after the auction house's cut of {cut} percent."], { cut = result.cut }))
        end
    else
        local key = count == 1
                and "{title}: {count} item sells for at least {percent} percent more at the auction house than to a vendor."
            or "{title}: {count} items sell for at least {percent} percent more at the auction house than to a vendor."
        tinsert(sentences, ns.fill(L[key], values))
        local gain = 0
        for _, entry in ipairs(result.entries) do
            gain = gain + entry.gain
        end
        if result.cut > 0 then
            tinsert(sentences, ns.fill(L["Estimated gain {gain}, after the auction house's cut of {cut} percent (the deposit comes back when an item sells)."], { gain = Game.coinText(gain), cut = result.cut }))
        else
            tinsert(sentences, ns.fill(L["Estimated gain {gain}, auction house fees not deducted."], { gain = Game.coinText(gain) }))
        end
    end
    local pending = result.counts.pending
    if pending > 0 then
        local key = pending == 1 and "{count} item is not loaded yet, its vendor price is unknown."
            or "{count} items are not loaded yet, their vendor prices are unknown."
        tinsert(sentences, ns.fill(L[key], { count = pending }))
    end
    for _, sentence in ipairs(priceSentences(result.snapshot, now)) do
        tinsert(sentences, sentence)
    end
    return table.concat(sentences, " ")
end

-- /wvhdv: the summary, then where the slots of the bags went and why the others are not in the list.
function Hints.statusText(result, now)
    local text = Hints.summaryText(result, now)
    local counts = result.counts
    return text
        .. " "
        .. ns.fill(
            L["{lines} in the list. Slots in the list: {slots}. Slots to sell to a merchant: {merchant}. Occupied slots in your bags: {total}, kept out of the list: {bound} bound, {noprice} without an auction house price, {below} under {percent} percent, {damaged} damaged; {pending} not loaded."],
            {
                lines = #result.entries,
                slots = counts.auction,
                merchant = counts.vendor,
                total = counts.total,
                bound = counts.bound,
                noprice = counts.noprice,
                below = counts.below,
                percent = Hints.PERCENT,
                damaged = counts.damaged,
                pending = counts.pending,
            }
        )
end
