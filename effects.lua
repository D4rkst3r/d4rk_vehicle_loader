-- Vehicle Loader - Sound Effects & Ramp Animation System

Effects = {}

-- ============================================================
-- SOUND EFFECTS
-- ============================================================
-- Native GTA V Sounds (kein Custom Audio nötig)

local SoundList = {
    -- Pneumatic Hiss (Truck Brakes)
    truck_brake = {
        soundName = 'TRUCK_BRAKES',
        soundSet = 'GENERIC_TRUCK_RELEASE_AIR_BRAKE',
    },

    -- Loading Start
    load_start = {
        soundName = 'Trunk_Open',
        soundSet = 'DLC_GR_VV_Trunk_Sounds',
    },

    -- Loading Complete
    load_complete = {
        soundName = 'Garage_Closed',
        soundSet = 'DLC_Apt_Apt_Door_Sounds',
    },

    -- Unload Drop (Crash)
    unload_drop = {
        soundName = 'CRASH',
        soundSet = 'PALETO_SCORE_SETUP_FIB_SOUNDS',
    },

    -- Mechanical / Strap tightening
    mechanical = {
        soundName = 'PICK_UP',
        soundSet = 'HUD_LIQUOR_STORE_SOUNDSET',
    },

    -- Error / Cancel
    error = {
        soundName = 'ERROR',
        soundSet = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
    },
}

-- 3D Sound an einer Position
function Effects.PlaySound3D(soundKey, coords)
    local sound = SoundList[soundKey]
    if not sound then return end

    local soundId = GetSoundId()
    PlaySoundFromCoord(soundId, sound.soundName, coords.x, coords.y, coords.z, sound.soundSet, false, 20, false)
    SetTimeout(3000, function()
        ReleaseSoundId(soundId)
    end)
end

-- Sound an einem Entity
function Effects.PlaySoundFromEntity(soundKey, entity)
    local sound = SoundList[soundKey]
    if not sound or not entity or entity == 0 then return end

    local soundId = GetSoundId()
    PlaySoundFromEntity(soundId, sound.soundName, entity, sound.soundSet, false, 0)
    SetTimeout(3000, function()
        ReleaseSoundId(soundId)
    end)
end

-- Frontend Sound (UI)
function Effects.PlaySoundUI(soundKey)
    local sound = SoundList[soundKey]
    if not sound then return end

    PlaySoundFrontend(-1, sound.soundName, sound.soundSet, true)
end

-- ============================================================
-- PARTICLE EFFECTS
-- ============================================================

function Effects.SpawnDust(coords, scale)
    scale = scale or 1.5

    CreateThread(function()
        lib.requestNamedPtfxAsset('core', 5000)
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord(
            'ent_amb_dust_floor',
            coords.x, coords.y, coords.z,
            0.0, 0.0, 0.0,
            scale, false, false, false
        )
    end)
end

function Effects.SpawnSparks(coords)
    CreateThread(function()
        lib.requestNamedPtfxAsset('core', 5000)
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord(
            'ent_sht_electrical_box',
            coords.x, coords.y, coords.z,
            0.0, 0.0, 0.0,
            1.0, false, false, false
        )
    end)
end

-- ============================================================
-- RAMP ANIMATION (Door/Trunk basierte Rampe)
-- ============================================================
-- Funktioniert mit jedem Door-Index von 0-6
-- Standard Trunk = 5
-- Boot/Tailgate = 5
-- Custom Models können andere Bones nutzen

-- Rampe öffnen
function Effects.OpenRamp(trailer, doorIndex, loose)
    if not trailer or trailer == 0 then return end
    doorIndex = doorIndex or 5 -- Default: Trunk

    SetVehicleDoorOpen(trailer, doorIndex, loose or false, false)

    -- Sound
    Effects.PlaySound3D('truck_brake', GetEntityCoords(trailer))
end

-- Rampe schließen
function Effects.CloseRamp(trailer, doorIndex)
    if not trailer or trailer == 0 then return end
    doorIndex = doorIndex or 5

    SetVehicleDoorShut(trailer, doorIndex, false)

    -- Sound
    Effects.PlaySound3D('load_complete', GetEntityCoords(trailer))
end

-- Rampe öffnen, warten, dann schließen
function Effects.AnimateRampCycle(trailer, doorIndex, openDuration)
    if not trailer or trailer == 0 then return end

    openDuration = openDuration or 5000
    doorIndex = doorIndex or 5

    Effects.OpenRamp(trailer, doorIndex, false)

    SetTimeout(openDuration, function()
        if DoesEntityExist(trailer) then
            Effects.CloseRamp(trailer, doorIndex)
        end
    end)
end

-- ============================================================
-- COMBO EFFECTS (für Loading/Unloading)
-- ============================================================

-- Start Loading Effect (Rampe öffnet + Sound)
function Effects.StartLoading(trailer, doorIndex)
    if not Config.Global.EnableEffects then return end

    Effects.OpenRamp(trailer, doorIndex)
    SetTimeout(500, function()
        if DoesEntityExist(trailer) then
            Effects.PlaySoundFromEntity('mechanical', trailer)
        end
    end)
end

-- Finish Loading Effect (Rampe schließt + Strap-Sound)
function Effects.FinishLoading(trailer, doorIndex)
    if not Config.Global.EnableEffects then return end

    Effects.PlaySoundFromEntity('mechanical', trailer)
    SetTimeout(800, function()
        if DoesEntityExist(trailer) then
            Effects.CloseRamp(trailer, doorIndex)
        end
    end)
end

-- Start Unloading Effect
function Effects.StartUnloading(trailer, doorIndex)
    if not Config.Global.EnableEffects then return end

    Effects.OpenRamp(trailer, doorIndex)
end

-- Finish Unloading Effect (Drop + Dust + Sound)
function Effects.FinishUnloading(trailer, doorIndex, dropCoords)
    if not Config.Global.EnableEffects then return end

    -- Truck-Bremsen Sound
    Effects.PlaySoundFromEntity('truck_brake', trailer)

    -- Staub am Drop-Point
    if dropCoords then
        Effects.SpawnDust(dropCoords, 1.8)
        Effects.PlaySound3D('unload_drop', dropCoords)
    end

    -- Rampe nach kurzer Zeit schließen
    SetTimeout(2000, function()
        if DoesEntityExist(trailer) then
            Effects.CloseRamp(trailer, doorIndex)
        end
    end)
end

-- ============================================================
-- EXPORTS für andere Resources
-- ============================================================

exports('PlaySound', function(soundKey, coords)
    Effects.PlaySound3D(soundKey, coords)
end)

exports('OpenTrailerRamp', function(trailer, doorIndex)
    Effects.OpenRamp(trailer, doorIndex)
end)

exports('CloseTrailerRamp', function(trailer, doorIndex)
    Effects.CloseRamp(trailer, doorIndex)
end)

print('^2[Vehicle Loader Effects]^7 Effects System geladen!')
