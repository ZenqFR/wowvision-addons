-- What is said about the player's health and resource, as a percentage. Pure Lua without game functions, so the
-- offline tests run it: the game's side is handed in as api.
--
-- api:
--   health()           the player's current and maximum health
--   power()            the player's current and maximum main resource, and its token ("MANA", "RAGE"...)
--   powerName(token)   the game's own name for that resource, or nothing
--   isSecret(value)    the restricted clients can hide a value; such a value cannot be read
local _, ns = ...
local L = ns.L

local Vitals = {}
ns.Vitals = Vitals

-- The whole percentage of current in maximum, or nil when it cannot be worked out. It is rounded, but never says
-- 0 while there is something left, nor 100 while there is something missing: those two words mean "dead or empty"
-- and "full", and a rounded 0.4 or 99.6 would mislead.
function Vitals.percent(current, maximum)
    if type(current) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then
        return nil
    end
    local percent = math.floor(current / maximum * 100 + 0.5)
    if current > 0 and percent < 1 then
        percent = 1
    end
    if current < maximum and percent > 99 then
        percent = 99
    end
    if percent > 100 then
        percent = 100
    end
    if percent < 0 then
        percent = 0
    end
    return percent
end

local function hidden(api, ...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil and api.isSecret(value) then
            return true
        end
    end
    return false
end

function Vitals.healthText(api)
    local current, maximum = api.health()
    if hidden(api, current, maximum) then
        return L["The game hides this value."]
    end
    local percent = Vitals.percent(current, maximum)
    if percent == nil then
        return L["Nothing to read."]
    end
    return string.format(L["%s %d percent"], L["Health"], percent)
end

function Vitals.powerText(api)
    local current, maximum, token = api.power()
    if hidden(api, current, maximum, token) then
        return L["The game hides this value."]
    end
    if type(maximum) == "number" and maximum <= 0 then
        return L["No resource to read."]
    end
    local percent = Vitals.percent(current, maximum)
    if percent == nil then
        return L["Nothing to read."]
    end
    local name = api.powerName ~= nil and api.powerName(token) or nil
    return string.format(L["%s %d percent"], name or L["Resource"], percent)
end

-- Both, for the command.
function Vitals.bothText(api)
    return string.format(L["%s and %s"], Vitals.healthText(api), Vitals.powerText(api))
end
