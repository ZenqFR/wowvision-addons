-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1 or newer). WowVision's REAL graph framework
-- (Builder, KeyGraph, node factories, the scroll box adapter) is loaded from the WowVision folder (or WOWVISION_DIR);
-- LFG Forever's window and the game are stand-ins (tests/world.lua) shaped after LFG Forever's own source, so the
-- screen is built and walked by the real code over the same fields LFG Forever's real frames carry. This addon's files
-- are loaded for real, in the order of the .toc. tests/real_core.lua runs the key and the window against WowVision's
-- real input manager and window classes.
local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local wowVisionDir = os.getenv("WOWVISION_DIR") or (addonDir .. "/../WowVision")

-- ----------------------------------------------------------------- harness

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

local function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function check(value, label)
    if not value then
        error(label or "expected a true value", 2)
    end
end

local function contains(text, part, label)
    if text == nil or not tostring(text):find(part, 1, true) then
        error((label or "text differs") .. ": expected it to contain '" .. part .. "', got " .. tostring(text), 2)
    end
end

local function absent(text, part, label)
    if text ~= nil and tostring(text):find(part, 1, true) then
        error((label or "text differs") .. ": expected it NOT to contain '" .. part .. "', got " .. tostring(text), 2)
    end
end

tinsert = table.insert
tremove = table.remove
unpack = unpack or table.unpack
wipe = wipe or function(t)
    for key in pairs(t) do
        t[key] = nil
    end
    return t
end

local env = dofile(testsDir .. "/graph_env.lua")(wowVisionDir)
local graph = env.graph

local FILES = { "Locale", "Game", "Labels", "Screen", "Main" }

-- ------------------------------------------------------------------- world

