-- Framework Bridge - Client Side
-- Auto-detect ESX / QBox / QBCore / Standalone

Bridge = {}
Framework = nil
FrameworkName = 'standalone'
PlayerData = {}

-- ============================================================
-- AUTO-DETECTION (QBox vor QBCore wegen Compat-Layer)
-- ============================================================

CreateThread(function()
    -- QBox FIRST
    if GetResourceState('qbx_core') == 'started' then
        FrameworkName = 'qbox'
        PlayerData = exports.qbx_core:GetPlayerData() or {}
        print('^2[Vehicle Loader]^7 Framework: QBox (qbx_core)')

    -- ESX
    elseif GetResourceState('es_extended') == 'started' then
        Framework = exports['es_extended']:getSharedObject()
        FrameworkName = 'esx'
        PlayerData = Framework.GetPlayerData() or {}
        print('^2[Vehicle Loader]^7 Framework: ESX')

    -- QBCore (Legacy)
    elseif GetResourceState('qb-core') == 'started' then
        Framework = exports['qb-core']:GetCoreObject()
        FrameworkName = 'qbcore'
        PlayerData = Framework.Functions.GetPlayerData() or {}
        print('^2[Vehicle Loader]^7 Framework: QBCore')

    else
        FrameworkName = 'standalone'
        print('^2[Vehicle Loader]^7 Framework: Standalone')
    end
end)

-- ============================================================
-- PLAYER DATA EVENTS
-- ============================================================

-- ESX Events
AddEventHandler('esx:playerLoaded', function(xPlayer)
    if FrameworkName == 'esx' then
        PlayerData = xPlayer
    end
end)

AddEventHandler('esx:setJob', function(job)
    if FrameworkName == 'esx' then
        PlayerData.job = job
    end
end)

-- QBCore Events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if FrameworkName == 'qbcore' then
        PlayerData = Framework.Functions.GetPlayerData()
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    if FrameworkName == 'qbcore' then
        PlayerData.job = JobInfo
    end
end)

-- QBox Events
RegisterNetEvent('qbx_core:client:onPlayerLoaded', function()
    if FrameworkName == 'qbox' then
        PlayerData = exports.qbx_core:GetPlayerData()
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo) -- QBox uses same event sometimes
    if FrameworkName == 'qbox' then
        PlayerData.job = JobInfo
    end
end)

-- QBox: State Bag Handler (modern approach)
if FrameworkName == 'qbox' then
    AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
        if value then
            PlayerData = exports.qbx_core:GetPlayerData()
        end
    end)
end

-- ============================================================
-- PLAYER API
-- ============================================================

-- Get Player Job
function Bridge.GetJob()
    if FrameworkName == 'qbox' then
        -- QBox: Aktuellster Player Data
        local data = exports.qbx_core:GetPlayerData()
        return data and data.job and data.job.name or nil

    elseif FrameworkName == 'esx' then
        return PlayerData.job and PlayerData.job.name or nil

    elseif FrameworkName == 'qbcore' then
        return PlayerData.job and PlayerData.job.name or nil
    end

    return nil
end

-- Get Player Job Grade
function Bridge.GetJobGrade()
    if FrameworkName == 'qbox' then
        local data = exports.qbx_core:GetPlayerData()
        return data and data.job and data.job.grade and data.job.grade.level or 0

    elseif FrameworkName == 'esx' then
        return PlayerData.job and PlayerData.job.grade or 0

    elseif FrameworkName == 'qbcore' then
        return PlayerData.job and PlayerData.job.grade and PlayerData.job.grade.level or 0
    end

    return 0
end

-- Is Player On Duty?
function Bridge.IsOnDuty()
    if FrameworkName == 'qbox' then
        local data = exports.qbx_core:GetPlayerData()
        return data and data.job and data.job.onduty or false

    elseif FrameworkName == 'esx' then
        return true -- ESX hat kein duty system standardmäßig

    elseif FrameworkName == 'qbcore' then
        return PlayerData.job and PlayerData.job.onduty or false
    end

    return true
end

-- ============================================================
-- NOTIFICATIONS & UI (via ox_lib)
-- ============================================================

function Bridge.Notify(title, message, notifyType)
    notifyType = notifyType or 'info'
    lib.notify({
        title = title,
        description = message,
        type = notifyType,
        position = 'top-right',
        duration = 4000,
    })
end

function Bridge.ProgressBar(label, duration)
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
    })
end

-- ============================================================
-- DEBUG
-- ============================================================

exports('GetFramework', function()
    return FrameworkName
end)

RegisterCommand('loaderframework', function()
    print(('^2[Vehicle Loader]^7 Framework: %s'):format(FrameworkName))
    Bridge.Notify('Framework', ('Aktiv: %s'):format(FrameworkName:upper()), 'info')
end, false)
