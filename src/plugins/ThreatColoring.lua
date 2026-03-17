local _, ns = ...
local RP = ns.RP ---@type RP

---@class RPThreatConfig
---@field enabled boolean
---@field colorTankAggro RPColor
---@field colorTankLow RPColor
---@field colorTankNoAggro RPColor
---@field colorDpsAggro RPColor
---@field colorDpsHigh RPColor
---@field colorDpsNoAggro RPColor

RP:RegisterSchema("threat", {
    _meta = { label = "Threat" },
    { key = "enabled",          default = true,                             label = "Enable Threat Colors" },
    { header = "Tank" },
    { key = "colorTankAggro",   default = { r = 0.29, g = 0.69, b = 0.30 }, label = "Has Aggro" },
    { key = "colorTankLow",     default = { r = 1.0, g = 0.46, b = 0.10 },  label = "Losing Aggro" },
    { key = "colorTankNoAggro", default = { r = 0.78, g = 0.25, b = 0.25 }, label = "Lost Aggro" },
    { header = "DPS / Healer" },
    { key = "colorDpsAggro",    default = { r = 0.78, g = 0.25, b = 0.25 }, label = "Has Aggro" },
    { key = "colorDpsHigh",     default = { r = 1.0, g = 0.46, b = 0.10 },  label = "High Threat" },
    { key = "colorDpsNoAggro",  default = { r = 0.29, g = 0.69, b = 0.30 }, label = "Safe" },
})

---@param original function
---@param plate RPPlate
RP:WrapHook("GetHealthColor", function(original, plate)
    local unit = plate.unit
    if not unit then return original(plate) end

    local db = RP.db.threat
    if not db.enabled then return original(plate) end
    if not InCombatLockdown() then return original(plate) end
    if not UnitCanAttack("player", unit) then return original(plate) end

    local threat = UnitThreatSituation("player", unit)
    if not threat then return original(plate) end

    local spec = GetSpecialization()
    local isTank = spec and GetSpecializationRole(spec) == "TANK"
    -- threat: 0 = not on list, 1 = on list but not tanking,
    --         2 = high threat / about to pull, 3 = tanking (has aggro)
    local c
    if isTank then
        if threat == 3 then
            c = db.colorTankAggro      -- green: tanking, good
        elseif threat == 2 then
            c = db.colorTankLow        -- orange: losing aggro
        else
            c = db.colorTankNoAggro    -- red: lost aggro
        end
    else
        if threat == 3 then
            c = db.colorDpsAggro       -- red: pulling aggro
        elseif threat == 2 then
            c = db.colorDpsHigh        -- orange: high threat
        else
            c = db.colorDpsNoAggro     -- green: safe
        end
    end
    return c.r, c.g, c.b
end)
