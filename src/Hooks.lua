local _, ns = ...
local RP = ns.RP ---@type RP

----------------------------------------------------------------
-- CVars
----------------------------------------------------------------

RP:RegisterHook("SetCVars", function()
    local inInstance, instanceType = IsInInstance()
    local inDungeon = inInstance and (instanceType == "party" or instanceType == "raid")
    local vis = RP.db.visibility
    local dist = RP.db.distances
    local gen = RP.db.general

    local function B(v) return v and 1 or 0 end

    -- Build stacking type: A=enemy, B=friendly, C=both
    local stackType
    if gen.stackEnemies and gen.stackFriendlies then
        stackType = "\2C"
    elseif gen.stackFriendlies then
        stackType = "\2B"
    else
        stackType = "\2A"
    end

    local cvars = {
        -- Visibility (from config)
        nameplateShowAll                      = 1,
        nameplateShowEnemies                  = B(vis.showEnemies),
        nameplateShowSelf                     = 0,
        nameplateShowFriendlyNPCs             = (inDungeon and vis.hideFriendlyInInstance) and 0 or B(vis.showFriendlyNPCs),
        nameplateShowFriendlyPlayers          = (inDungeon and vis.hideFriendlyInInstance) and 0 or B(vis.showFriendlyPlayers),
        nameplateShowCastBars                 = 0,     -- we render our own
        nameplateShowOffscreen                = 1,

        -- Enemy unit type visibility (from config)
        nameplateShowEnemyMinions             = B(vis.showEnemyMinions),
        nameplateShowEnemyGuardians           = B(vis.showEnemyGuardians),
        nameplateShowEnemyMinus               = B(vis.showEnemyMinus),
        nameplateShowEnemyPets                = B(vis.showEnemyPets),
        nameplateShowEnemyTotems              = B(vis.showEnemyTotems),

        -- Friendly player unit type visibility (from config)
        nameplateShowFriendlyPlayerPets       = B(vis.showFriendlyPlayerPets),
        nameplateShowFriendlyPlayerGuardians  = B(vis.showFriendlyPlayerGuardians),
        nameplateShowFriendlyPlayerTotems     = B(vis.showFriendlyPlayerTotems),
        nameplateShowFriendlyPlayerMinions    = B(vis.showFriendlyPlayerMinions),

        -- Scale (hardcoded)
        nameplateMinScale                     = 1,
        nameplateMaxScale                     = 1,
        nameplateSelectedScale                = 1,
        nameplateSimplifiedScale              = 1,
        nameplateMinScaleDistance             = 0,
        nameplateMaxScaleDistance             = 40,

        -- Alpha (from config)
        nameplateMinAlpha                     = gen.alpha,
        nameplateMaxAlpha                     = gen.alpha,
        nameplateSelectedAlpha                = gen.selectedAlpha,
        nameplateOccludedAlphaMult            = gen.occludedAlphaMult,

        -- Stacking / overlap (from config)
        nameplateOverlapH                     = gen.overlapH,
        nameplateOverlapV                     = gen.overlapV,
        nameplateStackingTypes                = stackType,

        -- Positioning (hardcoded)
        nameplateOtherAtBase                  = 0,

        -- Distance (from config)
        nameplateMaxDistance                  = dist.maxDistance,
        nameplateMaxAlphaDistance             = 40,
        nameplateMinAlphaDistance             = 0,
        nameplateTargetBehindMaxDistance      = 0,
        nameplatePlayerMaxDistance            = dist.playerMaxDistance,

        -- Class colors (hardcoded)
        nameplateShowClassColor               = 1,
        nameplateShowFriendlyClassColor       = 1,

        -- Disable Blizzard overlays (hardcoded)
        nameplateThreatDisplay                = 0,

        -- Aura display CVars must stay enabled so Blizzard's C engine
        -- populates AurasFrame — we read its filtered aura IDs.
        nameplateEnemyNpcAuraDisplay          = "1G",
        nameplateEnemyPlayerAuraDisplay       = "1G",
        nameplateFriendlyPlayerAuraDisplay    = "1G",
        nameplateShowDebuffsOnFriendly        = 1,
    }

    for name, value in pairs(cvars) do
        if GetCVar(name) ~= nil then
            SetCVar(name, value)
        else
            print("|cffff6600RetzerPlates:|r CVar not found: " .. name)
        end
    end
end)

