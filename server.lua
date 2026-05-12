-- Vehicle Loader System - Server (v3.4)
-- Framework-agnostic with Security, Rate Limiting, Statebags, Restrictions & Anti-Theft

local LoadedVehicles = {}      -- vehicleNet -> LoadedVehicleData
local SlotLocks = {}           -- "trailerNet:slotId" -> SlotLock
local LOCK_TIMEOUT = 15000     -- ms bis Slot-Lock auto-expired

-- Structured Logger (ox_lib)
---@param level 'info'|'warn'|'error'|'debug'
---@param message string
---@param ... any
local function Log(level, message, ...)
    if select('#', ...) > 0 then
        message = message:format(...)
    end
    lib.print[level]('^7[Loader]^7 ' .. message)
end

-- ============================================================
-- INTERNAL API (für api/server.lua zugänglich)
-- ============================================================

function GetAllLoadedVehicles()
    return LoadedVehicles
end

function GetLoadedVehicleData(vehicleNet)
    return LoadedVehicles[vehicleNet]
end

-- ============================================================
-- HELPERS
-- ============================================================

local function CountVehiclesOnTrailer(trailerNet)
    local count = 0
    for _, data in pairs(LoadedVehicles) do
        if data.trailerNet == trailerNet then
            count = count + 1
        end
    end
    return count
end

local function GetMaxVehiclesForTrailerNet(trailerNet)
    local entity = NetworkGetEntityFromNetworkId(trailerNet)
    if not entity or entity == 0 then return 1 end

    local model = GetEntityModel(entity)
    for _, trailer in ipairs(Config.Trailers) do
        if GetHashKey(trailer.model) == model then
            return trailer.maxVehicles
        end
    end

    return 1
end

local function IsSlotOccupied(trailerNet, slotId)
    for _, data in pairs(LoadedVehicles) do
        if data.trailerNet == trailerNet and data.slotId == slotId then
            return true
        end
    end
    return false
end

local function IsVehicleLoaded(vehicleNet)
    return LoadedVehicles[vehicleNet] ~= nil
end

-- ============================================================
-- SLOT LOCKING (Race-Condition Prevention)
-- ============================================================

local function GetLockKey(trailerNet, slotId)
    return ('%d:%d'):format(trailerNet, slotId)
end

-- Versucht Slot zu locken (atomar)
local function TryLockSlot(trailerNet, slotId, source)
    local key = GetLockKey(trailerNet, slotId)

    -- Bereits gelocked? (von wem auch immer)
    if SlotLocks[key] then
        return false
    end

    SlotLocks[key] = {
        source = source,
        lockedAt = GetGameTimer(),
    }

    -- Auto-Release nach Timeout
    SetTimeout(LOCK_TIMEOUT, function()
        if SlotLocks[key] and SlotLocks[key].source == source then
            SlotLocks[key] = nil
        end
    end)

    return true
end

local function ReleaseSlotLock(trailerNet, slotId)
    SlotLocks[GetLockKey(trailerNet, slotId)] = nil
end

local function IsSlotLocked(trailerNet, slotId)
    return SlotLocks[GetLockKey(trailerNet, slotId)] ~= nil
end

local function HasJobPermission(source)
    if not Config.Jobs or not next(Config.Jobs) then
        return true
    end

    local playerJob = Bridge.GetJob(source)
    return playerJob and Config.Jobs[playerJob] == true
end

-- ============================================================
-- INTERNAL LOAD/UNLOAD (auch für API genutzt)
-- ============================================================

function ForceLoadVehicleInternal(vehicleNet, trailerNet, slotId, source)
    if IsVehicleLoaded(vehicleNet) then return false, 'already_loaded' end
    if IsSlotOccupied(trailerNet, slotId) then return false, 'slot_occupied' end

    -- Get entities
    local vehicleEntity = NetworkGetEntityFromNetworkId(vehicleNet)
    local trailerEntity = NetworkGetEntityFromNetworkId(trailerNet)

    if not vehicleEntity or vehicleEntity == 0 then return false, 'invalid_vehicle' end
    if not trailerEntity or trailerEntity == 0 then return false, 'invalid_trailer' end

    -- Update internal tracking
    LoadedVehicles[vehicleNet] = {
        trailerNet = trailerNet,
        slotId = slotId,
        owner = source or 0,
        loadedAt = os.time(),
    }

    -- ⭐ Statebag-based Sync (automatic via FiveM)
    -- source mitgeben damit nur der Loader Client das Attach ausführt
    StatebagAPI.OccupySlot(trailerEntity, slotId, vehicleNet)
    StatebagAPI.AttachVehicleState(vehicleEntity, trailerNet, slotId, source)

    -- Slot-Lock freigeben (Loading abgeschlossen)
    ReleaseSlotLock(trailerNet, slotId)

    -- Persist to storage (if enabled)
    PersistVehicleLoaded(vehicleNet, trailerNet, slotId, source)

    -- HOOK: Notify other resources
    TriggerEvent('vehicle_loader:server:onVehicleLoaded', vehicleNet, trailerNet, slotId, source)

    return true
