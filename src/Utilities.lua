local _, ns = ...
local RP = ns.RP ---@type RP

----------------------------------------------------------------
-- Shared icon frame factory (used by Auras, CrowdControl, etc.)
----------------------------------------------------------------

---@class RPIconFrame : Frame
---@field Icon Texture
---@field Border Texture
---@field Cooldown Cooldown
---@field Stack FontString
---@field auraInstanceID number?
---@field SetBorderColor fun(self, r: number, g: number, b: number, a: number)

function RP.CreateIconFrame(parent, db)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(db.iconSize, db.iconSize)
    frame:EnableMouse(false)

    -- Plain texture instead of BackdropTemplate to avoid taint from
    -- SetCooldownFromDurationObject propagating to Backdrop.lua arithmetic
    local border = frame:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)
    frame.Border = border

    function frame:SetBorderColor(r, g, b, a)
        border:SetColorTexture(r, g, b, a)
    end

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.Icon = icon

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:EnableMouse(false)
    if cooldown.EnableMouseMotion then cooldown:EnableMouseMotion(false) end
    cooldown:SetDrawEdge(false)
    cooldown:SetReverse(true)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:SetMinimumCountdownDuration(0)
    cooldown:SetCountdownAbbrevThreshold(60)
    -- Grab the built-in countdown fontstring and resize it
    local timerRegion = cooldown:GetRegions()
    if timerRegion and timerRegion:IsObjectType("FontString") then
        ---@cast timerRegion FontString
        timerRegion:SetFont(STANDARD_TEXT_FONT, db.durationFontSize, "OUTLINE")
    end
    frame.Cooldown = cooldown

    local stackFrame = CreateFrame("Frame", nil, frame)
    stackFrame:SetAllPoints()
    stackFrame:SetFrameLevel(cooldown:GetFrameLevel() + 2)
    local stack = stackFrame:CreateFontString(nil, "OVERLAY")
    stack:SetFont(STANDARD_TEXT_FONT, db.stackFontSize, "OUTLINE")
    stack:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
    stack:SetJustifyH("RIGHT")
    stack:Hide()
    frame.Stack = stack

    frame:Hide()
    return frame --[[@as RPIconFrame]]
end
