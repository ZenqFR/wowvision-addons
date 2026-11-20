-- Runs this addon's key (Alt+Ctrl+G) and its window against WowVision's REAL class system, registry, input manager, binding types and db
-- manager (the code that decides which key goes to which binding and what the player's saved keys do), with the
-- keys WowVision and the other extensions already use registered as bindings of their own. Usage, from the addon
-- folder: lua tests/real_core.lua   (prints "all ok" when every check passes).
local script = arg and arg[0] or "tests/real_core.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local wv = (os.getenv("WOWVISION_DIR") or (addonDir .. "/../WowVision")) .. "/"

tinsert = table.insert
tremove = table.remove
unpack = unpack or table.unpack
wipe = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end
GetLocale = function()
    return "frFR"
end

local failures = 0
local function check(label, ok, extra)
    if not ok then
        failures = failures + 1
    end
    print((ok and "ok    " or "FAIL  ") .. label .. (extra ~= nil and ("  " .. tostring(extra)) or ""))
end

local function newFrame(name)
    local frame = { name = name, attributes = {}, scripts = {} }
    function frame:SetAttribute(k, v)
        self.attributes[k] = v
    end
    function frame:GetAttribute(k)
        return self.attributes[k]
    end
    function frame:GetName()
        return self.name
    end
    function frame:SetScript(kind, fn)
        self.scripts[kind] = fn
    end
    function frame:RegisterEvent() end
    function frame:RegisterForClicks() end
    return frame
end

-- Every key combination WowVision and the other extensions use, read from their source, so that nothing of this
-- addon's can sit on one of them.
local function readFile(path)
    local f = assert(io.open(path, "rb"), path)
    local s = f:read("a")
    f:close()
    return s
end

local function listFiles(dir)
    local files = {}
    local handle = io.popen('dir /b /s "' .. dir:gsub("/", "\\") .. '\\*.lua" 2>NUL')
    if handle == nil then
        return files
    end
    for line in handle:lines() do
        files[#files + 1] = line
    end
    handle:close()
    return files
end

local function existingKeys()
    local taken = {}
    local function scan(dir)
        for _, path in ipairs(listFiles(dir)) do
            local text = readFile(path)
            for list in text:gmatch("inputs = (%b{})") do
                for key in list:gmatch('"([^"]+)"') do
                    taken[key] = taken[key] or path
                end
            end
        end
    end
    scan(wv .. "core")
    scan(wv .. "retail")
    scan(wv .. "camelot")
    local extras = os.getenv("WOWVISION_ADDONS_DIR") or (addonDir .. "/..")
    for _, name in ipairs({ "WowVision_Bags", "WowVision_QuestTargets", "WowVision_Quests", "WowVision_ItemCompare", "WowVision_LocalizedNames", "WowVision_PetTraining", "WowVision_RestedXP", "WowVision_AtlasLoot", "WowVision_TargetDirection", "WowVision_RollJudge", "WowVision_AuctionHints", "WowVision_Auras" }) do
        scan(extras .. "/" .. name)
    end
    return taken
end

local overrides, spoken, errors

-- One start of the game: the real core afresh, the keys WowVision already has, then this addon's files.
-- savedChar / account: the saved variables present at load; lateAccount: the account's, handed over after load.
local graphOpened, graphClosed
local function boot(savedChar, account, lateAccount, loadedAddons)
    overrides, spoken, errors = {}, {}, {}
    -- nothing of LFG Forever until a test says so
    _G.LFGForeverFrame, _G.LFGForever_ToggleWindow = nil, nil
    local poolCount = 0
    CreateObjectPool = function()
        return {
            Acquire = function()
                poolCount = poolCount + 1
                return newFrame("WowVisionInputManager" .. poolCount)
            end,
            Release = function(_, frame)
                ClearOverrideBindings(frame)
                frame.attributes.type = nil
            end,
        }
    end
    CreateFrame = function(_, name)
        return newFrame(name)
    end
    UIParent = {}
    SetOverrideBindingClick = function(frame, _, key, clickName, button)
        overrides[key] = { frame = frame, key = key, click = clickName, button = button }
    end
    ClearOverrideBindings = function(frame)
        for key, o in pairs(overrides) do
            if o.frame == frame then
                overrides[key] = nil
            end
        end
    end
    InCombatLockdown = function()
        return false
    end
    GetTime = function()
        return 1
    end
    geterrorhandler = function()
        return function(err)
            errors[#errors + 1] = tostring(err)
        end
    end
    SlashCmdList = {}
    C_Timer = nil

    local namespace = {}
    local function load(path)
        local chunk, err = loadfile(wv .. path)
        if chunk == nil then
            error(err)
        end
        return chunk("WowVision", namespace)
    end
    load("core/Class.lua")
    load("core/fieldTypes.lua")
    WowVision = { Class = namespace.Class, NewClass = namespace.Class, classes = namespace.classes }
    function WowVision:getLocale()
        return setmetatable({}, {
            __index = function(_, k)
                return k
            end,
        })
    end
    load("core/Registry.lua")
    load("core/Event.lua")
    load("core/db.lua")
    load("core/ui/input/input.lua")
    load("core/ui/input/padLogic.lua")
    load("core/ui/input/binding.lua")
    load("core/ui/input/bindings.lua")
    -- the real window classes and manager: the window this addon registers is built and polled by them
    load("core/ui/WindowManager.lua")
    load("core/ui/Window.lua")

    WowVisionDB = savedChar or { submodules = {} }
    WowVision.globalDb = account or {}
    WowVision.consts = { UI_DELAY = 0 }
    WowVision.pad = {
        attach = function()
            return {}
        end,
        detach = function() end,
    }
    WowVision.base = {
        speech = { stop = function() end, uiStop = function() end },
        ui = { settings = { menuSounds = false, interruptSpeechOnWindowClose = false } },
    }
    WowVision.loadedAddons = loadedAddons or {}
    -- the graph host: what a window opened by the manager hands its screen to
    graphOpened, graphClosed = {}, {}
    WowVision.graphHost = {
        open = function(_, config)
            graphOpened[#graphOpened + 1] = config
            return { name = "stack" .. #graphOpened }
        end,
        close = function(_, stack)
            graphClosed[#graphClosed + 1] = stack
        end,
    }
    WowVision.UIHost = { windowManager = WowVision.WindowManager:new() }
    WowVision.speak = function(_, text)
        spoken[#spoken + 1] = text
    end
    function WowVision:applyBindingStore(store)
        self.input:setDB(store)
        self.input.bindings:reactivateAll()
    end

    -- the keys already in use, one dummy binding each
    local existing = {}
    for key in pairs(existingKeys()) do
        existing[#existing + 1] = WowVision.input:createBinding({
            type = "Function",
            key = "existing/" .. key,
            label = key,
            inputs = { key },
            func = function() end,
        })
    end
    WowVision:applyBindingStore(WowVision.dbManager:resolveBindings(WowVision.input:getDefaultDB(), WowVisionDB, WowVision.globalDb))
    for _, binding in ipairs(existing) do
        binding:activate()
    end

    local ns = {}
    for _, name in ipairs({ "Locale", "Game", "Labels", "Screen", "Main" }) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_LFGForever", ns)
    end

    if lateAccount ~= nil then
        -- the client hands the account's saved variable over; WowVision binds it again (WowVision:bindGlobalStore)
        WowVision.globalDb = lateAccount
        WowVision:applyBindingStore(WowVision.dbManager:resolveBindings(WowVision.input:getDefaultDB(), WowVisionDB, WowVision.globalDb))
    end
    return ns
end

local function owner(key)
    local o = overrides[key]
    return o ~= nil and o.frame.binding ~= nil and o.frame.binding.key or nil
end

local OPEN = "lfgForever/open"

-- LFG Forever's window as the game would hold it: a frame, shown or not
local function lfgFrame(shown)
    local frame = { shown = shown, hides = 0 }
    function frame:IsShown()
        return self.shown
    end
    function frame:IsVisible()
        return self.shown
    end
    function frame:Hide()
        self.shown = false
        self.hides = self.hides + 1
    end
    function frame:Show()
        self.shown = true
    end
    return frame
end

-- A. a first start: the account store is not there yet (WoW: Forever hands it over late)
local ns = boot(nil, nil, {})
check("A: the addon installed", ns.installed == true)
check("A: no error", #errors == 0, errors[1])
check("A: Alt+Ctrl+G opens LFG Forever", owner("ALT-CTRL-G") == OPEN, owner("ALT-CTRL-G"))
check("A: pressing the key runs a function", (function()
    local o = overrides["ALT-CTRL-G"]
    return o ~= nil and type(o.frame.func) == "function"
end)())
check("A: pressing it with no LFG Forever says so, in French", (function()
    overrides["ALT-CTRL-G"].frame.func()
    return spoken[#spoken] == "LFG Forever n'est pas chargé."
end)(), spoken[#spoken])
check("A: pressing it with LFG Forever installed opens and closes its window", (function()
    local frame = lfgFrame(false)
    local toggled = 0
    _G.LFGForeverFrame = frame
    _G.LFGForever_ToggleWindow = function()
        toggled = toggled + 1
        frame.shown = not frame.shown
    end
    overrides["ALT-CTRL-G"].frame.func()
    local opened = frame.shown
    overrides["ALT-CTRL-G"].frame.func()
    return toggled == 2 and opened and not frame.shown
end)())
check("A: the label is French", WowVision.input:getBinding(OPEN).label == "Ouvrir ou fermer LFG Forever", WowVision.input:getBinding(OPEN).label)
local store = WowVision.dbManager:resolveBindings(WowVision.input:getDefaultDB(), WowVisionDB, WowVision.globalDb)
check("A: the store has an entry for the key", store[OPEN] ~= nil and store[OPEN].inputs[1] == "ALT-CTRL-G")

-- B. the player gave the key another one
local account = {
    _bindingsSeeded = true, -- an account that has been through a start before keeps its own keys
    bindings = { [OPEN] = { inputs = { "CTRL-F6" }, padInputs = {} } },
}
ns = boot(nil, account, nil)
check("B: no error", #errors == 0, errors[1])
check("B: the key is on Ctrl+F6", owner("CTRL-F6") == OPEN, owner("CTRL-F6"))
check("B: Alt+Ctrl+G is free again", owner("ALT-CTRL-G") == nil, owner("ALT-CTRL-G"))

-- C. the same, with the account's keys handed over late
ns = boot(nil, nil, account)
check("C: no error", #errors == 0, errors[1])
check("C: the key is on Ctrl+F6", owner("CTRL-F6") == OPEN, owner("CTRL-F6"))
check("C: Alt+Ctrl+G is free again", owner("ALT-CTRL-G") == nil, owner("ALT-CTRL-G"))

-- D. the player took the key away altogether: it has none, and nothing else takes it
account = { _bindingsSeeded = true, bindings = { [OPEN] = { inputs = {}, padInputs = {} } } }
ns = boot(nil, account, nil)
check("D: no key, no error", owner("ALT-CTRL-G") == nil and #errors == 0, errors[1])

-- E. no key of this addon is on a key WowVision or the other extensions already have
ns = boot(nil, nil, {})
local taken = existingKeys()
local clashes = {}
for _, info in ipairs(ns.bindings) do
    for _, key in ipairs(info.inputs) do
        if taken[key] ~= nil then
            clashes[#clashes + 1] = key .. " (" .. taken[key] .. ")"
        end
    end
end
check("E: no clash with the keys already in use", #clashes == 0, table.concat(clashes, ", "))
local count = 0
for _ in pairs(taken) do
    count = count + 1
end
check("E: the keys in use were read (" .. count .. ")", count > 30)
check("E: the keys of the buffers, Alt+arrows, are not touched", taken["ALT-LEFT"] ~= nil and taken["ALT-DOWN"] ~= nil)

-- F. the window, on WowVision's real window classes and manager
ns = boot(nil, nil, {})
local manager = WowVision.UIHost.windowManager
local window = manager:getWindow("lfgForever")
check("F: the window is registered", window ~= nil)
check("F: it is a frame window on LFG Forever's frame", window ~= nil and window.frameName == "LFGForeverFrame" and window.class ~= nil and window:needsPolling() == true)
check("F: it is polled with the other automatic windows", (function()
    for _, auto in ipairs(manager.autoWindows) do
        if auto == window then
            return true
        end
    end
    return false
end)())
manager:update()
check("F: LFG Forever not built yet: nothing opens", #graphOpened == 0 and #errors == 0, errors[1])
local frame = lfgFrame(false)
_G.LFGForeverFrame = frame
manager:update()
check("F: its window built but closed: nothing opens", #graphOpened == 0)
frame.shown = true
manager:update()
check("F: LFG Forever's window shown: WowVision opens its screen", #graphOpened == 1 and graphOpened[1].key == "lfgForever" and type(graphOpened[1].render) == "function", #graphOpened)
check("F: and only once while it stays open", (function()
    manager:update()
    manager:update()
    return #graphOpened == 1
end)())
check("F: Escape from the screen hides LFG Forever's window", (function()
    graphOpened[1].onRequestClose()
    return frame.hides == 1 and frame.shown == false
end)())
manager:update()
check("F: the window closed: WowVision closes its screen", #graphClosed == 1 and graphClosed[1].name == "stack1", #graphClosed)
frame.shown = true
manager:update()
check("F: opened again, a new screen", #graphOpened == 2)
check("F: no error in all that", #errors == 0, errors[1])

-- G. Sku has its own windows: left alone, as everywhere in WowVision
ns = boot(nil, nil, {}, { Sku = true })
manager = WowVision.UIHost.windowManager
_G.LFGForeverFrame = lfgFrame(true)
manager:update()
check("G: with Sku loaded the window does not open", #graphOpened == 0 and manager:getWindow("lfgForever"):canOpen() == false)

print(failures == 0 and "all ok" or (failures .. " failure(s)"))
os.exit(failures == 0 and 0 or 1)
