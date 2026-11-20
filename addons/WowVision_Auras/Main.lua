-- Glue: the two keys (WowVision's Bindings screen lists them) and the /wvauras command.
local _, ns = ...
local L = ns.L
local Game = ns.Game
local Auras = ns.Auras
local Screen = ns.Screen

-- Alt+Ctrl+B: every buff, then every debuff, said at once.
function ns.sayAll()
    local groups = Auras.read(true)
    if groups == nil then
        Game.speak(L["Auras are not available."])
        return
    end
    Game.speak(Auras.allText(groups))
end

-- /wvauras count: just the numbers.
function ns.sayCount()
    local groups = Auras.read(true)
    if groups == nil then
        Game.speak(L["Auras are not available."])
        return
    end
    Game.speak(Auras.countText(groups))
end

-- The keys. B for "buffs"; Alt+Ctrl is the family of the extensions' own keys (Alt+Ctrl+J, Alt+Ctrl+Q...), and neither
-- key is used by WowVision or by any of the other extensions (tests/real_core.lua checks that against WowVision's real
-- input manager).
ns.bindings = {
    {
        type = "Function",
        key = "auras/say",
        label = "Say the player's buffs and debuffs",
        inputs = { "ALT-CTRL-B" },
        interruptSpeech = true,
        func = function()
            ns.sayAll()
        end,
    },
    {
        type = "Function",
        key = "auras/open",
        label = "Open the list of the player's buffs and debuffs",
        inputs = { "ALT-SHIFT-B" },
        interruptSpeech = true,
        func = function()
            Screen.toggle()
        end,
    },
}

-- The keys are bindings like WowVision's own: listed, and changeable, in the Bindings screen (/wv, Interface,
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
    ns.installed = ns.installBindings()
end

-- ----------------------------------------------------------------- command

local SAY = { say = true, dire = true, sagen = true, alle = true, tout = true, all = true }
local COUNT = { count = true, nombre = true, anzahl = true, numbers = true }
local HELP = { help = true, aide = true, hilfe = true }

-- /wvauras: opens the list (or closes it); /wvauras say (dire, sagen): says them all; /wvauras count (nombre, anzahl):
-- says the numbers.
function ns.handleCommand(message)
    local word = (message or ""):lower():match("^%s*(%S*)") or ""
    if SAY[word] then
        ns.sayAll()
    elseif COUNT[word] then
        ns.sayCount()
    elseif HELP[word] then
        Game.speak(L["Use /wvauras to open the list, /wvauras say to hear them all, /wvauras count for the numbers."])
    else
        Screen.toggle()
    end
end

if SlashCmdList ~= nil then
    SLASH_WVAURAS1 = "/wvauras"
    SLASH_WVAURAS2 = "/wvbuffs"
    SLASH_WVAURAS3 = "/wvauren"
    SlashCmdList["WVAURAS"] = Game.guarded(ns.handleCommand)
end
