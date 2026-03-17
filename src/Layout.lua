local _, ns = ...
local RP = ns.RP ---@type RP

----------------------------------------------------------------
-- Right-side slot layout system
--
-- Plugins register named slots with an order number.
-- At construction time, plugins hand their frame to the system.
-- The system owns all anchoring — plugins just toggle active/inactive.
--
-- Usage:
--   RP:RegisterRightSlot("raidMarker", 1)
--   RP:SetSlotFrame(plate, "raidMarker", frame)
--   RP:SetSlotActive(plate, "raidMarker", true)
--   RP:SetSlotActive(plate, "raidMarker", false)
--   RP:GetLastSlot(plate) -- returns rightmost active frame, or plate.Health
----------------------------------------------------------------

---@class RPPlate
---@field _rightSlots table<string, { frame: Frame, active: boolean }>?

local SLOT_GAP = 2

-- Ordered list of registered slot names (order = TOC load order)
local slotOrder = {} -- { "raidMarker", "quest", "cc", ... }

--- Register a named slot. Call once at file load time.
--- Order is determined by registration order (= TOC load order).
---@param name string
function RP:RegisterRightSlot(name)
    slotOrder[#slotOrder + 1] = name
end

--- Assign a frame to a slot on a specific plate.
---@param plate RPPlate
---@param name string
---@param frame Frame
function RP:SetSlotFrame(plate, name, frame)
    if not plate._rightSlots then
        plate._rightSlots = {}
    end
    plate._rightSlots[name] = { frame = frame, active = false }
end

--- Get the rightmost active slot frame, or plate.Health as fallback.
---@param plate RPPlate
---@return Frame
function RP:GetLastSlot(plate)
    local base = (RP.IsPassive(plate) and plate.Name or plate.Health) ---@type Frame
    if not plate._rightSlots then return base end
    for i = #slotOrder, 1, -1 do
        local slot = plate._rightSlots[slotOrder[i]]
        if slot and slot.active then
            return slot.frame
        end
    end
    return base
end

--- Toggle a slot active/inactive and re-layout the chain.
---@param plate RPPlate
---@param name string
---@param active boolean
function RP:SetSlotActive(plate, name, active)
    if not plate._rightSlots then return end
    local slot = plate._rightSlots[name]
    if not slot then return end
    slot.active = active
    if active then
        slot.frame:Show()
    else
        slot.frame:Hide()
    end
    self:LayoutRightSlots(plate)
end

--- Re-anchor all slots in order. Only active slots get chained.
--- Fires OnLayoutChanged hook after repositioning.
---@param plate RPPlate
function RP:LayoutRightSlots(plate)
    if not plate._rightSlots then return end
    local prev = (RP.IsPassive(plate) and plate.Name or plate.Health) ---@type Frame
    for _, name in ipairs(slotOrder) do
        local slot = plate._rightSlots[name]
        if slot and slot.active then
            slot.frame:ClearAllPoints()
            slot.frame:SetPoint("LEFT", prev, "RIGHT", SLOT_GAP, 0)
            prev = slot.frame
        end
    end
    RP:Call("OnLayoutChanged", plate, prev)
end

---@param plate RPPlate
---@param lastAnchor Frame
RP:RegisterHook("OnLayoutChanged", function(plate, lastAnchor) end)

----------------------------------------------------------------
-- Left-side anchor
--
-- Simpler than right slots — just one frame at a time.
-- Plugins call SetLeftAnchor to declare themselves as the
-- leftmost element. Fires OnLeftLayoutChanged so listeners
-- (e.g. target arrow) can reposition.
--
-- Usage:
--   RP:SetLeftAnchor(plate, frame)   -- cast icon showing
--   RP:ClearLeftAnchor(plate)        -- cast icon hidden
----------------------------------------------------------------

---@class RPPlate
---@field _leftAnchor Frame?

--- Set the leftmost anchor frame on a plate.
---@param plate RPPlate
---@param frame Frame
function RP:SetLeftAnchor(plate, frame)
    plate._leftAnchor = frame
    RP:Call("OnLeftLayoutChanged", plate, frame)
end

--- Clear the left anchor, falling back to plate.Health.
---@param plate RPPlate
function RP:ClearLeftAnchor(plate)
    plate._leftAnchor = nil
    RP:Call("OnLeftLayoutChanged", plate, plate.Health)
end

--- Get the current left anchor.
---@param plate RPPlate
---@return Frame
function RP:GetLeftAnchor(plate)
    return plate._leftAnchor or plate.Health
end

---@param plate RPPlate
---@param leftmostAnchor Frame
RP:RegisterHook("OnLeftLayoutChanged", function(plate, leftmostAnchor) end)

-- Replace GetRightAnchor with the slot system
RP:RegisterHook("GetRightAnchor", function(plate)
    return RP:GetLastSlot(plate)
end)