-- One start of the game: LFG Forever's window as a stand-in, WowVision's window machinery as far as this addon asks,
-- then this addon's files.
local function newWorld(config)
    config = config or {}
    local w = dofile(testsDir .. "/world.lua")(config)
    GetLocale = function()
        return config.locale or "enUS"
    end
    WowVision.speak = function(_, text)
        w.spoken[#w.spoken + 1] = text
    end

    -- the window machinery of WowVision
    local manager = { windows = {} }
    function manager:getWindow(name)
        return self.windows[name]
    end
    function manager:RegisterWindow(window)
        self.windows[window.name] = window
    end
    w.manager = manager
    WowVision.WindowManager = {
        CreateWindow = function(_, kind, windowConfig)
            local window = { kind = kind, name = windowConfig.name, config = windowConfig }
            w.created = (w.created or 0) + 1
            return window
        end,
    }
    WowVision.UIHost = { windowManager = manager }
    if config.noHost then
        WowVision.UIHost = nil
    end

    -- the keys: a stand-in input manager that records what is created
    w.bindings = {}
    WowVision.input = {
        getBinding = function(_, key)
            return w.bindings[key]
        end,
        createBinding = function(_, info)
            local binding = { info = info, activated = false }
            function binding:activate()
                self.activated = true
            end
            w.bindings[info.key] = binding
            return binding
        end,
        getDefaultDB = function()
            return {}
        end,
    }
    WowVision.dbManager = {
        resolveBindings = function()
            return {}
        end,
    }
    w.applied = 0
    WowVision.applyBindingStore = function()
        w.applied = w.applied + 1
    end
    WowVisionDB = {}
    WowVision.globalDb = {}
    SlashCmdList = {}

    -- the addon
    local ns = {}
    for _, name in ipairs(FILES) do
        local chunk, err = loadfile(addonDir .. "/" .. name .. ".lua")
        if chunk == nil then
            error(err)
        end
        chunk("WowVision_LFGForever", ns)
    end
    w.ns = ns
    if config.locale ~= nil then
        ns.useLocale(config.locale)
    end

    function w:driver()
        return env.driver(function(builder)
            ns.Screen.render(builder)
        end)
    end
    -- every node of the screen, in order, with the stop it belongs to and what it says
    function w:walk()
        local d = self:driver()
        local out = {}
        for _, node in ipairs(d.nodes()) do
            out[#out + 1] = { stop = node.stopKey, text = d.say(node), node = node, vtable = node.vtable }
        end
        return out, d
    end
    return w
end

local function texts(rows, stop)
    local out = {}
    for _, row in ipairs(rows) do
        if stop == nil or row.stop == stop then
            out[#out + 1] = row.text
        end
    end
    return out
end

local function find(rows, start, stop)
    for _, row in ipairs(rows) do
        if (stop == nil or row.stop == stop) and row.text ~= nil and row.text:sub(1, #start) == start then
            return row
        end
    end
    return nil
end

local function stops(rows)
    local out, seen = {}, {}
    for _, row in ipairs(rows) do
        if row.stop ~= nil and not seen[row.stop] then
            seen[row.stop] = true
            out[#out + 1] = row.stop
        end
    end
    return out
end

-- the actions a node's context menu offers: label -> { click = ... }
local function contextActions(vtable)
    local out = {}
    if vtable.contextActions ~= nil then
        vtable.contextActions(function(entry)
            out[#out + 1] = entry
        end)
    end
    return out
end

local function binding(vtable, name)
    for _, spec in ipairs(vtable.bindings or {}) do
        if spec.binding == name then
            return spec
        end
    end
    return nil
end

local function resolve(target)
    if type(target) == "function" then
        return target()
    end
    return target
end

-- ------------------------------------------------------------------ tests

-- a results tree: dividers with the listings under them (listings of a folded divider are not in the flat list)
local function fillResults(w, items)
    local box = w.list.ScrollBox
    box.flat, box.frames, box.scrolled = {}, {}, {}
    w.nodes = {}
    for _, item in ipairs(items) do
        local divider = w.treeNode({ dividerType = item.divider }, item.collapsed)
        box.frames[divider] = w.newFrame({})
        box.flat[#box.flat + 1] = divider
        w.nodes[item.divider] = divider
        for _, row in ipairs(item.rows) do
            local child = w.treeNode({ resultID = row.id })
            divider.children[#divider.children + 1] = child
            w.nodes[row.id] = child
            if not item.collapsed then
                box.flat[#box.flat + 1] = child
                box.frames[child] = w.resultRow(row.kind, row.asked)
            end
        end
    end
end

-- the usual search: two groups and two players
local function usualSearch(w)
    w.group(1, { leaderName = "Thrall", numMembers = 3, comment = "LF healer,  fast\n please" })
    w.counts[1] = { TANK = 1, HEALER = 0, DAMAGER = 2 }
    w.group(2, { leaderName = "Garrosh", numMembers = 5 })
    w.player(3, { leaderName = "Jaina", comment = "Need a dungeon" })
    w.player(4, { leaderName = "Anduin", newPlayerFriendly = true }, {
        classFilename = "PRIEST",
        level = 21,
        areaName = "Duskwood",
        lfgRoles = { tank = false, healer = true, dps = false },
    })
    fillResults(w, {
        { divider = "group", rows = { { id = 1, kind = "group" }, { id = 2, kind = "group", asked = true } } },
        { divider = "solo", rows = { { id = 3, kind = "solo" }, { id = 4, kind = "solo" } } },
    })
end

-- ---- what each line says

test("labels: a group says who leads it, what for, how many and what they are, and the note on one line", function()
    local w = newWorld()
    usualSearch(w)
    eq(w.ns.Labels.listing(1), "Thrall, Deadmines, 3 members (1 Tank, 2 Damage), LF healer, fast please")
    eq(w.ns.Labels.listing(2), "Garrosh, Deadmines, 5 members")
end)

test("labels: a player says level, class, roles, what for, where and the note", function()
    local w = newWorld()
    usualSearch(w)
    eq(w.ns.Labels.listing(3), "Jaina, level 17 Mage, roles: Damage, Deadmines, in Westfall, Need a dungeon")
    eq(w.ns.Labels.listing(4), "Anduin, level 21 Priest, roles: Healer, Deadmines, in Duskwood, welcomes new players")
end)

test("labels: several activities are named up to three, then counted", function()
    local w = newWorld()
    w.activities[101], w.activities[102], w.activities[103] = { fullName = "Wailing Caverns" }, { fullName = "Shadowfang Keep" }, { fullName = "Stockade" }
    w.group(5, { activityIDs = { 100, 101 } })
    contains(w.ns.Labels.listing(5), "Deadmines / Wailing Caverns")
    w.group(6, { activityIDs = { 100, 101, 102, 103 } })
    contains(w.ns.Labels.listing(6), "4 activities")
    absent(w.ns.Labels.listing(6), "Deadmines")
end)

test("labels: a listing says if it is yours, removed, and its play style", function()
    local w = newWorld()
    w.group(7, { hasSelf = true, isDelisted = true, generalPlaystyle = 3 })
    contains(w.ns.Labels.listing(7), "Competitive")
    contains(w.ns.Labels.listing(7), "your own listing")
    contains(w.ns.Labels.listing(7), "listing removed")
end)

test("labels: the game's own words for the headers and the roles are used when it has them", function()
    local w = newWorld()
    LFG_LIST_CATEGORY_GROUPS, LFG_LIST_CATEGORY_SOLO_PLAYERS = "Groupes (jeu)", "Joueurs (jeu)"
    TANK = "Tank (jeu)"
    eq(w.ns.Labels.divider("group", 4), "Groupes (jeu), 4")
    eq(w.ns.Labels.divider("solo"), "Joueurs (jeu)")
    eq(w.ns.Labels.groupRoles({ TANK = 2 }), "2 Tank (jeu)")
end)

test("labels: without the game's words the addon's own are said", function()
    local w = newWorld({ locale = "frFR", gameWords = false })
    TANK, HEALER, DAMAGER = nil, nil, nil
    eq(w.ns.Labels.divider("group", 2), "Groupes, 2")
    eq(w.ns.Labels.divider("solo"), "Joueurs")
    eq(w.ns.Labels.groupRoles({ TANK = 1, HEALER = 1, DAMAGER = 3 }), "1 Tank, 1 Soigneur, 3 Dégâts")
end)

test("labels: what the game keeps secret is left out, never guessed", function()
    local w = newWorld()
    w.group(8, {
        leaderName = w.secret(),
        numMembers = w.secret(),
        activityIDs = w.secret(),
        comment = w.secret(),
        isDelisted = w.secret(),
        hasSelf = w.secret(),
    })
    eq(w.ns.Labels.listing(8), "Group, details unavailable")
    w.group(9, { leaderName = "Rexxar", numMembers = w.secret(), activityIDs = w.secret(), comment = w.secret() })
    eq(w.ns.Labels.listing(9), "Rexxar")
    -- a player whose level and roles are secret
    w.player(10, { leaderName = "Vol'jin" }, { classFilename = w.secret(), level = w.secret(), areaName = w.secret(), lfgRoles = w.secret() })
    eq(w.ns.Labels.listing(10), "Vol'jin, Deadmines")
    -- no listing at all
    eq(w.ns.Labels.listing(404), "Group")
end)

test("labels: a whisper says who wrote it, level and class, and what", function()
    local w = newWorld()
    local Labels = w.ns.Labels
    eq(Labels.whisper({ name = "Aragorn", level = 30, classFilename = "WARRIOR", text = "Hello there" }), "Aragorn, level 30 Warrior: Hello there")
    eq(Labels.whisper({ name = "Aragorn", text = "Hi" }), "Aragorn: Hi")
    eq(Labels.whisper({ name = "Aragorn", text = w.secret() }), "Aragorn: message unavailable")
    eq(Labels.whisper({ name = w.secret(), text = "Hi" }), "Hi")
    eq(Labels.whisper(nil), nil)
end)

test("labels: an ally says who, level and class, what you did together; the stars say their number", function()
    local w = newWorld()
    local Labels = w.ns.Labels
    eq(Labels.ally({ name = "Legolas", level = 40, classFilename = "MAGE", text = "Deadmines, 2 hours ago" }), "Legolas, level 40 Mage, Deadmines, 2 hours ago")
    eq(Labels.ally({}), "Player")
    eq(Labels.rating(2), "rated 2 of 3 stars")
    eq(Labels.rating(nil), "not rated")
    eq(Labels.rating(0), "not rated")
end)

-- ---- the screen

test("screen: nothing of LFG Forever yet, nothing is drawn", function()
    local w = newWorld({ installed = false })
    eq(#w:walk(), 0)
    -- built, but not yet filled with its two panels
    w.install()
    w.frame.Content = nil
    eq(#w:walk(), 0)
end)

test("screen: a closed window draws nothing", function()
    local w = newWorld()
    w.frame:Hide()
    eq(#w:walk(), 0)
end)

test("screen: the stops, in order, with the filters tab open", function()
    local w = newWorld()
    usualSearch(w)
    local rows = w:walk()
    local got = table.concat(stops(rows), " ")
    eq(got, "tabs search results filters:groups filters:roles filters:classes filters:misc options")
end)

test("screen: the tabs say which one is open and follow the tab the window shows", function()
    local w = newWorld()
    local rows = w:walk()
    eq(table.concat(texts(rows, "tabs"), "|"), "Filters, Button, selected, 1 of 3|Whispers, Button, 2 of 3|Player ratings, Button, 3 of 3")
    w.openTab("whispers")
    rows = w:walk()
    contains(find(rows, "Whispers", "tabs").text, "selected")
    absent(find(rows, "Filters", "tabs").text, "selected")
    w.openTab("ratings")
    contains(find(w:walk(), "Player ratings", "tabs").text, "selected")
    eq(w.ns.Screen.currentTab(w.filter), "ratings")
end)

test("screen: the ratings tab is not offered when LFG Forever hides it", function()
    local w = newWorld()
    w.filter.tabButtons[3].shown = false
    local rows = w:walk()
    eq(#texts(rows, "tabs"), 2)
    eq(find(rows, "Player ratings", "tabs"), nil)
end)

test("screen: a tab is a real click on LFG Forever's tab button, in a row", function()
    local w = newWorld()
    local rows = w:walk()
    local tab = find(rows, "Whispers", "tabs")
    local spec = binding(tab.vtable, "leftClick")
    eq(spec.type, "Click")
    check(resolve(spec.target) == w.filter.tabButtons[2], "the click goes to the Whispers tab's button")
    eq(binding(tab.vtable, "rightClick"), nil, "no right click on a tab")
end)

test("screen: the search stop names the menus and clicks the real buttons", function()
    local w = newWorld()
    local rows = w:walk()
    eq(table.concat(texts(rows, "search"), "|"), "Category, Dungeons, Dropdown, 1 of 4|Activity, All activities, Dropdown, 2 of 4|Search, Button, 3 of 4|Role check, Button, 4 of 4")
    local search = find(rows, "Search", "search")
    check(resolve(binding(search.vtable, "leftClick").target) == w.filter.SearchButton)
    -- Enter on a menu opens it
    local category = find(rows, "Category", "search")
    category.vtable.onActivate()
    check(w.filter.CategoryDropdown.menuOpened, "the category menu opened")
end)

test("screen: a menu that shows its own name is not said twice, in the game's words", function()
    local w = newWorld({ locale = "frFR" })
    w.filter.CategoryDropdown.text = "catégorie"
    local rows = w:walk()
    eq(find(rows, "Catégorie", "search").text, "Catégorie, Dropdown, 1 of 4")
end)

test("screen: Search says it is disabled while a search runs, and Role check hides when it does", function()
    local w = newWorld()
    w.filter.SearchButton.enabled = false
    w.filter.RoleCheckButton.shown = false
    local rows = w:walk()
    contains(find(rows, "Search", "search").text, "Disabled")
    eq(find(rows, "Role check", "search"), nil)
end)

test("screen: the first stop is the search, where a first press of Tab lands", function()
    local w = newWorld()
    local _, d = w:walk()
    d.kg:rerender()
    local start = d.kg.current.startKey
    check(start ~= nil, "a start")
    eq(d.kg.current.nodes[start.key].stopKey, "search")
end)

-- ---- the results

test("results: empty before a search, with a word while one runs", function()
    local w = newWorld()
    local rows = w:walk()
    eq(table.concat(texts(rows, "results"), "|"), "Empty")
    w.list.SearchingSpinner.shown = true
    rows = w:walk()
    eq(texts(rows, "results")[1], "Searching, 1 of 2")
end)

test("results: the headers and the listings, one line each, with what Enter does", function()
    local w = newWorld()
    usualSearch(w)
    local rows = w:walk()
    local lines = texts(rows, "results")
    eq(#lines, 6)
    eq(lines[1], "Groups, 2, Button, expanded, 1 of 6")
    eq(lines[2], "Thrall, Deadmines, 3 members (1 Tank, 2 Damage), LF healer, fast please, Button, Ask to join, 2 of 6")
    eq(lines[3], "Garrosh, Deadmines, 5 members, Button, Ask to join, already asked, 3 of 6")
    eq(lines[4], "Players, 2, Button, expanded, 4 of 6")
    eq(lines[5], "Jaina, level 17 Mage, roles: Damage, Deadmines, in Westfall, Need a dungeon, Button, Invite, 5 of 6")
    eq(lines[6], "Anduin, level 21 Priest, roles: Healer, Deadmines, in Duskwood, welcomes new players, Button, Invite, 6 of 6")
end)

test("results: the value 'Ask to join' / 'Invite' is said once the row is drawn", function()
    local w = newWorld()
    usualSearch(w)
    local rows = w:walk()
    local thrall = find(rows, "Thrall", "results")
    local value = thrall.vtable.announcements[2].text()
    eq(value, "Ask to join")
    local jaina = find(rows, "Jaina", "results")
    eq(jaina.vtable.announcements[2].text(), "Invite")
    -- a row not drawn yet says nothing more
    w.list.ScrollBox.frames[w.nodes[1]] = nil
    eq(find(w:walk(), "Thrall", "results").vtable.announcements[2].text(), nil)
end)

test("results: Enter asks a group to take you, invites a player, and the right click is the game's menu", function()
    local w = newWorld()
    usualSearch(w)
    local rows = w:walk()
    local box = w.list.ScrollBox
    local thrall = find(rows, "Thrall", "results")
    local row1 = box.frames[w.nodes[1]]
    check(resolve(binding(thrall.vtable, "leftClick").target) == row1.LFGFAskToJoin, "a group: Ask to Join")
    eq(binding(thrall.vtable, "leftClick").emulatedKey, "LeftButton")
    check(resolve(binding(thrall.vtable, "rightClick").target) == row1, "right click: the row")
    eq(binding(thrall.vtable, "rightClick").emulatedKey, "RightButton")
    local jaina = find(rows, "Jaina", "results")
    local row3 = box.frames[w.nodes[3]]
    check(resolve(binding(jaina.vtable, "leftClick").target) == row3.LFGFInvite, "a player: Invite")
end)

test("results: a listing with no action button (yours, removed) falls back to the row", function()
    local w = newWorld()
    usualSearch(w)
    local box = w.list.ScrollBox
    local row = box.frames[w.nodes[1]]
    row.LFGFAskToJoin.shown = false
    local thrall = find(w:walk(), "Thrall", "results")
    check(resolve(binding(thrall.vtable, "leftClick").target) == row, "the row itself")
end)

test("results: the context menu lists the actions that apply, then the right click menu", function()
    local w = newWorld()
    usualSearch(w)
    local rows = w:walk()
    local box = w.list.ScrollBox
    local function labels(vtable)
        local out = {}
        for _, entry in ipairs(contextActions(vtable)) do
            out[#out + 1] = entry.label
        end
        return table.concat(out, "|")
    end
    eq(labels(find(rows, "Thrall", "results").vtable), "Ask to join|Right click menu")
    eq(labels(find(rows, "Jaina", "results").vtable), "Invite|Right click menu")
    local entry = contextActions(find(rows, "Thrall", "results").vtable)[1]
    check(entry.click.target == box.frames[w.nodes[1]].LFGFAskToJoin)
    eq(entry.click.emulatedKey, "LeftButton")
    local menu = contextActions(find(rows, "Thrall", "results").vtable)[2]
    eq(menu.click.emulatedKey, "RightButton")
end)

test("results: a header folds and unfolds by a real click, and says which", function()
    local w = newWorld()
    usualSearch(w)
    local rows = w:walk()
    local header = find(rows, "Groups", "results")
    local spec = binding(header.vtable, "leftClick")
    check(resolve(spec.target) == w.list.ScrollBox.frames[w.nodes.group])
    eq(spec.emulatedKey, "LeftButton")
    -- folded: its listings are gone from the list and the header says so, with how many it holds
    fillResults(w, {
        { divider = "group", collapsed = true, rows = { { id = 1, kind = "group" }, { id = 2, kind = "group" } } },
        { divider = "solo", rows = { { id = 3, kind = "solo" } } },
    })
    local lines = texts(w:walk(), "results")
    eq(lines[1], "Groups, 2, Button, collapsed, 1 of 3")
    eq(#lines, 3)
end)

test("results: a header is folded or not by its own state, whichever way the tree says it", function()
    local w = newWorld()
    usualSearch(w)
    -- a node that only has the field (no IsCollapsed method), as WowVision's own list reads it
    local node = w.nodes.group
    node.IsCollapsed = nil
    node.collapsed = true
    eq(texts(w:walk(), "results")[1], "Groups, 2, Button, collapsed, 1 of 6")
    node.collapsed = false
    eq(texts(w:walk(), "results")[1], "Groups, 2, Button, expanded, 1 of 6")
end)

test("results: moving to a row scrolls it into view and hovers it, as WowVision's own lists do", function()
    local w = newWorld()
    usualSearch(w)
    local box = w.list.ScrollBox
    local entered = 0
    for _, frame in pairs(box.frames) do
        frame.scripts.OnEnter = function()
            entered = entered + 1
        end
    end
    local thrall = find(w:walk(), "Thrall", "results")
    thrall.vtable.onFocus()
    check(#box.scrolled == 1 and box.scrolled[1] == 2, "scrolled to the second line of the list")
    eq(entered, 1, "the row's own OnEnter ran (it shows the group's tooltip)")
    eq(resolve(thrall.vtable.tooltipFrame), box.frames[w.nodes[1]])
end)

test("results: unreadable listings are still lines, and never an error", function()
    local w = newWorld()
    w.group(1, { leaderName = w.secret(), numMembers = w.secret(), activityIDs = w.secret(), comment = w.secret() })
    fillResults(w, { { divider = "group", rows = { { id = 1, kind = "group" } } } })
    local lines = texts(w:walk(), "results")
    eq(lines[2], "Group, details unavailable, Button, Ask to join, 2 of 2")
    eq(#w.errors, 0)
end)

-- ---- the filters

test("filters: every section is a stop with its header and its controls, read from LFG Forever's own words", function()
    local w = newWorld()
    local rows = w:walk()
    eq(table.concat(texts(rows, "filters:groups"), "|"),
        "Groups, Button, expanded, 1 of 7|Tank role available, Checkbox, Unchecked, 2 of 7|Healer role available, Checkbox, Checked, 3 of 7|Has tank, Checkbox, Unchecked, 4 of 7|No groups with..., Dropdown, 5 of 7|Reset filters, Button, 6 of 7|Save new filter, Button, 7 of 7")
    eq(table.concat(texts(rows, "filters:roles"), "|"),
        "Player roles, Button, expanded, 1 of 6|Tank, Checkbox, Checked, 2 of 6|Healer, Checkbox, Checked, 3 of 6|Damage, Checkbox, Checked, 4 of 6|Player level range, minimum, EditBox, 5 of 6|Player level range, maximum, EditBox, 20, 6 of 6")
    eq(table.concat(texts(rows, "filters:classes"), "|"),
        "Player classes, Button, expanded, 1 of 5|Mage, Checkbox, Checked, 2 of 5|Warrior, Checkbox, Checked, 3 of 5|Unselect all, Button, 4 of 5|Select all, Button, 5 of 5")
    eq(table.concat(texts(rows, "filters:misc"), "|"),
        "Miscellaneous, Button, expanded, 1 of 3|Play style, All, Dropdown, 2 of 3|Languages, English, Dropdown, 3 of 3")
end)

test("filters: a check box is the real one, and the level boxes take typing", function()
    local w = newWorld()
    local rows = w:walk()
    local tank = find(rows, "Tank role available", "filters:groups")
    check(resolve(binding(tank.vtable, "leftClick").target) == w.filter.GroupFilterChecks[1])
    local max = find(rows, "Player level range, maximum", "filters:roles")
    max.vtable.onActivate()
    check(w.filter.LevelRange.MaxLevel.focused, "Enter puts the cursor in the box")
end)

test("filters: a folded section shows its header (and the controls on its title row) only, and its warning", function()
    local w = newWorld()
    local section = w.filter.GroupSection
    section.collapsed = true
    section.Content.shown = false
    section.Header.Warning.shown = true
    w.filter.MyFiltersDropdown.shown = true
    local rows = w:walk()
    eq(table.concat(texts(rows, "filters:groups"), "|"),
        "Groups, Button, collapsed, has changed filters, 1 of 4|Reset filters, Button, 2 of 4|Save new filter, Button, 3 of 4|My filters, Dropdown, 4 of 4")
    eq(find(rows, "Tank role available"), nil)
    -- the header is the real one: a click folds or unfolds it
    check(resolve(binding(find(rows, "Groups", "filters:groups").vtable, "leftClick").target) == section.Header)
    -- the other sections are unaffected
    eq(#texts(rows, "filters:roles"), 6)
end)

test("filters: a section whose content is hidden lists nothing of it, whatever its flag says", function()
    local w = newWorld()
    w.filter.RoleSection.Content.shown = false
    local rows = w:walk()
    eq(table.concat(texts(rows, "filters:roles"), "|"), "Player roles, Button, expanded")
end)

test("filters: the controls only show when LFG Forever shows them", function()
    local w = newWorld()
    w.filter.GroupClassDropdown.shown = false
    w.filter.LevelRange.shown = false
    w.filter.PlaystyleDropdown.shown = false
    local rows = w:walk()
    eq(find(rows, "No groups with"), nil)
    eq(find(rows, "Player level range"), nil)
    eq(find(rows, "Play style"), nil)
    check(find(rows, "Languages") ~= nil)
end)

test("filters: Options holds LFG Forever's settings", function()
    local w = newWorld()
    local rows = w:walk()
    local settings = find(rows, "Settings", "options")
    check(resolve(binding(settings.vtable, "leftClick").target) == w.filter.SettingsGear)
end)

-- ---- whispers and ratings

local function fillWhispers(w)
    local box = w.filter.WhisperLog.ScrollBox
    local entries = {
        { name = "Aragorn", level = 30, classFilename = "WARRIOR", text = "Hello there" },
        { name = "Boromir", text = "Need a hand?" },
    }
    box.flat, box.frames = entries, {}
    for _, entry in ipairs(entries) do
        local row = w.newFrame({})
        row.InviteLink = w.newFrame({ text = "Invite" })
        row.LocationLink = w.newFrame({ text = "Location", shown = false })
        row.RemoveLink = w.newFrame({ text = "Remove" })
        box.frames[entry] = row
    end
    return entries
end

test("whispers: the tab lists the whispers, Enter opens the line's menu, the actions are in its context menu", function()
    local w = newWorld()
    local entries = fillWhispers(w)
    w.openTab("whispers")
    local rows = w:walk()
    eq(table.concat(stops(rows), " "), "tabs search results whispers options")
    eq(table.concat(texts(rows, "whispers"), "|"),
        "Aragorn, level 30 Warrior: Hello there, Button, 1 of 3|Boromir: Need a hand?, Button, 2 of 3|Clear chat, Button, 3 of 3")
    local box = w.filter.WhisperLog.ScrollBox
    local aragorn = find(rows, "Aragorn", "whispers")
    local spec = binding(aragorn.vtable, "leftClick")
    eq(spec.emulatedKey, "RightButton", "Enter is a right click: the menu")
    check(resolve(spec.target) == box.frames[entries[1]])
    local actions = contextActions(aragorn.vtable)
    eq(#actions, 2, "the Location link is hidden, so it is not offered")
    eq(actions[1].label, "Invite")
    eq(actions[2].label, "Remove")
    check(actions[1].click.target == box.frames[entries[1]].InviteLink)
    box.frames[entries[1]].LocationLink.shown = true
    actions = contextActions(find(w:walk(), "Aragorn", "whispers").vtable)
    eq(actions[2].label, "Where is this player")
    -- Clear chat follows the list
    contains(find(rows, "Clear chat", "whispers").text, "Button")
end)

test("whispers: an empty log says it is empty", function()
    local w = newWorld()
    w.openTab("whispers")
    eq(table.concat(texts(w:walk(), "whispers"), "|"), "Empty, 1 of 2|Clear chat, Button, 2 of 2")
end)

local function fillAllies(w)
    local box = w.filter.PlayerRatings.ScrollBox
    local entries = {
        { name = "Legolas", level = 40, classFilename = "MAGE", text = "Deadmines" },
        { name = "Gimli" },
    }
    box.flat, box.frames = entries, {}
    for index, entry in ipairs(entries) do
        local row = w.newFrame({})
        row.Stars = w.newFrame({ rating = index == 1 and 2 or nil, Buttons = { w.newFrame({}), w.newFrame({}), w.newFrame({}) } })
        box.frames[entry] = row
    end
    return entries
end

test("ratings: the tab lists the recent allies with their stars, the stars are in the context menu", function()
    local w = newWorld()
    local entries = fillAllies(w)
    w.openTab("ratings")
    local rows = w:walk()
    eq(table.concat(stops(rows), " "), "tabs search results ratings options")
    eq(table.concat(texts(rows, "ratings"), "|"),
        "Legolas, level 40 Mage, Deadmines, Button, rated 2 of 3 stars, 1 of 3|Gimli, Button, not rated, 2 of 3|Clear a rating, Button, 3 of 3")
    local box = w.filter.PlayerRatings.ScrollBox
    local legolas = find(rows, "Legolas", "ratings")
    local labels, clicks = {}, {}
    for _, entry in ipairs(contextActions(legolas.vtable)) do
        labels[#labels + 1] = entry.label
        clicks[#clicks + 1] = resolve(entry.click.target)
    end
    eq(table.concat(labels, "|"), "Rate 1 star|Rate 2 stars|Rate 3 stars|Right click menu")
    local stars = box.frames[entries[1]].Stars
    check(clicks[1] == stars.Buttons[1] and clicks[2] == stars.Buttons[2] and clicks[3] == stars.Buttons[3], "each star's own button")
    check(clicks[4] == box.frames[entries[1]], "the right click menu: the row")
    eq(binding(legolas.vtable, "leftClick").emulatedKey, "RightButton")
    contains(find(rows, "Clear a rating", "ratings").text, "Button")
end)

test("ratings: the stars of a row that is not drawn yet are not guessed", function()
    local w = newWorld()
    local entries = fillAllies(w)
    w.filter.PlayerRatings.ScrollBox.frames[entries[1]] = nil
    w.openTab("ratings")
    local rows = w:walk()
    eq(find(rows, "Legolas", "ratings").text, "Legolas, level 40 Mage, Deadmines, Button, 1 of 3")
    -- and a click on a star that is not there is nothing
    local entry = contextActions(find(rows, "Legolas", "ratings").vtable)[1]
    eq(resolve(entry.click.target), nil)
    -- a row that is there but not filled yet has no stars: nothing is said of them
    w.filter.PlayerRatings.ScrollBox.frames[entries[1]] = w.newFrame({})
    eq(find(w:walk(), "Legolas", "ratings").text, "Legolas, level 40 Mage, Deadmines, Button, 1 of 3")
    entry = contextActions(find(w:walk(), "Legolas", "ratings").vtable)[1]
    eq(resolve(entry.click.target), nil)
end)

-- ---- a broken part never breaks the others

test("errors: a control that is not what it was expected to be is reported once and the rest is read", function()
    local w = newWorld()
    w.filter.PlayerRoleChecks = {
        setmetatable({}, {
            __index = function()
                error("boom")
            end,
        }),
    }
    local rows = w:walk()
    local rows2 = w:walk()
    eq(#w.errors, 1, "reported once, not on every tick")
    contains(w.errors[1], "player filters")
    contains(w.errors[1], "boom")
    -- what was built before the error stays (the section's header), what it could not build does not
    eq(table.concat(stops(rows), " "), "tabs search results filters:groups filters:roles filters:classes filters:misc options")
    eq(#texts(rows, "filters:roles"), 1)
    eq(#rows2, #rows)
    -- the contexts were closed again: what follows is still inside the window, as a sibling of the sections before
    local mage, settings = find(rows, "Mage", "filters:classes").node, find(rows, "Settings", "options").node
    check(mage.parent ~= nil and mage.parent.parent ~= nil, "inside the window")
    check(mage.parent.parent == settings.parent.parent, "the window's context, not the failed section's")
    local category = find(rows, "Category", "search").node
    check(category.parent.parent == mage.parent.parent, "the same context as the parts before the failure")
end)

-- ---- the window

test("window: registered with WowVision as the window that follows LFG Forever's frame", function()
    local w = newWorld()
    check(w.ns.windowInstalled == true, "installed")
    local window = w.manager:getWindow("lfgForever")
    check(window ~= nil, "registered")
    eq(window.kind, "FrameWindow")
    eq(window.config.frameName, "LFGForeverFrame")
    eq(window.config.conflictingAddons[1], "Sku")
    eq(type(window.config.graphScreen.render), "function")
    eq(window.config.graphScreen.key, "lfgForever")
end)

test("window: registered once, however often", function()
    local w = newWorld()
    check(w.ns.Game.registerWindow(w.ns.Screen.config()) == true)
    check(w.ns.installWindow() == true)
    eq(w.created, 1)
end)

test("window: Escape closes LFG Forever's window with a plain Hide", function()
    local w = newWorld()
    local config = w.manager:getWindow("lfgForever").config.graphScreen
    config.onRequestClose()
    eq(w.frame.hides, 1)
    eq(w.frame:IsShown(), false)
    eq(#w.errors, 0)
    -- the window exists once LFG Forever has built it: before that, Escape does nothing and is no error
    w.uninstall()
    config.onRequestClose()
    eq(#w.errors, 0)
end)

test("window: without WowVision's windows it is not installed and nothing breaks", function()
    local w = newWorld({ noHost = true })
    eq(w.ns.windowInstalled, false)
    eq(w.created, nil)
    eq(#w.errors, 0, "not an error: WowVision is just not there")
end)

test("window: a registration that fails is reported, not raised", function()
    local w = newWorld()
    WowVision.WindowManager.CreateWindow = function()
        error("no such window type")
    end
    w.manager.windows = {}
    eq(w.ns.installWindow(), false)
    contains(w.errors[1], "no such window type")
end)

-- ---- the key and the command

test("key: Alt+Ctrl+G opens LFG Forever, listed in WowVision's Bindings screen", function()
    local w = newWorld({ locale = "frFR" })
    local binding = w.bindings["lfgForever/open"]
    check(binding ~= nil, "created")
    check(binding.activated, "active")
    eq(binding.info.inputs[1], "ALT-CTRL-G")
    eq(binding.info.type, "Function")
    eq(binding.info.interruptSpeech, true)
    eq(binding.info.label, "Ouvrir ou fermer LFG Forever")
    eq(w.applied, 1)
    binding.info.func()
    eq(w.toggled, 1)
    eq(w.frame:IsShown(), false)
    binding.info.func()
    eq(w.toggled, 2)
    eq(w.frame:IsShown(), true)
end)

test("key: not created twice, and nothing happens without WowVision's input manager", function()
    local w = newWorld()
    eq(w.ns.installBindings(), true)
    eq(w.applied, 1, "the second call found it there")
    WowVision.input = nil
    eq(w.ns.installBindings(), false)
end)

test("key: LFG Forever not installed is said, not an error", function()
    local w = newWorld({ installed = false })
    w.bindings["lfgForever/open"].info.func()
    eq(w.spoken[#w.spoken], "LFG Forever is not loaded.")
    eq(#w.errors, 0)
    w.ns.useLocale("deDE")
    SlashCmdList["WVLFG"]("")
    eq(w.spoken[#w.spoken], "LFG Forever ist nicht geladen.")
end)

test("command: /wvlfg opens and closes LFG Forever, help says how", function()
    local w = newWorld()
    local command = SlashCmdList["WVLFG"]
    command("")
    eq(w.toggled, 1)
    command(nil)
    eq(w.toggled, 2)
    for _, word in ipairs({ "help", "aide", "hilfe", "HELP" }) do
        command(word)
    end
    eq(w.toggled, 2, "help opens nothing")
    eq(w.spoken[#w.spoken], "Use /wvlfg to open or close LFG Forever.")
    eq(SLASH_WVLFG1, "/wvlfg")
    eq(SLASH_WVLFG2, "/wvgroupe")
    eq(SLASH_WVLFG3, "/wvgruppe")
end)

test("key: a key that fails is reported once and raises nothing", function()
    local w = newWorld()
    _G.LFGForever_ToggleWindow = function()
        error("key broke")
    end
    local func = w.bindings["lfgForever/open"].info.func
    func()
    func()
    eq(#w.errors, 1)
    contains(w.errors[1], "key broke")
end)

test("locale: a placeholder with no value stays as it is", function()
    local w = newWorld()
    eq(w.ns.fill("{a} and {b}", { a = 1 }), "1 and {b}")
end)

test("command: a command that fails is reported once", function()
    local w = newWorld()
    _G.LFGForever_ToggleWindow = function()
        error("command broke")
    end
    SlashCmdList["WVLFG"]("")
    SlashCmdList["WVLFG"]("")
    eq(#w.errors, 1)
    contains(w.errors[1], "command broke")
end)

-- ---- the words

test("locale: every sentence the code says has its French and its German", function()
    local w = newWorld()
    local used, listed = {}, {}
    for _, name in ipairs(FILES) do
        local f = assert(io.open(addonDir .. "/" .. name .. ".lua", "rb"))
        local source = f:read("a")
        f:close()
        if name ~= "Locale" then
            for key in source:gmatch('L%["([^"]+)"%]') do
                used[key] = true
            end
            -- the keys given in a table and looked up through it, and the key labels of the bindings
            for key in source:gmatch('key = "(%b{}[^"]*)"') do
                used[key] = true
            end
            for key in source:gmatch('key = "({label}[^"]*)"') do
                used[key] = true
            end
            for key in source:gmatch('label = "([^"]+)",') do
                used[key] = true
            end
        end
    end
    for key in pairs(used) do
        for _, locale in ipairs({ "frFR", "deDE" }) do
            check(w.ns.TRANSLATIONS[locale][key] ~= nil, locale .. " lacks: " .. key)
        end
    end
    -- nothing translated that is never said, and both languages have the same sentences
    for locale, table_ in pairs(w.ns.TRANSLATIONS) do
        for key in pairs(table_) do
            listed[key] = true
            local other = locale == "frFR" and "deDE" or "frFR"
            check(w.ns.TRANSLATIONS[other][key] ~= nil, other .. " lacks: " .. key)
        end
    end
    for key in pairs(listed) do
        local found = used[key]
        if not found then
            for _, name in ipairs({ "Screen", "Labels", "Main", "Game" }) do
                local f = assert(io.open(addonDir .. "/" .. name .. ".lua", "rb"))
                local source = f:read("a")
                f:close()
                if source:find('"' .. key:gsub("%p", "%%%0") .. '"') then
                    found = true
                end
            end
        end
        check(found, "translated but never said: " .. key)
    end
end)

test("locale: the placeholders are the same in every language", function()
    local w = newWorld()
    local function holes(text)
        local out = {}
        for name in text:gmatch("{(%w+)}") do
            out[#out + 1] = name
        end
        table.sort(out)
        return table.concat(out, ",")
    end
    for _, locale in ipairs({ "frFR", "deDE" }) do
        for key, value in pairs(w.ns.TRANSLATIONS[locale]) do
            eq(holes(value), holes(key), locale .. ": " .. key)
        end
    end
end)

test("locale: French and German read as the game's language when it is one of them", function()
    local w = newWorld({ locale = "frFR" })
    TANK, HEALER, DAMAGER = "Tank", "Soigneur", "Dégâts" -- the game's own French words for the roles
    usualSearch(w)
    local rows = w:walk()
    contains(find(rows, "Thrall", "results").text, "3 membres (1 Tank, 2 Dégâts)")
    contains(find(rows, "Thrall", "results").text, "Demander à rejoindre")
    eq(texts(rows, "tabs")[1]:sub(1, 7), "Filters")
    w = newWorld({ locale = "deDE" })
    TANK, HEALER, DAMAGER = "Tank", "Heiler", "Schaden"
    usualSearch(w)
    contains(find(w:walk(), "Jaina", "results").text, "Stufe 17 Mage, Rollen: Schaden")
end)

io.write(string.format("%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
