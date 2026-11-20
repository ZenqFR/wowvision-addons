-- What AtlasLoot's own files need from the game, just enough to load its REAL ItemDB (ItemDB/ItemDB.lua) and its REAL
-- loot data files outside the game. Usage: local stub = dofile("atlas_stub.lua")(root) where root is the folder that
-- holds the AtlasLoot folders. Returns { newAtlas, read, exists, guarded }.
return function(root)
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

    local AL = setmetatable({}, {
        __index = function(_, key)
            return key
        end,
    })
    GetLocale = function()
        return "enUS"
    end
    UNKNOWN = "Unknown"
    FACTION_HORDE, FACTION_ALLIANCE = "Horde", "Alliance"
    UnitFactionGroup = function()
        return "Alliance"
    end
    C_Map = {
        GetAreaInfo = function(id)
            return "Area " .. tostring(id)
        end,
    }
    CreateFrame = function()
        return setmetatable({}, {
            __index = function()
                return function() end
            end,
        })
    end
    GetFactionInfoByID = function(id)
        return "Faction " .. tostring(id)
    end
    GetAchievementInfo = function(id)
        return id, "Achievement " .. tostring(id)
    end
    for _, name in ipairs({ "DUNGEON", "RAID20", "RAID40", "UNKNOWN", "FACTION", "PVP", "RAID", "COLLECTION", "COLLECTIONS", "WORLD_BOSS", "PERMRECEVENTS", "PRIMPROFESSION", "SECPROFESSION", "CLASSPROFESSION", "SEASONALEVENTS", "REMOVED", "HORDE", "ALLIANCE" }) do
        _G["ATLASLOOT_" .. name .. "_COLOR"] = { 0, 0, 0, 1 }
    end
    ATLASLOOT_IT_FILTERIGNORE, ATLASLOOT_IT_HORDE, ATLASLOOT_IT_ALLIANCE = 900, 901, 902
    ATLASLOOT_IT_AMOUNT1, ATLASLOOT_IT_AMOUNT2 = 903, 904

    local STANDARD = { "Name", "Description", "Extra" }
    local stub = { root = root }

    -- AtlasLoot's global as its files see it. current is the game version (1 Classic, 4 Forever for AtlasLootContinued).
    function stub.newAtlas(current, forever)
        local atlas = {
            Locales = AL,
            IngameLocales = AL,
            CLASSIC_VERSION_NUM = 1,
            BC_VERSION_NUM = 2,
            WRATH_VERSION_NUM = 3,
            RETAIL_VERSION_NUM = 99,
            FOREVER_VERSION_NUM = forever,
            db = { GUI = { selectedGameVersion = current }, ContentPhase = {}, showLvlRange = false },
            Data = {
                ContentPhase = {
                    IsActive = function()
                        return true
                    end,
                    GetActivePhase = function()
                        return 6
                    end,
                },
                AutoSelect = {
                    AddInstanceTable = function() end,
                },
            },
            Loader = {
                IsMapsModuleAviable = function()
                    return false
                end,
            },
            Button = {
                CreateFormatTable = function(_, tab)
                    for i = 1, #STANDARD do
                        tab[#tab + 1] = STANDARD[i]
                    end
                    return tab
                end,
            },
            ReturnForGameVersion = function(classic)
                return classic
            end,
            DIFFICULTY = {},
            Compat = {},
        }
        function atlas:GetGameVersion()
            return current
        end
        local compare = {
            EQ = function(a, b) return a == b end,
            NE = function(a, b) return a ~= b end,
            GT = function(a, b) return a > b end,
            GE = function(a, b) return a >= b end,
            LT = function(a, b) return a < b end,
            LE = function(a, b) return a <= b end,
        }
        for name, fn in pairs(compare) do
            atlas["GameVersion_" .. name] = function(_, version, ret, retFalse)
                if version ~= nil and fn(current, version) then
                    return ret or true
                end
                return retFalse
            end
        end
        for key, short in pairs({ NORMAL = "n", HEROIC = "h", ["10RAID"] = "r10", ["25RAID"] = "r25", ["10RAIDH"] = "r10h", ["25RAIDH"] = "r25h", ["40RAID"] = "r40", ["20RAID"] = "r20" }) do
            atlas.DIFFICULTY[key] = { id = key, short = short, loc = key, key = key }
        end
        return atlas
    end

    function stub.read(path)
        local chunk, err = loadfile(path)
        if chunk == nil then
            error(err)
        end
        return chunk
    end

    function stub.exists(path)
        local f = io.open(path, "rb")
        if f == nil then
            return false
        end
        f:close()
        return true
    end

    -- A call that never returns is a failure, not a hang.
    function stub.guarded(fn, ...)
        debug.sethook(function()
            error("took too long (an endless loop?)", 2)
        end, "", 5000000)
        local results = table.pack(pcall(fn, ...))
        debug.sethook()
        return table.unpack(results, 1, results.n)
    end

    return stub
end
