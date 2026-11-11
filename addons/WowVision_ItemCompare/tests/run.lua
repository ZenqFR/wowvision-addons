-- Offline tests: `lua tests/run.lua` from the addon folder (any Lua 5.1+).
--
-- The game is mocked, but WowVision's own tooltip code (Tooltip.lua,
-- TooltipReader.lua, secrets.lua, itemQuality.lua) is loaded for real, so the
-- tests exercise what Space and Shift+Down actually do with the added lines.
-- They need WowVision installed next to this addon (../WowVision).

local script = arg and arg[0] or "tests/run.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local wowVision = addonDir .. "/../WowVision/core"

-- ----------------------------------------------------------------- harness

local passed, failed = 0, 0

-- The game's print is mocked below to capture addon output; the harness
-- keeps the real one.
local function out(text)
    io.write(text, "\n")
end

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        out("FAIL  " .. name .. "\n      " .. tostring(err))
    end
end

local function show(value)
    if type(value) == "table" then
        local parts = {}
        for i, v in ipairs(value) do
            parts[i] = "[" .. i .. "] " .. tostring(v)
        end
        return "{\n        " .. table.concat(parts, "\n        ") .. "\n      }"
    end
    return tostring(value)
end

local function eq(actual, expected, label)
    if type(expected) == "table" then
        local same = type(actual) == "table" and #actual == #expected
        if same then
            for i = 1, #expected do
                if actual[i] ~= expected[i] then
                    same = false
                end
            end
        end
        if not same then
            error((label or "") .. "\n    expected " .. show(expected) .. "\n    got      " .. show(actual), 2)
        end
        return
    end
    if actual ~= expected then
        error((label or "") .. "\n    expected " .. show(expected) .. "\n    got      " .. show(actual), 2)
    end
end

-- ------------------------------------------------------------- game mocks

