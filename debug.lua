-- Vehicle Loader Debug System v5.0
-- Modern In-Game Editor mit Snap, Ghost-Preview, Test-Vehicle, Undo/Redo & mehr

local debugMode = false
local selectedTrailer = nil
local selectedSlot = 1
local adjustmentMode = 'position'
local adjustmentAxis = 'x'
local adjustmentStep = 0.1

-- Backup System (Undo/Redo)
local undoStack = {}
local redoStack = {}
local MAX_UNDO = 20

-- Test-Vehicle & Ghost
local testVehicle = nil
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

local function CalculateOffsetFromWorld(trailer, worldPos)
    local trailerCoords = GetEntityCoords(trailer)
    local trailerHeading = GetEntityHeading(trailer)
    local radians = -math.rad(trailerHeading)

    local deltaX = worldPos.x - trailerCoords.x
    local deltaY = worldPos.y - trailerCoords.y
    local deltaZ = worldPos.z - trailerCoords.z

    local offsetX = deltaX * math.cos(radians) - deltaY * math.sin(radians)
    local offsetY = deltaX * math.sin(radians) + deltaY * math.cos(radians)

    return vector3(
        math.floor(offsetX * 100) / 100,
        math.floor(offsetY * 100) / 100,
        math.floor(deltaZ * 100) / 100
    )
end

-- ============================================================
-- ⭐ UNDO/REDO SYSTEM
-- ============================================================

local function DeepCopySlots(slots)
    local copy = {}
    for i, slot in ipairs(slots) do
        copy[i] = {
            id = slot.id,
            offset = vector3(slot.offset.x, slot.offset.y, slot.offset.z),
            rotation = vector3(slot.rotation.x, slot.rotation.y, slot.rotation.z),
        }
    end
    return copy
end

local function SaveUndoState(trailerConfig)
    if not trailerConfig then return end

    table.insert(undoStack, DeepCopySlots(trailerConfig.slots))
    if #undoStack > MAX_UNDO then
        table.remove(undoStack, 1)
    end
    redoStack = {} -- Clear redo on new change
end

local function Undo(trailerConfig)
    if #undoStack == 0 then
        Bridge.Notify('Debug', 'Nichts zum Rückgängig machen!', 'warning')
        return
    end

    table.insert(redoStack, DeepCopySlots(trailerConfig.slots))
    trailerConfig.slots = table.remove(undoStack)

    Bridge.Notify('Debug', 'Undo!', 'info')
end

local function Redo(trailerConfig)
    if #redoStack == 0 then
        Bridge.Notify('Debug', 'Nichts zum Wiederherstellen!', 'warning')
        return
    end

    table.insert(undoStack, DeepCopySlots(trailerConfig.slots))
    trailerConfig.slots = table.remove(redoStack)

    Bridge.Notify('Debug', 'Redo!', 'info')
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
-- ⭐ SNAP TO VEHICLE
-- ============================================================

local function SnapSlotToCurrentVehicle()
    if not selectedTrailer or not DoesEntityExist(selectedTrailer) then return end

    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    local sourceVehicle = nil
    local pedCoords = GetEntityCoords(cache.ped)

    if IsPedInAnyVehicle(cache.ped, false) then
        local veh = cache.vehicle or GetVehiclePedIsIn(cache.ped, false)
        if veh ~= selectedTrailer then
            sourceVehicle = veh
        end
    end

    if not sourceVehicle then
        local vehicles = GetGamePool('CVehicle')
        local nearestDist = 10.0

        for _, v in ipairs(vehicles) do
            if v ~= selectedTrailer and v ~= ghostVehicle and IsEntityAVehicle(v) then
                local dist = #(pedCoords - GetEntityCoords(v))
                if dist < nearestDist then
                    nearestDist = dist
                    sourceVehicle = v
                end
            end
        end
    end

    if not sourceVehicle then
        Bridge.Notify('Debug', 'Kein Fahrzeug zum Snappen!', 'error')
        return
    end

    SaveUndoState(trailerConfig)

    local vehCoords = GetEntityCoords(sourceVehicle)
    local vehHeading = GetEntityHeading(sourceVehicle)
    local trailerHeading = GetEntityHeading(selectedTrailer)

    local newOffset = CalculateOffsetFromWorld(selectedTrailer, vehCoords)
    local rotDiff = vehHeading - trailerHeading
    while rotDiff > 180 do rotDiff = rotDiff - 360 end
    while rotDiff < -180 do rotDiff = rotDiff + 360 end

    slot.offset = newOffset
    slot.rotation = vector3(0.0, 0.0, math.floor(rotDiff * 100) / 100)

    Bridge.Notify('Debug', ('Slot %d gesnapped!'):format(slot.id), 'success')
