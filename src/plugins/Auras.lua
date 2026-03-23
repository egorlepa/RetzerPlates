local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field AuraContainer RPAuraContainer?

---@class RPAuraContainer : Frame
---@field icons RPIconFrame[]
---@field db table

---@class RPAurasConfig
---@field enabled boolean
---@field debug boolean
---@field iconSize number
---@field spacing number
---@field groupGap number
---@field maxIcons number
---@field showDebuffs boolean
---@field showBuffs boolean
---@field onlyMine boolean
---@field durationFontSize number
---@field stackFontSize number

RP:RegisterSchema("auras", {
    _meta = { label = "Auras" },
    { key = "enabled",          default = true,  label = "Enable Auras" },
    { key = "debug",            default = false, label = "Debug Auras" },
    { key = "iconSize",         default = 30,    label = "Icon Size",          min = 14, max = 60, step = 1, scalable = true },
    { key = "spacing",          default = 2,     label = "Spacing",            min = 0,  max = 10, step = 1, scalable = true },
    { key = "groupGap",         default = 10,    label = "Group Gap",          min = 0,  max = 30, step = 1, scalable = true },
    { key = "maxIcons",         default = 6,     label = "Max Icons",          min = 1,  max = 20, step = 1 },
    { key = "showDebuffs",      default = true,  label = "Show Debuffs" },
    { key = "showBuffs",        default = true,  label = "Show Buffs" },
    { key = "onlyMine",         default = true,  label = "Only My Debuffs" },
    { key = "durationFontSize", default = 20,    label = "Duration Font Size", min = 8,  max = 30, step = 1, scalable = true },
    { key = "stackFontSize",    default = 16,    label = "Stack Font Size",    min = 8,  max = 24, step = 1, scalable = true },
})

----------------------------------------------------------------
-- Construction: aura container below health bar
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructHealth", function(original, plate)
    original(plate)

    local db = RP.db.auras
    if not db.enabled then return end

    local container = CreateFrame("Frame", nil, plate.Health)
    container:SetPoint("TOPLEFT", plate.Health, "BOTTOMLEFT", 0, -2)
    container:SetSize(RP.db.healthbar.width, db.iconSize)
    container:EnableMouse(false)

    container.icons = {}
    container.db = db

    plate.AuraContainer = container
end)

----------------------------------------------------------------
-- Fetch auras via C_UnitAuras
----------------------------------------------------------------

--- Read auraInstanceIDs that Blizzard's nameplate chose to display.
--- The C engine filters these; we just read the result.
local function GetBlizzardAuraIDs(plate)
    local parent = plate:GetParent()
    local uf = parent and parent.UnitFrame
    if not uf or uf:IsForbidden() then return nil, nil end

    local aurasFrame = uf.AurasFrame
    if not aurasFrame then return nil, nil end

    local blizzBuffs, blizzDebuffs

    local buffList = aurasFrame.BuffListFrame
    if buffList then
        blizzBuffs = {}
        for _, child in ipairs(buffList:GetLayoutChildren()) do
            if child.auraInstanceID then
                blizzBuffs[child.auraInstanceID] = true
            end
        end
    end

    local debuffList = aurasFrame.DebuffListFrame
    if debuffList then
        blizzDebuffs = {}
        for _, child in ipairs(debuffList:GetLayoutChildren()) do
            if child.auraInstanceID then
                blizzDebuffs[child.auraInstanceID] = true
            end
        end
    end

    return blizzBuffs, blizzDebuffs
end

