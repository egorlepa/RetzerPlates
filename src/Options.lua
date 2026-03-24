local _, ns = ...
local RP = ns.RP ---@type RP

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------

local FRAME_W, FRAME_H = 600, 580
local TAB_W = 140
local WIDGET_H = 28
local WIDGET_GAP = 4
local SLIDER_W = 180
local LABEL_W = 180
local SWATCH_SIZE = 20
local HEADER_GAP = 12
local CONTENT_PAD = 12

----------------------------------------------------------------
-- Refresh throttle
----------------------------------------------------------------

local refreshTimer

local function RefreshAllPlates()
    local NP = RP:GetModule("Nameplates")
    if not NP then return end

    -- Hide and discard all current plates
    for frame, plate in pairs(NP.plates) do
        plate:Hide()
    end
    wipe(NP.plates)

    RP:Call("SetCVars")
    RP:Call("SetClickSpace")

    -- Reconstruct all visible nameplates
    for _, frame in pairs(C_NamePlate.GetNamePlates()) do
        local plate = RP:Call("ConstructPlate", frame) --[[@as RPPlate]]
        NP.plates[frame] = plate
        RP:Call("OnPlateCreated", plate)

        local unit = frame.namePlateUnitToken
        if unit then
            RP:Call("SuppressBlizzardPlate", frame)
            plate.unit = unit
            plate.unitGUID = UnitGUID(unit)
            plate.frameType = RP:Call("GetFrameType", unit)
            RP:Call("UpdatePlate", plate)
            RP:Call("StartCastBarTicker", plate)
            RP:Call("UpdateCastBar", plate)
            plate:Show()
            RP:Call("OnPlateAdded", plate)
        end
    end
end

RP.RefreshAllPlates = RefreshAllPlates

local function ScheduleRefresh()
    if refreshTimer then return end
    refreshTimer = C_Timer.After(0.05, function()
        refreshTimer = nil
        RefreshAllPlates()
    end)
end

----------------------------------------------------------------
-- Widget: Header
----------------------------------------------------------------

local function CreateHeader(parent, label, yOffset)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    text:SetTextColor(0.8, 0.8, 0.8)
    text:SetText(label)
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    return WIDGET_H
end

----------------------------------------------------------------
-- Widget: Checkbox
----------------------------------------------------------------

local function CreateCheckbox(parent, sectionKey, key, def, yOffset)
    local btn = CreateFrame("CheckButton", nil, parent)
    btn:SetSize(20, 20)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 1)

    local border = btn:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.4, 0.4, 0.4, 1)

    local check = btn:CreateTexture(nil, "ARTWORK")
    check:SetPoint("TOPLEFT", 3, -3)
    check:SetPoint("BOTTOMRIGHT", -3, 3)
    check:SetColorTexture(1, 1, 1, 1)
    btn:SetCheckedTexture(check)

    btn:SetChecked(RP.db[sectionKey][key])

    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 12, "")
    label:SetTextColor(1, 1, 1)
    label:SetText(def.label)
    label:SetPoint("LEFT", btn, "RIGHT", 6, 0)

    if def.reload then
        local note = parent:CreateFontString(nil, "OVERLAY")
        note:SetFont(STANDARD_TEXT_FONT, 10, "")
        note:SetTextColor(0.6, 0.6, 0.6)
        note:SetText("(requires /reload)")
        note:SetPoint("LEFT", label, "RIGHT", 6, 0)
    end

    btn:SetScript("OnClick", function(self)
        RP.db[sectionKey][key] = self:GetChecked()
        ScheduleRefresh()
    end)

    btn._sectionKey = sectionKey
    btn._key = key
    btn._type = "checkbox"
    return WIDGET_H
end

----------------------------------------------------------------
-- Widget: Slider
----------------------------------------------------------------