end

-- ============================================================
-- ⭐ SLOT OPERATIONS
-- ============================================================

local function AddNewSlot()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    SaveUndoState(trailerConfig)

    local maxId = 0
    for _, slot in ipairs(trailerConfig.slots) do
        if slot.id > maxId then maxId = slot.id end
    end

    local newSlot = {
        id = maxId + 1,
        offset = vector3(0.0, -3.5, 1.0),
        rotation = vector3(0.0, 0.0, 0.0),
    }

    table.insert(trailerConfig.slots, newSlot)
    trailerConfig.maxVehicles = #trailerConfig.slots
    selectedSlot = #trailerConfig.slots

    exports.vehicle_loader:ToggleZoneDebug(false)
    Wait(100)
    exports.vehicle_loader:ToggleZoneDebug(true)

    Bridge.Notify('Debug', ('Slot %d hinzugefügt!'):format(newSlot.id), 'success')
end

-- ⭐ Slot duplizieren (Copy)
local function DuplicateCurrentSlot()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local source = trailerConfig.slots[selectedSlot]
    if not source then return end

    SaveUndoState(trailerConfig)

    local maxId = 0
    for _, slot in ipairs(trailerConfig.slots) do
        if slot.id > maxId then maxId = slot.id end
    end

    local newSlot = {
        id = maxId + 1,
        offset = vector3(source.offset.x, source.offset.y - 1.0, source.offset.z),
        rotation = vector3(source.rotation.x, source.rotation.y, source.rotation.z),
    }

    table.insert(trailerConfig.slots, newSlot)
    trailerConfig.maxVehicles = #trailerConfig.slots
    selectedSlot = #trailerConfig.slots

    exports.vehicle_loader:ToggleZoneDebug(false)
    Wait(100)
    exports.vehicle_loader:ToggleZoneDebug(true)

    Bridge.Notify('Debug', ('Slot %d → Slot %d kopiert!'):format(source.id, newSlot.id), 'success')
end

-- ⭐ Slot spiegeln (Mirror an X-Achse für L/R Paare)
local function MirrorCurrentSlot()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local source = trailerConfig.slots[selectedSlot]
    if not source then return end

    SaveUndoState(trailerConfig)

    local maxId = 0
    for _, slot in ipairs(trailerConfig.slots) do
        if slot.id > maxId then maxId = slot.id end
    end

    -- Spiegelt X-Achse (links/rechts)
    local newSlot = {
        id = maxId + 1,
        offset = vector3(-source.offset.x, source.offset.y, source.offset.z),
        rotation = vector3(source.rotation.x, source.rotation.y, -source.rotation.z),
    }

    table.insert(trailerConfig.slots, newSlot)
    trailerConfig.maxVehicles = #trailerConfig.slots
    selectedSlot = #trailerConfig.slots

    exports.vehicle_loader:ToggleZoneDebug(false)
    Wait(100)
    exports.vehicle_loader:ToggleZoneDebug(true)

    Bridge.Notify('Debug', ('Slot %d gespiegelt → Slot %d!'):format(source.id, newSlot.id), 'success')
end

