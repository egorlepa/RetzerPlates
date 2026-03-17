local _, ns = ...
local RP = ns.RP ---@type RP

----------------------------------------------------------------
-- Mouseover highlight (OnUpdate polling, like Plater)
----------------------------------------------------------------

---@param plate RPPlate
RP:RegisterHook("ConstructHighlight", function(plate)
    local isOver = false
    plate:SetScript("OnUpdate", function()
        local unit = plate.unit
        if not unit then
            if isOver then
                isOver = false
                RP:Call("OnPlateLeave", plate)
            end
            return
        end
        local nowOver = UnitIsUnit("mouseover", unit)
        if nowOver and not isOver then
            isOver = true
            RP:Call("OnPlateEnter", plate)
        elseif not nowOver and isOver then
            isOver = false
            RP:Call("OnPlateLeave", plate)
        end
    end)
end)

---@param plate RPPlate
RP:RegisterHook("OnPlateEnter", function(plate)
    if plate.Health and plate.Health.highlight and not RP.IsPassive(plate) then
        plate.Health.highlight:Show()
    end
end)

---@param plate RPPlate
RP:RegisterHook("OnPlateLeave", function(plate)
    if plate.Health and plate.Health.highlight then
        plate.Health.highlight:Hide()
    end
end)
