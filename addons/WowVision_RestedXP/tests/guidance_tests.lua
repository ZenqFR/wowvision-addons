return function(runner, env)
local loadAddon = env.loadAddon

local FILES = { "Locale", "Text", "Guidance" }

-- WowVision's maps module, as far as this addon uses it.
local function fakeMaps(config)
    config = config or {}
    local maps = { calls = {}, guiding = config.guiding or false }
    function maps:directTo(x, y, label)
        tinsert(self.calls, { "directTo", x, y, label })
        if config.directError then
            error("direct failed")
        end
        self.guiding = true
    end
    function maps:beaconTo(x, y, label)
        tinsert(self.calls, { "beaconTo", x, y, label })
        self.guiding = true
    end
    function maps:goToDestination(destination, direct)
        tinsert(self.calls, { "goToDestination", destination, direct })
        if config.routeResult == false then
            return false
        end
        self.guiding = true
        return true
    end
    function maps:isGuiding()
        return self.guiding
    end
    function maps:cancelNavigation()
        tinsert(self.calls, { "cancel" })
        self.guiding = false
        return true
    end
    return maps
end

local function arrow(extra)
    local value = { title = "Talk to Ailee", wx = 10.5, wy = 20.25, instance = 1 }
    for key, v in pairs(extra or {}) do
        value[key] = v
    end
    return value
end

local function fresh()
    local ns = loadAddon(FILES)
    ns.Guidance.following = nil
    ns.Guidance.lastPoint = nil
    return ns
end

runner:addSuite("Guidance: the destination", {
    ["WowVision's x and y are RestedXP's wy and wx"] = function(t)
        local ns = fresh()
        local destination = ns.Guidance.destination(arrow())
        t:assertEqual(destination.x, 20.25)
        t:assertEqual(destination.y, 10.5)
        t:assertEqual(destination.n, "Talk to Ailee")
        t:assertTrue(destination.virtual)
        t:assertTrue(destination.routeData.lowestFloor)
    end,
    ["a destination without a title gets a name"] = function(t)
        local ns = fresh()
        t:assertEqual(ns.Guidance.destination(arrow({ title = false })).n, "Destination")
        local nameless = arrow()
        nameless.title = nil
        t:assertEqual(ns.Guidance.destination(nameless).n, "Destination")
    end,
    ["the point is the arrow's place and instance, nothing when it has none"] = function(t)
        local ns = fresh()
        local point = ns.Guidance.point(arrow())
        t:assertEqual(point.x, 10.5)
        t:assertEqual(point.y, 20.25)
        t:assertEqual(point.instance, 1)
        t:assertNil(ns.Guidance.point(nil))
        t:assertNil(ns.Guidance.point({ none = true }))
        t:assertNil(ns.Guidance.point({ title = "No place" }))
        t:assertEqual(ns.Guidance.point({ wx = 3 }).y, 0)
    end,
    ["the tolerance is ten yards"] = function(t)
        t:assertEqual(fresh().Guidance.tolerance, 10)
    end,
})

local function point(ns, x, y, instance)
    return ns.Guidance.point({ wx = x, wy = y, instance = instance or 1 })
end

runner:addSuite("Guidance: when the destination counts as another", {
    ["with nothing before, it is another"] = function(t)
        local ns = fresh()
        t:assertTrue(ns.Guidance.moved(nil, point(ns, 0, 0)))
    end,
    ["the same place is not"] = function(t)
        local ns = fresh()
        t:assertFalse(ns.Guidance.moved(point(ns, 5, 5), point(ns, 5, 5)))
    end,
    ["a drift inside the tolerance is not, in any direction"] = function(t)
        local ns = fresh()
        local before = point(ns, 100, 100)
        t:assertFalse(ns.Guidance.moved(before, point(ns, 109, 100)))
        t:assertFalse(ns.Guidance.moved(before, point(ns, 91, 100)))
        t:assertFalse(ns.Guidance.moved(before, point(ns, 100, 109)))
        t:assertFalse(ns.Guidance.moved(before, point(ns, 100, 91)))
    end,
    ["further than the tolerance is, in any direction"] = function(t)
        local ns = fresh()
        local before = point(ns, 100, 100)
        t:assertTrue(ns.Guidance.moved(before, point(ns, 111, 100)))
        t:assertTrue(ns.Guidance.moved(before, point(ns, 89, 100)))
        t:assertTrue(ns.Guidance.moved(before, point(ns, 100, 111)))
        t:assertTrue(ns.Guidance.moved(before, point(ns, 100, 89)))
    end,
    ["the distance is the straight one, across both axes"] = function(t)
        local ns = fresh()
        local before = point(ns, 0, 0)
        -- 6 and 8 make exactly 10: still the same; a hair more is another
        t:assertFalse(ns.Guidance.moved(before, point(ns, 6, 8)))
        t:assertTrue(ns.Guidance.moved(before, point(ns, 6, 8.1)))
        t:assertFalse(ns.Guidance.moved(before, point(ns, -6, -8)))
        t:assertTrue(ns.Guidance.moved(before, point(ns, -7, -8)))
    end,
    ["another instance is another, at the same place"] = function(t)
        local ns = fresh()
        t:assertTrue(ns.Guidance.moved(point(ns, 5, 5, 1), point(ns, 5, 5, 2)))
        t:assertFalse(ns.Guidance.moved(point(ns, 5, 5, nil), point(ns, 5, 5, nil)))
    end,
    ["the tolerance can be changed"] = function(t)
        local ns = fresh()
        ns.Guidance.tolerance = 0
        t:assertTrue(ns.Guidance.moved(point(ns, 0, 0), point(ns, 0, 0.5)))
        t:assertFalse(ns.Guidance.moved(point(ns, 0, 0), point(ns, 0, 0)))
        ns.Guidance.tolerance = 50
        t:assertFalse(ns.Guidance.moved(point(ns, 0, 0), point(ns, 30, 30)))
        t:assertTrue(ns.Guidance.moved(point(ns, 0, 0), point(ns, 40, 40)))
    end,
})

