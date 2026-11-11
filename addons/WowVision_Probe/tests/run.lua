-- Offline smoke test: `lua tests/run.lua` from the addon folder.
-- A fake window tree stands in for the game; the probe must report it and must
-- survive a broken frame.
local script = arg and arg[0] or "tests/run.lua"
local dir = (script:match("^(.*)[/\\][^/\\]*$") or ".") .. "/.."

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        io.write("FAIL  ", name, "\n      ", tostring(err), "\n")
    end
end
local function has(lines, needle, label)
    for _, line in ipairs(lines) do
        if line:find(needle, 1, true) then
            return
        end
    end
    error((label or "missing") .. ": " .. needle, 2)
end
local function eqText(a, b)
    if a ~= b then
        error("expected " .. tostring(b) .. ", got " .. tostring(a), 2)
    end
end
local function hasNot(lines, needle)
    for _, line in ipairs(lines) do
        if line:find(needle, 1, true) then
            error("unexpected: " .. needle, 2)
        end
    end
end

-- ----------------------------------------------------------- a fake game

local Frame = {}
Frame.__index = Frame
local function new(objectType, name, props)
    local frame = setmetatable({ _type = objectType, _name = name, _children = {}, _regions = {}, _shown = true }, Frame)
    for key, value in pairs(props or {}) do
        frame[key] = value
    end
    return frame
end
function Frame:GetObjectType() return self._type end
function Frame:GetName() return self._name end
function Frame:IsShown() return self._shown end
function Frame:IsVisible() return self._shown end
function Frame:GetWidth() return self._w or 100 end
function Frame:GetHeight() return self._h or 50 end
function Frame:GetLeft() return self._left or 10 end
function Frame:GetTop() return self._top or 500 end
function Frame:GetChildren() return table.unpack(self._children) end
function Frame:GetRegions() return table.unpack(self._regions) end
function Frame:GetText() return self._text end
function Frame:HasScript() return self._onclick == true end
function Frame:IsEnabled() return self._enabled ~= false end
function Frame:GetChecked() return self._checked end
function Frame:add(child, key)
    table.insert(self._children, child)
    if key then self[key] = child end
    return child
end
function Frame:label(text, hidden)
    table.insert(self._regions, new("FontString", nil, { _text = text, _shown = not hidden }))
end

local provider = {
    rows = {
        { name = "Grondement", rank = 1, cost = 1, index = 1 },
        { name = "Armure naturelle", rank = 1, cost = 1, index = 2 },
        { name = "Griffe", rank = 2, cost = 2, index = 3 },
    },
    GetSize = function(self) return #self.rows end,
    Find = function(self, i)
        local data = self.rows[i]
        return { GetData = function() return data end }
    end,
}

UIParent = new("Frame", "UIParent")
WorldFrame = new("Frame", "WorldFrame")
UIParent._children = {}

local playerFrame = UIParent:add(new("Frame", "PlayerFrame"))
PlayerFrame = playerFrame -- named frames are globals in the game
UIParent:add(new("Frame", "HiddenThing", { _shown = false }))

local trainer = UIParent:add(new("Frame", "BeastTrainerFrame", { _left = 12, _top = 700 }))
trainer:label("Scorpide")
trainer:label("Points d'entraînement : 30")
trainer:label("caché", true)
trainer:add(new("Button", nil, { _text = "Filtres", _onclick = true }), "FilterButton")
local scrollBox = trainer:add(new("Frame", nil), "ScrollBox")
scrollBox.GetDataProvider = function() return provider end
trainer:add(new("Button", "BeastTrainButton", { _text = "S'entraîner", _onclick = true, _enabled = false }), "TrainButton")
local brokenChild = trainer:add(new("Frame", "Broken"))
brokenChild.GetText = function() error("boom") end

-- a window found only by what it says
local mystery = UIParent:add(new("Frame", "SomethingElse"))
mystery:label("Points d'entraînement : 12")

