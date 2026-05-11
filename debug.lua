-- Vehicle Loader Debug System (v3.0)
-- Nutzt lib.zones für native ox_lib Visualisierung

local debugMode = false
local selectedTrailer = nil
local selectedSlot = 1
local adjustmentMode = 'position'
local adjustmentAxis = 'x'
local adjustmentStep = 0.1

-- ============================================================
-- HELPERS
-- ============================================================

local function FindNearestTrailer()
    local vehicles = GetGamePool('CVehicle')
    local nearestDist = 50.0
    local nearestTrailer = nil

    for _, vehicle in ipairs(vehicles) do
        if GetTrailerConfigByEntity(vehicle) then
            local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle))
            if dist < nearestDist then
                nearestDist = dist
                nearestTrailer = vehicle
            end
        end
    end

    return nearestTrailer
end

local function AdjustSlot(trailerConfig, axisDelta)
    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    if adjustmentMode == 'position' then
        local current = slot.offset
        slot.offset = vector3(
            current.x + (adjustmentAxis == 'x' and axisDelta or 0),
            current.y + (adjustmentAxis == 'y' and axisDelta or 0),
            current.z + (adjustmentAxis == 'z' and axisDelta or 0)
        )
    else
        local current = slot.rotation
        slot.rotation = vector3(
            current.x + (adjustmentAxis == 'x' and axisDelta or 0),
            current.y + (adjustmentAxis == 'y' and axisDelta or 0),
            current.z + (adjustmentAxis == 'z' and axisDelta or 0)
        )
    end
end

-- ============================================================
-- DEBUG HUD
-- ============================================================

local function ShowDebugHUD(trailerConfig)
    local slot = trailerConfig.slots[selectedSlot]
    if not slot then return end

    local value = adjustmentMode == 'position' and slot.offset or slot.rotation

    lib.showTextUI(
        ('**Debug Mode**  \n' ..
        'Trailer: %s  \n' ..
        'Slot: %d/%d  \n' ..
        'Modus: **%s**  \n' ..
        'Achse: **%s**  \n' ..
        'Werte: %.2f, %.2f, %.2f  \n' ..
        'Step: %.2f  \n' ..
        '\n' ..
        '[G] Slot wechseln  \n' ..
        '[M] Position/Rotation  \n' ..
        '[X/C/V] X/Y/Z Achse  \n' ..
        '[E] +Wert | [Q] -Wert  \n' ..
        '[1/2] Step ändern  \n' ..
        '[B] Config kopieren  \n' ..
        '[N] Debug beenden')
        :format(
            trailerConfig.label,
            selectedSlot, #trailerConfig.slots,
            adjustmentMode,
            adjustmentAxis:upper(),
            value.x, value.y, value.z,
            adjustmentStep
        ),
        { position = 'right-center', icon = 'fa-solid fa-wrench' }
    )
end

-- ============================================================
-- PRINT CONFIG
-- ============================================================

local function PrintConfig(trailerConfig)
    local output = ('\n^2=== Trailer Config: %s ===^7\n'):format(trailerConfig.label)
    output = output .. ('{\n    model = "%s",\n    label = "%s",\n    maxVehicles = %d,\n    slots = {\n'):format(
        trailerConfig.model, trailerConfig.label, trailerConfig.maxVehicles
    )

    for _, slot in ipairs(trailerConfig.slots) do
        output = output .. ('        {\n'):format()
        output = output .. ('            id = %d,\n'):format(slot.id)
        output = output .. ('            offset = vector3(%.2f, %.2f, %.2f),\n'):format(
            slot.offset.x, slot.offset.y, slot.offset.z
        )
        output = output .. ('            rotation = vector3(%.2f, %.2f, %.2f),\n'):format(
            slot.rotation.x, slot.rotation.y, slot.rotation.z
        )
        output = output .. ('        },\n'):format()
    end

    output = output .. '    }\n}\n^2================^7\n'

    print(output)
    lib.setClipboard(output)
    Bridge.Notify('Debug', 'Config in F8 Console + Clipboard kopiert!', 'success')
end

-- ============================================================
-- DEBUG INPUT HANDLER
-- ============================================================

