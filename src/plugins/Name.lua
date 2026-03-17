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
    { key = "fontSize",         default = 16,   label = "Font Size",          min = 8, max = 30, step = 1 },
    { key = "friendlyFontSize", default = 20,   label = "Friendly Font Size", min = 8, max = 30, step = 1 },
})

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("ConstructName", function(plate)
    local db = RP.db.name
    if not db.enabled then return end

    local text = plate.Health:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
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
    if RP.IsPassive(plate) then
        plate.Name:SetFont(STANDARD_TEXT_FONT, db.friendlyFontSize, "OUTLINE")
        plate.Name:ClearAllPoints()
        plate.Name:SetPoint("CENTER", plate.Health, "CENTER", 0, 0)
    else
        plate.Name:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
        plate.Name:ClearAllPoints()
        plate.Name:SetPoint("BOTTOMLEFT", plate.Health, "TOPLEFT", 0, 2)
    end
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
