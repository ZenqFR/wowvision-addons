-- Glue: the key (WowVision's Bindings screen lists it), the /wvtarget command, the calls into the game and into
-- WowVision, and the follower that keeps a beacon on a group member who walks.
local _, ns = ...
local L = ns.L
local Target = ns.Target

-- An error here must never break the key, and must not repeat on every press either: report each distinct message
-- once.
local reported = {}
local function report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_TargetDirection: " .. err)
end
ns.report = report

local function guarded(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            report(err)
        end
    end
end

-- ---------------------------------------------------------------- the game

-- Everything this addon asks of the game and of WowVision, in one table, so the tests can replace it.
local Game = {}
ns.Game = Game

function Game.speak(text)
    if text == nil or text == "" then
        return
    end
    if WowVision ~= nil and WowVision.speak ~= nil then
        WowVision:speak(text)
    else
        print(text)
    end
end

-- WowVision's maps module: the sound beacon, the words for a distance and a direction.
function Game.maps()
    local base = WowVision ~= nil and WowVision.base or nil
    local navigation = base ~= nil and base.navigation or nil
    return navigation ~= nil and navigation.maps or nil
end

-- WowVision's own finder of where the target stands (the one its "Route to Your Target" key uses).
function Game.targetFind()
    return WowVision ~= nil and WowVision.targetFind or nil
end

local function usable(value)
    return value ~= nil and not (WowVision ~= nil and WowVision.isSecret ~= nil and WowVision.isSecret(value))
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- A unit's position as WowVision's maps read it (UnitPosition's own order), nil when the game does not say.
function Game.unitPosition(unit)
    local ok, x, y = pcall(UnitPosition, unit)
    if ok and usable(x) and usable(y) and finite(x) and finite(y) then
        return x, y
    end
    return nil
end

-- The party or raid unit that is the target, nil when the target is in no group of the player's.
local function groupUnit()
    local raid = IsInRaid ~= nil and IsInRaid()
    local count = GetNumGroupMembers ~= nil and GetNumGroupMembers() or 0
    for i = 1, raid and count or math.min(count, 4) do
        local unit = raid and ("raid" .. i) or ("party" .. i)
        if UnitExists(unit) and UnitIsUnit(unit, "target") and not UnitIsUnit(unit, "player") then
            return unit
        end
    end
    return nil
end

-- The game interface WowVision's targetFind.locate reads, built as its own route-to-target key builds it.
function Game.api(maps)
    local engine = maps:activeRouteEngine()
    return {
        exists = function()
            return UnitExists("target") == true
        end,
        isPlayer = function()
            return UnitIsUnit("target", "player") == true
        end,
        name = function()
            local name = UnitName("target")
            return usable(name) and name or L["Target"]
        end,
        player = function()
            local px, py, _, map = UnitPosition("player")
            if px == nil then
                return nil
            end
            return px, py, map
        end,
        groupUnit = groupUnit,
        unitPosition = Game.unitPosition,
        guid = function()
            local guid = UnitGUID("target")
            return usable(guid) and guid or nil
        end,
        engine = engine,
        waypointNamed = function(name, px, py)
            local fold = WowVision.utils.foldCase
            local wanted = fold(name)
            local found = WowVision.Router.nearest(maps:currentWaypoints(), px, py, 1, function(wp)
                return wp.n ~= nil and fold(wp.n) == wanted
            end)[1]
            if found == nil or found.distance > WowVision.targetFind.UNIT_RADIUS then
                return nil
            end
            return found.waypoint
        end,
        hasRouteData = function()
            return next(maps:currentWaypoints()) ~= nil
        end,
    }
end

function Game.defer(fn)
    if C_Timer ~= nil and C_Timer.After ~= nil then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

-- ------------------------------------------------------------- the actions

-- What guides now: { guid, unit?, x, y, n } while the beacon is on a target, else nil.
ns.following = nil

local function ready()
    local maps, targetFind = Game.maps(), Game.targetFind()
    if
        maps == nil
        or targetFind == nil
        or type(maps.directTo) ~= "function"
        or type(maps.whereText) ~= "function"
        or type(maps.activeRouteEngine) ~= "function"
    then
        Game.speak(L["WowVision cannot find the position of a target here."])
        return nil
    end
    return maps, targetFind
end

-- Ends the beacon (WowVision's own Shift+F12 does the same and tells us through the hook below).
function ns.stop(maps)
    ns.following = nil
    if maps ~= nil and type(maps.isGuiding) == "function" and maps:isGuiding() and type(maps.cancelNavigation) == "function" then
        maps:cancelNavigation()
    end
end

-- Says where the target is and aims the beacon at it.
local function aim(maps, target)
    Game.speak(Target.text(maps, target))
    local ok, err = pcall(maps.directTo, maps, target.x, target.y, target.n)
    if not ok then
        report(err)
        return
    end
    ns.following = { guid = target.guid, unit = target.unit, x = target.x, y = target.y, n = target.n }
end

-- The key: the beacon toward the target, and where it is; pressed again on the same target (or with no target at
-- all), it ends.
function ns.toggle()
    local maps, targetFind = ready()
    if maps == nil then
        return
    end
    local api = Game.api(maps)
    local following = ns.following
    if following ~= nil and (not api.exists() or Target.same(following, api)) then
        ns.stop(maps)
        Game.speak(L["Guidance stopped."])
        return
    end
    local plan = Target.plan(api, targetFind)
    if plan.say ~= nil then
        Game.speak(plan.say)
        return
    end
    aim(maps, plan.target)
end

-- /wvtarget say: only where the target is, no beacon.
function ns.say()
    local maps, targetFind = ready()
    if maps == nil then
        return
    end
    local plan = Target.plan(Game.api(maps), targetFind)
    if plan.say ~= nil then
        Game.speak(plan.say)
        return
    end
    Game.speak(Target.text(maps, plan.target))
end

function ns.stopKey()
    local maps = Game.maps()
    local was = ns.following ~= nil
    ns.stop(maps)
    if was then
        Game.speak(L["Guidance stopped."])
    end
end

-- ---------------------------------------------------------------- follower

-- Every second: a group member who walked far enough is aimed at again. A creature's spot (WowNav's catalogue) does
-- not move, so nothing to do for it.
function ns.follow()
    local following = ns.following
    if following == nil or following.unit == nil then
        return
    end
    local maps = Game.maps()
    if maps == nil or type(maps.directTo) ~= "function" then
        return
    end
    local x, y = Game.unitPosition(following.unit)
    if x ~= nil and Target.moved(following, x, y) then
        following.x, following.y = x, y
        maps:directTo(x, y, following.n)
    end
end

function ns.startFollower()
    if ns.followerStarted or C_Timer == nil or C_Timer.NewTicker == nil then
        return false
    end
    ns.followerStarted = true
    C_Timer.NewTicker(1, guarded(ns.follow))
    return true
end

-- WowVision's own "cancel navigation" (Shift+F12) also ends the following of the target.
function ns.hookCancel()
    local maps = Game.maps()
    if maps == nil or ns.cancelHooked or type(maps.cancelNavigation) ~= "function" then
        return false
    end
    hooksecurefunc(maps, "cancelNavigation", function()
        ns.following = nil
    end)
    ns.cancelHooked = true
    return true
end

-- --------------------------------------------------------------------- key

ns.bindings = {
    {
        type = "Function",
        key = "targetdirection/toggle",
        label = "Beacon Toward Your Target",
        inputs = { "CTRL-C" },
        interruptSpeech = true,
        func = function()
            ns.toggle()
        end,
    },
}

-- The key is a binding like WowVision's own: listed, and changeable, in the Bindings screen (/wv, Interface,
-- Bindings). WowVision keeps every binding in one registry that the screen reads and stores the player's keys by the
-- binding's key, so a binding added now is picked up like the ones it loaded with. A binding is switched on once the
-- stores have told it the player's keys.
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
            copy.func = guarded(info.func)
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

-- (string.lower leaves an accented capital as it is, so the capitalised forms are there too)
local SAY = { say = true, dire = true, sagen = true }
local STOP = { stop = true, arret = true, ["arrêt"] = true, ["arrÊt"] = true, stopp = true }

function ns.handleCommand(message)
    local word = (message or ""):lower():match("^%s*(%S*)")
    word = word or ""
    if word == "" then
        ns.toggle()
    elseif SAY[word] then
        ns.say()
    elseif STOP[word] then
        ns.stopKey()
    else
        Game.speak(
            L["Target direction: /wvtarget starts a sound beacon toward your target (again on the same target stops it), /wvtarget say only says where it is, /wvtarget stop ends it."]
        )
    end
end

if SlashCmdList ~= nil then
    SLASH_WVTARGETDIRECTION1 = "/wvtarget"
    SLASH_WVTARGETDIRECTION2 = "/wvcible"
    SLASH_WVTARGETDIRECTION3 = "/wvziel"
    SlashCmdList["WVTARGETDIRECTION"] = guarded(ns.handleCommand)
end

-- ------------------------------------------------------------------- start

local function install()
    if WowVision == nil or WowVision.input == nil then
        return false
    end
    local ok, err = pcall(ns.hookCancel)
    if not ok then
        report(err)
    end
    ok, err = pcall(ns.startFollower)
    if not ok then
        report(err)
    end
    local installed
    ok, installed = pcall(ns.installBindings)
    if not ok then
        report(installed)
        return false
    end
    return installed
end

ns.installed = install()

if CreateFrame ~= nil then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function()
        local ok, err = pcall(ns.hookCancel)
        if not ok then
            report(err)
        end
    end)
end
