local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPPlate
---@field CastBar RPCastBar?
---@field _debugCastBar boolean?
---@field _debugStart number?
---@field _debugEnd number?
---@field _debugBarEnd number?
---@field _debugCount number?
---@field _debugInterrupt boolean?

---@class RPCastBar : StatusBar
---@field bg Texture
---@field border Frame
---@field Icon Texture
---@field Text FontString
---@field _iconFrame Frame
---@field _fadeOut number?
---@field _fadeDuration number?
---@field _durationObject table?
---@field _hasTicker boolean?

---@class RPCastbarConfig
---@field enabled boolean
---@field debug boolean
---@field height number
---@field fontSize number
---@field fadeDuration number

RP:RegisterSchema("castbar", {
    _meta = { label = "Cast Bar" },
    { key = "enabled",      default = true,  label = "Enable Cast Bar" },
    { key = "debug",        default = false, label = "Debug Cast Bar" },
    { key = "height",       default = 20,    label = "Height",         min = 8, max = 40,  step = 1, scalable = true },
    { key = "fontSize",     default = 16,    label = "Font Size",      min = 8, max = 24,  step = 1, scalable = true },
    { key = "fadeDuration", default = 0.5,   label = "Fade Duration",  min = 0, max = 2.0, step = 0.1 },
})

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("ConstructCastBar", function(plate)
    local db = RP.db.castbar
    if not db.enabled then return end

    local bar = CreateFrame("StatusBar", nil, plate)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetSize(RP.db.healthbar.width, db.height)
    bar:SetPoint("BOTTOM", plate.Health, "TOP", 0, -1)
    bar:EnableMouse(false)
    bar:Hide()

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)

    local totalHeight = RP.db.healthbar.height + db.height - 1 -- shared border pixel
    local iconFrame = CreateFrame("Frame", nil, bar)
    iconFrame:SetSize(totalHeight, totalHeight)
    iconFrame:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
    iconFrame:EnableMouse(false)

    local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconBg:SetAllPoints()
    iconBg:SetColorTexture(0, 0, 0, 1)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFont(RP.GetTextFont(), db.fontSize, "OUTLINE")
    text:SetPoint("LEFT", bar, "LEFT", 4, 0)

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

    plate.CastBar = bar
    plate.CastBar.bg = bg
    plate.CastBar.border = border
    plate.CastBar.Icon = icon
    plate.CastBar.Text = text
    plate.CastBar._iconFrame = iconFrame

    -- Debug mode: auto-cycle fake casts
    if db.debug then
        plate._debugCastBar = true
        plate._debugCount = 0
        bar:SetScript("OnUpdate", function()
            RP:Call("UpdateDebugCastBar", plate)
        end)
    end

    -- Toggle name visibility and left anchor when castbar shows/hides
    bar:SetScript("OnShow", function()
        if plate.Name then plate.Name:Hide() end
        RP:SetLeftAnchor(plate, iconFrame)
    end)
    bar:SetScript("OnHide", function()
        if plate.Name then plate.Name:Show() end
        RP:ClearLeftAnchor(plate)
    end)
end)

----------------------------------------------------------------
-- Fade animation driver
----------------------------------------------------------------

local function FadeCastBar(castBar)
    if not castBar._fadeOut then return false end
    local remaining = castBar._fadeOut - GetTime()
    if remaining <= 0 then
        castBar._fadeOut = nil
        castBar._fadeDuration = nil
        castBar:SetAlpha(1)
        return false
    end
    castBar:SetAlpha(remaining / castBar._fadeDuration)
    return true
end

