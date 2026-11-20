-- Runs this addon's reading (Loot.lua) over AtlasLoot's REAL data: the ItemDB of each AtlasLoot there is for WoW: Forever
-- (AtlasLootClassic, "AtlasLoot Forever", and AtlasLootContinued) and the loot files its TOC loads for the dungeons and
-- raids, walked as the screen walks them: module, instance, boss, difficulty, entries. Usage, from the addon folder:
-- lua tests/real_data.lua   (prints "all ok" when every check passes). ATLASLOOT_DIR names the folder that holds the
-- AtlasLoot folders (default: next to this addon). An AtlasLoot that is not installed is skipped.
local script = arg and arg[0] or "tests/real_data.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local root = os.getenv("ATLASLOOT_DIR") or (addonDir .. "/..")

unpack = unpack or table.unpack
getfenv = getfenv or function()
    return _G
end
tinsert = table.insert
tremove = table.remove
format = string.format
wipe = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

local failures = 0
local function check(label, ok, extra)
    if not ok then
        failures = failures + 1
    end
    print((ok and "ok    " or "FAIL  ") .. label .. (extra ~= nil and ("  " .. tostring(extra)) or ""))
end

local stub = dofile(testsDir .. "/atlas_stub.lua")(root)
local guarded, exists, read, newAtlas = stub.guarded, stub.exists, stub.read, stub.newAtlas

-- The game, as Loot.lua asks it (the facts about items are not what is tested here).
local game = {
    faction = function()
        return "Alliance"
    end,
    className = function(token)
        return token
    end,
    setName = function(id)
        return "Set " .. id
    end,
    setItems = function(id)
        return { id * 10, id * 10 + 1 }
    end,
}

