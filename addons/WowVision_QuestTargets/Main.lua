-- Glue: the two secure buttons the keys click, the keys themselves (WowVision's Bindings screen lists them), and
-- the /wvqt command.
--
-- Targeting a creature is a protected action, so a key cannot simply call TargetUnit. A secure button of type
-- "target" does it, with the creature it aims at in its "unit" attribute. That attribute can only be written out of
-- combat, so the button's PreClick (which runs just before the secure action, on every click) picks the creature
-- and writes it, and the game's own targeting then happens. WowVision's key bindings click such buttons the same
-- way for its virtual focus.
local _, ns = ...
local L = ns.L
local Targets = ns.Targets

local reported = {}

-- An error here must never break the keys, and must not repeat on every press either: report each distinct
-- message once.
local function report(err)
    err = tostring(err)
    if reported[err] then
        return
    end
    reported[err] = true
    geterrorhandler()("WowVision_QuestTargets: " .. err)
end
ns.report = report

-- ---------------------------------------------------------------- settings

local DEFAULTS = { autoPlates = true }

-- Read through the global every time: the client can hand over an account-wide saved variable after the addon's
-- loaded event and replace the table, so a reference cached at load could go stale.
function ns.getSetting(key)
    local db = rawget(_G, "WowVisionQuestTargetsDB")
    if type(db) == "table" and db[key] ~= nil then
        return db[key]
    end
    return DEFAULTS[key]
end

function ns.setSetting(key, value)
    local db = rawget(_G, "WowVisionQuestTargetsDB")
    if type(db) ~= "table" then
        db = {}
        _G.WowVisionQuestTargetsDB = db
    end
    db[key] = value
end

local function speak(text)
    if WowVision ~= nil and WowVision.speak ~= nil then
        WowVision:speak(text)
    else
        print(text)
    end
end

local function plain(value)
    return value ~= nil and not (WowVision ~= nil and WowVision.isSecret ~= nil and WowVision.isSecret(value))
end

local function isTarget(unit)
    local ok, same = pcall(UnitIsUnit, unit, "target")
    return ok and plain(same) and same == true
end

-- ---------------------------------------------------------------- looking

function ns.lookup()
    return Targets.collect(ns.Game.api())
end

-- Why there is nothing to target, in a sentence.
function ns.nothingText(secretSkipped)
    if not ns.Game.canTell() then
        return L["This game version cannot tell which creatures belong to your quests."]
    end
    if secretSkipped > 0 then
        return L["The game hides quest targets in combat."]
    end
    if not ns.Game.platesShown() then
        return L["Enemy nameplates are off, so nearby enemies cannot be found. Type /wvqt plates to turn them on."]
    end
    return L["No quest target nearby."]
end

-- Says why there is nothing to target. When the reason is that the game shows no enemy nameplates (the only way to
-- see the creatures around), they are turned on here, once, out of combat, and the player is told: they would only
-- have to do it by hand otherwise.
function ns.reportNothing(secretSkipped)
    if
        ns.Game.canTell()
        and secretSkipped == 0
        and not ns.Game.platesShown()
        and not InCombatLockdown()
        and ns.getSetting("autoPlates") ~= false
        and ns.Game.showPlates()
    then
        speak(L["Enemy nameplates were off: I turned them on to find the enemies near you. Press again."])
        return
    end
    speak(ns.nothingText(secretSkipped))
end

-- Every creature around with the reason it was kept or left out, and what in the game stops the addon from seeing
-- them. Only reads: it changes nothing, not even the nameplate setting.
function ns.review()
    local api = ns.Game.api()
    local verdicts = Targets.review(api)
    return verdicts,
        {
            platesShown = ns.Game.platesShown(),
            combat = InCombatLockdown() == true,
            hasRelated = api.related ~= nil,
            hasLines = api.lines ~= nil,
        }
end

function ns.sayWhy()
    local ok, verdicts, context = pcall(ns.review)
    if not ok then
        report(verdicts)
        return
    end
    speak(Targets.diagnosisText(verdicts, context))
end

function ns.sayList()
    local ok, candidates, secretSkipped = pcall(ns.lookup)
    if not ok then
        report(candidates)
        return
    end
    if #candidates == 0 then
        ns.reportNothing(secretSkipped)
        return
    end
    speak(Targets.listText(candidates))
end

-- ---------------------------------------------------------------- targeting

-- The position of the creature just aimed at, said once the game has changed the target to it.
local pending = nil

-- Runs just before a button's secure targeting action: picks the creature and aims the button at it. direction is
-- 1 for the next creature and -1 for the previous one. Returns the unit token it aimed at, or nil.
function ns.prepare(button, direction)
    pending = nil
    if InCombatLockdown() then
        -- The attribute cannot be written now: whatever it held before the fight is all the button can do.
        speak(L["Quest targets cannot be picked in combat."])
        return nil
    end
    button:SetAttribute("unit", nil)
    local ok, candidates, secretSkipped = pcall(ns.lookup)
    if not ok then
        report(candidates)
        return nil
    end
    local index, count = Targets.choose(candidates, direction, isTarget)
    if index == nil then
        ns.reportNothing(secretSkipped)
        return nil
    end
    local unit = candidates[index].unit
    button:SetAttribute("unit", unit)
    if count > 1 then
        pending = { index = index, count = count, time = GetTime() }
    end
    return unit
end

local function makeButton(name, direction)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    button:SetAttribute("type", "target")
    -- The Click binding forwards one up/complete click; pin the action to key-up so that it is not dropped when the
    -- game casts on key down (the same as WowVision's virtual focus buttons).
    button:SetAttribute("useOnKeyDown", false)
    button:SetScript("PreClick", function()
        local ok, err = pcall(ns.prepare, button, direction)
        if not ok then
            report(err)
        end
    end)
    button:SetScript("PostClick", function()
        if not InCombatLockdown() then
            button:SetAttribute("unit", nil)
        end
    end)
    return button
end

-- ------------------------------------------------------------------- keys

ns.bindings = {
    {
        type = "Click",
        key = "questTarget/next",
        label = "Target Next Quest Target",
        inputs = { "ALT-Q" },
        emulatedKey = "LeftButton",
        button = "next",
    },
    {
        type = "Click",
        key = "questTarget/previous",
        label = "Target Previous Quest Target",
        inputs = { "ALT-SHIFT-Q" },
        emulatedKey = "LeftButton",
        button = "previous",
    },
    {
        type = "Function",
        key = "questTarget/list",
        label = "Say Quest Targets Nearby",
        inputs = { "ALT-CTRL-Q" },
        interruptSpeech = true,
        func = function()
            ns.sayList()
        end,
    },
}

-- The keys are bindings like WowVision's own: listed, and changeable, in the Bindings screen (/wv, Interface,
-- Bindings). WowVision keeps every binding in one registry that the screen reads and stores the player's keys by
-- the binding's key, so a binding added now is picked up like the ones it loaded with. A binding is switched on
-- once the stores have told it the player's keys.
function ns.installBindings()
    local input = WowVision ~= nil and WowVision.input or nil
    if input == nil or type(input.createBinding) ~= "function" or type(input.getBinding) ~= "function" then
        return false
    end
    local created = {}
    for _, info in ipairs(ns.bindings) do
        if input:getBinding(info.key) == nil then
            local copy = {}
            for key, value in pairs(info) do
                copy[key] = value
            end
            copy.label = L[info.label]
            copy.button = nil
            if info.button == "next" then
                copy.targetFrame = ns.nextButton
            elseif info.button == "previous" then
                copy.targetFrame = ns.previousButton
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

local PLATES = { plates = true, plaques = true, plaketten = true }
local WHY = { why = true, pourquoi = true, warum = true, diagnostic = true, diagnose = true }
local AUTO = { auto = true, automatique = true, automatisch = true }
local ON = { on = true, ["1"] = true, oui = true, yes = true, ja = true, an = true }
local OFF = { off = true, ["0"] = true, non = true, no = true, nein = true, aus = true }

function ns.handleCommand(message)
    local word, value = (message or ""):lower():match("^%s*(%S*)%s*(%S*)")
    if AUTO[word or ""] then
        if ON[value or ""] then
            ns.setSetting("autoPlates", true)
        elseif OFF[value or ""] then
            ns.setSetting("autoPlates", false)
        end
        local enabled = ns.getSetting("autoPlates") ~= false
        speak(string.format(L["%s: %s"], L["Turning on enemy nameplates by itself"], enabled and L["on"] or L["off"]))
        return
    end
    if WHY[word or ""] then
        ns.sayWhy()
        return
    end
    if PLATES[word or ""] then
        if ns.Game.showPlates() then
            speak(L["Enemy nameplates turned on."])
        else
            speak(L["Enemy nameplates could not be turned on."])
        end
        return
    end
    if word ~= nil and word ~= "" and word ~= "list" and word ~= "liste" then
        speak(
            L["Quest targets: /wvqt says the ones near you, /wvqt why says what it sees and why, /wvqt plates turns on enemy nameplates."]
        )
        return
    end
    ns.sayList()
end

if SlashCmdList ~= nil then
    SLASH_WVQUESTTARGETS1 = "/wvqt"
    SLASH_WVQUESTTARGETS2 = "/wvquesttargets"
    SlashCmdList["WVQUESTTARGETS"] = ns.handleCommand
end

-- ---------------------------------------------------------------- start

-- Once the game has changed the target to the creature a key aimed at, say its place in the list.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function()
    local waiting = pending
    pending = nil
    if waiting ~= nil and GetTime() - waiting.time < 1 and UnitExists("target") then
        speak(string.format(L["%d of %d"], waiting.index, waiting.count))
    end
end)

local function install()
    if WowVision == nil or WowVision.input == nil then
        return false
    end
    ns.nextButton = makeButton("WowVisionQuestTargetsNext", 1)
    ns.previousButton = makeButton("WowVisionQuestTargetsPrevious", -1)
    local ok, installed = pcall(ns.installBindings)
    if not ok then
        report(installed)
        return false
    end
    return installed
end

ns.installed = install()
