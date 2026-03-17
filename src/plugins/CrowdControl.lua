local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field CCContainer RPCCContainer?

---@class RPCCContainer : Frame, BackdropTemplate
---@field icons RPIconFrame[]
---@field db table
---@field active boolean?

---@class RPCCConfig
---@field enabled boolean
---@field debug boolean
---@field iconSize number
---@field spacing number
---@field maxIcons number
---@field durationFontSize number
---@field stackFontSize number

RP:RegisterSchema("crowdControl", {
    _meta = { label = "Crowd Control" },
    { key = "enabled",          default = true,  label = "Enable CC Icons" },
    { key = "debug",            default = false, label = "Debug CC Icons" },
    { key = "iconSize",         default = 40,    label = "Icon Size",          min = 14, max = 80, step = 1 },
    { key = "spacing",          default = 2,     label = "Spacing",            min = 0,  max = 10, step = 1 },
    { key = "maxIcons",         default = 3,     label = "Max Icons",          min = 1,  max = 10, step = 1 },
    { key = "durationFontSize", default = 22,    label = "Duration Font Size", min = 8,  max = 30, step = 1 },
    { key = "stackFontSize",    default = 16,    label = "Stack Font Size",    min = 8,  max = 24, step = 1 },
})

----------------------------------------------------------------
-- CC icon pool (reusable per plate)
----------------------------------------------------------------

----------------------------------------------------------------
-- Construction: CC container to the right of health bar
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructHealth", function(original, plate)
    original(plate)

    local db = RP.db.crowdControl
    if not db.enabled then return end

    local container = CreateFrame("Frame", nil, plate.Health)
    container:SetPoint("LEFT", plate.Health, "RIGHT", db.spacing, 0)
    container:SetSize(db.maxIcons * (db.iconSize + db.spacing), db.iconSize)
    container:EnableMouse(false)

    container.icons = {}
    container.db = db

    plate.CCContainer = container
end)

----------------------------------------------------------------
-- Fetch CC auras using IsAuraFilteredOutByInstanceID
----------------------------------------------------------------

local function GetCCAuras(unit)
    -- Get all debuffs on the unit (from any source)
    local debuffs = C_UnitAuras.GetUnitAuras(unit, "HARMFUL", nil, Enum.UnitAuraSortRule.Expiration)
    if not debuffs then return {} end

    local cc = {}
    for _, aura in ipairs(debuffs) do
        -- IsAuraFilteredOutByInstanceID returns false when the aura MATCHES the filter
        local filtered = C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, "HARMFUL|CROWD_CONTROL")
        if not filtered then
            cc[#cc + 1] = aura
        end
    end
    return cc
end

----------------------------------------------------------------
-- Debug CC auras
----------------------------------------------------------------

local debugCCIcons = {
    "Interface\\Icons\\Spell_Frost_FrostNova",
    "Interface\\Icons\\Spell_Holy_SealOfMight",
    "Interface\\Icons\\Spell_Nature_EarthBind",
}

local function GetDebugCCAuras()
    local cc = {}
    local now = GetTime()
    for i = 1, 2 do
        cc[#cc + 1] = {
            icon = debugCCIcons[i],
            _debugStart = now,
            _debugDuration = 4 + i * 2,
            applications = nil,
        }
    end
    return cc
end

----------------------------------------------------------------
-- Update CC display
----------------------------------------------------------------

local function UpdateCC(plate)
    local container = plate.CCContainer
    if not container then return end

    local unit = plate.unit
    if not unit then return end

    -- Hide on passive units
    if RP.IsPassive(plate) then
        for _, icon in ipairs(container.icons) do
            icon:Hide()
        end
        return
    end

    local db = container.db
    local isDebug = db.debug
    local auras
    if isDebug then
        auras = GetDebugCCAuras()
    else
        auras = GetCCAuras(unit)
    end

    local shown = 0
    for _, aura in ipairs(auras) do
        if shown >= db.maxIcons then break end
        shown = shown + 1

        local iconFrame = container.icons[shown]
        if not iconFrame then
            iconFrame = RP.CreateIconFrame(container, db)
            iconFrame:SetBackdropBorderColor(1, 1, 0, 1)
            container.icons[shown] = iconFrame
        end

        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("TOPLEFT", container, "TOPLEFT",
            (shown - 1) * (db.iconSize + db.spacing), 0)

        if aura.icon then
            iconFrame.Icon:SetTexture(aura.icon)
        end

        -- Cooldown spiral
        if isDebug then
            iconFrame.Cooldown:SetCooldown(aura._debugStart, aura._debugDuration)
        else
            local durationObj = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
            if durationObj then
                iconFrame.Cooldown:SetCooldownFromDurationObject(durationObj)
            end
        end
        iconFrame.Cooldown:Show()

        -- Stack count
        if aura.applications then
            if isDebug then
                iconFrame.Stack:SetText(aura.applications)
            else
                iconFrame.Stack:SetText(C_StringUtil.TruncateWhenZero(aura.applications))
            end
            iconFrame.Stack:Show()
        else
            iconFrame.Stack:Hide()
        end

        iconFrame:Show()
    end

    -- Hide unused
    for i = shown + 1, #container.icons do
        container.icons[i]:Hide()
    end

    -- Track active state and resize container
    container.active = shown > 0
    container:ClearAllPoints()
    if container.active then
        container:SetPoint("LEFT", plate.Health, "RIGHT", db.spacing, 0)
        container:SetWidth(shown * db.iconSize + (shown - 1) * db.spacing)
    else
        container:SetPoint("LEFT", plate.Health, "RIGHT", 0, 0)
        container:SetWidth(0.001)
    end

end

----------------------------------------------------------------
-- Hook into plate lifecycle
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("GetRightAnchor", function(original, plate)
    return plate.CCContainer or original(plate)
end)

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdatePlate", function(original, plate)
    original(plate)
    UpdateCC(plate)
end)

RP:RegisterEvent("UNIT_AURA", function(_, unitToken)
    if not unitToken:find("nameplate") then return end
    local NP = RP:GetModule("Nameplates")
    if not NP then return end

    local frame = C_NamePlate.GetNamePlateForUnit(unitToken)
    if not frame then return end

    local plate = NP.plates[frame]
    if not plate then return end

    UpdateCC(plate)
end)

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateRemoved", function(original, plate)
    if plate.CCContainer then
        for _, icon in ipairs(plate.CCContainer.icons) do
            icon:Hide()
        end
    end
    original(plate)
end)
