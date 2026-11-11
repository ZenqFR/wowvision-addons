return function(runner, env)
local loadAddon = env.loadAddon
local fake = env.fake

local FILES = { "Locale", "Text", "Import" }

unpack = unpack or table.unpack

-- A fake RestedXP with its importer, the addon's Import loaded, and RXPData (Battle.net's answer) set as told;
-- always cleans RXPData afterwards.
local function withImport(config, fn)
    config = config or {}
    local ns = loadAddon(FILES)
    -- withImporter puts the importer (and the rest of what RestedXP keeps for it) on the table given
    local holder = {}
    local importer = fake.withImporter(holder, config)
    local saved = rawget(_G, "RXPData")
    if config.connected == false then
        rawset(_G, "RXPData", {})
    else
        rawset(_G, "RXPData", { cache = true })
    end
    local spoken = {}
    local ok, err = pcall(fn, {
        ns = ns,
        Import = ns.Import,
        rxp = holder,
        importer = importer,
        spoken = spoken,
        speak = function(text)
            tinsert(spoken, text)
        end,
    })
    rawset(_G, "RXPData", saved)
    if not ok then
        error(err, 0)
    end
end

runner:addSuite("Import: reading", {
    ["without an importer there is nothing"] = function(t)
        local ns = loadAddon(FILES)
        t:assertNil(ns.Import.importer({}))
        t:assertNil(ns.Import.importer({ guideImporter = {} }))
        t:assertNil(ns.Import.importer(nil))
        t:assertNil(ns.Import.state({}))
    end,
    ["a module that cannot be opened, or cannot import, is not an importer"] = function(t)
        local ns = loadAddon(FILES)
        t:assertNil(ns.Import.importer({ guideImporter = { Open = function() end } }))
        t:assertNil(ns.Import.importer({ guideImporter = { Validate = function() end } }))
        t:assertNotNil(ns.Import.importer({ guideImporter = { Open = function() end, Validate = function() end } }))
    end,
    ["a fresh importer: nothing pasted, not running, Battle.net there, nothing said"] = function(t)
        withImport(nil, function(w)
            local state = w.Import.state(w.rxp)
            t:assertEqual(state.characters, 0)
            t:assertFalse(state.ready)
            t:assertFalse(state.busy)
            t:assertTrue(state.connected)
            t:assertFalse(state.failed)
            t:assertNil(state.current)
            t:assertNil(state.last)
        end)
    end,
    ["a pasted text is ready, with its length"] = function(t)
        withImport(nil, function(w)
            w.importer:paste(string.rep("x", 5000))
            local state = w.Import.state(w.rxp)
            t:assertTrue(state.ready)
            t:assertEqual(state.characters, 5000)
        end)
    end,
    ["the importer says ready but the text is empty: not ready"] = function(t)
        withImport(nil, function(w)
            w.importer.importReady = true
            t:assertFalse(w.Import.state(w.rxp).ready)
        end)
    end,
    ["it is busy while the worker frame shows, or a coroutine runs"] = function(t)
        withImport(nil, function(w)
            w.rxp.workerFrame.shown = true
            t:assertTrue(w.Import.state(w.rxp).busy)
            w.rxp.workerFrame.shown = false
            t:assertFalse(w.Import.state(w.rxp).busy)
            w.importer.importCoroutine = {}
            t:assertTrue(w.Import.state(w.rxp).busy)
        end)
    end,
    ["a worker frame that fails to answer is not busy"] = function(t)
        withImport(nil, function(w)
            w.rxp.workerFrame = { IsShown = function() error("gone") end }
            t:assertFalse(w.Import.state(w.rxp).busy)
            w.rxp.workerFrame = nil
            t:assertFalse(w.Import.state(w.rxp).busy)
        end)
    end,
    ["the progress is read from the importer's progress message"] = function(t)
        withImport(nil, function(w)
            w.importer.gui.progressMessage = "Total guides loaded: 7/12"
            local state = w.Import.state(w.rxp)
            t:assertEqual(state.current, 7)
            t:assertEqual(state.total, 12)
        end)
    end,
    ["an import that ended on an error says so"] = function(t)
        withImport(nil, function(w)
            w.importer.gui.progressError = true
            t:assertTrue(w.Import.state(w.rxp).failed)
        end)
    end,
    ["Battle.net gave no answer: not connected"] = function(t)
        withImport({ connected = false }, function(w)
            t:assertFalse(w.Import.state(w.rxp).connected)
        end)
    end,
    ["no RXPData at all is not connected either"] = function(t)
        withImport(nil, function(w)
            rawset(_G, "RXPData", nil)
            t:assertFalse(w.Import.state(w.rxp).connected)
        end)
    end,
    ["the last message is a sentence: lines joined, codes out, no full stop at the end of a line"] = function(t)
        withImport(nil, function(w)
            w.importer.gui.importStatusHistory = { "|cffff0000Failed integrity check.|r\nSecond line" }
            t:assertEqual(w.Import.state(w.rxp).last, "Failed integrity check. Second line")
        end)
    end,
    ["a sentence with nothing in it is nil"] = function(t)
        local ns = loadAddon(FILES)
        t:assertNil(ns.Import.sentence(nil))
        t:assertNil(ns.Import.sentence(""))
        t:assertNil(ns.Import.sentence("\n |r \n"))
        t:assertNil(ns.Import.sentence("..."))
    end,
})

