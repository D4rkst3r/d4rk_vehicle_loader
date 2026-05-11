-- Vehicle Loader Public API - Server Side
-- Für andere Resources um mit Vehicle Loader zu interagieren

-- ============================================================
-- EXPORTS (Andere Resources fragen Daten ab)
-- ============================================================

-- Get all loaded vehicles
exports('GetLoadedVehicles', function()
    return GetAllLoadedVehicles()
end)

-- Check if vehicle is loaded
exports('IsVehicleLoaded', function(vehicleNet)
    return GetLoadedVehicleData(vehicleNet) ~= nil
end)

-- Get vehicle data (trailer, slot, owner, time)
exports('GetVehicleData', function(vehicleNet)
    return GetLoadedVehicleData(vehicleNet)
end)

-- Get all vehicles on a specific trailer
exports('GetVehiclesOnTrailer', function(trailerNet)
    local vehicles = {}
    for vehicleNet, data in pairs(GetAllLoadedVehicles()) do
        if data.trailerNet == trailerNet then
            vehicles[#vehicles + 1] = {
                vehicleNet = vehicleNet,
                slotId = data.slotId,
                owner = data.owner,
                loadedAt = data.loadedAt,
            }
        end
    end
    return vehicles
end)

-- Check if trailer has free slots
exports('HasFreeSlots', function(trailerNet)
    local trailer = NetworkGetEntityFromNetworkId(trailerNet)
    if not trailer or trailer == 0 then return false end

    local model = GetEntityModel(trailer)
    local maxVehicles = 1

    for _, config in ipairs(Config.Trailers) do
        if GetHashKey(config.model) == model then
            maxVehicles = config.maxVehicles
            break
        end
    end

    local count = 0
    for _, data in pairs(GetAllLoadedVehicles()) do
        if data.trailerNet == trailerNet then
            count = count + 1
        end
    end

    return count < maxVehicles
end)

-- Get free slots on a trailer
exports('GetFreeSlots', function(trailerNet)
    local trailer = NetworkGetEntityFromNetworkId(trailerNet)
    if not trailer or trailer == 0 then return {} end

    local model = GetEntityModel(trailer)
    local trailerConfig = nil

    for _, config in ipairs(Config.Trailers) do
        if GetHashKey(config.model) == model then
            trailerConfig = config
            break
        end
    end

    if not trailerConfig then return {} end

    -- Get occupied slots
    local occupied = {}
    for _, data in pairs(GetAllLoadedVehicles()) do
        if data.trailerNet == trailerNet then
            occupied[data.slotId] = true
        end
    end

    -- Find free slots
    local freeSlots = {}
    for _, slot in ipairs(trailerConfig.slots) do
        if not occupied[slot.id] then
            freeSlots[#freeSlots + 1] = slot.id
        end
    end

    return freeSlots
end)

-- ============================================================
-- FORCE FUNCTIONS (Für andere Resources um Aktionen auszuführen)
-- ============================================================

-- Force Load Vehicle (ohne Items/Geld zu verbrauchen)
exports('ForceLoadVehicle', function(vehicleNet, trailerNet, slotId, source)
    return ForceLoadVehicleInternal(vehicleNet, trailerNet, slotId, source)
end)

-- Force Unload Vehicle
exports('ForceUnloadVehicle', function(vehicleNet)
    return ForceUnloadVehicleInternal(vehicleNet)
end)

-- Force Unload Trailer (alle Fahrzeuge)
exports('ForceUnloadAllFromTrailer', function(trailerNet)
    local unloaded = 0
    local toUnload = {}

    for vehicleNet, data in pairs(GetAllLoadedVehicles()) do
        if data.trailerNet == trailerNet then
            toUnload[#toUnload + 1] = vehicleNet
        end
    end

    for _, vehicleNet in ipairs(toUnload) do
        if ForceUnloadVehicleInternal(vehicleNet) then
            unloaded = unloaded + 1
        end
    end

    return unloaded
end)

-- ============================================================
-- EVENTS (Andere Resources können diese auslösen)
-- ============================================================

-- Event: Force Load via Event
RegisterNetEvent('vehicle_loader:api:forceLoad', function(vehicleNet, trailerNet, slotId)
    ForceLoadVehicleInternal(vehicleNet, trailerNet, slotId, source)
end)

-- Event: Force Unload via Event
RegisterNetEvent('vehicle_loader:api:forceUnload', function(vehicleNet)
    ForceUnloadVehicleInternal(vehicleNet)
end)

-- ============================================================
-- CALLBACKS (Für synchrone Datenabfrage)
-- ============================================================

-- Callback: Get Loaded Vehicles
lib.callback.register('vehicle_loader:api:getLoadedVehicles', function(source)
    return GetAllLoadedVehicles()
end)

-- Callback: Is Vehicle Loaded
lib.callback.register('vehicle_loader:api:isVehicleLoaded', function(source, vehicleNet)
    return GetLoadedVehicleData(vehicleNet) ~= nil
end)

-- Callback: Get Trailer Info
lib.callback.register('vehicle_loader:api:getTrailerInfo', function(source, trailerNet)
    local trailer = NetworkGetEntityFromNetworkId(trailerNet)
    if not trailer or trailer == 0 then return nil end

    local model = GetEntityModel(trailer)
    for _, config in ipairs(Config.Trailers) do
        if GetHashKey(config.model) == model then
            local loadedCount = 0
            for _, data in pairs(GetAllLoadedVehicles()) do
                if data.trailerNet == trailerNet then
                    loadedCount = loadedCount + 1
                end
            end

            return {
                model = config.model,
                label = config.label,
                maxVehicles = config.maxVehicles,
                slotCount = #config.slots,
                loadedCount = loadedCount,
                hasFreeSlots = loadedCount < config.maxVehicles,
            }
        end
    end

    return nil
end)

print('^2[Vehicle Loader API]^7 Public API loaded - andere Resources können nun integrieren!')
