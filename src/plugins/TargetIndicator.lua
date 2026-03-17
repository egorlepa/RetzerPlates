local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPHealthBar
---@field targetArrowL Texture?
---@field targetArrowR Texture?

---@class RPTargetConfig
---@field enabled boolean
---@field arrowSize number
---@field arrowColor RPColor

RP:RegisterSchema("target", {
    _meta = { label = "Target" },
    { key = "enabled",    default = true,                          label = "Enable Target Arrows" },
    { key = "arrowSize",  default = 80,                            label = "Arrow Size",          min = 20, max = 160, step = 5 },
    { key = "arrowColor", default = { r = 1.0, g = 1.0, b = 1.0 }, label = "Arrow Color" },
})

----------------------------------------------------------------
-- Target indicator: chevron arrows on left/right of health bar
----------------------------------------------------------------

local currentTarget = nil

local function CreateArrow(parent, pointRight)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\AddOns\\RetzerPlates\\plugins\\arrow.tga")
    local size = RP.db.target.arrowSize
    tex:SetSize(size, size)
    tex:SetRotation(pointRight and 0 or math.rad(180))
    local c = RP.db.target.arrowColor
    tex:SetVertexColor(c.r, c.g, c.b, 1)
    tex:Hide()
    return tex
end

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructHealth", function(original, plate)
    original(plate)

    local arrowL = CreateArrow(plate.Health, true)
    arrowL:SetPoint("RIGHT", plate.Health, "LEFT", 0, 0)

    local arrowR = CreateArrow(plate.Health, false)
    arrowR:SetPoint("LEFT", plate.Health, "RIGHT", 0, 0)

    plate.Health.targetArrowL = arrowL
    plate.Health.targetArrowR = arrowR
end)

---@param original function
---@param plate RPPlate
---@param lastAnchor Frame
RP:WrapHook("OnLayoutChanged", function(original, plate, lastAnchor)
    original(plate, lastAnchor)
    if plate.Health and plate.Health.targetArrowR then
        plate.Health.targetArrowR:ClearAllPoints()
        plate.Health.targetArrowR:SetPoint("LEFT", lastAnchor, "RIGHT", 0, 0)
    end
end)

---@param original function
---@param plate RPPlate
---@param leftmostAnchor Frame
RP:WrapHook("OnLeftLayoutChanged", function(original, plate, leftmostAnchor)
    original(plate, leftmostAnchor)
    if plate.Health and plate.Health.targetArrowL then
        local xOffset = (leftmostAnchor ~= plate.Health) and leftmostAnchor:GetWidth() or 0
        plate.Health.targetArrowL:ClearAllPoints()
        plate.Health.targetArrowL:SetPoint("RIGHT", plate.Health, "LEFT", -xOffset, 0)
    end
end)

local function ShowArrows(plate, show)
    if not plate.Health or not plate.Health.targetArrowL then return end
    if not RP.db.target.enabled or RP.IsPassive(plate) then show = false end

    if show then
        plate.Health.targetArrowL:Show()
        plate.Health.targetArrowR:Show()
    else
        plate.Health.targetArrowL:Hide()
        plate.Health.targetArrowR:Hide()
    end
end

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateLayout", function(original, plate)
    original(plate)
    if plate == currentTarget then
        ShowArrows(plate, true) -- ShowArrows internally checks IsPassive
    end
end)

local function RefreshTarget()
    local NP = RP:GetModule("Nameplates")
    if not NP then return end

    if currentTarget then
        ShowArrows(currentTarget, false)
        currentTarget = nil
    end

    local frame = C_NamePlate.GetNamePlateForUnit("target")
    if not frame then return end
    local plate = NP.plates[frame]
    if not plate then return end

    currentTarget = plate
    ShowArrows(plate, true)
end

RP:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    RefreshTarget()
end)

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateRemoved", function(original, plate)
    if plate == currentTarget then
        ShowArrows(plate, false)
        currentTarget = nil
    end
    original(plate)
end)

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateAdded", function(original, plate)
    original(plate)
    if plate.unit and UnitIsUnit(plate.unit, "target") then
        currentTarget = plate
        ShowArrows(plate, true)
    end
end)
