-- Everything this addon asks of the game, of LFG Forever and of WowVision, in one table, so the tests can replace it.
--
-- LFG Forever keeps all its code in a private table, so nothing of it can be called from outside. What is reachable is
-- what it leaves in the game's global space: its window (LFGForeverFrame) and, on that frame, the panels it built
-- (frame.Content.FilterPanel and frame.Content.ListPanel, and the controls and lists they hold), and the global
-- function it gives its key binding (LFGForever_ToggleWindow). This addon reads those and clicks the real controls,
-- the way WowVision does with the game's own windows.
local _, ns = ...

local Game = {}
ns.Game = Game

-- The name of the WowVision window this addon registers, and the name of LFG Forever's frame it follows.
Game.WINDOW = "lfgForever"
Game.FRAME = "LFGForeverFrame"

-- An error here must never break a key or a screen, and must not repeat on every tick either: each distinct message
-- once.
local reported = {}
function Game.report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_LFGForever: " .. err)
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

-- ----------------------------------------------------------------- reading

-- A value the game keeps secret (in a dungeon, a raid, a fight, or while chat messaging is locked down) cannot be
-- compared, joined or used as a key: it is read as nothing.
function Game.readable(value)
    if value == nil then
        return nil
    end
    local isSecret = rawget(_G, "issecretvalue")
    if isSecret ~= nil and isSecret(value) then
        return nil
    end
    local canAccess = rawget(_G, "canaccessvalue")
    if canAccess ~= nil and not canAccess(value) then
        return nil
    end
    return value
end

local function call(fn, ...)
    if fn == nil then
        return nil
    end
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function lfgList()
    return rawget(_G, "C_LFGList")
end

-- One listing of the search results: leaderName, numMembers, activityIDs, comment, age, isDelisted, hasSelf,
-- newPlayerFriendly, generalPlaystyle... (any of them can be secret).
function Game.resultInfo(resultID)
    local api = lfgList()
    return api ~= nil and call(api.GetSearchResultInfo, resultID) or nil
end

-- A member of a listing: classFilename, level, areaName, lfgRoles ({ tank, healer, dps }).
function Game.memberInfo(resultID, index)
    local api = lfgList()
    return api ~= nil and call(api.GetSearchResultPlayerInfo, resultID, index) or nil
end

-- What a group has: { TANK = n, HEALER = n, DAMAGER = n }.
function Game.memberCounts(resultID)
    local api = lfgList()
    return api ~= nil and call(api.GetSearchResultMemberCounts, resultID) or nil
end

-- The name the game gives an activity, in the game's language.
function Game.activityName(activityID)
    local api = lfgList()
    local info = api ~= nil and call(api.GetActivityInfoTable, activityID) or nil
    if type(info) ~= "table" then
        return nil
    end
    local named = rawget(_G, "LFGUtil_GetActivityInfoName")
    local name = named ~= nil and call(named, info) or nil
    return Game.readable(name or info.fullName or info.shortName)
end

function Game.playstyleName(playstyle)
    local word = rawget(_G, "GetGeneralPlaystyleString")
    if word == nil or playstyle == nil then
        return nil
    end
    local text = call(word, playstyle)
    if text == nil or text == "" then
        return nil
    end
    return text
end

function Game.className(classFilename)
    if type(classFilename) ~= "string" then
        return nil
    end
    local names = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
    return names ~= nil and names[classFilename] or classFilename
end

-- The game's own words for the three roles (Tank, Healer, Damage), else the addon's.
local ROLE_GLOBALS = { TANK = "TANK", HEALER = "HEALER", DAMAGER = "DAMAGER" }
function Game.roleName(role)
    local name = rawget(_G, ROLE_GLOBALS[role] or "")
    if type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

-- The headers of the two parts of the results, in the game's words.
function Game.dividerName(dividerType)
    if dividerType == "solo" then
        return rawget(_G, "LFG_LIST_CATEGORY_SOLO_PLAYERS")
    end
    return rawget(_G, "LFG_LIST_CATEGORY_GROUPS")
end

-- ------------------------------------------------------------- LFG Forever

function Game.isLoaded()
    return rawget(_G, "LFGForever_ToggleWindow") ~= nil
end

-- LFG Forever's window, and the two panels it is made of. Any of them is nil until the window has been opened once
-- (LFG Forever builds it on the first /lfg).
function Game.frame()
    return rawget(_G, Game.FRAME)
end

function Game.panels()
    local frame = Game.frame()
    local content = frame ~= nil and frame.Content or nil
    if content == nil then
        return frame, nil, nil
    end
    return frame, content.FilterPanel, content.ListPanel
end

function Game.shown(frame)
    return frame ~= nil and frame.IsShown ~= nil and frame:IsShown() == true
end

-- Opens or closes LFG Forever's window the way its own key does: through the function it gives that key (a plain frame,
-- so this works in combat too).
function Game.toggle()
    local toggle = rawget(_G, "LFGForever_ToggleWindow")
    if toggle == nil then
        return false
    end
    toggle()
    return true
end

-- Closes the window (Escape from WowVision's screen). A plain Hide is never refused, in combat or not.
function Game.hide()
    local frame = Game.frame()
    if frame ~= nil then
        frame:Hide()
    end
end

-- ------------------------------------------------------------ the window

local function windowManager()
    local wowVision = rawget(_G, "WowVision")
    if wowVision == nil or wowVision.WindowManager == nil or wowVision.UIHost == nil then
        return nil, nil
    end
    return wowVision.WindowManager, wowVision.UIHost.windowManager
end

-- Registers the WowVision window that follows LFG Forever's frame: it opens when the frame is shown and closes when it
-- is hidden, like the windows WowVision registers for the game's own frames. Sku, which has its own windows, is left
-- alone as everywhere in WowVision. screen is the graphScreen config (render, onRequestClose...).
function Game.registerWindow(screen)
    local windows, manager = windowManager()
    if windows == nil or manager == nil then
        return false
    end
    if manager.getWindow ~= nil and manager:getWindow(Game.WINDOW) ~= nil then
        return true
    end
    local window = windows:CreateWindow("FrameWindow", {
        name = Game.WINDOW,
        frameName = Game.FRAME,
        conflictingAddons = { "Sku" },
        graphScreen = screen,
    })
    manager:RegisterWindow(window)
    return true
end
