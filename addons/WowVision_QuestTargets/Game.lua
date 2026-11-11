-- The game's side of Targets.lua: the unit tokens to look at and the calls that answer about them. Every call is
-- looked up when it is used and a missing one is simply absent, so a client without it loses that part and not the
-- addon.
local _, ns = ...

local Game = {}
ns.Game = Game

-- The units that can be looked at: the target, the soft target and the mouseover, then the enemy nameplates (the
-- only way to reach a creature that is not already under the cursor). The nameplates exist only for enemies in
-- range while the game shows enemy nameplates (Game.platesShown).
local UNITS = { "target", "softenemy", "mouseover" }
for index = 1, 40 do
    tinsert(UNITS, "nameplate" .. index)
end

local function isSecret(value)
    if WowVision ~= nil and WowVision.isSecret ~= nil then
        return WowVision.isSecret(value)
    end
    return false
end

local function lines(unit)
    if C_TooltipInfo == nil or C_TooltipInfo.GetUnit == nil then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil
    end
    local out = {}
    for index, line in ipairs(data.lines) do
        out[index] = { type = line.type, text = line.leftText, completed = line.completed }
    end
    return out
end

local rangeCheck = LibStub ~= nil and LibStub("LibRangeCheck-3.0", true) or nil

local function range(unit)
    if rangeCheck == nil then
        return nil
    end
    return rangeCheck:GetRange(unit)
end

-- The api Targets.collect asks. related and lines are absent when the client lacks C_QuestLog.UnitIsRelatedToActiveQuest
-- and C_TooltipInfo.GetUnit.
function Game.api()
    local api = {
        units = function()
            return UNITS
        end,
        exists = UnitExists,
        isUnit = UnitIsUnit,
        isPlayer = UnitIsPlayer,
        canAttack = function(unit)
            return UnitCanAttack("player", unit)
        end,
        isDead = UnitIsDead,
        name = UnitName,
        range = range,
        isSecret = isSecret,
    }
    if C_QuestLog ~= nil and C_QuestLog.UnitIsRelatedToActiveQuest ~= nil then
        api.related = C_QuestLog.UnitIsRelatedToActiveQuest
    end
    if C_TooltipInfo ~= nil and C_TooltipInfo.GetUnit ~= nil then
        api.lines = lines
    end
    return api
end

-- Whether the client can tell which creatures belong to the player's quests at all.
function Game.canTell()
    return (C_QuestLog ~= nil and C_QuestLog.UnitIsRelatedToActiveQuest ~= nil)
        or (C_TooltipInfo ~= nil and C_TooltipInfo.GetUnit ~= nil)
end

-- Enemy nameplates are off by default; without them only the target, the soft target and the mouseover can be read.
function Game.platesShown()
    local getBool = C_CVar ~= nil and C_CVar.GetCVarBool or GetCVarBool
    if getBool == nil then
        return true
    end
    local ok, shown = pcall(getBool, "nameplateShowEnemies")
    return not ok or shown ~= false
end

function Game.showPlates()
    local set = C_CVar ~= nil and C_CVar.SetCVar or SetCVar
    if set == nil then
        return false
    end
    local ok = pcall(set, "nameplateShowEnemies", "1")
    return ok
end