runner:addSuite("Import: what is said about it", {
    ["the status: nothing pasted"] = function(t)
        withImport(nil, function(w)
            t:assertEqual(w.Import.statusText(w.rxp), "Nothing pasted yet.")
        end)
    end,
    ["the status: ready, with the length"] = function(t)
        withImport(nil, function(w)
            w.importer:paste("abc")
            t:assertEqual(w.Import.statusText(w.rxp), "3 characters pasted, ready to import.")
        end)
    end,
    ["the status: running, with or without the count"] = function(t)
        withImport(nil, function(w)
            w.rxp.workerFrame.shown = true
            t:assertEqual(w.Import.statusText(w.rxp), "Importing the guides.")
            w.importer.gui.progressMessage = "Total guides loaded: 3/12"
            t:assertEqual(w.Import.statusText(w.rxp), "Importing: 3 of 12 guides loaded.")
        end)
    end,
    ["the status: Battle.net out of reach comes before the rest"] = function(t)
        withImport({ connected = false }, function(w)
            w.importer:paste("abc")
            t:assertMatch(w.Import.statusText(w.rxp), "cannot reach Battle.net")
        end)
    end,
    ["the status without an importer"] = function(t)
        local ns = loadAddon(FILES)
        t:assertEqual(ns.Import.statusText({}), "RestedXP has no guide importer.")
    end,
    ["the reasons"] = function(t)
        local ns = loadAddon(FILES)
        t:assertEqual(ns.Import.why("missing"), "RestedXP has no guide importer.")
        t:assertEqual(ns.Import.why("busy"), "An import is already running.")
        t:assertEqual(ns.Import.why("closed"), "RestedXP's import window cannot be opened now.")
        t:assertEqual(ns.Import.why("nothing"), "Nothing has been pasted yet. Paste a guide string first.")
        t:assertMatch(ns.Import.why("offline"), "restart Battle.net")
        t:assertNil(ns.Import.why("failed"))
        t:assertNil(ns.Import.why("whatever"))
    end,
    ["French"] = function(t)
        withImport(nil, function(w)
            w.ns.useLocale("frFR")
            t:assertEqual(w.Import.statusText(w.rxp), "Rien de collé pour le moment.")
            w.importer:paste("abc")
            t:assertEqual(w.Import.statusText(w.rxp), "3 caractères collés, prêt à importer.")
            w.rxp.workerFrame.shown = true
            w.importer.gui.progressMessage = "Total guides loaded: 3/12"
            t:assertEqual(w.Import.statusText(w.rxp), "Import : 3 guides chargés sur 12.")
        end)
    end,
})

