-- /wvprobe [FrameName]
--
-- Writes what the game holds about the windows that are open, as text lines in
-- WowVisionProbeDB.lines (saved to disk by /reload or logout):
--   * the game build and locale, the Blizzard UI addons that are loaded, and
--     which of a list of API functions exist (what a window could be driven by);
--   * every frame shown straight under UIParent, one line each;
--   * the whole tree (children, texts, buttons, named parts, lists with the data
--     of their rows) of the frames that look like a training or crafting window,
--     or of the frame named on the command line.
--
-- It reads and never writes to the game: no clicks, no scripts run, nothing the
-- game's own windows could be tainted by. Every call that could fail or hand
-- back a secret value is guarded.
-- What it says out loud, in the game's language (the dump it writes is a technical record and stays English).
-- The keys are the English sentences, so a language with no table here reads English. French is the author's own
-- wording; German is a translation by the author and has not been checked by a native speaker.
local MESSAGES = {
    frFR = {
        ["Probe done: %d lines, 1 window dumped. Type slash reload to save it."] = "Relevé terminé : %d lignes, 1 fenêtre relevée. Tapez slash reload pour l'enregistrer.",
        ["Probe done: %d lines, %d windows dumped. Type slash reload to save it."] = "Relevé terminé : %d lignes, %d fenêtres relevées. Tapez slash reload pour l'enregistrer.",
        ["Probe watch done: 1 window captured, %d lines. Type slash reload to save it."] = "Surveillance terminée : 1 fenêtre relevée, %d lignes. Tapez slash reload pour l'enregistrer.",
        ["Probe watch done: %d windows captured, %d lines. Type slash reload to save it."] = "Surveillance terminée : %d fenêtres relevées, %d lignes. Tapez slash reload pour l'enregistrer.",
        ["Probe captured window %d"] = "Fenêtre %d relevée",
        ["Probe watching for %d seconds. Open the window now."] = "Surveillance pendant %d secondes. Ouvrez la fenêtre maintenant.",
    },
    deDE = {
        ["Probe done: %d lines, 1 window dumped. Type slash reload to save it."] = "Aufnahme fertig: %d Zeilen, 1 Fenster aufgenommen. Gib slash reload ein, um sie zu speichern.",
        ["Probe done: %d lines, %d windows dumped. Type slash reload to save it."] = "Aufnahme fertig: %d Zeilen, %d Fenster aufgenommen. Gib slash reload ein, um sie zu speichern.",
        ["Probe watch done: 1 window captured, %d lines. Type slash reload to save it."] = "Beobachtung beendet: 1 Fenster erfasst, %d Zeilen. Gib slash reload ein, um sie zu speichern.",
        ["Probe watch done: %d windows captured, %d lines. Type slash reload to save it."] = "Beobachtung beendet: %d Fenster erfasst, %d Zeilen. Gib slash reload ein, um sie zu speichern.",
        ["Probe captured window %d"] = "Fenster %d erfasst",
        ["Probe watching for %d seconds. Open the window now."] = "Beobachtung für %d Sekunden. Öffne das Fenster jetzt.",
    },
}

local function T(key, ...)
    local locale = GetLocale ~= nil and GetLocale() or "enUS"
    local table = MESSAGES[locale]
    local text = table ~= nil and table[key] or key
    return string.format(text, ...)
end
WowVisionProbeMessages = MESSAGES

local MAX_LINES = 4000
local MAX_DEPTH = 8
local MAX_CHILDREN = 60
local MAX_ROWS = 12

local lines

