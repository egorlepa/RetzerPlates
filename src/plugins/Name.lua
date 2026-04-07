local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field Name FontString?

---@class RPNameConfig
---@field enabled boolean
---@field fontSize number
---@field friendlyFontSize number

RP:RegisterSchema("name", {
    _meta = { label = "Name" },
    { key = "enabled",          default = true, label = "Enable Name Text" },
    { key = "fontSize",         default = 16,   label = "Font Size",          min = 8, max = 30, step = 1, scalable = true },
    { key = "friendlyFontSize", default = 22,   label = "Friendly Font Size", min = 8, max = 30, step = 1, scalable = true },
})

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("ConstructName", function(plate)
    local db = RP.db.name
    if not db.enabled then return end

    local text = plate.Health:CreateFontString(nil, "OVERLAY")
    text:SetFont(RP.GetTextFont(), db.fontSize, "OUTLINE")
    text:SetPoint("BOTTOMLEFT", plate.Health, "TOPLEFT", 0, 2)
    plate.Name = text
end)

----------------------------------------------------------------
-- Updates
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("UpdateName", function(plate)
    if not plate.Name then return end
    local unit = plate.unit
    if not unit then return end

    plate.Name:SetText(UnitName(unit))

    local r, g, b = RP:Call("GetNameColor", plate)
    if r then
        plate.Name:SetTextColor(r, g, b)
    else
        plate.Name:SetTextColor(1, 1, 1)
    end
end)

----------------------------------------------------------------
-- Layout: passive name repositioning
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateLayout", function(original, plate)
    original(plate)
    if not plate.Name then return end

    local db = RP.db.name
    local sdb = RP.db.simplified
    local isSimplified = plate.isMinor and sdb.enabled

    if RP.IsPassive(plate) then
        local fontSize = isSimplified and sdb.passiveFontSize or db.friendlyFontSize
        plate.Name:SetFont(RP.GetTextFont(), fontSize, "OUTLINE")
        plate.Name:ClearAllPoints()
        plate.Name:SetPoint("CENTER", plate.Health, "CENTER", 0, 0)
    else
        local fontSize = isSimplified and sdb.enemyFontSize or db.fontSize
        plate.Name:SetFont(RP.GetTextFont(), fontSize, "OUTLINE")
        plate.Name:ClearAllPoints()
        plate.Name:SetPoint("BOTTOMLEFT", plate.Health, "TOPLEFT", 0, 2)
    end
end)

---@param original function
---@param plate RPPlate
---@param factor number
RP:WrapHook("ScalePlate", function(original, plate, factor)
    original(plate, factor)
    if not plate.Name then return end
    local isMinorEnemy = plate.isMinor and not RP.IsPassive(plate) and RP.db.simplified.enabled
    local baseFs = isMinorEnemy and RP.db.simplified.enemyFontSize or RP.db.name.fontSize
    plate.Name:SetFont(RP.GetTextFont(), math.floor(baseFs * factor + 0.5), "OUTLINE")
end)

----------------------------------------------------------------
-- Color
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("GetNameColor", function(plate)
    local unit = plate.unit
    if not unit then return end

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local color = RAID_CLASS_COLORS[class]
        if color then
            return color.r, color.g, color.b
        end
    elseif RP.IsFriendly(plate.frameType) then
        local c = RP.db.healthbar.colorFriendly
        return c.r, c.g, c.b
    elseif RP.IsPassive(plate) then
        local c = RP.db.healthbar.colorNeutral
        return c.r, c.g, c.b
    end
end)
