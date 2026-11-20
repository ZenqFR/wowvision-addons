-- Glue: the window registered with WowVision, the key that opens LFG Forever (WowVision's Bindings screen lists it) and
-- the /wvlfg command.
local _, ns = ...
local L = ns.L
local Game = ns.Game
local Screen = ns.Screen

-- The window: WowVision opens its screen whenever LFG Forever's window is shown (/lfg, LFG Forever's own key, its
-- minimap button) and closes it when that is hidden.
function ns.installWindow()
    local ok, installed = pcall(Game.registerWindow, Screen.config())
    if not ok then
        Game.report(installed)
        return false
    end
    return installed
end

-- Opens LFG Forever's window, or closes it when it is open: the same as /lfg.
function ns.toggle()
    if not Game.isLoaded() then
        Game.speak(L["LFG Forever is not loaded."])
        return false
    end
    return Game.toggle()
end

-- The key. G for "group"; Alt+Ctrl is the family of the extensions' own keys (Alt+Ctrl+J, Alt+Ctrl+Q, Alt+Ctrl+B...),
-- and the key is used by neither WowVision nor any of the other extensions (tests/real_core.lua checks that against
-- WowVision's real input manager). LFG Forever has its own two keys (Open and Search) in the game's Keybindings; they
-- are not taken over.
ns.bindings = {
    {
        type = "Function",
        key = "lfgForever/open",
        label = "Open or close LFG Forever",
        inputs = { "ALT-CTRL-G" },
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

if rawget(_G, "WowVision") ~= nil then
    ns.windowInstalled = ns.installWindow()
    ns.installed = ns.installBindings()
end

-- ----------------------------------------------------------------- command

local HELP = { help = true, aide = true, hilfe = true }

-- /wvlfg opens LFG Forever, or closes it.
function ns.handleCommand(message)
    local word = (message or ""):lower():match("^%s*(%S*)") or ""
    if HELP[word] then
        Game.speak(L["Use /wvlfg to open or close LFG Forever."])
        return
    end
    ns.toggle()
end

if SlashCmdList ~= nil then
    SLASH_WVLFG1 = "/wvlfg"
    SLASH_WVLFG2 = "/wvgroupe"
    SLASH_WVLFG3 = "/wvgruppe"
    SlashCmdList["WVLFG"] = Game.guarded(ns.handleCommand)
end
