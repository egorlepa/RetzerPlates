local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPHealthBar
---@field targetArrowL Texture?
---@field targetArrowR Texture?


---@class RPTargetConfig
---@field arrowsEnabled boolean
---@field arrowSize number
---@field arrowColor RPColor
---@field scaleEnabled boolean
---@field scale number

RP:RegisterSchema("target", {
    _meta = { label = "Target" },
    { key = "arrowsEnabled", default = true,                           label = "Enable Target Arrows" },
    { key = "arrowSize",     default = 80,                             label = "Arrow Size",           min = 20, max = 160, step = 5, scalable = true },
    { key = "arrowColor",    default = { r = 1.0, g = 1.0, b = 1.0 }, label = "Arrow Color" },
    { key = "scaleEnabled",  default = true,                           label = "Enable Target Scale" },
    { key = "scale",         default = 1.15,                           label = "Target Scale",         min = 1.0, max = 1.5, step = 0.05 },
})

----------------------------------------------------------------
-- Target indicator: chevron arrows on left/right of health bar
----------------------------------------------------------------

local currentTarget = nil

local function CreateArrow(parent, pointRight)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\AddOns\\RetzerPlates\\media\\arrow.tga")
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
        local xOffset = (leftmostAnchor ~= plate.Health) and (leftmostAnchor--[[@as RPClassificationFrame]]._cleanWidth or leftmostAnchor:GetWidth()) or 0
        plate.Health.targetArrowL:ClearAllPoints()
        plate.Health.targetArrowL:SetPoint("RIGHT", plate.Health, "LEFT", -xOffset, 0)
    end
end)

local function UpdateTargetPlate(plate, show)
    if not plate.Health or not plate.Health.targetArrowL then return end
    local db = RP.db.target
    if RP.IsPassive(plate) then show = false end
    local showArrows = show and db.arrowsEnabled
    local showScale  = show and db.scaleEnabled

    if showArrows then
        plate.Health.targetArrowL:Show()
        plate.Health.targetArrowR:Show()
    else
        plate.Health.targetArrowL:Hide()
        plate.Health.targetArrowR:Hide()
    end

    if showScale and db.scale ~= 1.0 then
        RP:Call("ScalePlate", plate, db.scale)
    else
        RP:Call("UpdateLayout", plate)
    end
end

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateLayout", function(original, plate)
    original(plate)
    local db = RP.db.target
    if plate == currentTarget and db.scaleEnabled and not RP.IsPassive(plate) and db.scale ~= 1.0 then
        RP:Call("ScalePlate", plate, db.scale)
    end
end)

local function RefreshTarget()
    local NP = RP:GetModule("Nameplates")
    if not NP then return end

    if currentTarget then
        local prev = currentTarget
        currentTarget = nil
        UpdateTargetPlate(prev, false)
    end

    local frame = C_NamePlate.GetNamePlateForUnit("target")
    if not frame then return end
    local plate = NP.plates[frame]
    if not plate then return end

    currentTarget = plate
    UpdateTargetPlate(plate, true)
end

RP:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    RefreshTarget()
end)

-- Re-apply target visuals when the plate updates (e.g. passive↔attackable transition)
---@param original function
---@param plate RPPlate
RP:WrapHook("UpdatePlate", function(original, plate)
    original(plate)
    if plate == currentTarget then
        UpdateTargetPlate(plate, true)
    end
end)

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateRemoved", function(original, plate)
    if plate == currentTarget then
        currentTarget = nil
        UpdateTargetPlate(plate, false)
    end
    original(plate)
end)

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateAdded", function(original, plate)
    original(plate)
    if plate.unit and UnitIsUnit(plate.unit, "target") then
        currentTarget = plate
        UpdateTargetPlate(plate, true)
    end
end)
