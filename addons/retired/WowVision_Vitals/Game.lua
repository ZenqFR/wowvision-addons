-- The game's side of Vitals.lua. Every call is looked up when it is used, so a client without one loses that part
-- and not the addon.
local _, ns = ...

local Game = {}
ns.Game = Game

local function isSecret(value)
    if WowVision ~= nil and WowVision.isSecret ~= nil then
        return WowVision.isSecret(value)
    end
    return false
end

local function powerName(token)
    if type(token) ~= "string" then
        return nil
    end
    -- The game keeps the resources' own names in globals named by their token: MANA, RAGE, ENERGY...
    local name = rawget(_G, token)
    if type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

function Game.api()
    return {
        health = function()
            return UnitHealth("player"), UnitHealthMax("player")
        end,
        power = function()
            local id, token = UnitPowerType("player")
            return UnitPower("player", id), UnitPowerMax("player", id), token
        end,
        powerName = powerName,
        isSecret = isSecret,
    }
end