local function CreateSlider(parent, sectionKey, key, def, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(LABEL_W + SLIDER_W + 60, WIDGET_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    -- Label
    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 12, "")
    label:SetTextColor(1, 1, 1)
    label:SetText(def.label)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(LABEL_W)
    label:SetJustifyH("LEFT")

    -- Slider
    local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
    slider:SetSize(SLIDER_W, 16)
    slider:SetPoint("LEFT", row, "LEFT", LABEL_W, 0)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    slider:SetBackdropColor(0.15, 0.15, 0.15, 1)
    slider:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(10, 16)
    thumb:SetColorTexture(0.7, 0.7, 0.7, 1)
    slider:SetThumbTexture(thumb)

    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(def.min, def.max)
    slider:SetValueStep(def.step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(true)

    -- Value readout
    local value = row:CreateFontString(nil, "OVERLAY")
    value:SetFont(STANDARD_TEXT_FONT, 12, "")
    value:SetTextColor(0.9, 0.9, 0.9)
    value:SetPoint("LEFT", slider, "RIGHT", 8, 0)

    local function FormatValue(v)
        if def.step < 1 then
            return string.format("%.2f", v)
        end
        return tostring(math.floor(v + 0.5))
    end

    local current = RP.db[sectionKey][key]
    slider:SetValue(current)
    value:SetText(FormatValue(current))

    slider:SetScript("OnValueChanged", function(self, v)
        -- Snap to step
        if def.step >= 1 then
            v = math.floor(v + 0.5)
        end
        RP.db[sectionKey][key] = v
        value:SetText(FormatValue(v))
        ScheduleRefresh()
    end)

    slider:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetValue() + delta * def.step
        v = math.max(def.min, math.min(def.max, v))
        self:SetValue(v)
    end)

    slider._sectionKey = sectionKey
    slider._key = key
    slider._type = "slider"
    return WIDGET_H
end

----------------------------------------------------------------
-- Widget: Color Picker
----------------------------------------------------------------

local function CreateColorPicker(parent, sectionKey, key, def, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(LABEL_W + SWATCH_SIZE + 10, WIDGET_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    -- Label
    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, 12, "")
    label:SetTextColor(1, 1, 1)
    label:SetText(def.label)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(LABEL_W)
    label:SetJustifyH("LEFT")

    -- Swatch
    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
    swatch:SetPoint("LEFT", row, "LEFT", LABEL_W, 0)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    swatch:SetBackdropBorderColor(0, 0, 0, 1)

    local c = RP.db[sectionKey][key]
    local hasAlpha = def.default.a ~= nil
    swatch:SetBackdropColor(c.r, c.g, c.b, 1)

    swatch:SetScript("OnClick", function()
        local cur = RP.db[sectionKey][key]
        local prev = { r = cur.r, g = cur.g, b = cur.b, a = cur.a }

        local info = {}
        info.r = cur.r
        info.g = cur.g
        info.b = cur.b
        info.hasOpacity = hasAlpha
        info.opacity = hasAlpha and (1 - (cur.a or 1)) or nil

        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            cur.r, cur.g, cur.b = r, g, b
            swatch:SetBackdropColor(r, g, b, 1)
            ScheduleRefresh()
        end

        if hasAlpha then
            info.opacityFunc = function()
                cur.a = 1 - ColorPickerFrame:GetColorAlpha()
                ScheduleRefresh()
            end
        end

        info.cancelFunc = function()
            cur.r, cur.g, cur.b, cur.a = prev.r, prev.g, prev.b, prev.a
            swatch:SetBackdropColor(prev.r, prev.g, prev.b, 1)
            ScheduleRefresh()
        end

        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    swatch._sectionKey = sectionKey
    swatch._key = key
    swatch._type = "color"
    return WIDGET_H
end

----------------------------------------------------------------
-- Widget dispatcher
----------------------------------------------------------------

local function CreateWidget(parent, sectionKey, key, def, yOffset)
    local d = def.default
    if type(d) == "boolean" then
        return CreateCheckbox(parent, sectionKey, key, def, yOffset)
    elseif type(d) == "number" and def.min then
        return CreateSlider(parent, sectionKey, key, def, yOffset)
    elseif type(d) == "table" and d.r ~= nil then
        return CreateColorPicker(parent, sectionKey, key, def, yOffset)
    end
    return 0
end

----------------------------------------------------------------
-- Reset helpers
----------------------------------------------------------------

local function ResetSection(sectionKey)
    local defaults = RP.defaults[sectionKey]
    if not defaults or not RP.db[sectionKey] then return end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            local cur = RP.db[sectionKey][k]
            if cur then
                for tk, tv in pairs(v) do cur[tk] = tv end
            end
        else
            RP.db[sectionKey][k] = v
        end
    end
    ScheduleRefresh()
end

----------------------------------------------------------------
-- Shared UI helpers
----------------------------------------------------------------

local BACKDROP_SOLID = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local function CreateButton(parent, label, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 24)
    btn:SetBackdrop(BACKDROP_SOLID)
    btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 11, "")
    text:SetText(label)
    text:SetPoint("CENTER")
    btn._text = text

    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.3, 0.3, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.2, 0.2, 1) end)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function CreateEditBox(parent, width)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, 24)
    box:SetBackdrop(BACKDROP_SOLID)
    box:SetBackdropColor(0.12, 0.12, 0.12, 1)
    box:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    box:SetFont(STANDARD_TEXT_FONT, 12, "")
    box:SetTextColor(1, 1, 1)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    return box
