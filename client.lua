-- Vehicle Loader System - Client (v3.4)
-- ox_lib + Statebags + lib.cache + lib.points + lib.locale + Multi-Slot

-- Init Locale
lib.locale(Config.Global.Locale or 'de')

local LoadedVehicles = {} -- NetId -> {trailerNet, slotId}

-- Expose to api/client.lua
function GetLocalLoadedVehicles()
    return LoadedVehicles
end

-- Check if valid flatbed
local function IsValidFlatbed(vehicle)
    return GetTrailerConfigByEntity(vehicle) ~= nil
end

-- Find nearby flatbed (uses lib.cache for performance)
local function FindNearbyFlatbed(targetCoords)
    targetCoords = targetCoords or GetEntityCoords(cache.ped)

    local vehicles = GetGamePool('CVehicle')
    local nearestDist = 20.0
    local nearestTrailer = nil

    for _, vehicle in ipairs(vehicles) do
        if IsValidFlatbed(vehicle) then
            local dist = #(targetCoords - GetEntityCoords(vehicle))
            if dist < nearestDist then
                nearestDist = dist
                nearestTrailer = vehicle
            end
        end
    end

    return nearestTrailer
end

-- Find available slot
local function FindAvailableSlot(trailerEntity)
    local trailerConfig = GetTrailerConfigByEntity(trailerEntity)
    if not trailerConfig then return nil end

    local occupiedSlots = {}
    for _, data in pairs(LoadedVehicles) do
        if NetworkGetEntityFromNetworkId(data.trailerNet) == trailerEntity then
            occupiedSlots[data.slotId] = true
        end
    end

    for _, slot in ipairs(trailerConfig.slots) do
        if not occupiedSlots[slot.id] then
            return slot.id
        end
    end

    return nil
end

-- Get slot config
local function GetSlotConfig(trailerEntity, slotId)
    local trailerConfig = GetTrailerConfigByEntity(trailerEntity)
    if not trailerConfig then return nil end

    for _, slot in ipairs(trailerConfig.slots) do
        if slot.id == slotId then
            return slot
        end
    end

    return nil
end

-- ============================================================
-- NETWORK OWNERSHIP HELPER
-- ============================================================
-- Request Network-Ownership einer Entity (mit Timeout)
-- Returns true wenn Ownership erhalten, false bei Timeout
---@param entity number
---@param timeout? number ms (default 1500)
---@return boolean
local function RequestNetworkOwnership(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    -- Wir sind schon Owner?
    if NetworkHasControlOfEntity(entity) then
        return true
    end

    timeout = timeout or 1500
    local deadline = GetGameTimer() + timeout

    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end

    return NetworkHasControlOfEntity(entity)
end

-- Attach Vehicle Helper mit korrektem NetworkOwner-Handling
local function AttachVehicleToTrailer(vehicle, trailer, slotConfig)
    -- ⭐ Network Ownership SICHERSTELLEN bevor wir die Entity manipulieren
    -- Sonst werden SetEntityCoords/AttachEntityToEntity vom Server ignoriert
    local hasVehicleControl = RequestNetworkOwnership(vehicle, 1500)
    local hasTrailerControl = RequestNetworkOwnership(trailer, 1500)

    if not hasVehicleControl then
        -- Wir konnten Ownership nicht bekommen → anderer Client macht es
        -- (Der NetworkOwner des Vehicles wird Attach durchführen)
        return false
    end

    local trailerCoords = GetEntityCoords(trailer)
    local trailerHeading = GetEntityHeading(trailer)

    local radians = math.rad(trailerHeading)
    local offsetX = slotConfig.offset.x * math.cos(radians) - slotConfig.offset.y * math.sin(radians)
    local offsetY = slotConfig.offset.x * math.sin(radians) + slotConfig.offset.y * math.cos(radians)

    local newCoords = vector3(
        trailerCoords.x + offsetX,
        trailerCoords.y + offsetY,
        trailerCoords.z + slotConfig.offset.z
    )

    -- Velocity reset (verhindert Glitches durch Restgeschwindigkeit)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)

    SetEntityCoords(vehicle, newCoords.x, newCoords.y, newCoords.z, false, false, false, true)
    SetEntityHeading(vehicle, trailerHeading + slotConfig.rotation.z)

    -- ⭐ Disable Kollision zwischen Vehicle und Trailer (verhindert Glitches)
    SetEntityNoCollisionEntity(vehicle, trailer, false)
    SetEntityNoCollisionEntity(trailer, vehicle, false)

    AttachEntityToEntity(
        vehicle,                  -- entity to attach
        trailer,                  -- entity to attach to
        0,                        -- boneIndex
        slotConfig.offset.x,      -- xOffset
        slotConfig.offset.y,      -- yOffset
        slotConfig.offset.z,      -- zOffset
        slotConfig.rotation.x,    -- xRotation
        slotConfig.rotation.y,    -- yRotation
        slotConfig.rotation.z,    -- zRotation
        false,                    -- p9: useSoftPinning (false = bleibt fest attached)
        false,                    -- ⭐ collision: FALSE (keine Kollision Vehicle vs Trailer)
        false,                    -- isPed
        true,                     -- vertexIndex
        2,                        -- rotationOrder (2 = ZYX, stabilste Rotation)
        true                      -- fixedRot (Rotation fest)
    )

    -- ⭐ Network ID Migration sperren (verhindert dass Ownership wandert während attached)
    local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    if vehicleNetId and vehicleNetId ~= 0 then
        SetNetworkIdCanMigrate(vehicleNetId, false)
    end

    -- Entity Properties optimieren für stabile Attach
    SetEntityCollision(vehicle, true, true)  -- Welt-Collision aktiv lassen
    FreezeEntityPosition(vehicle, false)     -- Nicht freezen (würde sich nicht mehr mitbewegen)
    SetEntityAsMissionEntity(vehicle, true, true)  -- Verhindert auto-despawn

    return true
