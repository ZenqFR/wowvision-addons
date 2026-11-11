-- Glue: WowNav names every target through WowVision.wownavText.targetName(
-- target, german) -- the destination list (F10), its search text, the route
-- announcements and WowVisionNavigationTargetName all call it through that
-- table at the time they need a name -- so wrapping it reaches them all.
local _, ns = ...
local Names = ns.Names

local function install()
    local text = WowVision ~= nil and WowVision.wownavText or nil
    -- WowNav only exists on WoW: Forever; elsewhere there is nothing to do.
    if text == nil or type(text.targetName) ~= "function" then
        return false
    end
    -- A WowVision that names targets in the game's language itself (it has been part of WowVision since the pull
    -- request this addon came from was merged) needs none of this, and its own setting must be the one that counts:
    -- wrapping it again would keep naming targets after the player turned that setting off.
    if type(text.localName) == "function" then
        ns.standsAside = true
        return true
    end
    if text.localizedNamesInstalled then
        return true
    end
    text.localizedNamesInstalled = true

    local original = text.targetName
    text.targetName = function(target, german, ...)
        -- german = true is a caller asking for the German name on purpose.
        if german ~= true and Names.appliesToLocale() and Names.isEnabled() then
            local ok, localized = pcall(Names.localized, target)
            if ok then
                target = localized
            end
        end
        return original(target, german, ...)
    end
    return true
end

ns.installed = install()

-- ----------------------------------------------------------------- command

local function say(message)
    if WowVision ~= nil and WowVision.speak ~= nil then
        local ok = pcall(WowVision.speak, WowVision, message)
        if ok then
            return
        end
    end
    print(message)
end

function ns.handleCommand(message)
    local L = ns.L
    if ns.standsAside then
        say(L["WowVision now names creatures and objects in your language itself, with its own setting; this addon does nothing."])
        return
    end
    local word = (message or ""):lower():match("^%s*(%S*)")
    if word == "on" or word == "oui" or word == "ja" or word == "an" or word == "1" then
        Names.setEnabled(true)
    elseif word == "off" or word == "non" or word == "nein" or word == "aus" or word == "0" then
        Names.setEnabled(false)
    elseif word ~= "" then
        Names.setEnabled(not Names.isEnabled())
    end
    Names.clearCache()
    if Names.isEnabled() then
        say(L["Localized navigation names: on"])
    else
        say(L["Localized navigation names: off"])
    end
end

if SlashCmdList ~= nil then
    SLASH_WVLOCALIZEDNAMES1 = "/wvnames"
    SlashCmdList["WVLOCALIZEDNAMES"] = ns.handleCommand
end
