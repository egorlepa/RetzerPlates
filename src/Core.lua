local ADDON_NAME, ns = ...

---@alias RPFrameType "PLAYER"|"FRIENDLY_PLAYER"|"ENEMY_PLAYER"|"FRIENDLY_NPC"|"ENEMY_NPC"

---@class RPColor
---@field r number
---@field g number
---@field b number
---@field a number?

---@class RPSchemaSection
---@field _meta RPSchemaMeta?

---@class RPSchemaMeta
---@field label string
---@field order number?

---@class RPDatabase
---@field general RPGeneralConfig
---@field visibility RPVisibilityConfig
---@field distances RPDistancesConfig
---@field healthbar RPHealthbarConfig
---@field name RPNameConfig
---@field castbar RPCastbarConfig
---@field threat RPThreatConfig
---@field auras RPAurasConfig
---@field crowdControl RPCCConfig
---@field execute RPExecuteConfig
---@field target RPTargetConfig
---@field quest RPQuestConfig
---@field raidMarker RPRaidMarkerConfig
---@field classification RPClassificationConfig
---@field minimap table

---@class RPModule
---@field name string
---@field Initialize fun(self: RPModule)?

-- Public addon table accessible as RetzerPlates globally
---@class RP
---@field db RPDatabase
---@field schema table<string, RPSchemaSection>
---@field defaults table<string, table>
---@field aceDB table
---@field ExtractDefaults fun(schema: table): table
---@field RefreshAllPlates fun()?
---@field version string
---@field IsFriendly fun(frameType: RPFrameType): boolean
---@field IsPassive fun(plate: RPPlate): boolean
---@field CreateIconFrame fun(parent: Frame, db: table): RPIconFrame
---@field RegisterSchema fun(self: RP, key: string, section: RPSchemaSection)
---@field RegisterRightSlot fun(self: RP, name: string)
---@field SetSlotFrame fun(self: RP, plate: RPPlate, name: string, frame: Frame)
---@field SetSlotActive fun(self: RP, plate: RPPlate, name: string, active: boolean)
---@field GetLastSlot fun(self: RP, plate: RPPlate): Frame
---@field LayoutRightSlots fun(self: RP, plate: RPPlate)
---@field SetLeftAnchor fun(self: RP, plate: RPPlate, frame: Frame)
---@field ClearLeftAnchor fun(self: RP, plate: RPPlate)
---@field GetLeftAnchor fun(self: RP, plate: RPPlate): Frame
local RP = {}
ns.RP = RP
_G.RetzerPlates = RP

RP.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")

----------------------------------------------------------------
-- Event dispatcher
----------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local events = {}

function RP:RegisterEvent(event, callback)
    events[event] = events[event] or {}
    events[event][callback] = true
    eventFrame:RegisterEvent(event)
end

function RP:UnregisterEvent(event, callback)
    if events[event] then
        events[event][callback] = nil
        if not next(events[event]) then
            events[event] = nil
            eventFrame:UnregisterEvent(event)
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if events[event] then
        for callback in pairs(events[event]) do
            callback(event, ...)
        end
    end
end)

----------------------------------------------------------------
-- Hook system
----------------------------------------------------------------

local hooks = {}    -- name -> current function
local defaults = {} -- name -> original default function (for ResetHook)

function RP:RegisterHook(name, fn)
    defaults[name] = fn
    if not hooks[name] then
        hooks[name] = fn
    end
end

function RP:Call(name, ...)
    local fn = hooks[name]
    if not fn then
        error("RetzerPlates: Unknown hook '" .. name .. "'")
    end
    local ok, r1, r2, r3 = pcall(fn, ...)
    if not ok then
        geterrorhandler()(r1)
        return
    end
    return r1, r2, r3
end

function RP:SetHook(name, fn)
    if not defaults[name] then
        error("RetzerPlates: Cannot set unknown hook '" .. name .. "'")
    end
    hooks[name] = fn
end

function RP:WrapHook(name, wrapper)
    local current = hooks[name]
    if not current then
        error("RetzerPlates: Cannot wrap unknown hook '" .. name .. "'")
    end
    hooks[name] = function(...)
        return wrapper(current, ...)
    end
end

function RP:ResetHook(name)
    hooks[name] = defaults[name]
end

function RP:GetHook(name)
    return hooks[name]
end

----------------------------------------------------------------
-- Module system
----------------------------------------------------------------

local modules = {}

function RP:NewModule(name)
    local mod = { name = name }
    modules[name] = mod
    return mod
end

function RP:GetModule(name)
    return modules[name]
end

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------

local function onAddonLoaded(event, addon)
    if addon ~= ADDON_NAME then return end
    RP:UnregisterEvent("ADDON_LOADED", onAddonLoaded)

    -- Build defaults from schema and initialize AceDB
    RP.defaults = RP.ExtractDefaults(RP.schema)
    local aceDB = LibStub("AceDB-3.0"):New("RetzerPlatesDB", {
        profile = RP.defaults,
        global = { minimap = {} },
    })
    RP.aceDB = aceDB
    RP.db = aceDB.profile

    -- Re-wire RP.db on profile changes and refresh all plates
    local function OnProfileChanged()
        RP.db = RP.aceDB.profile
        if RP.RefreshAllPlates then RP.RefreshAllPlates() end
    end
    aceDB.RegisterCallback(RP, "OnProfileChanged", OnProfileChanged)
    aceDB.RegisterCallback(RP, "OnProfileReset", OnProfileChanged)
    aceDB.RegisterCallback(RP, "OnProfileCopied", OnProfileChanged)

    for _, mod in pairs(modules) do
        if mod.Initialize then
            mod:Initialize()
        end
    end
end

RP:RegisterEvent("ADDON_LOADED", onAddonLoaded)