----------------------------------------------------------------
-- Updates
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("UpdateDebugCastBar", function(plate)
    if not plate.CastBar then return end
    if RP.IsPassive(plate) then return end

    if FadeCastBar(plate.CastBar) then return end

    local now = GetTime() * 1000
    local castDuration = 2000 -- 2 seconds in ms
    -- Initialize on first call or after fade finished
    if not plate._debugStart then
        plate._debugCount = (plate._debugCount or 0) + 1
        plate._debugStart = now
        plate._debugBarEnd = now + castDuration -- full duration for bar display
        -- Every 3rd cast gets interrupted at ~60% through
        plate._debugInterrupt = (plate._debugCount % 3 == 0)
        plate._debugEnd = now + (plate._debugInterrupt and (castDuration * 0.6) or castDuration)
    end
    -- Cast expired or interrupted — trigger stop animation
    if now >= plate._debugEnd then
        local reason = plate._debugInterrupt and "INTERRUPTED" or "SUCCESS"
        plate._debugStart = nil
        RP:Call("StopCastBar", plate, reason)
        return
    end
    plate.CastBar:SetMinMaxValues(plate._debugStart, plate._debugBarEnd)
    plate.CastBar:SetValue(now)
    plate.CastBar:SetReverseFill(false)
    plate.CastBar.Text:SetText("Shadow Bolt")
    plate.CastBar.Icon:SetTexture(136197)
    plate.CastBar.Icon:Show()
    plate.CastBar:SetStatusBarColor(1, 0.7, 0, 1)
    plate.CastBar:SetAlpha(1)
    plate.CastBar:Show()
end)

---@param plate RPPlate
RP:RegisterHook("UpdateCastBar", function(plate)
    if not plate.CastBar then return end

    if plate._debugCastBar then
        RP:Call("UpdateDebugCastBar", plate)
        return
    end

    local unit = plate.unit
    if not unit then return end

    if RP.IsPassive(plate) then
        plate.CastBar:Hide()
        return
    end

    -- UnitCastingInfo/UnitChannelInfo return secret/tainted values in Midnight.
    -- Workaround: use UnitCastingDuration/UnitChannelDuration + SetTimerDuration for progress,
    -- and C_CurveUtil.EvaluateColorValueFromBoolean for secret booleans (like Plater does).
    local name, _, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(unit)
    local channeling = false
    if not name then
        name, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
        channeling = true
    end

    if not name then
        plate.CastBar:Hide()
        return
    end

    local durationObject
    if channeling then
        durationObject = UnitChannelDuration(unit)
    else
        durationObject = UnitCastingDuration(unit)
    end

    if durationObject then
        local direction = channeling
            and Enum.StatusBarTimerDirection.RemainingTime
            or Enum.StatusBarTimerDirection.ElapsedTime
        plate.CastBar:SetMinMaxValues(startTime, endTime)
        plate.CastBar:SetTimerDuration(durationObject, Enum.StatusBarInterpolation.Immediate, direction)
        plate.CastBar._durationObject = durationObject
    end

    plate.CastBar.Text:SetText(name)
    if texture then
        plate.CastBar.Icon:SetTexture(texture)
        plate.CastBar.Icon:Show()
    else
        plate.CastBar.Icon:Hide()
    end

    RP:Call("UpdateCastBarColor", plate, notInterruptible)
    -- Clear any stale fade-out OnUpdate from a previous cast, otherwise it fires
    -- one more time, sees _fadeOut == nil, and hides the bar we just showed.
    if not plate._debugCastBar then
        plate.CastBar:SetScript("OnUpdate", nil)
    end
    plate.CastBar:SetAlpha(1)
    plate.CastBar._fadeOut = nil
    plate.CastBar:Show()
end)

---@param plate RPPlate
---@param notInterruptible any -- secret boolean
RP:RegisterHook("UpdateCastBarColor", function(plate, notInterruptible)
    -- notInterruptible is a secret boolean — use C API to branch on it
    -- EvaluateColorValueFromBoolean(secretBool, trueValue, falseValue)
    local r = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, 0.7, 1.0)
    local g = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, 0.7, 0.7)
    local b = C_CurveUtil.EvaluateColorValueFromBoolean(notInterruptible, 0.7, 0.0)
    plate.CastBar:SetStatusBarColor(r, g, b, 1)
end)

---@param plate RPPlate
RP:RegisterHook("StartCastBarTicker", function(plate)
    -- SetTimerDuration drives real casts automatically.
    -- Debug casts need an OnUpdate to loop.
    if plate._debugCastBar and plate.CastBar and not plate.CastBar._hasTicker then
        plate.CastBar:SetScript("OnUpdate", function()
            RP:Call("UpdateDebugCastBar", plate)
        end)
        plate.CastBar._hasTicker = true
    end
end)

