-- Framework Bridge - Server Side
-- Auto-detect ESX / QBox / QBCore / Standalone
-- QBox wird PRIORITÄR geprüft (vor QBCore, da Compat-Layer parallel laufen kann)

Bridge = {}
Framework = nil
FrameworkName = 'standalone'

-- Auto-Detection (Reihenfolge ist wichtig!)
CreateThread(function()
    -- QBox FIRST (oft mit qb-core Compat-Layer)
    if GetResourceState('qbx_core') == 'started' then
        FrameworkName = 'qbox'
        print('^2[Vehicle Loader]^7 Framework: QBox (qbx_core)')

    -- ESX
    elseif GetResourceState('es_extended') == 'started' then
        Framework = exports['es_extended']:getSharedObject()
        FrameworkName = 'esx'
        print('^2[Vehicle Loader]^7 Framework: ESX')

    -- QBCore (Legacy)
    elseif GetResourceState('qb-core') == 'started' then
        Framework = exports['qb-core']:GetCoreObject()
        FrameworkName = 'qbcore'
        print('^2[Vehicle Loader]^7 Framework: QBCore')

    else
        FrameworkName = 'standalone'
        print('^2[Vehicle Loader]^7 Framework: Standalone (ox_inventory only)')
    end
end)

-- ============================================================
-- PLAYER API
-- ============================================================

-- Get Player Object
function Bridge.GetPlayer(source)
    if FrameworkName == 'qbox' then
        return exports.qbx_core:GetPlayer(source)
    elseif FrameworkName == 'esx' then
        return Framework.GetPlayerFromId(source)
    elseif FrameworkName == 'qbcore' then
        return Framework.Functions.GetPlayer(source)
    else
        return {source = source}
    end
end

-- Get Player Money
function Bridge.GetMoney(source, moneyType)
    moneyType = moneyType or 'cash'

    if FrameworkName == 'qbox' then
        -- QBox: Modern statebag-friendly approach
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return 0 end
        return player.PlayerData.money[moneyType] or 0

    elseif FrameworkName == 'esx' then
        local player = Framework.GetPlayerFromId(source)
        if not player then return 0 end
        if moneyType == 'bank' then
            return player.getAccount('bank').money
        else
            return player.getMoney()
        end

    elseif FrameworkName == 'qbcore' then
        local player = Framework.Functions.GetPlayer(source)
        if not player then return 0 end
        return player.PlayerData.money[moneyType] or 0
    end

    return 0
end

-- Remove Money
function Bridge.RemoveMoney(source, amount, moneyType)
    moneyType = moneyType or 'cash'

    if FrameworkName == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return false end
        player.Functions.RemoveMoney(moneyType, amount, 'vehicle_loader')
        return true

    elseif FrameworkName == 'esx' then
        local player = Framework.GetPlayerFromId(source)
        if not player then return false end
        if moneyType == 'bank' then
            player.removeAccountMoney('bank', amount)
        else
            player.removeMoney(amount)
        end
        return true

    elseif FrameworkName == 'qbcore' then
        local player = Framework.Functions.GetPlayer(source)
        if not player then return false end
        player.Functions.RemoveMoney(moneyType, amount, 'vehicle_loader')
        return true
    end

    return false
end

-- Add Money
function Bridge.AddMoney(source, amount, moneyType)
    moneyType = moneyType or 'cash'

    if FrameworkName == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return false end
        player.Functions.AddMoney(moneyType, amount, 'vehicle_loader')
        return true

    elseif FrameworkName == 'esx' then
        local player = Framework.GetPlayerFromId(source)
        if not player then return false end
        if moneyType == 'bank' then
            player.addAccountMoney('bank', amount)
        else
            player.addMoney(amount)
        end
        return true

    elseif FrameworkName == 'qbcore' then
        local player = Framework.Functions.GetPlayer(source)
        if not player then return false end
        player.Functions.AddMoney(moneyType, amount, 'vehicle_loader')
        return true
    end

    return false
end

-- Get Player Job
function Bridge.GetJob(source)
    if FrameworkName == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData.job and player.PlayerData.job.name or nil

    elseif FrameworkName == 'esx' then
        local player = Framework.GetPlayerFromId(source)
        return player and player.job and player.job.name or nil

    elseif FrameworkName == 'qbcore' then
        local player = Framework.Functions.GetPlayer(source)
        return player and player.PlayerData.job and player.PlayerData.job.name or nil
    end

    return nil
end

-- Get Player Job Grade
function Bridge.GetJobGrade(source)
    if FrameworkName == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData.job and player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0

    elseif FrameworkName == 'esx' then
        local player = Framework.GetPlayerFromId(source)
        return player and player.job and player.job.grade or 0

    elseif FrameworkName == 'qbcore' then
        local player = Framework.Functions.GetPlayer(source)
        return player and player.PlayerData.job and player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0
    end

    return 0
end