local function HandleDebugInput(trailerConfig)
    -- G - Slot wechseln
    if IsControlJustReleased(0, 47) then
        selectedSlot = selectedSlot + 1
        if selectedSlot > #trailerConfig.slots then
            selectedSlot = 1
        end
        Bridge.Notify('Debug', ('Slot %d ausgewählt'):format(selectedSlot), 'info')
    end

    -- M - Mode wechseln
    if IsControlJustReleased(0, 244) then
        adjustmentMode = adjustmentMode == 'position' and 'rotation' or 'position'
        Bridge.Notify('Debug', ('Modus: %s'):format(adjustmentMode), 'info')
    end

    -- X/C/V - Achse wählen
    if IsControlJustReleased(0, 73) then adjustmentAxis = 'x'
    elseif IsControlJustReleased(0, 26) then adjustmentAxis = 'y'
    elseif IsControlJustReleased(0, 71) then adjustmentAxis = 'z'
    end

    -- E - Erhöhen
    if IsControlPressed(0, 38) then
        AdjustSlot(trailerConfig, adjustmentStep)
    end

    -- Q - Verringern
    if IsControlPressed(0, 44) then
        AdjustSlot(trailerConfig, -adjustmentStep)
    end

    -- 1/2 - Step ändern
    if IsControlJustReleased(0, 157) then adjustmentStep = 0.05
    elseif IsControlJustReleased(0, 158) then adjustmentStep = 0.1
    end

    -- B - Save
    if IsControlJustReleased(0, 29) then
        PrintConfig(trailerConfig)
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

    -- Aktiviere ox_lib Zone Debug (zeigt automatisch die Boxen!)
    exports.vehicle_loader:ToggleZoneDebug(true)

    Bridge.Notify('Debug', 'Debug Mode aktiviert! Zonen sind sichtbar.', 'success')

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
        Bridge.Notify('Debug', 'Debug Mode beendet!', 'info')
    end)
end

-- ============================================================
-- SLOT MANAGER MENU (ox_lib Context Menu)
-- ============================================================

local function OpenSlotMenu()
    local trailer = FindNearestTrailer()
    if not trailer then
        Bridge.Notify('Debug', 'Kein Anhänger in der Nähe!', 'error')
        return
    end

    local trailerConfig = GetTrailerConfigByEntity(trailer)
    if not trailerConfig then return end

    local options = {}

    for i, slot in ipairs(trailerConfig.slots) do
        options[#options + 1] = {
            title = ('Slot %d'):format(slot.id),
            description = ('Offset: %.2f, %.2f, %.2f'):format(slot.offset.x, slot.offset.y, slot.offset.z),
            icon = 'fa-solid fa-cube',
            onSelect = function()
                selectedSlot = i
                StartDebugMode()
            end
        }
    end

    options[#options + 1] = {
        title = '──────────────',
        disabled = true,
    }

    options[#options + 1] = {
        title = 'Config kopieren',
        description = 'Aktuelle Werte → Clipboard',
        icon = 'fa-solid fa-copy',
        onSelect = function() PrintConfig(trailerConfig) end
    }

    options[#options + 1] = {
        title = 'Zonen sichtbar machen',
        description = 'Debug-Visualisierung an/aus',
        icon = 'fa-solid fa-eye',
        onSelect = function()
            exports.vehicle_loader:ToggleZoneDebug(true)
            Bridge.Notify('Debug', 'Zonen sichtbar (5s)', 'info')
            SetTimeout(5000, function()
                exports.vehicle_loader:ToggleZoneDebug(false)
            end)
        end
    }

    lib.registerContext({
        id = 'vehicle_loader_debug',
        title = trailerConfig.label,
        options = options
    })

    lib.showContext('vehicle_loader_debug')
end

-- ============================================================
-- COMMANDS
-- ============================================================

if Config.Global.DebugMode then
    RegisterCommand('debugloader', function()
        StartDebugMode()
    end, false)

    RegisterCommand('debugmenu', function()
        OpenSlotMenu()
    end, false)

    RegisterCommand('debugzones', function(_, args)
        local state = args[1] == 'on' or args[1] == 'true' or args[1] == '1'
        exports.vehicle_loader:ToggleZoneDebug(state)
        Bridge.Notify('Debug', ('Zone Debug: %s'):format(state and 'ON' or 'OFF'), 'info')
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

    print('^2[Vehicle Loader Debug]^7 Debug System geladen! /debugloader oder F7')
end