end

--- Simple dropdown: a button that opens a menu of choices below it.
--- onChange(value) is called when a choice is selected.
local function CreateDropdown(parent, width, choices, current, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 24)

    local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
    btn:SetSize(width, 24)
    btn:SetPoint("TOPLEFT")
    btn:SetBackdrop(BACKDROP_SOLID)
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 12, "")
    text:SetTextColor(1, 1, 1)
    text:SetText(current or "")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -20, 0)
    text:SetJustifyH("LEFT")

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(STANDARD_TEXT_FONT, 10, "")
    arrow:SetTextColor(0.6, 0.6, 0.6)
    arrow:SetText("v")
    arrow:SetPoint("RIGHT", -6, 0)

    -- Menu frame (hidden by default)
    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetBackdrop(BACKDROP_SOLID)
    menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
    menu:SetFrameStrata("TOOLTIP")
    menu:Hide()

    local function Refresh(newChoices, newCurrent)
        choices = newChoices or choices
        text:SetText(newCurrent or current or "")
        current = newCurrent or current

        -- Clear old items
        for _, child in pairs({ menu:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end

        local itemH = 22
        menu:SetSize(width, #choices * itemH + 4)

        for i, choice in ipairs(choices) do
            local item = CreateFrame("Button", nil, menu)
            item:SetSize(width - 4, itemH)
            item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * itemH)

            local itemHL = item:CreateTexture(nil, "BACKGROUND")
            itemHL:SetAllPoints()
            itemHL:SetColorTexture(0, 0, 0, 0)

            local itemText = item:CreateFontString(nil, "OVERLAY")
            itemText:SetFont(STANDARD_TEXT_FONT, 12, "")
            itemText:SetTextColor(0.9, 0.9, 0.9)
            itemText:SetText(choice)
            itemText:SetPoint("LEFT", 8, 0)

            item:SetScript("OnEnter", function() itemHL:SetColorTexture(1, 1, 1, 0.1) end)
            item:SetScript("OnLeave", function() itemHL:SetColorTexture(0, 0, 0, 0) end)
            item:SetScript("OnClick", function()
                current = choice
                text:SetText(choice)
                menu:Hide()
                if onChange then onChange(choice) end
            end)
        end
    end

    Refresh(choices, current)

    btn:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            Refresh(choices, current)
            menu:Show()
        end
    end)

    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.2, 0.2, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.15, 0.15, 0.15, 1) end)

    container.Refresh = Refresh
    container.GetValue = function() return current end
    return container
end

----------------------------------------------------------------
-- Profile management tab
----------------------------------------------------------------

local function ClearScrollChild(scrollChild)
    for _, child in pairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in pairs({ scrollChild:GetRegions() }) do
        region:Hide()
        region:SetParent(nil)
    end
end