----------------------------------------------------------------
-- Click Space
----------------------------------------------------------------

local clickSpaceHooked = false

RP:RegisterHook("SetClickSpace", function()
    local db = RP.db.general
    C_NamePlate.SetNamePlateSize(db.hitboxWidth, db.hitboxHeight)
    -- Negative insets expand the hit test area to fill the entire frame
    C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Enemy,    -10000, -10000, -10000, -10000)
    C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Friendly, -10000, -10000, -10000, -10000)

    -- Prevent other addons from overriding our plate size
    if not clickSpaceHooked then
        local locked = false
        hooksecurefunc(C_NamePlate, "SetNamePlateSize", function(w, h)
            if locked then return end
            local want_w, want_h = RP.db.general.hitboxWidth, RP.db.general.hitboxHeight
            if w ~= want_w or h ~= want_h then
                locked = true
                C_NamePlate.SetNamePlateSize(want_w, want_h)
                locked = false
            end
        end)
        clickSpaceHooked = true
    end
end)

----------------------------------------------------------------
-- Shared helpers
----------------------------------------------------------------

function RP.IsFriendly(frameType)
    return frameType == "FRIENDLY_NPC" or frameType == "FRIENDLY_PLAYER"
end

function RP.IsPassive(plate)
    return plate.unit ~= nil and not UnitCanAttack("player", plate.unit)
end

function RP.IsMinor(unit)
    if not unit then return false end

    -- "minus" classification (trivial mobs, some guardians)
    if UnitClassification(unit) == "minus" then return true end

    -- Pets, minions, guardians
    local isPet = UnitIsMinion(unit) or UnitIsOtherPlayersPet(unit) or UnitIsUnit("pet", unit)
    if issecretvalue and issecretvalue(isPet) then return false end
    if isPet then return true end

    -- Totems
    local ok, ctype = pcall(UnitCreatureType, unit)
    if ok and not (issecretvalue and issecretvalue(ctype)) and ctype == "Totem" then return true end

    return false
end

----------------------------------------------------------------
-- Classification
----------------------------------------------------------------

---@param unit string
RP:RegisterHook("GetFrameType", function(unit)
    if UnitIsUnit(unit, "player") then
        return "PLAYER"
    elseif UnitIsPlayer(unit) then
        if UnitIsFriend("player", unit) then
            return "FRIENDLY_PLAYER"
        else
            return "ENEMY_PLAYER"
        end
    else
        if UnitIsFriend("player", unit) then
            return "FRIENDLY_NPC"
        else
            return "ENEMY_NPC"
        end
    end
end)

----------------------------------------------------------------
-- Construction
----------------------------------------------------------------

---@class BlizzPlate : Frame
---@field UnitFrame Frame?
---@field _rpSuppressed boolean?

---@class RPHitboxDebug : Frame, BackdropTemplate

---@class RPPlate : Frame
---@field unit string?
---@field unitGUID string?
---@field frameType RPFrameType?
---@field isMinor boolean?
---@field _hitboxDebug RPHitboxDebug?

---@param parent BlizzPlate
RP:RegisterHook("ConstructPlate", function(parent)
    local plate = CreateFrame("Frame", nil, parent) --[[@as RPPlate]]
    plate:SetAllPoints(parent)
    plate:EnableMouse(false)
    plate:Hide()
    RP:Call("ConstructHealth", plate)
    RP:Call("ConstructName", plate)
    RP:Call("ConstructCastBar", plate)
    RP:Call("ConstructHighlight", plate)

    -- Hitbox debug overlay (always constructed, shown/sized in UpdateLayout)
    local dbg = CreateFrame("Frame", nil, plate, "BackdropTemplate") --[[@as RPHitboxDebug]]
    dbg:SetPoint("CENTER", parent, "CENTER", 0, 0)
    dbg:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    dbg:Hide()
    plate._hitboxDebug = dbg

    return plate
end)

