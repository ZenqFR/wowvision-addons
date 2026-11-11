-- The hunter's pet training window for the graph UI. It is the class trainer window of WowVision's training.lua
-- (the service list, the selected service's details, the train button) with three differences for the pet:
-- a stop that reads the training points left, a cost said in training points rather than coins, and the pet's
-- name as the title. WowVision's own training window waits for a trainer NPC; the Beast Training spell opens the
-- same frame with none, so this window is opened by the frame itself (Pet.lua says when).
--
-- The rest is WowVision's code for the class trainer, kept here as it is so that this window does not depend on
-- how WowVision organises its own.
local _, ns = ...
local L = ns.L
local pet = ns.pet

local graph = WowVision.graph
local nodes = graph.nodes
local ControlId = graph.ControlId
local kinds = graph.kinds

-- Tree-backed ScrollBoxes (WoW: Forever) hand emitters the tree node, not its payload -- Find(index, true)
-- returns the node so collapse state stays readable; the actual { skillIndex, playerMoney, trainerType } table
-- lives behind node:GetData(). Flat providers (Classic/TBC/Mists) already return the payload directly.
local function servicePayload(data)
    if type(data) == "table" and data.GetData ~= nil then
        return data:GetData()
    end
    return data
end

-- GetTrainerServiceInfo's return order differs by client: Classic/TBC/Mists return (name, rank, category,
-- isExpanded); WoW: Forever (since patch 1.60.1) returns (name, category, spellID, levelReq, rank) instead. The
-- two are told apart by the 3rd value's type -- a category string on the old signature, a numeric spellID on the
-- new one.
local function getServiceInfo(index)
    local a, b, c, d, e = GetTrainerServiceInfo(index)
    if type(c) == "number" then
        return { name = a, category = b, spellID = c, levelReq = d, rank = e }
    end
    return { name = a, rank = b, category = c, isExpanded = d }
end

-- The "Requires" line Blizzard prints under each row: level, profession rank and abilities, built from the same
-- globals the row uses so it reads in the client's language.
local function serviceRequirements(index, info)
    local parts = {}
    local levelReq = info.levelReq
    if levelReq == nil and GetTrainerServiceLevelReq ~= nil then
        levelReq = GetTrainerServiceLevelReq(index)
    end
    if levelReq ~= nil and levelReq > 1 then
        tinsert(parts, format(TRAINER_REQ_LEVEL, levelReq))
    end
    if GetTrainerServiceSkillReq ~= nil then
        local skill, rank = GetTrainerServiceSkillReq(index)
        if skill ~= nil and skill ~= "" then
            tinsert(parts, format(TRAINER_REQ_SKILL_RANK, skill, rank))
        end
    end
    if GetTrainerServiceNumAbilityReq ~= nil then
        for i = 1, GetTrainerServiceNumAbilityReq(index) or 0 do
            local ability = GetTrainerServiceAbilityReq(index, i)
            if ability ~= nil and ability ~= "" then
                tinsert(parts, ability)
            end
        end
    end
    if #parts == 0 then
        return nil
    end
    return REQUIRES_LABEL .. " " .. table.concat(parts, PLAYER_LIST_DELIMITER)
end

local function serviceLabel(index)
    local info = getServiceInfo(index)
    if info.name == nil then
        return nil
    end
    local label = info.name
    if info.rank ~= nil and info.rank ~= "" then
        label = label .. " " .. info.rank
    end
    if info.category == "used" then
        label = label .. ", " .. L["Known"]
    elseif info.category == "unavailable" then
        label = label .. ", " .. L["Unavailable"]
    end
    if info.category ~= "header" then
        local cost = GetTrainerServiceCost ~= nil and GetTrainerServiceCost(index) or nil
        if cost ~= nil and cost > 0 then
            -- the hunter's pet pays in training points
            label = label .. ", " .. pet.costText(cost)
        end
        if info.category ~= "used" then
            local requirements = serviceRequirements(index, info)
            if requirements ~= nil then
                label = label .. ", " .. requirements
            end
        end
    end
    return label