end

function ForceUnloadVehicleInternal(vehicleNet)
    local data = LoadedVehicles[vehicleNet]
    if not data then return false, 'not_loaded' end

    local trailerNet = data.trailerNet
    local slotId = data.slotId
    local owner = data.owner

    -- Get entities
    local vehicleEntity = NetworkGetEntityFromNetworkId(vehicleNet)
    local trailerEntity = NetworkGetEntityFromNetworkId(trailerNet)

    LoadedVehicles[vehicleNet] = nil

    -- ⭐ Statebag-based Sync
    if trailerEntity and trailerEntity ~= 0 then
        StatebagAPI.ReleaseSlot(trailerEntity, slotId)
    end

    if vehicleEntity and vehicleEntity ~= 0 then
        StatebagAPI.DetachVehicleState(vehicleEntity)
    end

    -- Remove from storage (if enabled)
    PersistVehicleUnloaded(vehicleNet)

    -- HOOK: Notify other resources
    TriggerEvent('vehicle_loader:server:onVehicleUnloaded', vehicleNet, trailerNet, slotId, owner)

    return true
end

-- ============================================================
-- PERSISTENCE RESTORE
-- ============================================================
-- Wird gefeuert wenn Storage Daten geladen hat
AddEventHandler('vehicle_loader:storage:dataReady', function(persistedData)
    CreateThread(function()
        Wait(Config.Storage.RestoreDelay or 5000)

        local restored = 0
        local skipped = 0

        for vehiclePlate, data in pairs(persistedData) do
            -- Finde Fahrzeug & Anhänger per Plate
            local vehicleEntity, trailerEntity = nil, nil
            local vehicles = GetAllVehicles()

            for _, veh in ipairs(vehicles) do
                local plate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
                if plate == vehiclePlate then
                    vehicleEntity = veh
                elseif plate == data.trailerPlate then
                    trailerEntity = veh
                end

                if vehicleEntity and trailerEntity then break end
            end

            if vehicleEntity and trailerEntity then
                local vehicleNet = NetworkGetNetworkIdFromEntity(vehicleEntity)
                local trailerNet = NetworkGetNetworkIdFromEntity(trailerEntity)

                if ForceLoadVehicleInternal(vehicleNet, trailerNet, data.slotId, data.owner) then
                    restored = restored + 1
                end
            else
                skipped = skipped + 1
                -- Cleanup: Wenn Fahrzeug nicht existiert, aus DB entfernen
                if not vehicleEntity then
                    PersistVehicleUnloaded(vehiclePlate)
                end
            end
        end

        if restored > 0 or skipped > 0 then
            Log('info', 'Persistence Restore: %d wiederhergestellt, %d übersprungen', restored, skipped)
        end
    end)
end)

-- ============================================================
-- CALLBACKS (Client → Server)
-- ============================================================

