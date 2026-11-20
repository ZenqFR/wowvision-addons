-- What each line of LFG Forever's lists says. A line is said as soon as the focus lands on it, before the game has drawn
-- its row, so it is built from the data (the search results the game holds, the whisper the log holds), never from the
-- drawn row. Every value is read through Game.readable: in a dungeon, a raid or a fight the game keeps most of a
-- listing secret, and what cannot be read is left out of the line (never guessed).
local _, ns = ...
local L = ns.L
local Game = ns.Game

local Labels = {}
ns.Labels = Labels

local readable = Game.readable

-- A word or sentence of the game's if it has one, else the addon's own.
local function word(gameWord, key)
    if type(gameWord) == "string" and gameWord ~= "" then
        return gameWord
    end
    return L[key]
end

local function add(parts, text)
    if type(text) == "string" and text ~= "" then
        parts[#parts + 1] = text
    end
end

local function oneLine(text)
    return (text:gsub("%s+", " "):match("^%s*(.-)%s*$"))
end

local function readableText(value)
    local text = readable(value)
    if type(text) ~= "string" then
        return nil
    end
    text = oneLine(text)
    if text == "" then
        return nil
    end
    return text
end

local ROLES = {
    { key = "TANK", fallback = "Tank", solo = "tank" },
    { key = "HEALER", fallback = "Healer", solo = "healer" },
    { key = "DAMAGER", fallback = "Damage", solo = "dps" },
}

local function roleWord(role)
    return word(Game.roleName(role.key), role.fallback)
end

-- What a group has, "1 Tank, 1 Healer, 3 Damage"; nil when the tally cannot be read or is empty.
function Labels.groupRoles(counts)
    counts = readable(counts)
    if type(counts) ~= "table" then
        return nil
    end
    local parts = {}
    for _, role in ipairs(ROLES) do
        local count = readable(counts[role.key])
        if type(count) == "number" and count > 0 then
            add(parts, ns.fill(L["{count} {role}"], { count = count, role = roleWord(role) }))
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

-- The roles a player signed up for, "Tank, Healer"; nil when none can be read.
function Labels.playerRoles(lfgRoles)
    lfgRoles = readable(lfgRoles)
    if type(lfgRoles) ~= "table" then
        return nil
    end
    local parts = {}
    for _, role in ipairs(ROLES) do
        if readable(lfgRoles[role.solo]) == true then
            add(parts, roleWord(role))
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

-- "level 60 Mage", "level 60" or nothing.
local function levelAndClass(level, classFilename)
    level = readable(level)
    if type(level) ~= "number" then
        return nil
    end
    local class = Game.className(readable(classFilename))
    if class ~= nil then
        return ns.fill(L["level {level} {class}"], { level = level, class = class })
    end
    return ns.fill(L["level {level}"], { level = level })
end

-- The activities a listing is for: one name, up to three names, else how many.
function Labels.activities(activityIDs)
    activityIDs = readable(activityIDs)
    if type(activityIDs) ~= "table" or #activityIDs == 0 then
        return nil
    end
    if #activityIDs > 3 then
        return ns.fill(L["{count} activities"], { count = #activityIDs })
    end
    local names = {}
    for _, activityID in ipairs(activityIDs) do
        add(names, Game.activityName(activityID))
    end
    if #names == 0 then
        return ns.fill(L["{count} activities"], { count = #activityIDs })
    end
    return table.concat(names, " / ")
end

-- One listing of the search results: a group or a player looking for a group.
--
-- A group: its leader, what it is for, how many members and what they are, its play style, its note. A player: the
-- name, level and class, the roles, what for, the zone, the play style, the note. Then, for either, what the game says
-- of the listing itself: yours, removed, welcoming new players.
function Labels.listing(resultID)
    local info = Game.resultInfo(resultID)
    if type(info) ~= "table" then
        return L["Group"]
    end
    local numMembers = readable(info.numMembers)
    local isSolo = type(numMembers) == "number" and numMembers <= 1
    local parts = {}
    local readAny = false

    local name = readableText(info.leaderName)
    add(parts, name)
    readAny = readAny or name ~= nil

    if isSolo then
        local member = Game.memberInfo(resultID, 1)
        if type(member) == "table" then
            add(parts, levelAndClass(member.level, member.classFilename))
            local roles = Labels.playerRoles(member.lfgRoles)
            if roles ~= nil then
                add(parts, ns.fill(L["roles: {roles}"], { roles = roles }))
            end
        end
        local activities = Labels.activities(info.activityIDs)
        add(parts, activities)
        readAny = readAny or activities ~= nil
        local zone = type(member) == "table" and readableText(member.areaName) or nil
        if zone ~= nil then
            add(parts, ns.fill(L["in {zone}"], { zone = zone }))
        end
    else
        local activities = Labels.activities(info.activityIDs)
        add(parts, activities)
        readAny = readAny or activities ~= nil
        if type(numMembers) == "number" then
            readAny = true
            local roles = Labels.groupRoles(Game.memberCounts(resultID))
            if roles ~= nil then
                add(parts, ns.fill(L["{count} members ({roles})"], { count = numMembers, roles = roles }))
            else
                add(parts, ns.fill(L["{count} members"], { count = numMembers }))
            end
        end
    end

    local playstyle = readable(info.generalPlaystyle)
    add(parts, playstyle ~= nil and Game.playstyleName(playstyle) or nil)
    local comment = readableText(info.comment)
    add(parts, comment)

    if readable(info.hasSelf) == true then
        add(parts, L["your own listing"])
    end
    if readable(info.isDelisted) == true then
        add(parts, L["listing removed"])
    end
    if readable(info.newPlayerFriendly) == true then
        add(parts, L["welcomes new players"])
    end

    -- nothing that says who or what: the game keeps it secret (a dungeon, a raid, a fight)
    if not readAny then
        table.insert(parts, 1, L["Group"])
        add(parts, L["details unavailable"])
    end
    return table.concat(parts, ", ")
end

-- A header of the results ("Groups", "Players"), with how many listings it holds when that is known.
function Labels.divider(dividerType, count)
    local label = word(Game.dividerName(dividerType), dividerType == "solo" and "Players" or "Groups")
    if type(count) == "number" then
        return ns.fill(L["{label}, {count}"], { label = label, count = count })
    end
    return label
end

-- One whisper of the whisper log: who, their level and class, what they wrote.
function Labels.whisper(entry)
    if type(entry) ~= "table" then
        return nil
    end
    local parts = {}
    add(parts, readableText(entry.name))
    add(parts, levelAndClass(entry.level, entry.classFilename))
    local who = table.concat(parts, ", ")
    local text = readableText(entry.text)
    if text == nil then
        text = L["message unavailable"]
    end
    if who == "" then
        return text
    end
    return who .. ": " .. text
end

-- One recent ally of the Player ratings tab: who, their level and class, what you did together.
function Labels.ally(entry)
    if type(entry) ~= "table" then
        return nil
    end
    local parts = {}
    add(parts, readableText(entry.name))
    add(parts, levelAndClass(entry.level, entry.classFilename))
    add(parts, readableText(entry.text))
    if #parts == 0 then
        return L["Player"]
    end
    return table.concat(parts, ", ")
end

-- What the stars of an ally say: "rated 2 of 3 stars" or "not rated".
function Labels.rating(rating)
    if type(rating) == "number" and rating >= 1 then
        return ns.fill(L["rated {count} of 3 stars"], { count = rating })
    end
    return L["not rated"]
end
