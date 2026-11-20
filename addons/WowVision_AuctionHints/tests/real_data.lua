-- Reads the REAL price data installed with Life on Azeroth Market (LifeOnAzeroth_Data/Data.lua, 16 MB) and checks this
-- addon's reading of it against Market's own: Market's real Core.lua parses the same lines (NS.Ensure) and every price
-- this addon reads straight from the text must be the one Market ends up with, for every item of the house. Skipped
-- when the data is not installed. Usage, from the addon folder: lua tests/real_data.lua   (prints "all ok").
local script = arg and arg[0] or "tests/real_data.lua"
local testsDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local addonDir = testsDir .. "/.."
local dataFile = os.getenv("LOA_DATA_FILE") or (addonDir .. "/../LifeOnAzeroth_Data/Data.lua")
local coreFile = os.getenv("LOA_CORE_FILE") or (addonDir .. "/../LifeOnAzeroth_Market/Core.lua")

local handle = io.open(dataFile, "rb")
if handle == nil then
    print("skipped: " .. dataFile .. " is not installed")
    os.exit(0)
end
handle:close()

tinsert = table.insert
local failures = 0
local function check(label, ok, extra)
    if not ok then
        failures = failures + 1
    end
    print((ok and "ok    " or "FAIL  ") .. label .. (extra ~= nil and ("  " .. tostring(extra)) or ""))
end

-- the game, as little as the two sides need
local NOW = 1795140000
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end, UnregisterEvent = function() end }
end
GetLocale = function()
    return "enUS"
end
GetRealmName = function()
    return "Testrealm"
end
UnitFactionGroup = function()
    return "Horde"
end
pcall = pcall
time = function()
    return NOW
end
InCombatLockdown = function()
    return false
end
geterrorhandler = function()
    return function(err)
        error(err, 0)
    end
end

-- the real data
local chunk = assert(loadfile(dataFile))
chunk()
check("the data loads", type(LOA_DATA) == "table" and type(LOA_DATA.houses) == "table")

-- this addon, text path (Market has not parsed anything yet)
local ns = {}
for _, name in ipairs({ "Locale", "Game", "Market" }) do
    assert(loadfile(addonDir .. "/" .. name .. ".lua"))("WowVision_AuctionHints", ns)
end
local houseKey, own = ns.Market.chooseHouse(LOA_DATA)
check("a house is chosen for a Horde character on a normal realm", houseKey == "1H" and own == true, tostring(houseKey))
local text = LOA_DATA.houses[houseKey].latS
check("the house still has its text, nothing parsed", type(text) == "string" and LOA_DATA.houses[houseKey].lat == nil)
local snapshot = ns.Market.snapshot()
check("a snapshot", snapshot ~= nil and snapshot.house == houseKey and snapshot.own == true)
check("built is the file's date", snapshot.built == LOA_DATA.built, tostring(snapshot.built))
check("the data was not touched", LOA_DATA.houses[houseKey].latS == text and LOA_DATA.houses[houseKey].lat == nil)

-- every id of the text, read by this addon
local mine, ids = {}, {}
for line in text:gmatch("[^\n]+") do
    local id = tonumber(line:match("^(%d+),"))
    if id ~= nil then
        ids[#ids + 1] = id
        mine[id] = snapshot.price(id)
    end
end
print("lines read: " .. #ids)
check("there are thousands of items", #ids > 1000, #ids)

-- Market's own reading of the same lines
local NS = {}
local ok, err = pcall(function()
    assert(loadfile(coreFile))("LifeOnAzeroth_Market", NS)
    NS.Ensure()
end)
check("Market's own Core.lua parses the data", ok, err)
local theirs = LOA_DATA.houses[houseKey].lat
check("Market has parsed the house", type(theirs) == "table")
local different, compared = {}, 0
for _, id in ipairs(ids) do
    local line = theirs[id]
    local typical = line ~= nil and line[1] or nil
    if typical ~= nil and typical <= 0 then
        typical = nil
    end
    compared = compared + 1
    if typical ~= mine[id] then
        different[#different + 1] = id .. ": market " .. tostring(typical) .. ", this addon " .. tostring(mine[id])
    end
end
check("every typical price this addon reads from the text is the one Market parsed (" .. compared .. " items)", #different == 0, table.concat(different, "; "):sub(1, 300))

-- after Market's parse the other path is used: same prices
local afterwards = ns.Market.snapshot()
local mismatches = 0
for _, id in ipairs(ids) do
    if afterwards.price(id) ~= mine[id] then
        mismatches = mismatches + 1
    end
end
check("the same prices once Market has parsed the data (table path)", mismatches == 0, mismatches)

-- how many priced items would pass the rule against the vendor value Market's catalogue holds, for information
local passing, priced = 0, 0
for _, id in ipairs(ids) do
    local entry = LOA_DATA.cat[id]
    local vendor = entry ~= nil and entry[7] or nil
    local price = mine[id]
    if price ~= nil and vendor ~= nil then
        priced = priced + 1
        if vendor == 0 or price * 100 >= vendor * 110 then
            passing = passing + 1
        end
    end
end
print(string.format("for information: %d of %d items with a price and a catalogue vendor value are 10%% or more above it (or have no vendor value)", passing, priced))

print(failures == 0 and "all ok" or (failures .. " FAILED"))
os.exit(failures == 0 and 0 or 1)
