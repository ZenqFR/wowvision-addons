-- Glue: the hook that adds the stop to WowVision's bags screen, and the /wvhdv command.
--
-- Where the stop goes. WowVision's bags window ("bags", in the containers module) draws one screen: its render function
-- pushes the "Bags" context and asks every container component that is open (the carried bags, the bank) to draw
-- itself, one after the other. WowVision 1.0.4 draws the bag controls and the search box BEFORE the bags, the Item
-- Lists of WowVision_Bags go right after them, and the bank's stops follow when the bank is open. To be the last stop
-- of all, the hook wraps the window's render function itself and adds the stop when everything else has drawn. The
-- window copies its screen configuration when it opens, so a wrapper put in its table now is the one used from then
-- on, whatever order the addons loaded in. Should a WowVision change take that door away, the second hook wraps the
-- carried bags' own renderGraph instead (last of the bags, but before the bank's stops).
local _, ns = ...
local L = ns.L
local Game = ns.Game
local Screen = ns.Screen
local Hints = ns.Hints

-- Draws the stop after the original has drawn, without ever letting an error of ours reach the bags.
local function afterRender(builder)
    local ok, err = pcall(Screen.addStop, builder)
    if not ok then
        Game.report(err)
    end
end

-- Preferred: wrap the render function of the bags window's screen.
function ns.installWindow()
    local window = Game.bagsWindow()
    local screen = window ~= nil and window.graphScreen or nil
    if type(screen) ~= "table" or type(screen.render) ~= "function" then
        return false
    end
    if screen.auctionHintsWrapped then
        return true
    end
    screen.auctionHintsWrapped = true
    local original = screen.render
    screen.render = function(builder, ...)
        local a, b = original(builder, ...)
        afterRender(builder)
        return a, b
    end
    return true
end

-- Fallback: wrap the carried bags' own renderGraph.
function ns.installComponent()
    local Bags = Game.bagsComponentType()
    if Bags == nil or type(Bags.renderGraph) ~= "function" then
        return false
    end
    if Bags.auctionHintsWrapped then
        return true
    end
    Bags.auctionHintsWrapped = true
    local original = Bags.renderGraph
    Bags.renderGraph = function(self, builder, ...)
        local a, b = original(self, builder, ...)
        afterRender(builder)
        return a, b
    end
    return true
end

local function install()
    if rawget(_G, "WowVision") == nil or WowVision.base == nil then
        return
    end
    ns.hooks = {}
    local ok, installed = pcall(ns.installWindow)
    ns.hooks.window = ok and installed == true
    if not ok then
        Game.report(installed)
    end
    if not ns.hooks.window then
        local okComponent, installedComponent = pcall(ns.installComponent)
        ns.hooks.component = okComponent and installedComponent == true
        if not okComponent then
            Game.report(installedComponent)
        elseif not installedComponent then
            print("WowVision_AuctionHints: " .. L["WowVision's bags were not found; the auction house stop is not available."])
        end
    end
    ns.installed = true
end

install()

-- ------------------------------------------------------------ the shared answer

-- WowVision_Bags' merchant category asks where each slot belongs here, so that the same function decides the auction
-- house list and the merchant category: a slot is in one or the other, never both (Hints.classify).
-- partition(positions) takes { { bag, slot, button? }, ... } and answers { auction = {...}, merchant = {...},
-- merchantLines = {...}, problem }: the positions (the same tables, in the order given) that are for the auction house
-- and that are for a vendor, and the merchant category's lines, one per ITEM however many stacks hold it, in the order
-- of the bags: { itemID, name, count (all the stacks), stacks, vendorUnit, vendorTotal, bag, slot, button (the first
-- stack's), piles = { { bag, slot, count, button } ... }, text (what is said) }; nil in combat. problem is "nomarket"
-- or "noprices" when there are no prices: then everything a vendor buys is for a vendor. version 2 added the lines.
WowVisionAuctionHints = {
    version = 2,
    partition = function(positions)
        if Game.inCombat() then
            return nil
        end
        local result = Hints.compute(positions)
        for _, line in ipairs(result.merchantLines) do
            line.text = Hints.merchantText(line)
        end
        return {
            auction = result.auctionPositions,
            merchant = result.merchantPositions,
            merchantLines = result.merchantLines,
            problem = result.problem,
        }
    end,
}

-- ----------------------------------------------------------------- command

local FEES = { fees = true, frais = true, gebuehren = true, ["gebühren"] = true, gebuhren = true }
local YES = { on = true, ["1"] = true, oui = true, yes = true, ja = true, an = true }
local NO = { off = true, ["0"] = true, non = true, no = true, nein = true, aus = true }

-- The state of the fees setting as a sentence: "yes, 5 percent" (the house's own cut) or "no".
local function feesState()
    if Game.getSetting("fees") == true then
        local snapshot = ns.Market.snapshot()
        return ns.fill(L["yes, {cut} percent"], { cut = snapshot ~= nil and snapshot.cut or 5 })
    end
    return L["no"]
end

-- /wvhdv fees on|off (also frais oui|non, gebuehren ja|nein; no word = switch): takes the auction house's cut off its
-- prices before the 10 percent is judged, or not.
local function setFees(word)
    local enabled
    if YES[word or ""] then
        enabled = true
    elseif NO[word or ""] then
        enabled = false
    else
        enabled = Game.getSetting("fees") ~= true
    end
    Game.setSetting("fees", enabled)
    Game.speak(ns.fill(L["Auction house cut taken off: {state}."], { state = feesState() }))
end

-- /wvhdv: says what the stop says (the summary) and why the other items of the bags are not in the list. Works with
-- the bags closed; it reads the carried bags straight from the game.
function ns.handleCommand(message)
    local first, second = (message or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if FEES[first or ""] then
        setFees(second)
        return
    end
    if Game.inCombat() then
        Game.speak(L["The list is not available during combat."])
        return
    end
    local result = Hints.compute(Hints.allPositions())
    Game.speak(
        Hints.statusText(result, Game.time())
            .. " "
            .. ns.fill(L["Auction house cut taken off: {state}."], { state = feesState() })
            .. " "
            .. L["Use /wvhdv fees on or off to take the auction house's cut off its prices, or not."]
    )
end

if SlashCmdList ~= nil then
    SLASH_WVAUCTIONHINTS1 = "/wvhdv"
    SLASH_WVAUCTIONHINTS2 = "/wvah"
    SLASH_WVAUCTIONHINTS3 = "/wvauktion"
    SlashCmdList["WVAUCTIONHINTS"] = Game.guarded(ns.handleCommand)
end