end

-- Load Vehicle (in specific slot)
function LoadVehicleInSlot(targetVehicle, trailerEntity, slotId)
    local vehicleNet = VehToNet(targetVehicle)
    local trailerNet = VehToNet(trailerEntity)

    -- ⭐ Client-Side Restriction Check (Class + Size) - VOR Server-Validation
    local trailerConfig = GetTrailerConfigByEntity(trailerEntity)
    if trailerConfig then
        local allowed, reason = Restrictions.IsVehicleAllowed(targetVehicle, trailerConfig)
        if not allowed then
            local message = 'Dieses Fahrzeug ist nicht erlaubt!'

            if reason == 'class_not_allowed' or reason == 'class_blacklisted' or reason == 'class_blacklisted_global' then
                local className = Restrictions.GetClassName(GetVehicleClass(targetVehicle))
                message = ('Klasse "%s" nicht erlaubt!'):format(className)
            elseif reason == 'too_large' then
                message = 'Fahrzeug ist zu groß für diesen Anhänger!'
            end

            Bridge.Notify(locale('loader_title'), message, 'error')
            return
        end
    end

    -- Server validation
    local valid = lib.callback.await('vehicle_loader:validateLoad', false, vehicleNet, trailerNet, slotId)
    if not valid then return end

    -- Get trailer ramp config
    local trailerConfig = GetTrailerConfigByEntity(trailerEntity)
    local rampConfig = trailerConfig and trailerConfig.ramp

    -- Rampe öffnen + Sound
    if rampConfig and rampConfig.enabled then
        Effects.StartLoading(trailerEntity, rampConfig.doorIndex)
        Wait(rampConfig.openTime or 500)
    end

    -- Player Animation
    if Config.Global.EnableAnimations then
        lib.requestAnimDict('mini@repair', 5000)
        TaskPlayAnim(cache.ped, 'mini@repair', 'fixing_a_player', 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    -- Progress Bar
    if not Bridge.ProgressBar(locale('loading_vehicle'), Config.Global.LoadingTime) then
        Bridge.Notify(locale('loader_title'), locale('loading_cancelled'), 'error')
        ClearPedTasks(cache.ped)
        if rampConfig and rampConfig.enabled then
            Effects.CloseRamp(trailerEntity, rampConfig.doorIndex)
        end
        return
    end

    ClearPedTasks(cache.ped)

    -- Rampe schließen + Final Sound
    if rampConfig and rampConfig.enabled then
        Effects.FinishLoading(trailerEntity, rampConfig.doorIndex)
    end

    -- Notify server to complete
    TriggerServerEvent('vehicle_loader:load', vehicleNet, trailerNet, slotId)
end

-- Get all available slots on a trailer
local function GetAvailableSlots(trailerEntity)
    local trailerConfig = GetTrailerConfigByEntity(trailerEntity)
    if not trailerConfig then return {} end

    local occupiedSlots = {}
    for _, data in pairs(LoadedVehicles) do
        if NetworkGetEntityFromNetworkId(data.trailerNet) == trailerEntity then
            occupiedSlots[data.slotId] = true
        end
    end

    local available = {}
    for _, slot in ipairs(trailerConfig.slots) do
        if not occupiedSlots[slot.id] then
            available[#available + 1] = slot
        end
    end

    return available
end

-- Load Vehicle (auto-finds nearest trailer & slot, asks user if multiple)
local function LoadVehicle(targetVehicle)
    local targetCoords = GetEntityCoords(targetVehicle)
    local trailerEntity = FindNearbyFlatbed(targetCoords)

    if not trailerEntity then
        Bridge.Notify(locale('loader_title'), locale('no_trailer_nearby'), 'error')
        return
    end

    local availableSlots = GetAvailableSlots(trailerEntity)

    if #availableSlots == 0 then
        Bridge.Notify(locale('loader_title'), locale('no_free_slots'), 'error')
        return
    end

    -- Nur 1 Slot frei? → Direkt nutzen
    if #availableSlots == 1 then
        LoadVehicleInSlot(targetVehicle, trailerEntity, availableSlots[1].id)
        return
    end

    -- Mehrere Slots → Dialog anzeigen
    local options = {}
    for _, slot in ipairs(availableSlots) do
        options[#options + 1] = {
            value = slot.id,
            label = locale('slot_label'):format(slot.id),
        }
    end

    local input = lib.inputDialog(locale('select_slot'), {
        {
            type = 'select',
            label = locale('select_slot'),
            description = locale('select_slot_desc'),
            options = options,
            required = true,
        }
    })

    if input and input[1] then
        LoadVehicleInSlot(targetVehicle, trailerEntity, tonumber(input[1]))
    end
end

-- Calculate Unload Position (hinter dem Anhänger, am Boden)
local function CalculateUnloadPosition(trailerEntity)
    local trailerCoords = GetEntityCoords(trailerEntity)
    local trailerHeading = GetEntityHeading(trailerEntity)

    -- Position: Hinter dem Anhänger
    local distance = Config.Global.UnloadDistance or 8.0
    local radians = math.rad(trailerHeading)
    local offsetY = -distance -- Hinter dem Anhänger

    local rotatedX = -offsetY * math.sin(radians)
    local rotatedY = offsetY * math.cos(radians)

    local unloadX = trailerCoords.x + rotatedX
    local unloadY = trailerCoords.y + rotatedY

    -- Ground Z finden (Bodenhöhe)
    local groundZ = trailerCoords.z
    local foundGround, zCoord = GetGroundZFor_3dCoord(unloadX, unloadY, trailerCoords.z + 5.0, false)
    if foundGround then
        groundZ = zCoord + 1.0 -- 1m über Boden für sauberes Drop
    end

    return vector3(unloadX, unloadY, groundZ), trailerHeading + 180.0 -- Schaut weg vom Anhänger
end

-- Unload Vehicle
local function UnloadVehicle(trailerEntity)
    local trailerNet = VehToNet(trailerEntity)

    -- Optional: Bestätigung anzeigen
    if Config.Global.ConfirmUnload then
        local confirmed = lib.alertDialog({
            header = locale('loader_title'),
            content = locale('confirm_unload'),
            centered = true,
            cancel = true,
            labels = {
                confirm = locale('confirm'),
                cancel = locale('cancel'),
            }
        })

        if confirmed ~= 'confirm' then return end
    end

    -- Get trailer ramp config
    local trailerConfig = GetTrailerConfigByEntity(trailerEntity)
    local rampConfig = trailerConfig and trailerConfig.ramp

    -- Rampe öffnen + Sound
    if rampConfig and rampConfig.enabled then
        Effects.StartUnloading(trailerEntity, rampConfig.doorIndex)
        Wait(rampConfig.openTime or 500)
    end

    -- Animation
    if Config.Global.EnableAnimations then
        lib.requestAnimDict('mini@repair', 5000)
        TaskPlayAnim(cache.ped, 'mini@repair', 'fixing_a_player', 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    -- Progress Bar
    if not Bridge.ProgressBar(locale('unloading_vehicle'), Config.Global.UnloadingTime or (Config.Global.LoadingTime / 2)) then
        Bridge.Notify(locale('loader_title'), locale('loading_cancelled'), 'error')
        ClearPedTasks(cache.ped)
        if rampConfig and rampConfig.enabled then
            Effects.CloseRamp(trailerEntity, rampConfig.doorIndex)
        end
        return
    end

    ClearPedTasks(cache.ped)
    TriggerServerEvent('vehicle_loader:unload', trailerNet)
end

-- ⭐ Statebag Listener: Vehicle attached (ersetzt syncLoad)
AddEventHandler('vehicle_loader:state:vehicleAttached', function(vehicle, vehicleNet, attachData)
    local trailerNet = attachData.trailerNet
    local slotId = attachData.slotId

    local trailer = NetworkGetEntityFromNetworkId(trailerNet)
    if not trailer or trailer == 0 then return end

    local slotConfig = GetSlotConfig(trailer, slotId)
    if not slotConfig then return end

    -- Nur attachen wenn nicht bereits attached
    if not IsEntityAttached(vehicle) then
        AttachVehicleToTrailer(vehicle, trailer, slotConfig)
    end

    LoadedVehicles[vehicleNet] = {
        trailerNet = trailerNet,
        slotId = slotId,
    }

    -- HOOK: Notify other resources
    TriggerEvent('vehicle_loader:client:onVehicleLoaded', vehicleNet, trailerNet, slotId)
end)

-- ⭐ Statebag Listener: Vehicle detached (ersetzt syncUnload)
AddEventHandler('vehicle_loader:state:vehicleDetached', function(vehicle, vehicleNet)
    local cachedData = LoadedVehicles[vehicleNet]
    if not cachedData then return end

    local trailerNet = cachedData.trailerNet
    local slotId = cachedData.slotId
    local trailer = NetworkGetEntityFromNetworkId(trailerNet)

    if vehicle and vehicle ~= 0 then
        -- ⭐ Network Ownership für Detach
        local hasControl = RequestNetworkOwnership(vehicle, 1500)
        if not hasControl then
            -- Wir können nicht detachen, anderer Client macht es
            LoadedVehicles[vehicleNet] = nil
            TriggerEvent('vehicle_loader:client:onVehicleUnloaded', vehicleNet, trailerNet, slotId)
            return
        end

        -- ⭐ Network ID Migration wieder erlauben (war beim Attach gesperrt)
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        if netId and netId ~= 0 then
            SetNetworkIdCanMigrate(netId, true)
        end

        -- Detach
        if IsEntityAttached(vehicle) then
            DetachEntity(vehicle, true, true)
        end

        -- ⭐ Collision wieder aktivieren (war beim Attach disabled)
        if trailer and trailer ~= 0 then
            SetEntityNoCollisionEntity(vehicle, trailer, true)
            SetEntityNoCollisionEntity(trailer, vehicle, true)
        end

        -- Berechne Unload-Position (hinter Anhänger, am Boden)
        if trailer and trailer ~= 0 and DoesEntityExist(trailer) then
            local unloadCoords, unloadHeading = CalculateUnloadPosition(trailer)

            SetEntityCoords(vehicle, unloadCoords.x, unloadCoords.y, unloadCoords.z, false, false, false, true)
            SetEntityHeading(vehicle, unloadHeading)
            SetVehicleOnGroundProperly(vehicle)
            FreezeEntityPosition(vehicle, false)
            SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)

            -- Effects
            local trailerConfig = GetTrailerConfigByEntity(trailer)
            local rampConfig = trailerConfig and trailerConfig.ramp
            local doorIndex = rampConfig and rampConfig.doorIndex or nil

            Effects.FinishUnloading(trailer, doorIndex, unloadCoords)
        end
    end

    LoadedVehicles[vehicleNet] = nil

    TriggerEvent('vehicle_loader:client:onVehicleUnloaded', vehicleNet, trailerNet, slotId)
end)

-- Initial Sync on Resource Start / Player Join
-- HINWEIS: Statebags syncen sich AUTOMATISCH für neue Spieler.
-- Dieser Block ist für Backwards-Compat falls Statebags noch nicht propagiert wurden.
CreateThread(function()
    Wait(2000) -- Wait for framework to initialize

    local loadedData = lib.callback.await('vehicle_loader:getLoaded', false)
    if not loadedData then return end

    for vehicleNet, data in pairs(loadedData) do
        local vehicle = NetworkGetEntityFromNetworkId(vehicleNet)
        local trailer = NetworkGetEntityFromNetworkId(data.trailerNet)

        if vehicle and vehicle ~= 0 and trailer and trailer ~= 0 then
            local slotConfig = GetSlotConfig(trailer, data.slotId)
            if slotConfig then
                AttachVehicleToTrailer(vehicle, trailer, slotConfig)
                LoadedVehicles[vehicleNet] = {
                    trailerNet = data.trailerNet,
                    slotId = data.slotId,
                }
            end
        end
    end
end)

-- ox_target Integration
CreateThread(function()
    Wait(1000)

    if GetResourceState('ox_target') ~= 'started' then
        print('^1[Vehicle Loader]^7 ox_target nicht gefunden!')
        return
    end

    -- Aufladen Option an Fahrzeugen
    exports.ox_target:addGlobalVehicle({
        {
            name = 'vehicle_loader_load',
            label = locale('target_load'),
            icon = 'fas fa-truck-loading',
            distance = 2.5,
            onSelect = function(data)
                LoadVehicle(data.entity)
            end,
            canInteract = function(entity)
                if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
                    return false
                end

                if IsValidFlatbed(entity) then
                    return false
                end

                local vehicleNet = VehToNet(entity)
                return not LoadedVehicles[vehicleNet]
            end
        }
    })

    -- Entladen Option an Anhängern
    exports.ox_target:addGlobalVehicle({
        {
            name = 'vehicle_loader_unload',
            label = locale('target_unload'),
            icon = 'fas fa-dolly',
            distance = 2.5,
            onSelect = function(data)
                UnloadVehicle(data.entity)
            end,
            canInteract = function(entity)
                if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
                    return false
                end

                if not IsValidFlatbed(entity) then
                    return false
                end

                local trailerNet = VehToNet(entity)
                for _, data in pairs(LoadedVehicles) do
                    if data.trailerNet == trailerNet then
                        return true
                    end
                end

                return false
            end
        }
    })

    -- Rampe öffnen / schließen (manuell)
    exports.ox_target:addGlobalVehicle({
        {
            name = 'vehicle_loader_ramp_open',
            label = locale('ramp_open'),
            icon = 'fas fa-arrow-up-from-bracket',
            distance = 2.5,
            onSelect = function(data)
                local trailerConfig = GetTrailerConfigByEntity(data.entity)
                local rampConfig = trailerConfig and trailerConfig.ramp

                if rampConfig and rampConfig.enabled then
                    Effects.OpenRamp(data.entity, rampConfig.doorIndex)
                    Bridge.Notify(locale('loader_title'), locale('ramp_opened'), 'info')
                end
            end,
            canInteract = function(entity)
                if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
                    return false
                end

                if not IsValidFlatbed(entity) then
                    return false
                end

                local trailerConfig = GetTrailerConfigByEntity(entity)
                local rampConfig = trailerConfig and trailerConfig.ramp

                if not rampConfig or not rampConfig.enabled then
                    return false
                end

                -- Nur zeigen wenn Rampe GESCHLOSSEN ist
                local doorIndex = rampConfig.doorIndex or 5
                local doorState = GetVehicleDoorAngleRatio(entity, doorIndex)
                return doorState < 0.1 -- Door fast komplett zu
            end
        },
        {
            name = 'vehicle_loader_ramp_close',
            label = locale('ramp_close'),
            icon = 'fas fa-arrow-down-to-bracket',
            distance = 2.5,
            onSelect = function(data)
                local trailerConfig = GetTrailerConfigByEntity(data.entity)
                local rampConfig = trailerConfig and trailerConfig.ramp

                if rampConfig and rampConfig.enabled then
                    Effects.CloseRamp(data.entity, rampConfig.doorIndex)
                    Bridge.Notify(locale('loader_title'), locale('ramp_closed'), 'info')
                end
            end,
            canInteract = function(entity)
                if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
                    return false
                end

                if not IsValidFlatbed(entity) then
                    return false
                end

                local trailerConfig = GetTrailerConfigByEntity(entity)
                local rampConfig = trailerConfig and trailerConfig.ramp

                if not rampConfig or not rampConfig.enabled then
                    return false
                end

                -- Nur zeigen wenn Rampe OFFEN ist
                local doorIndex = rampConfig.doorIndex or 5
                local doorState = GetVehicleDoorAngleRatio(entity, doorIndex)
                return doorState > 0.1 -- Door zumindest etwas offen
            end
        }
    })
end)

-- Exports
exports('IsVehicleLoaded', function(vehicleNet)
    return LoadedVehicles[vehicleNet] ~= nil
end)

exports('GetLoadedVehicles', function()
    return LoadedVehicles
end)

-- Debug Info
RegisterCommand('loaderinfo', function()
    print('^2[Loader]^7 ' .. json.encode(LoadedVehicles, {indent = true}))
end, false)

lib.print.info('^7[Vehicle Loader]^7 Client v3.4 geladen!')