local function GetUnitAuras(unit, db, blizzBuffs, blizzDebuffs)
    local buffs = {}
    local debuffs = {}

    if db.showBuffs then
        local results = C_UnitAuras.GetUnitAuras(unit, "HELPFUL", nil, Enum.UnitAuraSortRule.Expiration)
        if results then
            for _, aura in ipairs(results) do
                if not blizzBuffs or blizzBuffs[aura.auraInstanceID] then
                    buffs[#buffs + 1] = aura
                end
            end
        end
    end

    if db.showDebuffs then
        local filter = db.onlyMine and "HARMFUL|PLAYER" or "HARMFUL"
        local results = C_UnitAuras.GetUnitAuras(unit, filter, nil, Enum.UnitAuraSortRule.Expiration)
        if results then
            for _, aura in ipairs(results) do
                if not blizzDebuffs or blizzDebuffs[aura.auraInstanceID] then
                    debuffs[#debuffs + 1] = aura
                end
            end
        end
    end

    return buffs, debuffs
end

----------------------------------------------------------------
-- Debug: fake aura data
----------------------------------------------------------------

local debugIcons = {
    "Interface\\Icons\\Spell_Holy_PowerWordShield",
    "Interface\\Icons\\Spell_Nature_Rejuvenation",
    "Interface\\Icons\\Spell_Holy_Renew",
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Ability_Rogue_Rupture",
    "Interface\\Icons\\Spell_Fire_FlameBolt",
    "Interface\\Icons\\Spell_Nature_LightningShield",
    "Interface\\Icons\\Spell_Frost_FrostNova",
}

local function GetDebugAuras(db)
    local buffs = {}
    local debuffs = {}
    local now = GetTime()

    if db.showBuffs then
        for i = 1, 3 do
            buffs[#buffs + 1] = {
                icon = debugIcons[i],
                _debugStart = now,
                _debugDuration = 10 + i * 5,
                applications = i == 2 and 3 or nil,
            }
        end
    end

    if db.showDebuffs then
        for i = 1, 4 do
            debuffs[#debuffs + 1] = {
                icon = debugIcons[3 + i],
                _debugStart = now,
                _debugDuration = 5 + i * 3,
                applications = i == 1 and 2 or nil,
            }
        end
    end

    return buffs, debuffs
end

----------------------------------------------------------------
-- Update aura display
----------------------------------------------------------------

local function UpdateAuras(plate)
    local container = plate.AuraContainer
    if not container then return end

    local unit = plate.unit
    if not unit then return end

    -- Hide auras on passive or simplified minor units
    if RP.IsPassive(plate) or (plate.isMinor and RP.db.simplified.enabled) then
        for _, icon in ipairs(container.icons) do
            icon:Hide()
        end
        return
    end

    local db = container.db
    local isDebug = db.debug
    local buffs, debuffs
    if isDebug then
        buffs, debuffs = GetDebugAuras(db)
    else
        local blizzBuffs, blizzDebuffs = GetBlizzardAuraIDs(plate)
        buffs, debuffs = GetUnitAuras(unit, db, blizzBuffs, blizzDebuffs)
    end
    local groupGap = db.groupGap

    local shown = 0
    local xOffset = 0

    -- Helper to show one aura icon at current xOffset
    local function ShowAura(aura, isBuff)
        if shown >= db.maxIcons then return false end
        shown = shown + 1

        local iconFrame = container.icons[shown]
        if not iconFrame then
            iconFrame = RP.CreateIconFrame(container, db)
            container.icons[shown] = iconFrame
        end

        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("TOPLEFT", container, "TOPLEFT", xOffset, 0)
        xOffset = xOffset + db.iconSize + db.spacing

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

        if isBuff then
            iconFrame:SetBorderColor(0, 0.5, 1, 1)
        else
            iconFrame:SetBorderColor(0.8, 0, 0, 1)
        end

        iconFrame.auraInstanceID = aura.auraInstanceID
        iconFrame:Show()
        return true
    end

    -- Buffs first
    for _, aura in ipairs(buffs) do
        if not ShowAura(aura, true) then break end
    end

    -- Add gap between groups if both have entries
    if #buffs > 0 and #debuffs > 0 and shown < db.maxIcons then
        xOffset = xOffset + groupGap
    end

    -- Then debuffs
    for _, aura in ipairs(debuffs) do
        if not ShowAura(aura, false) then break end
    end

    -- Hide unused icons
    for i = shown + 1, #container.icons do
        container.icons[i]:Hide()
    end
end

----------------------------------------------------------------
-- Hook into plate lifecycle
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdatePlate", function(original, plate)
    original(plate)
    UpdateAuras(plate)
end)

-- Listen for UNIT_AURA to refresh in real-time.
-- Defer by one frame so Blizzard's UnitFrame processes the event first
-- and populates its AurasFrame — we read from that as a whitelist.
RP:RegisterEvent("UNIT_AURA", function(_, unitToken)
    if not unitToken:find("nameplate") then return end
    C_Timer.After(0, function()
        local NP = RP:GetModule("Nameplates")
        if not NP then return end

        local frame = C_NamePlate.GetNamePlateForUnit(unitToken)
        if not frame then return end

        local plate = NP.plates[frame]
        if not plate or not plate.unit then return end

        UpdateAuras(plate)
    end)
end)

-- Clear on plate removal
---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateRemoved", function(original, plate)
    if plate.AuraContainer then
        for _, icon in ipairs(plate.AuraContainer.icons) do
            icon:Hide()
        end
    end
    original(plate)
end)
