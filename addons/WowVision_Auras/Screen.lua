-- The WowVision screen: two tab stops, the player's buffs and the player's debuffs, each a list with one line per aura
-- (name, stacks, time left, dispel type: what WowVision's Aura buffer says). Space reads the aura's whole tooltip, its
-- description included, line by line with the shift-arrow keys, as everywhere in WowVision. Escape closes it.
--
-- The screen is drawn again every tick, so the lines are the buffers' own and always current: the buffers rebuild
-- themselves when the game says the unit's auras changed.
local _, ns = ...
local L = ns.L
local Game = ns.Game
local Auras = ns.Auras

local Screen = {}
ns.Screen = Screen

local function graph()
    return WowVision.graph
end

local function id(key)
    return graph().ControlId.structural(key)
end

-- One aura: its line is read when the focus lands on it (the time left changes every second, so it is not watched:
-- it would be said again each time it ticked), and Space reads its tooltip.
local function auraNode(nodes, item)
    local vtable = nodes.text({
        label = function()
            return Game.line(item)
        end,
        live = false,
    })
    vtable.tooltip = item:getTooltipData()
    return vtable
end

function Screen.render(builder)
    local nodes = graph().nodes
    local groups = Auras.read(false)
    if groups == nil then
        builder:beginStop("auras:none")
        builder:addItem(id("auras:none"), nodes.text({ label = L["Auras are not available."] }))
        return
    end
    for _, group in ipairs(groups) do
        builder:beginStop("auras:" .. group.key)
        builder:pushContext("auras:" .. group.key, group.label)
        if #group.auras == 0 then
            -- nothing to list: the buffer says it ("Player Buffs, none")
            local message = group.message
            builder:addItem(
                id("auras:" .. group.key .. ":none"),
                nodes.text({
                    label = function()
                        if message ~= nil then
                            return Game.line(message)
                        end
                        return ns.fill(L["{label}: {count}"], { label = group.label, count = 0 })
                    end,
                })
            )
        else
            for index, item in ipairs(group.auras) do
                builder:addItem(id("auras:" .. group.key .. ":" .. index), auraNode(nodes, item))
            end
        end
        builder:popContext()
    end
end

function Screen.config()
    return {
        key = Game.WINDOW,
        -- a frameless window: the game cannot close it for us, so Escape is held by the screen (WowVision's host
        -- only takes the close key for such a stack when it asks)
        captureClose = true,
        render = function(builder)
            return Screen.render(builder)
        end,
        onRequestClose = Game.guarded(function()
            Game.close()
        end),
    }
end

-- Opens the screen, or closes it when it is open (the key and the command both toggle).
function Screen.toggle()
    if Game.isOpen() then
        Game.close()
        return true
    end
    -- the game is asked afresh once, as the screen opens; after that the buffers keep it up to date
    Auras.read(true)
    if not Game.open(Screen.config()) then
        Game.speak(L["WowVision's windows are not available."])
        return false
    end
    return true
end
