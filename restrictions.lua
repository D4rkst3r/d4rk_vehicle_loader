-- Vehicle Loader - Restrictions Module (CLIENT-ONLY)
-- Vehicle Class & Size Validation
--
-- WICHTIG: GetVehicleClass und GetModelDimensions sind CLIENT-NATIVES.
-- Server-Side Check passiert via vehicleType (siehe server.lua)

Restrictions = {}

-- ============================================================
-- CLIENT-SIDE: Vollständiger Check (Class + Size)
-- ============================================================

---@param vehicle number
---@param trailerConfig TrailerConfig
---@return boolean allowed, string|nil reason
function Restrictions.IsVehicleAllowed(vehicle, trailerConfig)
    if not vehicle or vehicle == 0 then
        return false, 'invalid_vehicle'
    end

    -- GetVehicleClass ist CLIENT-only
    if IsDuplicityVersion() then
        -- Server: keine Class-Detection möglich
        -- → Server akzeptiert alles, Client macht den Check
        return true, nil
    end

    local vehicleClass = GetVehicleClass(vehicle)

    -- Global Blacklist (immer geblockt)
    if Config.BlacklistedClasses and Config.BlacklistedClasses[vehicleClass] then
        return false, 'class_blacklisted_global'
    end

    -- Trailer-spezifische Restrictions
    if not trailerConfig.restrictions then
        return true, nil
    end

    local r = trailerConfig.restrictions

    -- Allowed Classes (Whitelist)
    if r.allowedClasses then
        local found = false
        for _, allowedClass in ipairs(r.allowedClasses) do
            if allowedClass == vehicleClass then
                found = true
                break
            end
        end

        if not found then
            return false, 'class_not_allowed'
        end
    end

    -- Blacklisted Classes (zusätzlich zu Global)
    if r.blacklistedClasses then
        for _, blacklistedClass in ipairs(r.blacklistedClasses) do
            if blacklistedClass == vehicleClass then
                return false, 'class_blacklisted'
            end
        end
    end

    -- Size Check (Client-side via GetModelDimensions)
    if r.maxLength then
        local min, max = GetModelDimensions(GetEntityModel(vehicle))
        local length = max.y - min.y
        if length > r.maxLength then
            return false, 'too_large'
        end
    end

    return true, nil
end

-- ============================================================
-- SERVER-SIDE: Type-based Check (ohne GetVehicleClass)
-- ============================================================
-- Server kann nur GetVehicleType nutzen ("automobile", "bike", "heli", etc.)

---@param vehicleType string
---@return boolean blocked
function Restrictions.IsTypeBlockedServerSide(vehicleType)
    -- Server-side check: Helis/Planes/Boats grundsätzlich blocken
    -- (diese sind in der Default-Blacklist)
    local blockedTypes = {
        ['heli'] = true,        -- Class 15
        ['plane'] = true,       -- Class 16
        ['boat'] = true,        -- Class 14
        ['train'] = true,       -- Class 21
        ['submarine'] = true,
    }

    return blockedTypes[vehicleType] == true
end

-- ============================================================
-- HUMAN-READABLE CLASS NAMES
-- ============================================================

-- Vehicle Classes (FiveM Native: GetVehicleClass, Hash: 0x29439776AAA00A62)
-- Hinweis: GetVehicleClass ist nur CLIENT-Side verfügbar
local ClassNames = {
    [0] = 'Compacts',
    [1] = 'Sedans',
    [2] = 'SUVs',
    [3] = 'Coupes',
    [4] = 'Muscle',
    [5] = 'Sports Classics',
    [6] = 'Sports',
    [7] = 'Super',
    [8] = 'Motorräder',
    [9] = 'Off-road',
    [10] = 'Industrial',
    [11] = 'Utility',
    [12] = 'Vans',
    [13] = 'Fahrräder',
    [14] = 'Boote',
    [15] = 'Helikopter',
    [16] = 'Flugzeuge',
    [17] = 'Service',
    [18] = 'Notfall',
    [19] = 'Militär',
    [20] = 'Kommerziell',
    [21] = 'Züge',
    [22] = 'Open Wheel',  -- F1 / Formula Cars
}

---@param classId number
---@return string
function Restrictions.GetClassName(classId)
    return ClassNames[classId] or 'Unbekannt'
end

if not IsDuplicityVersion() then
    print('^2[Vehicle Loader Restrictions]^7 Restrictions Module geladen (Client)')
else
    print('^2[Vehicle Loader Restrictions]^7 Restrictions Module geladen (Server)')
end