runner:addSuite("Import: pasting", {
    ["it opens RestedXP's window and puts the keyboard in its box"] = function(t)
        withImport(nil, function(w)
            local ok = w.Import.beginPaste(w.rxp)
            t:assertTrue(ok)
            t:assertEqual(w.importer.calls.open, 1)
            t:assertTrue(w.importer.widgets.import.shown)
            t:assertTrue(w.importer.widgets.importBox.editBox.focused)
        end)
    end,
    ["a second go works as well"] = function(t)
        withImport(nil, function(w)
            w.Import.beginPaste(w.rxp)
            w.importer:paste("abc")
            t:assertFalse(w.importer.widgets.importBox.editBox.focused)
            t:assertTrue(w.Import.beginPaste(w.rxp))
            t:assertTrue(w.importer.widgets.importBox.editBox.focused)
        end)
    end,
    ["while an import runs the box is left alone"] = function(t)
        withImport(nil, function(w)
            w.rxp.workerFrame.shown = true
            local ok, why = w.Import.beginPaste(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "busy")
            t:assertEqual(w.importer.calls.open, 0)
        end)
    end,
    ["a window that cannot open (combat) gives a reason"] = function(t)
        withImport({ cannotOpen = true }, function(w)
            local ok, why = w.Import.beginPaste(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "closed")
        end)
    end,
    ["a box that refuses the keyboard gives a reason"] = function(t)
        withImport({ noFocus = true }, function(w)
            local ok, why = w.Import.beginPaste(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "closed")
        end)
    end,
    ["an Open that fails gives a reason"] = function(t)
        withImport(nil, function(w)
            w.importer.Open = function()
                error("no")
            end
            local ok, why = w.Import.beginPaste(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "closed")
        end)
    end,
    ["an Open that fails half way leaves the keyboard alone"] = function(t)
        withImport(nil, function(w)
            local open = w.importer.Open
            w.importer.Open = function(self)
                open(self)
                error("late failure")
            end
            local ok, why = w.Import.beginPaste(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "closed")
            t:assertFalse(w.importer.widgets.importBox.editBox.focused)
        end)
    end,
    ["a box without an edit box gives a reason"] = function(t)
        withImport(nil, function(w)
            w.importer.Open = function(self)
                self.widgets.importBox = {}
            end
            local ok, why = w.Import.beginPaste(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "closed")
            w.importer.Open = function(self)
                self.widgets.importBox = { GetEditBox = function() error("no") end }
            end
            ok, why = w.Import.beginPaste(w.rxp)
            t:assertEqual(why, "closed")
            w.importer.Open = function(self)
                self.widgets.importBox = { GetEditBox = function() return {} end }
            end
            ok, why = w.Import.beginPaste(w.rxp)
            t:assertEqual(why, "closed")
        end)
    end,
    ["without an importer"] = function(t)
        local ns = loadAddon(FILES)
        local ok, why = ns.Import.beginPaste({})
        t:assertFalse(ok)
        t:assertEqual(why, "missing")
    end,
    ["the window is put away"] = function(t)
        withImport(nil, function(w)
            w.Import.beginPaste(w.rxp)
            t:assertTrue(w.Import.hide(w.rxp))
            t:assertFalse(w.importer.widgets.import.shown)
        end)
    end,
    ["putting away a window that was never opened does nothing"] = function(t)
        withImport(nil, function(w)
            t:assertFalse(w.Import.hide(w.rxp))
            t:assertFalse(w.Import.hide({}))
        end)
    end,
    ["a window that fails to hide is not an error"] = function(t)
        withImport(nil, function(w)
            w.importer.widgets.import = {
                Hide = function()
                    error("no")
                end,
            }
            t:assertFalse(w.Import.hide(w.rxp))
        end)
    end,
})