local function RemoveCurrentSlot()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig or #trailerConfig.slots <= 1 then
        Bridge.Notify('Debug', 'Mindestens 1 Slot muss bleiben!', 'error')
        return
    end

    SaveUndoState(trailerConfig)

    local removed = table.remove(trailerConfig.slots, selectedSlot)
    trailerConfig.maxVehicles = math.max(1, #trailerConfig.slots)

    if selectedSlot > #trailerConfig.slots then
        selectedSlot = #trailerConfig.slots
    end

    exports.vehicle_loader:ToggleZoneDebug(false)
    Wait(100)
    exports.vehicle_loader:ToggleZoneDebug(true)

    Bridge.Notify('Debug', ('Slot %d entfernt!'):format(removed.id), 'info')
end

-- ============================================================
-- ⭐ TEST VEHICLE SPAWN
-- ============================================================

local TestVehicles = {
    'adder',         -- Sports Car
    'sultanrs',      -- Sports
    'bati',          -- Bike
    'sandking',      -- SUV
    'asea',          -- Sedan
    'phantom',       -- Truck
    'baller',        -- SUV
}

local function SpawnTestVehicle(modelName)
    if testVehicle and DoesEntityExist(testVehicle) then
        SetEntityAsMissionEntity(testVehicle, true, true)
        DeleteVehicle(testVehicle)
        testVehicle = nil
    end

    local model = GetHashKey(modelName)
    lib.requestModel(model, 5000)

    local pedCoords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)

    -- 5m vor dem Spieler spawnen
    local spawnX = pedCoords.x + math.cos(math.rad(heading + 90)) * 5
    local spawnY = pedCoords.y + math.sin(math.rad(heading + 90)) * 5

    testVehicle = CreateVehicle(model, spawnX, spawnY, pedCoords.z, heading, true, false)
    SetVehicleOnGroundProperly(testVehicle)
    SetModelAsNoLongerNeeded(model)

    Bridge.Notify('Debug', ('Test-Vehicle "%s" gespawnt!'):format(modelName), 'success')
end

local function DeleteTestVehicle()
    if testVehicle and DoesEntityExist(testVehicle) then
        SetEntityAsMissionEntity(testVehicle, true, true)
        DeleteVehicle(testVehicle)
        testVehicle = nil
        Bridge.Notify('Debug', 'Test-Vehicle gelöscht!', 'info')
    end
end

-- ============================================================
-- ⭐ RAMP TESTER
-- ============================================================

local function TestRamp()
    if not selectedTrailer then return end

    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig or not trailerConfig.ramp then
        Bridge.Notify('Debug', 'Anhänger hat keine Rampe konfiguriert!', 'error')
        return
    end

    local doorIndex = trailerConfig.ramp.doorIndex or 5
    local currentRatio = GetVehicleDoorAngleRatio(selectedTrailer, doorIndex)

    if currentRatio < 0.1 then
        Effects.OpenRamp(selectedTrailer, doorIndex)
        Bridge.Notify('Debug', ('Rampe geöffnet (Door %d)'):format(doorIndex), 'success')
    else
        Effects.CloseRamp(selectedTrailer, doorIndex)
        Bridge.Notify('Debug', ('Rampe geschlossen (Door %d)'):format(doorIndex), 'info')
    end
end

-- ⭐ Auto-Detect Door Index für Rampe
local function AutoDetectRampDoor()
    if not selectedTrailer then return end

    Bridge.Notify('Debug', 'Teste Door 0-6 - sieh hin!', 'info')

    CreateThread(function()
        for doorIdx = 0, 6 do
            SetVehicleDoorOpen(selectedTrailer, doorIdx, false, false)
            Bridge.Notify('Debug', ('Door %d offen → 2s warten'):format(doorIdx), 'info')
            Wait(2000)
            SetVehicleDoorShut(selectedTrailer, doorIdx, false)
            Wait(500)
        end
        Bridge.Notify('Debug', 'Test abgeschlossen!', 'success')
    end)
end

-- ============================================================
-- DEBUG HUD
-- ============================================================

