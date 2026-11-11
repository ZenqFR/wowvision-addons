-- A mark the player puts on the items of their bags: the item itself carries it, wherever it sits, so a second
-- stack of the same item is marked too. Two parts use this -- junk (sold by themselves at a merchant, Hooks.lua)
-- and favorites (never sold, only found again more easily) -- and each is one Marks.new(...) with its own words.
--
-- The marks are saved per character in WowVisionBagsDB, by item (Store.lua says what makes an item the same
-- item): a mark on one character never reaches another.
local _, ns = ...
local L = ns.L
local store = ns.store

local Marks = {}
ns.Marks = Marks

-- The saved table of one part ("junk", "favorites"), made when it is first needed. It is read through the global
-- every time: on WoW: Forever the client can hand a saved variable over after the addon's loaded event and
-- replace the table, so a reference kept from load time could go stale.
function ns.root()
    local db = rawget(_G, "WowVisionBagsDB")
    if type(db) ~= "table" then
        db = {}
        _G.WowVisionBagsDB = db
    end
    return db
end

function ns.section(name)
    local db = ns.root()
    local section = db[name]
    if type(section) ~= "table" then
        section = {}
        db[name] = section
    end
    if type(section.marks) ~= "table" then
        section.marks = {}
    end
    return section
end

local function speak(text)
    if WowVision ~= nil and WowVision.speak ~= nil then
        WowVision:speak(text)
    end
end

-- What the item is called when it is said: the game's name, else the one in its link, else its key.
local function nameOf(info, key)
    if type(info.itemName) == "string" and info.itemName ~= "" then
        return info.itemName
    end
    local ok, name = pcall(store.nameFromLink, info.hyperlink)
    if ok and name ~= nil then
        return name
    end
    return key
end

-- opts:
--   name          "junk" or "favorites": the part's table in the saved variables
--   word          the English word of the tag said ahead of a slot, "[Junk] Linen Cloth" (translated by Locale.lua)
--   bindingKey    the key binding that marks the slot you stand on
--   markLabel, unmarkLabel                 the slot's menu entries
--   markedText, unmarkedText, cannotText   what is said: "%s: marked as junk", ..., "This item cannot be ..."
--   refuse(info, name)   optional: a sentence when this item must not be marked (nil to allow it)
function Marks.new(opts)
    local feature = { name = opts.name, bindingKey = opts.bindingKey }

    function feature:section()
        return ns.section(opts.name)
    end

    function feature:isEnabled()
        return self:section().enabled ~= false
    end

    function feature:setEnabled(enabled)
        self:section().enabled = enabled == true
    end

    -- The marks table; nil while the part is off, which reads as "nothing is marked".
    function feature:getMarks()
        if not self:isEnabled() then
            return nil
        end
        return self:section().marks
    end

    -- The game's item info for a bag slot and the item's key; nil when the slot is empty or cannot be read.
    function feature:itemAt(bagID, slotID)
        local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slotID)
        if not ok or info == nil then
            return nil
        end
        local keyOk, key = pcall(store.keyFromLink, info.hyperlink)
        return info, keyOk and key or nil
    end

    function feature:isMarkedAt(bagID, slotID)
        local marks = self:getMarks()
        if marks == nil then
            return false
        end
        local _, key = self:itemAt(bagID, slotID)
        return store.isMarked(marks, key)
    end

    -- The item buttons among these whose slot holds a marked item, in the order given. locate(button) returns the
    -- slot's bag and slot id. A button that cannot be read is left out.
    function feature:markedSlots(buttons, locate)
        local marked = {}
        if self:getMarks() == nil then
            return marked
        end
        for _, itemButton in ipairs(buttons) do
            local ok, isMarked = pcall(function()
                return self:isMarkedAt(locate(itemButton))
            end)
            if ok and isMarked then
                tinsert(marked, itemButton)
            end
        end
        return marked
    end

    -- A bag slot's label with "[Word] " ahead of it when its item is marked. Never fails: a slot that cannot be
    -- read has the label it had.
    function feature:tagLabel(label, bagID, slotID)
        if label == nil then
            return nil
        end
        local ok, marked = pcall(self.isMarkedAt, self, bagID, slotID)
        if ok and marked then
            return "[" .. L[opts.word] .. "] " .. label
        end
        return label
    end

    -- The mark of the item in a bag slot, taken off when it is there and put on when it is not; says what
    -- happened.
    function feature:toggleAt(bagID, slotID)
        local marks = self:getMarks()
        if marks == nil then
            return
        end
        local info, key = self:itemAt(bagID, slotID)
        if info == nil then
            speak(L["Empty"])
            return
        end
        if key == nil then
            speak(L[opts.cannotText])
            return
        end
        local name = nameOf(info, key)
        if not store.isMarked(marks, key) and opts.refuse ~= nil then
            local reason = opts.refuse(info, name)
            if reason ~= nil then
                speak(reason)
                return
            end
        end
        local marked = store.toggle(marks, key, name ~= key and name or nil)
        speak(string.format(L[marked and opts.markedText or opts.unmarkedText], name))
        -- The label changed with the mark and was just said; the live watch must not say it a second time.
        local host = WowVision ~= nil and WowVision.graphHost or nil
        local screen = host ~= nil and host:focusedScreen() or nil
        if screen ~= nil then
            screen._liveKey = nil
        end
    end

    -- What a bag item slot node gains: the part's key and a context menu entry for the same. locate() returns
    -- the slot's bag and slot id as they are now (the button is reused for other slots). The node is handed
    -- back; nil and a part that is off pass through untouched.
    function feature:decorateSlot(vtable, locate)
        if vtable == nil or not self:isEnabled() then
            return vtable
        end
        local function toggle()
            local bagID, slotID = locate()
            self:toggleAt(bagID, slotID)
        end
        tinsert(vtable.bindings, {
            binding = opts.bindingKey,
            type = "Function",
            interruptSpeech = true,
            func = toggle,
        })
        local actions = vtable.contextActions
        vtable.contextActions = function(add, node)
            if type(actions) == "function" then
                actions(add, node)
            end
            add({
                label = self:isMarkedAt(locate()) and L[opts.unmarkLabel] or L[opts.markLabel],
                onActivate = toggle,
            })
        end
        return vtable
    end

    -- Takes every mark off. Returns how many there were.
    function feature:forget()
        local marks = self:section().marks
        local count = store.count(marks)
        store.clear(marks)
        return count
    end

    return feature
end
