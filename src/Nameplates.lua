local _, ns = ...
local RP = ns.RP ---@type RP
---@class RPNameplatesModule : RPModule
---@field plates table<Frame, RPPlate>
local NP = RP:NewModule("Nameplates") --[[@as RPNameplatesModule]]

NP.plates = {}

local function EnsurePlate(frame)
    if NP.plates[frame] then return NP.plates[frame] end
    local plate = RP:Call("ConstructPlate", frame)
    NP.plates[frame] = plate
    RP:Call("OnPlateCreated", plate)
    return plate
end

local function InitPlate(frame, unitToken)
    if UnitNameplateShowsWidgetsOnly(unitToken) then
        -- Restore Blizzard UnitFrame if this frame was previously suppressed
        if frame._rpSuppressed then
            frame._rpSuppressed = false
            if frame.UnitFrame and not frame.UnitFrame:IsForbidden() then
                frame.UnitFrame:SetAlpha(1)
            end
        end
        return
    end
    RP:Call("SuppressBlizzardPlate", frame)
    local plate = NP.plates[frame]
    if not plate then return end

    plate.unit = unitToken
    plate.unitGUID = UnitGUID(unitToken)
    plate.frameType = RP:Call("GetFrameType", unitToken)
    plate.isMinor = RP.IsMinor(unitToken) or RP.db.simplified.debug

    RP:Call("UpdatePlate", plate)
    RP:Call("StartCastBarTicker", plate)
    RP:Call("UpdateCastBar", plate)
    plate:Show()
    RP:Call("OnPlateAdded", plate)

    -- If the name is unknown at this point (unit summoned mid-combat and server
    -- hasn't sent the name yet), schedule a retry.  UNIT_NAME_UPDATE will also
    -- fire when the name resolves, but can arrive before the plate is ready.
    local name = UnitName(unitToken)
    if not name or (issecretvalue and issecretvalue(name)) then
        C_Timer.After(0.5, function()
            if plate.unit == unitToken then
                RP:Call("UpdateName", plate)
            end
        end)
    end
end

function NP:Initialize()
    if not RP.db.general.enabled then return end

    RP:Call("SetCVars")
    RP:Call("SetClickSpace")

    -- Re-apply after all addons have initialized, in case another addon overwrites them
    RP:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        RP:Call("SetCVars")
        RP:Call("SetClickSpace")
    end)

    RP:RegisterEvent("NAME_PLATE_CREATED", function(_, frame)
        EnsurePlate(frame)
    end)

    RP:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unitToken)
        local frame = C_NamePlate.GetNamePlateForUnit(unitToken)
        if not frame then return end
        EnsurePlate(frame)
        InitPlate(frame, unitToken)
    end)

    RP:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, unitToken)
        local frame = C_NamePlate.GetNamePlateForUnit(unitToken)
        if not frame then return end
        local plate = NP.plates[frame]
        if not plate then return end

        RP:Call("StopCastBar", plate)
        RP:Call("OnPlateRemoved", plate)
        plate.unit = nil
        plate.unitGUID = nil
        plate.frameType = nil
        plate.isMinor = nil
        plate:Hide()
    end)

    local function GetPlateByUnit(unitToken)
        if not strmatch(unitToken, "^nameplate") then return end
        local frame = C_NamePlate.GetNamePlateForUnit(unitToken)
        return frame and NP.plates[frame]
    end

    -- Health updates
    RP:RegisterEvent("UNIT_HEALTH", function(_, unitToken)
        local plate = GetPlateByUnit(unitToken)
        if not plate then return end
        RP:Call("UpdateHealth", plate)
        RP:Call("UpdateHealthColor", plate)
    end)

    -- Name updates (UnitName returns "Unknown" until server sends the name)
    RP:RegisterEvent("UNIT_NAME_UPDATE", function(_, unitToken)
        local plate = GetPlateByUnit(unitToken)
        if not plate then return end
        RP:Call("UpdateName", plate)
    end)

    -- Faction/reaction changes (e.g. neutral NPC becomes friendly or passive becomes hostile)
    local function OnFactionChanged(_, unitToken)
        local plate = GetPlateByUnit(unitToken)
        if not plate then return end
        -- Defer by one frame — UnitCanAttack may not reflect the new state yet
        C_Timer.After(0, function()
            if not plate.unit then return end
            plate.frameType = RP:Call("GetFrameType", plate.unit)
            RP:Call("UpdatePlate", plate)
        end)
    end
    RP:RegisterEvent("UNIT_FACTION", OnFactionChanged)
    RP:RegisterEvent("UNIT_FLAGS", OnFactionChanged)

    -- Threat updates
    RP:RegisterEvent("UNIT_THREAT_LIST_UPDATE", function(_, unitToken)
        local plate = GetPlateByUnit(unitToken)
        if not plate then return end
        RP:Call("UpdateHealthColor", plate)
    end)

    -- Cast bar events

    local castEvents = {
        "UNIT_SPELLCAST_START",
        "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_INTERRUPTIBLE",
        "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    }
    for _, event in ipairs(castEvents) do
        RP:RegisterEvent(event, function(_, unitToken)
            local plate = GetPlateByUnit(unitToken)
            if not plate then return end
            RP:Call("StartCastBarTicker", plate)
            RP:Call("UpdateCastBar", plate)
        end)
    end

    -- INTERRUPTED — capture interruptedBy GUID for display
    RP:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", function(_, unitToken, _, _, interruptedBy)
        local plate = GetPlateByUnit(unitToken)
        if not plate or not plate.CastBar then return end
        RP:Call("StopCastBar", plate, "INTERRUPTED", interruptedBy)
    end)

    RP:RegisterEvent("UNIT_SPELLCAST_FAILED", function(_, unitToken)
        local plate = GetPlateByUnit(unitToken)
        if not plate or not plate.CastBar then return end
        RP:Call("StopCastBar", plate, "INTERRUPTED")
    end)

    -- STOP — if already fading (from INTERRUPTED), skip
    RP:RegisterEvent("UNIT_SPELLCAST_STOP", function(_, unitToken)
        local plate = GetPlateByUnit(unitToken)
        if not plate or not plate.CastBar then return end
        if plate.CastBar._fadeOut then return end
        RP:Call("StopCastBar", plate, "SUCCESS")
    end)

    -- CHANNEL_STOP — just hide, no color animation (same as Plater)
    RP:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unitToken)
        local plate = GetPlateByUnit(unitToken)
        if not plate or not plate.CastBar then return end
        if plate.CastBar._fadeOut then return end
        RP:Call("StopCastBar", plate)
    end)

    -- Handle existing nameplates on /reload
    for _, frame in pairs(C_NamePlate.GetNamePlates()) do
        EnsurePlate(frame)
        local unit = frame.namePlateUnitToken
        if unit then
            InitPlate(frame, unit)
        end
    end
end
