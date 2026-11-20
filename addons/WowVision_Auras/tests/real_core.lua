-- Runs this addon's keys (Alt+Ctrl+B and Alt+Shift+B) against WowVision's REAL class system, registry, input manager, binding types and db
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
    for _, name in ipairs({ "WowVision_Bags", "WowVision_QuestTargets", "WowVision_Quests", "WowVision_ItemCompare", "WowVision_LocalizedNames", "WowVision_PetTraining", "WowVision_RestedXP", "WowVision_AtlasLoot", "WowVision_TargetDirection", "WowVision_RollJudge", "WowVision_AuctionHints" }) do
        scan(extras .. "/" .. name)
    end
    return taken
end

local overrides, spoken, errors

-- One start of the game: the real core afresh, the keys WowVision already has, then this addon's files.
-- savedChar / account: the saved variables present at load; lateAccount: the account's, handed over after load.
local function boot(savedChar, account, lateAccount)
    overrides, spoken, errors = {}, {}, {}
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

    WowVisionDB = savedChar or { submodules = {} }
    WowVision.globalDb = account or {}
    WowVision.consts = { UI_DELAY = 0 }
    WowVision.pad = {
        attach = function()
            return {}
        end,
        detach = function() end,
    }
    WowVision.base = { speech = { stop = function() end } }
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
    for _, name in ipairs({ "Locale", "Game", "Auras", "Screen", "Main" }) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_Auras", ns)
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

local SAY, OPEN = "auras/say", "auras/open"

-- A. a first start: the account store is not there yet (WoW: Forever hands it over late)
local ns = boot(nil, nil, {})
check("A: the addon installed", ns.installed == true)
check("A: no error", #errors == 0, errors[1])
check("A: Alt+Ctrl+B says them all", owner("ALT-CTRL-B") == SAY, owner("ALT-CTRL-B"))
check("A: Alt+Shift+B opens the list", owner("ALT-SHIFT-B") == OPEN, owner("ALT-SHIFT-B"))
check("A: pressing a key runs a function", (function()
    local o = overrides["ALT-CTRL-B"]
    return o ~= nil and type(o.frame.func) == "function"
end)())
check("A: pressing it with no Aura buffer in WowVision says so, in French", (function()
    overrides["ALT-CTRL-B"].frame.func()
    return spoken[#spoken] == "Les auras ne sont pas disponibles."
end)(), spoken[#spoken])
check("A: the labels are French", WowVision.input:getBinding(SAY).label == "Dire les améliorations et affaiblissements du joueur" and WowVision.input:getBinding(OPEN).label == "Ouvrir la liste des améliorations et affaiblissements du joueur", WowVision.input:getBinding(SAY).label)
local store = WowVision.dbManager:resolveBindings(WowVision.input:getDefaultDB(), WowVisionDB, WowVision.globalDb)
check("A: the store has an entry for each key", store[SAY] ~= nil and store[SAY].inputs[1] == "ALT-CTRL-B" and store[OPEN] ~= nil and store[OPEN].inputs[1] == "ALT-SHIFT-B")

-- B. the player gave the list another key
local account = {
    _bindingsSeeded = true, -- an account that has been through a start before keeps its own keys
    bindings = { [OPEN] = { inputs = { "CTRL-F6" }, padInputs = {} } },
}
ns = boot(nil, account, nil)
check("B: no error", #errors == 0, errors[1])
check("B: the list is on Ctrl+F6", owner("CTRL-F6") == OPEN, owner("CTRL-F6"))
check("B: Alt+Shift+B is free again", owner("ALT-SHIFT-B") == nil, owner("ALT-SHIFT-B"))
check("B: the other key keeps Alt+Ctrl+B", owner("ALT-CTRL-B") == SAY, owner("ALT-CTRL-B"))

-- C. the same, with the account's keys handed over late
ns = boot(nil, nil, account)
check("C: no error", #errors == 0, errors[1])
check("C: the list is on Ctrl+F6", owner("CTRL-F6") == OPEN, owner("CTRL-F6"))
check("C: Alt+Shift+B is free again", owner("ALT-SHIFT-B") == nil, owner("ALT-SHIFT-B"))

-- D. the player swapped the two keys
account = {
    _bindingsSeeded = true,
    bindings = {
        [SAY] = { inputs = { "ALT-SHIFT-B" }, padInputs = {} },
        [OPEN] = { inputs = { "ALT-CTRL-B" }, padInputs = {} },
    },
}
ns = boot(nil, account, nil)
check("D: no error", #errors == 0, errors[1])
check("D: the keys are swapped", owner("ALT-SHIFT-B") == SAY and owner("ALT-CTRL-B") == OPEN, tostring(owner("ALT-SHIFT-B")) .. " " .. tostring(owner("ALT-CTRL-B")))

-- E. the player took a key away altogether: it has none, and nothing else takes it
account = { _bindingsSeeded = true, bindings = { [SAY] = { inputs = {}, padInputs = {} } } }
ns = boot(nil, account, nil)
check("E: no key, no error", owner("ALT-CTRL-B") == nil and #errors == 0, errors[1])
check("E: the other key is unchanged", owner("ALT-SHIFT-B") == OPEN, owner("ALT-SHIFT-B"))

ns = boot(nil, nil, {})
-- F. no key of this addon is on a key WowVision or the other extensions already have
local taken = existingKeys()
local clashes = {}
for _, info in ipairs(ns.bindings) do
    for _, key in ipairs(info.inputs) do
        if taken[key] ~= nil then
            clashes[#clashes + 1] = key .. " (" .. taken[key] .. ")"
        end
    end
end
check("F: no clash with the keys already in use", #clashes == 0, table.concat(clashes, ", "))
local count = 0
for _ in pairs(taken) do
    count = count + 1
end
check("F: the keys in use were read (" .. count .. ")", count > 30)
check("F: the keys of the buffers, Alt+arrows, are not touched", taken["ALT-LEFT"] ~= nil and taken["ALT-DOWN"] ~= nil)

print(failures == 0 and "all ok" or (failures .. " failure(s)"))
os.exit(failures == 0 and 0 or 1)
