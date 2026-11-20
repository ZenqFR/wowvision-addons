-- Glue: the key (WowVision's Bindings screen lists it), the /wvloot command, and the hook that opens the screen when
-- AtlasLoot's own window opens (/al).
local _, ns = ...
local L = ns.L
local Game = ns.Game
local Screen = ns.Screen

-- Whether the screen was opened by AtlasLoot's window (then closing the screen closes that window too).
ns.openedByAl = false

-- The key and the command: the screen, open or closed.
function ns.toggle()
    ns.hookAtlasFrame()
    if Game.isOpen() then
        Screen.close()
        return
    end
    if Game.atlas() == nil then
        Game.speak(L["AtlasLoot is not installed or not enabled."])
        return
    end
    ns.openedByAl = false
    Screen.open()
end

-- Closing the screen that AtlasLoot's window opened closes that window as well.
function ns.afterClose()
    if not ns.openedByAl then
        return
    end
    ns.openedByAl = false
    local frame = Game.atlasFrame()
    if frame ~= nil and type(frame.IsShown) == "function" and frame:IsShown() then
        pcall(frame.Hide, frame)
    end
end

-- AtlasLoot's window (/al) opens the screen too, and closes it when it is closed. The window is built a little after
-- AtlasLoot is read, so this is tried again at each event below.
function ns.hookAtlasFrame()
    local frame = Game.atlasFrame()
    if frame == nil or ns.frameHooked or type(frame.HookScript) ~= "function" then
        return false
    end
    frame:HookScript(
        "OnShow",
        Game.guarded(function()
            if Game.getSetting("openWithAl") ~= true or Game.isOpen() or Game.atlas() == nil then
                return
            end
            ns.openedByAl = true
            Screen.open()
        end)
    )
    frame:HookScript(
        "OnHide",
        Game.guarded(function()
            if ns.openedByAl and Game.isOpen() then
                ns.openedByAl = false
                Game.close()
            end
        end)
    )
    ns.frameHooked = true
    return true
end

-- --------------------------------------------------------------------- key

ns.bindings = {
    {
        type = "Function",
        key = "atlasloot/open",
        label = "Open the loot browser (AtlasLoot)",
        inputs = { "ALT-L" },
        interruptSpeech = true,
        func = function()
            ns.toggle()
        end,
    },
}

-- The key is a binding like WowVision's own: listed, and changeable, in the Bindings screen (/wv, Interface,
-- Bindings). WowVision keeps every binding in one registry and stores the player's keys by the binding's key, so a
-- binding added now is picked up like the ones it loaded with.
function ns.installBindings()
    local input = WowVision ~= nil and WowVision.input or nil
    if input == nil or type(input.createBinding) ~= "function" or type(input.getBinding) ~= "function" then
        return false
    end
    local created = {}
    for _, info in ipairs(ns.bindings) do
        if input:getBinding(info.key) == nil then
            local copy = {}
            for key, value in pairs(info) do
                copy[key] = value
            end
            copy.label = L[info.label]
            copy.func = Game.guarded(info.func)
            tinsert(created, input:createBinding(copy))
        end
    end
    if #created > 0 then
        local resolved = WowVision.dbManager:resolveBindings(input:getDefaultDB(), WowVisionDB, WowVision.globalDb)
        WowVision:applyBindingStore(resolved)
        for _, binding in ipairs(created) do
            binding:activate()
        end
    end
    return true
end

-- ----------------------------------------------------------------- command

local HELP = { help = true, aide = true, hilfe = true }

function ns.handleCommand(message)
    local word = (message or ""):lower():match("^%s*(%S*)") or ""
    if HELP[word] then
        Game.speak(
            L["Loot browser: /wvloot opens or closes the screen where you pick a category, a dungeon and a boss and hear the loot. It also opens when AtlasLoot's own window does (/al)."]
        )
        return
    end
    ns.toggle()
end

if SlashCmdList ~= nil then
    SLASH_WVATLASLOOT1 = "/wvloot"
    SLASH_WVATLASLOOT2 = "/wvbutin"
    SLASH_WVATLASLOOT3 = "/wvbeute"
    SlashCmdList["WVATLASLOOT"] = Game.guarded(ns.handleCommand)
end

-- ------------------------------------------------------------------- start

local function install()
    if WowVision == nil or WowVision.input == nil then
        return false
    end
    local ok, installed = pcall(ns.installBindings)
    if not ok then
        Game.report(installed)
        return false
    end
    return installed
end

ns.installed = install()

if CreateFrame ~= nil then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:SetScript("OnEvent", function(_, event, itemId, success)
        if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
            -- what is an upgrade depends on what is worn, and what a class can wear depends on its level
            Game.gearChanged()
            return
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            -- an item the server does not know never gets a name: the search must not wait for it
            Game.itemReceived(itemId, success)
            return
        end
        local ok, err = pcall(ns.hookAtlasFrame)
        if not ok then
            Game.report(err)
        end
    end)
end
