local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field isQuest boolean?
---@field questObjectives string[]?

---@class RPHealthBar
---@field questContainer Frame?
---@field questIcons table[]?

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
-- Returns list of incomplete objective progress strings
----------------------------------------------------------------

local function GetQuestObjectives(unit)
    if not unit then return {} end
    local tooltipData = C_TooltipInfo.GetUnit(unit)
    if not tooltipData then return {} end

    local objectives = {}

    for _, line in ipairs(tooltipData.lines or {}) do
        if line.type == Enum.TooltipDataLineType.QuestObjective then
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
                objectives[#objectives + 1] = result
            end
        end
    end

    return objectives
end

----------------------------------------------------------------
-- Visual: quest icons + progress text on health bar
----------------------------------------------------------------

RP:RegisterRightSlot("quest")

local ICON_GAP = 2

--- Ensure icon+progress pair exists at the given index, create if needed
local function EnsureQuestIcon(plate, index)
    local icons = plate.Health.questIcons
    if icons[index] then return icons[index] end

    local db = RP.db.quest
    local container = plate.Health.questContainer

    local iconFrame = CreateFrame("Frame", nil, container, "BackdropTemplate")
    iconFrame:SetSize(db.iconSize, db.iconSize)
    iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    iconFrame:SetBackdropColor(0, 0, 0, 1)
    iconFrame:SetBackdropBorderColor(0, 0, 0, 1)
    iconFrame:EnableMouse(false)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetAtlas("QuestNormal")

    local progress = container:CreateFontString(nil, "OVERLAY")
    progress:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    progress:SetPoint("TOP", iconFrame, "BOTTOM", 1, -1)
    progress:SetJustifyH("CENTER")
    progress:SetTextColor(1, 0.82, 0)

    icons[index] = { frame = iconFrame, progress = progress }
    return icons[index]
end

---@param original function
---@param plate RPPlate
RP:WrapHook("ConstructHealth", function(original, plate)
    original(plate)

    local db = RP.db.quest
    if not db.enabled then return end

    local container = CreateFrame("Frame", nil, plate.Health)
    container:SetSize(db.iconSize, db.iconSize)
    container:EnableMouse(false)
    container:Hide()

    plate.Health.questContainer = container
    plate.Health.questIcons = {}
    RP:SetSlotFrame(plate, "quest", container)
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
            plate.questObjectives = { "3/5", "10%" }
        else
            plate.questObjectives = GetQuestObjectives(unit)
        end
        plate.isQuest = #plate.questObjectives > 0
    else
        plate.isQuest = false
        plate.questObjectives = {}
    end

    original(plate)

    if not plate.Health.questContainer then return end
    if not db.enabled then return end

    local count = #plate.questObjectives
    if count > 0 then
        -- Size container to fit all icons
        local totalWidth = count * db.iconSize + (count - 1) * ICON_GAP
        plate.Health.questContainer:SetSize(totalWidth, db.iconSize)

        for i = 1, count do
            local entry = EnsureQuestIcon(plate, i)
            entry.frame:ClearAllPoints()
            if i == 1 then
                entry.frame:SetPoint("LEFT", plate.Health.questContainer, "LEFT", 0, 0)
            else
                entry.frame:SetPoint("LEFT", plate.Health.questIcons[i - 1].frame, "RIGHT", ICON_GAP, 0)
            end
            entry.frame:Show()
            entry.progress:SetText(plate.questObjectives[i])
            entry.progress:Show()
        end

        -- Hide unused icons
        for i = count + 1, #plate.Health.questIcons do
            plate.Health.questIcons[i].frame:Hide()
            plate.Health.questIcons[i].progress:Hide()
        end

        RP:SetSlotActive(plate, "quest", true)
    else
        for i = 1, #plate.Health.questIcons do
            plate.Health.questIcons[i].frame:Hide()
            plate.Health.questIcons[i].progress:Hide()
        end
        RP:SetSlotActive(plate, "quest", false)
    end
end)

----------------------------------------------------------------
-- Clear quest state when plate is recycled
----------------------------------------------------------------

---@param original function
---@param plate RPPlate
RP:WrapHook("OnPlateRemoved", function(original, plate)
    plate.isQuest = false
    plate.questObjectives = {}
    if plate.Health and plate.Health.questIcons then
        for _, entry in ipairs(plate.Health.questIcons) do
            entry.frame:Hide()
            entry.progress:Hide()
        end
    end
    if plate.Health and plate.Health.questContainer then
        plate.Health.questContainer:Hide()
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