end

local function serviceAnnouncements(index)
    local category = getServiceInfo(index).category

    local announcements = {
        {
            text = function()
                return serviceLabel(index)
            end,
            kind = kinds.label,
            live = "focus",
        },
    }
    if category == "header" then
        tinsert(announcements, {
            text = function()
                return getServiceInfo(index).isExpanded and L["Expanded"] or L["Collapsed"]
            end,
            kind = kinds.value,
            live = "focus",
        })
    else
        tinsert(announcements, {
            text = function()
                if index == GetTrainerSelectionIndex() then
                    return L["selected"]
                end
                return nil
            end,
            kind = kinds.selected,
            live = "focus",
        })
    end
    return announcements
end

local function emitService(builder, data, position, helpers)
    builder:addItem(helpers.id, {
        controlType = graph.controlTypes.button,
        announcements = serviceAnnouncements(servicePayload(data).skillIndex),
        bindings = {
            { binding = "leftClick", type = "Click", emulatedKey = "LeftButton", target = helpers.target },
        },
        onFocus = helpers.onFocus,
        onFocusTick = helpers.onFocusTick,
        onUnfocus = helpers.onUnfocus,
        tooltipFrame = helpers.target,
    })
end

local function detailText(builder, id, label)
    builder:addItem(
        id,
        nodes.text({
            label = label,
            live = "focus",
        })
    )
end

local function renderDetails(builder)
    local frame = ClassTrainerDetailScrollFrame
    if frame == nil or not frame:IsVisible() then
        return
    end
    if ClassTrainerSkillIcon == nil or not ClassTrainerSkillIcon:IsShown() then
        return
    end

    builder:beginStop("details")
    builder:pushContext("details", L["Details"])
    builder:addItem(
        ControlId.structural("skill"),
        nodes.attachHover({
            controlType = graph.controlTypes.button,
            announcements = {
                {
                    text = function()
                        return ClassTrainerSkillName:GetText()
                    end,
                    kind = kinds.label,
                    live = "focus",
                },
            },
            bindings = {
                {
                    binding = "leftClick",
                    type = "Click",
                    emulatedKey = "LeftButton",
                    target = ClassTrainerSkillIcon,
                },
            },
        }, ClassTrainerSkillIcon)
    )
    if ClassTrainerSubSkillName ~= nil and ClassTrainerSubSkillName:IsVisible() then
        detailText(builder, ControlId.structural("subSkill"), function()
            return ClassTrainerSubSkillName:GetText()
        end)
    end
    if ClassTrainerSkillRequirements ~= nil and ClassTrainerSkillRequirements:IsVisible() then
        detailText(builder, ControlId.structural("requirements"), function()
            return ClassTrainerSkillRequirements:GetText()
        end)
    end
    if ClassTrainerCostLabel ~= nil and ClassTrainerCostLabel:IsVisible() then
        detailText(builder, ControlId.structural("cost"), function()
            return (ClassTrainerCostLabel:GetText() or "")
                .. " "
                .. C_CurrencyInfo.GetCoinText(ClassTrainerDetailMoneyFrame.staticMoney or 0)
        end)
    end
    builder:popContext()
end

