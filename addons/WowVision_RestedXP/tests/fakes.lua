-- Doubles shared by the suites: RestedXP's tables (steps with lines and check boxes, the arrow, the menu) and
-- HereBeDragons.
local fake = {}

-- A check box as RestedXP builds it: a CheckButton whose parent frame carries the element.
function fake.button(frame)
    local button = { checked = false, enabled = true }
    function button:SetChecked(value)
        self.checked = value and true or false
    end
    function button:GetChecked()
        return self.checked
    end
    function button:IsEnabled()
        return self.enabled
    end
    function button:GetParent()
        return frame
    end
    return button
end

-- config.steps: array of { title?, sticky?, tip?, hidewindow?, hidetip?, level?, optional?, lines = { { text, done?,
-- skip?, textOnly?, optional?, noFrame?, noText? } } }; config.active: indexes of the steps now shown;
-- config.current: the step the guide is at; config.menuList; config.translate. Returns the fake RestedXP table.
function fake.rxp(config)
    config = config or {}
    local rxp = {
        calls = { postClick = 0, updateMap = 0, setStep = {}, setComplete = 0, menu = 0 },
        locale = {
            Get = function(text)
                return (config.translate or {})[text] or text
            end,
        },
        ReplaceNpcIds = function(text)
            -- like the real one: creature names without their id (and a second value, as gsub gives)
            return text:gsub("::%d+", "")
        end,
        RXPFrame = { activeSteps = {} },
    }
    local steps = {}
    for index, spec in ipairs(config.steps or {}) do
        local step = {
            index = index,
            title = spec.title,
            sticky = spec.sticky,
            tip = spec.tip,
            hidewindow = spec.hidewindow,
            hidetip = spec.hidetip,
            level = spec.level,
            optional = spec.optional,
            elements = {},
        }
        for _, lineSpec in ipairs(spec.lines or {}) do
            local element = {
                text = lineSpec.text,
                completed = lineSpec.done,
                skip = lineSpec.skip,
                textOnly = lineSpec.textOnly,
                optional = lineSpec.optional,
                step = step,
            }
            if lineSpec.noText then
                element.text = nil
            end
            if not lineSpec.noFrame then
                local frame = { element = element }
                frame.button = fake.button(frame)
                frame.button.checked = (lineSpec.done or lineSpec.skip) and true or false
                element.frame = frame
            end
            tinsert(step.elements, element)
        end
        steps[index] = step
    end
    rxp.currentGuide = {
        steps = steps,
        displayname = config.name or "1-12 Durotar",
        subgroup = config.subgroup,
        title = config.guideTitle,
    }
    if config.empty then
        rxp.currentGuide.empty = true
    end
    rxp.progress = config.current or 1
    rxp.GetGuideProgress = function()
        return rxp.progress, nil
    end
    rxp.GetGuideName = function(guide)
        return guide.displayname
    end
    for _, index in ipairs(config.active or {}) do
        tinsert(rxp.RXPFrame.activeSteps, steps[index])
    end
    rxp.ActiveStepElementPostClick = function(button)
        rxp.calls.postClick = rxp.calls.postClick + 1
        local element = button:GetParent().element
        if element and not element.optional then
            element.skip = button:GetChecked()
        end
        rxp.updateSteps = true
        rxp.UpdateMap()
    end
    rxp.UpdateMap = function()
        rxp.calls.updateMap = rxp.calls.updateMap + 1
    end
    rxp.SetElementComplete = function(element)
        rxp.calls.setComplete = rxp.calls.setComplete + 1
        element.completed = true
        element.skip = true
    end
    rxp.SetStep = function(step)
        tinsert(rxp.calls.setStep, step)
        rxp.progress = step
    end
    rxp.arrowFrame = { wrongContinent = false }
    rxp.RXPFrame.GenerateMenuTable = function(...)
        rxp.calls.menu = rxp.calls.menu + 1
        rxp.calls.menuArgs = select("#", ...)
        rxp.RXPFrame.menuList = config.menuList
    end
    return rxp
end

