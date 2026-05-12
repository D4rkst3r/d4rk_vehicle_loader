-- Vehicle Loader Debug System v6.0
-- Modern NUI UI mit Glassmorphism Design

local debugMode = false
local selectedTrailer = nil
local selectedSlot = 1
local adjustmentMode = 'position'
local adjustmentStep = 0.1
local lastAdjustTime = 0
local ADJUST_COOLDOWN = 100

-- Undo/Redo
local undoStack = {}
local redoStack = {}
local MAX_UNDO = 20

-- Test-Vehicle
local testVehicle = nil

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
    redoStack = {}
end

-- ============================================================
-- NUI COMMUNICATION
-- ============================================================

local function SendNUIUpdate()
    if not selectedTrailer or not DoesEntityExist(selectedTrailer) then return end

    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    -- Build slots data for UI
    local slotsData = {}
    local occupiedSlots = StatebagAPI.GetTrailerSlots(selectedTrailer) or {}

    for _, s in ipairs(trailerConfig.slots) do
        slotsData[#slotsData + 1] = {
            id = s.id,
            offset = { x = s.offset.x, y = s.offset.y, z = s.offset.z },
            rotation = { x = s.rotation.x, y = s.rotation.y, z = s.rotation.z },
            occupied = occupiedSlots[tostring(s.id)] ~= nil,
        }
    end

    SendNUIMessage({
        type = 'update',
        trailerLabel = trailerConfig.label,
        currentSlot = selectedSlot,
        totalSlots = #trailerConfig.slots,
        slotId = slot.id,
        values = { x = slot.offset.x, y = slot.offset.y, z = slot.offset.z },
        rotation = { x = slot.rotation.x, y = slot.rotation.y, z = slot.rotation.z },
        slotType = slot.type or 'car',  -- ⭐ Aktueller Type für UI
        undoCount = #undoStack,
        redoCount = #redoStack,
        slots = slotsData,
    })
end

local function OpenNUI()
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'show' })
    SendNUIUpdate()
end

local function CloseNUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'hide' })
end

-- ============================================================
-- ACTIONS
-- ============================================================

local function AdjustSlot(axis, delta)
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    local target = adjustmentMode == 'position' and slot.offset or slot.rotation
    local round = function(v) return math.floor(v * 100 + 0.5) / 100 end

    local newVec = vector3(
        round(target.x + (axis == 'x' and delta or 0)),
        round(target.y + (axis == 'y' and delta or 0)),
        round(target.z + (axis == 'z' and delta or 0))
    )

    if adjustmentMode == 'position' then
        slot.offset = newVec
    else
        slot.rotation = newVec
    end

    -- Live Zone Update
    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()
end

local function ApplyValues(mode, x, y, z)
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    SaveUndoState(trailerConfig)

    local newVec = vector3(
        tonumber(x) or 0,
        tonumber(y) or 0,
        tonumber(z) or 0
    )

    if mode == 'position' then
        slot.offset = newVec
    else
        slot.rotation = newVec
    end

    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()
    Bridge.Notify('Debug', 'Werte angewendet!', 'success')
end

local function SnapToVehicle()
    if not selectedTrailer or not DoesEntityExist(selectedTrailer) then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    local sourceVehicle = nil
    local pedCoords = GetEntityCoords(cache.ped)

    if IsPedInAnyVehicle(cache.ped, false) then
        local veh = cache.vehicle or GetVehiclePedIsIn(cache.ped, false)
        if veh ~= selectedTrailer then sourceVehicle = veh end
    end

    if not sourceVehicle then
        local vehicles = GetGamePool('CVehicle')
        local nearestDist = 10.0
        for _, v in ipairs(vehicles) do
            if v ~= selectedTrailer and v ~= testVehicle and IsEntityAVehicle(v) then
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
    local rotDiff = vehHeading - trailerHeading
    while rotDiff > 180 do rotDiff = rotDiff - 360 end
    while rotDiff < -180 do rotDiff = rotDiff + 360 end

    slot.offset = CalculateOffsetFromWorld(selectedTrailer, vehCoords)
    slot.rotation = vector3(0.0, 0.0, math.floor(rotDiff * 100) / 100)

    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()

    Bridge.Notify('Debug', ('Slot %d gesnapped!'):format(slot.id), 'success')
