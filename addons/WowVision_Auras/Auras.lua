-- What is said: the numbers of buffs and debuffs, and every one of them. Where the lines come from is Game.lua.
local _, ns = ...
local L = ns.L
local Game = ns.Game

local Auras = {}
ns.Auras = Auras

-- The groups, buffs first (the order of WowVision's own Aura buffer: its sources are the player's buffs, then debuffs,
-- in the names it gives them).
Auras.GROUPS = {
    { key = "buffs", label = "Player Buffs" },
    { key = "debuffs", label = "Player Debuffs" },
}

-- The groups as they are now: { { key, label, auras = { AuraItem... }, message = the item that says why there are
-- none ("Player Buffs, none"), or nil }, ... }. nil when the auras cannot be read at all.
function Auras.read(refresh)
    local groups = {}
    for _, group in ipairs(Auras.GROUPS) do
        local items = Game.items(group.key, refresh)
        if items == nil then
            return nil
        end
        local auras, message = {}, nil
        for _, item in ipairs(items) do
            -- an aura offers its tooltip; the message that stands for "nothing to list" does not
            if item.getTooltipData ~= nil then
                tinsert(auras, item)
            elseif message == nil then
                message = item
            end
        end
        tinsert(groups, { key = group.key, label = L[group.label], auras = auras, message = message })
    end
    return groups
end

-- "Améliorations du joueur : 4. Affaiblissements du joueur : 1."
function Auras.countText(groups)
    local text = ""
    for index, group in ipairs(groups) do
        if index > 1 then
            text = text .. ". "
        end
        text = text .. ns.fill(L["{label}: {count}"], { label = group.label, count = #group.auras })
    end
    return text .. "."
end

-- Every one of them: each group by its name and number, then its auras one after the other, a group with none by what
-- the buffer says about it. Built by joining with "..", never with table.concat or a pattern: under the game's secret
-- values a line can be a secret string, which can be joined and spoken and nothing else.
function Auras.allText(groups)
    local text = ""
    for index, group in ipairs(groups) do
        if index > 1 then
            text = text .. ". "
        end
        if #group.auras == 0 then
            if group.message ~= nil then
                text = text .. Game.line(group.message)
            else
                text = text .. ns.fill(L["{label}: {count}"], { label = group.label, count = 0 })
            end
        else
            text = text .. ns.fill(L["{label}: {count}"], { label = group.label, count = #group.auras })
            for _, item in ipairs(group.auras) do
                text = text .. ". " .. Game.line(item)
            end
        end
    end
    return text
end