-- Suppress default Blizzard nameplate. Called on NAME_PLATE_UNIT_ADDED
-- because the UnitFrame child doesn't exist yet at NAME_PLATE_CREATED time.
-- Can't Hide() UnitFrame — click hitbox is tied to it. Force alpha to 0 instead.
-- We do NOT UnregisterAllEvents — the Blizzard UnitFrame must keep processing
-- events so its AurasFrame stays populated. We read its filtered aura IDs.
local hookedPlates = {}
---@param parent BlizzPlate
RP:RegisterHook("SuppressBlizzardPlate", function(parent)
    parent._rpSuppressed = true

    if not parent.UnitFrame then return end
    if parent.UnitFrame:IsForbidden() then return end

    parent.UnitFrame:SetAlpha(0)

    if not hookedPlates[parent] then
        local locked = false
        hooksecurefunc(parent.UnitFrame, "SetAlpha", function(self)
            if locked or self:IsForbidden() then return end
            if not parent._rpSuppressed then return end
            locked = true
            self:SetAlpha(0)
            locked = false
        end)
        hookedPlates[parent] = true
    end
end)

----------------------------------------------------------------
-- Updates
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("UpdatePlate", function(plate)
    RP:Call("UpdateHealth", plate)
    RP:Call("UpdateName", plate)
    RP:Call("UpdateHealthColor", plate)
    RP:Call("UpdateLayout", plate)
end)

---@param plate RPPlate
RP:RegisterHook("UpdateLayout", function(plate)
    local isMinorEnemy = plate.isMinor and not RP.IsPassive(plate) and RP.db.simplified.enabled

    if RP.IsPassive(plate) then
        plate.Health:SetStatusBarColor(0, 0, 0, 0)
        plate.Health.bg:Hide()
        plate.Health.border:Hide()
    elseif isMinorEnemy then
        local sdb = RP.db.simplified
        plate.Health:SetSize(sdb.enemyWidth, sdb.enemyHeight)
        plate.Health.bg:Show()
        plate.Health.border:Show()
        if plate.CastBar then
            plate.CastBar:SetSize(sdb.enemyWidth, sdb.enemyCastBarHeight)
            plate.CastBar.Text:SetFont(STANDARD_TEXT_FONT, sdb.enemyCastBarFontSize, "OUTLINE")
            plate.CastBar._iconFrame:Hide()
        end
    else
        plate.Health:SetSize(RP.db.healthbar.width, RP.db.healthbar.height)
        plate.Health.bg:Show()
        plate.Health.border:Show()
        if plate.CastBar then
            plate.CastBar:SetSize(RP.db.healthbar.width, RP.db.castbar.height)
            plate.CastBar.Text:SetFont(STANDARD_TEXT_FONT, RP.db.castbar.fontSize, "OUTLINE")
            plate.CastBar._iconFrame:Show()
        end
    end

    local dbg = plate._hitboxDebug
    if not dbg then return end
    local db = RP.db.general
    if db.debug then
        dbg:SetSize(db.hitboxWidth, db.hitboxHeight)
        dbg:SetBackdropColor(1, 0.85, 0.2, 0.15)
        dbg:SetBackdropBorderColor(1, 0.85, 0.2, 0.8)
        dbg:Show()
    else
        dbg:Hide()
    end
end)

----------------------------------------------------------------
-- Plate scaling (e.g. target emphasis)
-- Plugins wrap this to scale their own frames/fonts.
-- Called by whoever sets plate._targetScale (e.g. TargetIndicator).
----------------------------------------------------------------

RP:RegisterHook("ScalePlate", function(plate, factor)
    local isMinorEnemy = plate.isMinor and not RP.IsPassive(plate) and RP.db.simplified.enabled
    local w = isMinorEnemy and RP.db.simplified.enemyWidth  or RP.db.healthbar.width
    local h = isMinorEnemy and RP.db.simplified.enemyHeight or RP.db.healthbar.height
    plate.Health:SetSize(math.floor(w * factor + 0.5), math.floor(h * factor + 0.5))
end)

----------------------------------------------------------------
-- Lifecycle notifications (default no-ops)
----------------------------------------------------------------

RP:RegisterHook("OnPlateCreated", function() end)
RP:RegisterHook("OnPlateAdded", function() end)
RP:RegisterHook("OnPlateRemoved", function() end)