end

local function Undo()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig or #undoStack == 0 then
        Bridge.Notify('Debug', 'Nichts zum Rückgängig machen!', 'warning')
        return
    end

    table.insert(redoStack, DeepCopySlots(trailerConfig.slots))
    trailerConfig.slots = table.remove(undoStack)

    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()
    Bridge.Notify('Debug', 'Undo!', 'info')
end

local function Redo()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig or #redoStack == 0 then
        Bridge.Notify('Debug', 'Nichts zum Wiederherstellen!', 'warning')
        return
    end

    table.insert(undoStack, DeepCopySlots(trailerConfig.slots))
    trailerConfig.slots = table.remove(redoStack)

    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()
    Bridge.Notify('Debug', 'Redo!', 'info')
end

local function AddSlot()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    SaveUndoState(trailerConfig)

    local maxId = 0
    for _, slot in ipairs(trailerConfig.slots) do
        if slot.id > maxId then maxId = slot.id end
    end

    table.insert(trailerConfig.slots, {
        id = maxId + 1,
        offset = vector3(0.0, -3.5, 1.0),
        rotation = vector3(0.0, 0.0, 0.0),
    })
    trailerConfig.maxVehicles = #trailerConfig.slots
    selectedSlot = #trailerConfig.slots

    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()
    Bridge.Notify('Debug', ('Slot %d hinzugefügt!'):format(maxId + 1), 'success')
end

local function DuplicateSlot()
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

    table.insert(trailerConfig.slots, {
        id = maxId + 1,
        offset = vector3(source.offset.x, source.offset.y - 1.0, source.offset.z),
        rotation = vector3(source.rotation.x, source.rotation.y, source.rotation.z),
    })
    trailerConfig.maxVehicles = #trailerConfig.slots
    selectedSlot = #trailerConfig.slots

    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()
    Bridge.Notify('Debug', 'Slot dupliziert!', 'success')
end

local function MirrorSlot()
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

    table.insert(trailerConfig.slots, {
        id = maxId + 1,
        offset = vector3(-source.offset.x, source.offset.y, source.offset.z),
        rotation = vector3(source.rotation.x, source.rotation.y, -source.rotation.z),
    })
    trailerConfig.maxVehicles = #trailerConfig.slots
    selectedSlot = #trailerConfig.slots

    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()
    Bridge.Notify('Debug', 'Slot gespiegelt!', 'success')
end