local function PopulateProfileSection(scrollChild, repopulate)
    ClearScrollChild(scrollChild)

    local y = -CONTENT_PAD
    local aceDB = RP.aceDB
    local profiles = {}
    aceDB:GetProfiles(profiles)
    table.sort(profiles, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a < b
    end)

    local currentProfile = aceDB:GetCurrentProfile()

    -- Active Profile
    local h = CreateHeader(scrollChild, "Active Profile", y)
    y = y - h - WIDGET_GAP

    local profileDropdown = CreateDropdown(scrollChild, 200, profiles, currentProfile, function(choice)
        if choice ~= aceDB:GetCurrentProfile() then
            aceDB:SetProfile(choice)
            -- OnProfileChanged callback handles RP.db re-wire and plate refresh
            repopulate()
        end
    end)
    profileDropdown:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    y = y - 28 - WIDGET_GAP

    -- New Profile
    y = y - HEADER_GAP
    h = CreateHeader(scrollChild, "New Profile", y)
    y = y - h - WIDGET_GAP

    local nameBox = CreateEditBox(scrollChild, 200)
    nameBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)

    local createBtn = CreateButton(scrollChild, "Create", 70, function()
        local name = strtrim(nameBox:GetText())
        if name == "" then return end
        -- SetProfile auto-creates if profile doesn't exist
        aceDB:SetProfile(name)
        repopulate()
    end)
    createBtn:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
    nameBox:SetScript("OnEnterPressed", function() createBtn:GetScript("OnClick")(createBtn) end)
    y = y - 28 - WIDGET_GAP

    -- Copy From
    y = y - HEADER_GAP
    h = CreateHeader(scrollChild, "Copy Settings From", y)
    y = y - h - WIDGET_GAP

    local otherProfiles = {}
    for _, p in ipairs(profiles) do
        if p ~= currentProfile then
            otherProfiles[#otherProfiles + 1] = p
        end
    end

    if #otherProfiles > 0 then
        local copyDropdown = CreateDropdown(scrollChild, 200, otherProfiles, otherProfiles[1])
        copyDropdown:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)

        local copyBtn = CreateButton(scrollChild, "Copy", 70, function()
            local source = copyDropdown.GetValue()
            if source then
                aceDB:CopyProfile(source)
                -- OnProfileCopied callback handles refresh
                repopulate()
            end
        end)
        copyBtn:SetPoint("LEFT", copyDropdown, "RIGHT", 6, 0)
    else
        local noOther = scrollChild:CreateFontString(nil, "OVERLAY")
        noOther:SetFont(STANDARD_TEXT_FONT, 11, "")
        noOther:SetTextColor(0.5, 0.5, 0.5)
        noOther:SetText("No other profiles to copy from")
        noOther:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    end
    y = y - 28 - WIDGET_GAP

    -- Actions
    y = y - HEADER_GAP
    h = CreateHeader(scrollChild, "Actions", y)
    y = y - h - WIDGET_GAP

    local resetBtn = CreateButton(scrollChild, "Reset Profile", 110, function()
        aceDB:ResetProfile()
        repopulate()
    end)
    resetBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)

    if currentProfile ~= "Default" then
        local profileToDelete = currentProfile
        local deleteBtn = CreateButton(scrollChild, "Delete Profile", 110, function()
            aceDB:SetProfile("Default")
            aceDB:DeleteProfile(profileToDelete)
            repopulate()
        end)
        deleteBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    end
    y = y - 28 - WIDGET_GAP

    -- Display scaling
    y = y - HEADER_GAP
    h = CreateHeader(scrollChild, "Display Scaling", y)
    y = y - h - WIDGET_GAP

    local scaleInfo = scrollChild:CreateFontString(nil, "OVERLAY")
    scaleInfo:SetFont(STANDARD_TEXT_FONT, 11, "")
    scaleInfo:SetTextColor(0.5, 0.5, 0.5)
    scaleInfo:SetText(string.format("Scale factor: %.2f (baseline: 1440p @ 0.53)", RP.GetScaleFactor()))
    scaleInfo:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    y = y - 16 - WIDGET_GAP

    local rescaleBtn = CreateButton(scrollChild, "Recalculate Sizes", 150, function()
        RP.RescaleProfile()
        ScheduleRefresh()
        repopulate()
    end)
    rescaleBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    y = y - 28 - WIDGET_GAP

    local scaleWarning = scrollChild:CreateFontString(nil, "OVERLAY")
    scaleWarning:SetFont(STANDARD_TEXT_FONT, 10, "")
    scaleWarning:SetTextColor(0.6, 0.5, 0.3)
    scaleWarning:SetText("Resets all size settings to scaled defaults. Custom size tweaks will be lost.")
    scaleWarning:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    y = y - 16 - WIDGET_GAP

    -- Character info
    y = y - HEADER_GAP
    h = CreateHeader(scrollChild, "Current Character", y)
    y = y - h - WIDGET_GAP

    local charInfo = scrollChild:CreateFontString(nil, "OVERLAY")
    charInfo:SetFont(STANDARD_TEXT_FONT, 11, "")
    charInfo:SetTextColor(0.7, 0.7, 0.7)
    charInfo:SetText(UnitName("player") .. " - " .. GetRealmName())
    charInfo:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    y = y - 20

    scrollChild:SetHeight(math.abs(y) + CONTENT_PAD)
