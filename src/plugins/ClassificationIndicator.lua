local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPClassificationFrame : Frame
---@field tex Texture

---@class RPPlate
---@field classificationIcon RPClassificationFrame?
---@field _debugClassification string?

---@class RPClassificationConfig
---@field enabled boolean
---@field hideInInstance boolean
---@field debug boolean
---@field iconSize number

RP:RegisterSchema("classification", {
    _meta = { label = "Classification" },
    { key = "enabled",        default = true,  label = "Enable Classification Icons" },
    { key = "hideInInstance", default = true,  label = "Hide in Instances" },
    { key = "debug",          default = false, label = "Debug Classifications" },
    { key = "iconSize",       default = 20,    label = "Icon Size", min = 8, max = 40, step = 1, scalable = true },
})

----------------------------------------------------------------
-- Icon appearance per classification
----------------------------------------------------------------

local ICON_GAP = 3  -- gap between icon and target arrow
local BAR_GAP  = 2  -- gap between icon and health bar

local DEBUG_CLASSIFICATIONS = { "elite", "rareelite", "rare", "worldboss" }
local debugCounter = 0

local SHOW_FOR = {
    elite     = true,
    rareelite = true,
    rare      = true,
    worldboss = true,
}

local function ApplyIconAppearance(tex, classification)
    if classification == "worldboss" then
        tex:SetTexture([[Interface\Scenarios\ScenarioIcon-Boss]])
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetDesaturated(false)
        tex:SetVertexColor(1, 1, 1)
    else
        -- elite / rareelite / rare share the same base texture
        tex:SetTexture([[Interface\GLUES\CharacterSelect\Glues-AddOn-Icons]])
        tex:SetTexCoord(0.75, 1, 0, 1)
        if classification == "elite" then
            tex:SetDesaturated(false)
            tex:SetVertexColor(1, 0.8, 0)   -- gold
        elseif classification == "rareelite" then
            tex:SetDesaturated(false)
            tex:SetVertexColor(1, 0.5, 0)   -- orange-gold
        else -- rare
            tex:SetDesaturated(true)
            tex:SetVertexColor(1, 1, 1)     -- silver
        end
    end
end

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructHealth", function(original, plate)
    original(plate)

    local db = RP.db.classification
    if not db.enabled then return end

    -- Frame width includes gap so GetWidth() accounts for spacing when
    -- TargetIndicator reads it to push the left arrow further out.
    local frame = CreateFrame("Frame", nil, plate.Health) --[[@as RPClassificationFrame]]
    frame:SetSize(db.iconSize + ICON_GAP + BAR_GAP, db.iconSize)
    frame:EnableMouse(false)
    frame:SetPoint("RIGHT", plate.Health, "LEFT", 0, 0)
    frame:Hide()

    -- Texture is inset BAR_GAP from the right so there's a small gap to the bar.
    -- ICON_GAP on the left side pushes the target arrow further out.
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetSize(db.iconSize, db.iconSize)
    tex:SetPoint("RIGHT", frame, "RIGHT", -BAR_GAP, 0)
    frame.tex = tex

    plate.classificationIcon = frame
end)

----------------------------------------------------------------
-- Debug: assign a cycling classification when each plate is added
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateAdded", function(original, plate)
    original(plate)
    debugCounter = debugCounter + 1
    plate._debugClassification = DEBUG_CLASSIFICATIONS[(debugCounter - 1) % #DEBUG_CLASSIFICATIONS + 1]
end)

----------------------------------------------------------------
-- Layout update: show/hide based on classification and passive state
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateLayout", function(original, plate)
    original(plate)

    local frame = plate.classificationIcon
    if not frame then return end

    local db = RP.db.classification
    local unit = plate.unit
    local classification = db.debug
        and plate._debugClassification
        or (unit and UnitClassification(unit))
    local inInstance = select(2, IsInInstance()) ~= "none"
    local shouldShow = db.enabled
        and not (db.hideInInstance and inInstance)
        and not RP.IsPassive(plate)
        and classification
        and (db.debug or SHOW_FOR[classification])

    if shouldShow then
        ApplyIconAppearance(frame.tex, classification)
        if not frame:IsShown() then
            frame:Show()
            RP:SetLeftAnchor(plate, frame)
        end
    else
        if frame:IsShown() then
            frame:Hide()
            RP:ClearLeftAnchor(plate)
        end
    end
end)

----------------------------------------------------------------
-- Cleanup
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateRemoved", function(original, plate)
    if plate.classificationIcon and plate.classificationIcon:IsShown() then
        plate.classificationIcon:Hide()
        RP:ClearLeftAnchor(plate)
    end
    original(plate)
end)
