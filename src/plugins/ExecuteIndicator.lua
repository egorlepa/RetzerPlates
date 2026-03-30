local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPHealthBar
---@field executeMark Texture?
---@field executeMarkUpper Texture?

---@class RPExecuteConfig
---@field enabled boolean
---@field showEarly number
---@field color RPColor
---@field width number

RP:RegisterSchema("execute", {
    _meta = { label = "Execute" },
    { key = "enabled",   default = true,                                   label = "Enable Execute Indicator" },
    { key = "showEarly", default = 5,                                      label = "Show Early %",            min = 0, max = 20, step = 1 },
    { key = "color",     default = { r = 1.0, g = 1.0, b = 1.0, a = 0.6 }, label = "Mark Color" },
    { key = "width",     default = 2,                                      label = "Mark Width",              min = 1, max = 6,  step = 1, scalable = true },
})

----------------------------------------------------------------
-- Auto-detect execute threshold based on class/spec/talents
----------------------------------------------------------------

local function isTalentLearned(nodeID)
    local info = C_Traits.GetNodeInfo(C_ClassTalents.GetActiveConfigID() or 0, nodeID)
    return info and info.currentRank and info.currentRank > 0
end

local function DetectExecuteThreshold()
    local _, class = UnitClass("player")
    local low, high

    if class == "WARRIOR" then
        if C_SpellBook.IsSpellKnown(163201) then -- Execute
            low = 0.20
            if C_SpellBook.IsSpellKnown(281001) or C_SpellBook.IsSpellKnown(206315) then -- Massacre
                low = 0.35
            end
        end

    elseif class == "PRIEST" then
        if C_SpellBook.IsSpellKnown(32379) then -- Shadow Word: Death
            low = 0.20
            if C_SpellBook.IsSpellKnown(392507) then -- Deathspeaker
                low = 0.35
            end
        end

    elseif class == "MAGE" then
        if C_SpellBook.IsSpellKnown(2948) then -- Scorch
            low = 0.30
            if isTalentLearned(449349) then -- Sunfury Execution
                low = 0.35
            end
        end
        if C_SpellBook.IsSpellKnown(384581) then -- Arcane Bombardment
            low = 0.35
        end
        if C_SpellBook.IsSpellKnown(205026) then -- Firestarter
            high = 0.90
        end

    elseif class == "HUNTER" then
        if C_SpellBook.IsSpellKnown(53351) or C_SpellBook.IsSpellKnown(320976) then -- Kill Shot
            low = 0.20
        end
        if isTalentLearned(94987) then -- Black Arrow
            low = 0.20
            high = 0.80
        end
        if C_SpellBook.IsSpellKnown(273887) then -- Killer Instinct
            low = 0.35
        end
        if C_SpellBook.IsSpellKnown(260228) then -- Careful Aim
            high = 0.70
        end

    elseif class == "PALADIN" then
        if C_SpellBook.IsSpellKnown(24275) then -- Hammer of Wrath
            low = 0.20
        end

    elseif class == "MONK" then
        if C_SpellBook.IsSpellKnown(322113) then -- Touch of Death
            low = 0.15
        end

    elseif class == "WARLOCK" then
        if C_SpellBook.IsSpellKnown(17877) then -- Shadowburn
            low = 0.20
            if C_SpellBook.IsSpellKnown(456939) then -- Blistering Atrophy
                low = 0.30
            end
        elseif C_SpellBook.IsSpellKnown(198590) then -- Drain Soul override
            low = 0.20
        end

    elseif class == "ROGUE" then
        if C_SpellBook.IsSpellKnown(328085) then -- Blindside
            low = 0.35
        end

    elseif class == "DEATHKNIGHT" then
        if C_SpellBook.IsSpellKnown(343294) then -- Soul Reaper
            low = 0.35
        end
    end

    return low, high
end

----------------------------------------------------------------
-- Threshold state and curve building
----------------------------------------------------------------

local function BuildThresholdCurve(threshold)
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(0, 0, 0, 1))
    curve:AddPoint(threshold, CreateColor(0, 0, 0, 0))
    return curve
end

-- Upper execute: alpha=1 ABOVE threshold, alpha=0 below
local function BuildUpperThresholdCurve(threshold)
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(0, 0, 0, 0))
    curve:AddPoint(threshold, CreateColor(0, 0, 0, 1))
    return curve
end

local lowThreshold, highThreshold
local lowCurve, highCurve
local thresholdDetected = false

