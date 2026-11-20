-- Glue: the calls into the game, Sharpie's Gear Judge and WowVision, the keys (WowVision's Bindings screen lists them)
-- and the /wvjuge command. What the Judge says and how it is said lives in Judge.lua.
local _, ns = ...
local L = ns.L
local Judge = ns.Judge

-- An error here must never break a key, and must not repeat on every press either: each distinct message once.
local reported = {}
local function report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_RollJudge: " .. err)
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

-- Everything this addon asks of the game, of the Judge and of WowVision, in one table, so the tests can replace it.
local Game = {}
ns.Game = Game
Game.report = report

local function usable(value)
    return value ~= nil and not (WowVision ~= nil and WowVision.isSecret ~= nil and WowVision.isSecret(value))
end

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

function Game.locale()
    return GetLocale ~= nil and GetLocale() or "enUS"
end

-- The Judge's public interface; nil when it is not installed or not enabled.
function Game.judge()
    local api = rawget(_G, "SharpiesGearJudgeAPI")
    return type(api) == "table" and api or nil
end

-- The roll windows that are open, in the order WowVision's own roll keys take them (the first visible one first):
-- { { link = the item's link | nil, name = the window's own text | nil } }.
function Game.rolls()
    local out = {}
    for i = 1, 6 do
        local frame = rawget(_G, "GroupLootFrame" .. i)
        if frame ~= nil and frame:IsVisible() then
            local link
            if frame.rollID ~= nil and GetLootRollItemLink ~= nil then
                local ok, result = pcall(GetLootRollItemLink, frame.rollID)
                if ok and usable(result) and type(result) == "string" then
                    link = result
                end
            end
            local name
            if frame.Name ~= nil and frame.Name.GetText ~= nil then
                local ok, text = pcall(frame.Name.GetText, frame.Name)
                if ok and usable(text) then
                    name = text
                end
            end
            out[#out + 1] = { link = link, name = name }
        end
    end
    return out
end

-- The game's name for an item (its link), nil while the game has not loaded it.
function Game.itemName(link)
    local c = rawget(_G, "C_Item")
    local getInfo = c ~= nil and c.GetItemInfo or rawget(_G, "GetItemInfo")
    if getInfo == nil then
        return nil
    end
    local ok, name = pcall(getInfo, link)
    if ok and usable(name) and type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

-- Asks the game to load an item it has not got.
function Game.requestItem(link)
    local c = rawget(_G, "C_Item")
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    if c ~= nil and c.RequestLoadItemDataByID ~= nil and id ~= nil then
        pcall(c.RequestLoadItemDataByID, id)
    end
end

function Game.after(seconds, fn)
    local timer = rawget(_G, "C_Timer")
    if timer ~= nil and timer.After ~= nil then
        timer.After(seconds, fn)
        return true
    end
    return false
end

-- ------------------------------------------------------------------- keys

-- How many times, and how often, the key asks again for an item the game has not loaded yet.
ns.RETRIES = 4
ns.RETRY_DELAY = 0.5

-- Each press is a new request: it cancels the retries of the one before.
local latest = 0

local function ask(roll, attempt, token)
    local text, retry = Judge.line(Game, roll)
    if retry and attempt < ns.RETRIES then
        if attempt == 0 then
            Game.speak(L["The item is loading."])
            Game.requestItem(roll.link)
        end
        if Game.after(ns.RETRY_DELAY, guarded(function()
            if token == latest then
                ask(roll, attempt + 1, token)
            end
        end)) then
            return
        end
    end
    Game.speak(text)
end

-- The first roll window's item: what the Judge thinks of it.
function ns.sayVerdict()
    latest = latest + 1
    local rolls = Game.rolls()
    if #rolls == 0 then
        Game.speak(L["No loot."])
        return
    end
    ask(rolls[1], 0, latest)
end

-- Every roll window's item, one after the other.
function ns.sayAll()
    latest = latest + 1
    local rolls = Game.rolls()
    if #rolls == 0 then
        Game.speak(L["No loot."])
        return
    end
    local lines = {}
    for position, roll in ipairs(rolls) do
        local text, retry = Judge.line(Game, roll)
        if retry then
            Game.requestItem(roll.link)
        end
        lines[#lines + 1] = string.format(L["Item %d of %d"], position, #rolls) .. ", " .. text
    end
    Game.speak(table.concat(lines, ". "))
end

-- Alt+Ctrl+J (J for judge) is in the family of WowVision's own roll keys (Alt+Ctrl+Y reads the tooltip, U needs, I
-- greeds, O passes). The player asked for Alt+T, but WowVision's "Open Target Menu" has it (and Alt+Ctrl+T is its
-- "Accept Trade"), and its input manager refuses two bindings on one key: the player can move the target menu in the
-- Bindings screen and give Alt+T to this key. tests/real_core.lua checks that the default is free and that this works.
ns.bindings = {
    {
        type = "Function",
        key = "rolljudge/verdict",
        label = "Gear Judge's verdict on the item up for a roll",
        inputs = { "ALT-CTRL-J" },
        interruptSpeech = true,
        func = function()
            ns.sayVerdict()
        end,
    },
    {
        type = "Function",
        key = "rolljudge/all",
        label = "Gear Judge's verdict on every item up for a roll",
        inputs = {},
        interruptSpeech = true,
        func = function()
            ns.sayAll()
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
            copy.func = guarded(info.func)
            table.insert(created, input:createBinding(copy))
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

local HELP = { help = true, aide = true, hilfe = true }
local ALL = { all = true, tout = true, tous = true, alle = true }

function ns.handleCommand(message)
    local word = (message or ""):lower():match("^%s*(%S*)") or ""
    if HELP[word] then
        Game.speak(
            L["Roll judge: the key says what Sharpie's Gear Judge thinks of the item up for a roll, whether it improves what you wear and by how many percent. /wvjuge says it too, /wvjuge all says it for every item up for a roll."]
        )
    elseif ALL[word] then
        ns.sayAll()
    else
        ns.sayVerdict()
    end
end

if SlashCmdList ~= nil then
    SLASH_WVROLLJUDGE1 = "/wvjuge"
    SLASH_WVROLLJUDGE2 = "/wvjudge"
    SLASH_WVROLLJUDGE3 = "/wvurteil"
    SlashCmdList["WVROLLJUDGE"] = guarded(ns.handleCommand)
end

-- ------------------------------------------------------------------- start

local function install()
    if WowVision == nil or WowVision.input == nil then
        return false
    end
    local ok, installed = pcall(ns.installBindings)
    if not ok then
        report(installed)
        return false
    end
    return installed
end

ns.installed = install()
