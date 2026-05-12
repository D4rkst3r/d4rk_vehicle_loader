-- Vehicle Loader System - Konfiguration (v3.4)
-- Standalone-fähig: ESX / QBCore / QBox

Config = {
    -- Globale Einstellungen
    Global = {
        Locale = 'de',                   -- 'de' oder 'en'

        -- ============================================================
        -- GELD (auf 0 setzen = kein Geld nötig)
        -- ============================================================
        MoneyRequired = 0,               -- Kosten pro Aufladen (0 = kostenlos)
        MoneyAccount = 'cash',           -- 'cash' oder 'bank'

        -- ============================================================
        -- LOADING / UNLOADING
        -- ============================================================
        LoadingTime = 5000,              -- ms zum Aufladen
        UnloadingTime = 3000,            -- ms zum Entladen
        UnloadDistance = 8.0,            -- Meter hinter Anhänger
        ConfirmUnload = false,           -- Bestätigung vor Entladen?
        RefundItemsOnUnload = false,     -- Items beim Entladen zurückgeben?

        -- ============================================================
        -- VISUALS & AUDIO
        -- ============================================================
        EnableAnimations = true,         -- Player-Animationen
        EnableParticles = true,          -- Staub-Effekt beim Entladen
        EnableEffects = true,            -- Sound Effects + Rampe Animation

        -- ============================================================
        -- ANTI-THEFT / OWNER-LOCK
        -- ============================================================
        OwnerOnlyUnload = false,         -- Nur Owner kann entladen?
        AllowJobUnload = true,           -- Job-Kollegen dürfen auch entladen
        AllowAdminUnload = true,         -- Admins dürfen immer entladen

        -- ============================================================
        -- VISUAL SLOT MARKERS
        -- ============================================================
        ShowSlotMarkers = true,          -- 3D Marker über freien Slots
        MarkerType = 'cylinder',         -- 'cylinder', 'arrow', 'cube'
        MarkerColor = {r = 0, g = 255, b = 100, a = 100},
        MarkerSize = 1.0,                -- Größe (1.0 = standard)
        MarkerMaxDistance = 30.0,        -- Anzeigeentfernung in Meter

        -- ============================================================
        -- DEBUG
        -- ============================================================
        DebugMode = true,                -- Debug Commands aktivieren (F7)
    },

    -- ============================================================
    -- STORAGE / PERSISTENCE
    -- ============================================================
    -- Speichert geladene Fahrzeuge in DB, sodass sie Server-Restart überleben
    --
    -- WICHTIG: Setze Enabled = false wenn dein Server bereits ein
    -- eigenes Persistence System für Trailer/Loadings hat!
    Storage = {
        Enabled = true,              -- Persistence aktivieren?
        Provider = 'auto',           -- 'auto', 'oxmysql', 'external'
        MatchByPlate = true,         -- Match Fahrzeuge per Nummernschild (empfohlen)
        RestoreDelay = 5000,         -- ms - Wartezeit vor Restore (für Spawn-Scripts)
    },

    -- ============================================================
    -- JOB-RESTRICTIONS (leer = jeder kann)
    -- ============================================================
    -- Beispiel: nur Mechaniker können aufladen:
    -- Jobs = { ['mechanic'] = true, ['tow_truck'] = true }
    Jobs = {
        -- ['mechanic'] = true,
        -- ['tow_truck'] = true,
    },

    -- ============================================================
    -- ITEMS (leer = keine Items nötig)
    -- ============================================================
    -- Diese Items werden beim Aufladen verbraucht (ox_inventory)
    -- Komplett leer lassen für keine Items: RequiredItems = {}
    RequiredItems = {
        ['tow_rope'] = 1,
        ['tow_strap'] = 2,
    },

    -- ============================================================
    -- VEHICLE RESTRICTIONS (Class-IDs)
    -- ============================================================
    -- Klassen: 0=Compacts, 1=Sedans, 2=SUVs, 3=Coupes, 4=Muscle, 5=Sports Classics,
    --          6=Sports, 7=Super, 8=Motorcycles, 9=Off-road, 10=Industrial,
    --          11=Utility, 12=Vans, 13=Cycles, 14=Boats, 15=Helicopters,
    --          16=Planes, 17=Service, 18=Emergency, 19=Military, 20=Commercial, 21=Trains

    -- Global Blacklist (NIEMALS aufladbar)
    BlacklistedClasses = {
        [14] = true,  -- Boats
        [15] = true,  -- Helicopters
        [16] = true,  -- Planes
        [21] = true,  -- Trains
    },

    -- ============================================================
    -- ANHÄNGER-DEFINITIONEN
    -- ============================================================
    -- Jeder Anhänger kann eigene Slots, Rampe und Restrictions haben.
    -- Du kannst beliebig viele Anhänger-Modelle hinzufügen.
    Trailers = {
        -- Standard Flatbed
        {
            model = 'flatbed',
            label = 'Standard Flatbed',
            maxVehicles = 1,

            -- Rampe (als Trunk-Bone im Modell definiert)
            ramp = {
                enabled = true,         -- Rampe-Animation an?
                doorIndex = 5,          -- 0=FL, 1=FR, 2=RL, 3=RR, 4=Hood, 5=Trunk, 6=Hatch
                openTime = 500,         -- ms bis Auto-Open komplett
            },

            -- Restrictions für DIESEN Anhänger (optional)
            restrictions = {
                allowedClasses = nil,         -- nil = alle erlaubt (außer Global Blacklist)
                -- allowedClasses = {0,1,2,3}, -- Nur Compacts/Sedans/SUVs/Coupes
                blacklistedClasses = nil,      -- zusätzliche Class-Blacklist
                maxLength = nil,               -- max. Fahrzeuglänge in Metern (nil = unbegrenzt)
            },

            slots = {
                {
                    id = 1,
                    offset = vector3(0.0, -2.00, 0.80),
                    rotation = vector3(0.0, 0.0, 0.0),
                }
            }
        },

        -- Custom Flatbed mit 2 Slots
        {
            model = 'flatbed_custom',
            label = 'Custom Flatbed Dual',
            maxVehicles = 2,
            ramp = {
                enabled = true,
                doorIndex = 5,
                openTime = 500,
            },
            restrictions = {
                allowedClasses = nil,
                blacklistedClasses = nil,
                maxLength = nil,
            },
            slots = {
                {
                    id = 1,
                    offset = vector3(-1.5, -2.5, 1.0),
                    rotation = vector3(0.0, 0.0, 0.0),
                },
                {
                    id = 2,
                    offset = vector3(1.5, -5.0, 1.0),
                    rotation = vector3(0.0, 0.0, 0.0),
                }
            }
        },

        -- Beispiel großer Anhänger mit 3 Slots
        {
            model = 'flatbed_large',
            label = 'Large Flatbed Triple',
            maxVehicles = 3,
            ramp = {
                enabled = true,
                doorIndex = 5,
                openTime = 500,
            },
            restrictions = {
                allowedClasses = nil,
                blacklistedClasses = nil,
                maxLength = nil,
            },
            slots = {
                {
                    id = 1,
                    offset = vector3(-2.0, -2.0, 1.0),
                    rotation = vector3(0.0, 0.0, 0.0),
                },
                {
                    id = 2,
                    offset = vector3(0.0, -4.5, 1.0),
                    rotation = vector3(0.0, 0.0, 0.0),
                },
                {
                    id = 3,
                    offset = vector3(2.0, -7.0, 1.0),
                    rotation = vector3(0.0, 0.0, 0.0),
                }
            }
        }
    },
}

-- Helper: Trailer Config finden
function GetTrailerConfig(modelHash)
    for _, trailer in ipairs(Config.Trailers) do
        if GetHashKey(trailer.model) == modelHash then
            return trailer
        end
    end
    return nil
end

-- Helper: Trailer Config by Entity
function GetTrailerConfigByEntity(entity)
    local model = GetEntityModel(entity)
    return GetTrailerConfig(model)
end

-- Helper: Alle Trailer Models
function GetAllTrailerModels()
    local models = {}
    for _, trailer in ipairs(Config.Trailers) do
        table.insert(models, trailer.model)
    end
    return models
end
