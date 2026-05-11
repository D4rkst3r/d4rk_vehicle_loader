-- Vehicle Loader Storage Adapter
-- Flexibel: Built-in DB, External Override, oder Disabled

Storage = {
    Provider = 'none', -- 'oxmysql', 'external', 'none'
    Ready = false,
}

-- ============================================================
-- STORAGE INTERFACE (abstract)
-- ============================================================

-- Standardimplementierungen werden überschrieben
Storage.SaveVehicle = function(vehicleNet, data) end
Storage.RemoveVehicle = function(vehicleNet) end
Storage.LoadAll = function() return {} end
Storage.Clear = function() end

-- ============================================================
-- BUILT-IN: oxmysql Provider
-- ============================================================

local function InitOxMySQL()
    if GetResourceState('oxmysql') ~= 'started' then
        return false
    end

    -- Defensive Check: MySQL Global muss verfügbar sein
    if not MySQL or not MySQL.query then
        lib.print.warn('[Vehicle Loader Storage] MySQL Global nicht verfügbar! Stelle sicher dass oxmysql geladen ist.')
        return false
    end

    -- Create table if not exists
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vehicle_loader_loaded` (
            `vehicle_plate` VARCHAR(16) NOT NULL,
            `trailer_plate` VARCHAR(16) NOT NULL,
            `slot_id` INT NOT NULL,
            `owner_id` INT DEFAULT 0,
            `loaded_at` BIGINT NOT NULL,
            PRIMARY KEY (`vehicle_plate`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    -- Override Storage Interface
    Storage.SaveVehicle = function(vehiclePlate, data)
        if not vehiclePlate or vehiclePlate == '' then return false end

        MySQL.prepare.await([[
            INSERT INTO vehicle_loader_loaded
                (vehicle_plate, trailer_plate, slot_id, owner_id, loaded_at)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                trailer_plate = VALUES(trailer_plate),
                slot_id = VALUES(slot_id),
                owner_id = VALUES(owner_id),
                loaded_at = VALUES(loaded_at)
        ]], {
            vehiclePlate,
            data.trailerPlate,
            data.slotId,
            data.owner or 0,
            data.loadedAt
        })

        return true
    end

    Storage.RemoveVehicle = function(vehiclePlate)
        if not vehiclePlate or vehiclePlate == '' then return false end
        MySQL.prepare.await('DELETE FROM vehicle_loader_loaded WHERE vehicle_plate = ?', {vehiclePlate})
        return true
    end

    Storage.LoadAll = function()
        local results = MySQL.query.await('SELECT * FROM vehicle_loader_loaded') or {}
        local loaded = {}

        for _, row in ipairs(results) do
            loaded[row.vehicle_plate] = {
                trailerPlate = row.trailer_plate,
                slotId = row.slot_id,
                owner = row.owner_id,
                loadedAt = row.loaded_at,
            }
        end

        return loaded
    end

    Storage.Clear = function()
        MySQL.query.await('DELETE FROM vehicle_loader_loaded')
    end

    Storage.Provider = 'oxmysql'
    Storage.Ready = true
    return true
end

-- ============================================================
-- EXTERNAL: Override durch andere Resources
-- ============================================================

-- Andere Resources können diese Exports nutzen um Storage zu übernehmen:
exports('SetStorageProvider', function(providerInterface)
    if providerInterface.SaveVehicle then Storage.SaveVehicle = providerInterface.SaveVehicle end
    if providerInterface.RemoveVehicle then Storage.RemoveVehicle = providerInterface.RemoveVehicle end
    if providerInterface.LoadAll then Storage.LoadAll = providerInterface.LoadAll end
    if providerInterface.Clear then Storage.Clear = providerInterface.Clear end

    Storage.Provider = 'external'
    Storage.Ready = true

    lib.print.info('[Vehicle Loader Storage] External Provider registriert!')
end)

-- ============================================================
-- INITIALIZATION
-- ============================================================

CreateThread(function()
    Wait(1000) -- Wait for other resources

    if not Config.Storage or not Config.Storage.Enabled then
        Storage.Provider = 'none'
        Storage.Ready = false
        lib.print.info('[Vehicle Loader Storage] Persistence DEAKTIVIERT (Config.Storage.Enabled = false)')
        return
    end

    -- Wenn schon extern gesetzt, nichts tun
    if Storage.Provider == 'external' then
        lib.print.info('[Vehicle Loader Storage] Verwende externen Provider')
        return
    end

    -- Versuche built-in oxmysql
    if Config.Storage.Provider == 'oxmysql' or Config.Storage.Provider == 'auto' then
        if InitOxMySQL() then
            lib.print.info('[Vehicle Loader Storage] oxmysql Provider initialisiert')
            return
        end
    end

    lib.print.warn('[Vehicle Loader Storage] Kein Storage Provider verfügbar - Persistence deaktiviert')
end)

-- ============================================================
-- AUTO-SAVE / AUTO-LOAD HELPER
-- ============================================================

-- Hilfsfunktion: Plate von vehicleNet bekommen
function GetVehiclePlateFromNet(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 then return nil end
    return GetVehicleNumberPlateText(entity):gsub('%s+', '')
end

-- Save Hook: Wird vom server.lua getriggert
function PersistVehicleLoaded(vehicleNet, trailerNet, slotId, owner)
    if not Storage.Ready then return end

    local vehiclePlate = GetVehiclePlateFromNet(vehicleNet)
    local trailerPlate = GetVehiclePlateFromNet(trailerNet)

    if not vehiclePlate or not trailerPlate then return end

    Storage.SaveVehicle(vehiclePlate, {
        trailerPlate = trailerPlate,
        slotId = slotId,
        owner = owner or 0,
        loadedAt = os.time(),
    })
end

function PersistVehicleUnloaded(vehicleNet)
    if not Storage.Ready then return end

    local vehiclePlate = GetVehiclePlateFromNet(vehicleNet)
    if not vehiclePlate then return end

    Storage.RemoveVehicle(vehiclePlate)
end

-- ============================================================
-- RESTORE ON RESOURCE START
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(3000) -- Wait for storage to init

        if not Storage.Ready then return end

        local persistedData = Storage.LoadAll()
        local count = 0
        for _ in pairs(persistedData) do count = count + 1 end

        if count > 0 then
            lib.print.info(('[Vehicle Loader Storage] %d gespeicherte Loadings gefunden'):format(count))
            -- Restore wird vom main server.lua gehandhabt (siehe TryRestorePersistedVehicles)
            TriggerEvent('vehicle_loader:storage:dataReady', persistedData)
        end
    end)
end)

-- ============================================================
-- ADMIN COMMANDS
-- ============================================================

lib.addCommand('loaderstorageclear', {
    help = 'Storage Datenbank leeren',
    restricted = 'group.admin',
}, function(source)
    if not Storage.Ready then
        Bridge.Notify(source, 'Storage', 'Storage nicht aktiv', 'error')
        return
    end

    Storage.Clear()
    Bridge.Notify(source, 'Storage', 'Datenbank geleert!', 'success')
end)

lib.addCommand('loaderstorageinfo', {
    help = 'Storage Info anzeigen',
    restricted = 'group.admin',
}, function(source)
    Bridge.Notify(source, 'Storage', ('Provider: %s | Ready: %s'):format(Storage.Provider, tostring(Storage.Ready)), 'info')
end)

-- Export für andere Resources um Storage Info zu prüfen
exports('GetStorageInfo', function()
    return {
        Provider = Storage.Provider,
        Ready = Storage.Ready,
        Enabled = Config.Storage and Config.Storage.Enabled or false,
    }
end)

lib.print.info('[Vehicle Loader Storage] Storage Adapter geladen')
