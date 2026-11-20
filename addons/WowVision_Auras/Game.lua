-- Everything this addon asks of the game and of WowVision, in one table, so the tests can replace it.
--
-- The auras are not read here: WowVision's own Aura buffer (core/buffers/types/AuraBuffer.lua) already reads the
-- buffs and debuffs of a unit under every restriction the game puts on addons (Retail's and WoW: Forever's secret
-- values in combat and in instances: the read by index where it is allowed, the game's own tooltip where it is not,
-- the stacks from Blizzard's buff buttons), and says each one as a line. This addon makes two of those buffers of its
-- own, one for the player's buffs and one for the player's debuffs, never put in the player's saved buffers (so
-- nothing of theirs is changed, no key is taken, nothing is saved), and uses what they list. They keep themselves
-- up to date: WowVision rebuilds a live buffer when the game says the unit's auras changed.
local _, ns = ...
local L = ns.L

local Game = {}
ns.Game = Game

-- The name of the WowVision window this addon opens.
Game.WINDOW = "auras"

-- An error here must never break a key, and must not repeat on every press either: each distinct message once.
local reported = {}
function Game.report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_Auras: " .. err)
end

function Game.guarded(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            Game.report(err)
        end
    end
end

function Game.speak(text)
    if text == nil or text == "" then
        return
    end
    local wowVision = rawget(_G, "WowVision")
    if wowVision ~= nil and wowVision.speak ~= nil then
        wowVision:speak(text)
    else
        print(text)
    end
end

-- ------------------------------------------------------------ the buffers

-- The one source of each buffer, in the Aura buffer's own words ("unit:FILTER").
local SOURCES = {
    buffs = "player:HELPFUL",
    debuffs = "player:HARMFUL",
}

local buffers = {}

-- The Aura buffer of one group ("buffs" or "debuffs"), made the first time it is asked for; nil when WowVision has
-- no Aura buffer (not this version of WowVision) or it could not be made.
function Game.buffer(kind)
    if buffers[kind] ~= nil then
        return buffers[kind]
    end
    local wowVision = rawget(_G, "WowVision")
    local registry = wowVision ~= nil and wowVision.buffers ~= nil and wowVision.buffers.registry or nil
    if registry == nil or registry.types == nil or registry.types:get("Aura") == nil then
        return nil
    end
    -- speak the time left and the dispel type, not the description (that is for Space, the tooltip key)
    local ok, buffer = pcall(registry.createTemporaryComponent, registry, {
        type = "Aura",
        sources = { SOURCES[kind] },
        speakRemaining = true,
        speakDescription = false,
    })
    if not ok then
        Game.report(buffer)
        return nil
    end
    buffers[kind] = buffer
    return buffer
end

-- The items of one group: AuraItems, or one message item ("Player Buffs, none", "..., unavailable") when there is
-- nothing to list. refresh: read the game again first (opening the list, a key press); between those the buffer keeps
-- itself up to date. nil when there is no buffer.
function Game.items(kind, refresh)
    local buffer = Game.buffer(kind)
    if buffer == nil then
        return nil
    end
    if refresh and type(buffer.rebuild) == "function" then
        local ok, err = pcall(buffer.rebuild, buffer)
        if not ok then
            Game.report(err)
        end
    end
    return buffer.items or {}
end

-- What an item says: name, stacks, time left, dispel type (a debuff's). A secret string is passed on as it is (it can
-- be joined with ".." and spoken, nothing else); a failure says "unavailable".
function Game.line(item)
    local ok, text = pcall(item.getFocusString, item)
    if not ok or text == nil then
        return L["unavailable"]
    end
    return text
end

-- ------------------------------------------------------------- the window

local function host()
    local wowVision = rawget(_G, "WowVision")
    return wowVision ~= nil and wowVision.UIHost or nil
end

function Game.isOpen()
    local current = host()
    local manager = current ~= nil and current.windowManager or nil
    if manager == nil then
        return false
    end
    for _, instance in ipairs(manager.openWindows) do
        if instance.name == Game.WINDOW then
            return true
        end
    end
    return false
end

-- Opens the frameless graph window. screen is the graphScreen config (render, onRequestClose...).
function Game.open(screen)
    local current = host()
    if current == nil then
        return false
    end
    current:openTemporaryWindow({ name = Game.WINDOW, graphScreen = screen })
    return true
end

function Game.close()
    local current = host()
    if current ~= nil then
        current:closeWindow(Game.WINDOW)
    end
end
