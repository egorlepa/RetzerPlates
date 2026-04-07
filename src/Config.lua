local _, ns = ...
local RP = ns.RP ---@type RP

----------------------------------------------------------------
-- Declarative schema: single source of truth for defaults + UI
-- Array part = ordered entries for UI. _meta = section metadata.
-- Plugins register their own sections via RP:RegisterSchema().
----------------------------------------------------------------

---@class RPGeneralConfig
---@field enabled boolean
---@field font string
---@field numberFont string
---@field hitboxWidth number
---@field hitboxHeight number
---@field yOffset number
---@field debug boolean
---@field alpha number
---@field selectedAlpha number
---@field occludedAlphaMult number
---@field overlapH number
---@field overlapV number
---@field stackEnemies boolean
---@field stackFriendlies boolean

---@class RPVisibilityConfig
---@field hideFriendlyInInstance boolean
---@field showEnemies boolean
---@field showEnemyMinions boolean
---@field showEnemyGuardians boolean
---@field showEnemyMinus boolean
---@field showEnemyPets boolean
---@field showEnemyTotems boolean
---@field showFriendlyNPCs boolean
---@field showFriendlyPlayers boolean
---@field showFriendlyPlayerPets boolean
---@field showFriendlyPlayerGuardians boolean
---@field showFriendlyPlayerTotems boolean
---@field showFriendlyPlayerMinions boolean

---@class RPSimplifiedConfig
---@field enabled boolean
---@field debug boolean
---@field passiveFontSize number
---@field passiveTitleFontSize number
---@field enemyWidth number
---@field enemyHeight number
---@field enemyCastBarHeight number
---@field enemyCastBarFontSize number
---@field enemyFontSize number

---@class RPDistancesConfig
---@field maxDistance number
---@field playerMaxDistance number

RP.schema = {
    general = {
        _meta = { label = "General", order = 1 },
        { key = "enabled",              default = true,  label = "Enable RetzerPlates",  reload = true },
        { key = "yOffset",              default = 7,     label = "Y Offset",             min = -50, max = 50,  step = 1, scalable = true },
        { header = "Hitbox" },
        { key = "hitboxWidth",  default = 250,   label = "Width",  min = 100, max = 400, step = 10, scalable = true },
        { key = "hitboxHeight", default = 75,    label = "Height", min = 30,  max = 200, step = 5, scalable = true },
        { key = "debug",        default = false, label = "Debug Hitboxes" },
        { header = "Alpha" },
        { key = "alpha",             default = 0.75,  label = "Normal Alpha",        min = 0.1,    max = 1.0, step = 0.05 },
        { key = "selectedAlpha",     default = 1.0,   label = "Selected Alpha",      min = 0.1,    max = 1.0, step = 0.05 },
        { key = "occludedAlphaMult", default = 0.5,   label = "Occluded Alpha",      min = 0.0,    max = 1.0, step = 0.05 },
        { header = "Stacking" },
        { key = "overlapH",          default = 0.8,   label = "Horizontal Overlap",  min = 0.2,    max = 3.0, step = 0.1 },
        { key = "overlapV",          default = 1.4,   label = "Vertical Overlap",    min = 0.2,    max = 3.0, step = 0.1 },
        { key = "stackEnemies",      default = true,  label = "Stack Enemies" },
        { key = "stackFriendlies",   default = false, label = "Stack Friendlies" },
        { header = "Fonts" },
        { key = "font",       default = "PT Sans Narrow", label = "Text Font",   lsm = "font" },
        { key = "numberFont", default = "PT Sans Narrow", label = "Number Font", lsm = "font" },
    },
    visibility = {
        _meta = { label = "Visibility", order = 2 },
        { key = "hideFriendlyInInstance",      default = true,  label = "Hide Friendly in Dungeons/Raids" },
        { header = "Enemies" },
        { key = "showEnemies",                 default = true,  label = "Show Enemies" },
        { key = "showEnemyMinions",            default = true,  label = "Enemy Minions" },
        { key = "showEnemyGuardians",          default = true,  label = "Enemy Guardians" },
        { key = "showEnemyMinus",              default = true,  label = "Enemy Minor" },
        { key = "showEnemyPets",               default = true,  label = "Enemy Pets" },
        { key = "showEnemyTotems",             default = true,  label = "Enemy Totems" },
        { header = "Friendlies" },
        { key = "showFriendlyNPCs",            default = true,  label = "Friendly NPCs" },
        { key = "showFriendlyPlayers",         default = true,  label = "Friendly Players" },
        { key = "showFriendlyPlayerPets",      default = false, label = "Friendly Player Pets" },
        { key = "showFriendlyPlayerGuardians", default = false, label = "Friendly Player Guardians" },
        { key = "showFriendlyPlayerTotems",    default = false, label = "Friendly Player Totems" },
        { key = "showFriendlyPlayerMinions",   default = false, label = "Friendly Player Minions" },
    },
    simplified = {
        _meta = { label = "Simplified Plates", order = 3 },
        { key = "enabled",            default = true, label = "Enable Simplified Plates" },
        { key = "debug",              default = false, label = "Debug (Force All Minor)" },
        { header = "Passive Minor Units" },
        { key = "passiveFontSize",      default = 16,  label = "Name Font Size",       min = 8, max = 30, step = 1, scalable = true },
        { key = "passiveTitleFontSize", default = 12,  label = "Title Font Size",      min = 8, max = 20, step = 1, scalable = true },
        { header = "Enemy Minor Units" },
        { key = "enemyWidth",           default = 100, label = "Health Bar Width",     min = 40, max = 300, step = 5, scalable = true },
        { key = "enemyHeight",          default = 14,  label = "Health Bar Height",    min = 4,  max = 40,  step = 1, scalable = true },
        { key = "enemyCastBarHeight",   default = 14,  label = "Cast Bar Height",      min = 4,  max = 40,  step = 1, scalable = true },
        { key = "enemyCastBarFontSize", default = 14,  label = "Cast Bar Font Size",   min = 8, max = 24, step = 1, scalable = true },
        { key = "enemyFontSize",        default = 14,  label = "Name Font Size",       min = 8, max = 30, step = 1, scalable = true },
    },
    distances = {
        _meta = { label = "Distances", order = 4 },
        { key = "maxDistance",       default = 60, label = "Max Distance",        min = 20, max = 60, step = 5 },
        { key = "playerMaxDistance", default = 60, label = "Player Max Distance", min = 20, max = 60, step = 5 },
    },
}

