-- Which of the creatures around the player their quests still need, nearest first, and which one a key should
-- target next. Pure Lua without game functions, so the offline tests run it: the game's side is handed in as api.
--
-- api:
--   units()            the unit tokens to look at, in the order they win a tie ("target", "mouseover", the
--                      nameplates...)
--   exists(unit), isUnit(a, b), isPlayer(unit), canAttack(unit), isDead(unit), name(unit)
--   related(unit)      whether the game says the unit belongs to an active quest (C_QuestLog.UnitIsRelatedToActiveQuest);
--                      absent when the client has no such call
--   lines(unit)        the unit tooltip's lines as { type, text, completed }; absent when the client has no such call
--   range(unit)        minimum and maximum distance in yards, or nothing
--   isSecret(value)    the restricted clients hide some values of enemies in combat; such a value is "unknown"
local _, ns = ...
local L = ns.L

local Targets = {}
ns.Targets = Targets

-- Tooltip line type of a quest objective ("Kobold Vermin slain: 3/10"), Enum.TooltipDataLineType.QuestObjective.
local LINE_QUEST_OBJECTIVE = 8

-- A yes/no answer of the game as true, false, or nil when it is missing or secret (not known).
local function readBool(api, value)
    if value == nil or api.isSecret(value) then
        return nil
    end
    return value == true
end

local function readText(api, value)
    if type(value) ~= "string" or value == "" or api.isSecret(value) then
        return nil
    end
    return value
end

-- The unfinished objective lines of a unit's tooltip, and how many objective lines it has in all.
local function objectives(api, unit)
    local unfinished, total = {}, 0
    if api.lines == nil then
        return unfinished, total
    end
    local lines = api.lines(unit)
    for _, line in ipairs(lines or {}) do
        if line.type == LINE_QUEST_OBJECTIVE then
            total = total + 1
            local done = readBool(api, line.completed)
            local text = readText(api, line.text)
            if done ~= true and text ~= nil then
                tinsert(unfinished, text)
            end
        end
    end
    return unfinished, total
end

-- The minimum and maximum distance in yards of a unit, each nil when not known.
local function rangeOf(api, unit)
    local minRange, maxRange
    if api.range ~= nil then
        local ok, low, high = pcall(api.range, unit)
        if ok then
            if type(low) == "number" and not api.isSecret(low) then
                minRange = low
            end
            if type(high) == "number" and not api.isSecret(high) then
                maxRange = high
            end
        end
    end
    return minRange, maxRange
end

-- Judges one unit. Returns a verdict { unit, name, reason, ... } and whether a secret value stopped the answer.
-- reason is nil for a unit the quests still need, and otherwise says why not:
--   "player"      another player
--   "friendly"    something the player cannot attack
--   "dead"        a corpse
--   "hidden"      the game hid a value, so the unit could not be judged
--   "notQuest"    not related to any of the player's quests (related == false when the game said so)
--   "finished"    related to a quest, but every objective line is complete
-- A unit that is kept also has its unfinished objectives and its distance.
local function examine(api, unit)
    local verdict = { unit = unit, name = readText(api, api.name(unit)) }

    local isPlayer = readBool(api, api.isPlayer(unit))
    if isPlayer ~= false then
        verdict.reason = isPlayer and "player" or "hidden"
        return verdict, false
    end
    -- Quest creatures that have to be killed: something the player can attack and that is still alive.
    -- (A dead one may still list the quest, for the loot it holds.)
    local canAttack = readBool(api, api.canAttack(unit))
    if canAttack ~= true then
        verdict.reason = canAttack == false and "friendly" or "hidden"
        return verdict, false
    end
    local dead = readBool(api, api.isDead(unit))
    if dead == true then
        verdict.reason = "dead"
        return verdict, false
    end
    if dead == nil or verdict.name == nil then
        verdict.reason = "hidden"
        return verdict, true
    end

    local unfinished, total = objectives(api, unit)
    verdict.objectives = unfinished
    verdict.objectiveLines = total
    if api.related ~= nil then
        local related = readBool(api, api.related(unit))
        verdict.related = related
        if related == nil then
            verdict.reason = "hidden"
            return verdict, true
        end
        -- Related to a quest, and not only through objectives that are finished.
        if not related then
            verdict.reason = "notQuest"
            return verdict, false
        end
        if total > 0 and #unfinished == 0 then
            verdict.reason = "finished"
            return verdict, false
        end
    elseif #unfinished == 0 then
        verdict.reason = total > 0 and "finished" or "notQuest"
        return verdict, false
    end

    verdict.minRange, verdict.maxRange = rangeOf(api, unit)
    return verdict, false
end

-- Every unit that exists, judged once (a creature seen under two tokens counts for the first one that sees it), in
-- the order the units were given. Returns the verdicts and how many units a secret value kept from being judged.
local function scan(api)
    local all, secretSkipped, seen = {}, 0, {}
    for _, unit in ipairs(api.units()) do
        if api.exists(unit) then
            local duplicate = false
            for _, other in ipairs(seen) do
                if readBool(api, api.isUnit(unit, other)) == true then
                    duplicate = true
                    break
                end
            end
            if not duplicate then
                tinsert(seen, unit)
                local verdict, secret = examine(api, unit)
                verdict.order = #all + 1
                if secret then
                    secretSkipped = secretSkipped + 1
                end
                tinsert(all, verdict)
            end
        end
    end
    return all, secretSkipped
end

-- Nearest first; a distance that is not known goes last, in the order the units were given.
local function nearerFirst(a, b)
    local aDistance = a.maxRange or a.minRange
    local bDistance = b.maxRange or b.minRange
    if aDistance ~= nil and bDistance ~= nil and aDistance ~= bDistance then
        return aDistance < bDistance
    end
    if (aDistance == nil) ~= (bDistance == nil) then
        return aDistance ~= nil
    end
    return a.order < b.order
