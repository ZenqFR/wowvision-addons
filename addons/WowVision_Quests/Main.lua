-- Glue: wrap the build of the scanner's Quests category (F9), and the /wvquests command.
--
-- WowVision's scanner builds its tree each time it opens: for every provider it calls provider.build(ctx), looking
-- the function up on the provider at that time, and the In Progress category it gets back lists its quests through
-- a children() function. Wrapping those two reaches the list however the scanner is opened.
local _, ns = ...
local L = ns.L

local reported = {}

-- An error here must never break the scanner, and must not repeat on every opening either: report each distinct
-- message once.
local function report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_Quests: " .. err)
end

-- ---------------------------------------------------------------- settings

local DEFAULTS = { sort = true }

-- Read through the global every time: the client can hand over an account-wide saved variable after the addon's
-- loaded event and replace the table, so a reference cached at load could go stale.
function ns.getSetting(key)
    local db = rawget(_G, "WowVisionQuestsDB")
    if type(db) == "table" and db[key] ~= nil then
        return db[key]
    end
    return DEFAULTS[key]
end

function ns.setSetting(key, value)
    local db = rawget(_G, "WowVisionQuestsDB")
    if type(db) ~= "table" then
        db = {}
        _G.WowVisionQuestsDB = db
    end
    db[key] = value
end

-- ------------------------------------------------------------- the game

local function questsModule()
    return WowVision ~= nil and WowVision.base ~= nil and WowVision.base.quests or nil
end

-- questId -> the level the quest log gives it.
local function logLevels()
    local levels = {}
    local quests = questsModule()
    if quests == nil then
        return levels
    end
    for _, entry in ipairs(quests:inProgress()) do
        levels[entry.questId] = entry.level
    end
    return levels
end

-- Where the player stands, as the quest adapter gives it ({ x, y, ... }); nil when it cannot be told.
local function playerPosition()
    local quests = questsModule()
    local adapter = quests ~= nil and quests.adapter or nil
    if adapter == nil then
        return nil
    end
    local read = adapter.playerContext or adapter._playerContext
    if read == nil then
        return nil
    end
    local ok, player = pcall(read, adapter)
    return ok and player or nil
end

local function refineNodes(nodes)
    local sort = ns.getSetting("sort") ~= false
    return ns.refine(nodes, logLevels(), sort and playerPosition() or nil, sort)
end

local function installCategory(category)
    local children = category.children
    category.children = function(...)
        local nodes = children(...)
        local ok, refined = pcall(refineNodes, nodes)
        if ok then
            return refined
        end
        report(refined)
        return nodes
    end
end

function ns.install()
    local scanner = WowVision ~= nil and WowVision.base ~= nil and WowVision.base.scanner or nil
    local providers = scanner ~= nil and scanner.providers or nil
    local provider = nil
    for _, candidate in ipairs(providers or {}) do
        if candidate.key == "quests" then
            provider = candidate
        end
    end
    if provider == nil or type(provider.build) ~= "function" then
        return false
    end
    if provider.levelsAndProximity then
        return true
    end
    provider.levelsAndProximity = true

    local original = provider.build
    provider.build = function(ctx, ...)
        local categories = original(ctx, ...)
        local ok, err = pcall(function()
            for _, category in ipairs(categories or {}) do
                if category.key == "inProgress" and type(category.children) == "function" then
                    installCategory(category)
                end
            end
        end)
        if not ok then
            report(err)
        end
        return categories
    end
    return true
end

local function install()
    if WowVision == nil or WowVision.base == nil then
        return false
    end
    -- A WowVision that sorts the quests by proximity itself needs none of this.
    local quests = WowVision.quests
    if quests ~= nil and quests.Adapter ~= nil and quests.Adapter.sortByProximity ~= nil then
        return true
    end
    local ok, installed = pcall(ns.install)
    if not ok then
        report(installed)
        return false
    end
    if not installed then
        print("WowVision_Quests: " .. L["WowVision's quest scanner was not found; nothing will be added."])
    end
    return installed
end

ns.installed = install()

-- ----------------------------------------------------------------- command

local function say(text)
    if WowVision ~= nil and WowVision.speak ~= nil then
        local ok = pcall(WowVision.speak, WowVision, text)
        if ok then
            return
        end
    end
    print(text)
end

local ON = { on = true, ["1"] = true, oui = true, yes = true, ja = true, an = true }
local OFF = { off = true, ["0"] = true, non = true, no = true, nein = true, aus = true }

function ns.handleCommand(message)
    local word = (message or ""):lower():match("^%s*(%S*)")
    if ON[word or ""] then
        ns.setSetting("sort", true)
    elseif OFF[word or ""] then
        ns.setSetting("sort", false)
    elseif word ~= nil and word ~= "" then
        say(L["Use /wvquests on or /wvquests off to switch the sorting by proximity."])
        return
    end
    local enabled = ns.getSetting("sort") ~= false
    say(string.format(L["%s: %s"], L["Sort Quests by Proximity"], enabled and L["on"] or L["off"]))
end

if SlashCmdList ~= nil then
    SLASH_WVQUESTS1 = "/wvquests"
    SlashCmdList["WVQUESTS"] = ns.handleCommand
end