-- RestedXP's guide importer, as far as this addon touches it, put on a fake RestedXP table: its paste box (a frame
-- that can take focus), its window, the messages it keeps (a port of UpdateImportStatusHistory and ProcessBuffer),
-- the worker frame that shows while an import runs, the list of guides, RemoveGuide and the saved data.
-- config: importError (what Validate refuses with), guides = { { key, imported, group, version, name } },
-- saved = the saved copies by key, cannotOpen (Open creates nothing, as in combat), noFocus (SetFocus fails).
function fake.withImporter(rxp, config)
    config = config or {}
    local importer = {
        calls = { open = 0, validate = 0, refresh = 0, battleNet = 0, focus = 0 },
        importReady = false,
        importCache = { bufferString = "", bufferData = {}, lastBuffer = 0 },
        gui = { selectedDeleteGuide = "", importStatusHistory = {}, progressMessage = nil, progressError = false },
        widgets = {},
    }
    rxp.guideImporter = importer
    rxp.workerFrame = {
        shown = false,
        IsShown = function(self)
            return self.shown
        end,
    }

    function importer:Open()
        self.calls.open = self.calls.open + 1
        if config.cannotOpen then
            return
        end
        if self.widgets.import == nil then
            local editBox = { focused = false }
            function editBox:SetFocus()
                if config.noFocus then
                    error("no focus")
                end
                self.focused = true
                importer.calls.focus = importer.calls.focus + 1
            end
            self.widgets.import = {
                shown = false,
                hides = 0,
                Show = function(window)
                    window.shown = true
                end,
                Hide = function(window)
                    window.shown = false
                    window.hides = window.hides + 1
                end,
                IsShown = function(window)
                    return window.shown
                end,
            }
            self.widgets.importBox = {
                editBox = editBox,
                GetEditBox = function(box)
                    return box.editBox
                end,
            }
            self.widgets.importButton = {}
        end
        self.widgets.import:Show()
    end

    function importer:UpdateImportUI()
        self.calls.refresh = self.calls.refresh + 1
    end

    function importer:CheckBattleNet()
        self.calls.battleNet = self.calls.battleNet + 1
        if config.answers then
            _G.RXPData = { cache = true }
        end
        return _G.RXPData and _G.RXPData.cache
    end

    -- as RestedXP's: a message with "n/m" in it is the progress, the other lines go to the history
    function importer:UpdateImportStatusHistory(data, isError, ...)
        if type(data) ~= "string" then
            return
        end
        local message = string.format(data, ...)
        local current, total = message:match("(%d+)/(%d+)")
        if current and total then
            local details
            for line in message:gmatch("[^\n]+") do
                if not line:match("%d+/%d+") then
                    details = details and details .. "\n" .. line or line
                end
            end
            if details then
                tinsert(self.gui.importStatusHistory, 1, details)
            end
            self.gui.progressMessage = string.format("Total guides loaded: %d/%s", current, total)
        else
            tinsert(self.gui.importStatusHistory, 1, message)
        end
        self.gui.progressError = not not isError
        self:UpdateImportUI()
    end

    function importer:ProcessBuffer(editBox)
        local cache = self.importCache
        cache.lastBuffer = 0
        cache.bufferString = table.concat(cache.bufferData)
        self.importReady = #cache.bufferString > 0
        local shown = math.min(#cache.bufferString, 150)
        self:UpdateImportStatusHistory("Loaded %d characters into import buffer, %d shown", false, #cache.bufferString, shown)
        if editBox then
            editBox.focused = false
        end
        cache.bufferData = {}
    end

    function importer:Validate()
        self.calls.validate = self.calls.validate + 1
        if config.validateRaises then
            error("validation blew up")
        end
        local cache = self.importCache
        cache.bufferString = ""
        if config.importError then
            self:UpdateImportStatusHistory(config.importError, true)
            return config.importError
        end
        self.importReady = false
        rxp.workerFrame.shown = true
        self:UpdateImportStatusHistory("Loading Guides... (0/%d)", false, config.total or 4)
        return true
    end

    -- what pasting does: the characters arrive one by one, then the box lets go a moment later
    function importer:paste(text)
        self.importCache.bufferData = { text }
        self:ProcessBuffer(self.widgets.importBox and self.widgets.importBox.editBox or nil)
    end

    rxp.guides = {}
    for _, spec in ipairs(config.guides or {}) do
        tinsert(rxp.guides, {
            key = spec.key,
            imported = spec.imported,
            cache = spec.cache,
            group = spec.group,
            version = spec.version,
        })
    end
    rxp.removed = {}
    rxp.RemoveGuide = function(key)
        tinsert(rxp.removed, key)
        for index, guide in ipairs(rxp.guides) do
            if guide.key == key then
                rxp.guides[index] = {}
                return true
            end
        end
        return nil
    end
    rxp.db = { profile = { guides = config.saved or {}, guideId = 5, guideLength = 6, guideContent = "x" } }
    rxp.settings = { profile = { skipQuest = { 1 }, questPrio = { 2 }, questPrioIndex = { 3 }, debug = config.debug } }
    rxp.metaDataCalls = {}
    rxp.CreateMetaDataTable = function(self, wipe)
        tinsert(self.metaDataCalls, wipe)
    end
    return importer
end

-- HereBeDragons stand-in: the player is at position = { x, y } (nil: unknown); the vector to a destination is the
-- given angle (counter clockwise from north, radians) and distance (yards).
function fake.hbd(position, angle, distance)
    return {
        GetPlayerWorldPosition = function()
            if position == nil then
                return nil, nil, 1
            end
            return position[1], position[2], 1
        end,
        GetWorldVector = function()
            return angle, distance
        end,
    }
end

return fake
