-- Runs this addon's keys against WowVision's REAL class system, registry, input manager, binding types and db
-- manager (the code that decides which key goes to which binding and what the player's saved keys do), with the
-- keys WowVision and the other extensions already use registered as bindings of their own. Usage, from the addon
-- folder: lua tests/real_core.lua   (prints "all ok" when every check passes).
local script = arg and arg[0] or "tests/real_core.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local wv = addonDir .. "/../WowVision/"

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
    local extras = addonDir .. "/.."
    for _, name in ipairs({ "WowVision_Bags", "WowVision_QuestTargets", "WowVision_Quests", "WowVision_ItemCompare", "WowVision_LocalizedNames", "WowVision_PetTraining", "WowVision_RestedXP", "WowVision_AtlasLoot", "WowVision_TargetDirection" }) do
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
    for _, name in ipairs({ "Locale", "Judge", "Main" }) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_RollJudge", ns)
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

local KEY, KEY_ALL = "rolljudge/verdict", "rolljudge/all"

-- A. a first start: the account store is not there yet (WoW: Forever hands it over late)
local ns = boot(nil, nil, {})
check("A: the addon installed", ns.installed == true)
check("A: no error", #errors == 0, errors[1])
check("A: Alt+Ctrl+J is the verdict key", owner("ALT-CTRL-J") == KEY, owner("ALT-CTRL-J"))
check("A: the other key has no key of its own", (function()
    for key, o in pairs(overrides) do
        if o.frame.binding ~= nil and o.frame.binding.key == KEY_ALL then
            return false
        end
    end
    return true
end)())
check("A: pressing it runs a function", (function()
    local o = overrides["ALT-CTRL-J"]
    return o ~= nil and type(o.frame.func) == "function"
end)())
check("A: pressing it with no roll window says so, in French", (function()
    overrides["ALT-CTRL-J"].frame.func()
    return spoken[#spoken] == "Pas de butin."
end)(), spoken[#spoken])
check("A: the label is French", WowVision.input:getBinding(KEY).label == "Avis de Gear Judge sur l'objet proposé au jet", WowVision.input:getBinding(KEY).label)
local store = WowVision.dbManager:resolveBindings(WowVision.input:getDefaultDB(), WowVisionDB, WowVision.globalDb)
check("A: the store has an entry for the key", store[KEY] ~= nil and store[KEY].inputs[1] == "ALT-CTRL-J")
check("A: and one for the key that has none", store[KEY_ALL] ~= nil and #store[KEY_ALL].inputs == 0)

-- B. the player moved WowVision's "Open Target Menu" (Alt+T) to another key and gave Alt+T to the verdict key
local account = {
    _bindingsSeeded = true, -- an account that has been through a start before keeps its own keys
    bindings = {
        ["existing/ALT-T"] = { inputs = { "ALT-SHIFT-F9" }, padInputs = {} },
        [KEY] = { inputs = { "ALT-T" }, padInputs = {} },
    },
}
ns = boot(nil, account, nil)
check("B: no error", #errors == 0, errors[1])
check("B: Alt+T is the verdict key", owner("ALT-T") == KEY, owner("ALT-T"))
check("B: the target menu is on its new key", owner("ALT-SHIFT-F9") == "existing/ALT-T", owner("ALT-SHIFT-F9"))
check("B: Alt+Ctrl+J is free again", owner("ALT-CTRL-J") == nil, owner("ALT-CTRL-J"))

-- C. the same, with the account's keys handed over late
ns = boot(nil, nil, account)
check("C: no error", #errors == 0, errors[1])
check("C: Alt+T is the verdict key", owner("ALT-T") == KEY, owner("ALT-T"))
check("C: Alt+Ctrl+J is free again", owner("ALT-CTRL-J") == nil, owner("ALT-CTRL-J"))

-- D. the player gave the second key a key of its own
account = {
    _bindingsSeeded = true,
    bindings = { [KEY_ALL] = { inputs = { "CTRL-F6" }, padInputs = {} } },
}
ns = boot(nil, account, nil)
check("D: no error", #errors == 0, errors[1])
check("D: the key is on Ctrl+F6", owner("CTRL-F6") == KEY_ALL, owner("CTRL-F6"))
check("D: the verdict key keeps Alt+Ctrl+J", owner("ALT-CTRL-J") == KEY, owner("ALT-CTRL-J"))
check("D: pressing it says there is no loot", (function()
    overrides["CTRL-F6"].frame.func()
    return spoken[#spoken] == "Pas de butin."
end)(), spoken[#spoken])

-- E. the player took the verdict key away altogether: it has none, and nothing else takes it
account = { _bindingsSeeded = true, bindings = { [KEY] = { inputs = {}, padInputs = {} } } }
ns = boot(nil, account, nil)
check("E: no key, no error", owner("ALT-CTRL-J") == nil and #errors == 0, errors[1])

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
check("F: Alt+T is WowVision's own (the reason it is not the default)", taken["ALT-T"] ~= nil and taken["ALT-T"]:find("unitMenus", 1, true) ~= nil, taken["ALT-T"])
local count = 0
for _ in pairs(taken) do
    count = count + 1
end
check("F: the keys in use were read (" .. count .. ")", count > 30)

print(failures == 0 and "all ok" or (failures .. " failure(s)"))
os.exit(failures == 0 and 0 or 1)
