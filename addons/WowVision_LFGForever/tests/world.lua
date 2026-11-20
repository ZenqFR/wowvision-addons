-- A stand-in for LFG Forever's window and the parts of the game it reads, shaped like the real thing (read from LFG
-- Forever's own source: core/window.lua, core/filterpanel*.lua, core/listpanel.lua, core/whisperlog.lua,
-- core/playerratings.lua): the same fields on the same panels. Usage: local world = dofile("world.lua")(config)
return function(config)
    config = config or {}
    local world = { errors = {}, spoken = {} }

    -- ------------------------------------------------------------ frames
    local Frame = {}
    Frame.__index = Frame

    local function newFrame(fields)
        local frame = setmetatable({ shown = true, enabled = true, scripts = {}, clicks = {} }, Frame)
        for key, value in pairs(fields or {}) do
            frame[key] = value
        end
        return frame
    end
    world.newFrame = newFrame

    function Frame:IsShown()
        return self.shown
    end
    function Frame:IsVisible()
        return self.shown
    end
    function Frame:Show()
        self.shown = true
    end
    function Frame:Hide()
        self.shown = false
        self.hides = (self.hides or 0) + 1
    end
    function Frame:SetShown(value)
        self.shown = value
    end
    function Frame:GetText()
        return self.text
    end
    function Frame:SetText(text)
        self.text = text
    end
    function Frame:IsEnabled()
        return self.enabled
    end
    function Frame:GetChecked()
        return self.checked
    end
    function Frame:GetObjectType()
        return self.objectType or "Button"
    end
    function Frame:GetRegions() end
    function Frame:GetChildren() end
    function Frame:GetScript(kind)
        return self.scripts[kind]
    end
    function Frame:HasScript()
        return true
    end
    function Frame:SetScript(kind, fn)
        self.scripts[kind] = fn
    end
    function Frame:Click(button)
        self.clicks[#self.clicks + 1] = button or "LeftButton"
    end
    function Frame:IsProtected()
        return false
    end
    function Frame:OpenMenu()
        self.menuOpened = true
    end
    function Frame:SetFocus()
        self.focused = true
    end
    function Frame:ClearFocus() end
    function Frame:SetAutoFocus() end
    function Frame:GetName()
        return nil
    end

    local function text(value)
        return newFrame({ text = value })
    end

    -- ------------------------------------------------------- the game
    world.results = {}
    world.activities = {}
    world.members = {}
    world.counts = {}
    local function refuse(what)
        return function()
            error("a secret value cannot be " .. what)
        end
    end
    local secretMeta = {
        __index = refuse("indexed"),
        __len = refuse("measured"),
        __concat = refuse("joined"),
        __lt = refuse("compared"),
        __le = refuse("compared"),
        __call = refuse("called"),
        __tostring = refuse("turned into text"),
    }
    issecretvalue = function(value)
        return type(value) == "table" and getmetatable(value) == secretMeta
    end
    canaccessvalue = function(value)
        return not issecretvalue(value)
    end
    world.secret = function()
        return setmetatable({}, secretMeta)
    end
    C_LFGList = {
        GetSearchResultInfo = function(id)
            return world.results[id]
        end,
        GetSearchResultPlayerInfo = function(id, index)
            return world.members[id] ~= nil and world.members[id][index] or nil
        end,
        GetSearchResultMemberCounts = function(id)
            return world.counts[id]
        end,
        GetActivityInfoTable = function(id)
            return world.activities[id]
        end,
    }
    GetGeneralPlaystyleString = function(playstyle)
        return ({ "Learning", "Relaxed", "Competitive", "Carry" })[playstyle]
    end
    TANK, HEALER, DAMAGER = "Tank", "Healer", "Damage"
    LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", WARRIOR = "Warrior", PRIEST = "Priest" }
    if config.gameWords ~= false then
        LFG_LIST_CATEGORY_GROUPS = "Groups"
        LFG_LIST_CATEGORY_SOLO_PLAYERS = "Players"
    else
        LFG_LIST_CATEGORY_GROUPS = nil
        LFG_LIST_CATEGORY_SOLO_PLAYERS = nil
    end
    ExecuteFrameScript = function(frame, kind)
        local fn = frame:GetScript(kind)
        if fn ~= nil then
            fn(frame)
        end
    end
    geterrorhandler = function()
        return function(err)
            world.errors[#world.errors + 1] = tostring(err)
        end
    end

    -- a group listing and a player listing, as the search returns them
    function world.group(id, fields)
        local info = { leaderName = "Leader" .. id, numMembers = 3, activityIDs = { 100 }, comment = "", age = id }
        for key, value in pairs(fields or {}) do
            info[key] = value
        end
        world.results[id] = info
        world.activities[100] = world.activities[100] or { fullName = "Deadmines" }
        return info
    end
    function world.player(id, fields, member)
        local info = { leaderName = "Player" .. id, numMembers = 1, activityIDs = { 100 }, comment = "", age = id }
        for key, value in pairs(fields or {}) do
            info[key] = value
        end
        world.results[id] = info
        world.activities[100] = world.activities[100] or { fullName = "Deadmines" }
        world.members[id] = { member or { classFilename = "MAGE", level = 17, areaName = "Westfall", lfgRoles = { tank = false, healer = false, dps = true } } }
        return info
    end

    -- ------------------------------------------ the scroll boxes (trees and lists)
    -- A tree node, as the game's tree data provider hands them out.
    local function treeNode(payload, collapsed)
        local node = { payload = payload, collapsed = collapsed == true, children = {} }
        function node:GetData()
            return self.payload
        end
        function node:IsCollapsed()
            return self.collapsed
        end
        function node:GetNodes()
            return self.children
        end
        return node
    end
    world.treeNode = treeNode

    -- A scroll box over a flat list of nodes (what the tree shows: collapsed headers hide their children).
    local function scrollBox(isTree)
        local box = newFrame({ flat = {}, frames = {}, scrolled = {} })
        box.provider = { GetRootNode = isTree and function() return {} end or nil }
        function box.provider:Find(index)
            return box.flat[index]
        end
        function box:GetDataProvider()
            return self.provider
        end
        function box:GetDataProviderSize()
            return #self.flat
        end
        function box:FindElementData(index)
            return self.flat[index]
        end
        function box:ScrollToElementDataIndex(index)
            self.scrolled[#self.scrolled + 1] = index
        end
        function box:FindFrame(node)
            return self.frames[node]
        end
        return box
    end
    world.scrollBox = scrollBox

    -- A drawn row of the results: the row's own two action buttons, as LFG Forever adds them.
    local function resultRow(kind, asked)
        local row = newFrame({})
        row.LFGFAskToJoin = newFrame({ shown = kind == "group" })
        row.LFGFAskToJoin.Check = newFrame({ shown = asked == true })
        row.LFGFInvite = newFrame({ shown = kind == "solo" })
        return row
    end
    world.resultRow = resultRow

    -- ------------------------------------------------------ the window
    local frame = newFrame({})
    local content = newFrame({})
    local filter = newFrame({})
    local list = newFrame({})
    frame.Content = content
    content.FilterPanel = filter
    content.ListPanel = list
    world.frame, world.filter, world.list = frame, filter, list

    filter.CategoryDropdown = newFrame({ text = "Dungeons" })
    filter.ActivityDropdown = newFrame({ text = "All activities" })
    filter.SearchButton = newFrame({ text = "Search" })
    filter.RoleCheckButton = newFrame({ text = "Role check" })
    filter.SettingsGear = newFrame({})

    local function section(title, collapsed)
        local s = newFrame({})
        s.Title = text(title)
        s.Header = newFrame({ text = title })
        s.Header.Warning = newFrame({ shown = false })
        s.Content = newFrame({ shown = collapsed ~= true })
        s.collapsed = collapsed == true
        return s
    end
    local function check(label, checked)
        local c = newFrame({ checked = checked == true, objectType = "CheckButton" })
        c.Text = text(label)
        return c
    end

    filter.GroupSection = section("Groups")
    filter.GroupFilterChecks = { check("Tank role available"), check("Healer role available", true), check("Has tank") }
    filter.GroupClassDropdown = newFrame({ text = "No groups with..." })
    filter.ResetFiltersLink = newFrame({ text = "Reset filters" })
    filter.SaveNewFilterLink = newFrame({ text = "Save new filter" })
    filter.MyFiltersDropdown = newFrame({ text = "My filters", shown = false })

    filter.RoleSection = section("Player roles")
    filter.PlayerRoleChecks = { check("Tank", true), check("Healer", true), check("Damage", true) }
    filter.LevelLabel = text("Player level range")
    filter.LevelRange = newFrame({})
    filter.LevelRange.MinLevel = newFrame({ text = "", objectType = "EditBox" })
    filter.LevelRange.MaxLevel = newFrame({ text = "20", objectType = "EditBox" })

    filter.ClassSection = section("Player classes")
    filter.PlayerClassChecks = { check("Mage", true), check("Warrior", true) }
    filter.UnselectAllClasses = newFrame({ text = "Unselect all" })
    filter.SelectAllClasses = newFrame({ text = "Select all" })

    filter.MiscellaneousSection = section("Miscellaneous")
    filter.PlaystyleLabel = text("Play style")
    filter.PlaystyleDropdown = newFrame({ text = "All" })
    filter.LanguagesLabel = text("Languages")
    filter.LanguagesDropdown = newFrame({ text = "English" })

    filter.WhispersSection = section("Whispers")
    filter.WhispersSection.shown = false
    filter.WhisperLog = newFrame({ ScrollBox = scrollBox(false) })
    filter.ClearChatLink = newFrame({ text = "Clear chat" })
    filter.RatingsSection = section("Player ratings")
    filter.RatingsSection.shown = false
    filter.PlayerRatings = newFrame({ ScrollBox = scrollBox(false) })
    filter.ClearPlayerRatingLink = newFrame({ text = "Clear a rating" })

    filter.filtersTabID, filter.whispersTabID, filter.ratingsTabID = 1, 2, 3
    filter.tabButtons = {
        [1] = newFrame({ tabText = "Filters" }),
        [2] = newFrame({ tabText = "Whispers" }),
        [3] = newFrame({ tabText = "Player ratings" }),
    }
    function filter:GetTabButton(id)
        return self.tabButtons[id]
    end

    list.ScrollBox = scrollBox(true)
    list.SearchingSpinner = newFrame({ shown = false })

    -- which tab is open: LFG Forever hides the content of the others
    function world.openTab(name)
        filter.GroupSection.shown = name == "filters"
        filter.RoleSection.shown = name == "filters"
        filter.ClassSection.shown = name == "filters"
        filter.MiscellaneousSection.shown = name == "filters"
        filter.WhispersSection.shown = name == "whispers"
        filter.RatingsSection.shown = name == "ratings"
    end
    world.openTab("filters")

    -- LFG Forever's window exists once /lfg has been typed, and its toggle is a global
    function world.install()
        _G.LFGForeverFrame = frame
        _G.LFGForever_ToggleWindow = function()
            world.toggled = (world.toggled or 0) + 1
            frame:SetShown(not frame:IsShown())
        end
    end
    function world.uninstall()
        _G.LFGForeverFrame = nil
        _G.LFGForever_ToggleWindow = nil
    end
    world.uninstall()
    if config.installed ~= false then
        world.install()
    end

    return world
end
