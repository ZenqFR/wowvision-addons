-- Loads WowVision's REAL graph framework (Builder, KeyGraph, node factories) with just enough around it, so the
-- screens of this addon are built and walked by the real code. Usage: local env = dofile("graph_env.lua")(dir)
-- where dir is the WowVision folder. Returns { graph, host, spoken, press... } helpers.
return function(wvDir)
    local ns = {}
    local function load(path, ...)
        local chunk, err = loadfile(wvDir .. "/" .. path)
        if chunk == nil then
            error(err)
        end
        return chunk(...)
    end

    tinsert = table.insert
    tremove = table.remove
    wipe = wipe or function(t)
        for k in pairs(t) do
            t[k] = nil
        end
    end
    strtrim = strtrim or function(s)
        return (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    format = string.format
    GetTime = GetTime or function()
        return 0
    end
    debugstack = debugstack or function()
        return ""
    end
    geterrorhandler = geterrorhandler or function()
        return function(err)
            error(err, 0)
        end
    end

    load("core/Class.lua", nil, ns)
    local identity = setmetatable({}, {
        __index = function(_, key)
            return key
        end,
    })
    local env = { spoken = {}, pushed = {}, popped = 0, entries = {} }
    WowVision = {
        Class = ns.Class,
        classes = ns.classes,
        getLocale = function()
            return identity
        end,
        speak = function(_, text)
            tinsert(env.spoken, text)
        end,
    }
    WowVision.graph = {}
    for _, file in ipairs({ "ControlId", "types", "Announcer", "KeyGraph", "Builder", "ControlTypes", "nodes" }) do
        load("core/graph/" .. file .. ".lua")
    end
    env.graph = WowVision.graph
    load("core/secrets.lua")

    -- The words the host installs into the announcer.
    local announcer = env.graph.announcer
    announcer.positionText = function(index, count)
        return index .. " of " .. count
    end
    announcer.expandedStateText = function(expanded)
        return expanded and "Expanded" or "Collapsed"
    end

    -- A screen driver over a render function(builder, screen): the real KeyGraph walks the real Builder's output.
    function env.driver(render)
        local graph = env.graph
        local state = graph.newState()
        local screen = {}
        local kg = graph.KeyGraph:new(function()
            local builder = graph.Builder:new(state.expanded)
            render(builder, screen)
            return builder:build()
        end, state)
        local d = { kg = kg, state = state, screen = screen }
        -- every node of the current render, in order
        function d.nodes()
            kg:rerender()
            return kg.current and kg.current.order or {}
        end
        function d.say(node)
            return announcer.leafText(node or kg:currentNode())
        end
        -- what each node reads as, one per line
        function d.dump()
            local lines = {}
            for _, node in ipairs(d.nodes()) do
                lines[#lines + 1] = d.say(node) or "?"
            end
            return lines
        end
        -- focus the first node whose reading starts with text; nil when none
        function d.focus(text)
            for _, node in ipairs(d.nodes()) do
                local said = d.say(node)
                if said ~= nil and said:sub(1, #text) == text then
                    kg:focus(node.id)
                    return node
                end
            end
            return nil
        end
        function d.enter()
            return kg:activate()
        end
        function d.right()
            return kg:treeRight()
        end
        function d.left()
            return kg:treeLeft()
        end
        function d.adjust(sign, large)
            return kg:tryAdjust(sign, large)
        end
        function d.tab(step)
            return kg:move(step and step < 0 and "previous" or "next")
        end
        function d.down()
            return kg:move("down")
        end
        function d.up()
            return kg:move("up")
        end
        return d
    end

    -- What the nodes ask of the host when activated: record it, so the tests can follow a pushed screen.
    local stack = { name = "stack" }
    WowVision.graphHost = {
        focusedStack = function()
            return stack
        end,
        push = function(_, _, config)
            tinsert(env.pushed, config)
        end,
        pop = function()
            env.popped = env.popped + 1
        end,
        openTextEntry = function(_, config)
            tinsert(env.entries, config)
        end,
    }
    env.stack = stack
    return env
end