runner:addSuite("Import: importing", {
    ["nothing pasted: it says so and does not ask RestedXP"] = function(t)
        withImport(nil, function(w)
            w.Import.beginPaste(w.rxp)
            local ok, why = w.Import.run(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "nothing")
            t:assertEqual(w.importer.calls.validate, 0)
        end)
    end,
    ["a pasted text is imported through RestedXP's own Validate"] = function(t)
        withImport(nil, function(w)
            w.Import.beginPaste(w.rxp)
            w.importer:paste("12|345:abc|678")
            local ok = w.Import.run(w.rxp)
            t:assertTrue(ok)
            t:assertEqual(w.importer.calls.validate, 1)
            t:assertTrue(w.Import.state(w.rxp).busy)
        end)
    end,
    ["while it runs, a second import does not start"] = function(t)
        withImport(nil, function(w)
            w.Import.beginPaste(w.rxp)
            w.importer:paste("12|345:abc|678")
            w.Import.run(w.rxp)
            local ok, why = w.Import.run(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "busy")
            t:assertEqual(w.importer.calls.validate, 1)
        end)
    end,
    ["a text RestedXP refuses: false, failed, with its message"] = function(t)
        withImport({ importError = "Failed integrity check" }, function(w)
            w.Import.beginPaste(w.rxp)
            w.importer:paste("garbage")
            local ok, why, message = w.Import.run(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "failed")
            t:assertEqual(message, "Failed integrity check")
        end)
    end,
    ["a Validate that blows up: false, error, with the error"] = function(t)
        withImport({ validateRaises = true }, function(w)
            w.Import.beginPaste(w.rxp)
            w.importer:paste("garbage")
            local ok, why, message = w.Import.run(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "error")
            t:assertMatch(message, "validation blew up")
        end)
    end,
    ["Battle.net out of reach: RestedXP is asked once more, then it says offline"] = function(t)
        withImport({ connected = false }, function(w)
            w.Import.beginPaste(w.rxp)
            w.importer:paste("12|345:abc|678")
            local ok, why = w.Import.run(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "offline")
            t:assertEqual(w.importer.calls.battleNet, 1)
            t:assertEqual(w.importer.calls.validate, 0)
        end)
    end,
    ["Battle.net answering the second time lets the import go"] = function(t)
        withImport({ connected = false, answers = true }, function(w)
            w.Import.beginPaste(w.rxp)
            w.importer:paste("12|345:abc|678")
            local ok = w.Import.run(w.rxp)
            t:assertTrue(ok)
            t:assertEqual(w.importer.calls.validate, 1)
        end)
    end,
    ["an importer with no Battle.net query is just offline"] = function(t)
        withImport({ connected = false }, function(w)
            w.importer.CheckBattleNet = nil
            w.Import.beginPaste(w.rxp)
            w.importer:paste("12|345:abc|678")
            local _, why = w.Import.run(w.rxp)
            t:assertEqual(why, "offline")
        end)
    end,
    ["without its window's widgets it says closed"] = function(t)
        withImport(nil, function(w)
            w.importer.importReady = true
            w.importer.importCache.bufferString = "abc"
            local ok, why = w.Import.run(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "closed")
        end)
    end,
    ["without an importer"] = function(t)
        local ns = loadAddon(FILES)
        local ok, why = ns.Import.run({})
        t:assertFalse(ok)
        t:assertEqual(why, "missing")
    end,
})

local function guideSpecs()
    return {
        { key = "RXP Leveling|Horde|10-20 Barrens", imported = true, group = "RXP Leveling", version = 4 },
        { key = "RXP Leveling||01-10 Durotar", imported = true, group = "RXP Leveling", version = 7 },
        { key = "Mine|Alts|Alt run", cache = true, group = "Mine" },
        { key = "RXPGuides||Built in", imported = true, group = "RXPGuides" },
        { key = "Standard||From a file", group = "Standard" },
    }
end