local function out(text)
    if #lines < MAX_LINES then
        lines[#lines + 1] = text
    elseif #lines == MAX_LINES then
        lines[#lines + 1] = "... output cut at " .. MAX_LINES .. " lines"
    end
end

local function secret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- A value as one short, safe string.
local function show(value, limit)
    limit = limit or 120
    if secret(value) then
        return "<secret>"
    end
    local kind = type(value)
    if kind == "string" then
        local text = value:gsub("[\r\n]", " ")
        if #text > limit then
            text = text:sub(1, limit) .. "..."
        end
        return '"' .. text .. '"'
    elseif kind == "number" or kind == "boolean" or kind == "nil" then
        return tostring(value)
    elseif kind == "table" then
        if value.GetObjectType ~= nil then
            local ok, objectType = pcall(value.GetObjectType, value)
            local name = nil
            if value.GetName ~= nil then
                local okName, got = pcall(value.GetName, value)
                name = okName and got or nil
            end
            return "<" .. (ok and tostring(objectType) or "frame") .. (name and (" " .. name) or "") .. ">"
        end
        return "<table>"
    end
    return "<" .. kind .. ">"
end

local function call(object, method, ...)
    if object == nil or object[method] == nil then
        return nil
    end
    local ok, a, b, c, d, e = pcall(object[method], object, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e
end

local isFrame

-- Every value a method returns (GetChildren and GetRegions return one per
-- child; `call` below stops at five).
local function callAll(object, method, ...)
    if object == nil or object[method] == nil then
        return {}
    end
    local results = { pcall(object[method], object, ...) }
    if not table.remove(results, 1) then
        return {}
    end
    return results
end

local function callGlobal(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e
end

function isFrame(value)
    return type(value) == "table" and value.GetObjectType ~= nil and value.GetChildren ~= nil
end

-- ------------------------------------------------------------------ one frame

-- The row data of a list (a ScrollBox's data provider): its size and the first
-- rows, each a flat table of its simple fields.
local function describeProvider(indent, provider)
    local size = call(provider, "GetSize")
    out(indent .. "  data provider: size " .. show(size))
    if provider.Find == nil then
        return
    end
    for index = 1, math.min(tonumber(size) or 0, MAX_ROWS) do
        local row = call(provider, "Find", index)
        local data = row
        if type(row) == "table" and row.GetData ~= nil then
            data = call(row, "GetData")
        end
        if type(data) == "table" then
            local parts = {}
            for key, value in pairs(data) do
                if type(value) ~= "table" or value.GetObjectType ~= nil then
                    parts[#parts + 1] = tostring(key) .. "=" .. show(value, 60)
                else
                    parts[#parts + 1] = tostring(key) .. "=<table>"
                end
            end
            table.sort(parts)
            out(indent .. "    row " .. index .. ": " .. table.concat(parts, ", "))
        else
            out(indent .. "    row " .. index .. ": " .. show(data))
        end
    end
end

local function describeParts(indent, frame)
    -- The named parts a template hangs on its frame (frame.ScrollBox, frame.TrainButton ...).
    local names = {}
    for key, value in pairs(frame) do
        if type(key) == "string" and (isFrame(value) or (type(value) == "table" and value.GetObjectType ~= nil)) then
            names[#names + 1] = key .. "=" .. show(value)
        end
    end
    table.sort(names)
    if #names > 0 then
        out(indent .. "  parts: " .. table.concat(names, ", ", 1, math.min(#names, 40)))
    end
end

local function describe(frame, path, depth, indent)
    local objectType = call(frame, "GetObjectType") or "?"
    local name = call(frame, "GetName")
    local shown = call(frame, "IsShown")
    local visible = call(frame, "IsVisible")
    local width, height = call(frame, "GetWidth"), call(frame, "GetHeight")
    local head = indent .. path .. " [" .. tostring(objectType) .. "]"
    if name then
        head = head .. " name=" .. tostring(name)
    end
    head = head .. " shown=" .. tostring(shown) .. " visible=" .. tostring(visible)
    if width and height and not secret(width) and not secret(height) then
        head = head .. string.format(" size=%.0fx%.0f", width, height)
    end
    local text = call(frame, "GetText")
    if text ~= nil then
        head = head .. " text=" .. show(text)
    end
    if objectType == "Button" or objectType == "CheckButton" then
        local enabled = call(frame, "IsEnabled")
        head = head .. " enabled=" .. tostring(enabled)
        local hasClick = call(frame, "HasScript", "OnClick")
        head = head .. " onclick=" .. tostring(hasClick)
    end
    if objectType == "CheckButton" then
        head = head .. " checked=" .. tostring(call(frame, "GetChecked"))
    end
    if objectType == "EditBox" then
        head = head .. " value=" .. show(call(frame, "GetText"))
    end
    out(head)

    -- texts of the frame's own regions (labels that are not buttons' text)
    local regions = callAll(frame, "GetRegions")
    local seen = 0
    for _, region in ipairs(regions) do
        if seen >= 25 then
            break
        end
        if call(region, "GetObjectType") == "FontString" then
            local regionText = call(region, "GetText")
            if regionText ~= nil and regionText ~= "" then
                out(indent .. "  label " .. show(regionText) .. (call(region, "IsShown") and "" or " (hidden)"))
                seen = seen + 1
            end
        end
    end

    describeParts(indent, frame)

    -- a list, or the frame holding one
    local scrollBox = frame.GetDataProvider ~= nil and frame or nil
    if scrollBox ~= nil then
        local provider = call(scrollBox, "GetDataProvider")
        if provider ~= nil then
            describeProvider(indent, provider)
        end
    end

    if depth >= MAX_DEPTH then
        return
    end
    local children = callAll(frame, "GetChildren")
    for index, child in ipairs(children) do
        if index > MAX_CHILDREN then
            out(indent .. "  ... " .. (#children - MAX_CHILDREN) .. " more children")
            break
        end
        local childName = call(child, "GetName")
        local label = childName or ("child" .. index)
        describe(child, path .. "." .. label, depth + 1, indent .. "  ")
    end
end

-- ------------------------------------------------------------------ the report

local APIS = {
    -- what a training or crafting window could be driven by
    "GetNumCrafts", "GetCraftInfo", "GetCraftSelectionIndex", "SelectCraft", "DoCraft", "GetCraftDescription",
    "GetCraftNumReagents", "GetCraftName", "GetCraftDisplaySkillLine",
    "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerSelectionIndex", "SetTrainerServiceTypeFilter",
    "BuyTrainerService", "GetTrainerServiceCost", "GetTrainerServiceDescription",
    "GetPetTrainingPoints", "GetPetTrainingPointsText", "GetPetTrainingInfo", "TrainPet", "CanTrainPet",
    "CastPetAction", "GetPetActionInfo", "HasPetUI", "UnitExists",
    "C_PetTraining", "C_BeastTraining", "C_Trainer", "C_TrainerUI", "C_SpellBook", "C_ClassTalents",
}

local GLOBAL_STRINGS = {
    "BEAST_TRAINING", "TRAINING_POINTS_LABEL", "TRAIN", "TRAINER_SERVICE_COST", "CRAFT_TRAIN", "PET_TRAINING",
}

local function sectionEnvironment()
    local version, build, date, toc = GetBuildInfo()
    out("== environment")
    out("build " .. tostring(version) .. " (" .. tostring(build) .. ") interface " .. tostring(toc) .. " locale " .. tostring(GetLocale()))
    local loaded = {}
    if C_AddOns ~= nil and C_AddOns.GetNumAddOns ~= nil then
        for i = 1, C_AddOns.GetNumAddOns() do
            local name = C_AddOns.GetAddOnInfo(i)
            if name ~= nil and name:find("^Blizzard_") and C_AddOns.IsAddOnLoaded(i) then
                loaded[#loaded + 1] = name
            end
        end
    end
    table.sort(loaded)
    out("loaded Blizzard UI addons: " .. table.concat(loaded, ", "))

    out("== api present (name = type)")
    local present = {}
    for _, name in ipairs(APIS) do
        present[#present + 1] = name .. "=" .. type(_G[name])
    end
    out(table.concat(present, ", "))
    for key, value in pairs(_G.C_PetTraining or {}) do
        out("C_PetTraining." .. tostring(key) .. " = " .. type(value))
    end
    for key, value in pairs(_G.C_BeastTraining or {}) do
        out("C_BeastTraining." .. tostring(key) .. " = " .. type(value))
    end
    out("== global strings")
    for _, name in ipairs(GLOBAL_STRINGS) do
        out(name .. " = " .. show(_G[name]))
    end

    -- What the craft and trainer APIs say right now, when they exist.
    if type(GetNumCrafts) == "function" then
        local count = callGlobal("GetNumCrafts")
        out("GetNumCrafts() = " .. show(count))
        for i = 1, math.min(tonumber(count) or 0, 12) do
            local ok, a, b, c, d, e, f, g = pcall(GetCraftInfo, i)
            if ok then
                out("GetCraftInfo(" .. i .. ") = " .. show(a) .. ", " .. show(b) .. ", " .. show(c) .. ", " .. show(d)
                    .. ", " .. show(e) .. ", " .. show(f) .. ", " .. show(g))
            end
        end
    end
    if type(GetNumTrainerServices) == "function" then
        local count = callGlobal("GetNumTrainerServices")
        out("GetNumTrainerServices() = " .. show(count) .. ", selection " .. show(callGlobal("GetTrainerSelectionIndex")))
        for i = 1, math.min(tonumber(count) or 0, 16) do
            local ok, a, b, c, d, e, f = pcall(GetTrainerServiceInfo, i)
            if ok then
                local cost = callGlobal("GetTrainerServiceCost", i)
                out("GetTrainerServiceInfo(" .. i .. ") = " .. show(a) .. ", " .. show(b) .. ", " .. show(c) .. ", "
                    .. show(d) .. ", " .. show(e) .. ", " .. show(f) .. "; cost " .. show(cost))
            end
        end
    end
    for _, tableName in ipairs({ "C_Trainer", "C_PetTraining", "C_BeastTraining" }) do
        local api = rawget(_G, tableName)
        if type(api) == "table" then
            local names = {}
            for key, value in pairs(api) do
                names[#names + 1] = tostring(key) .. "=" .. type(value)
            end
            table.sort(names)
            out(tableName .. ": " .. table.concat(names, ", "))
        end
    end

    -- Every global that is a frame and is named like a training window, shown or not.
    out("== frames named like a training window (global name, type, shown, parent)")
    local found = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and isFrame(value) and not key:find("^WowVision") then
            local lowered = key:lower()
            if lowered:find("train", 1, true) or lowered:find("beast", 1, true) or lowered:find("craft", 1, true)
                or lowered:find("stable", 1, true) or lowered:find("petfeed", 1, true) then
                local parent = call(value, "GetParent")
                found[#found + 1] = string.format("  %s [%s] shown=%s parent=%s", key,
                    tostring(call(value, "GetObjectType")), tostring(call(value, "IsShown")),
                    tostring(parent and call(parent, "GetName") or nil))
            end
        end
    end
    table.sort(found)
    for index, line in ipairs(found) do
        if index > 150 then
            out("  ... " .. (#found - 150) .. " more")
            break
        end
        out(line)
    end
    if type(GetPetTrainingPoints) == "function" then
        local points = { callGlobal("GetPetTrainingPoints") }
        out("GetPetTrainingPoints() = " .. show(points[1]) .. ", " .. show(points[2]))
    end
end

-- Shown frames directly under UIParent.
local function topLevel()
    local list = {}
    for _, child in ipairs({ UIParent:GetChildren() }) do
        if call(child, "IsShown") then
            list[#list + 1] = child
        end
    end
    return list
end

local function matches(frame)
    local name = call(frame, "GetName")
    if name ~= nil and (name:find("Craft") or name:find("Train") or name:find("Beast") or name:find("Pet")) then
        return true
    end
    return false
end

-- A frame whose own title text or a label says it is a training window: the
-- global strings of the client's language name it.
local function mentionsTraining(frame)
    local needles = {}
    for _, key in ipairs({ "BEAST_TRAINING", "TRAINING_POINTS_LABEL", "PET_TRAINING" }) do
        local value = _G[key]
        if type(value) == "string" and value ~= "" then
            needles[#needles + 1] = (value:gsub(":%s*$", ""))
        end
    end
    local function scan(node, level)
        for _, region in ipairs(callAll(node, "GetRegions")) do
            if call(region, "GetObjectType") == "FontString" then
                local text = call(region, "GetText")
                if type(text) == "string" and not secret(text) then
                    for _, needle in ipairs(needles) do
                        if text:find(needle, 1, true) then
                            return true
                        end
                    end
                end
            end
        end
        if level < 5 then
            for _, child in ipairs(callAll(node, "GetChildren")) do
                if call(child, "IsShown") and scan(child, level + 1) then
                    return true
                end
            end
        end
        return false
    end
    return scan(frame, 0)
end

function WowVisionProbeRun(frameName)
    lines = {}
    out("WowVision Probe " .. date("%Y-%m-%d %H:%M:%S"))
    local ok, err = pcall(sectionEnvironment)
    if not ok then
        out("environment error: " .. tostring(err))
    end

    local shown = topLevel()
    out("== shown frames directly under UIParent: " .. #shown)
    for _, frame in ipairs(shown) do
        local name = call(frame, "GetName")
        local left, top = call(frame, "GetLeft"), call(frame, "GetTop")
        out(string.format("  %s [%s] at %s,%s", tostring(name or "<anonymous>"), tostring(call(frame, "GetObjectType")),
            show(left and math.floor(left) or nil), show(top and math.floor(top) or nil)))
    end

    local targets = {}
    if frameName ~= nil and frameName ~= "" then
        local frame = rawget(_G, frameName)
        if isFrame(frame) then
            targets[#targets + 1] = frame
        else
            out("== no frame named " .. frameName)
        end
    else
        for _, frame in ipairs(shown) do
            if matches(frame) or mentionsTraining(frame) then
                targets[#targets + 1] = frame
            end
        end
    end
    out("== frames dumped in full: " .. #targets)
    for _, frame in ipairs(targets) do
        local okDump, errDump = pcall(describe, frame, tostring(call(frame, "GetName") or "frame"), 0, "")
        if not okDump then
            out("dump error: " .. tostring(errDump))
        end
    end

    WowVisionProbeDB = WowVisionProbeDB or {}
    WowVisionProbeDB.lines = lines
    local message
    if #targets == 1 then
        message = T("Probe done: %d lines, 1 window dumped. Type slash reload to save it.", #lines)
    else
        message = T("Probe done: %d lines, %d windows dumped. Type slash reload to save it.", #lines, #targets)
    end
    if WowVision ~= nil and WowVision.speak ~= nil then
        pcall(WowVision.speak, WowVision, message)
    end
    print(message)
    return lines
end

-- ------------------------------------------------------------------ watching

-- /wvprobe watch [seconds]: from now on, a window that opens is dumped in full
-- the moment it shows, whatever it is called and wherever it hangs. Open the
-- window you want recorded after typing the command.
local WATCH_SECONDS = 90
local NOISE = { "^WowVision", "^Details", "^DBM", "^GTFO", "^Questie", "^AceGUI", "^GameTooltip", "^ShoppingTooltip",
    "^ItemRefTooltip", "^UIErrorsFrame", "^ChatFrame", "^GeneralDockManager", "^BuffFrame", "^DebuffFrame" }

local function noise(frame)
    local name = call(frame, "GetName")
    if name ~= nil then
        for _, pattern in ipairs(NOISE) do
            if name:find(pattern) then
                return true
            end
        end
    end
    return false
end

-- The frames shown within a few levels below UIParent.
local function shownTree(maxDepth)
    local set, list = {}, {}
    local function visit(frame, depth)
        for _, child in ipairs(callAll(frame, "GetChildren")) do
            if #list >= 5000 then
                return
            end
            if call(child, "IsShown") then
                set[child] = true
                list[#list + 1] = child
                if depth < maxDepth then
                    visit(child, depth + 1)
                end
            end
        end
    end
    visit(UIParent, 1)
    return set, list
end

local function markSubtree(set, frame, depth)
    set[frame] = true
    if depth >= MAX_DEPTH then
        return
    end
    for _, child in ipairs(callAll(frame, "GetChildren")) do
        markSubtree(set, child, depth + 1)
    end
end

local watcher
local function stopWatch(captured)
    if watcher ~= nil then
        watcher:SetScript("OnUpdate", nil)
    end
    local message
    if captured == 1 then
        message = T("Probe watch done: 1 window captured, %d lines. Type slash reload to save it.", lines and #lines or 0)
    else
        message = T("Probe watch done: %d windows captured, %d lines. Type slash reload to save it.", captured,
            lines and #lines or 0)
    end
    if WowVision ~= nil and WowVision.speak ~= nil then
        pcall(WowVision.speak, WowVision, message)
    end
    print(message)
end

function WowVisionProbeWatch(seconds)
    seconds = tonumber(seconds) or WATCH_SECONDS
    lines = {}
    out("WowVision Probe watch " .. date("%Y-%m-%d %H:%M:%S") .. " for " .. seconds .. " seconds")
    pcall(sectionEnvironment)
    WowVisionProbeDB = WowVisionProbeDB or {}
    WowVisionProbeDB.lines = lines

    local baseline = shownTree(3)
    local captured = 0
    local elapsedTotal, sinceTick = 0, 0
    watcher = watcher or CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        sinceTick = sinceTick + elapsed
        if sinceTick < 0.3 then
            return
        end
        sinceTick = 0
        local _, list = shownTree(3)
        for _, frame in ipairs(list) do
            if not baseline[frame] then
                local parent = call(frame, "GetParent")
                -- a root of what just opened: its parent was already on screen
                if parent == nil or parent == UIParent or baseline[parent] then
                    local width, height = call(frame, "GetWidth"), call(frame, "GetHeight")
                    local big = width ~= nil and height ~= nil and not secret(width) and not secret(height)
                        and width >= 120 and height >= 80
                    if big and not noise(frame) then
                        captured = captured + 1
                        out(string.format("== captured %d at %.1f s: %s [%s]", captured, elapsedTotal,
                            tostring(call(frame, "GetName") or "<anonymous>"), tostring(call(frame, "GetObjectType"))))
                        local ok, err = pcall(describe, frame, tostring(call(frame, "GetName") or "frame"), 0, "")
                        if not ok then
                            out("dump error: " .. tostring(err))
                        end
                        if WowVision ~= nil and WowVision.speak ~= nil then
                            pcall(WowVision.speak, WowVision, T("Probe captured window %d", captured))
                        end
                    end
                    markSubtree(baseline, frame, 0)
                end
            end
        end
        if elapsedTotal >= seconds then
            stopWatch(captured)
        end
    end)
    local message = T("Probe watching for %d seconds. Open the window now.", seconds)
    if WowVision ~= nil and WowVision.speak ~= nil then
        pcall(WowVision.speak, WowVision, message)
    end
    print(message)
end

SLASH_WVPROBE1 = "/wvprobe"
SlashCmdList["WVPROBE"] = function(message)
    local word, rest = (message or ""):match("^%s*(%S*)%s*(%S*)")
    if word == "watch" then
        WowVisionProbeWatch(rest)
        return
    end
    WowVisionProbeRun(word)
end