lib.callback.register('vehicle_loader:validateLoad', function(source, vehicleNet, trailerNet, slotId)
    -- ⭐ Security Check (Rate Limit, Distance, Routing Bucket)
    local valid, reason = Security.ValidateLoadAction(source, vehicleNet, trailerNet)
    if not valid then
        Log('warn', 'Security blocked load from %d: %s', source, reason)
        if reason == 'rate_limit' then
            Bridge.Notify(source, 'Loader', 'Bitte etwas langsamer!', 'error')
        else
            Bridge.Notify(source, 'Loader', 'Validierung fehlgeschlagen!', 'error')
        end
        return false
    end

    -- Argument validation
    if type(slotId) ~= 'number' or slotId < 1 then
        Log('warn', 'Invalid slotId from %d: %s', source, tostring(slotId))
        return false
    end

    -- HOOK: Pre-Load Check (andere Resources können blockieren)
    local cancel = false
    local cancelReason = nil

    TriggerEvent('vehicle_loader:server:onBeforeLoad', source, vehicleNet, trailerNet, slotId, function(block, reason)
        if block then
            cancel = true
            cancelReason = reason
        end
    end)

    if cancel then
        Bridge.Notify(source, 'Loader', cancelReason or 'Aktion blockiert!', 'error')
        return false
    end

    -- Job Check
    if not HasJobPermission(source) then
        Bridge.Notify(source, 'Loader', 'Du hast keine Berechtigung!', 'error')
        return false
    end

    -- Bereits geladen?
    if IsVehicleLoaded(vehicleNet) then
        Bridge.Notify(source, 'Loader', 'Fahrzeug ist bereits geladen!', 'error')
        return false
    end

    -- Slot belegt?
    if IsSlotOccupied(trailerNet, slotId) then
        Bridge.Notify(source, 'Loader', 'Slot ist bereits belegt!', 'error')
        return false
    end

    -- Slot Lock Check (Race-Condition Prevention)
    if IsSlotLocked(trailerNet, slotId) then
        Bridge.Notify(source, 'Loader', 'Slot wird gerade von jemandem genutzt!', 'error')
        return false
    end

    -- Trailer voll?
    if CountVehiclesOnTrailer(trailerNet) >= GetMaxVehiclesForTrailerNet(trailerNet) then
        Bridge.Notify(source, 'Loader', 'Anhänger ist voll!', 'error')
        return false
    end

    -- ⭐ Server-Side Vehicle Type Check (basis - GetVehicleClass ist client-only)
    -- Detaillierter Class-Check passiert client-side BEVOR der Callback überhaupt gefeuert wird
    local vehicleEntity = Security.GetValidEntityFromNetId(vehicleNet)

    if vehicleEntity then
        local vehType = GetVehicleType(vehicleEntity)
        if Restrictions.IsTypeBlockedServerSide(vehType) then
            Log('warn', 'Vehicle Type Restriction blocked: %s (type: %s)', source, vehType)
            Bridge.Notify(source, 'Loader', 'Dieser Fahrzeugtyp ist nicht erlaubt!', 'error')
            return false
        end
    end

    -- Items check (VOR Slot-Lock!)
    for itemName, amount in pairs(Config.RequiredItems) do
        if not Bridge.HasItem(source, itemName, amount) then
            Bridge.Notify(source, 'Loader', ('Du brauchst %dx %s!'):format(amount, itemName), 'error')
            return false
        end
    end

    -- Geld check (VOR Slot-Lock!)
    if Config.Global.MoneyRequired > 0 then
        if Bridge.GetMoney(source, Config.Global.MoneyAccount or 'cash') < Config.Global.MoneyRequired then
            Bridge.Notify(source, 'Loader', 'Du hast nicht genug Geld!', 'error')
            return false
        end
    end

    -- Lock the slot for this player (als ALLERLETZTES, alle Checks bestanden!)
    if not TryLockSlot(trailerNet, slotId, source) then
        Bridge.Notify(source, 'Loader', 'Slot wird gerade reserviert!', 'error')
        return false
    end

    return true
end)

-- Initial Sync für neue Spieler (Statebags machen das eigentlich automatisch,
-- aber wir behalten den Callback für Backwards-Compat)
lib.callback.register('vehicle_loader:getLoaded', function(source)
    return LoadedVehicles
end)

-- ============================================================
-- CLEANUP: Player Disconnect
-- ============================================================
AddEventHandler('playerDropped', function()
    local source = source

    -- Release Slot Locks die dieser Spieler hatte
    for key, lock in pairs(SlotLocks) do
        if lock.source == source then
            SlotLocks[key] = nil
        end
    end
end)

