local _, ns = ...
local RP = ns.RP ---@type RP

-- Absorb bar anchored to health fill right edge, width synced to health bar.
-- Uses heal prediction calculator — all values are secret-safe.
-- Mirrors Plater's Midnight unitframe approach.

---@class RPHealthBar
---@field absorbBar StatusBar?
---@field absorbCalc table?

---@class RPAbsorbConfig
---@field enabled boolean
---@field debug boolean

RP:RegisterSchema("absorb", {
    _meta = { label = "Absorb Shield" },
    { key = "enabled", default = true,  label = "Enable Absorb Overlay" },
    { key = "debug",   default = false, label = "Debug Absorb" },
})

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructHealth", function(original, plate)
    original(plate)

    local db = RP.db.absorb
    if not db.enabled then return end

    -- Heal prediction calculator (Midnight API)
    local calc = CreateUnitHealPredictionCalculator()
    calc:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)
    calc:SetHealAbsorbClampMode(Enum.UnitHealAbsorbClampMode.MaximumHealth)
    calc:SetHealAbsorbMode(Enum.UnitHealAbsorbMode.Total)
    calc:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
    calc:SetIncomingHealOverflowPercent(1)
    plate.Health.absorbCalc = calc

    -- Absorb StatusBar: anchored to health fill right edge, width synced
    local bar = CreateFrame("StatusBar", nil, plate.Health)
    local barTex = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bar:SetStatusBarTexture(barTex)
    barTex:SetTexture("Interface\\RaidFrame\\Shield-Fill")
    bar:SetPoint("TOPLEFT", plate.Health.barTexture, "TOPRIGHT")
    bar:SetPoint("BOTTOMLEFT", plate.Health.barTexture, "BOTTOMRIGHT")
    bar:SetWidth(plate.Health:GetWidth())
    bar:SetFrameLevel(plate.Health:GetFrameLevel())
    bar:EnableMouse(false)
    bar:Hide()

    -- Keep absorb bar width synced with health bar
    hooksecurefunc(plate.Health, "SetWidth", function(_, w)
        bar:SetWidth(w)
    end)
    hooksecurefunc(plate.Health, "SetSize", function(_, _, w)
        bar:SetWidth(w)
    end)

    plate.Health.absorbBar = bar
end)

----------------------------------------------------------------
-- Updates
----------------------------------------------------------------

local function UpdateAbsorb(plate)
    local bar = plate.Health and plate.Health.absorbBar
    local calc = plate.Health and plate.Health.absorbCalc
    if not bar or not calc then return end

    local unit = plate.unit
    if not unit or RP.IsPassive(plate) or (plate.isMinor and RP.db.simplified.enabled) then
        bar:Hide()
        return
    end

    -- Debug: fake 30% absorb on a 60% health bar
    if RP.db.absorb.debug then
        plate.Health:SetMinMaxValues(0, 100)
        plate.Health:SetValue(60)
        bar:Show()
        bar:SetAlpha(1)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(30)
        return
    end

    -- Feed calculator
    UnitGetDetailedHealPrediction(unit, nil, calc)

    -- Phase 1: Default mode — get health values
    calc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
    calc:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)
    local health = calc:GetCurrentHealth()

    -- Phase 2: WithAbsorbs mode — get max including absorbs
    calc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.WithAbsorbs)
    local maxWithAbsorb = calc:GetMaximumDamageAbsorbs()

    -- Override health bar max so health fills less when absorbs exist
    plate.Health:SetMinMaxValues(0, maxWithAbsorb)
    plate.Health:SetValue(health)

    -- Get absorb amount (clamped to missing health)
    calc:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealthWithoutIncomingHeals)
    local absorb = calc:GetDamageAbsorbs()

    -- Absorb bar fills proportionally from health fill right edge
    bar:Show()
    bar:SetAlpha(absorb)
    bar:SetMinMaxValues(0, maxWithAbsorb)
    bar:SetValue(absorb)
end

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateHealth", function(original, plate)
    original(plate)
    UpdateAbsorb(plate)
end)

RP:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", function(_, unit)
    local NP = RP:GetModule("Nameplates")
    if not NP then return end
    for _, plate in pairs(NP.plates) do
        if plate.unit == unit then
            UpdateAbsorb(plate)
            break
        end
    end
end)

----------------------------------------------------------------
-- Cleanup
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateRemoved", function(original, plate)
    if plate.Health and plate.Health.absorbBar then
        plate.Health.absorbBar:Hide()
    end
    original(plate)
end)