tinsert = table.insert
format = string.format
strtrim = function(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
SELL_PRICE = "Sell Price"
ITEM_LEVEL = "Item Level %d"
C_CurrencyInfo = { GetCoinText = function() return "" end }

local errors = {}
geterrorhandler = function()
    return function(err)
        errors[#errors + 1] = tostring(err)
    end
end
local printed = {}
print = function(...)
    printed[#printed + 1] = table.concat({ ... }, " ")
end

local function setGlobalStrings(locale)
    if locale == "frFR" then
        ITEM_LEVEL = "Niveau d'objet %d"
        RESISTANCE0_NAME = "Armure"
        ITEM_MOD_STAMINA_SHORT = "Endurance"
        ITEM_MOD_INTELLECT_SHORT = "Intelligence"
        ITEM_MOD_STRENGTH_SHORT = "Force"
        ITEM_MOD_AGILITY_SHORT = "Agilité"
        ITEM_MOD_CRIT_RATING_SHORT = "Critique"
        ITEM_MOD_HASTE_RATING_SHORT = "Hâte"
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Dégâts par seconde"
        EMPTY_SOCKET_BLUE = "Châsse bleue"
        INVTYPE_HEAD = "Tête"
    else
        ITEM_LEVEL = "Item Level %d"
        RESISTANCE0_NAME = "Armor"
        ITEM_MOD_STAMINA_SHORT = "Stamina"
        ITEM_MOD_INTELLECT_SHORT = "Intellect"
        ITEM_MOD_STRENGTH_SHORT = "Strength"
        ITEM_MOD_AGILITY_SHORT = "Agility"
        ITEM_MOD_CRIT_RATING_SHORT = "Critical Strike"
        ITEM_MOD_HASTE_RATING_SHORT = "Haste"
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "Damage Per Second"
        EMPTY_SOCKET_BLUE = "Blue Socket"
        INVTYPE_HEAD = "Head"
    end
    ITEM_QUALITY2_DESC = locale == "frFR" and "Inhabituel" or "Uncommon"
    ITEM_QUALITY3_DESC = locale == "frFR" and "Rare" or "Rare"
end

-- The item database the mocked client answers from.
local DB = {}
local equipped = {}

local function link(id)
    local item = DB[id]
    return "|cff1eff00|Hitem:" .. id .. ":0:0:0|h[" .. item.name .. "]|h|r"
end

local function idOf(itemLink)
    return tonumber(tostring(itemLink):match("item:(%d+)"))
end

local function add(id, name, quality, equipLoc, ilvl, stats)
    DB[id] = { name = name, quality = quality, equipLoc = equipLoc, ilvl = ilvl, stats = stats or {} }
end

C_Item = {
    GetItemInfo = function(itemLink)
        local item = DB[idOf(itemLink)]
        if item == nil then
            return nil
        end
        return item.name, itemLink, item.quality, item.ilvl, 1, "Armor", "Cloth", 1, item.equipLoc
    end,
    GetItemInfoInstant = function(itemLink)
        local item = DB[idOf(itemLink)]
        if item == nil then
            return nil
        end
        return idOf(itemLink), "Armor", "Cloth", item.equipLoc or ""
    end,
    GetDetailedItemLevelInfo = function(itemLink)
        local item = DB[idOf(itemLink)]
        return item and item.ilvl or nil
    end,
    GetItemStats = function(itemLink)
        local item = DB[idOf(itemLink)]
        local copy = {}
        for key, value in pairs(item and item.stats or {}) do
            copy[key] = value
        end
        return copy
    end,
}
GetInventoryItemLink = function(_, slot)
    local id = equipped[slot]
    return id ~= nil and link(id) or nil
end

-- --------------------------------------------------- WowVision (real parts)

local function Class(name, parent)
    local class = { name = name }
    class.__index = class
    if parent ~= nil then
        setmetatable(class, { __index = parent })
    end
    function class:new(...)
        local object = setmetatable({}, class)
        if object.initialize ~= nil then
            object:initialize(...)
        end
        return object
    end
    return class
end

WowVision = {
    Class = Class,
    isSecret = function() return false end,
    utils = { moneyLineText = function() return nil end },
    Registry = { new = function() return { register = function() end, get = function() end } end },
}
function WowVision:getLocale()
    return setmetatable({}, { __index = function(_, key) return key end })
end
local spoken = {}
function WowVision:speak(text)
    spoken[#spoken + 1] = text
end
CreateFrame = function()
    return { SetOwner = function() end, ClearLines = function() end }
end

local function load(path, ...)
    local chunk = assert(loadfile(path))
    return chunk(...)
end

load(wowVision .. "/secrets.lua")
load(wowVision .. "/gameDB/itemQuality.lua")
load(wowVision .. "/ui/tooltip/TooltipReader.lua")
load(wowVision .. "/ui/tooltip/Tooltip.lua")

-- The real hook, before this addon wraps it.
local realAugment = WowVision.items.augmentTooltipLines

-- ------------------------------------------------------ the addon (loaded)

local ns = {}
local function loadAddon()
    load(addonDir .. "/Locale.lua", "WowVision_ItemCompare", ns)
    load(addonDir .. "/Core.lua", "WowVision_ItemCompare", ns)
    load(addonDir .. "/Main.lua", "WowVision_ItemCompare", ns)
end
loadAddon()
local Core = ns.Core
local installedAugment = WowVision.items.augmentTooltipLines

local function use(locale)
    ns.useLocale(locale)
    setGlobalStrings(locale)
end

local function reset()
    DB = {}
    equipped = {}
    errors = {}
    printed = {}
    spoken = {}
    WowVisionItemCompareDB = nil
    PawnGetItemData, PawnIsItemAnUpgrade, PawnCommon, PawnGetSlotsForItemType = nil, nil, nil, nil
    PawnBigUpgradeThreshold = nil
end

-- Lines of a fresh tooltip for an item, through the installed hook.
local function lineTexts(lines)
    local out = {}
    for i, line in ipairs(lines) do
        out[i] = (line[1] or "") .. (line[2] ~= nil and (" | " .. line[2]) or "")
    end
    return out
end

local function augmented(itemLink, rows)
    local lines = {}
    for i, row in ipairs(rows or { { "Un objet" } }) do
        lines[i] = { row[1], row[2] }
    end
    installedAugment(lines, itemLink)
    return lines
end

-- Only what this addon adds: WowVision's own hook adds the quality and item
-- level lines first, so the lines it leaves are the baseline.
local function ours(itemLink, rows)
    local baseline = {}
    for i, row in ipairs(rows or { { "Un objet" } }) do
        baseline[i] = { row[1], row[2] }
    end
    realAugment(baseline, itemLink)
    local full = augmented(itemLink, rows)
    local out = {}
    for i = #baseline + 1, #full do
        out[#out + 1] = full[i][1]
    end
    return out
end

-- ------------------------------------------------------------------ tests

test("the hook is installed once, in front of WowVision's own", function()
    reset()
    eq(ns.installed, true)
    assert(installedAugment ~= realAugment, "augmentTooltipLines was not wrapped")
    assert(WowVision.items.itemCompareInstalled == true)
end)

test("Shift+Down reads the comparison with the equipped item, French", function()
    reset()
    use("frFR")
    add(100, "Casque ancien", 2, "INVTYPE_HEAD", 50, {
        RESISTANCE0_NAME = 120,
        ITEM_MOD_STAMINA_SHORT = 10,
        ITEM_MOD_INTELLECT_SHORT = 4,
    })
    add(101, "Casque neuf", 3, "INVTYPE_HEAD", 55, {
        RESISTANCE0_NAME = 130,
        ITEM_MOD_STAMINA_SHORT = 12,
        ITEM_MOD_CRIT_RATING_SHORT = 8,
    })
    equipped[1] = 100
    eq(ours(link(101), { { "Casque neuf" }, { "Tête" } }), {
        "Comparé à l'objet équipé : Casque ancien, Green",
        "Niveau d'objet : 5 de plus",
        "Armure : 10 de plus",
        "Endurance : 2 de plus",
        "Intelligence : 4 de moins",
        "Critique : 8 de plus",
    })
end)

test("the same comparison in English", function()
    reset()
    use("enUS")
    add(100, "Old Helm", 2, "INVTYPE_HEAD", 50, { RESISTANCE0_NAME = 120 })
    add(101, "New Helm", 3, "INVTYPE_HEAD", 48, { RESISTANCE0_NAME = 118, ITEM_MOD_STAMINA_SHORT = 3 })
    equipped[1] = 100
    eq(ours(link(101), { { "New Helm" }, { "Head" } }), {
        "Compared to equipped: Old Helm, Green",
        "Item level: 2 less",
        "Armor: 2 less",
        "Stamina: 3 more",
    })
end)

test("equal item levels read 'same'; equal stats read 'no difference'", function()
    reset()
    use("enUS")
    add(100, "Helm A", 2, "INVTYPE_HEAD", 50, { RESISTANCE0_NAME = 120 })
    add(101, "Helm B", 2, "INVTYPE_HEAD", 50, { RESISTANCE0_NAME = 120 })
    equipped[1] = 100
    eq(ours(link(101)), {
        "Compared to equipped: Helm A, Green",
        "Item level: same",
        "No difference in stats",
    })
end)

test("decimal stats use a comma in French and a point in English", function()
    reset()
    add(100, "Epee A", 2, "INVTYPE_2HWEAPON", 50, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 40.0 })
    add(101, "Epee B", 2, "INVTYPE_2HWEAPON", 50, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 42.5 })
    equipped[16] = 100
    use("frFR")
    local fr = augmented(link(101))
    eq(fr[#fr][1], "Dégâts par seconde : 2,5 de plus")
    use("enUS")
    local en = augmented(link(101))
    eq(en[#en][1], "Damage Per Second: 2.5 more")
end)

test("the item that is already worn is not compared with itself", function()
    reset()
    use("frFR")
    add(100, "Casque ancien", 2, "INVTYPE_HEAD", 50, { RESISTANCE0_NAME = 120 })
    equipped[1] = 100
    eq(ours(link(100)), {}, "no comparison lines for the worn item")
end)

test("an empty slot is announced", function()
    reset()
    use("frFR")
    add(101, "Casque neuf", 2, "INVTYPE_HEAD", 55, { RESISTANCE0_NAME = 130 })
    eq(ours(link(101)), { "Rien d'équipé à cet emplacement" })
end)

test("rings are compared with both worn rings", function()
    reset()
    use("enUS")
    add(1, "Ring One", 2, "INVTYPE_FINGER", 40, { ITEM_MOD_STAMINA_SHORT = 5 })
    add(2, "Ring Two", 2, "INVTYPE_FINGER", 45, { ITEM_MOD_STAMINA_SHORT = 9 })
    add(3, "Ring New", 3, "INVTYPE_FINGER", 50, { ITEM_MOD_STAMINA_SHORT = 7 })
    equipped[11], equipped[12] = 1, 2
    eq(ours(link(3)), {
        "Slot 1 of 2: Compared to equipped: Ring One, Green",
        "Item level: 10 more",
        "Stamina: 2 more",
        "Slot 2 of 2: Compared to equipped: Ring Two, Green",
        "Item level: 5 more",
        "Stamina: 2 less",
    })
end)

test("reading a worn ring does not announce the empty second ring slot", function()
    reset()
    use("enUS")
    add(1, "Ring One", 2, "INVTYPE_FINGER", 40, { ITEM_MOD_STAMINA_SHORT = 5 })
    equipped[11] = 1
    eq(ours(link(1)), {})
end)

test("a one-hand weapon is compared with the off hand only when it holds a weapon", function()
    reset()
    use("enUS")
    add(10, "Sword A", 2, "INVTYPE_WEAPON", 40, { ITEM_MOD_STRENGTH_SHORT = 5 })
    add(11, "Shield", 2, "INVTYPE_SHIELD", 40, { RESISTANCE0_NAME = 300 })
    add(12, "Sword B", 2, "INVTYPE_WEAPON", 40, { ITEM_MOD_STRENGTH_SHORT = 4 })
    add(13, "Sword New", 3, "INVTYPE_WEAPON", 45, { ITEM_MOD_STRENGTH_SHORT = 6 })
    equipped[16], equipped[17] = 10, 11
    eq(ours(link(13)), {
        "Compared to equipped: Sword A, Green",
        "Item level: 5 more",
        "Strength: 1 more",
    })
    equipped[17] = 12
    local dualWield = ours(link(13))
    eq(#dualWield, 6, "both hands are compared")
    eq(dualWield[1], "Slot 1 of 2: Compared to equipped: Sword A, Green")
    eq(dualWield[4], "Slot 2 of 2: Compared to equipped: Sword B, Green")
end)

test("a two-hander says it also takes off the off hand", function()
    reset()
    use("enUS")
    add(20, "Axe", 2, "INVTYPE_WEAPON", 40, {})
    add(21, "Shield", 2, "INVTYPE_SHIELD", 40, {})
    add(22, "Greatsword", 3, "INVTYPE_2HWEAPON", 50, {})
    equipped[16], equipped[17] = 20, 21
    local lines = augmented(link(22))
    eq(lines[#lines][1], "Also takes off the off hand: Shield, Green")
end)

test("ranged weapons go to the ranged slot Pawn names", function()
    reset()
    use("enUS")
    add(30, "Old Bow", 2, "INVTYPE_RANGED", 30, { ITEM_MOD_AGILITY_SHORT = 5 })
    add(31, "New Bow", 3, "INVTYPE_RANGED", 35, { ITEM_MOD_AGILITY_SHORT = 8 })
    PawnGetSlotsForItemType = function(loc)
        if loc == "INVTYPE_RANGED" then
            return 18
        end
    end
    equipped[18] = 30
    eq(ours(link(31))[1], "Compared to equipped: Old Bow, Green")
end)

test("things that are not gear get nothing", function()
    reset()
    use("enUS")
    add(40, "Healing Potion", 1, nil, nil, {})
    add(41, "Bag", 1, "INVTYPE_BAG", nil, {})
    eq(ours(link(40)), {})
    eq(ours(link(41)), {})
end)

test("an unreadable link leaves the tooltip alone", function()
    reset()
    use("enUS")
    eq(#augmented(nil), 1)
    WowVision.isSecret = function() return true end
    eq(#augmented("item:1"), 1)
    WowVision.isSecret = function() return false end
end)

test("a failing game API does not break the tooltip", function()
    reset()
    use("enUS")
    add(100, "Old Helm", 2, "INVTYPE_HEAD", 50, { RESISTANCE0_NAME = 120 })
    add(101, "New Helm", 3, "INVTYPE_HEAD", 55, { RESISTANCE0_NAME = 130 })
    equipped[1] = 100
    local original = C_Item.GetItemStats
    C_Item.GetItemStats = function() error("boom") end
    local added = ours(link(101))
    C_Item.GetItemStats = original
    eq(added[1], "Compared to equipped: Old Helm, Green")
    eq(#errors, 0)
end)

test("an error inside the addon is reported once, and the tooltip survives", function()
    reset()
    use("enUS")
    local original = Core.getSetting
    Core.getSetting = function() error("settings broke") end
    local lines = augmented("item:1")
    augmented("item:1")
    Core.getSetting = original
    eq(#lines, 1)
    eq(#errors, 1)
end)

-- ---------------------------------------------------------------- Pawn

local function pawnWith(upgrades)
    PawnCommon = { Scales = {} }
    PawnBigUpgradeThreshold = 100
    PawnGetItemData = function(itemLink)
        return { Link = itemLink }
    end
    PawnIsItemAnUpgrade = function()
        return upgrades
    end
end

test("Pawn's upgrade becomes a sentence naming what it replaces", function()
    reset()
    use("frFR")
    add(100, "Casque ancien", 2, "INVTYPE_HEAD", 50, {})
    add(101, "Casque neuf", 3, "INVTYPE_HEAD", 55, {})
    equipped[1] = 100
    pawnWith({
        { ScaleName = "a", LocalizedScaleName = "Chasseur : Précision", PercentUpgrade = 0.123, ExistingItemLink = "item:100:0:0:0" },
    })
    eq(ours(link(101))[1], "Pawn : Chasseur : Précision, amélioration de 12 pour cent, par rapport à Casque ancien, Green")
end)

test("one Pawn sentence per scale, big upgrades without a number", function()
    reset()
    use("enUS")
    add(101, "New Helm", 3, "INVTYPE_HEAD", 55, {})
    pawnWith({
        { ScaleName = "a", LocalizedScaleName = "Hunter: Marksmanship", PercentUpgrade = 0.04 },
        { ScaleName = "b", LocalizedScaleName = "Hunter: Survival", PercentUpgrade = 100 },
    })
    local added = ours(link(101))
    eq(added[1], "Pawn: Hunter: Marksmanship, upgrade of 4 percent")
    eq(added[2], "Pawn: Hunter: Survival, big upgrade")
end)

test("no upgrade, no Pawn sentence; no Pawn, no error", function()
    reset()
    use("enUS")
    add(101, "New Helm", 3, "INVTYPE_HEAD", 55, {})
    pawnWith(nil)
    eq(ours(link(101)), { "Nothing equipped in this slot" })
    PawnGetItemData, PawnIsItemAnUpgrade, PawnCommon = nil, nil, nil
    eq(ours(link(101)), { "Nothing equipped in this slot" })
    eq(#errors, 0)
end)

test("Pawn's own upgrade lines are replaced, its other lines and the item level stay", function()
    reset()
    use("enUS")
    add(101, "New Helm", 3, "INVTYPE_HEAD", 55, {})
    pawnWith({ { ScaleName = "a", LocalizedScaleName = "Mage: Fire", PercentUpgrade = 0.2 } })
    local arrow = "|TInterface\\AddOns\\Pawn\\Textures\\UpgradeArrow:0|t"
    local lines = augmented(link(101), {
        { "New Helm" },
        { "Item Level 55  " .. arrow .. "|cff00ff00+5" },
        { "Head" },
        { " " },
        { "|cff3fc7ebMage: Fire:  " .. arrow .. "|cff00ff00+20% upgrade|r" },
        { "|cff3fc7ebMage: Frost:  12.0  (your best)" },
    })
    local texts = {}
    for i, line in ipairs(lines) do
        texts[i] = line[1]
    end
    for _, text in ipairs(texts) do
        assert(not text:find("Mage: Fire:", 1, true), "Pawn's raw upgrade line was kept: " .. text)
    end
    local keptLevel = false
    for _, text in ipairs(texts) do
        if text:find("Item Level 55", 1, true) and text:find("UpgradeArrow", 1, true) then
            keptLevel = true
        end
    end
    assert(keptLevel, "the item level line lost its text")
    local keptBest = false
    for _, text in ipairs(texts) do
        if text:find("your best", 1, true) then
            keptBest = true
        end
    end
    assert(keptBest, "Pawn's non-upgrade line was removed")
    eq(texts[#texts - 1], "Pawn: Mage: Fire, upgrade of 20 percent")
end)

test("Pawn lines in the right column of a two-column line are replaced too", function()
    reset()
    use("enUS")
    add(101, "New Helm", 3, "INVTYPE_HEAD", 55, {})
    pawnWith({ { ScaleName = "a", LocalizedScaleName = "Mage: Fire", PercentUpgrade = 0.2 } })
    local lines = augmented(link(101), {
        { "New Helm" },
        { "Mage: Fire", "12.0 |TInterface\\AddOns\\Pawn\\Textures\\UpgradeArrow:0|t +20% upgrade" },
    })
    for _, line in ipairs(lines) do
        assert(not (line[2] and line[2]:find("UpgradeArrow", 1, true)), "right column Pawn line was kept")
    end
end)

-- ------------------------------------------------------------- settings

test("each part can be switched off, and back", function()
    reset()
    use("enUS")
    add(100, "Old Helm", 2, "INVTYPE_HEAD", 50, {})
    add(101, "New Helm", 3, "INVTYPE_HEAD", 55, {})
    equipped[1] = 100
    pawnWith({ { ScaleName = "a", LocalizedScaleName = "Mage: Fire", PercentUpgrade = 0.2 } })

    eq(#ours(link(101)), 4, "everything on: one Pawn line, header, item level")

    ns.handleCommand("pawn")
    eq(#ours(link(101)), 3, "Pawn off: comparison only")
    eq(spoken[#spoken], "Pawn summary: off")

    ns.handleCommand("equipped off")
    eq(#ours(link(101)), 0, "both off")
    eq(spoken[#spoken], "Comparison with equipped item: off")

    ns.handleCommand("pawn on")
    ns.handleCommand("equipped on")
    eq(#ours(link(101)), 4, "both back on")
end)

test("/wvcompare alone reports the state; Pawn missing is said", function()
    reset()
    use("frFR")
    ns.handleCommand("")
    eq(spoken[#spoken], "Résumé Pawn : activé. Comparaison avec l'objet équipé : activé. "
        .. "Tapez /wvcompare pawn ou /wvcompare equipped pour activer ou désactiver l'un des deux.")
    ns.handleCommand("pawn off")
    ns.handleCommand("pawn on")
    eq(spoken[#spoken], "Résumé Pawn : activé. Pawn n'est pas chargé, il n'y a donc pas de résumé Pawn.")
end)

test("a saved-variable table replaced after load is still honoured", function()
    reset()
    use("enUS")
    Core.setSetting("equipped", false)
    WowVisionItemCompareDB = { equipped = true }
    eq(Core.getSetting("equipped"), true)
end)

-- --------------------------------- through WowVision's real tooltip reader

local function realTooltip(itemLink, rows)
    local name = "ICTestTooltip"
    for i, row in ipairs(rows) do
        _G[name .. "TextLeft" .. i] = { GetText = function() return row[1] end }
        _G[name .. "TextRight" .. i] = { GetText = function() return row[2] end }
    end
    local frame = {
        GetName = function() return name end,
        NumLines = function() return #rows end,
        GetItem = function() return "x", itemLink end,
        shownMoneyFrames = 0,
    }
    local tooltip = WowVision.Tooltip:new("ic")
    tooltip.activeFrame = frame
    tooltip.tooltipData = {}
    return tooltip
end

local function bagHelm()
    reset()
    use("frFR")
    add(100, "Casque ancien", 2, "INVTYPE_HEAD", 50, { RESISTANCE0_NAME = 120, ITEM_MOD_STAMINA_SHORT = 10 })
    add(101, "Casque neuf", 3, "INVTYPE_HEAD", 55, { RESISTANCE0_NAME = 130, ITEM_MOD_STAMINA_SHORT = 12 })
    equipped[1] = 100
    pawnWith({ { ScaleName = "a", LocalizedScaleName = "Chasseur : Précision", PercentUpgrade = 0.123, ExistingItemLink = "item:100:0:0:0" } })
    local arrow = "|TInterface\\AddOns\\Pawn\\Textures\\UpgradeArrow:0|t"
    return realTooltip(link(101), {
        { "Casque neuf" },
        { "Tête" },
        { "Armure : 130" },
        { " " },
        { "|cffc69b6dChasseur : Précision:  " .. arrow .. "|cff00ff00+12% amélioration|r" },
    })
end

test("Space reads the whole tooltip, Pawn and comparison included", function()
    local tooltip = bagHelm()
    local text = tooltip:getText()
    assert(text:find("Pawn : Chasseur : Précision, amélioration de 12 pour cent, par rapport à Casque ancien", 1, true), text)
    assert(text:find("Comparé à l'objet équipé : Casque ancien", 1, true), text)
    assert(text:find("Niveau d'objet : 5 de plus", 1, true), text)
    assert(text:find("Armure : 10 de plus", 1, true), text)
    assert(text:find("Endurance : 2 de plus", 1, true), text)
    assert(not text:find("UpgradeArrow", 1, true), "raw Pawn text reached the speech: " .. text)
    local pawnAt = text:find("Pawn :", 1, true)
    local compareAt = text:find("Comparé", 1, true)
    assert(pawnAt < compareAt, "Pawn comes before the comparison")
end)

test("Shift+Down steps through the lines one by one, then stops on the last", function()
    local tooltip = bagHelm()
    local heard = {}
    for _ = 1, 20 do
        tooltip:nextLine()
        heard[#heard + 1] = spoken[#spoken]
    end
    eq(heard[1], "Casque neuf", "first press reads the first line")
    -- The added lines come last, in order.
    local last = #heard
    eq(heard[last], "Endurance : 2 de plus", "stops on the last line")
    eq(heard[last - 1], "Endurance : 2 de plus", "and repeats it when pressed again")
    local sequence = {}
    local previous
    for _, line in ipairs(heard) do
        if line ~= previous then
            sequence[#sequence + 1] = line
        end
        previous = line
    end
    local tail = {}
    for i = #sequence - 4, #sequence do
        tail[#tail + 1] = sequence[i]
    end
    eq(tail, {
        "Pawn : Chasseur : Précision, amélioration de 12 pour cent, par rapport à Casque ancien, Green",
        "Comparé à l'objet équipé : Casque ancien, Green",
        "Niveau d'objet : 5 de plus",
        "Armure : 10 de plus",
        "Endurance : 2 de plus",
    })
end)

test("Shift+Up from the start reads the last added line; blank lines are skipped", function()
    local tooltip = bagHelm()
    tooltip:previousLine()
    eq(spoken[#spoken], "Endurance : 2 de plus")
    tooltip:previousLine()
    eq(spoken[#spoken], "Armure : 10 de plus")
    for _, text in ipairs(spoken) do
        assert(text ~= " " and text ~= "", "a blank line was spoken")
    end
end)

test("the addon never leaves an error behind in a normal read", function()
    local tooltip = bagHelm()
    tooltip:getText()
    for _ = 1, 15 do
        tooltip:nextLine()
    end
    eq(#errors, 0, table.concat(errors, "\n"))
end)

-- -------------------------------------------------------------- languages

test("the same comparison in German", function()
    reset()
    use("deDE")
    add(100, "Old Helm", 2, "INVTYPE_HEAD", 50, { RESISTANCE0_NAME = 120 })
    add(101, "New Helm", 3, "INVTYPE_HEAD", 48, { RESISTANCE0_NAME = 118, ITEM_MOD_STAMINA_SHORT = 3 })
    equipped[1] = 100
    local lines = ours(link(101), { { "New Helm" }, { "Head" } })
    eq(#lines, 4)
    assert(lines[1]:find("^Verglichen mit dem angelegten Gegenstand: Old Helm"), lines[1])
    eq(lines[2], "Gegenstandsstufe: 2 weniger")
    eq(lines[3], "Armor: 2 weniger")
    eq(lines[4], "Stamina: 3 mehr")
    use("enUS")
end)

test("German writes its decimals with a comma, like French", function()
    use("deDE")
    eq(ns.usesDecimalComma(), true)
    use("enUS")
    eq(ns.usesDecimalComma(), false)
end)

test("German reads the Pawn sentence and the commands", function()
    reset()
    use("deDE")
    add(100, "Old Helm", 2, "INVTYPE_HEAD", 50, {})
    add(101, "New Helm", 3, "INVTYPE_HEAD", 55, {})
    equipped[1] = 100
    pawnWith({ { ScaleName = "a", LocalizedScaleName = "Magier: Feuer", PercentUpgrade = 0.2 } })
    local lines = ours(link(101))
    eq(lines[1], "Pawn: Magier: Feuer, Verbesserung um 20 Prozent")
    ns.handleCommand("pawn nein")
    eq(spoken[#spoken], "Pawn-Zusammenfassung: aus")
    ns.handleCommand("pawn ja")
    eq(spoken[#spoken], "Pawn-Zusammenfassung: an")
    ns.handleCommand("equipped aus")
    eq(spoken[#spoken], "Vergleich mit dem angelegten Gegenstand: aus")
    ns.handleCommand("equipped an")
    eq(spoken[#spoken], "Vergleich mit dem angelegten Gegenstand: an")
    use("enUS")
end)

-- English is the table the others fall back on; French and German must say every one of its lines in their own words
-- (the few that read the same in all three are listed).
test("every line has a French and a German translation", function()
    local handle = assert(io.open(addonDir .. "/Locale.lua", "rb"))
    local source = handle:read("a")
    handle:close()
    local block = source:match("enUS = {(.-)\n    },")
    local keys = {}
    for key in block:gmatch("\n%s+(%w+)%s*=%s*\"") do
        keys[#keys + 1] = key
    end
    assert(#keys > 20, "the English keys were not found")
    local same = { pawnLine = true, statLine = true, status = true }
    use("enUS")
    local english = {}
    for _, key in ipairs(keys) do
        english[key] = ns.L[key]
    end
    for _, locale in ipairs({ "frFR", "deDE" }) do
        use(locale)
        for _, key in ipairs(keys) do
            local said = ns.L[key]
            assert(said ~= nil, locale .. " has no " .. key)
            if not same[key] then
                assert(said ~= english[key], locale .. " says " .. key .. " in English")
            end
            -- the same % placeholders, in the same number
            local _, wanted = english[key]:gsub("%%[ds]", "")
            local _, got = said:gsub("%%[ds]", "")
            eq(got, wanted, locale .. " " .. key .. " placeholders")
        end
    end
    use("enUS")
end)

test("a language with no translation reads English", function()
    use("esES")
    eq(ns.L.header, "Compared to equipped: %s")
    use("enUS")
end)

-- ------------------------------------------------- when WowVision does it

test("a WowVision that compares items itself is left alone, and the command says so in three languages", function()
    reset()
    local before = WowVision.items.augmentTooltipLines
    WowVision.items.augmentComparisonLines = function() end
    local other = {}
    load(addonDir .. "/Locale.lua", "WowVision_ItemCompare", other)
    load(addonDir .. "/Core.lua", "WowVision_ItemCompare", other)
    load(addonDir .. "/Main.lua", "WowVision_ItemCompare", other)
    WowVision.items.augmentComparisonLines = nil
    eq(other.installed, true)
    eq(other.standsAside, true)
    assert(WowVision.items.augmentTooltipLines == before, "the hook was wrapped again")
    other.useLocale("enUS")
    other.handleCommand("pawn off")
    eq(spoken[#spoken], "WowVision now compares items itself, with its own settings; this addon does nothing.")
    other.useLocale("frFR")
    other.handleCommand("")
    assert(spoken[#spoken]:find("WowVision compare maintenant les objets lui%-même"), spoken[#spoken])
    other.useLocale("deDE")
    other.handleCommand("")
    assert(spoken[#spoken]:find("WowVision vergleicht Gegenstände jetzt selbst"), spoken[#spoken])
    -- and the settings were not touched
    eq(WowVisionItemCompareDB, nil)
end)

test("a WowVision without the tooltip hook says so, in the player's language", function()
    reset()
    local items = WowVision.items
    local hook = items.augmentTooltipLines
    items.augmentTooltipLines = nil
    local other = {}
    load(addonDir .. "/Locale.lua", "WowVision_ItemCompare", other)
    other.useLocale("deDE")
    load(addonDir .. "/Core.lua", "WowVision_ItemCompare", other)
    other.useLocale("deDE")
    -- Main reads the language at load time through L, so set it before Main runs
    local chunk = assert(loadfile(addonDir .. "/Main.lua"))
    chunk("WowVision_ItemCompare", other)
    items.augmentTooltipLines = hook
    eq(other.installed, false)
    eq(printed[#printed], "WowVision_ItemCompare: Der Tooltip-Haken für Gegenstände von WowVision wurde nicht gefunden; es wird nichts hinzugefügt.")
end)

-- ------------------------------------------------------------------ report

out(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
