fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Vehicle Loader System v3.4 - Restrictions, Anti-Theft, Markers, Statebags, Security'
version '3.4.0'

lua54 'yes'

-- Required Dependencies
dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory'
}

-- Optional Dependencies (auto-detected at runtime):
--   oxmysql      - für Built-in Persistence (Storage.Provider = 'auto')
--   es_extended  - ESX Framework Support
--   qbx_core     - QBox Framework Support (empfohlen)
--   qb-core      - QBCore Framework Support

shared_scripts {
    '@ox_lib/init.lua',
    'types.lua',
    'config.lua',
    'statebags.lua',
    'restrictions.lua'
}

files {
    'locales/de.json',
    'locales/en.json'
}

server_scripts {
    -- Optional: oxmysql wrapper (nur geladen wenn oxmysql installiert)
    '@oxmysql/lib/MySQL.lua',

    -- Bridge System (Framework Detection)
    'bridge/server.lua',

    -- Security Module (Rate Limit, Validation)
    'security.lua',

    -- Storage Adapter (oxmysql/external/disabled)
    'storage/server.lua',

    -- Main Server Logic
    'server.lua',

    -- Public API für andere Resources
    'api/server.lua'
}

client_scripts {
    -- Bridge (Framework Detection)
    'bridge/client.lua',

    -- Effects (Sounds + Ramp Animations)
    'effects.lua',

    -- Main Client Logic
    'client.lua',

    -- Zones (lib.zones + lib.points)
    'zones.lua',

    -- Visual Markers über freien Slots
    'markers.lua',

    -- Debug System (In-Game Slot Editor)
    'debug.lua',

    -- Public API
    'api/client.lua'
}