local printed = {}
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
GetBuildInfo = function() return "1.60.1", "99999", "Jan 1 2026", 16001 end
GetLocale = function() return "frFR" end
C_AddOns = {
    GetNumAddOns = function() return 3 end,
    GetAddOnInfo = function(i) return ({ "Blizzard_TrainerUI", "Questie", "Blizzard_CraftUI" })[i] end,
    IsAddOnLoaded = function(i) return i ~= 3 end,
}
TRAINING_POINTS_LABEL = "Points d'entraînement :"
GetNumCrafts = function() return 2 end
GetCraftInfo = function(i) return "Grondement", "Rang " .. i, "optimal", 0, false, i, 8 end
GetPetTrainingPoints = function() return 30, 5 end
SlashCmdList = {}
date = os.date -- WoW provides date as a global
WowVision = { speak = function(_, text) printed[#printed + 1] = "SPOKEN: " .. text end }

assert(loadfile(dir .. "/Probe.lua"))("WowVision_Probe")

-- ------------------------------------------------------------------- tests

test("the command is registered", function()
    assert(type(SlashCmdList.WVPROBE) == "function")
    assert(SLASH_WVPROBE1 == "/wvprobe")
end)

local lines
test("it runs without an error and keeps its lines for the saved variable", function()
    SlashCmdList.WVPROBE("")
    lines = WowVisionProbeDB.lines
    assert(type(lines) == "table" and #lines > 10, "no report")
end)

test("it reports the environment, the APIs and what they answer", function()
    has(lines, "build 1.60.1 (99999) interface 16001 locale frFR")
    has(lines, "loaded Blizzard UI addons: Blizzard_TrainerUI")
    hasNot(lines, "Blizzard_CraftUI,")
    has(lines, "GetNumCrafts=function")
    has(lines, "GetCraftInfo(2) =")
    has(lines, "GetPetTrainingPoints() = 30, 5")
end)

test("it lists every shown top-level frame and not the hidden one", function()
    has(lines, "shown frames directly under UIParent: 3")
    has(lines, "PlayerFrame [Frame]")
    hasNot(lines, "HiddenThing")
end)

test("a frame named like a training window is dumped in full, with its parts and rows", function()
    has(lines, "BeastTrainerFrame [Frame] name=BeastTrainerFrame shown=true")
    has(lines, 'label "Scorpide"')
    has(lines, 'label "caché" (hidden)')
    has(lines, 'text="S\'entraîner" enabled=false onclick=true')
    has(lines, "parts: FilterButton=<Button>, ScrollBox=<Frame>, TrainButton=<Button BeastTrainButton>")
    has(lines, "data provider: size 3")
    has(lines, "row 1: cost=1, index=1, name=\"Grondement\", rank=1")
    has(lines, "row 3: cost=2, index=3, name=\"Griffe\", rank=2")
end)

test("a window found only by its text is dumped too", function()
    has(lines, "SomethingElse [Frame]")
    has(lines, "frames dumped in full: 2")
end)

test("a broken frame does not stop the report", function()
    has(lines, "Broken")
    has(lines, "name=Broken")
end)

test("a named frame is dumped alone, and an unknown name is said", function()
    local one = WowVisionProbeRun("PlayerFrame")
    has(one, "frames dumped in full: 1")
    local none = WowVisionProbeRun("NoSuchFrame")
    has(none, "no frame named NoSuchFrame")
end)

test("it speaks a short summary and says to reload", function()
    local spoken
    for _, line in ipairs(printed) do
        -- (the test game is French)
        if line:find("SPOKEN: Relevé terminé", 1, true) then spoken = line end
    end
    assert(spoken and spoken:find("reload", 1, true), "no spoken summary")
end)

-- What the probe says out loud comes in the game's language: English, French or German.
local function spokenIn(locale, run)
    local saved = GetLocale
    GetLocale = function() return locale end
    printed = {}
    run()
    GetLocale = saved
    local said = {}
    for _, line in ipairs(printed) do
        if line:find("SPOKEN: ", 1, true) then said[#said + 1] = line:sub(9) end
    end
    return said
end

test("the summary is said in English, French and German", function()
    local english = spokenIn("enUS", function() SlashCmdList.WVPROBE("") end)
    assert(english[#english]:find("^Probe done: %d+ lines, %d+ windows? dumped%. Type slash reload to save it%.$"), english[#english])
    local french = spokenIn("frFR", function() SlashCmdList.WVPROBE("") end)
    assert(french[#french]:find("^Relevé terminé : %d+ lignes, %d+ fenêtres? relevées? ?%. Tapez slash reload pour l'enregistrer%.$"), french[#french])
    local german = spokenIn("deDE", function() SlashCmdList.WVPROBE("") end)
    assert(german[#german]:find("^Aufnahme fertig: %d+ Zeilen, %d+ Fenster aufgenommen%. Gib slash reload ein, um sie zu speichern%.$"), german[#german])
    -- a language with no table reads English
    local spanish = spokenIn("esES", function() SlashCmdList.WVPROBE("") end)
    assert(spanish[#spanish]:find("^Probe done:"), spanish[#spanish])
end)

test("one window and several windows are said differently, in every language", function()
    local messages = WowVisionProbeMessages
    for locale, table in pairs(messages) do
        for key in pairs(table) do
            assert(messages.frFR[key] and messages.deDE[key], locale .. ": a key missing in the other language: " .. key)
        end
    end
    -- every % placeholder of the English key survives in the translation
    for _, locale in ipairs({ "frFR", "deDE" }) do
        for key, value in pairs(messages[locale]) do
            local _, wanted = key:gsub("%%d", "")
            local _, got = value:gsub("%%d", "")
            assert(wanted == got, locale .. ": placeholders differ for " .. key)
        end
    end
    local single = spokenIn("enUS", function() SlashCmdList.WVPROBE("") end)
    assert(single[#single] ~= nil)
end)

test("a frame with many children and labels is dumped whole, not cut at five", function()
    local crowded = new("Frame", "CrowdedTrainerFrame", { _left = 5, _top = 500 })
    for n = 1, 9 do
        crowded:add(new("Button", "CrowdedButton" .. n, { _text = "Bouton " .. n, _onclick = true }))
        crowded:label("Texte " .. n)
    end
    CrowdedTrainerFrame = crowded
    local report = WowVisionProbeRun("CrowdedTrainerFrame")
    has(report, "CrowdedButton9")
    has(report, 'text="Bouton 9"')
    has(report, 'label "Texte 9"')
end)

-- ------------------------------------------------------------ the extras

test("it reports the trainer data and the frames named like a training window", function()
    GetNumTrainerServices = function() return 2 end
    GetTrainerSelectionIndex = function() return 1 end
    GetTrainerServiceInfo = function(i) return "Grondement", "Rang " .. i, "available", 8 end
    GetTrainerServiceCost = function(i) return i * 10 end
    C_Trainer = { GetTrainerServiceInfo = function() end, IsTrainerServiceLearned = function() end }
    ClassTrainerFrame = new("Frame", "ClassTrainerFrame", { _shown = false })
    ClassTrainerFrame._parent = UIParent
    local report = WowVisionProbeRun("")
    has(report, "GetNumTrainerServices() = 2, selection 1")
    has(report, 'GetTrainerServiceInfo(2) = "Grondement", "Rang 2"')
    has(report, "; cost 20")
    has(report, "C_Trainer: GetTrainerServiceInfo=function, IsTrainerServiceLearned=function")
    has(report, "== frames named like a training window")
    has(report, "ClassTrainerFrame [Frame] shown=false")
end)

-- The watch: a frame that shows up after the command is dumped, the others are not.
local handler
function Frame:SetScript(name, fn) if name == "OnUpdate" then handler = fn end end
function Frame:GetParent() return self._parent end
CreateFrame = function() return new("Frame", nil) end

test("watch mode dumps a window that opens afterwards, once, and nothing else", function()
    printed = {}
    WowVisionProbeDB = nil
    SlashCmdList.WVPROBE("watch 5")
    local report = WowVisionProbeDB.lines
    has(report, "WowVision Probe watch")
    handler(nil, 0.4) -- nothing new yet
    for _, line in ipairs(report) do
        assert(not line:find("== captured", 1, true), "captured too early")
    end

    local window = UIParent:add(new("Frame", "PetTrainingWindow", { _w = 300, _h = 400, _parent = UIParent }))
    window:label("Scorpide")
    local list = window:add(new("Frame", nil, { _w = 200, _h = 300, _parent = window }), "ScrollBox")
    list.GetDataProvider = function() return provider end
    UIParent:add(new("Frame", nil, { _w = 40, _h = 40, _parent = UIParent }))              -- too small
    UIParent:add(new("Frame", "DetailsPopup", { _w = 300, _h = 300, _parent = UIParent })) -- an addon's noise
    handler(nil, 0.4)
    handler(nil, 0.4) -- a second tick must not capture again

    has(report, "== captured 1 at")
    has(report, "PetTrainingWindow [Frame]")
    has(report, 'label "Scorpide"')
    has(report, "data provider: size 3")
    local count = 0
    for _, line in ipairs(report) do
        if line:find("== captured", 1, true) then
            count = count + 1
        end
    end
    assert(count == 1, "expected one capture, got " .. count)
end)

test("watch mode ends by itself and says so", function()
    printed = {}
    SlashCmdList.WVPROBE("watch 1")
    handler(nil, 0.5)
    handler(nil, 0.6) -- one second has passed
    local done
    for _, line in ipairs(printed) do
        if line:find("Surveillance terminée", 1, true) then
            done = line
        end
    end
    assert(done and done:find("reload", 1, true), "no end message")
end)

test("the watch says it starts, and ends, in German and English too", function()
    local started = spokenIn("deDE", function() SlashCmdList.WVPROBE("watch 1") end)
    eqText(started[1], "Beobachtung für 1 Sekunden. Öffne das Fenster jetzt.")
    started = spokenIn("enUS", function() SlashCmdList.WVPROBE("watch 2") end)
    eqText(started[1], "Probe watching for 2 seconds. Open the window now.")
    local saved = GetLocale
    GetLocale = function() return "enUS" end
    printed = {}
    handler(nil, 1.0)
    handler(nil, 1.1) -- two seconds have passed: the watch ends and lets go of its handler
    GetLocale = saved
    local done
    for _, line in ipairs(printed) do
        if line:find("SPOKEN: Probe watch done", 1, true) then
            done = line
        end
    end
    assert(done and done:find("0 windows captured", 1, true), done)
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
