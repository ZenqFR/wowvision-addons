-- The two things this addon does to the scanner's list of quests in progress, without the game: pure Lua.
local _, ns = ...
local L = ns.L

local function distanceBetween(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

-- Nodes nearest first. A node is anything with world coordinates x and y (a scanner node); player is { x, y }.
-- A node with no position (nothing known to walk to, or another continent) goes after every node that has one,
-- and nodes at the same distance, or without a position, keep the order they came in. Without a player
-- position the list is returned as it is. The list given is not changed.
function ns.sortByProximity(nodes, player)
    if player == nil or player.x == nil or player.y == nil then
        return nodes
    end
    local ranked = {}
    for index, node in ipairs(nodes) do
        local distance = nil
        if node.x ~= nil and node.y ~= nil then
            distance = distanceBetween(player.x, player.y, node.x, node.y)
        end
        ranked[index] = { node = node, index = index, distance = distance }
    end
    table.sort(ranked, function(a, b)
        if a.distance ~= nil and b.distance ~= nil and a.distance ~= b.distance then
            return a.distance < b.distance
        end
        if (a.distance == nil) ~= (b.distance == nil) then
            return a.distance ~= nil
        end
        return a.index < b.index
    end)
    local sorted = {}
    for index, entry in ipairs(ranked) do
        sorted[index] = entry.node
    end
    return sorted
end

-- The title of a quest in the log with its level: "A Threat Within, Level 5". The log's level is the quest's own
-- and can be a scaled one, so it is approximate; a quest with no level in the log reads its bare title.
function ns.titleWithLevel(title, level)
    if type(level) == "number" and level > 0 then
        return string.format("%s, %s %d", title, L["Level"], level)
    end
    return title
end

-- The nodes of the In Progress category, each quest's title with its level, then nearest first when asked.
-- levels[questId] is the level the quest log gives; player is the player's position as the quest adapter gives
-- it (or nil). Nodes that are not quests keep their label. The nodes given are changed (their labels), the list
-- is a new one when it is sorted.
function ns.refine(nodes, levels, player, sort)
    for _, node in ipairs(nodes) do
        local questId = type(node.key) == "string" and node.key:match("^quest:(%d+)$") or nil
        if questId ~= nil and type(node.label) == "string" then
            node.label = ns.titleWithLevel(node.label, levels[tonumber(questId)])
        end
    end
    if sort then
        return ns.sortByProximity(nodes, player)
    end
    return nodes
end
