-- Vehicle Loader Zones System (v3.1)
-- lib.zones + lib.points für maximale Performance

ActiveZones = {}      -- trailerNetId -> { slotId -> zone }
ActivePoints = {}     -- trailerNetId -> lib.point
DebugZonesActive = false

-- ============================================================
-- HELPERS (mit lib.cache)
-- ============================================================

-- Slot World-Position berechnen
local function CalculateSlotWorldPos(trailer, slot)
    local trailerCoords = GetEntityCoords(trailer)
    local trailerHeading = GetEntityHeading(trailer)
    local radians = math.rad(trailerHeading)

    local offsetX = slot.offset.x * math.cos(radians) - slot.offset.y * math.sin(radians)
    local offsetY = slot.offset.x * math.sin(radians) + slot.offset.y * math.cos(radians)

    return vector3(
        trailerCoords.x + offsetX,
        trailerCoords.y + offsetY,
        trailerCoords.z + slot.offset.z
    )
end

-- Zone für einen Slot erstellen
local function CreateSlotZone(trailer, slot, debug)
    local trailerNet = NetworkGetNetworkIdFromEntity(trailer)

    -- ⭐ Color-Coded Zones im Debug Mode
    -- Grün = frei, Rot = belegt (wird beim Update gesetzt)
    return lib.zones.box({
        coords = CalculateSlotWorldPos(trailer, slot),
        size = vec3(2.5, 5.0, 2.0),
        rotation = GetEntityHeading(trailer) + (slot.rotation.z or 0),
        debug = debug or false,
        debugColour = {0, 255, 0, 100}, -- Grün als Default

        onEnter = function(self)
            -- lib.cache nutzen für PlayerPed
            local ped = cache.ped

            if IsPedInAnyVehicle(ped, false) then
                local vehicle = cache.vehicle or GetVehiclePedIsIn(ped, false)

                -- Nicht den Anhänger selbst aufladen!
                if vehicle == trailer then return end

                TriggerEvent('vehicle_loader:zone:vehicleEntered', {
                    trailer = trailer,
                    trailerNet = trailerNet,
                    slot = slot,
                    vehicle = vehicle,
                })
            end
        end,

        onExit = function(self)
            TriggerEvent('vehicle_loader:zone:vehicleExited', {
                trailer = trailer,
                trailerNet = trailerNet,
                slot = slot,
            })
        end,
    })
end

-- ============================================================
-- ZONE MANAGEMENT
-- ============================================================

function CreateZonesForTrailer(trailer, debug)
    local trailerConfig = GetTrailerConfigByEntity(trailer)
    if not trailerConfig then return end

    local trailerNet = NetworkGetNetworkIdFromEntity(trailer)
    RemoveZonesForTrailer(trailerNet)

    ActiveZones[trailerNet] = {}

    for _, slot in ipairs(trailerConfig.slots) do
        ActiveZones[trailerNet][slot.id] = CreateSlotZone(trailer, slot, debug)
    end
end

function RemoveZonesForTrailer(trailerNet)
    if not ActiveZones[trailerNet] then return end

    for _, zone in pairs(ActiveZones[trailerNet]) do
        if zone and zone.remove then
            zone:remove()
        end
    end

    ActiveZones[trailerNet] = nil
end

function RemoveAllZones()
    for trailerNet, _ in pairs(ActiveZones) do
        RemoveZonesForTrailer(trailerNet)
    end
end

-- ============================================================
-- ZONE AUTO-UPDATE (Anhänger-Bewegung)
-- ============================================================
CreateThread(function()
    while true do
        for trailerNet, zones in pairs(ActiveZones) do
            local trailer = NetworkGetEntityFromNetworkId(trailerNet)

            if not trailer or trailer == 0 or not DoesEntityExist(trailer) then
                RemoveZonesForTrailer(trailerNet)
            else
                local trailerConfig = GetTrailerConfigByEntity(trailer)
                if trailerConfig then
                    for slotId, zone in pairs(zones) do
                        if zone then
                            local slot
                            for _, s in ipairs(trailerConfig.slots) do
                                if s.id == slotId then slot = s break end
                            end

                            if slot then
                                zone.coords = CalculateSlotWorldPos(trailer, slot)
                                zone.rotation = GetEntityHeading(trailer) + (slot.rotation.z or 0)
                            end
                        end
                    end
                end
            end
        end

        Wait(250)
    end
end)

-- ============================================================
-- TRAILER DETECTION via lib.points (PERFORMANCE!)
-- ============================================================
-- lib.points statt eigenem Thread = native Performance
-- Wir erstellen für jeden Anhänger einen Point der bei nearby triggert

