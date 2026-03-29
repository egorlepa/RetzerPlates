local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field Health RPHealthBar

---@class RPHealthBar : StatusBar
---@field barTexture Texture
---@field bg Texture
---@field border Frame
---@field highlight Texture

---@class RPHealthbarConfig
---@field width number
---@field height number
---@field colorByClass boolean
---@field colorByReaction boolean
---@field colorFriendly RPColor
---@field colorNeutral RPColor
---@field colorHostile RPColor
---@field colorTapped RPColor

RP:RegisterSchema("healthbar", {
    _meta = { label = "Health Bar" },
    { key = "width",           default = 200,                              label = "Width",            min = 80, max = 400, step = 5, scalable = true },
    { key = "height",          default = 20,                               label = "Height",           min = 4,  max = 60,  step = 1, scalable = true },
    { key = "colorByClass",    default = true,                             label = "Color by Class" },
    { key = "colorByReaction", default = true,                             label = "Color by Reaction" },
    { key = "colorFriendly",   default = { r = 0.29, g = 0.69, b = 0.30 }, label = "Friendly Color" },
    { key = "colorNeutral",    default = { r = 0.85, g = 0.77, b = 0.36 }, label = "Neutral Color" },
    { key = "colorHostile",    default = { r = 0.78, g = 0.25, b = 0.25 }, label = "Hostile Color" },
    { key = "colorTapped",     default = { r = 0.90, g = 0.90, b = 0.90 }, label = "Tapped Color" },
})

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("ConstructHealth", function(plate)
    local db = RP.db.healthbar

    local bar = CreateFrame("StatusBar", nil, plate)
    local barTex = bar:CreateTexture(nil, "ARTWORK")
    barTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarTexture(barTex)
    bar.barTexture = barTex
    bar:SetMinMaxValues(0, 1)
    bar:SetSize(db.width, db.height)
    bar:SetPoint("CENTER", plate, "CENTER", 0, RP.db.general.yOffset or 0)
    bar:EnableMouse(false)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)

    local border = CreateFrame("Frame", nil, bar)
    border:SetAllPoints(bar)
    border:EnableMouse(false)
    for _, e in ipairs({
        {"TOPLEFT", "TOPRIGHT", "SetHeight"},
        {"BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight"},
        {"TOPLEFT", "BOTTOMLEFT", "SetWidth"},
        {"TOPRIGHT", "BOTTOMRIGHT", "SetWidth"},
    }) do
        local t = border:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0, 0, 0, 1)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        t[e[3]](t, 1)
    end

    local highlight = bar:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.3)
    highlight:Hide()

    plate.Health = bar
    plate.Health.bg = bg
    plate.Health.border = border
    plate.Health.highlight = highlight
end)

----------------------------------------------------------------
-- Updates
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("UpdateHealth", function(plate)
    local unit = plate.unit
    if not unit then return end

    -- UnitHealth/UnitHealthMax return secret values — pass directly to C API
    plate.Health:SetMinMaxValues(0, UnitHealthMax(unit))
    plate.Health:SetValue(UnitHealth(unit))
end)

---@param plate RPPlate
RP:RegisterHook("UpdateHealthColor", function(plate)
    if RP.IsPassive(plate) then
        plate.Health:SetStatusBarColor(0, 0, 0, 0)
        return
    end
    local r, g, b = RP:Call("GetHealthColor", plate)
    if r then
        plate.Health:SetStatusBarColor(r, g, b, 1)
    end
end)

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateLayout", function(original, plate)
    original(plate)
    local isMinorEnemy = plate.isMinor and not RP.IsPassive(plate) and RP.db.simplified.enabled
    if RP.IsPassive(plate) then
        plate.Health.bg:Hide()
        plate.Health.border:Hide()
    elseif isMinorEnemy then
        local sdb = RP.db.simplified
        plate.Health:SetSize(sdb.enemyWidth, sdb.enemyHeight)
        plate.Health.bg:Show()
        plate.Health.border:Show()
    else
        plate.Health:SetSize(RP.db.healthbar.width, RP.db.healthbar.height)
        plate.Health.bg:Show()
        plate.Health.border:Show()
    end
end)

---@param original function
---@param plate RPPlate
---@param factor number
RP:WrapHook("ScalePlate", function(original, plate, factor)
    original(plate, factor)
    local isMinorEnemy = plate.isMinor and not RP.IsPassive(plate) and RP.db.simplified.enabled
    local w = isMinorEnemy and RP.db.simplified.enemyWidth  or RP.db.healthbar.width
    local h = isMinorEnemy and RP.db.simplified.enemyHeight or RP.db.healthbar.height
    plate.Health:SetSize(math.floor(w * factor + 0.5), math.floor(h * factor + 0.5))
end)

---@param plate RPPlate
RP:RegisterHook("GetHealthColor", function(plate)
    local unit = plate.unit
    if not unit then return end

    local db = RP.db.healthbar

    -- Tapped units (tagged by another player)
    if UnitIsTapDenied(unit) then
        local c = db.colorTapped
        return c.r, c.g, c.b
    end

    if db.colorByClass and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local color = RAID_CLASS_COLORS[class]
        if color then
            return color.r, color.g, color.b
        end
    end

    if db.colorByReaction then
        local reaction = UnitReaction("player", unit)
        if reaction then
            if reaction >= 5 then
                local c = db.colorFriendly
                return c.r, c.g, c.b
            elseif reaction == 4 then
                local c = db.colorNeutral
                return c.r, c.g, c.b
            else
                local c = db.colorHostile
                return c.r, c.g, c.b
            end
        end
    end
end)
