-- Glue: register the pet training window with WowVision's window manager.
local _, ns = ...
local L = ns.L

local function install()
    if WowVision == nil or WowVision.UIHost == nil then
        return false
    end
    -- A WowVision that has the pet's window itself needs none of this.
    if WowVision.petTraining ~= nil then
        return true
    end
    local ok, installed = pcall(ns.install)
    if not ok then
        geterrorhandler()("WowVision_PetTraining: " .. tostring(installed))
        return false
    end
    if not installed then
        print("WowVision_PetTraining: " .. L["WowVision's training window was not found; the pet training window is not available."])
    end
    return installed
end

ns.installed = install()
