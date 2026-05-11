-- Vehicle Loader - Statebag System
-- Moderne Network-Synchronization via FiveM Statebags
--
-- State Bag Keys:
--   Trailer Entity:
--     state.vehicleLoaderSlots = { [slotId] = vehicleNet }
--
--   Vehicle Entity:
--     state.vehicleLoaderAttached = { trailerNet, slotId }
--
-- Benefits:
--   - Auto-Sync für alle Clients
--   - Late-Joiner bekommen State automatisch
--   - Cleanup bei Entity-Despawn automatisch
--   - Weniger Network Events

StatebagAPI = {}

-- ============================================================
-- SERVER-SIDE STATE MANAGEMENT
-- ============================================================
if IsDuplicityVersion() then

    -- Slot belegen (Server-side, atomar)
    function StatebagAPI.OccupySlot(trailerEntity, slotId, vehicleNet)
        if not trailerEntity or trailerEntity == 0 then return false end

        local slots = Entity(trailerEntity).state.vehicleLoaderSlots or {}

        -- Slot bereits belegt?
        if slots[tostring(slotId)] then
            return false
        end

        -- Atomic update (Statebag ist server-authoritative)
        slots[tostring(slotId)] = vehicleNet
        Entity(trailerEntity).state:set('vehicleLoaderSlots', slots, true)

        return true
    end

    -- Slot freigeben
    function StatebagAPI.ReleaseSlot(trailerEntity, slotId)
        if not trailerEntity or trailerEntity == 0 then return false end

        local slots = Entity(trailerEntity).state.vehicleLoaderSlots or {}
        slots[tostring(slotId)] = nil

        Entity(trailerEntity).state:set('vehicleLoaderSlots', slots, true)
        return true
    end

    -- Slot Status abfragen
    function StatebagAPI.IsSlotOccupied(trailerEntity, slotId)
        if not trailerEntity or trailerEntity == 0 then return false end

        local slots = Entity(trailerEntity).state.vehicleLoaderSlots or {}
        return slots[tostring(slotId)] ~= nil
    end

    -- Vehicle als geladen markieren
    function StatebagAPI.AttachVehicleState(vehicleEntity, trailerNet, slotId)
        if not vehicleEntity or vehicleEntity == 0 then return end

        Entity(vehicleEntity).state:set('vehicleLoaderAttached', {
            trailerNet = trailerNet,
            slotId = slotId,
        }, true)
    end

    -- Vehicle als entladen markieren
    function StatebagAPI.DetachVehicleState(vehicleEntity)
        if not vehicleEntity or vehicleEntity == 0 then return end

        Entity(vehicleEntity).state:set('vehicleLoaderAttached', nil, true)
    end

    -- Alle Slots auf Trailer abfragen
    function StatebagAPI.GetTrailerSlots(trailerEntity)
        if not trailerEntity or trailerEntity == 0 then return {} end
        return Entity(trailerEntity).state.vehicleLoaderSlots or {}
    end

    -- Count loaded vehicles on trailer
    function StatebagAPI.CountSlotsOccupied(trailerEntity)
        if not trailerEntity or trailerEntity == 0 then return 0 end

        local slots = Entity(trailerEntity).state.vehicleLoaderSlots or {}
        local count = 0
        for _ in pairs(slots) do count = count + 1 end
        return count
    end
end

-- ============================================================
-- CLIENT-SIDE STATE LISTENERS
-- ============================================================
if not IsDuplicityVersion() then

    -- ============================================================
    -- HELPER: Parse Entity NetId aus Bag Name
    -- ============================================================
    -- bagName Format: "entity:<netId>" oder "Entity:<netId>"
    -- gsub returnt 2 Werte (string, count) → extra Klammern nötig!
    local function ExtractNetIdFromBag(bagName)
        local cleaned = (bagName:gsub('^entity:', ''):gsub('^Entity:', ''))
        return tonumber(cleaned)
    end

    -- ============================================================
    -- TRAILER SLOTS CHANGE HANDLER
    -- ============================================================
    AddStateBagChangeHandler('vehicleLoaderSlots', nil, function(bagName, key, value, _, replicated)
        local entityNetId = ExtractNetIdFromBag(bagName)
        if not entityNetId then return end

        local trailer = NetworkGetEntityFromNetworkId(entityNetId)
        if not trailer or trailer == 0 then return end

        -- Triggere Event für andere Systeme
        TriggerEvent('vehicle_loader:state:trailerSlotsChanged', trailer, entityNetId, value or {})
    end)

    -- ============================================================
    -- VEHICLE ATTACH STATE HANDLER
    -- ============================================================
    AddStateBagChangeHandler('vehicleLoaderAttached', nil, function(bagName, key, value, _, replicated)
        local entityNetId = ExtractNetIdFromBag(bagName)
        if not entityNetId then return end

        local vehicle = NetworkGetEntityFromNetworkId(entityNetId)
        if not vehicle or vehicle == 0 then return end

        if value then
            -- Vehicle wurde an Trailer attached
            TriggerEvent('vehicle_loader:state:vehicleAttached', vehicle, entityNetId, value)
        else
            -- Vehicle wurde detached
            TriggerEvent('vehicle_loader:state:vehicleDetached', vehicle, entityNetId)
        end
    end)

    -- ============================================================
    -- CLIENT API
    -- ============================================================

    -- Check ob Vehicle aktuell geladen ist (via Statebag)
    function StatebagAPI.IsVehicleLoaded(vehicleEntity)
        if not vehicleEntity or vehicleEntity == 0 then return false end
        return Entity(vehicleEntity).state.vehicleLoaderAttached ~= nil
    end

    -- Get attached info
    function StatebagAPI.GetVehicleAttachData(vehicleEntity)
        if not vehicleEntity or vehicleEntity == 0 then return nil end
        return Entity(vehicleEntity).state.vehicleLoaderAttached
    end

    -- Get all loaded vehicles on trailer
    function StatebagAPI.GetTrailerSlots(trailerEntity)
        if not trailerEntity or trailerEntity == 0 then return {} end
        return Entity(trailerEntity).state.vehicleLoaderSlots or {}
    end

    -- Slot belegt?
    function StatebagAPI.IsSlotOccupied(trailerEntity, slotId)
        if not trailerEntity or trailerEntity == 0 then return false end
        local slots = Entity(trailerEntity).state.vehicleLoaderSlots or {}
        return slots[tostring(slotId)] ~= nil
    end

    -- Count occupied slots
    function StatebagAPI.CountSlotsOccupied(trailerEntity)
        if not trailerEntity or trailerEntity == 0 then return 0 end
        local slots = Entity(trailerEntity).state.vehicleLoaderSlots or {}
        local count = 0
        for _ in pairs(slots) do count = count + 1 end
        return count
    end
end

print('^2[Vehicle Loader Statebags]^7 State Bag System geladen!')
