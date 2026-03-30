-- RetzerUI-1.0
-- Shared settings-UI widget library for Retzer addons.
-- Usage: local RUI = LibStub("RetzerUI-1.0")

local LIB_NAME, LIB_VERSION = "RetzerUI-1.0", 1
local RUI, oldVersion = LibStub:NewLibrary(LIB_NAME, LIB_VERSION)
if not RUI then return end

----------------------------------------------------------------
-- Layout constants (public)
----------------------------------------------------------------

RUI.WIDGET_H    = 28
RUI.WIDGET_GAP  = 4
RUI.HEADER_GAP  = 12
RUI.CONTENT_PAD = 12

local WIDGET_H    = RUI.WIDGET_H
local WIDGET_GAP  = RUI.WIDGET_GAP
local HEADER_GAP  = RUI.HEADER_GAP
local CONTENT_PAD = RUI.CONTENT_PAD

local SLIDER_W    = 180
local LABEL_W     = 180
local SWATCH_SIZE = 20
local TAB_W       = 140

local BACKDROP_SOLID = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

----------------------------------------------------------------
-- Public: ClearScrollChild
----------------------------------------------------------------

function RUI.ClearScrollChild(sc)
    for _, child in pairs({ sc:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
    for _, region in pairs({ sc:GetRegions() }) do
        region:Hide()
        region:SetParent(nil)
    end
end

----------------------------------------------------------------
-- Public: Header
----------------------------------------------------------------

function RUI.Header(parent, label, yOffset)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    text:SetTextColor(0.8, 0.8, 0.8)
    text:SetText(label)
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    return WIDGET_H
end

----------------------------------------------------------------
-- Public: Button
----------------------------------------------------------------

function RUI.Button(parent, label, width, onClick)
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

----------------------------------------------------------------
-- Public: EditBox
----------------------------------------------------------------

function RUI.EditBox(parent, width)
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

----------------------------------------------------------------
-- Public: Dropdown
-- Returns container with .Refresh(newChoices, newCurrent) and .GetValue()
----------------------------------------------------------------

function RUI.Dropdown(parent, width, choices, current, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 24)

    local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
    btn:SetSize(width, 24)
    btn:SetPoint("TOPLEFT")
    btn:SetBackdrop(BACKDROP_SOLID)
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local btnText = btn:CreateFontString(nil, "OVERLAY")
    btnText:SetFont(STANDARD_TEXT_FONT, 12, "")
    btnText:SetTextColor(1, 1, 1)
    btnText:SetText(current or "")
    btnText:SetPoint("LEFT", 8, 0)
    btnText:SetPoint("RIGHT", -20, 0)
    btnText:SetJustifyH("LEFT")

    local arrow = btn:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(STANDARD_TEXT_FONT, 10, "")
    arrow:SetTextColor(0.6, 0.6, 0.6)
    arrow:SetText("v")
    arrow:SetPoint("RIGHT", -6, 0)

    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetBackdrop(BACKDROP_SOLID)
    menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
    menu:SetFrameStrata("TOOLTIP")
    menu:Hide()

    local function Refresh(newChoices, newCurrent)
        choices = newChoices or choices
        current = newCurrent or current
        btnText:SetText(current or "")

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
                btnText:SetText(choice)
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
-- Private: schema-driven widget creators
----------------------------------------------------------------

local function MakeCheckbox(parent, sectionKey, key, def, yOffset, db, onChanged)
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

    btn:SetChecked(db[sectionKey][key])

    local labelFs = parent:CreateFontString(nil, "OVERLAY")
    labelFs:SetFont(STANDARD_TEXT_FONT, 12, "")
    labelFs:SetTextColor(1, 1, 1)
    labelFs:SetText(def.label)
    labelFs:SetPoint("LEFT", btn, "RIGHT", 6, 0)

    if def.reload then
        local note = parent:CreateFontString(nil, "OVERLAY")
        note:SetFont(STANDARD_TEXT_FONT, 10, "")
        note:SetTextColor(0.6, 0.6, 0.6)
        note:SetText("(requires /reload)")
        note:SetPoint("LEFT", labelFs, "RIGHT", 6, 0)
    end

    btn:SetScript("OnClick", function(self)
        db[sectionKey][key] = self:GetChecked()
        if onChanged then onChanged() end
    end)

    return WIDGET_H
end

local function MakeSlider(parent, sectionKey, key, def, yOffset, db, onChanged)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(LABEL_W + SLIDER_W + 60, WIDGET_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local labelFs = row:CreateFontString(nil, "OVERLAY")
    labelFs:SetFont(STANDARD_TEXT_FONT, 12, "")
    labelFs:SetTextColor(1, 1, 1)
    labelFs:SetText(def.label)
    labelFs:SetPoint("LEFT", row, "LEFT", 0, 0)
    labelFs:SetWidth(LABEL_W)
    labelFs:SetJustifyH("LEFT")

    local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
    slider:SetSize(SLIDER_W, 16)
    slider:SetPoint("LEFT", row, "LEFT", LABEL_W, 0)
    slider:SetBackdrop(BACKDROP_SOLID)
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

    local valueFs = row:CreateFontString(nil, "OVERLAY")
    valueFs:SetFont(STANDARD_TEXT_FONT, 12, "")
    valueFs:SetTextColor(0.9, 0.9, 0.9)
    valueFs:SetPoint("LEFT", slider, "RIGHT", 8, 0)

    local function FormatValue(v)
        if def.step < 1 then return string.format("%.2f", v) end
        return tostring(math.floor(v + 0.5))
    end

    local cur = db[sectionKey][key]
    slider:SetValue(cur)
    valueFs:SetText(FormatValue(cur))

    slider:SetScript("OnValueChanged", function(self, v)
        if def.step >= 1 then v = math.floor(v + 0.5) end
        db[sectionKey][key] = v
        valueFs:SetText(FormatValue(v))
        if onChanged then onChanged() end
    end)

    slider:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetValue() + delta * def.step
        v = math.max(def.min, math.min(def.max, v))
        self:SetValue(v)
    end)

    return WIDGET_H
end

local function MakeColorPicker(parent, sectionKey, key, def, yOffset, db, onChanged)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(LABEL_W + SWATCH_SIZE + 10, WIDGET_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local labelFs = row:CreateFontString(nil, "OVERLAY")
    labelFs:SetFont(STANDARD_TEXT_FONT, 12, "")
    labelFs:SetTextColor(1, 1, 1)
    labelFs:SetText(def.label)
    labelFs:SetPoint("LEFT", row, "LEFT", 0, 0)
    labelFs:SetWidth(LABEL_W)
    labelFs:SetJustifyH("LEFT")

    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
    swatch:SetPoint("LEFT", row, "LEFT", LABEL_W, 0)
    swatch:SetBackdrop(BACKDROP_SOLID)
    swatch:SetBackdropBorderColor(0, 0, 0, 1)

    local c = db[sectionKey][key]
    local hasAlpha = def.default.a ~= nil
    swatch:SetBackdropColor(c.r, c.g, c.b, 1)

    swatch:SetScript("OnClick", function()
        local col = db[sectionKey][key]
        local prev = { r = col.r, g = col.g, b = col.b, a = col.a }

        local info = {
            r          = col.r,
            g          = col.g,
            b          = col.b,
            hasOpacity = hasAlpha,
            opacity    = hasAlpha and (1 - (col.a or 1)) or nil,
        }

        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            col.r, col.g, col.b = r, g, b
            swatch:SetBackdropColor(r, g, b, 1)
            if onChanged then onChanged() end
        end

        if hasAlpha then
            info.opacityFunc = function()
                col.a = 1 - ColorPickerFrame:GetColorAlpha()
                if onChanged then onChanged() end
            end
        end

        info.cancelFunc = function()
            col.r, col.g, col.b, col.a = prev.r, prev.g, prev.b, prev.a
            swatch:SetBackdropColor(prev.r, prev.g, prev.b, 1)
            if onChanged then onChanged() end
        end

        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    return WIDGET_H
end

-- Schema entry with choices = {"a","b",...} renders as a labeled dropdown row.
local function MakeDropdownWidget(parent, sectionKey, key, def, yOffset, db, onChanged)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(LABEL_W + 160, WIDGET_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local labelFs = row:CreateFontString(nil, "OVERLAY")
    labelFs:SetFont(STANDARD_TEXT_FONT, 12, "")
    labelFs:SetTextColor(1, 1, 1)
    labelFs:SetText(def.label)
    labelFs:SetPoint("LEFT", row, "LEFT", 0, 0)
    labelFs:SetWidth(LABEL_W)
    labelFs:SetJustifyH("LEFT")

    local dd = RUI.Dropdown(row, 150, def.choices, db[sectionKey][key], function(choice)
        db[sectionKey][key] = choice
        if onChanged then onChanged() end
    end)
    dd:SetPoint("LEFT", row, "LEFT", LABEL_W, 0)

    return WIDGET_H
end

local function MakeWidget(parent, sectionKey, key, def, yOffset, db, onChanged)
    local d = def.default
    if type(d) == "boolean" then
        return MakeCheckbox(parent, sectionKey, key, def, yOffset, db, onChanged)
    elseif type(d) == "number" and def.min then
        return MakeSlider(parent, sectionKey, key, def, yOffset, db, onChanged)
    elseif type(d) == "table" and d.r ~= nil then
        return MakeColorPicker(parent, sectionKey, key, def, yOffset, db, onChanged)
    elseif type(d) == "string" and def.choices then
        return MakeDropdownWidget(parent, sectionKey, key, def, yOffset, db, onChanged)
    end
    return 0
end

----------------------------------------------------------------
-- Private: section population
----------------------------------------------------------------

local function ExtractDefaults(schema)
    local out = {}
    for section, entries in pairs(schema) do
        out[section] = {}
        for _, entry in ipairs(entries) do
            if entry.key then
                local d = entry.default
                if type(d) == "table" then
                    out[section][entry.key] = { r = d.r, g = d.g, b = d.b, a = d.a }
                else
                    out[section][entry.key] = d
                end
            end
        end
    end
    return out
end

local function ResetSection(sectionKey, db, defaults, onChanged)
    local sectionDefaults = defaults[sectionKey]
    if not sectionDefaults or not db[sectionKey] then return end
    for k, v in pairs(sectionDefaults) do
        if type(v) == "table" then
            local cur = db[sectionKey][k]
            if cur then
                for tk, tv in pairs(v) do cur[tk] = tv end
            end
        else
            db[sectionKey][k] = v
        end
    end
    if onChanged then onChanged() end
end

local function PopulateSection(scrollChild, sectionKey, schema, db, onChanged, defaults)
    RUI.ClearScrollChild(scrollChild)

    local section = schema[sectionKey]
    if not section then return end

    local y = -CONTENT_PAD

    for _, entry in ipairs(section) do
        if entry.header then
            y = y - HEADER_GAP
            local h = RUI.Header(scrollChild, entry.header, y)
            y = y - h - WIDGET_GAP
        elseif entry.key and not entry.hidden then
            local h = MakeWidget(scrollChild, sectionKey, entry.key, entry, y, db, onChanged)
            y = y - h - WIDGET_GAP
        end
    end

    y = y - HEADER_GAP
    local resetBtn = RUI.Button(scrollChild, "Reset Section", 100, function()
        ResetSection(sectionKey, db, defaults, onChanged)
        PopulateSection(scrollChild, sectionKey, schema, db, onChanged, defaults)
    end)
    resetBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    y = y - 30

    scrollChild:SetHeight(math.abs(y) + CONTENT_PAD)
end

----------------------------------------------------------------
-- Public: BuildOptionsFrame
--
-- opts = {
--   title      string           window title
--   name       string|nil       global frame name (for UISpecialFrames / Escape key)
--   schema     table            addon schema (same shape as RP.schema)
--   db         table            live db table (nested: db[sectionKey][key])
--   onChanged  function|nil     called after any widget change
--   frameW     number|nil       default 600
--   frameH     number|nil       default 480
--   extraTabs  table|nil        array of { label, order, populate(scrollChild, repopulate) }
-- }
-- Returns the options frame (hidden by default).
----------------------------------------------------------------

function RUI:BuildOptionsFrame(opts)
    local schema    = opts.schema
    local db        = opts.db
    local onChanged = opts.onChanged
    local frameW    = opts.frameW or 600
    local frameH    = opts.frameH or 480
    local defaults  = ExtractDefaults(schema)

    local frame = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    frame:SetSize(frameW, frameH)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
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
    if opts.name then
        tinsert(UISpecialFrames, opts.name)
    end

    local titleFs = frame:CreateFontString(nil, "OVERLAY")
    titleFs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    titleFs:SetText(opts.title or "")
    titleFs:SetPoint("TOP", 0, -10)

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

    local tabPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    tabPanel:SetPoint("TOPLEFT", 8, -32)
    tabPanel:SetPoint("BOTTOMLEFT", 8, 8)
    tabPanel:SetWidth(TAB_W)
    tabPanel:SetBackdrop(BACKDROP_SOLID)
    tabPanel:SetBackdropColor(0.12, 0.12, 0.12, 1)
    tabPanel:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tabPanel, "TOPRIGHT", 8, -CONTENT_PAD)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8 + CONTENT_PAD)

    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(frameW - TAB_W - 56)

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

    -- Merge extraTabs + schema sections, sort by order
    local sections = {}
    if opts.extraTabs then
        for _, t in ipairs(opts.extraTabs) do
            sections[#sections + 1] = {
                key      = "_extra_" .. t.label,
                label    = t.label,
                order    = t.order,
                populate = t.populate,
            }
        end
    end
    for sectionKey, fields in pairs(schema) do
        if fields._meta then
            sections[#sections + 1] = {
                key   = sectionKey,
                label = fields._meta.label,
                order = fields._meta.order or 99,
            }
        end
    end
    table.sort(sections, function(a, b) return a.order < b.order end)

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

        local sec = sections[index]
        if sec.populate then
            local repopulate
            repopulate = function()
                sec.populate(scrollChild, repopulate)
            end
            repopulate()
        else
            PopulateSection(scrollChild, sec.key, schema, db, onChanged, defaults)
        end
    end

    for i, sec in ipairs(sections) do
        local tab = CreateFrame("Button", nil, tabChild)
        tab:SetSize(TAB_W - 4, 24)
        tab:SetPoint("TOPLEFT", tabChild, "TOPLEFT", 2, -2 - (i - 1) * 26)

        local highlight = tab:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0, 0, 0, 0)
        tab.highlight = highlight

        local tabText = tab:CreateFontString(nil, "OVERLAY")
        tabText:SetFont(STANDARD_TEXT_FONT, 12, "")
        tabText:SetTextColor(0.7, 0.7, 0.7)
        tabText:SetText(sec.label)
        tabText:SetPoint("LEFT", 8, 0)
        tab.text = tabText

        tab:SetScript("OnClick", function() SelectTab(i) end)
        tab:SetScript("OnEnter", function()
            if selectedTab ~= i then highlight:SetColorTexture(1, 1, 1, 0.05) end
        end)
        tab:SetScript("OnLeave", function()
            if selectedTab ~= i then highlight:SetColorTexture(0, 0, 0, 0) end
        end)

        tabButtons[i] = tab
    end

    tabChild:SetHeight(2 + #sections * 26)
    SelectTab(1)

    return frame
end
