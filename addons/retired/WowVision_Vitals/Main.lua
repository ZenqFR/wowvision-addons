-- Glue: the two keys, the /wvvitals command, and the one change this addon makes to WowVision's own keys.
--
-- Alt+Left and Alt+Right are WowVision's "previous buffer" and "next buffer" keys. WowVision lets a key do only one
-- thing, so before this addon's keys can have them, those two move to Alt+Shift+Left and Alt+Shift+Right, the way
-- the player would move them in the Bindings screen (/wv, Interface, Bindings). That happens once: the first time
-- this addon's keys are not yet in the player's saved keys. After that the saved keys decide, so a player who gives
-- Alt+Left back to the buffers in the Bindings screen keeps it.
local _, ns = ...
local L = ns.L
local Vitals = ns.Vitals

local reported = {}

-- An error here must never break the keys, and must not repeat on every press either: report each distinct
-- message once.
local function report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_Vitals: " .. err)
end
ns.report = report

local function speak(text)
    if WowVision ~= nil and WowVision.speak ~= nil then
        WowVision:speak(text)
    else
        print(text)
    end
end

-- ------------------------------------------------------------------ saying

-- which is "health", "power" or nothing (both).
function ns.say(which)
    local ok, text = pcall(function()
        local api = ns.Game.api()
        if which == "health" then
            return Vitals.healthText(api)
        elseif which == "power" then
            return Vitals.powerText(api)
        end
        return Vitals.bothText(api)
    end)
    if not ok then
        report(text)
        text = L["Nothing to read."]
    end
    speak(text)
end

-- ------------------------------------------------------------------- keys

ns.bindings = {
    {
        type = "Function",
        key = "vitals/health",
        label = "Say Health Percent",
        inputs = { "ALT-LEFT" },
        interruptSpeech = true,
        func = function()
            ns.say("health")
        end,
    },
    {
        type = "Function",
        key = "vitals/power",
        label = "Say Power Percent",
        inputs = { "ALT-RIGHT" },
        interruptSpeech = true,
        func = function()
            ns.say("power")
        end,
    },
}

-- The keys of WowVision's own buffer navigation that this addon's keys take, and where those go.
ns.relocations = {
    ["ALT-LEFT"] = { holder = "buffers/previousBuffer", to = "ALT-SHIFT-LEFT" },
    ["ALT-RIGHT"] = { holder = "buffers/nextBuffer", to = "ALT-SHIFT-RIGHT" },
}

-- The binding that has this key (leaving out one binding), or nil.
local function holderOf(input, key, except)
    for _, binding in ipairs(input.bindings.orderedBindings) do
        if binding ~= except then
            for _, bound in ipairs(binding.inputs or {}) do
                if bound == key then
                    return binding
                end
            end
        end
    end
    return nil
end

-- The store of keys the player's keys are saved in: the character's own when the character chose that, the
-- account's otherwise.
local function activeStore()
    local charDB = rawget(_G, "WowVisionDB")
    if type(charDB) == "table" and charDB.bindingScope == "char" then
        return charDB.bindings
    end
    local globalDB = WowVision ~= nil and WowVision.globalDb or nil
    if type(globalDB) == "table" then
        return globalDB.bindings
    end
    return nil
end

-- Makes a key free for one of this addon's bindings. Returns whether it can have it. A key that WowVision's buffer
-- navigation holds moves aside, but only on the first time (see the top of the file) and only when the place it
-- moves to is free.
local function claim(input, key, firstTime)
    local holder = holderOf(input, key)
    if holder == nil then
        return true
    end
    local move = ns.relocations[key]
    if firstTime and move ~= nil and holder.key == move.holder and holderOf(input, move.to) == nil then
        holder:removeInput(key)
        holder:addInput(move.to)
        return true
    end
    return false
end