-- ============================================================
-- CLEANUP: Entity Despawn
-- ============================================================
-- WICHTIG: Plate wird VORHER aus der Entity gelesen, da bei entityRemoved
-- die Entity nicht mehr verfügbar ist
AddEventHandler('entityRemoved', function(entity)
    if not entity or entity == 0 then return end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then return end

    -- Wenn ein geladenes Fahrzeug despawnt
    if LoadedVehicles[netId] then
        local data = LoadedVehicles[netId]

        -- Plate VORHER capturen (solange Entity noch da)
        local vehiclePlate = nil
        if DoesEntityExist(entity) then
            vehiclePlate = GetVehicleNumberPlateText(entity):gsub('%s+', '')
        end

        -- Trailer Slot freigeben
        local trailerEntity = NetworkGetEntityFromNetworkId(data.trailerNet)
        if trailerEntity and trailerEntity ~= 0 then
            StatebagAPI.ReleaseSlot(trailerEntity, data.slotId)
        end

        LoadedVehicles[netId] = nil

        -- Persistence Cleanup mit Plate (nicht NetId!)
        if vehiclePlate and Storage and Storage.Ready then
            Storage.RemoveVehicle(vehiclePlate)
        end

        Log('debug', 'Cleanup: Vehicle %d despawnt, State entfernt', netId)
    end

    -- Wenn ein Trailer mit geladenen Vehicles despawnt
    for vehicleNet, data in pairs(LoadedVehicles) do
        if data.trailerNet == netId then
            -- Plate vom Vehicle capturen (nicht vom Trailer!)
            local vehEntity = NetworkGetEntityFromNetworkId(vehicleNet)
            local vehPlate = nil
            if vehEntity and vehEntity ~= 0 then
                vehPlate = GetVehicleNumberPlateText(vehEntity):gsub('%s+', '')
                StatebagAPI.DetachVehicleState(vehEntity)
            end

            LoadedVehicles[vehicleNet] = nil

            if vehPlate and Storage and Storage.Ready then
                Storage.RemoveVehicle(vehPlate)
            end
        end
    end
end)

-- ============================================================
-- EVENTS (Client → Server)
-- ============================================================

-- Aufladen abschließen
RegisterNetEvent('vehicle_loader:load', function(vehicleNet, trailerNet, slotId)
    local source = source

    -- Re-validate (Slot kann zwischenzeitlich belegt worden sein)
    if IsVehicleLoaded(vehicleNet) or IsSlotOccupied(trailerNet, slotId) then
        Bridge.Notify(source, 'Loader', 'Validierung fehlgeschlagen!', 'error')
        ReleaseSlotLock(trailerNet, slotId)
        return
    end

    -- Items check vor Removal (double-check)
    for itemName, amount in pairs(Config.RequiredItems) do
        if not Bridge.HasItem(source, itemName, amount) then
            Bridge.Notify(source, 'Loader', 'Items fehlen!', 'error')
            ReleaseSlotLock(trailerNet, slotId)
            return
        end
    end

    -- Items entfernen
    for itemName, amount in pairs(Config.RequiredItems) do
        Bridge.RemoveItem(source, itemName, amount)
    end

    -- Geld entfernen
    if Config.Global.MoneyRequired > 0 then
        Bridge.RemoveMoney(source, Config.Global.MoneyRequired, Config.Global.MoneyAccount or 'cash')
    end

    -- Load via internal function (Lock wird in ForceLoadVehicleInternal released)
    if ForceLoadVehicleInternal(vehicleNet, trailerNet, slotId, source) then
        Bridge.Notify(source, 'Loader', 'Fahrzeug erfolgreich aufgeladen!', 'success')

        Log('info', '%s (%d) hat Fahrzeug %d in Slot %d aufgeladen',
            Bridge.GetName(source), source, vehicleNet, slotId
        )
    else
        -- Bei Fehler: Items + Geld zurückgeben
        for itemName, amount in pairs(Config.RequiredItems) do
            Bridge.AddItem(source, itemName, amount)
        end

        if Config.Global.MoneyRequired > 0 then
            Bridge.AddMoney(source, Config.Global.MoneyRequired, Config.Global.MoneyAccount or 'cash')
        end

        ReleaseSlotLock(trailerNet, slotId)
    end
end)

-- Event: Loading abgebrochen → Lock freigeben
RegisterNetEvent('vehicle_loader:releaseLock', function(trailerNet, slotId)
    local source = source
    local lock = SlotLocks[GetLockKey(trailerNet, slotId)]

    -- Nur der Owner kann den Lock freigeben
    if lock and lock.source == source then
        ReleaseSlotLock(trailerNet, slotId)
    end
end)