end

----------------------------------------------------------------
-- Section tabs (sorted by _meta.order)
----------------------------------------------------------------

local function GetSortedSections()
    local list = {
        { key = "_profiles", label = "Profiles", order = 0 },
    }
    for sectionKey, fields in pairs(RP.schema) do
        local meta = fields._meta
        if meta then
            list[#list + 1] = { key = sectionKey, label = meta.label, order = meta.order or 99 }
        end
    end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

----------------------------------------------------------------
-- Populate section content
----------------------------------------------------------------

local function PopulateSection(scrollChild, sectionKey)
    ClearScrollChild(scrollChild)

    if sectionKey == "_profiles" then
        PopulateProfileSection(scrollChild, function()
            PopulateSection(scrollChild, "_profiles")
        end)
        return
    end

    local section = RP.schema[sectionKey]
    if not section then return end

    local y = -CONTENT_PAD

    for _, entry in ipairs(section) do
        if entry.header then
            -- Sub-header
            y = y - HEADER_GAP
            local h = CreateHeader(scrollChild, entry.header, y)
            y = y - h - WIDGET_GAP
        elseif entry.key and not entry.hidden then
            local h = CreateWidget(scrollChild, sectionKey, entry.key, entry, y)
            y = y - h - WIDGET_GAP
        end
    end

    -- Reset button
    y = y - HEADER_GAP
    local resetBtn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    resetBtn:SetSize(100, 24)
    resetBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    resetBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    resetBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    resetBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local resetText = resetBtn:CreateFontString(nil, "OVERLAY")
    resetText:SetFont(STANDARD_TEXT_FONT, 11, "")
    resetText:SetText("Reset Section")
    resetText:SetPoint("CENTER")

    resetBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
    end)
    resetBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
    end)

    local currentSection = sectionKey
    resetBtn:SetScript("OnClick", function()
        ResetSection(currentSection)
        PopulateSection(scrollChild, currentSection)
    end)

    y = y - 30

    scrollChild:SetHeight(math.abs(y) + CONTENT_PAD)
end

----------------------------------------------------------------
-- Main frame construction
----------------------------------------------------------------