local function RemoveSlot()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig or #trailerConfig.slots <= 1 then
        Bridge.Notify('Debug', 'Mindestens 1 Slot muss bleiben!', 'error')
        return
    end

    SaveUndoState(trailerConfig)
    table.remove(trailerConfig.slots, selectedSlot)
    trailerConfig.maxVehicles = math.max(1, #trailerConfig.slots)

    if selectedSlot > #trailerConfig.slots then
        selectedSlot = #trailerConfig.slots
    end

    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()
    Bridge.Notify('Debug', 'Slot entfernt!', 'info')
end

local function TestRamp()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig or not trailerConfig.ramp then
        Bridge.Notify('Debug', 'Keine Rampe konfiguriert!', 'error')
        return
    end

    local doorIndex = trailerConfig.ramp.doorIndex or 5
    local currentRatio = GetVehicleDoorAngleRatio(selectedTrailer, doorIndex)

    if currentRatio < 0.1 then
        Effects.OpenRamp(selectedTrailer, doorIndex)
        Bridge.Notify('Debug', ('Rampe geöffnet (Door %d)'):format(doorIndex), 'success')
    else
        Effects.CloseRamp(selectedTrailer, doorIndex)
        Bridge.Notify('Debug', 'Rampe geschlossen', 'info')
    end
end

local function DetectRampDoor()
    if not selectedTrailer then return end
    Bridge.Notify('Debug', 'Teste Door 0-6...', 'info')

    CreateThread(function()
        for doorIdx = 0, 6 do
            SetVehicleDoorOpen(selectedTrailer, doorIdx, false, false)
            Bridge.Notify('Debug', ('Door %d offen'):format(doorIdx), 'info')
            Wait(2000)
            SetVehicleDoorShut(selectedTrailer, doorIdx, false)
            Wait(500)
        end
        Bridge.Notify('Debug', 'Test abgeschlossen!', 'success')
    end)
end

local function ExportConfig()
    if not selectedTrailer then return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then return end

    local output = ('\n^2=== %s ===^7\n{\n'):format(trailerConfig.label)
    output = output .. ('    model = "%s",\n'):format(trailerConfig.model)
    output = output .. ('    label = "%s",\n'):format(trailerConfig.label)
    output = output .. ('    maxVehicles = %d,\n'):format(trailerConfig.maxVehicles)

    if trailerConfig.ramp then
        output = output .. ('    ramp = { enabled = %s, doorIndex = %d, openTime = %d },\n'):format(
            tostring(trailerConfig.ramp.enabled),
            trailerConfig.ramp.doorIndex or 5,
            trailerConfig.ramp.openTime or 500
        )
    end

    output = output .. ('    slots = {\n')
    for _, slot in ipairs(trailerConfig.slots) do
        local typeStr = slot.type and (' type = "%s",'):format(slot.type) or ''
        local sizeStr = slot.size and (' size = vec3(%.2f, %.2f, %.2f),'):format(
            slot.size.x, slot.size.y, slot.size.z
        ) or ''

        output = output .. ('        { id = %d,%s%s offset = vector3(%.2f, %.2f, %.2f), rotation = vector3(%.2f, %.2f, %.2f) },\n'):format(
            slot.id, typeStr, sizeStr,
            slot.offset.x, slot.offset.y, slot.offset.z,
            slot.rotation.x, slot.rotation.y, slot.rotation.z
        )
    end
    output = output .. ('    }\n}\n')

    print(output)
    lib.setClipboard(output)
    Bridge.Notify('Debug', 'Config in Clipboard!', 'success')
end

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
    local spawnX = pedCoords.x + math.cos(math.rad(heading + 90)) * 5
    local spawnY = pedCoords.y + math.sin(math.rad(heading + 90)) * 5

    testVehicle = CreateVehicle(model, spawnX, spawnY, pedCoords.z, heading, true, false)
    SetVehicleOnGroundProperly(testVehicle)
    SetModelAsNoLongerNeeded(model)

    Bridge.Notify('Debug', ('Spawned: %s'):format(modelName), 'success')
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
-- NUI CALLBACKS
-- ============================================================

RegisterNUICallback('close', function(_, cb)
    debugMode = false
    cb({})
end)

RegisterNUICallback('selectSlot', function(data, cb)
    selectedSlot = tonumber(data.index) or 1
    SendNUIUpdate()
    cb({})
end)

RegisterNUICallback('setMode', function(data, cb)
    adjustmentMode = data.mode or 'position'
    SendNUIUpdate()
    cb({})
end)

RegisterNUICallback('setStep', function(data, cb)
    adjustmentStep = tonumber(data.step) or 0.1
    cb({})
end)

-- ⭐ Slot-Type ändern (bike/car/suv/truck)
RegisterNUICallback('setSlotType', function(data, cb)
    if not selectedTrailer then cb({}) return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if not trailerConfig then cb({}) return end

    local slot = trailerConfig.slots[selectedSlot]
    if not slot then cb({}) return end

    SaveUndoState(trailerConfig)
    slot.type = data.type
    slot.size = nil  -- Custom size resetten, damit Preset wirkt

    exports.vehicle_loader:ForceRecreateZones(selectedTrailer)
    SendNUIUpdate()
    Bridge.Notify('Debug', ('Slot %d Type: %s'):format(slot.id, data.type), 'success')
    cb({})
end)

RegisterNUICallback('adjust', function(data, cb)
    if not selectedTrailer then cb({}) return end
    local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
    if trailerConfig then SaveUndoState(trailerConfig) end
    AdjustSlot(data.axis, tonumber(data.delta) or 0)
    cb({})
end)

RegisterNUICallback('applyValues', function(data, cb)
    ApplyValues(data.mode, data.x, data.y, data.z)
    cb({})
end)

RegisterNUICallback('snap', function(_, cb) SnapToVehicle() cb({}) end)
RegisterNUICallback('undo', function(_, cb) Undo() cb({}) end)
RegisterNUICallback('redo', function(_, cb) Redo() cb({}) end)
RegisterNUICallback('testRamp', function(_, cb) TestRamp() cb({}) end)
RegisterNUICallback('detectRamp', function(_, cb) DetectRampDoor() cb({}) end)
RegisterNUICallback('export', function(_, cb) ExportConfig() cb({}) end)
RegisterNUICallback('addSlot', function(_, cb) AddSlot() cb({}) end)
RegisterNUICallback('duplicateSlot', function(_, cb) DuplicateSlot() cb({}) end)
RegisterNUICallback('mirrorSlot', function(_, cb) MirrorSlot() cb({}) end)
RegisterNUICallback('removeSlot', function(_, cb) RemoveSlot() cb({}) end)

RegisterNUICallback('spawnTestVehicle', function(data, cb)
    SpawnTestVehicle(data.model)
    cb({})
end)

RegisterNUICallback('deleteTestVehicle', function(_, cb)
    DeleteTestVehicle()
    cb({})
end)

-- ============================================================
-- KEYBOARD SHORTCUTS (im Debug Mode außerhalb der NUI)
-- ============================================================

local function HandleDebugInput()
    -- F - Snap
    if IsControlJustReleased(0, 23) then SnapToVehicle() end

    -- G - Slot wechseln
    if IsControlJustReleased(0, 47) then
        local trailerConfig = GetTrailerConfigByEntity(selectedTrailer)
        if trailerConfig then
            selectedSlot = selectedSlot + 1
            if selectedSlot > #trailerConfig.slots then selectedSlot = 1 end
            SendNUIUpdate()
        end
    end

    -- Z/Y - Undo/Redo
    if IsControlJustReleased(0, 20) then Undo() end
    if IsControlJustReleased(0, 246) then Redo() end

    -- T - Test Vehicle
    if IsControlJustReleased(0, 245) then
        SpawnTestVehicle('adder')
    end

    -- N - Beenden
    if IsControlJustReleased(0, 249) then
        debugMode = false
    end
end

-- ============================================================
-- START / STOP
-- ============================================================

local function StartDebugMode()
    if debugMode then return end

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
    OpenNUI()

    CreateThread(function()
        while debugMode do
            Wait(0)
            if not selectedTrailer or not DoesEntityExist(selectedTrailer) then
                debugMode = false
                break
            end
            HandleDebugInput()
        end

        CloseNUI()
        exports.vehicle_loader:ToggleZoneDebug(false)
        DeleteTestVehicle()
        Bridge.Notify('Debug', 'Debug Mode beendet!', 'info')
    end)
end

-- ============================================================
-- COMMANDS
-- ============================================================

if Config.Global.DebugMode then
    RegisterCommand('debugloader', StartDebugMode, false)

    RegisterCommand('debugstop', function()
        debugMode = false
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

    lib.print.info('[Vehicle Loader Debug] v6.0 NUI geladen!')
end
