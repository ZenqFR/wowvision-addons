-- What the key does, as plain functions over a small game interface, so the tests run them as they are. Where the
-- target stands is WowVision's own business (WowVision.targetFind, the one its "Route to Your Target" key uses): a
-- group member's real position from the game, and for a creature the nearest spot WowNav knows that creature at (the
-- game hides the real position of any other creature from addons). This only asks it and decides what to say.
local _, ns = ...
local L = ns.L

local Target = {}
ns.Target = Target

-- How far a followed group member has to walk before the beacon is aimed at them again.
Target.REAIM_YARDS = 8

-- api: exists() -> bool; isPlayer() -> bool; name() -> text; player() -> px, py, map or nil; plus what
-- targetFind.locate reads (groupUnit, unitPosition, guid, engine, waypointNamed, hasRouteData).
-- Returns { say = text } (nothing to aim at) or { target = { x, y, n, unit?, guid? } }.
function Target.plan(api, targetFind)
    if not api.exists() then
        return { say = L["You have no target."] }
    end
    if api.isPlayer() then
        return { say = L["You are targeting yourself."] }
    end
    local px, py, map = api.player()
    if px == nil then
        return { say = L["Position unavailable."] }
    end
    local found = targetFind.locate(api, px, py, map)
    if found == nil then
        return { say = L["Your target's position is not known."] }
    end
    local data = type(found.data) == "table" and found.data or nil
    return {
        target = {
            x = found.x,
            y = found.y,
            n = found.n or api.name(),
            -- the party or raid unit, when the target is one: its position is read again as it walks
            unit = data ~= nil and data.unit or nil,
            guid = api.guid(),
        },
    }
end

-- "Lazy Peon, 120 yards, ahead left": the name, then WowVision's own words for the distance and the direction.
function Target.text(maps, target)
    local where = maps:whereText(target.x, target.y)
    if where == nil or where == "" then
        return target.n .. ", " .. L["Position unavailable."]
    end
    return target.n .. ", " .. where
end

-- Whether the target now is the one the beacon was aimed at: the same GUID, or, when the game keeps a GUID back
-- (a secret value), the same party or raid unit.
function Target.same(following, api)
    local guid = api.guid()
    if guid ~= nil and following.guid ~= nil then
        return guid == following.guid
    end
    if following.unit ~= nil then
        return api.groupUnit() == following.unit
    end
    return false
end

-- Whether a followed group member has walked far enough from where the beacon was aimed to aim it again.
function Target.moved(from, x, y)
    local dx, dy = x - from.x, y - from.y
    return math.sqrt(dx * dx + dy * dy) > Target.REAIM_YARDS
end