local function CreateOptionsFrame()
    local frame = CreateFrame("Frame", "RetzerPlatesOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    tinsert(UISpecialFrames, "RetzerPlatesOptionsFrame")

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    title:SetText("RetzerPlates")
    title:SetPoint("TOP", 0, -10)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    closeText:SetText("x")
    closeText:SetPoint("CENTER", 0, 0)
    closeText:SetTextColor(0.6, 0.6, 0.6)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    closeBtn:SetScript("OnEnter", function() closeText:SetTextColor(1, 1, 1) end)
    closeBtn:SetScript("OnLeave", function() closeText:SetTextColor(0.6, 0.6, 0.6) end)

    -- Tab panel (left)
    local tabPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    tabPanel:SetPoint("TOPLEFT", 8, -32)
    tabPanel:SetPoint("BOTTOMLEFT", 8, 8)
    tabPanel:SetWidth(TAB_W)
    tabPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    tabPanel:SetBackdropColor(0.12, 0.12, 0.12, 1)
    tabPanel:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    -- Content scroll area (right)
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tabPanel, "TOPRIGHT", 8, -CONTENT_PAD)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8 + CONTENT_PAD)

    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(FRAME_W - TAB_W - 56)

    -- Tab scroll area (inside tab panel)
    local tabScroll = CreateFrame("ScrollFrame", nil, tabPanel)
    tabScroll:SetPoint("TOPLEFT", 0, 0)
    tabScroll:SetPoint("BOTTOMRIGHT", 0, 0)
    tabScroll:EnableMouseWheel(true)
    tabScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 26)))
    end)

    local tabChild = CreateFrame("Frame", nil, tabScroll)
    tabChild:SetWidth(TAB_W)
    tabScroll:SetScrollChild(tabChild)

    -- Build tabs
    local sections = GetSortedSections()
    local tabButtons = {}
    local selectedTab

    local function SelectTab(index)
        if selectedTab then
            tabButtons[selectedTab].highlight:SetColorTexture(0, 0, 0, 0)
            tabButtons[selectedTab].text:SetTextColor(0.7, 0.7, 0.7)
        end
        selectedTab = index
        tabButtons[index].highlight:SetColorTexture(1, 1, 1, 0.1)
        tabButtons[index].text:SetTextColor(1, 1, 1)
        PopulateSection(scrollChild, sections[index].key)
    end

    for i, sec in ipairs(sections) do
        local tab = CreateFrame("Button", nil, tabChild)
        tab:SetSize(TAB_W - 4, 24)
        tab:SetPoint("TOPLEFT", tabChild, "TOPLEFT", 2, -2 - (i - 1) * 26)

        local highlight = tab:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0, 0, 0, 0)
        tab.highlight = highlight

        local text = tab:CreateFontString(nil, "OVERLAY")
        text:SetFont(STANDARD_TEXT_FONT, 12, "")
        text:SetTextColor(0.7, 0.7, 0.7)
        text:SetText(sec.label)
        text:SetPoint("LEFT", 8, 0)
        tab.text = text

        tab:SetScript("OnClick", function() SelectTab(i) end)
        tab:SetScript("OnEnter", function()
            if selectedTab ~= i then
                highlight:SetColorTexture(1, 1, 1, 0.05)
            end
        end)
        tab:SetScript("OnLeave", function()
            if selectedTab ~= i then
                highlight:SetColorTexture(0, 0, 0, 0)
            end
        end)

        tabButtons[i] = tab
    end

    tabChild:SetHeight(2 + #sections * 26)

    -- Select first tab
    SelectTab(1)

    return frame
end

----------------------------------------------------------------
-- Slash command
----------------------------------------------------------------

local optionsFrame

local function ToggleOptions()
    if InCombatLockdown() then
        print("|cffff6600RetzerPlates:|r Cannot open settings in combat")
        return
    end
    if not optionsFrame then
        optionsFrame = CreateOptionsFrame()
    end
    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        optionsFrame:Show()
    end
end

SLASH_RETZERPLATES1 = "/rp"
SlashCmdList["RETZERPLATES"] = ToggleOptions

-- Force-close options on combat start
RP:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    if optionsFrame and optionsFrame:IsShown() then
        optionsFrame:Hide()
    end
end)

----------------------------------------------------------------
-- Minimap button (LibDBIcon)
----------------------------------------------------------------

local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LDB and LibStub("LibDBIcon-1.0", true)

if LDB and LDBIcon then
    local broker = LDB:NewDataObject("RetzerPlates", {
        type = "data source",
        icon = "Interface\\AddOns\\RetzerPlates\\media\\icon",
        text = "RetzerPlates",
        showInCompartment = true,

        OnClick = function(_, button)
            if button == "LeftButton" then
                ToggleOptions()
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine("RetzerPlates")
            tooltip:AddLine("|cFFCFCFCFClick|r to open settings", 0.7, 0.7, 0.7)
        end,
    })

    RP:RegisterEvent("PLAYER_LOGIN", function()
        if not LDBIcon:IsRegistered("RetzerPlates") then
            LDBIcon:Register("RetzerPlates", broker, RP.aceDB.global.minimap)
        end
    end)
end