function ns.render(builder, screen)
    if ClassTrainerFrame == nil or not ClassTrainerFrame:IsShown() then
        return
    end
    local title = ClassTrainerNameText ~= nil and ClassTrainerNameText:GetText() or nil
    if title == nil or title == "" then
        title = pet.title()
    end
    builder:pushContext("trainer", title or L["Training"])

    -- The hunter's pet: how many training points are left, read live.
    if pet.pointsText() ~= nil then
        builder:beginStop("trainingPoints")
        builder:addItem(
            ControlId.structural("trainingPoints"),
            nodes.text({
                label = function()
                    return pet.pointsText() or ""
                end,
                live = "focus",
            })
        )
    end

    -- WoW: Forever lifts the profession's next rank out of the service list into its own button above it; the
    -- list never contains that service.
    local stepButton = ClassTrainerFrame.skillStepButton
    local stepIndex = GetTrainerServiceStepIndex ~= nil and GetTrainerServiceStepIndex() or nil
    if stepButton ~= nil and stepButton:IsShown() and stepIndex ~= nil then
        builder:beginStop("step")
        builder:addItem(
            ControlId.structural("step"),
            nodes.attachHover({
                controlType = graph.controlTypes.button,
                announcements = serviceAnnouncements(stepIndex),
                bindings = {
                    { binding = "leftClick", type = "Click", emulatedKey = "LeftButton", target = stepButton },
                },
            }, stepButton)
        )
    end

    -- The service filter (Available, Unavailable, Already Known), a dropdown of checkboxes on every client. The
    -- game hides unavailable services by default on WoW: Forever, so without this a low level character hears
    -- one service and nothing of what comes later.
    local filter = ClassTrainerFrame.FilterDropdown
    if filter ~= nil and filter:IsShown() then
        builder:beginStop("filter")
        builder:addItem(
            ControlId.forObject(filter),
            nodes.proxyDropdown({ target = filter, label = L["Filter"] })
        )
    end

    builder:beginStop("services")
    if ClassTrainerFrame.ScrollBox ~= nil then
        nodes.scrollBoxList(builder, {
            scrollBox = ClassTrainerFrame.ScrollBox,
            key = "services",
            label = L["Training"],
            id = function(data)
                return ControlId.structural("services:" .. tostring(servicePayload(data).skillIndex))
            end,
            emit = emitService,
        })
    elseif ClassTrainerListScrollFrame ~= nil then
        -- Older clients still on the Faux-style static button pool.
        nodes.hybridScrollList(builder, {
            scrollFrame = ClassTrainerListScrollFrame,
            key = "services",
            label = L["Training"],
            count = function()
                return GetNumTrainerServices()
            end,
            rowHeight = CLASS_TRAINER_SKILL_HEIGHT,
            buttons = function()
                local buttons = {}
                for i = 1, CLASS_TRAINER_SKILLS_DISPLAYED do
                    local button = _G["ClassTrainerSkill" .. i]
                    if button ~= nil then
                        tinsert(buttons, button)
                    end
                end
                return buttons
            end,
            emit = function(emitBuilder, index, helpers)
                emitService(emitBuilder, { skillIndex = index }, index, helpers)
            end,
        })
    else
        builder:pushContext("services", L["Training"])
        builder:addItem(ControlId.structural("services:unsupported"), nodes.text({ label = L["Unavailable"] }))
        builder:popContext()
    end

    renderDetails(builder)

    local trainButton = ClassTrainerFrame.TrainButton or ClassTrainerTrainButton
    if trainButton ~= nil and trainButton:IsShown() then
        builder:beginStop("train")
        builder:addItem(ControlId.forObject(trainButton), nodes.proxyButton({ target = trainButton }))
    end

    builder:popContext()
end

-- The window itself: open while the pet's frame is. WowVision's window manager polls it like the ones its own
-- modules register; Sku, which has its own windows, is left alone as everywhere in WowVision.
function ns.install()
    local manager = WowVision ~= nil and WowVision.UIHost ~= nil and WowVision.UIHost.windowManager or nil
    local windows = WowVision ~= nil and WowVision.WindowManager or nil
    if manager == nil or windows == nil then
        return false
    end
    if manager.getWindow ~= nil and manager:getWindow("beastTraining") ~= nil then
        return true
    end
    local window = windows:CreateWindow("CustomWindow", {
        name = "beastTraining",
        isOpenFunc = function()
            return pet.isActive()
        end,
        conflictingAddons = { "Sku" },
        graphScreen = { render = ns.render },
    })
    manager:RegisterWindow(window)
    return true
end