----------------------------------------------------------------
-- Schema registration for plugins
----------------------------------------------------------------

local nextPluginOrder = 100

function RP:RegisterSchema(key, section)
    if not section._meta then section._meta = { label = key } end
    if not section._meta.order then
        section._meta.order = nextPluginOrder
        nextPluginOrder = nextPluginOrder + 1
    end
    RP.schema[key] = section
end

----------------------------------------------------------------
-- Display scaling
----------------------------------------------------------------

local BASELINE_SCALE = 768 / 1440 -- pixel-perfect UI scale for 1440p

function RP.GetScaleFactor()
    return BASELINE_SCALE / UIParent:GetEffectiveScale()
end

function RP.RescaleProfile()
    local factor = RP.GetScaleFactor()
    for sectionKey, entries in pairs(RP.schema) do
        for _, entry in ipairs(entries) do
            if entry.scalable and entry.key and type(entry.default) == "number" then
                local scaled = entry.default * factor
                if entry.step and entry.step >= 1 then
                    scaled = math.floor(scaled + 0.5)
                end
                if entry.min then scaled = math.max(entry.min, scaled) end
                if entry.max then scaled = math.min(entry.max, scaled) end
                if RP.db[sectionKey] then
                    RP.db[sectionKey][entry.key] = scaled
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Font accessors (via LibSharedMedia)
----------------------------------------------------------------

local LSM = LibStub("LibSharedMedia-3.0")

function RP.GetTextFont()
    return LSM:Fetch("font", RP.db.general.font) or STANDARD_TEXT_FONT
end

function RP.GetNumberFont()
    return LSM:Fetch("font", RP.db.general.numberFont) or STANDARD_TEXT_FONT
end

----------------------------------------------------------------
-- Extract flat defaults from schema
----------------------------------------------------------------

function RP.ExtractDefaults(schema)
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