-- The facts the filters, the upgrades and the sorts ask, invented from the item's number: some items the game has not
-- sent yet, every kind of equip location, Pawn answering in every way, a slot worn or free.
local LOCS = { "INVTYPE_HEAD", "INVTYPE_CHEST", "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_BAG", "", "INVTYPE_RANGED", "INVTYPE_ROBE", "INVTYPE_SHIELD" }
function game.itemInfo(id)
    return {
        id = id,
        name = "Item" .. id,
        link = "item:" .. id,
        quality = 1 + id % 4,
        level = 1 + id % 60,
        minLevel = id % 60,
        classID = id % 3 == 0 and 2 or (id % 3 == 1 and 4 or 0),
        subClassID = id % 5,
        type = "Type" .. (id % 3 == 0 and 2 or (id % 3 == 1 and 4 or 0)),
        subType = "Sub" .. id % 5,
        equipLoc = LOCS[id % #LOCS + 1],
        cached = id % 7 ~= 0,
    }
end
function game.canUse(id)
    return id % 4 ~= 0
end
function game.playerLevel()
    return 40
end
function game.slotName(loc)
    return loc ~= "" and loc or nil
end
function game.qualityName(quality)
    return "Quality" .. quality
end
function game.droprate(_, id)
    return id % 3 ~= 0 and (id % 100) / 2 or nil
end
function game.gearVersion()
    return 0
end
-- the names the search reads: every item has one but each eleventh, which the game has not sent
function game.itemName(id)
    return id % 11 ~= 0 and ("Item" .. id) or nil
end
function game.itemFailed()
    return false
end
function game.requestItem() end
local reported = {}
function game.report(message)
    reported[#reported + 1] = tostring(message)
end
function game.wornSlots(loc)
    if loc == nil or loc == "" or loc == "INVTYPE_BAG" then
        return nil
    elseif loc == "INVTYPE_FINGER" then
        return { { id = 1, level = 30 }, { empty = true } }
    end
    return { { id = 1, level = 30 } }
end
function game.itemLevelOf(ref)
    return type(ref) == "number" and 1 + ref % 60 or nil
end
function game.pawnReady()
    return true
end
-- who judges the upgrades: each test of a table runs with each of the three
game.measure = "pawn"
function game.upgradeMeasure()
    return game.measure
end
function game.judgeReady()
    return true
end
function game.locale()
    return "frFR"
end
-- the Gear Judge answering in every way it can
function game.judgeScore(link)
    local n = tonumber(link:match("%d+"))
    if n % 7 == 0 then
        return nil, "NOT_CACHED"
    elseif n % 5 == 0 then
        return nil, "NOT_USABLE"
    elseif n % 3 == 0 then
        return { upgradePct = (n % 40) / 10 - 1, equipped = n % 11 == 0 }
    elseif n % 2 == 0 then
        return { upgrade = (n % 9) - 4 }
    end
    return { upgradePct = (n % 25) / 2 }
end
function game.pawnUpgrade(link)
    local n = tonumber(link:match("%d+"))
    if n % 5 == 0 then
        return nil
    elseif n % 3 == 0 then
        return false
    elseif n % 2 == 0 then
        return { percent = (n % 40) / 100 }
    end
    return { big = true }
end

local FILTERS = {
    {},
    { classFilter = true },
    { levelFilter = true },
    { upgradesOnly = true },
    { classFilter = true, levelFilter = true, upgradesOnly = true },
    { classFilter = true, slot = "head" },
    { kind = "c4" },
    { kind = "c4s2" },
    { classFilter = true, slot = "head", kind = "c2" },
}
local SORTS = { "default", "level", "upgrade", "slot", "drop", "nonsense" }

-- Every filter, every sort and the slot choices over one real loot table: nothing fails, the filters keep or hide each item
-- exactly once, a sort neither loses nor adds a line, and each item is in one slot group.
local function exercise(Loot, entries, where, problems)
    local total = Loot.count(entries)
    for _, filters in ipairs(FILTERS) do
        local ok, shown, hidden = guarded(Loot.visible, entries, filters, game)
        if not ok then
            problems[#problems + 1] = where .. ": visible: " .. tostring(shown)
        else
            if Loot.count(shown) + hidden ~= total then
                problems[#problems + 1] = where .. ": the filters do not account for every item"
            end
            local headers = #shown - Loot.count(shown)
            for _, sort in ipairs(SORTS) do
                local okS, sorted = guarded(Loot.sort, shown, sort, game)
                if not okS then
                    problems[#problems + 1] = where .. ": sort " .. sort .. ": " .. tostring(sorted)
                elseif #sorted ~= #shown or #sorted - Loot.count(sorted) ~= headers then
                    problems[#problems + 1] = where .. ": sort " .. sort .. " changed the lines"
                end
            end
            for _, entry in ipairs(shown) do
                if entry.kind == "item" then
                    local okD, text = guarded(Loot.describe, entry, filters, game)
                    if not okD or type(text) ~= "string" or text == "" then
                        problems[#problems + 1] = where .. ": describe " .. entry.id .. ": " .. tostring(text)
                    end
                end
            end
        end
    end
    local okC, choices = guarded(Loot.slotChoices, entries, nil, game)
    if not okC then
        problems[#problems + 1] = where .. ": slotChoices: " .. tostring(choices)
        return
    end
    -- each item is of one kind: the sub types the choices list hold every item once
    local okK, kinds = guarded(Loot.kindChoices, entries, nil, game)
    if not okK then
        problems[#problems + 1] = where .. ": kindChoices: " .. tostring(kinds)
    else
        local leaves = 0
        for _, choice in ipairs(kinds) do
            if type(choice.label) ~= "string" or choice.label == "" then
                problems[#problems + 1] = where .. ": a kind without a name: " .. tostring(choice.value)
            elseif choice.value:match("^c%d+s%d+$") then
                local _, hiddenByKind = Loot.visible(entries, { kind = choice.value }, game)
                leaves = leaves + (total - hiddenByKind)
            end
        end
        if leaves ~= total then
            problems[#problems + 1] = where .. ": the kinds hold " .. leaves .. " items of " .. total
        end
    end
    local sum = 0
    for _, choice in ipairs(choices) do
        if choice.value ~= "all" then
            local _, hidden = Loot.visible(entries, { slot = choice.value }, game)
            sum = sum + (total - hidden)
            if type(choice.label) ~= "string" or choice.label == "" then
                problems[#problems + 1] = where .. ": a slot without a name: " .. tostring(choice.value)
            end
        end
    end
    if sum ~= total then
        problems[#problems + 1] = where .. ": the slot groups hold " .. sum .. " items of " .. total
    end
end

-- The files each AtlasLoot's TOC loads for its dungeons and raids (the Forever TOC of AtlasLootClassic, the Camelot TOC of
-- AtlasLootContinued).
local FLAVOURS = {
    {
        name = "AtlasLootClassic",
        current = 1,
        files = { "data.lua", "data-tbc.lua" },
        expect = { instances = 20, bosses = 100, items = 500 },
    },
    {
        name = "AtlasLootContinued",
        current = 4,
        forever = 4,
        files = { "data.lua", "data-forever.lua" },
        expect = { instances = 20, bosses = 100, items = 500 },
    },
}

-- The index, the search and the whole-instance helpers over one module's real data, for every game version it has.
local function exerciseSearch(Loot, atlas, moduleId, data, versions, name, problems)
    for _, version in ipairs(versions) do
        local index = Loot.index(atlas, moduleId, data, version)
        local steps = 0
        while not index.done and steps < 5000 do
            index:step(game, 25)
            steps = steps + 1
        end
        local where = name .. " v" .. version
        if not index.done then
            problems[#problems + 1] = where .. ": the index never finished"
        end
        if index.skipped > 0 then
            problems[#problems + 1] = where .. ": " .. index.skipped .. " bosses left out of the index"
        end
        if #reported > 0 then
            problems[#problems + 1] = where .. ": an error while reading: " .. reported[1]
        end
        local noWhere = 0
        for _, record in ipairs(index.records) do
            if type(Loot.where(record)) ~= "string" or Loot.where(record) == "" or record.entry.kind ~= "item" then
                noWhere = noWhere + 1
            end
        end
        if noWhere > 0 then
            problems[#problems + 1] = where .. ": " .. noWhere .. " records without a place"
        end
        print(format("      %s: index of %d items in %d steps", where, #index.records, steps))
        -- a search finds exactly the items whose name has the words, as long as it does not stop early
        for _, query in ipairs({ "item12", "item1 item2", "ITEM3", "item" }) do
            local words = Loot.words(query)
            local result = Loot.find(index, words, {}, game)
            local expected = 0
            for _, record in ipairs(index.records) do
                local name_ = game.itemName(record.entry.id)
                local all = name_ ~= nil
                for _, word in ipairs(words) do
                    all = all and name_:lower():find(word, 1, true) ~= nil
                end
                if all then
                    expected = expected + 1
                end
            end
            if not result.more and #result.found ~= expected then
                problems[#problems + 1] = where .. ": '" .. query .. "' found " .. #result.found .. ", expected " .. expected
            end
            if result.more and #result.found ~= Loot.SEARCH_SCAN then
                problems[#problems + 1] = where .. ": '" .. query .. "' stopped early at " .. #result.found
            end
            for _, filters in ipairs(FILTERS) do
                local okF, filtered = guarded(Loot.find, index, words, filters, game)
                if not okF then
                    problems[#problems + 1] = where .. ": find with filters: " .. tostring(filtered)
                elseif #filtered.found + filtered.hidden > #index.records then
                    problems[#problems + 1] = where .. ": the filters count more items than there are"
                end
            end
        end
        -- what the screen does at every tick must stay small: one search, with every filter on, once the item facts are kept
        local busy = { classFilter = true, levelFilter = true, upgradesOnly = true }
        local words = Loot.words("item1")
        Loot.find(index, words, busy, game)
        local started = os.clock()
        for _ = 1, 50 do
            Loot.find(index, words, busy, game)
        end
        local perTick = (os.clock() - started) / 50 * 1000
        print(format("      %s: one search costs %.2f ms per tick", where, perTick))
        if perTick > 20 then
            problems[#problems + 1] = where .. ": a search takes " .. perTick .. " ms per tick"
        end
        -- the same item in two places is two records, each with its own place
        local places = {}
        for _, record in ipairs(index.records) do
            local key = record.entry.id .. "|" .. Loot.where(record)
            if places[key] then
                problems[#problems + 1] = where .. ": the same item twice in one place: " .. key
                break
            end
            places[key] = true
        end
    end
    -- the whole-instance helpers, for every instance
    for _, version in ipairs(versions) do
        local okG, groups = guarded(Loot.instances, atlas, moduleId, data, version)
        for _, group in ipairs(okG and groups or {}) do
            for _, instance in ipairs(group.list) do
                local bosses = Loot.instanceBosses(data, instance.key)
                local all = Loot.bosses(data, instance.key)
                if #bosses > #all or (#all > 0 and #bosses == 0) then
                    problems[#problems + 1] = "instanceBosses of " .. tostring(instance.key) .. ": " .. #bosses .. " of " .. #all
                end
                local diffs = Loot.mergeDifficulties(data, instance.key, bosses)
                for position = 2, #diffs do
                    if diffs[position].id <= diffs[position - 1].id then
                        problems[#problems + 1] = "mergeDifficulties of " .. tostring(instance.key) .. " is not in order"
                    end
                end
            end
        end
    end
end

local function walk(flavour)
    local name = flavour.name
    local moduleId = name .. "_DungeonsAndRaids"
    if not exists(root .. "/" .. name .. "/ItemDB/ItemDB.lua") then
        print("skip  " .. name .. " is not installed")
        return
    end
    AtlasLoot = newAtlas(flavour.current, flavour.forever)
    local ALPrivate = {}
    read(root .. "/" .. name .. "/ItemDB/ItemDB.lua")(name, ALPrivate)
    check(name .. ": AtlasLoot's ItemDB loads", AtlasLoot.ItemDB ~= nil)
    for _, file in ipairs(flavour.files) do
        local ok, err = pcall(function()
            read(root .. "/" .. moduleId .. "/" .. file)(moduleId, ALPrivate)
        end)
        check(name .. ": data file " .. file .. " loads", ok, err)
    end

    local ns = {}
    local function loadAddon(file)
        read(addonDir .. "/" .. file .. ".lua")("WowVision_AtlasLoot", ns)
    end
    loadAddon("Locale")
    loadAddon("Game")
    loadAddon("Loot")
    local Loot = ns.Loot
    local atlas = AtlasLoot

    local data = atlas.ItemDB:Get(moduleId)
    check(name .. ": the module is in the ItemDB", data ~= nil)
    if data == nil then
        return
    end
    local versions = Loot.versions(data)
    check(name .. ": has game versions (" .. table.concat(versions, ",") .. ")", #versions >= 1)
    local totals = { instances = 0, bosses = 0, tables = 0, items = 0, headers = 0, errors = 0, loading = 0, emptyBosses = 0 }
    local problems = {}
    for _, version in ipairs(versions) do
        local ok, groups = guarded(Loot.instances, atlas, moduleId, data, version)
        check(name .. " v" .. version .. ": instances are listed", ok, groups)
        for _, group in ipairs(ok and groups or {}) do
            for _, instance in ipairs(group.list) do
                totals.instances = totals.instances + 1
                if instance.name == "" or instance.name == nil then
                    problems[#problems + 1] = "instance without a name: " .. tostring(instance.key)
                end
                local okB, bosses = guarded(Loot.bosses, data, instance.key)
                if not okB then
                    problems[#problems + 1] = "bosses of " .. tostring(instance.key) .. ": " .. tostring(bosses)
                    bosses = {}
                end
                for _, boss in ipairs(bosses) do
                    totals.bosses = totals.bosses + 1
                    Loot.resolve(atlas, moduleId, instance.key, boss.index)
                    local okD, diffs = guarded(Loot.difficulties, data, instance.key, boss.index)
                    if not okD then
                        problems[#problems + 1] = "difficulties of " .. instance.key .. "/" .. boss.index .. ": " .. tostring(diffs)
                        diffs = {}
                    end
                    if #diffs == 0 then
                        totals.emptyBosses = totals.emptyBosses + 1
                    end
                    for _, diff in ipairs(diffs) do
                        local okT, entries, problem, message = guarded(Loot.table, atlas, moduleId, instance.key, boss.index, diff.id, game, boss.npcID)
                        if not okT then
                            problems[#problems + 1] = instance.key .. "/" .. boss.index .. "/" .. diff.id .. ": " .. tostring(entries)
                        elseif problem == "error" then
                            totals.errors = totals.errors + 1
                            problems[#problems + 1] = instance.key .. "/" .. boss.index .. "/" .. diff.id .. ": " .. tostring(message)
                        elseif problem == "loading" then
                            totals.loading = totals.loading + 1
                        else
                            totals.tables = totals.tables + 1
                            for _, measure in ipairs({ "judge", "pawn", "level" }) do
                                game.measure = measure
                                exercise(Loot, entries, instance.key .. "/" .. boss.index .. "/" .. diff.id .. "/" .. measure, problems)
                            end
                            game.measure = "pawn"
                            for _, entry in ipairs(entries) do
                                if entry.kind == "item" then
                                    totals.items = totals.items + 1
                                    if type(entry.id) ~= "number" or entry.id <= 0 or type(entry.pos) ~= "number" then
                                        problems[#problems + 1] = "bad item entry in " .. instance.key .. "/" .. boss.index
                                    end
                                elseif entry.kind == "header" then
                                    totals.headers = totals.headers + 1
                                    if type(entry.name) ~= "string" or entry.name == "" then
                                        problems[#problems + 1] = "empty header in " .. instance.key .. "/" .. boss.index
                                    end
                                else
                                    problems[#problems + 1] = "unknown entry kind in " .. instance.key .. "/" .. boss.index
                                end
                            end
                        end
                    end
                    if #diffs > 0 and Loot.pickDifficulty(diffs, 999) == nil then
                        problems[#problems + 1] = "no difficulty picked for " .. instance.key
                    end
                end
            end
        end
    end
    exerciseSearch(Loot, atlas, moduleId, data, versions, name, problems)
    print(format("      %s: %d instances, %d bosses (%d without a table), %d loot tables, %d items, %d headers, %d errors, %d not loaded", name, totals.instances, totals.bosses, totals.emptyBosses, totals.tables, totals.items, totals.headers, totals.errors, totals.loading))
    for i = 1, math.min(#problems, 15) do
        print("      problem: " .. problems[i])
    end
    check(name .. ": no problem while walking every table (" .. #problems .. ")", #problems == 0)
    check(name .. ": it has instances, bosses and items", totals.instances > flavour.expect.instances and totals.bosses > flavour.expect.bosses and totals.items > flavour.expect.items)
end

for _, flavour in ipairs(FLAVOURS) do
    walk(flavour)
end

print(failures == 0 and "all ok" or (failures .. " failure(s)"))
os.exit(failures == 0 and 0 or 1)