runner:addSuite("Import: the guides already imported", {
    ["only imported or saved guides, sorted by place then name"] = function(t)
        withImport({ guides = guideSpecs() }, function(w)
            local list = w.Import.guides(w.rxp)
            t:assertEqual(#list, 3)
            t:assertEqual(list[1].key, "Mine|Alts|Alt run")
            t:assertEqual(list[2].key, "RXP Leveling||01-10 Durotar")
            t:assertEqual(list[3].key, "RXP Leveling|Horde|10-20 Barrens")
        end)
    end,
    ["a label reads the name, the place and the version"] = function(t)
        withImport({ guides = guideSpecs() }, function(w)
            local list = w.Import.guides(w.rxp)
            t:assertEqual(list[1].label, "Alt run, in Mine/Alts")
            t:assertEqual(list[2].label, "01-10 Durotar, in RXP Leveling, version 7")
            t:assertEqual(list[3].label, "10-20 Barrens, in RXP Leveling/Horde, version 4")
            t:assertEqual(list[3].name, "10-20 Barrens")
            t:assertEqual(list[3].place, "RXP Leveling/Horde")
        end)
    end,
    ["in the same place the guides are sorted by name"] = function(t)
        withImport({
            guides = {
                { key = "Same||B second", imported = true },
                { key = "Same||a first", imported = true },
                { key = "Same||c third", imported = true },
            },
        }, function(w)
            local names = {}
            for _, guide in ipairs(w.Import.guides(w.rxp)) do
                names[#names + 1] = guide.name
            end
            t:assertEqual(table.concat(names, ","), "a first,B second,c third")
        end)
    end,
    ["RestedXP's own group is shown only in debug"] = function(t)
        withImport({ guides = guideSpecs(), debug = true }, function(w)
            t:assertEqual(#w.Import.guides(w.rxp), 4)
        end)
    end,
    ["colour codes in a name do not reach the speech"] = function(t)
        withImport({ guides = { { key = "|cffff0000Red|r||Name", imported = true } } }, function(w)
            local list = w.Import.guides(w.rxp)
            t:assertEqual(list[1].place, "Red")
        end)
    end,
    ["a key that is not of the three parts is left out"] = function(t)
        withImport({ guides = { { key = "no parts", imported = true } } }, function(w)
            t:assertEqual(#w.Import.guides(w.rxp), 0)
        end)
    end,
    ["removed guides (replaced by the empty guide) are gone from the list"] = function(t)
        withImport({ guides = guideSpecs() }, function(w)
            w.rxp.RemoveGuide("Mine|Alts|Alt run")
            t:assertEqual(#w.Import.guides(w.rxp), 2)
        end)
    end,
    ["nothing imported: an empty list; no guides table: an empty list"] = function(t)
        withImport(nil, function(w)
            t:assertEqual(#w.Import.guides(w.rxp), 0)
            t:assertEqual(#w.Import.guides({}), 0)
            t:assertEqual(#w.Import.guides(nil), 0)
        end)
    end,
    ["French label"] = function(t)
        withImport({ guides = guideSpecs() }, function(w)
            w.ns.useLocale("frFR")
            t:assertEqual(w.Import.guides(w.rxp)[2].label, "01-10 Durotar, dans RXP Leveling, version 7")
        end)
    end,
})

runner:addSuite("Import: removing guides", {
    ["a guide is removed through RestedXP's own function, and its saved copies with it"] = function(t)
        local saved = {
            ["RXP Leveling||01-10 Durotar|1"] = { key = "RXP Leveling||01-10 Durotar" },
            ["RXP Leveling||01-10 Durotar|2"] = { key = "RXP Leveling||01-10 Durotar" },
            ["RXP Leveling||01-10 Durotar"] = {},
            ["Mine|Alts|Alt run|3"] = { key = "Mine|Alts|Alt run" },
        }
        withImport({ guides = guideSpecs(), saved = saved }, function(w)
            w.importer.gui.selectedDeleteGuide = "something"
            t:assertTrue(w.Import.remove(w.rxp, "RXP Leveling||01-10 Durotar"))
            t:assertEqual(w.rxp.removed[1], "RXP Leveling||01-10 Durotar")
            t:assertNil(saved["RXP Leveling||01-10 Durotar|1"])
            t:assertNil(saved["RXP Leveling||01-10 Durotar|2"])
            t:assertNil(saved["RXP Leveling||01-10 Durotar"])
            t:assertNotNil(saved["Mine|Alts|Alt run|3"])
            t:assertEqual(w.importer.gui.selectedDeleteGuide, "")
            t:assertEqual(w.importer.calls.refresh, 1)
        end)
    end,
    ["a guide RestedXP does not know changes nothing"] = function(t)
        local saved = { ["Other|x|y|1"] = { key = "Other|x|y" } }
        withImport({ guides = guideSpecs(), saved = saved }, function(w)
            t:assertFalse(w.Import.remove(w.rxp, "Other|x|y"))
            t:assertNotNil(saved["Other|x|y|1"])
        end)
    end,
    ["RestedXP's function failing is not an error"] = function(t)
        withImport({ guides = guideSpecs() }, function(w)
            w.rxp.RemoveGuide = function()
                error("no")
            end
            t:assertFalse(w.Import.remove(w.rxp, "Mine|Alts|Alt run"))
        end)
    end,
    ["no key, no function, no importer"] = function(t)
        withImport({ guides = guideSpecs() }, function(w)
            t:assertFalse(w.Import.remove(w.rxp, nil))
            w.rxp.RemoveGuide = nil
            t:assertFalse(w.Import.remove(w.rxp, "Mine|Alts|Alt run"))
            t:assertFalse(w.Import.remove({}, "x"))
        end)
    end,
    ["without saved data the guide still leaves the lists"] = function(t)
        withImport({ guides = guideSpecs() }, function(w)
            w.rxp.db = nil
            t:assertTrue(w.Import.remove(w.rxp, "Mine|Alts|Alt run"))
        end)
    end,
    ["purge empties the saved guides and what RestedXP keeps about the quests"] = function(t)
        withImport({ guides = guideSpecs(), saved = { a = {}, b = {} } }, function(w)
            t:assertTrue(w.Import.purge(w.rxp))
            t:assertNil(next(w.rxp.db.profile.guides))
            t:assertNil(next(w.rxp.settings.profile.skipQuest))
            t:assertNil(next(w.rxp.settings.profile.questPrio))
            t:assertNil(next(w.rxp.settings.profile.questPrioIndex))
            t:assertNil(w.rxp.db.profile.guideId)
            t:assertNil(w.rxp.db.profile.guideLength)
            t:assertNil(w.rxp.db.profile.guideContent)
            t:assertEqual(#w.rxp.metaDataCalls, 1)
            t:assertTrue(w.rxp.metaDataCalls[1])
            t:assertEqual(w.importer.calls.refresh, 1)
        end)
    end,
    ["purge without saved data or settings does what it can"] = function(t)
        withImport(nil, function(w)
            w.rxp.settings = nil
            w.rxp.CreateMetaDataTable = nil
            t:assertTrue(w.Import.purge(w.rxp))
            w.rxp.db = nil
            t:assertFalse(w.Import.purge(w.rxp))
            t:assertFalse(w.Import.purge({}))
        end)
    end,
})

runner:addSuite("Import: saying the news", {
    ["a plain message is said as it is"] = function(t)
        local ns = loadAddon(FILES)
        local said = {}
        ns.Import.announce({}, "Guides Loaded Successfully", false, function(text)
            tinsert(said, text)
        end)
        t:assertEqual(table.concat(said, "|"), "Guides Loaded Successfully")
    end,
    ["an error gets its word, a message of several lines becomes one sentence"] = function(t)
        local ns = loadAddon(FILES)
        local said = {}
        ns.Import.announce({}, "Incomplete or invalid encoded string.\nTry again", true, function(text)
            tinsert(said, text)
        end)
        t:assertEqual(table.concat(said, "|"), "Import error: Incomplete or invalid encoded string. Try again")
    end,
    ["an error that carries a count says the count after the error"] = function(t)
        local ns = loadAddon(FILES)
        local said = {}
        ns.Import.announce({}, "Failed integrity check\nTotal guides loaded: 2/12", true, function(text)
            tinsert(said, text)
        end)
        t:assertEqual(table.concat(said, "|"), "Import error: Failed integrity check|2 of 12 guides loaded.")
    end,
    ["a count with nothing else and no error: said at the start, then at each quarter"] = function(t)
        local ns = loadAddon(FILES)
        local said = {}
        local memory = {}
        local function say(text)
            tinsert(said, text)
        end
        for current = 0, 12 do
            ns.Import.announce(memory, "Loading Guides... (" .. current .. "/12)", false, say)
        end
        t:assertEqual(
            table.concat(said, "|"),
            "Importing 12 guides.|3 of 12 guides loaded.|6 of 12 guides loaded.|9 of 12 guides loaded."
        )
    end,
    ["a new import starts again from the beginning"] = function(t)
        local ns = loadAddon(FILES)
        local said = {}
        local memory = {}
        local function say(text)
            tinsert(said, text)
        end
        for current = 0, 4 do
            ns.Import.announce(memory, "Loading Guides... (" .. current .. "/4)", false, say)
        end
        ns.Import.announce(memory, "Loading Guides... (0/8)", false, say)
        ns.Import.announce(memory, "Loading Guides... (2/8)", false, say)
        t:assertEqual(said[#said - 1], "Importing 8 guides.")
        t:assertEqual(said[#said], "2 of 8 guides loaded.")
    end,
    ["one guide only: said at the start and not again"] = function(t)
        local ns = loadAddon(FILES)
        local said = {}
        local memory = {}
        local function say(text)
            tinsert(said, text)
        end
        ns.Import.announce(memory, "Loading Guides... (0/1)", false, say)
        ns.Import.announce(memory, "Loading Guides... (1/1)", false, say)
        t:assertEqual(#said, 1)
    end,
    ["a total of zero does not divide by zero"] = function(t)
        local ns = loadAddon(FILES)
        local said = {}
        ns.Import.announce({}, "Loading Guides... (1/0)", false, function(text)
            tinsert(said, text)
        end)
        t:assertEqual(#said, 0)
    end,
    ["French"] = function(t)
        local ns = loadAddon(FILES)
        ns.useLocale("frFR")
        local said = {}
        ns.Import.announce({}, "Boom", true, function(text)
            tinsert(said, text)
        end)
        t:assertEqual(said[1], "Erreur d'import : Boom")
    end,
})

-- the importer as the hook sees it: a messages log, calls through the importer's own methods
runner:addSuite("Import: the hook", {
    ["what the importer reports is said out loud, and still kept for its window"] = function(t)
        withImport(nil, function(w)
            t:assertTrue(w.Import.hook(w.rxp, w.speak))
            w.importer:UpdateImportStatusHistory("Guides Loaded Successfully", false)
            t:assertEqual(w.spoken[1], "Guides Loaded Successfully")
            t:assertEqual(w.importer.gui.importStatusHistory[1], "Guides Loaded Successfully")
            t:assertEqual(w.importer.calls.refresh, 1)
        end)
    end,
    ["a message with arguments is formatted as RestedXP does"] = function(t)
        withImport(nil, function(w)
            w.Import.hook(w.rxp, w.speak)
            w.importer:UpdateImportStatusHistory("Loading Guides... (%d/%d)", false, 0, 12)
            t:assertEqual(w.spoken[1], "Importing 12 guides.")
        end)
    end,
    ["a message that does not format is said as it is"] = function(t)
        withImport(nil, function(w)
            -- an importer that keeps its messages without formatting them, so only the hook's own formatting fails
            w.importer.UpdateImportStatusHistory = function() end
            w.Import.hook(w.rxp, w.speak)
            w.importer:UpdateImportStatusHistory("100% sure %d", false)
            t:assertEqual(w.spoken[1], "100% sure %d")
        end)
    end,
    ["a paste is said by its size, once: RestedXP's own words for it stay quiet"] = function(t)
        withImport(nil, function(w)
            w.Import.hook(w.rxp, w.speak)
            w.Import.beginPaste(w.rxp)
            w.importer:paste(string.rep("x", 40000))
            t:assertEqual(#w.spoken, 1)
            t:assertEqual(w.spoken[1], "40000 characters pasted. You can now import them.")
            -- and the window still got the message
            t:assertMatch(w.importer.gui.importStatusHistory[1], "Loaded 40000 characters")
        end)
    end,
    ["a paste of nothing says so"] = function(t)
        withImport(nil, function(w)
            w.Import.hook(w.rxp, w.speak)
            w.importer:paste("")
            t:assertEqual(w.spoken[1], "Nothing was pasted.")
        end)
    end,
    ["the whole walk: paste, import, progress, the end"] = function(t)
        withImport({ total = 8 }, function(w)
            w.Import.hook(w.rxp, w.speak)
            w.Import.beginPaste(w.rxp)
            w.importer:paste("12|345:abc|678")
            w.Import.run(w.rxp)
            for current = 1, 8 do
                w.importer:UpdateImportStatusHistory("Loading Guides... (%d/%d)", false, current, 8)
            end
            w.rxp.workerFrame.shown = false
            w.importer:UpdateImportStatusHistory("Guides Loaded Successfully", false)
            t:assertEqual(
                table.concat(w.spoken, "|"),
                "14 characters pasted. You can now import them.|Importing 8 guides.|2 of 8 guides loaded.|4 of 8 guides loaded.|6 of 8 guides loaded.|Guides Loaded Successfully"
            )
        end)
    end,
    ["a refused text is said by the importer's own error, once"] = function(t)
        withImport({ importError = "Account mismatch" }, function(w)
            w.Import.hook(w.rxp, w.speak)
            w.Import.beginPaste(w.rxp)
            w.importer:paste("garbage")
            local before = #w.spoken
            local ok, why = w.Import.run(w.rxp)
            t:assertFalse(ok)
            t:assertEqual(why, "failed")
            t:assertEqual(#w.spoken, before + 1)
            t:assertEqual(w.spoken[before + 1], "Import error: Account mismatch")
        end)
    end,
    ["hooked once only"] = function(t)
        withImport(nil, function(w)
            t:assertTrue(w.Import.hook(w.rxp, w.speak))
            t:assertFalse(w.Import.hook(w.rxp, w.speak))
            w.importer:UpdateImportStatusHistory("Once", false)
            t:assertEqual(#w.spoken, 1)
        end)
    end,
    ["what RestedXP's own method gives back is given back"] = function(t)
        withImport(nil, function(w)
            w.importer.UpdateImportStatusHistory = function(_, _, _, ...)
                return "first", nil, ...
            end
            w.Import.hook(w.rxp, w.speak)
            local a, b, c = w.importer:UpdateImportStatusHistory("Message", false, "third")
            t:assertEqual(a, "first")
            t:assertNil(b)
            t:assertEqual(c, "third")
        end)
    end,
    ["the data of a status that is not a text is passed through"] = function(t)
        withImport(nil, function(w)
            w.Import.hook(w.rxp, w.speak)
            w.importer:UpdateImportStatusHistory({}, false)
            t:assertEqual(#w.spoken, 0)
        end)
    end,
    ["a failing speaker does not break RestedXP's import"] = function(t)
        withImport(nil, function(w)
            w.Import.hook(w.rxp, function()
                error("speech is down")
            end)
            w.importer:UpdateImportStatusHistory("Fine", false)
            t:assertEqual(w.importer.gui.importStatusHistory[1], "Fine")
            w.importer:paste("abc")
            t:assertTrue(w.importer.importReady)
        end)
    end,
    ["an error inside RestedXP's paste handling goes on as it was"] = function(t)
        withImport(nil, function(w)
            w.importer.ProcessBuffer = function()
                error("paste failed")
            end
            w.Import.hook(w.rxp, w.speak)
            local ok, err = pcall(w.importer.ProcessBuffer, w.importer)
            t:assertFalse(ok)
            t:assertMatch(err, "paste failed")
            -- and the news is not left muted
            w.importer:UpdateImportStatusHistory("Still heard", false)
            t:assertEqual(w.spoken[#w.spoken], "Still heard")
        end)
    end,
    ["without an importer, or one missing a method, there is nothing to hook"] = function(t)
        local ns = loadAddon(FILES)
        t:assertFalse(ns.Import.hook({}, function() end))
        withImport(nil, function(w)
            w.importer.ProcessBuffer = nil
            t:assertFalse(w.Import.hook(w.rxp, w.speak))
            t:assertNil(w.importer.wowVisionHooked)
        end)
    end,
})

end