-- Get Player Name
function Bridge.GetName(source)
    if FrameworkName == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        if player and player.PlayerData.charinfo then
            return ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
        end

    elseif FrameworkName == 'esx' then
        local player = Framework.GetPlayerFromId(source)
        if player then return player.getName() end

    elseif FrameworkName == 'qbcore' then
        local player = Framework.Functions.GetPlayer(source)
        if player and player.PlayerData.charinfo then
            return ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
        end
    end

    return GetPlayerName(source) or 'Unknown'
end

-- Get Player Identifier (eindeutige ID, framework-spezifisch)
function Bridge.GetIdentifier(source)
    if FrameworkName == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData.citizenid or nil

    elseif FrameworkName == 'esx' then
        local player = Framework.GetPlayerFromId(source)
        return player and player.identifier or nil

    elseif FrameworkName == 'qbcore' then
        local player = Framework.Functions.GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    end

    return GetPlayerIdentifier(source, 0)
end

-- ============================================================
-- ADMIN CHECK (ACE + txAdmin + Framework)
-- ============================================================
-- Unterstützt:
--   - ACE Permissions (FiveM Standard)
--   - txAdmin (über ACE automatisch)
--   - ESX (xPlayer.getGroup() == 'admin')
--   - QBox / QBCore (PlayerData.metadata.admin)
--
---@param source number
---@return boolean
function Bridge.IsAdmin(source)
    -- 1. ACE Permission Check (Standard, txAdmin, manuelle Admins)
    if IsPlayerAceAllowed(source, 'group.admin') then return true end
    if IsPlayerAceAllowed(source, 'group.superadmin') then return true end
    if IsPlayerAceAllowed(source, 'vehicle_loader.admin') then return true end

    -- 2. txAdmin-spezifisch (Monitor Resource)
    if GetResourceState('monitor') == 'started' then
        local hasPerm = pcall(function()
            return exports.monitor:txaAdminCheckPermission(source, 'all_permissions')
        end)
        if hasPerm then return true end
    end

    -- 3. Framework-spezifisch
    if FrameworkName == 'esx' then
        local player = Framework.GetPlayerFromId(source)
        if player and player.getGroup then
            local group = player.getGroup()
            if group == 'admin' or group == 'superadmin' or group == 'owner' then
                return true
            end
        end

    elseif FrameworkName == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        if player and player.PlayerData.metadata then
            if player.PlayerData.metadata.admin then return true end
        end

    elseif FrameworkName == 'qbcore' then
        local player = Framework.Functions.GetPlayer(source)
        if player then
            -- QBCore Admin Check via PermissionsCheck
            if Framework.Functions.HasPermission then
                if Framework.Functions.HasPermission(source, 'admin') then return true end
                if Framework.Functions.HasPermission(source, 'god') then return true end
            end
        end
    end

    return false
end

-- ============================================================
-- INVENTORY (Universal via ox_inventory)
-- ============================================================

function Bridge.HasItem(source, itemName, amount)
    amount = amount or 1
    local count = exports.ox_inventory:GetItemCount(source, itemName)
    return count >= amount
end

function Bridge.RemoveItem(source, itemName, amount)
    amount = amount or 1
    return exports.ox_inventory:RemoveItem(source, itemName, amount)
end

function Bridge.AddItem(source, itemName, amount)
    amount = amount or 1
    return exports.ox_inventory:AddItem(source, itemName, amount)
end

-- ============================================================
-- NOTIFICATIONS (via ox_lib)
-- ============================================================

function Bridge.Notify(source, title, message, notifyType)
    notifyType = notifyType or 'info'
    TriggerClientEvent('ox_lib:notify', source, {
        title = title,
        description = message,
        type = notifyType,
        position = 'top-right',
        duration = 4000,
    })
end

-- ============================================================
-- DEBUG / UTILITY
-- ============================================================

-- Export für andere Resources: Welches Framework wird genutzt?
exports('GetFramework', function()
    return FrameworkName
end)

-- Admin Command: Framework Info
lib.addCommand('loaderframework', {
    help = 'Aktives Framework anzeigen',
    restricted = 'group.admin',
}, function(source)
    Bridge.Notify(source, 'Framework', ('Aktiv: %s'):format(FrameworkName:upper()), 'info')
    print(('^2[Vehicle Loader]^7 Framework: %s'):format(FrameworkName))
end)

-- Admin Test Command: Prüft ob du als Admin erkannt wirst
RegisterCommand('loaderadmincheck', function(source)
    if source == 0 then
        print('^2[Vehicle Loader]^7 Console hat immer Admin-Rechte')
        return
    end

    local isAdmin = Bridge.IsAdmin(source)
    local checks = {
        ('ACE group.admin: %s'):format(tostring(IsPlayerAceAllowed(source, 'group.admin'))),
        ('ACE group.superadmin: %s'):format(tostring(IsPlayerAceAllowed(source, 'group.superadmin'))),
        ('ACE vehicle_loader.admin: %s'):format(tostring(IsPlayerAceAllowed(source, 'vehicle_loader.admin'))),
        ('Framework Admin: %s'):format(FrameworkName),
        ('Final: %s'):format(isAdmin and '✅ ADMIN' or '❌ NO'),
    }

    Bridge.Notify(source, 'Admin Check', table.concat(checks, '\n'), isAdmin and 'success' or 'info')
end, false)
