-- What Sharpie's Gear Judge says of an item, as one spoken sentence. Pure: the game and the Judge come in as `game`
-- (ns.Game, replaced by the tests). The Judge's public interface is documented in its SGJ_API_Info.md:
-- SharpiesGearJudgeAPI.ScoreItem(link) gives a table (upgradePct, equippedLink, equipped...) or nil and a reason.
local _, ns = ...
local L = ns.L

local Judge = {}
ns.Judge = Judge

-- Languages that write 1,5 rather than 1.5: the speech engine reads the comma as a decimal mark and the point as the
-- word "point".
local DECIMAL_COMMA = { frFR = true, deDE = true, esES = true, itIT = true, ptBR = true, ruRU = true }

-- A percentage as it is spoken: one decimal at most, no ".0", never a minus sign (the sentence says which way).
function Judge.number(value, locale)
    local text = string.format("%.1f", math.abs(value))
    text = text:gsub("%.0$", "")
    if DECIMAL_COMMA[locale] then
        text = text:gsub("%.", ",")
    end
    return text
end

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- The name of an item: the game's, else the one in the link.
local function nameOf(link, game)
    local name = game.itemName(link)
    if name == nil and type(link) == "string" then
        name = link:match("%[(.-)%]")
    end
    return name
end

-- The words for a reason the Judge could not score (its own, plus MISSING and OLD from here).
function Judge.reasonText(reason)
    if reason == "NOT_USABLE" then
        return L["your class cannot use it"]
    elseif reason == "NOT_EQUIPPABLE" then
        return L["it is not equipment"]
    elseif reason == "NOT_READY" then
        return L["Gear Judge is not ready yet"]
    elseif reason == "NOT_CACHED" then
        return L["the item is not loaded yet"]
    elseif reason == "BAD_LINK" then
        return L["Gear Judge cannot read that item"]
    elseif reason == "MISSING" then
        return L["Gear Judge is not installed or not enabled."]
    elseif reason == "OLD" then
        return L["Gear Judge is too old: version 3.2.7 or later is needed."]
    end
    return L["Gear Judge reported an error"]
end

-- Asks the Judge about an item link: result | nil, reason.
function Judge.score(game, link)
    local api = game.judge()
    if api == nil then
        return nil, "MISSING"
    end
    if type(api.ScoreItem) ~= "function" then
        return nil, "OLD"
    end
    if type(api.IsReady) == "function" then
        local ok, ready = pcall(api.IsReady)
        if ok and ready == false then
            return nil, "NOT_READY"
        end
    end
    local ok, result, reason = pcall(api.ScoreItem, link)
    if not ok then
        game.report(result)
        return nil, "ERROR"
    end
    if type(result) ~= "table" then
        return nil, reason or "ERROR"
    end
    return result
end

-- What the Judge's answer means for the player, as a sentence without the item's name.
function Judge.verdict(game, result, reason)
    if result == nil then
        return Judge.reasonText(reason)
    end
    if result.equipped == true then
        return L["you already wear it"]
    end
    local amount = result.upgradePct
    local text
    if finite(amount) then
        local rounded = tonumber(string.format("%.1f", amount))
        if rounded == 0 then
            text = L["no change"]
        elseif amount > 0 then
            text = string.format(L["upgrade of %s percent"], Judge.number(amount, game.locale()))
        else
            text = string.format(L["downgrade of %s percent"], Judge.number(amount, game.locale()))
        end
    elseif finite(result.upgrade) then
        -- the Judge gives no percentage when the character's own score is 0 (nothing worn yet): the points still say
        -- which way it goes
        if result.upgrade > 0 then
            text = L["an upgrade"]
        elseif result.upgrade < 0 then
            text = L["a downgrade"]
        else
            text = L["no change"]
        end
    else
        return L["Gear Judge gave no figure"]
    end
    local replaced = result.equippedLink
    if replaced == nil or replaced == "" then
        text = text .. ", " .. L["empty slot"]
    else
        local name = nameOf(replaced, game)
        if name ~= nil and name ~= "" then
            text = text .. ", " .. string.format(L["instead of %s"], name)
        end
    end
    return text
end

-- The sentence for one roll window ({ link, name }): the item's name, then the verdict. The second value is true when
-- the game has not loaded the item yet (the caller may ask again in a moment).
function Judge.line(game, roll)
    local name = roll.link ~= nil and nameOf(roll.link, game) or roll.name
    local verdict, retry
    if roll.link == nil then
        verdict = Judge.reasonText("BAD_LINK")
    else
        local result, reason = Judge.score(game, roll.link)
        verdict = Judge.verdict(game, result, reason)
        retry = result == nil and reason == "NOT_CACHED"
    end
    if name ~= nil and name ~= "" then
        return name .. ", " .. verdict, retry
    end
    return verdict, retry
end
