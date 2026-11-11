return function(runner, env)
local loadAddon = env.loadAddon

-- ----------------------------------------------------------------- Text

runner:addSuite("Text", {
    ["plain strips colour codes and textures"] = function(t)
        local ns = loadAddon()
        t:assertEqual(ns.Text.plain("|cff00ff00Hello|r |T132845:0|t[Spell]"), "Hello [Spell]")
        t:assertEqual(ns.Text.plain("|Tinterface/worldmap/chatbubble_64grey.blp:20|tParlez à |cffffffffAilee::251362|r."), "Parlez à Ailee.")
    end,
    ["plain keeps the text of a hyperlink"] = function(t)
        local ns = loadAddon()
        t:assertEqual(ns.Text.plain("Take |Hquest:123:5|h[The Quest]|h now"), "Take [The Quest] now")
    end,
    ["plain strips unresolved RestedXP colour tokens"] = function(t)
        local ns = loadAddon()
        t:assertEqual(ns.Text.plain("Kill |cRXP_ENEMY_Wolves::1234|r"), "Kill Wolves")
    end,
    ["plain collapses whitespace and line breaks"] = function(t)
        local ns = loadAddon()
        t:assertEqual(ns.Text.plain("  one\n   two\t three  "), "one two three")
        t:assertEqual(ns.Text.plain("a|nb"), "a b")
    end,
    ["plain gives nil for nothing"] = function(t)
        local ns = loadAddon()
        t:assertNil(ns.Text.plain(nil))
        t:assertNil(ns.Text.plain(""))
        t:assertNil(ns.Text.plain("  |cff00ff00|r  "))
        t:assertNil(ns.Text.plain("|T132845:0|t"))
    end,
    ["plain accepts a number"] = function(t)
        local ns = loadAddon()
        t:assertEqual(ns.Text.plain(12), "12")
    end,

    ["relative degrees: facing north, a target east is on the right"] = function(t)
        local ns = loadAddon()
        -- HereBeDragons' angle for east is 3*pi/2 when facing is counted counter clockwise from north.
        local degrees = ns.Text.relativeDegrees(3 * math.pi / 2, 0)
        t:assertTrue(math.abs(degrees - 90) < 1e-9, "east is 90 degrees to the right, got " .. degrees)
    end,
    ["relative degrees: a target west is on the left"] = function(t)
        local ns = loadAddon()
        local degrees = ns.Text.relativeDegrees(math.pi / 2, 0)
        t:assertTrue(math.abs(degrees + 90) < 1e-9, "west is 90 degrees to the left, got " .. degrees)
    end,
    ["relative degrees: facing the target is zero"] = function(t)
        local ns = loadAddon()
        t:assertTrue(math.abs(ns.Text.relativeDegrees(1.2, 1.2)) < 1e-9)
    end,
    ["relative degrees: behind is 180 and the range is -180 to 180"] = function(t)
        local ns = loadAddon()
        local degrees = ns.Text.relativeDegrees(math.pi, 0)
        t:assertTrue(math.abs(math.abs(degrees) - 180) < 1e-9)
        for step = 0, 71 do
            local value = ns.Text.relativeDegrees(step * math.pi / 36, 0.3)
            t:assertTrue(value > -180 - 1e-9 and value <= 180 + 1e-9, "out of range: " .. value)
        end
    end,
    ["relative degrees: turning right moves a target to the left"] = function(t)
        local ns = loadAddon()
        -- the player turns clockwise (facing decreases): a fixed target drifts to the left of the view
        local before = ns.Text.relativeDegrees(0, 0)
        local after = ns.Text.relativeDegrees(0, -math.rad(30))
        t:assertTrue(after < before, "target should move left when the player turns right")
    end,

    ["direction words"] = function(t)
        local ns = loadAddon()
        local D = ns.Text.direction
        t:assertEqual(D(0), "ahead of you")
        t:assertEqual(D(14), "ahead of you")
        t:assertEqual(D(-14), "ahead of you")
        t:assertEqual(D(180), "behind you")
        t:assertEqual(D(-170), "behind you")
        t:assertEqual(D(90), "at 3 o'clock, to your right")
        t:assertEqual(D(-90), "at 9 o'clock, to your left")
        t:assertEqual(D(30), "at 1 o'clock, to your right")
        t:assertEqual(D(-30), "at 11 o'clock, to your left")
        t:assertEqual(D(150), "at 5 o'clock, to your right")
        t:assertEqual(D(-150), "at 7 o'clock, to your left")
    end,
    ["direction edges sit where the words change"] = function(t)
        local ns = loadAddon()
        local D = ns.Text.direction
        t:assertEqual(D(15), "at 1 o'clock, to your right")
        t:assertEqual(D(165), "at 5 o'clock, to your right")
        t:assertEqual(D(165.5), "behind you")
        t:assertEqual(D(-15), "at 11 o'clock, to your left")
    end,
    ["direction in French"] = function(t)
        local ns = loadAddon()
        ns.useLocale("frFR")
        t:assertEqual(ns.Text.direction(0), "devant vous")
        t:assertEqual(ns.Text.direction(60), "à 2 heures, à droite")
        t:assertEqual(ns.Text.direction(-60), "à 10 heures, à gauche")
        t:assertEqual(ns.Text.direction(180), "derrière vous")
    end,

    ["yards say metres in French and use the singular"] = function(t)
        local ns = loadAddon()
        t:assertEqual(ns.Text.yards(35), "35 yards")
        t:assertEqual(ns.Text.yards(1), "1 yard")
        t:assertEqual(ns.Text.yards(0.4), "0 yards")
        ns.useLocale("frFR")
        t:assertEqual(ns.Text.yards(35.6), "36 mètres")
        t:assertEqual(ns.Text.yards(1.2), "1 mètre")
    end,

    ["a step reads its title and its lines"] = function(t)
        local ns = loadAddon()
        t:assertEqual(
            ns.Text.step("Step 3", { { text = "Accept A" }, { text = "Go to B", done = true } }),
            "Step 3. Accept A. Go to B, done"
        )
        t:assertEqual(ns.Text.step(nil, { { text = "Only line" } }), "Only line")
        t:assertEqual(ns.Text.step("", { { text = "Only line" } }), "Only line")
        t:assertEqual(ns.Text.step("Step 1", {}), "Step 1")
    end,

    ["the arrow says its target, direction and distance"] = function(t)
        local ns = loadAddon()
        t:assertEqual(
            ns.Text.arrow({ title = "Talk to Ailee", degrees = 90, distance = 35 }),
            "Talk to Ailee, at 3 o'clock, to your right, 35 yards"
        )
        t:assertEqual(ns.Text.arrow({ degrees = 0, distance = 12 }), "ahead of you, 12 yards")
        t:assertEqual(ns.Text.arrow({ distance = 12 }), "12 yards")
    end,
    ["the arrow on another continent gives no direction"] = function(t)
        local ns = loadAddon()
        t:assertEqual(
            ns.Text.arrow({ title = "Boat", otherContinent = true, degrees = 10, distance = 5 }),
            "Boat, on another continent"
        )
    end,
    ["the arrow with nothing says so"] = function(t)
        local ns = loadAddon()
        t:assertEqual(ns.Text.arrow(nil), "No destination in the guide right now.")
        t:assertEqual(ns.Text.arrow({ none = true }), "No destination in the guide right now.")
        t:assertEqual(ns.Text.arrow({}), "Destination unknown.")
    end,
})


end
