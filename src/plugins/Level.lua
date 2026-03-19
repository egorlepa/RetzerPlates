local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field Level FontString?

---@class RPLevelConfig
---@field enabled boolean
---@field fontSize number
---@field hideMaxLevel boolean
---@field hideForPlayers boolean

RP:RegisterSchema("level", {
    _meta = { label = "Level" },
    { key = "enabled",        default = true,  label = "Enable Level Text" },
    { key = "fontSize",       default = 14,    label = "Font Size",          min = 8, max = 24, step = 1 },
    { key = "hideMaxLevel",   default = true,  label = "Hide at Max Level" },
    { key = "hideForPlayers", default = true,  label = "Hide for Players" },
})

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructName", function(original, plate)
    original(plate)

    local db = RP.db.level
    if not db.enabled then return end

    local text = plate.Health:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    text:SetPoint("BOTTOMRIGHT", plate.Health, "TOPRIGHT", 0, 2)
    plate.Level = text
end)

----------------------------------------------------------------
-- Updates
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateName", function(original, plate)
    original(plate)
    if not plate.Level then return end

    local unit = plate.unit
    if not unit then
        plate.Level:Hide()
        return
    end

    local db = RP.db.level

    -- Hide for players if configured
    if db.hideForPlayers and UnitIsPlayer(unit) then
        plate.Level:Hide()
        return
    end

    local level = UnitLevel(unit)

    -- Boss-level units
    if level == -1 then
        plate.Level:SetText("??")
        plate.Level:SetTextColor(1, 0, 0)
        plate.Level:Show()
        return
    end

    -- Hide max-level units if configured
    if db.hideMaxLevel and level >= GetMaxPlayerLevel() then
        plate.Level:Hide()
        return
    end

    plate.Level:SetText(level)
    local color = GetQuestDifficultyColor(level)
    plate.Level:SetTextColor(color.r, color.g, color.b)
    plate.Level:Show()
end)

----------------------------------------------------------------
-- Layout: reposition for passive units
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateLayout", function(original, plate)
    original(plate)
    if not plate.Level then return end

    local db = RP.db.level
    plate.Level:ClearAllPoints()

    if RP.IsPassive(plate) then
        plate.Level:Hide()
        return
    end

    plate.Level:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    plate.Level:SetPoint("BOTTOMRIGHT", plate.Health, "TOPRIGHT", 0, 2)
end)
