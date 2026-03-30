local _, ns = ...
local RP = ns.RP ---@type RP

local RUI = LibStub("RetzerUI-1.0")

local CONTENT_PAD = RUI.CONTENT_PAD
local WIDGET_GAP  = RUI.WIDGET_GAP
local HEADER_GAP  = RUI.HEADER_GAP

----------------------------------------------------------------
-- Refresh throttle
----------------------------------------------------------------

local refreshTimer

local function RefreshAllPlates()
    local NP = RP:GetModule("Nameplates")
    if not NP then return end

    for _, plate in pairs(NP.plates) do
        plate:Hide()
    end
    wipe(NP.plates)

    RP:Call("SetCVars")
    RP:Call("SetClickSpace")

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
-- Profile management tab
----------------------------------------------------------------

local function PopulateProfileSection(scrollChild, repopulate)
    RUI.ClearScrollChild(scrollChild)

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
    local h = RUI.Header(scrollChild, "Active Profile", y)
    y = y - h - WIDGET_GAP

    local profileDropdown = RUI.Dropdown(scrollChild, 200, profiles, currentProfile, function(choice)
        if choice ~= aceDB:GetCurrentProfile() then
            aceDB:SetProfile(choice)
            repopulate()
        end
    end)
    profileDropdown:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    y = y - 28 - WIDGET_GAP

    -- New Profile
    y = y - HEADER_GAP
    h = RUI.Header(scrollChild, "New Profile", y)
    y = y - h - WIDGET_GAP

    local nameBox = RUI.EditBox(scrollChild, 200)
    nameBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)

    local createBtn = RUI.Button(scrollChild, "Create", 70, function()
        local name = strtrim(nameBox:GetText())
        if name == "" then return end
        aceDB:SetProfile(name)
        repopulate()
    end)
    createBtn:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
    nameBox:SetScript("OnEnterPressed", function(_) createBtn:GetScript("OnClick")(createBtn) end)
    y = y - 28 - WIDGET_GAP

    -- Copy From
    y = y - HEADER_GAP
    h = RUI.Header(scrollChild, "Copy Settings From", y)
    y = y - h - WIDGET_GAP

    local otherProfiles = {}
    for _, p in ipairs(profiles) do
        if p ~= currentProfile then
            otherProfiles[#otherProfiles + 1] = p
        end
    end

    if #otherProfiles > 0 then
        local copyDropdown = RUI.Dropdown(scrollChild, 200, otherProfiles, otherProfiles[1])
        copyDropdown:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)

        local copyBtn = RUI.Button(scrollChild, "Copy", 70, function()
            local source = copyDropdown.GetValue()
            if source then
                aceDB:CopyProfile(source)
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
    h = RUI.Header(scrollChild, "Actions", y)
    y = y - h - WIDGET_GAP

    local resetBtn = RUI.Button(scrollChild, "Reset Profile", 110, function()
        aceDB:ResetProfile()
        repopulate()
    end)
    resetBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)

    if currentProfile ~= "Default" then
        local profileToDelete = currentProfile
        local deleteBtn = RUI.Button(scrollChild, "Delete Profile", 110, function()
            aceDB:SetProfile("Default")
            aceDB:DeleteProfile(profileToDelete)
            repopulate()
        end)
        deleteBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    end
    y = y - 28 - WIDGET_GAP

    -- Display scaling
    y = y - HEADER_GAP
    h = RUI.Header(scrollChild, "Display Scaling", y)
    y = y - h - WIDGET_GAP

    local scaleInfo = scrollChild:CreateFontString(nil, "OVERLAY")
    scaleInfo:SetFont(STANDARD_TEXT_FONT, 11, "")
    scaleInfo:SetTextColor(0.5, 0.5, 0.5)
    scaleInfo:SetText(string.format("Scale factor: %.2f (baseline: 1440p @ 0.53)", RP.GetScaleFactor()))
    scaleInfo:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    y = y - 16 - WIDGET_GAP

    local rescaleBtn = RUI.Button(scrollChild, "Recalculate Sizes", 150, function()
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
    h = RUI.Header(scrollChild, "Current Character", y)
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
-- Toggle
----------------------------------------------------------------

local optionsFrame

local function ToggleOptions()
    if InCombatLockdown() then
        print("|cffff6600RetzerPlates:|r Cannot open settings in combat")
        return
    end
    if not optionsFrame then
        optionsFrame = RUI:BuildOptionsFrame({
            title     = "RetzerPlates",
            name      = "RetzerPlatesOptionsFrame",
            schema    = RP.schema,
            db        = RP.db,
            onChanged = ScheduleRefresh,
            frameW    = 600,
            frameH    = 580,
            extraTabs = {
                { label = "Profiles", order = 0, populate = PopulateProfileSection },
            },
        })
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
