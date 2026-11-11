-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- The game and WowVision are mocked, but the addon's own files are loaded for real, in the order of the .toc, so
-- the tests run the window's real render code against a trainer frame shaped like the one the game builds.

local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."

-- ----------------------------------------------------------------- harness

tinsert = table.insert
format = string.format

local runner = { suites = {}, order = {}, passed = 0, failed = 0 }

function runner:addSuite(name, suite)
    self.suites[name] = suite
    tinsert(self.order, name)
end
function runner:assertEqual(a, b, message)
    if a ~= b then
        error((message or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end
function runner:assertTrue(value, message)
    if value ~= true then
        error((message or "expected true") .. ", got " .. tostring(value), 2)
    end
end
function runner:assertFalse(value, message)
    if value ~= false then
        error((message or "expected false") .. ", got " .. tostring(value), 2)
    end
end
function runner:assertNil(value, message)
    if value ~= nil then
        error((message or "expected nil") .. ", got " .. tostring(value), 2)
    end
end
function runner:assertNotNil(value, message)
    if value == nil then
        error(message or "expected a value", 2)
    end
end

function runner:run()
    for _, name in ipairs(self.order) do
        local names = {}
        for testName in pairs(self.suites[name]) do
            tinsert(names, testName)
        end
        table.sort(names)
        for _, testName in ipairs(names) do
            local ok, err = pcall(self.suites[name][testName], self)
            if ok then
                self.passed = self.passed + 1
            else
                self.failed = self.failed + 1
                io.write("FAIL  ", name, " / ", testName, "\n      ", tostring(err), "\n")
            end
        end
    end
    io.write(string.format("%d passed, %d failed\n", self.passed, self.failed))
    os.exit(self.failed == 0 and 0 or 1)
end

-- ------------------------------------------------------------- the addon

local FILES = { "Locale", "Pet", "Window", "Main" }

local function loadAddon(upTo)
    local ns = {}
    for _, name in ipairs(FILES) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_PetTraining", ns)
        if name == upTo then
            break
        end
    end
    return ns
end

-- ported suite: the pet's window detection (it finds its subject on WowVision)
local function setupFakeGraph(world)
    local nodes = {}
    function nodes.text(config)
        return { label = config.label, live = config.live }
    end
    function nodes.proxyDropdown(config)
        return { label = config.label or "dropdown" }
    end
    function nodes.proxyButton(config)
        return { label = config.label or "button" }
    end
    function nodes.attachHover(vtable)
        return vtable
    end
    function nodes.scrollBoxList(builder, config)
        tinsert(world.recorded, "list " .. tostring(config.key) .. " (" .. tostring(config.label) .. ")")
        -- two rows shaped as the tree provider hands them: a node holding the data
        for index = 1, 2 do
            local data = {
                GetData = function()
                    return { skillIndex = index }
                end,
            }
            config.emit(builder, data, index, { id = "row" .. index, target = {} })
        end
    end
    return {
        nodes = nodes,
        ControlId = {
            structural = function(name)
                return "structural:" .. name
            end,
            forObject = function()
                return "object"
            end,
        },
        controlTypes = { button = "button" },
        kinds = { label = "label", value = "value", selected = "selected" },
    }
end

local function region(text)
    return {
        GetText = function()
            return text
        end,
    }
end

local function frame(shown, parts)
    local result = {
        IsShown = function()
            return shown
        end,
        IsVisible = function()
            return shown
        end,
    }
    for key, value in pairs(parts or {}) do
        result[key] = value
    end
    return result
end

-- A fake WowVision and game around the real addon. options.interacting: a trainer NPC is open too;
-- options.locale: the game's language.
local function newWorld(options)
    options = options or {}
    local world = { recorded = {}, windows = {}, errors = {}, registered = 0, locale = options.locale or "enUS" }

    GetLocale = function()
        return world.locale
    end
    geterrorhandler = function()
        return function(err)
            tinsert(world.errors, tostring(err))
        end
    end
    print = function(...)
        tinsert(world.errors, "print: " .. table.concat({ ... }, " "))
    end

    -- the recorded builder
    local builder = {}
    function builder:pushContext(key, label)
        tinsert(world.recorded, "context " .. tostring(key) .. ": " .. tostring(label))
    end
    function builder:popContext() end
    function builder:beginStop(key)
        tinsert(world.recorded, "stop " .. tostring(key))
    end
    function builder:addItem(id, vtable)
        local first = vtable.announcements and vtable.announcements[1]
        local text = first and first.text
        if type(text) == "function" then
            text = text()
        end
        local label = vtable.label
        if type(label) == "function" then
            label = label()
        end
        tinsert(world.recorded, "item " .. tostring(id) .. ((text or label) and (" = " .. tostring(text or label)) or ""))
    end
    world.builder = builder

    -- the window manager
    local manager = { windows = {} }
    function manager:RegisterWindow(window)
        world.registered = world.registered + 1
        self.windows[window.name] = window
    end
    function manager:getWindow(name)
        return self.windows[name]
    end
    local windowClass = {}
    function windowClass:CreateWindow(typeKey, config)
        assert(typeKey == "CustomWindow", "the window is a custom window")
        return config
    end

    WowVision = {
        graph = setupFakeGraph(world),
        UIHost = { windowManager = manager },
        WindowManager = windowClass,
    }
    if options.corePet then
        WowVision.petTraining = {}
    end

    Enum = { PlayerInteractionType = { Trainer = 43 } }
    C_PlayerInteractionManager = {
        IsInteractingWithNpcOfType = function()
            return options.interacting == true
        end,
    }
    C_CurrencyInfo = {
        GetCoinText = function(copper)
            return copper .. " copper"
        end,
    }
    TRAINER_REQ_LEVEL, REQUIRES_LABEL, PLAYER_LIST_DELIMITER = "Level %d", "Requires:", ", "

    GetNumTrainerServices = function()
        return 2
    end
    GetTrainerSelectionIndex = function()
        return 1
    end
    GetTrainerServiceInfo = function(index)
        return ({ "Natural Armor", "Great Stamina" })[index], "available", 136094, index == 1 and 8 or 12, "Rank " .. index
    end
    GetTrainerServiceCost = function(index)
        return index == 1 and 1 or 5
    end

    local points = region("Training Points: 19")
    ClassTrainerFrame = frame(options.shown ~= false, {
        trainingPoints = frame(options.points ~= false, { text = points }),
        FilterDropdown = frame(true),
        ScrollBox = frame(true),
        TrainButton = frame(true),
    })
    ClassTrainerFrameTitleText = region("Scorpid")
    ClassTrainerFrameTrainingPointsLabel = points

    world.ns = loadAddon()
    return world
end

local function render(world)
    world.recorded = {}
    local window = world.ns.getWindow()
    window.graphScreen.render(world.builder, {})
    return table.concat(world.recorded, "\n")
end

local function contains(text, part)
    return text:find(part, 1, true) ~= nil
end

-- the ported suite of Pet.lua, as it was inside WowVision
local purePet = loadAddon("Pet")
WowVision = { testing = { testRunner = runner }, petTraining = purePet.pet }
local firstPure = #runner.order
dofile(testsDir .. "/pet.lua")
for index = firstPure + 1, #runner.order do
    local suite = runner.suites[runner.order[index]]
    for testName, fn in pairs(suite) do
        suite[testName] = function(t)
            WowVision = { testing = { testRunner = runner }, petTraining = purePet.pet }
            return fn(t)
        end
    end
end

-- ------------------------------------------------------------------ tests

runner:addSuite("Window", {
    ["the window is registered once, as a custom window"] = function(t)
        local world = newWorld()
        t:assertEqual(world.registered, 1)
        local window = WowVision.UIHost.windowManager:getWindow("beastTraining")
        t:assertNotNil(window)
        t:assertEqual(window.conflictingAddons[1], "Sku")
        t:assertTrue(world.ns.install())
        t:assertEqual(world.registered, 1, "a second install adds nothing")
        t:assertEqual(#world.errors, 0, table.concat(world.errors, "; "))
    end,

    ["it is open while the pet's frame is, and not for a trainer NPC"] = function(t)
        local world = newWorld()
        local window = WowVision.UIHost.windowManager:getWindow("beastTraining")
        t:assertTrue(window.isOpenFunc())
        ClassTrainerFrame.trainingPoints = frame(false)
        t:assertFalse(window.isOpenFunc())
        local npc = newWorld({ interacting = true })
        t:assertFalse(WowVision.UIHost.windowManager:getWindow("beastTraining").isOpenFunc())
        t:assertNotNil(npc)
    end,

    ["a WowVision that has the pet's window itself gets none"] = function(t)
        local world = newWorld({ corePet = true })
        t:assertEqual(world.registered, 0)
    end,

    ["a WowVision without a window manager is reported"] = function(t)
        local world = newWorld()
        WowVision.UIHost = nil
        local again = loadAddon()
        t:assertFalse(again.installed)
    end,

    ["the screen reads the points first, then the filter, the services and the train button"] = function(t)
        local world = newWorld()
        world.ns.getWindow = function()
            return WowVision.UIHost.windowManager:getWindow("beastTraining")
        end
        local text = render(world)
        local lines = {}
        for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            tinsert(lines, line)
        end
        t:assertEqual(lines[1], "context trainer: Scorpid")
        t:assertEqual(lines[2], "stop trainingPoints")
        t:assertEqual(lines[3], "item structural:trainingPoints = Training Points: 19")
        t:assertEqual(lines[4], "stop filter")
        t:assertTrue(contains(text, "stop services"), text)
        t:assertTrue(contains(text, "stop train"), text)
    end,

    ["a skill's cost is said in training points, not coins"] = function(t)
        local world = newWorld()
        world.ns.getWindow = function()
            return WowVision.UIHost.windowManager:getWindow("beastTraining")
        end
        local text = render(world)
        t:assertTrue(contains(text, "Natural Armor Rank 1, Training point cost: 1"), text)
        t:assertTrue(contains(text, "Great Stamina Rank 2, Training point cost: 5"), text)
        t:assertFalse(contains(text, "copper"), text)
    end,

    ["a requirement is said with the level"] = function(t)
        local world = newWorld()
        world.ns.getWindow = function()
            return WowVision.UIHost.windowManager:getWindow("beastTraining")
        end
        local text = render(world)
        t:assertTrue(contains(text, "Requires: Level 12"), text)
    end,

    ["the French window says its points and costs in French"] = function(t)
        local world = newWorld({ locale = "frFR" })
        world.ns.getWindow = function()
            return WowVision.UIHost.windowManager:getWindow("beastTraining")
        end
        local text = render(world)
        t:assertTrue(contains(text, "Coût en points d'entraînement : 5"), text)
        t:assertTrue(contains(text, "list services (Entraînement)"), text)
    end,

    ["the German window says its costs and headings in German"] = function(t)
        local world = newWorld({ locale = "deDE" })
        world.ns.getWindow = function()
            return WowVision.UIHost.windowManager:getWindow("beastTraining")
        end
        local text = render(world)
        t:assertTrue(contains(text, "Kosten in Trainingspunkten: 5"), text)
        t:assertTrue(contains(text, "list services (Ausbildung)"), text)
        t:assertTrue(contains(text, "Training Points: 19"), "the points are the game's own text")
    end,

    ["a language without translations reads English, and the window still opens"] = function(t)
        for _, locale in ipairs({ "enUS", "enGB", "esES", "ruRU", "koKR" }) do
            local world = newWorld({ locale = locale })
            t:assertEqual(world.registered, 1, locale)
            local window = WowVision.UIHost.windowManager:getWindow("beastTraining")
            t:assertTrue(window.isOpenFunc(), locale)
            world.ns.getWindow = function()
                return window
            end
            local text = render(world)
            t:assertTrue(contains(text, "Training point cost: 5"), locale .. ": " .. text)
            t:assertTrue(contains(text, "list services (Training)"), locale)
            t:assertTrue(contains(text, "Natural Armor Rank 1"), locale .. ": the skill names are the game's")
        end
    end,

    ["a closed frame renders nothing"] = function(t)
        local world = newWorld({ shown = false })
        world.ns.getWindow = function()
            return WowVision.UIHost.windowManager:getWindow("beastTraining")
        end
        t:assertEqual(render(world), "")
    end,

    ["without points to read there is no points stop"] = function(t)
        local world = newWorld()
        world.ns.getWindow = function()
            return WowVision.UIHost.windowManager:getWindow("beastTraining")
        end
        ClassTrainerFrame.trainingPoints.text = nil
        ClassTrainerFrameTrainingPointsLabel = nil
        t:assertFalse(contains(render(world), "stop trainingPoints"))
    end,
})

runner:run()
