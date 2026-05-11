-- Vehicle Loader Public API - Client Side
-- Für andere Resources um lokal Daten abzufragen

-- ============================================================
-- EXPORTS (Client-Side)
-- ============================================================

-- Get all locally cached loaded vehicles
exports('GetLoadedVehicles', function()
    return GetLocalLoadedVehicles()
end)

-- Check if vehicle is loaded (lokal)
exports('IsVehicleLoaded', function(vehicleNet)
    local loaded = GetLocalLoadedVehicles()
    return loaded[vehicleNet] ~= nil
end)

-- Get vehicle slot info
exports('GetVehicleSlot', function(vehicleNet)
    local loaded = GetLocalLoadedVehicles()
    return loaded[vehicleNet] and loaded[vehicleNet].slotId or nil
end)

-- Get vehicles on trailer (lokal)
exports('GetVehiclesOnTrailer', function(trailerNet)
    local vehicles = {}
    for vehicleNet, data in pairs(GetLocalLoadedVehicles()) do
        if data.trailerNet == trailerNet then
            vehicles[#vehicles + 1] = {
                vehicleNet = vehicleNet,
                slotId = data.slotId,
            }
        end
    end
    return vehicles
end)

-- Get trailer config (model definitions)
exports('GetTrailerConfig', function(model)
    if type(model) == 'string' then
        model = GetHashKey(model)
    end
    return GetTrailerConfig(model)
end)

-- Check if entity is a configured trailer
exports('IsConfiguredTrailer', function(entity)
    return GetTrailerConfigByEntity(entity) ~= nil
end)

-- ============================================================
-- EVENTS (Andere Resources können diese auslösen)
-- ============================================================

-- Event: Request Load
RegisterNetEvent('vehicle_loader:api:requestLoad', function(vehicleNet, trailerNet)
    -- Delegiert an die normale Load-Funktion
    TriggerEvent('vehicle_loader:internal:load', vehicleNet, trailerNet)
end)

-- Event: Request Unload
RegisterNetEvent('vehicle_loader:api:requestUnload', function(trailerNet)
    TriggerEvent('vehicle_loader:internal:unload', trailerNet)
end)

print('^2[Vehicle Loader API]^7 Client API loaded')
