local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field Title FontString?

---@class RPTitleConfig
---@field enabled boolean
---@field fontSize number
---@field showGuild boolean
---@field showNPCTitle boolean

RP:RegisterSchema("title", {
    _meta = { label = "Title" },
    { key = "enabled",      default = true, label = "Enable Title Text" },
    { key = "fontSize",     default = 16,   label = "Font Size",       min = 8, max = 20, step = 1 },
    { key = "showGuild",    default = true, label = "Show Guild Name" },
    { key = "showNPCTitle", default = true, label = "Show NPC Title" },
})

----------------------------------------------------------------
-- Title detection
----------------------------------------------------------------

local function GetTitleText(unit, db)
    if UnitIsPlayer(unit) then
        if not db.showGuild then return nil end
        local guild = GetGuildInfo(unit)
        if guild then return "<" .. guild .. ">" end
        return nil
    end

    if not db.showNPCTitle then return nil end

    -- NPC subtitle via tooltip scan (no visible tooltip)
    local tooltipData = C_TooltipInfo.GetUnit(unit)
    if not tooltipData or not tooltipData.lines then return nil end

    local line2 = tooltipData.lines[2]
    if not line2 then return nil end

    -- Skip quest lines
    if line2.type == Enum.TooltipDataLineType.QuestTitle then return nil end
    if line2.type == Enum.TooltipDataLineType.QuestObjective then return nil end

    -- leftText may be a secret value — pcall for safety
    local ok, text = pcall(function()
        local t = line2.leftText
        if not t or t == "" then return nil end
        -- Skip level lines (e.g. "Level 90", "Level 90 (Elite)")
        if t:match("^Level ") then return nil end
        return t
    end)

    if ok and text then return text end
    return nil
end

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructName", function(original, plate)
    original(plate)

    local db = RP.db.title
    if not db.enabled then return end
    if not plate.Name then return end

    local text = plate.Health:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    text:SetTextColor(0.7, 0.7, 0.7)
    text:SetPoint("TOPLEFT", plate.Name, "BOTTOMLEFT", 0, -1)
    plate.Title = text
end)

----------------------------------------------------------------
-- Updates
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateName", function(original, plate)
    original(plate)
    if not plate.Title then return end

    local unit = plate.unit
    if not unit then
        plate.Title:Hide()
        return
    end

    local title = (RP.IsPassive(plate) or RP.IsFriendly(plate.frameType)) and GetTitleText(unit, RP.db.title) or nil
    if title then
        plate.Title:SetText(title)
        plate.Title:Show()
    else
        plate.Title:Hide()
    end
end)

----------------------------------------------------------------
-- Layout: reposition for passive units
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateLayout", function(original, plate)
    original(plate)
    if not plate.Title then return end

    local db = RP.db.title
    plate.Title:ClearAllPoints()

    if RP.IsPassive(plate) then
        plate.Title:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
        plate.Title:SetPoint("TOP", plate.Name, "BOTTOM", 0, -1)
    else
        plate.Title:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
        plate.Title:SetPoint("TOPLEFT", plate.Name, "BOTTOMLEFT", 0, -1)
    end
end)
