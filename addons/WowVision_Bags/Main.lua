-- Glue: install the hooks, bring over the marks the junk code inside WowVision kept before this addon existed, and
-- the /wvbags command that switches each part on or off.
local _, ns = ...
local L = ns.L

local function say(text)
    if WowVision ~= nil and WowVision.speak ~= nil then
        local ok = pcall(WowVision.speak, WowVision, text)
        if ok then
            return
        end
    end
    print(text)
end

-- Before this addon, the junk marks lived in WowVision's own saved data (a module that was part of a modified
-- WowVision). They are copied over once, and the original is left where it is.
local function importOldMarks()
    local root = ns.root()
    if root.imported then
        return
    end
    root.imported = true
    local ok, old = pcall(function()
        return WowVisionDB.submodules.windows.submodules.junk.data.marks
    end)
    if not ok or type(old) ~= "table" then
        return
    end
    local marks = ns.section("junk").marks
    for key, name in pairs(old) do
        if marks[key] == nil then
            marks[key] = name
        end
    end
end

local function install()
    if WowVision == nil or WowVision.base == nil then
        return
    end
    local windows = WowVision.base.windows
    -- A WowVision that has these lists itself needs none of this.
    if WowVision.bagLists ~= nil or (windows ~= nil and windows.junk ~= nil) then
        print("WowVision_Bags: " .. L["WowVision already has its own bag lists; WowVision Bags does nothing."])
        return
    end
    pcall(importOldMarks)
    -- Each hook stands alone: one that cannot be installed is said once and the others go on.
    ns.hooks = {}
    local missing = {
        installSlots = "WowVision's bags were not found; the marks are not available.",
        installLists = "WowVision's bags were not found; the item lists are not available.",
        installMerchant = "WowVision's merchant window was not found; marked junk will not be sold.",
        installBindings = "WowVision's key bindings were not found; the marking keys are not available.",
    }
    for _, hook in ipairs({ "installSlots", "installLists", "installMerchant", "installBindings" }) do
        local ok, installed = pcall(ns[hook])
        ns.hooks[hook] = ok and installed == true
        if not ok then
            ns.report(installed)
        elseif not installed then
            print("WowVision_Bags: " .. L[missing[hook]])
        end
    end
    -- The new items the game does not flag (a quest's reward) are found by watching what the bags hold.
    local watching, err = pcall(ns.newItems.watch)
    if not watching then
        ns.report(err)
    end
    ns.installed = true
end

install()

-- ----------------------------------------------------------------- command

local ON = { on = true, ["1"] = true, oui = true, yes = true, ja = true, an = true }
local OFF = { off = true, ["0"] = true, non = true, no = true, nein = true, aus = true }

local PARTS = {
    junk = "junk",
    camelote = "junk",
    plunder = "junk",
    sell = "sell",
    vente = "sell",
    vendre = "sell",
    verkauf = "sell",
    favorites = "favorites",
    favorite = "favorites",
    favoris = "favorites",
    favori = "favorites",
    favoriten = "favorites",
}

local FORGET = { forget = true, oublier = true, vergessen = true }

-- /wvbags new: the new items this addon has seen arrive and that are waiting to be looked at, said by name.
local NEW = { new = true, nouveaux = true, nouveau = true, neue = true, neu = true }

local function itemName(itemID)
    local getName = C_Item ~= nil and C_Item.GetItemNameByID or nil
    if getName ~= nil then
        local ok, name = pcall(getName, itemID)
        if ok and type(name) == "string" then
            return name
        end
    end
    local getInfo = C_Item ~= nil and C_Item.GetItemInfo or GetItemInfo
    if getInfo ~= nil then
        local ok, name = pcall(getInfo, itemID)
        if ok and type(name) == "string" then
            return name
        end
    end
    return tostring(itemID)
end

function ns.describeNewItems()
    local ids = ns.newItems.arrivedIDs()
    if #ids == 0 then
        return L["No new item followed."]
    end
    local names = {}
    for index = 1, math.min(#ids, 8) do
        tinsert(names, itemName(ids[index]))
    end
    local text = table.concat(names, ", ")
    if #ids > 8 then
        text = string.format(L["%s and %d more"], text, #ids - 8)
    end
    return string.format(L["New items followed: %s."], text)
end

local function stateWord(enabled)
    return enabled and L["on"] or L["off"]
end

local function describe()
    return table.concat({
        string.format(L["%s: %s"], L["Junk marks"], stateWord(ns.junk:isEnabled())),
        string.format(L["%s: %s"], L["Selling marked junk at merchants"], stateWord(ns.junk:sellsAtMerchants())),
        string.format(L["%s: %s"], L["Favorites marks"], stateWord(ns.favorites:isEnabled())),
    }, ". ")
end

function ns.handleCommand(message)
    local first, second, third = (message or ""):lower():match("^%s*(%S*)%s*(%S*)%s*(%S*)")
    if NEW[first or ""] then
        say(ns.describeNewItems())
        return
    end
    if FORGET[first or ""] then
        local part = PARTS[second or ""]
        if part == "junk" then
            ns.junk:forget()
            say(L["Junk marks forgotten"])
        elseif part == "favorites" then
            ns.favorites:forget()
            say(L["Favorites forgotten"])
        else
            say(L["Use /wvbags junk, sell or favorites to switch one on or off (add on or off), /wvbags forget junk or forget favorites to take every mark off."])
        end
        return
    end
    local part = PARTS[first or ""]
    if part == nil then
        say(describe() .. ". " .. L["Use /wvbags junk, sell or favorites to switch one on or off (add on or off), /wvbags forget junk or forget favorites to take every mark off."])
        return
    end
    local current
    if part == "junk" then
        current = ns.junk:isEnabled()
    elseif part == "sell" then
        current = ns.junk:sellsAtMerchants()
    else
        current = ns.favorites:isEnabled()
    end
    local enabled
    if ON[second or ""] then
        enabled = true
    elseif OFF[second or ""] then
        enabled = false
    else
        enabled = not current
    end
    if part == "junk" then
        ns.junk:setEnabled(enabled)
    elseif part == "sell" then
        ns.junk:setSellsAtMerchants(enabled)
    else
        ns.favorites:setEnabled(enabled)
    end
    local name = part == "junk" and L["Junk marks"]
        or part == "sell" and L["Selling marked junk at merchants"]
        or L["Favorites marks"]
    say(string.format(L["%s: %s"], name, stateWord(enabled)))
end

if SlashCmdList ~= nil then
    SLASH_WVBAGS1 = "/wvbags"
    SlashCmdList["WVBAGS"] = ns.handleCommand
end
