-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- The game, RestedXP and WowVision are mocked; the addon's own files are loaded for real, in the order of the
-- .toc. Neither RestedXP nor WowVision is needed.

local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."

tinsert = table.insert

-- ----------------------------------------------------------------- harness

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
function runner:assertMatch(value, pattern, message)
    if type(value) ~= "string" or not value:find(pattern) then
        error((message or "no match") .. ": expected " .. pattern .. ", got " .. tostring(value), 2)
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

local FILES = { "Locale", "Text", "Source" }

-- A fresh namespace with the addon's files loaded into it, in .toc order.
local function loadAddon(only)
    local ns = {}
    for _, name in ipairs(only or FILES) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_RestedXP", ns)
    end
    return ns
end

-- Shared with the suites: the loader, the folders and the fakes of the game and of RestedXP.
local env = {
    loadAddon = loadAddon,
    addonDir = addonDir,
    testsDir = testsDir,
    -- WowVision's folder, whose real graph framework the screens are built and walked with
    wowvision = os.getenv("WOWVISION_DIR") or (addonDir .. "/../WowVision"),
}
env.fake = dofile(testsDir .. "/fakes.lua")

local SUITES = {
    "text_tests",
    "source_tests",
    "options_tests",
    "menu_tests",
    "guidance_tests",
    "import_tests",
    "screens_tests",
    "main_tests",
    "game_tests",
    "locale_tests",
    "perf_tests",
}
for _, name in ipairs(SUITES) do
    dofile(testsDir .. "/" .. name .. ".lua")(runner, env)
end

runner:run()