local function CreateMark(plate, db)
    local mark = plate.Health:CreateTexture(nil, "OVERLAY")
    mark:SetColorTexture(db.color.r, db.color.g, db.color.b, db.color.a)
    mark:SetWidth(db.width)
    mark:Hide()
    return mark
end

local function PositionMark(mark, health, threshold)
    mark:ClearAllPoints()
    mark:SetPoint("TOP", health, "TOP", 0, 0)
    mark:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
    mark:SetPoint("LEFT", health, "LEFT", health:GetWidth() * threshold, 0)
end

local function EnsureMark(plate, db)
    -- Lower mark
    if lowThreshold then
        if not plate.Health.executeMark then
            plate.Health.executeMark = CreateMark(plate, db)
        end
        PositionMark(plate.Health.executeMark, plate.Health, lowThreshold)
    elseif plate.Health.executeMark then
        plate.Health.executeMark:Hide()
    end

    -- Upper mark
    if highThreshold then
        if not plate.Health.executeMarkUpper then
            plate.Health.executeMarkUpper = CreateMark(plate, db)
        end
        PositionMark(plate.Health.executeMarkUpper, plate.Health, highThreshold)
    elseif plate.Health.executeMarkUpper then
        plate.Health.executeMarkUpper:Hide()
    end
end

local function RefreshThresholds()
    local detectedLow, detectedHigh = DetectExecuteThreshold()
    local db = RP.db.execute

    lowThreshold = detectedLow
    highThreshold = detectedHigh

    local earlyPct = db.showEarly / 100
    lowCurve = lowThreshold and BuildThresholdCurve(lowThreshold + earlyPct) or nil
    highCurve = highThreshold and BuildUpperThresholdCurve(highThreshold - earlyPct) or nil

    thresholdDetected = true

    -- Update marks on all existing plates (create, reposition, or hide)
    local NP = RP:GetModule("Nameplates")
    if NP then
        for _, plate in pairs(NP.plates) do
            EnsureMark(plate, db)
        end
    end
end

-- Refresh on spec/talent changes
RP:RegisterEvent("PLAYER_TALENT_UPDATE", function() RefreshThresholds() end)
RP:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", function() RefreshThresholds() end)
RP:RegisterEvent("TRAIT_CONFIG_UPDATED", function() RefreshThresholds() end)
RP:RegisterEvent("TRAIT_NODE_CHANGED", function() RefreshThresholds() end)
RP:RegisterEvent("PLAYER_ENTERING_WORLD", function() RefreshThresholds() end)

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructHealth", function(original, plate)
    original(plate)

    local db = RP.db.execute
    if not db.enabled then return end

    -- Lazy init thresholds (db not available at file load)
    if not thresholdDetected then RefreshThresholds() end

    EnsureMark(plate, db)
end)

----------------------------------------------------------------
-- Scaling: reposition marks to match scaled bar width
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
---@param factor number
RP:WrapHook("ScalePlate", function(original, plate, factor)
    original(plate, factor)
    if not plate.Health then return end
    local db = RP.db.execute
    if not db.enabled then return end
    EnsureMark(plate, db)
end)

----------------------------------------------------------------
-- Layout: hide for friendly
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateLayout", function(original, plate)
    original(plate)

    local db = RP.db.execute
    if not db.enabled then return end
    if RP.IsPassive(plate) or (plate.isMinor and RP.db.simplified.enabled) then
        if plate.Health.executeMark then plate.Health.executeMark:Hide() end
        if plate.Health.executeMarkUpper then plate.Health.executeMarkUpper:Hide() end
    else
        EnsureMark(plate, db)
    end
end)

----------------------------------------------------------------
-- Health update: show/hide based on secret-safe curve
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateHealth", function(original, plate)
    original(plate)

    if not plate.unit then return end
    if RP.IsPassive(plate) then return end
    if plate.isMinor and RP.db.simplified.enabled then return end
    if not thresholdDetected then RefreshThresholds() end

    -- Lower execute
    if plate.Health.executeMark and lowCurve then
        local color = UnitHealthPercent(plate.unit, true, lowCurve) --[[@as ColorMixin]]
        local _, _, _, alpha = color:GetRGBA()
        plate.Health.executeMark:Show()
        plate.Health.executeMark:SetAlpha(alpha --[[@as number]])
    end

    -- Upper execute
    if highCurve and plate.Health.executeMarkUpper then
        local color = UnitHealthPercent(plate.unit, true, highCurve) --[[@as ColorMixin]]
        local _, _, _, alphaUp = color:GetRGBA()
        plate.Health.executeMarkUpper:Show()
        plate.Health.executeMarkUpper:SetAlpha(alphaUp --[[@as number]])
    end

end)