local function RegisterTrailerPoint(trailer)
    local trailerNet = NetworkGetNetworkIdFromEntity(trailer)

    if ActivePoints[trailerNet] then return end

    local point = lib.points.new({
        coords = GetEntityCoords(trailer),
        distance = 30.0,

        onEnter = function(self)
            -- Spieler nähert sich Anhänger → Zonen erstellen
            local currentTrailer = NetworkGetEntityFromNetworkId(trailerNet)
            if currentTrailer and currentTrailer ~= 0 then
                CreateZonesForTrailer(currentTrailer, DebugZonesActive)
            end
        end,

        onExit = function(self)
            -- Spieler entfernt sich → Zonen entfernen (Performance!)
            RemoveZonesForTrailer(trailerNet)
        end,

        nearby = function(self)
            -- Update Point-Position wenn Anhänger sich bewegt
            local currentTrailer = NetworkGetEntityFromNetworkId(trailerNet)
            if currentTrailer and currentTrailer ~= 0 then
                self.coords = GetEntityCoords(currentTrailer)
            end
        end,
    })

    ActivePoints[trailerNet] = point
end

-- Trailer-Scan: Findet neue Anhänger und registriert Points
-- Läuft seltener (5s) weil lib.points dann die Heavy Work macht
CreateThread(function()
    while true do
        local vehicles = GetGamePool('CVehicle')

        for _, vehicle in ipairs(vehicles) do
            if GetTrailerConfigByEntity(vehicle) then
                RegisterTrailerPoint(vehicle)
            end
        end

        -- Cleanup verwaiste Points
        for trailerNet, point in pairs(ActivePoints) do
            local trailer = NetworkGetEntityFromNetworkId(trailerNet)
            if not trailer or trailer == 0 or not DoesEntityExist(trailer) then
                if point.remove then point:remove() end
                ActivePoints[trailerNet] = nil
                RemoveZonesForTrailer(trailerNet)
            end
        end

        Wait(5000)
    end
end)

-- ============================================================
-- DEBUG TOGGLE
-- ============================================================

function ToggleDebugZones(state)
    DebugZonesActive = state

    for trailerNet, _ in pairs(ActiveZones) do
        local trailer = NetworkGetEntityFromNetworkId(trailerNet)
        if trailer and trailer ~= 0 then
            CreateZonesForTrailer(trailer, state)
        end
    end
end

-- ============================================================
-- ZONE EVENT HANDLERS
-- ============================================================

-- Animation Helper
local function PlayLoadingAnimation()
    lib.requestAnimDict('mini@repair', 5000)
    TaskPlayAnim(cache.ped, 'mini@repair', 'fixing_a_player', 8.0, -8.0, -1, 49, 0, false, false, false)
end

local function StopLoadingAnimation()
    ClearPedTasks(cache.ped)
end

-- Fahrzeug fährt in Slot-Zone
AddEventHandler('vehicle_loader:zone:vehicleEntered', function(data)
    if data.vehicle == data.trailer then return end

    local vehicleNet = NetworkGetNetworkIdFromEntity(data.vehicle)
    local loaded = GetLocalLoadedVehicles()
    if loaded[vehicleNet] then return end

    -- TextUI mit locale
    lib.showTextUI(
        locale('press_e_to_load'),
        {
            position = 'top-center',
            icon = 'fa-solid fa-truck-loading',
            style = {
                borderRadius = 8,
                backgroundColor = '#1e1e2e',
                color = '#fff',
            }
        }
    )

    -- E-Taste Listener
    CreateThread(function()
        while ActiveZones[data.trailerNet] and ActiveZones[data.trailerNet][data.slot.id] do
            Wait(0)

            if IsControlJustReleased(0, 38) then -- E
                TriggerEvent('vehicle_loader:zone:loadHere', data)
                break
            end

            -- Exit-Check via Distance (Cache-friendly)
            local pedCoords = GetEntityCoords(cache.ped)
            local slotCoords = CalculateSlotWorldPos(data.trailer, data.slot)
            if #(pedCoords - slotCoords) > 5.0 then
                break
            end
        end
        lib.hideTextUI()
    end)
end)

AddEventHandler('vehicle_loader:zone:vehicleExited', function(data)
    lib.hideTextUI()
end)

-- Load via Zone
AddEventHandler('vehicle_loader:zone:loadHere', function(data)
    if LoadVehicleInSlot then
        PlayLoadingAnimation()
        LoadVehicleInSlot(data.vehicle, data.trailer, data.slot.id)
        SetTimeout(Config.Global.LoadingTime + 500, StopLoadingAnimation)
    end
    lib.hideTextUI()
end)

-- ============================================================
-- CLEANUP
-- ============================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RemoveAllZones()

        for _, point in pairs(ActivePoints) do
            if point.remove then point:remove() end
        end
        ActivePoints = {}

        lib.hideTextUI()
    end
end)

-- ============================================================
-- EXPORTS
-- ============================================================

exports('ToggleZoneDebug', function(state)
    ToggleDebugZones(state)
end)

exports('GetActiveZones', function()
    return ActiveZones
end)

print('^2[Vehicle Loader Zones]^7 Zone System geladen (lib.zones + lib.points)!')