runner:addSuite("Guidance: starting", {
    ["a beacon goes straight to the point"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        t:assertTrue(ns.Guidance.start(maps, arrow(), "beacon"))
        t:assertEqual(maps.calls[1][1], "directTo")
        t:assertEqual(maps.calls[1][2], 20.25)
        t:assertEqual(maps.calls[1][3], 10.5)
        t:assertEqual(maps.calls[1][4], "Talk to Ailee")
        t:assertEqual(ns.Guidance.following, "beacon")
    end,
    ["a route asks WowVision to go to the destination, not direct"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        t:assertTrue(ns.Guidance.start(maps, arrow(), "route"))
        t:assertEqual(maps.calls[1][1], "goToDestination")
        t:assertEqual(maps.calls[1][2].x, 20.25)
        t:assertFalse(maps.calls[1][3])
        t:assertEqual(ns.Guidance.following, "route")
    end,
    ["a route that is not found says so and follows nothing"] = function(t)
        local ns = fresh()
        local maps = fakeMaps({ routeResult = false })
        local ok, why = ns.Guidance.start(maps, arrow(), "route")
        t:assertFalse(ok)
        t:assertEqual(why, "No route found.")
        t:assertNil(ns.Guidance.following)
    end,
    ["no navigation, no destination, another continent"] = function(t)
        local ns = fresh()
        local ok, why = ns.Guidance.start(nil, arrow(), "beacon")
        t:assertFalse(ok)
        t:assertEqual(why, "WowVision's navigation is not available.")
        ok, why = ns.Guidance.start(fakeMaps(), { none = true }, "beacon")
        t:assertEqual(why, "No destination in the guide right now.")
        ok, why = ns.Guidance.start(fakeMaps(), nil, "beacon")
        t:assertEqual(why, "No destination in the guide right now.")
        ok, why = ns.Guidance.start(fakeMaps(), arrow({ otherContinent = true }), "beacon")
        t:assertEqual(why, "The destination is on another continent.")
        t:assertNil(ns.Guidance.following)
    end,
    ["a failing beacon is reported and follows nothing"] = function(t)
        local ns = fresh()
        local maps = fakeMaps({ directError = true })
        local ok, why = ns.Guidance.start(maps, arrow(), "beacon")
        t:assertFalse(ok)
        t:assertMatch(why, "direct failed")
        t:assertNil(ns.Guidance.following)
    end,
    ["an older WowVision without directTo uses the plain beacon"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        maps.directTo = nil
        t:assertTrue(ns.Guidance.start(maps, arrow(), "beacon"))
        t:assertEqual(maps.calls[1][1], "beaconTo")
    end,
    ["a maps module with nothing usable"] = function(t)
        local ns = fresh()
        local ok, why = ns.Guidance.start({}, arrow(), "beacon")
        t:assertFalse(ok)
        t:assertEqual(why, "WowVision's navigation is not available.")
    end,
})

runner:addSuite("Guidance: following the arrow", {
    ["it guides again when the destination changes, once"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.start(maps, arrow(), "beacon")
        t:assertFalse(ns.Guidance.follow(maps, arrow()))
        t:assertEqual(#maps.calls, 1)
        t:assertTrue(ns.Guidance.follow(maps, arrow({ wx = 99, title = "Next" })))
        t:assertEqual(#maps.calls, 2)
        t:assertEqual(maps.calls[2][4], "Next")
        t:assertFalse(ns.Guidance.follow(maps, arrow({ wx = 99, title = "Next" })))
        t:assertEqual(#maps.calls, 2)
    end,
    ["a small drift of the arrow does not redo the guidance"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.start(maps, arrow(), "route")
        t:assertFalse(ns.Guidance.follow(maps, arrow({ wx = 15 })))
        t:assertFalse(ns.Guidance.follow(maps, arrow({ wy = 25, title = "Same place, another name" })))
        t:assertEqual(#maps.calls, 1)
        t:assertEqual(ns.Guidance.following, "route")
    end,
    ["small drifts add up against where the guidance was aimed, and then it is redone, once"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.start(maps, arrow({ wx = 0, wy = 0 }), "beacon")
        for _, x in ipairs({ 3, 6, 9, 10 }) do
            t:assertFalse(ns.Guidance.follow(maps, arrow({ wx = x, wy = 0 })), "at " .. x)
        end
        t:assertEqual(#maps.calls, 1)
        t:assertTrue(ns.Guidance.follow(maps, arrow({ wx = 12, wy = 0, title = "Drifted" })))
        t:assertEqual(#maps.calls, 2)
        t:assertEqual(maps.calls[2][4], "Drifted")
        -- aimed at 12 now: 15 is a small move from there
        t:assertFalse(ns.Guidance.follow(maps, arrow({ wx = 15, wy = 0 })))
        t:assertEqual(#maps.calls, 2)
    end,
    ["another instance redoes the guidance at the same place"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.start(maps, arrow(), "beacon")
        t:assertTrue(ns.Guidance.follow(maps, arrow({ instance = 2 })))
        t:assertEqual(#maps.calls, 2)
    end,
    ["it follows in the mode it was asked in"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.start(maps, arrow(), "route")
        ns.Guidance.follow(maps, arrow({ wx = 50 }))
        t:assertEqual(maps.calls[2][1], "goToDestination")
    end,
    ["it does nothing when nothing was asked"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        t:assertFalse(ns.Guidance.follow(maps, arrow()))
        t:assertEqual(#maps.calls, 0)
    end,
    ["an arrow without a destination leaves the guidance as it is"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.start(maps, arrow(), "beacon")
        t:assertFalse(ns.Guidance.follow(maps, { none = true }))
        t:assertEqual(ns.Guidance.following, "beacon")
        t:assertEqual(#maps.calls, 1)
    end,
    ["another continent waits"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.start(maps, arrow(), "beacon")
        t:assertFalse(ns.Guidance.follow(maps, arrow({ wx = 70, otherContinent = true })))
        t:assertEqual(#maps.calls, 1)
        t:assertEqual(ns.Guidance.following, "beacon")
    end,
    ["a start that fails is tried once per destination, not every moment"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.start(maps, arrow(), "beacon")
        maps.directTo = function()
            tinsert(maps.calls, { "directTo failing" })
            error("boom")
        end
        t:assertFalse(ns.Guidance.follow(maps, arrow({ wx = 70 })))
        t:assertFalse(ns.Guidance.follow(maps, arrow({ wx = 70 })))
        t:assertFalse(ns.Guidance.follow(maps, arrow({ wx = 70 })))
        t:assertEqual(#maps.calls, 2)
        t:assertEqual(ns.Guidance.following, "beacon")
    end,
})

runner:addSuite("Guidance: stopping", {
    ["stop ends the following and WowVision's guidance"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.start(maps, arrow(), "beacon")
        t:assertNotNil(ns.Guidance.lastPoint)
        t:assertTrue(ns.Guidance.stop(maps))
        t:assertEqual(maps.calls[2][1], "cancel")
        t:assertNil(ns.Guidance.following)
        t:assertNil(ns.Guidance.lastPoint)
        t:assertFalse(ns.Guidance.follow(maps, arrow({ wx = 70 })))
    end,
    ["stop with nothing guiding only clears the following"] = function(t)
        local ns = fresh()
        local maps = fakeMaps()
        ns.Guidance.following = "route"
        t:assertFalse(ns.Guidance.stop(maps))
        t:assertEqual(#maps.calls, 0)
        t:assertNil(ns.Guidance.following)
    end,
    ["stop without a maps module is harmless"] = function(t)
        local ns = fresh()
        ns.Guidance.following = "route"
        t:assertFalse(ns.Guidance.stop(nil))
        t:assertNil(ns.Guidance.following)
    end,
})

end