---@param original function
---@param plate RPPlate
RP:WrapHook("UpdateLayout", function(original, plate)
    original(plate)
    if not plate.CastBar then return end
    local isMinorEnemy = plate.isMinor and not RP.IsPassive(plate) and RP.db.simplified.enabled
    if isMinorEnemy then
        local sdb = RP.db.simplified
        plate.CastBar:SetSize(sdb.enemyWidth, sdb.enemyCastBarHeight)
        plate.CastBar.Text:SetFont(RP.GetTextFont(), sdb.enemyCastBarFontSize, "OUTLINE")
        plate.CastBar._iconFrame:Hide()
    else
        plate.CastBar:SetSize(RP.db.healthbar.width, RP.db.castbar.height)
        plate.CastBar.Text:SetFont(RP.GetTextFont(), RP.db.castbar.fontSize, "OUTLINE")
        plate.CastBar._iconFrame:Show()
    end
end)

---@param original function
---@param plate RPPlate
---@param factor number
RP:WrapHook("ScalePlate", function(original, plate, factor)
    original(plate, factor)
    if not plate.CastBar then return end
    local isMinorEnemy = plate.isMinor and not RP.IsPassive(plate) and RP.db.simplified.enabled
    local baseW  = isMinorEnemy and RP.db.simplified.enemyWidth          or RP.db.healthbar.width
    local baseHH = isMinorEnemy and RP.db.simplified.enemyHeight         or RP.db.healthbar.height
    local baseCH = isMinorEnemy and RP.db.simplified.enemyCastBarHeight  or RP.db.castbar.height
    local baseFs = isMinorEnemy and RP.db.simplified.enemyCastBarFontSize or RP.db.castbar.fontSize
    local w  = math.floor(baseW  * factor + 0.5)
    local hh = math.floor(baseHH * factor + 0.5)
    local ch = math.floor(baseCH * factor + 0.5)
    plate.CastBar:SetSize(w, ch)
    plate.CastBar._iconFrame:SetSize(hh + ch - 1, hh + ch - 1)
    plate.CastBar.Text:SetFont(RP.GetTextFont(), math.floor(baseFs * factor + 0.5), "OUTLINE")
end)

---@param plate RPPlate
---@param reason string?
---@param interruptedBy string?
RP:RegisterHook("StopCastBar", function(plate, reason, interruptedBy)
    if not plate.CastBar then return end
    local cbConfig = RP.db.castbar
    if not cbConfig then return end

    -- Clear debug state so next UpdateCastBar starts fresh
    plate._debugStart = nil

    -- Freeze the bar using the duration object (like Plater)
    local dur = plate.CastBar._durationObject
    if dur then
        local total = dur:GetTotalDuration()
        plate.CastBar:SetMinMaxValues(0, total)
        plate.CastBar:SetValue(total) -- fill bar on stop
    end
    plate.CastBar._durationObject = nil

    local fadeDuration = cbConfig.fadeDuration
    local duration
    if reason == "INTERRUPTED" then
        plate.CastBar:SetStatusBarColor(1, 0, 0, 1)
        -- Show interrupter name with class color (like Plater)
        if interruptedBy then
            local _, class, _, _, _, name = GetPlayerInfoByGUID(interruptedBy)
            if name then
                local classColor = class and C_ClassColor.GetClassColor(class)
                local coloredName = classColor and classColor:WrapTextInColorCode(name) or name
                plate.CastBar.Text:SetText(INTERRUPTED .. " [" .. coloredName .. "]")
            else
                plate.CastBar.Text:SetText(INTERRUPTED)
            end
        else
            plate.CastBar.Text:SetText(INTERRUPTED)
        end
        duration = fadeDuration
    elseif reason == "SUCCESS" then
        plate.CastBar:SetStatusBarColor(0.2, 1, 0.2, 1)
        duration = fadeDuration
    end

    if duration then
        plate.CastBar._fadeOut = GetTime() + duration
        plate.CastBar._fadeDuration = duration
        -- Debug plates already have a permanent OnUpdate driving FadeCastBar
        if not plate._debugCastBar then
            plate.CastBar:SetScript("OnUpdate", function(self)
                if not FadeCastBar(self) then
                    self:Hide()
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    else
        plate.CastBar._fadeOut = nil
        plate.CastBar._fadeDuration = nil
        plate.CastBar:SetAlpha(1)
        if not plate._debugCastBar then
            plate.CastBar:SetScript("OnUpdate", nil)
        end
        plate.CastBar:Hide()
    end
end)
