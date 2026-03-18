local _, ns = ...
local RP = ns.RP ---@type RP

----------------------------------------------------------------
-- Declarative schema: single source of truth for defaults + UI
-- Array part = ordered entries for UI. _meta = section metadata.
-- Plugins register their own sections via RP:RegisterSchema().
----------------------------------------------------------------

---@class RPGeneralConfig
---@field enabled boolean
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
---@field hideFriendlyInDungeon boolean
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

---@class RPDistancesConfig
---@field maxDistance number
---@field playerMaxDistance number

RP.schema = {
    general = {
        _meta = { label = "General", order = 1 },
        { key = "enabled",              default = true,  label = "Enable RetzerPlates",  reload = true },
        { key = "yOffset",              default = 8,     label = "Y Offset",             min = -50, max = 50,  step = 1 },
        { header = "Hitbox" },
        { key = "hitboxWidth",  default = 280,   label = "Width",  min = 100, max = 400, step = 10 },
        { key = "hitboxHeight", default = 90,    label = "Height", min = 30,  max = 200, step = 5 },
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
    },
    visibility = {
        _meta = { label = "Visibility", order = 2 },
        { key = "hideFriendlyInDungeon",       default = true,  label = "Hide Friendly in Dungeon" },
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
    distances = {
        _meta = { label = "Distances", order = 3 },
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
-- Extract flat defaults from schema
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

----------------------------------------------------------------
-- Merge defaults into saved variables
----------------------------------------------------------------

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

RP:RegisterHook("ApplyDefaults", function()
    RP.defaults = ExtractDefaults(RP.schema)
    CopyDefaults(RP.defaults, RP.db)
end)
