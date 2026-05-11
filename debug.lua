-- Vehicle Loader Debug System v4.0
-- Modern In-Game Editor mit Snap-to-Vehicle Feature

local debugMode = false
local selectedTrailer = nil
local selectedSlot = 1
local adjustmentMode = 'position'
local adjustmentAxis = 'x'
local adjustmentStep = 0.1
local ghostVehicle = nil

-- ============================================================
-- HELPERS
-- ============================================================

local function FindNearestTrailer()
    local vehicles = GetGamePool('CVehicle')
    local nearestDist = 50.0
    local nearestTrailer = nil

    for _, vehicle in ipairs(vehicles) do
        if GetTrailerConfigByEntity(vehicle) then
            local dist = #(GetEntityCoords(cache.ped) - GetEntityCoords(vehicle))
            if dist < nearestDist then
                nearestDist = dist
                nearestTrailer = vehicle
            end
        end
    end

    return nearestTrailer
end

-- Berechne World-Position aus Trailer + Offset
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

-- Berechne Offset von World-Position (umgekehrt)
local function CalculateOffsetFromWorld(trailer, worldPos)
    local trailerCoords = GetEntityCoords(trailer)
    local trailerHeading = GetEntityHeading(trailer)
    local radians = -math.rad(trailerHeading) -- Inverse rotation

    local deltaX = worldPos.x - trailerCoords.x
    local deltaY = worldPos.y - trailerCoords.y
    local deltaZ = worldPos.z - trailerCoords.z

    -- Inverse Rotation
    local offsetX = deltaX * math.cos(radians) - deltaY * math.sin(radians)
    local offsetY = deltaX * math.sin(radians) + deltaY * math.cos(radians)

    return vector3(
        math.floor(offsetX * 100) / 100,
        math.floor(offsetY * 100) / 100,
        math.floor(deltaZ * 100) / 100
    )
end

local function AdjustSlot(trailerConfig, axisDelta)
    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    if adjustmentMode == 'position' then
        local c = slot.offset
        slot.offset = vector3(
            c.x + (adjustmentAxis == 'x' and axisDelta or 0),
            c.y + (adjustmentAxis == 'y' and axisDelta or 0),
            c.z + (adjustmentAxis == 'z' and axisDelta or 0)
        )
    else
        local c = slot.rotation
        slot.rotation = vector3(
            c.x + (adjustmentAxis == 'x' and axisDelta or 0),
            c.y + (adjustmentAxis == 'y' and axisDelta or 0),
            c.z + (adjustmentAxis == 'z' and axisDelta or 0)
        )
    end
end

-- ============================================================
-- ⭐ SNAP-TO-VEHICLE Feature
-- ============================================================
-- Spieler steht in/neben einem Vehicle → Position wird übernommen
local function SnapSlotToCurrentVehicle()
    if not selectedTrailer or not DoesEntityExist(selectedTrailer) then return end

    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    -- Suche das nächste Vehicle (nicht den Trailer selbst)
    local sourceVehicle = nil
    local pedCoords = GetEntityCoords(cache.ped)

    if IsPedInAnyVehicle(cache.ped, false) then
        local veh = cache.vehicle or GetVehiclePedIsIn(cache.ped, false)
        if veh ~= selectedTrailer then
            sourceVehicle = veh
        end
    end

    if not sourceVehicle then
        -- Fallback: nächstes Vehicle in der Nähe
        local vehicles = GetGamePool('CVehicle')
        local nearestDist = 10.0

        for _, v in ipairs(vehicles) do
            if v ~= selectedTrailer and IsEntityAVehicle(v) then
                local dist = #(pedCoords - GetEntityCoords(v))
                if dist < nearestDist then
                    nearestDist = dist
                    sourceVehicle = v
                end
            end
        end
    end

    if not sourceVehicle then
        Bridge.Notify('Debug', 'Kein Fahrzeug zum Snappen gefunden! (Steig in ein Auto oder stell dich daneben)', 'error')
        return
    end

    -- Vehicle-Position als World-Pos
    local vehCoords = GetEntityCoords(sourceVehicle)
    local vehHeading = GetEntityHeading(sourceVehicle)
    local trailerHeading = GetEntityHeading(selectedTrailer)

    -- Berechne Offset relativ zum Trailer
    local newOffset = CalculateOffsetFromWorld(selectedTrailer, vehCoords)

    -- Berechne Rotation-Differenz
    local rotDiff = vehHeading - trailerHeading
    while rotDiff > 180 do rotDiff = rotDiff - 360 end
    while rotDiff < -180 do rotDiff = rotDiff + 360 end

    -- Slot updaten
    slot.offset = newOffset
    slot.rotation = vector3(0.0, 0.0, math.floor(rotDiff * 100) / 100)

    Bridge.Notify('Debug', ('Slot %d gesnapped! Offset: %.2f, %.2f, %.2f'):format(
        slot.id, newOffset.x, newOffset.y, newOffset.z
    ), 'success')