-- Entladen
RegisterNetEvent('vehicle_loader:unload', function(trailerNet)
    local source = source

    -- ⭐ Security Check
    local valid, reason = Security.ValidateUnloadAction(source, trailerNet)
    if not valid then
        Log('warn', 'Security blocked unload from %d: %s', source, reason)
        Bridge.Notify(source, 'Loader', 'Validierung fehlgeschlagen!', 'error')
        return
    end

    if not HasJobPermission(source) then
        Bridge.Notify(source, 'Loader', 'Du hast keine Berechtigung!', 'error')
        return
    end

    local foundVehicleNet = nil
    local foundData = nil
    for vehicleNet, data in pairs(LoadedVehicles) do
        if data.trailerNet == trailerNet then
            foundVehicleNet = vehicleNet
            foundData = data
            break
        end
    end

    if not foundVehicleNet then
        Bridge.Notify(source, 'Loader', 'Kein Fahrzeug zum Entladen!', 'error')
        return
    end

    -- ⭐ Anti-Theft Check
    if Config.Global.OwnerOnlyUnload and foundData.owner ~= 0 then
        local isOwner = foundData.owner == source
        local isJobMate = false
        local isAdmin = false

        -- Job-Kollegen Check
        if not isOwner and Config.Global.AllowJobUnload then
            local sourceJob = Bridge.GetJob(source)
            local ownerJob = Bridge.GetJob(foundData.owner)
            if sourceJob and sourceJob == ownerJob then
                isJobMate = true
            end
        end

        -- Admin Check (ACE + txAdmin + Framework)
        if not isOwner and not isJobMate and Config.Global.AllowAdminUnload then
            isAdmin = Bridge.IsAdmin(source)
        end

        if not isOwner and not isJobMate and not isAdmin then
            Log('warn', 'Anti-Theft blocked unload from %d (owner: %d)', source, foundData.owner)
            Bridge.Notify(source, 'Loader', 'Du kannst nur deine eigenen Fahrzeuge entladen!', 'error')
            return
        end
    end

    -- HOOK: Pre-Unload Check
    local cancel = false
    local cancelReason = nil
    TriggerEvent('vehicle_loader:server:onBeforeUnload', source, foundVehicleNet, trailerNet, function(block, reason)
        if block then
            cancel = true
            cancelReason = reason
        end
    end)

    if cancel then
        Bridge.Notify(source, 'Loader', cancelReason or 'Aktion blockiert!', 'error')
        return
    end

    -- Items zurückgeben (optional)
    if Config.Global.RefundItemsOnUnload then
        for itemName, amount in pairs(Config.RequiredItems) do
            Bridge.AddItem(source, itemName, amount)
        end
    end

    if ForceUnloadVehicleInternal(foundVehicleNet) then
        Bridge.Notify(source, 'Loader', 'Fahrzeug erfolgreich entladen!', 'success')

        Log('info', '%s (%d) hat Fahrzeug %d entladen',
            Bridge.GetName(source), source, foundVehicleNet
        )
    end
end)

-- ============================================================
-- ADMIN COMMANDS
-- ============================================================

lib.addCommand('loaderstatus', {
    help = 'Vehicle Loader Status anzeigen',
    restricted = 'group.admin',
}, function(source)
    local count = 0
    for _ in pairs(LoadedVehicles) do count = count + 1 end

    Bridge.Notify(source, 'Loader Status', ('Geladene Fahrzeuge: %d'):format(count), 'info')
    Log('info', 'Status: %d geladene Fahrzeuge', count)
    Log('debug', 'Details: %s', json.encode(LoadedVehicles, {indent = true}))
end)

lib.addCommand('forceunloadall', {
    help = 'Alle geladenen Fahrzeuge entladen',
    restricted = 'group.admin',
}, function(source)
    local count = 0
    local toUnload = {}

    for vehicleNet in pairs(LoadedVehicles) do
        toUnload[#toUnload + 1] = vehicleNet
    end

    for _, vehicleNet in ipairs(toUnload) do
        if ForceUnloadVehicleInternal(vehicleNet) then
            count = count + 1
        end
    end

    Bridge.Notify(source, 'Loader', ('%d Fahrzeuge entladen'):format(count), 'success')
end)

Log('info', 'Server v3.4 geladen (Statebags + Security + Restrictions + Anti-Theft)')
