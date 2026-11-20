-- The stop this addon adds to WowVision's bags screen: "For sale at the auction house", the last one.
--
-- It is built into the graph builder WowVision's bags screen is being drawn with (Main.lua calls addStop once the
-- bags have drawn everything they have). The first line of the stop, the summary, is a row of its own outside the
-- list, so that the "1 of 3" positions of the items count the items only; the items follow in a list, each as the
-- bags' own slot (the same clicks: pick up, use, sell, put up for auction when the window is open) with a sentence
-- of its own instead of the bag's label.
local _, ns = ...
local L = ns.L
local Game = ns.Game
local Hints = ns.Hints

local Screen = {}
ns.Screen = Screen

-- The key of the stop (it must be the same at every rebuild: it keys the stop's remembered position).
Screen.STOP = "auctionHints"

-- One line of the list as the bags' slot node, the slot of the line's first stack: Enter, the right click and the
-- menu act on that stack (when it is gone the screen is drawn again and the next stack is the first). The sentence
-- was made when the screen was drawn; while every stack of the line still holds the same item and count it is read as
-- it is, and if the bags changed under it (the screen is redrawn soon after) the bags' own label of the first stack
-- is read instead, which is always true.
local function slotNode(containers, entry)
    local button = entry.button
    local text = Hints.entryText(entry)
    local function label()
        for _, pile in ipairs(entry.piles) do
            local info = Game.slotInfo(pile.bag, pile.slot)
            if info == nil or info.itemID ~= entry.itemID or info.count ~= pile.count then
                return containers.getBagItemLabel(button)
            end
        end
        return text
    end
    return containers.itemSlotNode(button, label, containers.itemClickLabels(button), containers.slotIsEmpty(button))
end

-- Adds the stop to the builder, at the end of what it holds. Once per builder; not in combat (WowVision draws its
-- own list then) and not when the carried bags are not open (the window is open for the bank alone).
function Screen.addStop(builder)
    if rawget(builder, "auctionHintsDone") then
        return false
    end
    if Game.inCombat() then
        return false
    end
    if #Game.shownFrames() == 0 then
        return false
    end
    rawset(builder, "auctionHintsDone", true)

    local containers = Game.containers()
    local graph = WowVision.graph
    local nodes = graph.nodes
    local ControlId = graph.ControlId

    -- the carried bags only: a frame the game shows for a bank bag (or the keyring) is not the player's bags
    local carried = {}
    for _, bag in ipairs(Game.bagIds()) do
        carried[bag] = true
    end
    local positions = {}
    for _, itemButton in ipairs(Game.bagButtons()) do
        local bag, slot = containers.slotLocation(itemButton)
        if carried[bag] then
            tinsert(positions, { bag = bag, slot = slot, button = itemButton })
        end
    end
    local result = Hints.compute(positions)

    builder:beginStop(Screen.STOP)
    builder:addItem(
        ControlId.structural("auctionHints:summary"),
        nodes.text({ label = Hints.summaryText(result, Game.time()), live = false })
    )
    local entries = result.entries or {}
    if #entries > 0 then
        builder:pushContext("auctionHints:list", L["For sale at the auction house"])
        for _, entry in ipairs(entries) do
            builder:addItem(
                -- by item, not by slot: the focus stays on the line when its first stack changes
                ControlId.structural("auctionHints:item:" .. entry.itemID),
                slotNode(containers, entry)
            )
        end
        builder:popContext()
    end
    return true
end