end

-- ============================================================
-- ⭐ SLOT MANAGEMENT (Add/Remove)
-- ============================================================

local function AddNewSlot()
    if not selectedTrailer then return end

    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    -- Finde nächste freie Slot-ID
    local maxId = 0
    for _, slot in ipairs(trailerConfig.slots) do
        if slot.id > maxId then maxId = slot.id end
    end

    -- Neuer Slot mit Default-Position
    local newSlot = {
        id = maxId + 1,
        offset = vector3(0.0, -3.5, 1.0),
        rotation = vector3(0.0, 0.0, 0.0),
    }

    table.insert(trailerConfig.slots, newSlot)
    trailerConfig.maxVehicles = trailerConfig.maxVehicles + 1

    selectedSlot = #trailerConfig.slots

    -- Zonen neu erstellen
    exports.vehicle_loader:ToggleZoneDebug(false)
    Wait(100)
    exports.vehicle_loader:ToggleZoneDebug(true)

    Bridge.Notify('Debug', ('Slot %d hinzugefügt!'):format(newSlot.id), 'success')
end

local function RemoveCurrentSlot()
    if not selectedTrailer then return end

    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig or #trailerConfig.slots <= 1 then
        Bridge.Notify('Debug', 'Mindestens 1 Slot muss bleiben!', 'error')
        return
    end

    local removed = table.remove(trailerConfig.slots, selectedSlot)
    trailerConfig.maxVehicles = math.max(1, trailerConfig.maxVehicles - 1)

    if selectedSlot > #trailerConfig.slots then
        selectedSlot = #trailerConfig.slots
    end

    -- Zonen neu erstellen
    exports.vehicle_loader:ToggleZoneDebug(false)
    Wait(100)
    exports.vehicle_loader:ToggleZoneDebug(true)

    Bridge.Notify('Debug', ('Slot %d entfernt!'):format(removed.id), 'info')
end

-- ============================================================
-- DEBUG HUD
-- ============================================================

local function ShowDebugHUD(trailerConfig)
    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    local value = adjustmentMode == 'position' and slot.offset or slot.rotation

    lib.showTextUI(
        ('**🔧 Debug Mode**  \n' ..
        '**Trailer:** %s  \n' ..
        '**Slot:** %d/%d (ID: %d)  \n' ..
        '**Modus:** `%s`  \n' ..
        '**Achse:** `%s`  \n' ..
        '**Werte:** %.2f, %.2f, %.2f  \n' ..
        '**Step:** %.2f  \n' ..
        '\n' ..
        '⌨️ **Steuerung:**  \n' ..
        '[G] Slot wechseln  \n' ..
        '[M] Position/Rotation  \n' ..
        '[X/C/V] X/Y/Z Achse  \n' ..
        '[E/Q] +/- Wert  \n' ..
        '[1/2/3] Step (0.05/0.1/0.5)  \n' ..
        '\n' ..
        '🎯 **Features:**  \n' ..
        '[F] **Snap to Vehicle**  \n' ..
        '[+/-] Slot Add/Remove  \n' ..
        '[B] Config kopieren  \n' ..
        '[H] Hauptmenü  \n' ..
        '[N] Debug beenden')
        :format(
            trailerConfig.label,
            selectedSlot, #trailerConfig.slots, slot.id,
            adjustmentMode,
            adjustmentAxis:upper(),
            value.x, value.y, value.z,
            adjustmentStep
        ),
        { position = 'right-center', icon = 'fa-solid fa-wrench' }
    )
