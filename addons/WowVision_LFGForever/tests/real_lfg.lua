-- The contract with the INSTALLED LFG Forever: this addon reads LFG Forever's frames by the names LFG Forever gives them
-- (it keeps its code private, so a frame's field is all that is reachable). This test reads LFG Forever's real source
-- and checks that every name this addon relies on is still assigned there, in the file that assigns it, and that the
-- two globals it uses are still defined. When LFG Forever changes a name, this says which one. Skipped when LFG Forever
-- is not installed. Usage, from the addon folder: lua tests/real_lfg.lua   (prints "all ok").
local script = arg and arg[0] or "tests/real_lfg.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local lfgDir = os.getenv("LFGFOREVER_DIR") or (addonDir .. "/../LFGForever")

local function readFile(path)
    local f = io.open(path, "rb")
    if f == nil then
        return nil
    end
    local s = f:read("a")
    f:close()
    return s
end

local toc = readFile(lfgDir .. "/LFGForever.toc")
if toc == nil then
    print("skipped: LFG Forever is not installed at " .. lfgDir)
    os.exit(0)
end
print("LFG Forever " .. (toc:match("## Version:%s*([^\r\n]+)") or "?"))

local failures = 0
local function check(label, ok)
    if not ok then
        failures = failures + 1
    end
    print((ok and "ok    " or "FAIL  ") .. label)
end

local sources = {}
local function source(file)
    if sources[file] == nil then
        sources[file] = readFile(lfgDir .. "/core/" .. file .. ".lua") or ""
    end
    return sources[file]
end

local function has(file, text)
    return source(file):find(text, 1, true) ~= nil
end

-- the window and its two panels
check("the window's frame is named LFGForeverFrame", has("window", 'local FRAME_NAME = "LFGForeverFrame"') and has("window", "CreateFrame(\"Frame\", FRAME_NAME, UIParent)"))
check("the window holds its content as frame.Content", has("window", "frame.Content = content"))
check("the content holds the filter panel", has("window", "content.FilterPanel = filter"))
check("the content holds the list panel", has("window", "content.ListPanel = list"))
check("the toggle is the global LFGForever_ToggleWindow", has("slash", "function LFGForever_ToggleWindow()"))

-- the filter panel's controls
for _, name in ipairs({
    "CategoryDropdown", "ActivityDropdown", "SearchButton", "RoleCheckButton", "SettingsGear",
    "GroupSection", "RoleSection", "ClassSection", "MiscellaneousSection",
    "GroupFilterChecks", "PlayerRoleChecks", "PlayerClassChecks",
    "LevelLabel", "LevelRange", "UnselectAllClasses", "SelectAllClasses",
    "ResetFiltersLink", "SaveNewFilterLink", "MyFiltersDropdown",
    "WhispersSection", "WhisperLog", "ClearChatLink", "RatingsSection", "PlayerRatings", "ClearPlayerRatingLink",
    "TabSystem",
}) do
    -- assigned alone, at the end of a line, or as the first of a multiple assignment
    check("the filter panel has panel." .. name, has("filterpanel", "panel." .. name .. " = ") or has("filterpanel", "panel." .. name .. " =\n") or has("filterpanel", "panel." .. name .. ", "))
end
check("the filter panel has the three tab ids", has("filterpanel", "panel.filtersTabID = ") and has("filterpanel", "panel.whispersTabID = ") and has("filterpanel", "panel.ratingsTabID = "))
check("a tab's button is found by panel:GetTabButton(tabID)", has("filterpanel", "panel:GetTabButton(panel.whispersTabID)"))
check("the group class filter is panel.GroupClassDropdown", has("filterpanel_groupclasses", "panel.GroupClassDropdown = dropdown"))
check("the play style row is panel.PlaystyleLabel / PlaystyleDropdown", has("filterpanel_miscellaneous", "panel.PlaystyleLabel = label") and has("filterpanel_miscellaneous", "panel.PlaystyleDropdown = dropdown"))
check("the languages row is panel.LanguagesLabel / LanguagesDropdown", has("filterpanel_miscellaneous", "panel.LanguagesLabel = label") and has("filterpanel_miscellaneous", "panel.LanguagesDropdown = dropdown"))
check("the level boxes are range.MinLevel and range.MaxLevel", has("filterpanel", "range.MinLevel, range.MaxLevel"))

-- a section
for _, field in ipairs({ "section.Title = title", "section.Header = header", "section.Content = content", "section.collapsed = collapsed", "header.Warning = warning" }) do
    check("a section has " .. field, has("filterpanel_shared", field))
end
check("a check box's label is check.Text", has("filterpanel_shared", "check.Text:SetText(role.label)"))
check("the tabs tell which is open by hiding the other sections (TabSystemOwner)", has("filterpanel", "(TabSystemOwner.lua:46-51)"))

-- the results
check("the list panel holds panel.ScrollBox", has("listpanel", "panel.ScrollBox = scrollBox"))
check("the list panel holds panel.SearchingSpinner", has("listpanel", "panel.SearchingSpinner = spinner"))
check("the results are a tree whose headers carry dividerType", has("listpanel", "dataProvider:Insert({ dividerType = dividerType })"))
check("a listing carries its resultID", has("listpanel", "resultID = resultID,"))
check("a row has its Ask to Join and Invite buttons", has("listpanel", "row.LFGFInvite = ") and has("listpanel", "row.LFGFAskToJoin = "))
check("Ask to Join has its Check mark", has("listpanel", "button.Check = check"))
check("the row's right click opens the game's menu", has("listpanel", 'if button ~= "RightButton" then'))
check("a player's data is classFilename, level, areaName and lfgRoles", has("listpanel", "memberInfo.classFilename") and has("listpanel", "memberInfo.level") and has("listpanel", "memberInfo.areaName") and has("listpanel", "memberInfo.lfgRoles"))
check("a group's tally is {TANK, HEALER, DAMAGER}", has("listpanel", 'counts = "TANK"') and has("listpanel", 'counts = "HEALER"') and has("listpanel", 'counts = "DAMAGER"'))
check("a listing's fields are the ones this addon reads", has("listpanel", "info.leaderName") and has("listpanel", "info.activityIDs") and has("listpanel", "info.numMembers") and has("listpanel", "info.comment") and has("listpanel", "info.newPlayerFriendly") and has("listpanel", "info.generalPlaystyle") and has("listpanel", "info.isDelisted") and has("listpanel", "info.hasSelf"))

-- the whispers and the ratings
check("the whisper log holds log.ScrollBox", has("whisperlog", "log.ScrollBox = scrollBox"))
check("a whisper entry is { text, name, classFilename, level }", has("whisperlog", "text = text, name = name,") and has("whisperlog", "classFilename = classFilename, level = level,"))
check("a whisper row has InviteLink, LocationLink, RemoveLink", has("whisperlog", "row.InviteLink = ") and has("whisperlog", "row.LocationLink = ") and has("whisperlog", "row.RemoveLink = "))
check("the ratings hold ratings.ScrollBox", has("playerratings", "ratings.ScrollBox = scrollBox"))
check("an ally entry is { name, classFilename, level, text }", has("playerratings", "name = DisplayName(character),") and has("playerratings", "classFilename = classInfo and classInfo.classFile or nil,") and has("playerratings", "level = character.level,") and has("playerratings", "text = ActivityLine(interaction),"))
check("an ally row has its stars: row.Stars.Buttons and stars.rating", has("playerratings", "row.Stars = stars") and has("playerratings", "stars.Buttons = {}") and has("playerratings", "stars.rating = "))

print(failures == 0 and "all ok" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