end

-- The creatures around that the quests still need, nearest first. Returns the list and how many units a secret
-- value kept from being judged.
function Targets.collect(api)
    local all, secretSkipped = scan(api)
    local found = {}
    for _, verdict in ipairs(all) do
        if verdict.reason == nil then
            tinsert(found, verdict)
        end
    end
    table.sort(found, nearerFirst)
    return found, secretSkipped
end

-- Every creature around, kept or not, nearest first, each with the reason it was left out (reason == nil for the
-- ones a key would target). This is what /wvqt why reads out.
function Targets.review(api)
    local all, secretSkipped = scan(api)
    for _, verdict in ipairs(all) do
        if verdict.reason ~= nil then
            verdict.minRange, verdict.maxRange = rangeOf(api, verdict.unit)
        end
    end
    table.sort(all, nearerFirst)
    return all, secretSkipped
end

-- Which candidate a key targets: going forward, the one after the creature already targeted (the nearest one when
-- the target is none of them, or the last of them: round the list); going back, the one before it (the farthest
-- when the target is none of them). isCurrent(unit) says whether a candidate is the player's target now.
-- Returns the index and the number of candidates, or nil when there are none.
function Targets.choose(candidates, direction, isCurrent)
    local count = #candidates
    if count == 0 then
        return nil
    end
    local current
    for index, candidate in ipairs(candidates) do
        if isCurrent(candidate.unit) then
            current = index
            break
        end
    end
    if direction < 0 then
        if current == nil then
            return count, count
        end
        return ((current - 2) % count) + 1, count
    end
    if current == nil then
        return 1, count
    end
    return (current % count) + 1, count
end

-- "within 10 yards" for a creature that is at most 10 yards away, "beyond 40 yards" when only a minimum is known.
function Targets.distanceText(candidate)
    if candidate.maxRange ~= nil then
        return string.format(L["within %d yards"], math.ceil(candidate.maxRange))
    end
    if candidate.minRange ~= nil then
        return string.format(L["beyond %d yards"], math.floor(candidate.minRange))
    end
    return nil
end

-- What is said of one candidate: its name, how far it is, and the objectives it is still needed for.
function Targets.describe(candidate)
    local parts = { candidate.name }
    local distance = Targets.distanceText(candidate)
    if distance ~= nil then
        tinsert(parts, distance)
    end
    for index, text in ipairs(candidate.objectives) do
        if index > 2 then
            break
        end
        tinsert(parts, text)
    end
    return table.concat(parts, ", ")
end

-- "3 quest targets: Kobold Vermin, within 8 yards, Kobold Vermin slain: 3/8; ...". At most five are read.
function Targets.listText(candidates)
    local count = #candidates
    if count == 0 then
        return L["No quest target nearby."]
    end
    local items = {}
    for index = 1, math.min(count, 5) do
        tinsert(items, Targets.describe(candidates[index]))
    end
    local text = table.concat(items, "; ")
    if count == 1 then
        return string.format(L["1 quest target: %s."], text)
    end
    return string.format(L["%d quest targets: %s."], count, text)
end

-- Why one creature was kept or left out, in a few words.
local function reasonText(verdict)
    local reason = verdict.reason
    if reason == nil then
        return L["proposed"]
    elseif reason == "player" then
        return L["a player"]
    elseif reason == "friendly" then
        return L["cannot be attacked"]
    elseif reason == "dead" then
        return L["dead"]
    elseif reason == "hidden" then
        return L["values hidden by the game"]
    elseif reason == "finished" then
        return L["objectives already complete"]
    elseif verdict.related == false then
        return L["not for any of your quests"]
    end
    return L["no unfinished objective in its tooltip"]
end

-- How many creatures /wvqt why reads out one by one.
local MAX_REVIEWED = 6

-- What /wvqt why says: how many creatures are around, what in the game stops the addon from seeing them (context:
-- platesShown, combat, hasRelated, hasLines), then the nearest ones with the reason each was kept or left out.
function Targets.diagnosisText(verdicts, context)
    local proposed = 0
    for _, verdict in ipairs(verdicts) do
        if verdict.reason == nil then
            proposed = proposed + 1
        end
    end
    local parts = { string.format(L["Creatures seen: %d. Proposed: %d."], #verdicts, proposed) }
    if context.platesShown == false then
        tinsert(parts, L["Enemy nameplates are off: type /wvqt plates."])
    end
    if context.combat then
        tinsert(parts, L["You are in combat."])
    end
    if context.hasRelated == false and context.hasLines == false then
        tinsert(parts, L["This game version cannot tell which creatures belong to your quests."])
    elseif context.hasRelated == false then
        tinsert(parts, L["Missing game call: quest link."])
    elseif context.hasLines == false then
        tinsert(parts, L["Missing game call: tooltip objectives."])
    end
    if #verdicts == 0 then
        tinsert(parts, L["Only your target, the creature under the mouse and the enemy nameplates in range can be seen."])
    end
    for index, verdict in ipairs(verdicts) do
        if index > MAX_REVIEWED then
            tinsert(parts, string.format(L["And %d more."], #verdicts - MAX_REVIEWED))
            break
        end
        local head = verdict.name or L["a creature with a hidden name"]
        local distance = Targets.distanceText(verdict)
        if distance ~= nil then
            head = head .. ", " .. distance
        end
        tinsert(parts, string.format(L["%s: %s"], head, reasonText(verdict)) .. ".")
    end
    return table.concat(parts, " ")
end