end

-- ============================================================
-- CONFIG EXPORT
-- ============================================================

local function PrintTrailerConfig(trailerConfig)
    local output = ('\n^2=== %s Config ===^7\n{\n'):format(trailerConfig.label)
    output = output .. ('    model = "%s",\n'):format(trailerConfig.model)
    output = output .. ('    label = "%s",\n'):format(trailerConfig.label)
    output = output .. ('    maxVehicles = %d,\n'):format(trailerConfig.maxVehicles)

    -- Ramp
    if trailerConfig.ramp then
        output = output .. ('    ramp = {\n')
        output = output .. ('        enabled = %s,\n'):format(tostring(trailerConfig.ramp.enabled))
        output = output .. ('        doorIndex = %d,\n'):format(trailerConfig.ramp.doorIndex or 5)
        output = output .. ('        openTime = %d,\n'):format(trailerConfig.ramp.openTime or 500)
        output = output .. ('    },\n')
    end

    -- Slots
    output = output .. ('    slots = {\n')
    for _, slot in ipairs(trailerConfig.slots) do
        output = output .. ('        {\n')
        output = output .. ('            id = %d,\n'):format(slot.id)
        output = output .. ('            offset = vector3(%.2f, %.2f, %.2f),\n'):format(
            slot.offset.x, slot.offset.y, slot.offset.z
        )
        output = output .. ('            rotation = vector3(%.2f, %.2f, %.2f),\n'):format(
            slot.rotation.x, slot.rotation.y, slot.rotation.z
        )
        output = output .. ('        },\n')
    end
    output = output .. ('    }\n}\n^2================^7\n')

    print(output)
    lib.setClipboard(output)
    Bridge.Notify('Debug', 'Config in F8 Console + Clipboard!', 'success')
end

-- ============================================================
-- ⭐ MAIN MENU (ox_lib Context Menu)
-- ============================================================