local function ShowDebugHUD(trailerConfig)
    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    local value = adjustmentMode == 'position' and slot.offset or slot.rotation

    lib.showTextUI(
        ('**🔧 Debug Mode v5.0**  \n' ..
        '**Trailer:** %s  \n' ..
        '**Slot:** %d/%d (ID: %d)  \n' ..
        '**Modus:** `%s` | **Achse:** `%s`  \n' ..
        '**Werte:** %.2f, %.2f, %.2f  \n' ..
        '**Step:** %.2f | **Undo:** %d  \n' ..
        '\n' ..
        '🎯 **Quick:**  \n' ..
        '[F] Snap to Vehicle  \n' ..
        '[T] Test-Vehicle spawnen  \n' ..
        '[R] Rampe testen  \n' ..
        '\n' ..
        '🔧 **Edit:**  \n' ..
        '[G] Slot wechseln  \n' ..
        '[M] Pos/Rot | [X/C/V] Achse  \n' ..
        '[E/Q] +/- Wert | [1/2/3] Step  \n' ..
        '\n' ..
        '📑 **Slots:**  \n' ..
        '[+] Add | [-] Remove  \n' ..
        '[K] Duplicate | [J] Mirror  \n' ..
        '\n' ..
        '⏪ **History:**  \n' ..
        '[Z] Undo | [Y] Redo  \n' ..
        '\n' ..
        '[H] Hauptmenü | [B] Export | [N] Beenden')
        :format(
            trailerConfig.label,
            selectedSlot, #trailerConfig.slots, slot.id,
            adjustmentMode, adjustmentAxis:upper(),
            value.x, value.y, value.z,
            adjustmentStep, #undoStack
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

    if trailerConfig.ramp then
        output = output .. ('    ramp = {\n')
        output = output .. ('        enabled = %s,\n'):format(tostring(trailerConfig.ramp.enabled))
        output = output .. ('        doorIndex = %d,\n'):format(trailerConfig.ramp.doorIndex or 5)
        output = output .. ('        openTime = %d,\n'):format(trailerConfig.ramp.openTime or 500)
        output = output .. ('    },\n')
    end

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
-- MAIN MENU
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

    local options = {
        {
            title = ('🚛 %s'):format(trailerConfig.label),
            description = ('Slots: %d | Aktuell: Slot %d'):format(
                #trailerConfig.slots,
                trailerConfig.slots[selectedSlot] and trailerConfig.slots[selectedSlot].id or 0
            ),
            disabled = true,
        }
    }

    -- Slot List
    for i, slot in ipairs(trailerConfig.slots) do
        local marker = (i == selectedSlot) and '✅ ' or '   '
        options[#options + 1] = {
            title = ('%sSlot %d'):format(marker, slot.id),
            description = ('Off: %.2f, %.2f, %.2f | Rot Z: %.0f°'):format(
                slot.offset.x, slot.offset.y, slot.offset.z, slot.rotation.z
            ),
            icon = 'fa-solid fa-cube',
            onSelect = function()
                selectedSlot = i
                lib.showContext('vehicle_loader_main')
            end,
        }
    end

    options[#options + 1] = { title = '──── 🎯 Quick Actions ────', disabled = true }

    options[#options + 1] = {
        title = '🎯 Snap to Vehicle',
        description = 'Übernimmt Position des nächsten Fahrzeugs',
        icon = 'fa-solid fa-bullseye',
        onSelect = function() SnapSlotToCurrentVehicle() SetTimeout(300, OpenMainMenu) end,
    }

    options[#options + 1] = {
        title = '🚗 Test-Vehicle spawnen',
        description = 'Wähle ein Vehicle zum Testen',
        icon = 'fa-solid fa-car',
        menu = 'vehicle_loader_testveh',
    }

    options[#options + 1] = {
        title = '🚪 Rampe testen',
        description = 'Öffnet/Schließt die Rampe',
        icon = 'fa-solid fa-door-open',
        onSelect = function() TestRamp() SetTimeout(300, OpenMainMenu) end,
    }

    options[#options + 1] = {
        title = '🔍 Door-Index ermitteln',
        description = 'Testet Door 0-6 automatisch',
        icon = 'fa-solid fa-magnifying-glass',
        onSelect = function() AutoDetectRampDoor() end,
    }

    options[#options + 1] = { title = '──── 📑 Slot Manage ────', disabled = true }

    options[#options + 1] = {
        title = '➕ Neuer Slot',
        icon = 'fa-solid fa-plus',
        onSelect = function() AddNewSlot() SetTimeout(300, OpenMainMenu) end,
    }

    options[#options + 1] = {
        title = '📋 Slot duplizieren',
        description = 'Kopiert aktuellen Slot',
        icon = 'fa-solid fa-copy',
        onSelect = function() DuplicateCurrentSlot() SetTimeout(300, OpenMainMenu) end,
    }

    options[#options + 1] = {
        title = '🪞 Slot spiegeln (L/R)',
        description = 'Spiegelt X-Achse für symmetrische Paare',
        icon = 'fa-solid fa-right-left',
        onSelect = function() MirrorCurrentSlot() SetTimeout(300, OpenMainMenu) end,
    }

    if #trailerConfig.slots > 1 then
        options[#options + 1] = {
            title = '🗑️ Slot löschen',
            description = ('Löscht Slot %d'):format(trailerConfig.slots[selectedSlot].id),
            icon = 'fa-solid fa-trash',
            onSelect = function()
                local confirmed = lib.alertDialog({
                    header = 'Slot löschen?',
                    content = ('Slot %d wirklich löschen?'):format(trailerConfig.slots[selectedSlot].id),
                    cancel = true,
                })
                if confirmed == 'confirm' then RemoveCurrentSlot() end
                SetTimeout(300, OpenMainMenu)
            end,
        }
    end

    options[#options + 1] = { title = '──── ⏪ History ────', disabled = true }

    options[#options + 1] = {
        title = ('↩️ Undo (%d)'):format(#undoStack),
        description = 'Letzte Änderung rückgängig',
        icon = 'fa-solid fa-rotate-left',
        disabled = #undoStack == 0,
        onSelect = function() Undo(trailerConfig) SetTimeout(300, OpenMainMenu) end,
    }

    options[#options + 1] = {
        title = ('↪️ Redo (%d)'):format(#redoStack),
        description = 'Rückgängig wiederherstellen',
        icon = 'fa-solid fa-rotate-right',
        disabled = #redoStack == 0,
        onSelect = function() Redo(trailerConfig) SetTimeout(300, OpenMainMenu) end,
    }

    options[#options + 1] = { title = '──── ✏️ Edit ────', disabled = true }

    options[#options + 1] = {
        title = '✏️ Werte manuell eingeben',
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
                SaveUndoState(trailerConfig)
                slot.offset = vector3(input[1] or 0, input[2] or 0, input[3] or 0)
                slot.rotation = vector3(0, 0, input[4] or 0)
                Bridge.Notify('Debug', 'Werte aktualisiert!', 'success')
            end

            SetTimeout(300, OpenMainMenu)
        end,
    }

    options[#options + 1] = { title = '──── 💾 Export ────', disabled = true }

    options[#options + 1] = {
        title = '📋 Config exportieren',
        description = 'In Clipboard + Console',
        icon = 'fa-solid fa-copy',
        onSelect = function() PrintTrailerConfig(trailerConfig) end,
    }

    options[#options + 1] = {
        title = '🚪 Debug beenden',
        icon = 'fa-solid fa-xmark',
        onSelect = function() debugMode = false end,
    }

    -- Test-Vehicle Submenu
    local testVehOptions = {}
    for _, model in ipairs(TestVehicles) do
        testVehOptions[#testVehOptions + 1] = {
            title = model,
            icon = 'fa-solid fa-car',
            onSelect = function() SpawnTestVehicle(model) SetTimeout(300, OpenMainMenu) end,
        }
    end
    testVehOptions[#testVehOptions + 1] = {
        title = '🗑️ Test-Vehicle löschen',
        icon = 'fa-solid fa-trash',
        onSelect = function() DeleteTestVehicle() SetTimeout(300, OpenMainMenu) end,
    }

    lib.registerContext({
        id = 'vehicle_loader_testveh',
        title = 'Test-Vehicle wählen',
        menu = 'vehicle_loader_main',
        options = testVehOptions,
    })

    lib.registerContext({
        id = 'vehicle_loader_main',
        title = '🔧 Vehicle Loader Debug',
        options = options,
    })

    lib.showContext('vehicle_loader_main')
end

-- ============================================================
-- INPUT HANDLER
-- ============================================================

local function HandleDebugInput(trailerConfig)
    -- H - Hauptmenü
    if IsControlJustReleased(0, 74) then OpenMainMenu() end

    -- G - Slot wechseln
    if IsControlJustReleased(0, 47) then
        selectedSlot = selectedSlot + 1
        if selectedSlot > #trailerConfig.slots then selectedSlot = 1 end
    end

    -- M - Mode
    if IsControlJustReleased(0, 244) then
        adjustmentMode = adjustmentMode == 'position' and 'rotation' or 'position'
    end

    -- Achse
    if IsControlJustReleased(0, 73) then adjustmentAxis = 'x'
    elseif IsControlJustReleased(0, 26) then adjustmentAxis = 'y'
    elseif IsControlJustReleased(0, 71) then adjustmentAxis = 'z'
    end

    -- E/Q - Adjust
    if IsControlPressed(0, 38) then AdjustSlot(trailerConfig, adjustmentStep) end
    if IsControlPressed(0, 44) then AdjustSlot(trailerConfig, -adjustmentStep) end

    -- 1/2/3 - Step
    if IsControlJustReleased(0, 157) then adjustmentStep = 0.05
    elseif IsControlJustReleased(0, 158) then adjustmentStep = 0.1
    elseif IsControlJustReleased(0, 160) then adjustmentStep = 0.5
    end

    -- F - SNAP
    if IsControlJustReleased(0, 23) then SnapSlotToCurrentVehicle() end

    -- T - Test Vehicle
    if IsControlJustReleased(0, 245) then -- T
        SpawnTestVehicle(TestVehicles[math.random(#TestVehicles)])
    end

    -- R - Rampe Test
    if IsControlJustReleased(0, 45) then TestRamp() end

    -- Slot Management
    if IsControlJustReleased(0, 84) then AddNewSlot() end       -- +
    if IsControlJustReleased(0, 82) then RemoveCurrentSlot() end -- -
    if IsControlJustReleased(0, 311) then DuplicateCurrentSlot() end -- K
    if IsControlJustReleased(0, 246) then MirrorCurrentSlot() end -- J

    -- Undo / Redo
    if IsControlJustReleased(0, 20) then Undo(trailerConfig) end -- Z
    if IsControlJustReleased(0, 246) then Redo(trailerConfig) end -- Y

    -- B - Export
    if IsControlJustReleased(0, 29) then PrintTrailerConfig(trailerConfig) end

    -- N - Beenden
    if IsControlJustReleased(0, 249) then debugMode = false end
end

-- ============================================================
-- START / STOP
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
    undoStack = {}
    redoStack = {}

    exports.vehicle_loader:ToggleZoneDebug(true)
    Bridge.Notify('Debug', 'Debug v5.0 aktiviert! [H] Menü, [F] Snap, [T] Test-Vehicle', 'success')

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

        -- Cleanup
        exports.vehicle_loader:ToggleZoneDebug(false)
        lib.hideTextUI()
        DeleteTestVehicle()
        Bridge.Notify('Debug', 'Debug Mode beendet!', 'info')
    end)
end

-- ============================================================
-- COMMANDS
-- ============================================================

if Config.Global.DebugMode then
    RegisterCommand('debugloader', function() StartDebugMode() end, false)
    RegisterCommand('debugmenu', function()
        if not selectedTrailer then selectedTrailer = FindNearestTrailer() end
        OpenMainMenu()
    end, false)
    RegisterCommand('debugsnap', function()
        if not selectedTrailer then selectedTrailer = FindNearestTrailer() end
        SnapSlotToCurrentVehicle()
    end, false)
    RegisterCommand('debugstop', function()
        debugMode = false
        exports.vehicle_loader:ToggleZoneDebug(false)
        lib.hideTextUI()
        DeleteTestVehicle()
    end, false)

    lib.addKeybind({
        name = 'debugloader_toggle',
        description = 'Vehicle Loader Debug',
        defaultKey = 'F7',
        onPressed = function()
            if debugMode then debugMode = false else StartDebugMode() end
        end,
    })

    lib.print.info('[Vehicle Loader Debug] System v5.0 geladen!')
end
