-- Glue: put Core.augment behind WowVision's item tooltip hook, and the
-- /wvcompare command that switches each part on or off.
--
-- WowVision builds the lines of an item tooltip in
-- WowVision.items.augmentTooltipLines(lines, link) and looks that function up
-- again on every read, so wrapping it reaches both reading modes: Space joins
-- the lines, Shift+Down steps through them.
local _, ns = ...
local Core = ns.Core
local L = ns.L

local reported = {}

-- An error here must never break the tooltip, and must not repeat on every
-- key press either: report each distinct message once.
local function report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_ItemCompare: " .. err)
end

local function install()
    local items = WowVision ~= nil and WowVision.items or nil
    if items == nil or type(items.augmentTooltipLines) ~= "function" then
        print("WowVision_ItemCompare: " .. L.hookMissing)
        return false
    end
    -- A WowVision that makes the comparison itself (it has been part of WowVision since the pull request that this
    -- addon came from was merged) needs none of this: adding it again would read every line twice.
    if type(items.augmentComparisonLines) == "function" then
        ns.standsAside = true
        return true
    end
    if items.itemCompareInstalled then
        return true
    end
    items.itemCompareInstalled = true

    local original = items.augmentTooltipLines
    items.augmentTooltipLines = function(lines, link, ...)
        local ok, err = pcall(original, lines, link, ...)
        local added, addErr = pcall(Core.augment, lines, link)
        if not added then
            report(addErr)
        end
        if not ok then
            error(err, 0)
        end
    end
    return true
end

ns.installed = install()

-- ----------------------------------------------------------------- command

local function say(text)
    if WowVision ~= nil and WowVision.speak ~= nil then
        local ok = pcall(WowVision.speak, WowVision, text)
        if ok then
            return
        end
    end
    print(text)
end

local function stateWord(enabled)
    return enabled and L.on or L.off
end

local function describe(key, name)
    return L.status:format(name, stateWord(Core.getSetting(key)))
end

local PARTS = {
    pawn = { key = "pawn", name = function() return L.pawnName end },
    equipped = { key = "equipped", name = function() return L.equippedName end },
    equip = { key = "equipped", name = function() return L.equippedName end },
}

function ns.handleCommand(message)
    if ns.standsAside then
        say(L.standsAside)
        return
    end
    local word, value = (message or ""):lower():match("^%s*(%S*)%s*(%S*)")
    local part = PARTS[word or ""]
    if part == nil then
        say(table.concat({
            describe("pawn", L.pawnName),
            describe("equipped", L.equippedName),
            L.usage,
        }, ". "))
        return
    end

    local enabled
    if value == "on" or value == "1" or value == "oui" or value == "ja" or value == "an" then
        enabled = true
    elseif value == "off" or value == "0" or value == "non" or value == "nein" or value == "aus" then
        enabled = false
    else
        enabled = not Core.getSetting(part.key)
    end
    Core.setSetting(part.key, enabled)

    local text = L.status:format(part.name(), stateWord(enabled))
    if part.key == "pawn" and enabled and PawnGetItemData == nil then
        text = text .. ". " .. L.pawnMissing
    end
    say(text)
end

if SlashCmdList ~= nil then
    SLASH_WVITEMCOMPARE1 = "/wvcompare"
    SlashCmdList["WVITEMCOMPARE"] = ns.handleCommand
end