local function OpenMainMenu()
    if not selectedTrailer then
        selectedTrailer = FindNearestTrailer()
    end

    if not selectedTrailer then
        Bridge.Notify('Debug', 'Kein Anhänger in der Nähe!', 'error')
        return
    end

    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local options = {}

    -- Header
    options[#options + 1] = {
        title = ('🚛 %s'):format(trailerConfig.label),
        description = ('Slots: %d | Aktuell: Slot %d'):format(#trailerConfig.slots, trailerConfig.slots[selectedSlot] and trailerConfig.slots[selectedSlot].id or 0),
        disabled = true,
    }

    -- Slot Selection
    for i, slot in ipairs(trailerConfig.slots) do
        local marker = (i == selectedSlot) and '✅ ' or ''
        options[#options + 1] = {
            title = ('%sSlot %d'):format(marker, slot.id),
            description = ('Offset: %.2f, %.2f, %.2f | Rot: %.0f°'):format(
                slot.offset.x, slot.offset.y, slot.offset.z, slot.rotation.z
            ),
            icon = 'fa-solid fa-cube',
            onSelect = function()
                selectedSlot = i
                lib.showContext('vehicle_loader_main')
            end,
        }
    end

    -- Divider
    options[#options + 1] = { title = '────────────────', disabled = true }

    -- Actions
    options[#options + 1] = {
        title = '🎯 Snap to Vehicle',
        description = 'Übernimmt Position des nächsten Fahrzeugs',
        icon = 'fa-solid fa-bullseye',
        onSelect = function()
            SnapSlotToCurrentVehicle()
            SetTimeout(500, OpenMainMenu)
        end,
    }

    options[#options + 1] = {
        title = '➕ Neuer Slot',
        description = 'Fügt einen neuen Slot hinzu',
        icon = 'fa-solid fa-plus',
        onSelect = function()
            AddNewSlot()
            SetTimeout(500, OpenMainMenu)
        end,
    }

    if #trailerConfig.slots > 1 then
        options[#options + 1] = {
            title = '➖ Aktuellen Slot löschen',
            description = ('Löscht Slot %d'):format(trailerConfig.slots[selectedSlot].id),
            icon = 'fa-solid fa-minus',
            onSelect = function()
                local confirmed = lib.alertDialog({
                    header = 'Slot löschen?',
                    content = ('Slot %d wirklich löschen?'):format(trailerConfig.slots[selectedSlot].id),
                    cancel = true,
                })
                if confirmed == 'confirm' then
                    RemoveCurrentSlot()
                end
                SetTimeout(500, OpenMainMenu)
            end,
        }
    end

    options[#options + 1] = { title = '────────────────', disabled = true }

    -- Manuelle Eingabe via inputDialog
    options[#options + 1] = {
        title = '✏️ Werte manuell eingeben',
        description = 'Position via Dialog setzen',
        icon = 'fa-solid fa-keyboard',
        onSelect = function()
            local slot = trailerConfig.slots[selectedSlot]
            local input = lib.inputDialog(('Slot %d bearbeiten'):format(slot.id), {
                { type = 'number', label = 'Offset X', default = slot.offset.x, step = 0.01 },
                { type = 'number', label = 'Offset Y', default = slot.offset.y, step = 0.01 },
                { type = 'number', label = 'Offset Z', default = slot.offset.z, step = 0.01 },
                { type = 'number', label = 'Rotation Z (Grad)', default = slot.rotation.z, step = 1 },
            })

            if input then
                slot.offset = vector3(input[1] or 0, input[2] or 0, input[3] or 0)
                slot.rotation = vector3(0, 0, input[4] or 0)
                Bridge.Notify('Debug', 'Werte aktualisiert!', 'success')
            end

            SetTimeout(500, OpenMainMenu)
        end,
    }

    options[#options + 1] = { title = '────────────────', disabled = true }

    -- Export
    options[#options + 1] = {
        title = '📋 Config exportieren',
        description = 'In Clipboard + Console',
        icon = 'fa-solid fa-copy',
        onSelect = function() PrintTrailerConfig(trailerConfig) end,
    }

    options[#options + 1] = {
        title = '👁️ Live Visualisierung',
        description = 'Zonen ein-/ausblenden',
        icon = 'fa-solid fa-eye',
        onSelect = function()
            exports.vehicle_loader:ToggleZoneDebug(true)
            Bridge.Notify('Debug', 'Zonen aktiviert', 'info')
            SetTimeout(500, OpenMainMenu)
        end,
    }

    options[#options + 1] = {
        title = '🚪 Debug beenden',
        icon = 'fa-solid fa-xmark',
        onSelect = function()
            debugMode = false
        end,
    }

    lib.registerContext({
        id = 'vehicle_loader_main',
        title = '🔧 Vehicle Loader Debug',
        options = options,
    })

    lib.showContext('vehicle_loader_main')
end

-- ============================================================
-- DEBUG INPUT HANDLER (Tastatur-Steuerung)
-- ============================================================

local function HandleDebugInput(trailerConfig)
    -- H - Hauptmenü öffnen
    if IsControlJustReleased(0, 74) then -- H
        OpenMainMenu()
    end

    -- G - Slot wechseln
    if IsControlJustReleased(0, 47) then
        selectedSlot = selectedSlot + 1
        if selectedSlot > #trailerConfig.slots then
            selectedSlot = 1
        end
    end

    -- M - Mode wechseln
    if IsControlJustReleased(0, 244) then
        adjustmentMode = adjustmentMode == 'position' and 'rotation' or 'position'
    end

    -- X/C/V - Achse
    if IsControlJustReleased(0, 73) then adjustmentAxis = 'x'
    elseif IsControlJustReleased(0, 26) then adjustmentAxis = 'y'
    elseif IsControlJustReleased(0, 71) then adjustmentAxis = 'z'
    end

    -- E/Q - Adjust (held für continuous)
    if IsControlPressed(0, 38) then AdjustSlot(trailerConfig, adjustmentStep) end
    if IsControlPressed(0, 44) then AdjustSlot(trailerConfig, -adjustmentStep) end

    -- 1/2/3 - Step
    if IsControlJustReleased(0, 157) then adjustmentStep = 0.05
    elseif IsControlJustReleased(0, 158) then adjustmentStep = 0.1
    elseif IsControlJustReleased(0, 160) then adjustmentStep = 0.5
    end

    -- F - SNAP TO VEHICLE ⭐
    if IsControlJustReleased(0, 23) then -- F
        SnapSlotToCurrentVehicle()
    end

    -- + / - Slot Management
    if IsControlJustReleased(0, 84) then -- + (Numpad)
        AddNewSlot()
    end
    if IsControlJustReleased(0, 82) then -- - (Numpad)
        RemoveCurrentSlot()
    end

    -- B - Export Config
    if IsControlJustReleased(0, 29) then
        PrintTrailerConfig(trailerConfig)
    end

    -- N - Beenden
    if IsControlJustReleased(0, 249) then
        debugMode = false
    end
end

-- ============================================================
-- START DEBUG MODE
-- ============================================================

local function StartDebugMode()
    if debugMode then
        Bridge.Notify('Debug', 'Debug ist bereits aktiv!', 'warning')
        return
    end

    selectedTrailer = FindNearestTrailer()
    if not selectedTrailer then
        Bridge.Notify('Debug', 'Kein Anhänger in der Nähe! (max 50m)', 'error')
        return
    end

    debugMode = true
    selectedSlot = 1

    exports.vehicle_loader:ToggleZoneDebug(true)
    Bridge.Notify('Debug', 'Debug aktiviert! [H] für Hauptmenü, [F] für Snap-to-Vehicle', 'success')

    CreateThread(function()
        while debugMode do
            Wait(0)

            local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
            if not trailerConfig or not DoesEntityExist(selectedTrailer) then
                debugMode = false
                lib.hideTextUI()
                break
            end

            ShowDebugHUD(trailerConfig)
            HandleDebugInput(trailerConfig)
        end

        exports.vehicle_loader:ToggleZoneDebug(false)
        lib.hideTextUI()
        Bridge.Notify('Debug', 'Debug Mode beendet!', 'info')
    end)
end

-- ============================================================
-- COMMANDS
-- ============================================================

if Config.Global.DebugMode then
    RegisterCommand('debugloader', function()
        StartDebugMode()
    end, false)

    RegisterCommand('debugmenu', function()
        if not selectedTrailer then
            selectedTrailer = FindNearestTrailer()
        end
        OpenMainMenu()
    end, false)

    RegisterCommand('debugsnap', function()
        if not selectedTrailer then
            selectedTrailer = FindNearestTrailer()
        end
        SnapSlotToCurrentVehicle()
    end, false)

    RegisterCommand('debugstop', function()
        debugMode = false
        exports.vehicle_loader:ToggleZoneDebug(false)
        lib.hideTextUI()
    end, false)

    lib.addKeybind({
        name = 'debugloader_toggle',
        description = 'Vehicle Loader Debug',
        defaultKey = 'F7',
        onPressed = function()
            if debugMode then
                debugMode = false
            else
                StartDebugMode()
            end
        end,
    })

    lib.print.info('[Vehicle Loader Debug] System v4.0 geladen! /debugloader oder F7')
end
