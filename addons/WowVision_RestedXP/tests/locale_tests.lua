return function(runner, env)
local loadAddon = env.loadAddon

local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("a")
    f:close()
    return s
end

local CODE = { "Text", "Perf", "Source", "Options", "Menu", "Guidance", "Import", "Game", "Screens", "Main" }

-- Every spoken string the code uses: L["..."] and the labels of the keys.
local function usedKeys()
    local keys = {}
    for _, name in ipairs(CODE) do
        for key in read(env.addonDir .. "/" .. name .. ".lua"):gmatch('L%["(.-)"%]') do
            keys[key] = true
        end
    end
    local main = read(env.addonDir .. "/Main.lua")
    for label in main:gmatch('label = "(.-)",') do
        keys[label] = true
    end
    return keys
end

local function specifiers(text)
    local list = {}
    for spec in text:gmatch("%%[%d%.]*[ds]") do
        list[#list + 1] = spec
    end
    return table.concat(list, ",")
end

runner:addSuite("Locale", {
    ["every spoken string has a French and a German translation"] = function(t)
        local ns = loadAddon({ "Locale" })
        local missing = {}
        for key in pairs(usedKeys()) do
            for _, locale in ipairs({ "frFR", "deDE" }) do
                if ns.translations[locale][key] == nil then
                    missing[#missing + 1] = locale .. ": " .. key
                end
            end
        end
        table.sort(missing)
        t:assertEqual(table.concat(missing, "\n"), "", "untranslated strings")
    end,
    ["no translation is left over"] = function(t)
        local ns = loadAddon({ "Locale" })
        local used = usedKeys()
        local extra = {}
        for _, locale in ipairs({ "frFR", "deDE" }) do
            for key in pairs(ns.translations[locale]) do
                if not used[key] then
                    extra[#extra + 1] = locale .. ": " .. key
                end
            end
        end
        table.sort(extra)
        t:assertEqual(table.concat(extra, "\n"), "", "translations nothing uses")
    end,
    ["a translation keeps the format specifiers of its key"] = function(t)
        local ns = loadAddon({ "Locale" })
        for _, locale in ipairs({ "frFR", "deDE" }) do
            for key, value in pairs(ns.translations[locale]) do
                t:assertEqual(specifiers(value), specifiers(key), locale .. ": " .. key)
            end
        end
    end,
    ["French and German differ from the English"] = function(t)
        local ns = loadAddon({ "Locale" })
        local same = {}
        for _, locale in ipairs({ "frFR", "deDE" }) do
            for key, value in pairs(ns.translations[locale]) do
                if key == value then
                    same[#same + 1] = locale .. ": " .. key
                end
            end
        end
        table.sort(same)
        -- names that are the same word in every language are fine
        local allowed = { ["frFR: RestedXP"] = true, ["deDE: RestedXP"] = true, ["frFR: Guide"] = true, ["deDE: Guide"] = true, ["frFR: Destination"] = true, ["deDE: %s MB"] = true, ["deDE: %s, in %s"] = true }
        local unexpected = {}
        for _, entry in ipairs(same) do
            if not allowed[entry] then
                unexpected[#unexpected + 1] = entry
            end
        end
        t:assertEqual(table.concat(unexpected, "\n"), "")
    end,
    ["an unknown locale reads the English"] = function(t)
        local ns = loadAddon({ "Locale" })
        ns.useLocale("esES")
        t:assertEqual(ns.L["Next step"], "Next step")
        ns.useLocale("frFR")
        t:assertEqual(ns.L["Next step"], "Étape suivante")
        ns.useLocale("deDE")
        t:assertEqual(ns.L["Next step"], "Nächster Schritt")
    end,
})

end
