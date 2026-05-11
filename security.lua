-- Vehicle Loader Security Module
-- Server-Side Validation, Rate Limiting, Entity Checks

if not IsDuplicityVersion() then return end

Security = {}

-- ============================================================
-- RATE LIMITING
-- ============================================================

local RateLimits = {} -- source -> { lastAction, count }

local DEFAULT_COOLDOWN = 1000  -- 1s zwischen Aktionen
local SPAM_THRESHOLD = 5        -- Max 5 Aktionen in 5s
local SPAM_WINDOW = 5000        -- 5s Window

---@param source number
---@param action string
---@return boolean allowed
function Security.CheckRateLimit(source, action)
    local now = GetGameTimer()
    local key = ('%s:%s'):format(source, action)

    if not RateLimits[key] then
        RateLimits[key] = {
            lastAction = now,
            count = 1,
            windowStart = now,
        }
        return true
    end

    local data = RateLimits[key]

    -- Cooldown Check
    if (now - data.lastAction) < DEFAULT_COOLDOWN then
        return false
    end

    -- Spam Window Check
    if (now - data.windowStart) > SPAM_WINDOW then
        -- Reset window
        data.count = 1
        data.windowStart = now
    else
        data.count = data.count + 1
        if data.count > SPAM_THRESHOLD then
            return false -- Spam detected
        end
    end

    data.lastAction = now
    return true
end

-- Cleanup on disconnect
AddEventHandler('playerDropped', function()
    local source = source
    for key, _ in pairs(RateLimits) do
        if key:find(('^%d+:'):format(source)) then
            RateLimits[key] = nil
        end
    end
end)

-- ============================================================
-- ENTITY VALIDATION
-- ============================================================

---@param entity number
---@return boolean
function Security.IsValidEntity(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

---@param netId number
---@return number|nil entity
function Security.GetValidEntityFromNetId(netId)
    if not netId or netId == 0 then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not Security.IsValidEntity(entity) then return nil end

    return entity
end

---@param source number
---@param entity number
---@param maxDistance number
---@return boolean
function Security.IsPlayerNearEntity(source, entity, maxDistance)
    maxDistance = maxDistance or 10.0

    local ped = GetPlayerPed(source)
    if not Security.IsValidEntity(ped) then return false end

    local pedCoords = GetEntityCoords(ped)
    local entityCoords = GetEntityCoords(entity)
    local distance = #(pedCoords - entityCoords)

    return distance <= maxDistance
end

-- Comprehensive Validation für Loading
---@param source number
---@param vehicleNet number
---@param trailerNet number
---@return boolean valid, string|nil reason
function Security.ValidateLoadAction(source, vehicleNet, trailerNet)
    -- Rate Limit
    if not Security.CheckRateLimit(source, 'load') then
        return false, 'rate_limit'
    end

    -- Entities valid?
    local vehicle = Security.GetValidEntityFromNetId(vehicleNet)
    if not vehicle then return false, 'invalid_vehicle' end

    local trailer = Security.GetValidEntityFromNetId(trailerNet)
    if not trailer then return false, 'invalid_trailer' end

    -- Spieler in der Nähe von beiden?
    if not Security.IsPlayerNearEntity(source, vehicle, 15.0) then
        return false, 'too_far_vehicle'
    end

    if not Security.IsPlayerNearEntity(source, trailer, 15.0) then
        return false, 'too_far_trailer'
    end

    -- Vehicle muss sich von Trailer unterscheiden
    if vehicle == trailer then return false, 'same_entity' end

    -- Routing Bucket Check (Spieler und Entities müssen im gleichen Bucket sein)
    local playerBucket = GetPlayerRoutingBucket(source)
    local vehicleBucket = GetEntityRoutingBucket(vehicle)
    local trailerBucket = GetEntityRoutingBucket(trailer)

    if playerBucket ~= vehicleBucket or playerBucket ~= trailerBucket then
        return false, 'routing_bucket_mismatch'
    end

    return true, nil
end

---@param source number
---@param trailerNet number
---@return boolean valid, string|nil reason
function Security.ValidateUnloadAction(source, trailerNet)
    if not Security.CheckRateLimit(source, 'unload') then
        return false, 'rate_limit'
    end

    local trailer = Security.GetValidEntityFromNetId(trailerNet)
    if not trailer then return false, 'invalid_trailer' end

    if not Security.IsPlayerNearEntity(source, trailer, 15.0) then
        return false, 'too_far_trailer'
    end

    local playerBucket = GetPlayerRoutingBucket(source)
    local trailerBucket = GetEntityRoutingBucket(trailer)

    if playerBucket ~= trailerBucket then
        return false, 'routing_bucket_mismatch'
    end

    return true, nil
end

print('^2[Vehicle Loader Security]^7 Security Module geladen!')
