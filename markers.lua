-- Vehicle Loader - Visual Slot Markers
-- 3D Markers über freien Slots zur visuellen Orientierung

if IsDuplicityVersion() then return end

local MarkerTypes = {
    cylinder = 1,
    arrow = 21,
    cube = 28,
    sphere = 28,
}

-- Cache für Performance
local activeMarkers = {}

-- ============================================================
-- MARKER DRAWING (Performance-Optimized)
-- ============================================================

CreateThread(function()
    while true do
        if not Config.Global.ShowSlotMarkers then
            Wait(2000)
        else
            local sleep = 1000 -- Wenn kein Marker zu zeichnen, langsamer Loop

            local pedCoords = GetEntityCoords(cache.ped)
            local maxDist = Config.Global.MarkerMaxDistance or 30.0
            local maxDistSquared = maxDist * maxDist -- Squared distance für Performance
            local markerType = MarkerTypes[Config.Global.MarkerType] or 1
            local color = Config.Global.MarkerColor or {r=0, g=255, b=100, a=100}
            local size = Config.Global.MarkerSize or 1.0

            -- Iteriere über aktive Zonen (von zones.lua)
            for trailerNet, _ in pairs(ActiveZones or {}) do
                local trailer = NetworkGetEntityFromNetworkId(trailerNet)
                if trailer and trailer ~= 0 and DoesEntityExist(trailer) then
                    local trailerCoords = GetEntityCoords(trailer)
                    local distVec = pedCoords - trailerCoords
                    local distSquared = distVec.x * distVec.x + distVec.y * distVec.y + distVec.z * distVec.z

                    if distSquared < maxDistSquared then
                        sleep = 0 -- Active rendering nötig

                        local trailerConfig = GetTrailerConfigByEntity(trailer)
                        if trailerConfig then
                            -- Get occupied slots via Statebag
                            local occupiedSlots = StatebagAPI.GetTrailerSlots(trailer)

                            local trailerHeading = GetEntityHeading(trailer)
                            local radians = math.rad(trailerHeading)

                            for _, slot in ipairs(trailerConfig.slots) do
                                -- Nur FREIE Slots zeigen
                                if not occupiedSlots[tostring(slot.id)] then

                                    local offsetX = slot.offset.x * math.cos(radians) - slot.offset.y * math.sin(radians)
                                    local offsetY = slot.offset.x * math.sin(radians) + slot.offset.y * math.cos(radians)

                                    local mx = trailerCoords.x + offsetX
                                    local my = trailerCoords.y + offsetY
                                    local mz = trailerCoords.z + slot.offset.z + 1.5

                                    -- Draw Marker
                                    DrawMarker(
                                        markerType,
                                        mx, my, mz,
                                        0.0, 0.0, 0.0,
                                        0.0, 0.0, 0.0,
                                        1.5 * size, 1.5 * size, 0.8 * size,
                                        color.r, color.g, color.b, color.a,
                                        true,           -- bobUpAndDown
                                        false,          -- faceCamera
                                        2,
                                        false,          -- rotate
                                        nil, nil, false
                                    )
                                end
                            end
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end
end)

-- ============================================================
-- TOGGLE COMMAND
-- ============================================================

RegisterCommand('togglemarkers', function()
    Config.Global.ShowSlotMarkers = not Config.Global.ShowSlotMarkers
    Bridge.Notify('Loader',
        ('Slot-Markers: %s'):format(Config.Global.ShowSlotMarkers and 'ON' or 'OFF'),
        'info'
    )
end, false)

-- Export für andere Resources
exports('ToggleMarkers', function(state)
    if state ~= nil then
        Config.Global.ShowSlotMarkers = state
    else
        Config.Global.ShowSlotMarkers = not Config.Global.ShowSlotMarkers
    end
    return Config.Global.ShowSlotMarkers
end)

print('^2[Vehicle Loader Markers]^7 Marker System geladen!')