-- Two bindings on one key. The Bindings screen never lets that happen, but a store of keys handed over to WowVision
-- can: WoW: Forever delivers the account's saved keys after the addons have loaded, and WowVision then binds that
-- store, in which the buffer navigation still has Alt+Left and Alt+Right and this addon's keys are filled in from
-- their defaults. Whenever one of this addon's keys finds the buffer navigation on the same key, the buffer
-- navigation moves aside, as it did the first time. Nothing else is touched, and a player's own choice (a key given
-- back to the buffers in the Bindings screen) is never a duplicate, because that screen takes it off this addon's key.
function ns.repairConflicts()
    local input = WowVision ~= nil and WowVision.input or nil
    if input == nil or input.bindings == nil then
        return false
    end
    local moved = false
    for _, info in ipairs(ns.bindings) do
        local ours = input:getBinding(info.key)
        if ours ~= nil then
            local keys = {}
            for _, key in ipairs(ours.inputs or {}) do
                tinsert(keys, key)
            end
            for _, key in ipairs(keys) do
                local holder = holderOf(input, key, ours)
                if holder ~= nil then
                    local move = ns.relocations[key]
                    if move ~= nil and holder.key == move.holder and holderOf(input, move.to) == nil then
                        holder:removeInput(key)
                        holder:addInput(move.to)
                        moved = true
                    else
                        report(
                            (holder:getLabel() or holder.key)
                                .. " and "
                                .. (ours:getLabel() or ours.key)
                                .. " both have "
                                .. key
                                .. ": remove it from one of them in the Bindings screen."
                        )
                    end
                end
            end
        end
    end
    if moved then
        input.bindings:reactivateAll()
        if WowVision.graphHost ~= nil and WowVision.graphHost.refreshBindings ~= nil then
            WowVision.graphHost:refreshBindings()
        end
    end
    return moved
end

-- Runs the repair after every time WowVision binds a store of keys. WowVision looks the function up on itself at
-- each call, so a wrapper in its place is used by all of them.
function ns.watchStores()
    if ns.storesWatched or WowVision == nil or type(WowVision.applyBindingStore) ~= "function" then
        return false
    end
    local original = WowVision.applyBindingStore
    WowVision.applyBindingStore = function(self, ...)
        local result = original(self, ...)
        local ok, err = pcall(ns.repairConflicts)
        if not ok then
            report(err)
        end
        return result
    end
    ns.storesWatched = true
    return true
end

-- The keys are bindings like WowVision's own: listed, and changeable, in the Bindings screen. WowVision keeps every
-- binding in one registry that the screen reads and stores the player's keys by the binding's key, so a binding
-- added now is picked up like the ones it loaded with. A binding is switched on once the stores have told it the
-- player's keys.
function ns.installBindings()
    local input = WowVision ~= nil and WowVision.input or nil
    if
        input == nil
        or type(input.createBinding) ~= "function"
        or type(input.getBinding) ~= "function"
        or input.bindings == nil
    then
        return false
    end
    local store = activeStore()
    local created = {}
    for _, info in ipairs(ns.bindings) do
        if input:getBinding(info.key) == nil then
            -- Without a store to save the move in, nothing is moved: it would come back at the next start.
            local firstTime = store ~= nil and store[info.key] == nil
            local copy = {}
            for key, value in pairs(info) do
                copy[key] = value
            end
            copy.label = L[info.label]
            copy.inputs = {}
            for _, key in ipairs(info.inputs) do
                if claim(input, key, firstTime) then
                    tinsert(copy.inputs, key)
                elseif store == nil or firstTime then
                    -- Not when the player's saved keys decided it: giving a key back to the buffers is a choice,
                    -- not a problem.
                    local holder = holderOf(input, key)
                    report(
                        (holder ~= nil and holder:getLabel() or "another binding")
                            .. " already has "
                            .. key
                            .. ": add a key to '"
                            .. copy.label
                            .. "' in the Bindings screen."
                    )
                end
            end
            tinsert(created, input:createBinding(copy))
        end
    end
    if #created > 0 then
        local resolved = WowVision.dbManager:resolveBindings(input:getDefaultDB(), WowVisionDB, WowVision.globalDb)
        WowVision:applyBindingStore(resolved)
        for _, binding in ipairs(created) do
            binding:activate()
        end
    end
    return true
end

-- ---------------------------------------------------------------- command

if SlashCmdList ~= nil then
    SLASH_WVVITALS1 = "/wvvitals"
    SLASH_WVVITALS2 = "/wvvie"
    SlashCmdList["WVVITALS"] = function()
        ns.say()
    end
end

-- ---------------------------------------------------------------- start

local function install()
    local watched, watchError = pcall(ns.watchStores)
    if not watched then
        report(watchError)
    end
    local ok, installed = pcall(ns.installBindings)
    if not ok then
        report(installed)
        return false
    end
    return installed
end

ns.installed = install()
