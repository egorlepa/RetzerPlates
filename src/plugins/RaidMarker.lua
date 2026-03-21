local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field RaidMarker Texture?
---@field _raidMarkerFrame Frame?

---@class RPRaidMarkerConfig
---@field enabled boolean
---@field debug boolean
---@field iconSize number

RP:RegisterSchema("raidMarker", {
    _meta = { label = "Raid Marker" },
    { key = "enabled",  default = true,  label = "Enable Raid Markers" },
    { key = "debug",    default = false, label = "Debug Raid Markers" },
    { key = "iconSize", default = 40,    label = "Icon Size", min = 14, max = 60, step = 1, scalable = true },
})

RP:RegisterRightSlot("raidMarker")

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructHealth", function(original, plate)
    original(plate)

    local db = RP.db.raidMarker
    if not db.enabled then return end

    -- Slot frame (anchored by layout system)
    local frame = CreateFrame("Frame", nil, plate)
    frame:SetSize(db.iconSize, db.iconSize)
    frame:EnableMouse(false)
    frame:Hide()

    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()

    plate.RaidMarker = icon
    plate._raidMarkerFrame = frame
    RP:SetSlotFrame(plate, "raidMarker", frame)
end)

----------------------------------------------------------------
-- Update
----------------------------------------------------------------

local function UpdateRaidMarker(plate)
    if not plate.RaidMarker then return end
    local unit = plate.unit
    if not unit then
        RP:SetSlotActive(plate, "raidMarker", false)
        return
    end

    local index = RP.db.raidMarker.debug and 8 or GetRaidTargetIndex(unit)
    if index then
        plate.RaidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        SetRaidTargetIconTexture(plate.RaidMarker, index)
        RP:SetSlotActive(plate, "raidMarker", true)
    else
        RP:SetSlotActive(plate, "raidMarker", false)
    end
end

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdatePlate", function(original, plate)
    original(plate)
    UpdateRaidMarker(plate)
end)

-- Refresh all plates when markers change
RP:RegisterEvent("RAID_TARGET_UPDATE", function()
    local NP = RP:GetModule("Nameplates")
    if not NP then return end

    for _, plate in pairs(NP.plates) do
        UpdateRaidMarker(plate)
    end
end)

----------------------------------------------------------------
-- Cleanup
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateRemoved", function(original, plate)
    if plate.RaidMarker then
        RP:SetSlotActive(plate, "raidMarker", false)
    end
    original(plate)
end)
