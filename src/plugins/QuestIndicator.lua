local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field isQuest boolean?
---@field questProgress string?

---@class RPHealthBar
---@field questIcon Frame?
---@field questProgress FontString?

---@class RPQuestConfig
---@field enabled boolean
---@field debug boolean
---@field colorEnemy RPColor
---@field colorNeutral RPColor
---@field iconSize number
---@field fontSize number

RP:RegisterSchema("quest", {
    _meta = { label = "Quest" },
    { key = "enabled",      default = true,                             label = "Enable Quest Indicator" },
    { key = "debug",        default = false,                            label = "Debug Quest" },
    { key = "colorEnemy",   default = { r = 1.0, g = 0.37, b = 0.0 },  label = "Enemy Quest Color" },
    { key = "colorNeutral", default = { r = 1.0, g = 0.65, b = 0.0 },  label = "Neutral Quest Color" },
    { key = "iconSize",     default = 30,                               label = "Icon Size",             min = 14, max = 60, step = 1 },
    { key = "fontSize",     default = 14,                               label = "Font Size",             min = 8,  max = 24, step = 1 },
})

----------------------------------------------------------------
-- Per-unit quest detection via tooltip scan
-- Returns: isQuest, progressText (e.g. "8/10" or "30%")
----------------------------------------------------------------

local function GetQuestInfo(unit)
    -- Tooltip scan via C_TooltipInfo (no visible tooltip needed)
    if not unit then return false, nil end
    local tooltipData = C_TooltipInfo.GetUnit(unit)
    if not tooltipData then return false, nil end

    local isQuest = false
    local progress = nil

    for _, line in ipairs(tooltipData.lines or {}) do
        if line.type == Enum.TooltipDataLineType.QuestTitle then
            isQuest = true
        elseif line.type == Enum.TooltipDataLineType.QuestObjective then
            isQuest = true
            -- leftText may be a secret value in Midnight — pcall all text operations
            local ok, result = pcall(function()
                local text = line.leftText or ""
                if text == "" then return nil end
                -- "8/10 Wolves slain" → "8/10"
                local current, total = text:match("(%d+)/(%d+)")
                if current and total then
                    if tonumber(current) < tonumber(total) then
                        return current .. "/" .. total
                    end
                    return nil
                end
                -- "30% complete" → "30%"
                local pct = text:match("(%d+)%%")
                if pct and tonumber(pct) < 100 then
                    return pct .. "%"
                end
                return nil
            end)
            if ok and result then
                progress = result
            end
        end
    end

    return isQuest, progress
end

----------------------------------------------------------------
-- Visual: quest icon + progress text on health bar
----------------------------------------------------------------

RP:RegisterRightSlot("quest")

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructHealth", function(original, plate)
    original(plate)

    local db = RP.db.quest
    if not db.enabled then return end

    local iconFrame = CreateFrame("Frame", nil, plate.Health, "BackdropTemplate")
    iconFrame:SetSize(db.iconSize, db.iconSize)
    iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    iconFrame:SetBackdropColor(0, 0, 0, 1)
    iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
    iconFrame:EnableMouse(false)
    iconFrame:Hide()

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    icon:SetAtlas("QuestNormal")
    icon:SetTexCoord(0, 1, 0, 1)

    local progressText = plate.Health:CreateFontString(nil, "OVERLAY")
    progressText:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    progressText:SetPoint("TOP", iconFrame, "BOTTOM", 1, -1)
    progressText:SetJustifyH("CENTER")
    progressText:SetTextColor(1, 0.82, 0)
    progressText:Hide()

    plate.Health.questIcon = iconFrame
    plate.Health.questProgress = progressText
    RP:SetSlotFrame(plate, "quest", iconFrame)
end)

----------------------------------------------------------------
-- Update quest status on plate show
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdatePlate", function(original, plate)
    -- Detect quest status BEFORE original so GetHealthColor has the flag
    local db = RP.db.quest
    local unit = plate.unit
    if db and db.enabled and unit then
        if db.debug then
            plate.isQuest = true
            plate.questProgress = "3/5"
        else
            local isQuest, progress = GetQuestInfo(unit)
            plate.isQuest = isQuest
            plate.questProgress = progress
        end
    else
        plate.isQuest = false
        plate.questProgress = nil
    end

    original(plate)

    if not plate.Health.questIcon then return end
    if not db.enabled then return end

    if plate.isQuest then
        RP:SetSlotActive(plate, "quest", true)
        if plate.questProgress then
            plate.Health.questProgress:SetText(plate.questProgress)
            plate.Health.questProgress:Show()
        else
            plate.Health.questProgress:Hide()
        end
    else
        RP:SetSlotActive(plate, "quest", false)
        plate.Health.questProgress:Hide()
    end
end)

----------------------------------------------------------------
-- Clear quest state when plate is recycled
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateRemoved", function(original, plate)
    plate.isQuest = false
    plate.questProgress = nil
    if plate.Health and plate.Health.questIcon then
        plate.Health.questIcon:Hide()
    end
    if plate.Health and plate.Health.questProgress then
        plate.Health.questProgress:Hide()
    end
    original(plate)
end)

----------------------------------------------------------------
-- Color quest mobs
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("GetHealthColor", function(original, plate)
    if plate.isQuest then
        local db = RP.db.quest
        local unit = plate.unit
        if unit and UnitCanAttack("player", unit) then
            local reaction = UnitReaction("player", unit)
            if reaction and reaction == 4 then
                return db.colorNeutral.r, db.colorNeutral.g, db.colorNeutral.b
            end
            return db.colorEnemy.r, db.colorEnemy.g, db.colorEnemy.b
        end
    end
    return original(plate)
end)
