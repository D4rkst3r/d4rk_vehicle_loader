# Vehicle Loader - Public API Dokumentation

API für andere Resources um mit Vehicle Loader zu interagieren.

---

## 📥 Server Exports

### Daten abfragen

```lua
-- Alle geladenen Fahrzeuge
local loaded = exports.vehicle_loader:GetLoadedVehicles()
-- Returns: { [vehicleNet] = { trailerNet, slotId, owner, loadedAt } }

-- Ist Fahrzeug geladen?
local isLoaded = exports.vehicle_loader:IsVehicleLoaded(vehicleNet)
-- Returns: boolean

-- Fahrzeug-Daten abrufen
local data = exports.vehicle_loader:GetVehicleData(vehicleNet)
-- Returns: { trailerNet, slotId, owner, loadedAt } | nil

-- Alle Fahrzeuge auf einem Anhänger
local vehicles = exports.vehicle_loader:GetVehiclesOnTrailer(trailerNet)
-- Returns: { { vehicleNet, slotId, owner, loadedAt }, ... }

-- Hat Anhänger freie Slots?
local hasFree = exports.vehicle_loader:HasFreeSlots(trailerNet)
-- Returns: boolean

-- Welche Slots sind frei?
local freeSlots = exports.vehicle_loader:GetFreeSlots(trailerNet)
-- Returns: { 1, 3 } -- slot IDs
```

### Aktionen ausführen (Force Functions)

```lua
-- Fahrzeug erzwingen laden (KEIN Items/Geld-Verbrauch!)
local success = exports.vehicle_loader:ForceLoadVehicle(vehicleNet, trailerNet, slotId, source)
-- success: boolean, optionalError

-- Fahrzeug erzwingen entladen
local success = exports.vehicle_loader:ForceUnloadVehicle(vehicleNet)

-- Anhänger komplett leeren
local unloadedCount = exports.vehicle_loader:ForceUnloadAllFromTrailer(trailerNet)
-- Returns: number
```

---

## 📡 Server Events (Hooks)

Andere Resources können diese Events listen:

### `vehicle_loader:server:onVehicleLoaded`
Wird gefeuert wenn ein Fahrzeug aufgeladen wurde.
```lua
AddEventHandler('vehicle_loader:server:onVehicleLoaded', function(vehicleNet, trailerNet, slotId, source)
    print('Fahrzeug ' .. vehicleNet .. ' wurde aufgeladen!')
end)
```

### `vehicle_loader:server:onVehicleUnloaded`
Wird gefeuert wenn ein Fahrzeug entladen wurde.
```lua
AddEventHandler('vehicle_loader:server:onVehicleUnloaded', function(vehicleNet, trailerNet, slotId, owner)
    print('Fahrzeug ' .. vehicleNet .. ' wurde entladen!')
end)
```

### `vehicle_loader:server:onBeforeLoad` (CANCELABLE)
Pre-Load Hook - andere Resources können den Vorgang **blockieren**.
```lua
AddEventHandler('vehicle_loader:server:onBeforeLoad', function(source, vehicleNet, trailerNet, slotId, cancelFunc)
    -- Bedingung prüfen
    if SomeCondition() then
        cancelFunc(true, 'Du darfst hier nicht laden!')
    end
end)
```

### `vehicle_loader:server:onBeforeUnload` (CANCELABLE)
Pre-Unload Hook.
```lua
AddEventHandler('vehicle_loader:server:onBeforeUnload', function(source, vehicleNet, trailerNet, cancelFunc)
    if NotAllowed() then
        cancelFunc(true, 'Entladen verboten!')
    end
end)
```

---

## 📡 Server Trigger Events

Andere Resources können diese Events feuern:

```lua
-- Fahrzeug per Event laden (ohne Validierung)
TriggerEvent('vehicle_loader:api:forceLoad', vehicleNet, trailerNet, slotId)

-- Fahrzeug per Event entladen
TriggerEvent('vehicle_loader:api:forceUnload', vehicleNet)
```

---

## 🔄 Server Callbacks (ox_lib)

```lua
-- Alle geladenen Fahrzeuge abrufen (synchron)
local loaded = lib.callback.await('vehicle_loader:api:getLoadedVehicles', false)

-- Ist Fahrzeug geladen?
local isLoaded = lib.callback.await('vehicle_loader:api:isVehicleLoaded', false, vehicleNet)

-- Trailer Info abrufen
local info = lib.callback.await('vehicle_loader:api:getTrailerInfo', false, trailerNet)
-- Returns: { model, label, maxVehicles, slotCount, loadedCount, hasFreeSlots }
```

---

## 🎨 Effects Exports (Client - v4.0+)

```lua
-- Sounds abspielen
exports.vehicle_loader:PlaySound('truck_brake', coords)
-- Verfügbare Sounds: 'truck_brake', 'load_start', 'load_complete',
--                    'unload_drop', 'mechanical', 'error'

-- Rampe öffnen/schließen
exports.vehicle_loader:OpenTrailerRamp(trailer, doorIndex)
exports.vehicle_loader:CloseTrailerRamp(trailer, doorIndex)

-- Visual Slot Markers togglen
exports.vehicle_loader:ToggleMarkers(state)  -- true/false/nil(toggle)

-- Debug-Zonen togglen
exports.vehicle_loader:ToggleZoneDebug(state)

-- Zone neu erstellen (nach manueller Slot-Änderung)
exports.vehicle_loader:ForceRecreateZones(trailer)
```

## 🛡️ Bridge Exports (Server)

```lua
-- Aktives Framework
local fw = exports.vehicle_loader:GetFramework()
-- Returns: 'qbox', 'esx', 'qbcore', 'standalone'

-- Admin Check (ACE + txAdmin + Framework)
local isAdmin = Bridge.IsAdmin(source)
```

---

## 🎮 Multiplayer Internals (v4.0+)

Das System nutzt diese FiveM Natives für stabilen Multiplayer:

### Network Ownership
```lua
-- Vor jeder Entity-Manipulation:
NetworkRequestControlOfEntity(entity)
-- Loop bis NetworkHasControlOfEntity(entity) == true
```

### Migration Lock (während Transport)
```lua
SetNetworkIdCanMigrate(netId, false)  -- Beim Attach
SetNetworkIdCanMigrate(netId, true)   -- Beim Detach
```

### High-Precision Blending
```lua
NetworkUseHighPrecisionBlending(netId, true)   -- Beim Attach
NetworkUseHighPrecisionBlending(netId, false)  -- Beim Detach
-- Native: 0x2B1813ABA29016C5
-- → Hochfrequente Position-Sync für andere Clients
-- → Verhindert Wackeln/Jitter bei bewegten Vehicles
```

### Loader-Source Statebag
```lua
-- Server schreibt source in Statebag
Entity(vehicle).state:set('vehicleLoaderAttached', {
    trailerNet = ...,
    slotId = ...,
    loaderSource = source,  -- Wer hat geladen
}, true)

-- Client filtert:
local isLoader = (loaderSource == GetPlayerServerId(PlayerId()))
if isLoader then
    -- Nur Loader führt physisches Attach aus
end
```

### Slot Locking (Race-Prevention)
```lua
-- Server-side Atomic Lock vor Loading
TryLockSlot(trailerNet, slotId, source)
-- Auto-Release nach 15s Timeout
-- Manual Release bei: Erfolg, Cancel, Player Disconnect
```

---

## 📥 Client Exports

```lua
-- Lokal gecachte geladene Fahrzeuge
local loaded = exports.vehicle_loader:GetLoadedVehicles()

-- Ist Fahrzeug geladen?
local isLoaded = exports.vehicle_loader:IsVehicleLoaded(vehicleNet)

-- Fahrzeug Slot
local slot = exports.vehicle_loader:GetVehicleSlot(vehicleNet)

-- Fahrzeuge auf Trailer
local vehicles = exports.vehicle_loader:GetVehiclesOnTrailer(trailerNet)

-- Trailer Config abrufen
local config = exports.vehicle_loader:GetTrailerConfig('flatbed')

-- Ist Entity ein konfigurierter Trailer?
local isTrailer = exports.vehicle_loader:IsConfiguredTrailer(entity)
```

---

## 📡 Client Events

### `vehicle_loader:client:onVehicleLoaded`
Wird auf jedem Client gefeuert wenn ein Fahrzeug geladen wurde.
```lua
AddEventHandler('vehicle_loader:client:onVehicleLoaded', function(vehicleNet, trailerNet, slotId)
    -- z.B. Sound abspielen, UI updaten, etc.
end)
```

### `vehicle_loader:client:onVehicleUnloaded`
```lua
AddEventHandler('vehicle_loader:client:onVehicleUnloaded', function(vehicleNet, trailerNet, slotId)
    -- z.B. Effekte abspielen
end)
```

---

## 💡 Beispiele

### Beispiel 1: Job-Bonus für Tow Truck Driver
```lua
-- In deinem eigenen Script
AddEventHandler('vehicle_loader:server:onVehicleLoaded', function(vehicleNet, trailerNet, slotId, source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.job.name == 'tow_truck' then
        xPlayer.addAccountMoney('bank', 100)
        TriggerClientEvent('chat:addMessage', source, {
            args = {'Job', 'Bonus für Aufladen: 100$'}
        })
    end
end)
```

### Beispiel 2: Sperrgebiet für Loading
```lua
AddEventHandler('vehicle_loader:server:onBeforeLoad', function(source, vehicleNet, trailerNet, slotId, cancelFunc)
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)

    -- Sperrgebiet: Polizeistation
    local policeStation = vector3(425.1, -979.5, 30.7)
    if #(coords - policeStation) < 50.0 then
        cancelFunc(true, 'Hier darfst du nicht aufladen!')
    end
end)
```

### Beispiel 3: Auto-Unload nach Zeit
```lua
AddEventHandler('vehicle_loader:server:onVehicleLoaded', function(vehicleNet, trailerNet, slotId, source)
    SetTimeout(60000 * 30, function() -- 30 Minuten
        if exports.vehicle_loader:IsVehicleLoaded(vehicleNet) then
            exports.vehicle_loader:ForceUnloadVehicle(vehicleNet)
        end
    end)
end)
```

### Beispiel 4: Custom Loading per anderem Script
```lua
-- Z.B. ein Garage-Script lädt das Fahrzeug automatisch
local vehicleNet = NetworkGetNetworkIdFromEntity(vehicle)
local trailerNet = NetworkGetNetworkIdFromEntity(trailer)

-- Erst Free Slots prüfen
local freeSlots = exports.vehicle_loader:GetFreeSlots(trailerNet)
if #freeSlots > 0 then
    exports.vehicle_loader:ForceLoadVehicle(vehicleNet, trailerNet, freeSlots[1], source)
end
```

### Beispiel 5: Discord Log integration
```lua
AddEventHandler('vehicle_loader:server:onVehicleLoaded', function(vehicleNet, trailerNet, slotId, source)
    local playerName = GetPlayerName(source)
    SendDiscordWebhook('Loading', ('%s hat Fahrzeug %d geladen'):format(playerName, vehicleNet))
end)
```

---

## 🔗 Event Flow

```
┌─────────────────┐
│ Player clicks   │
│ "Auf Anhänger   │
│  laden" target  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ Client: LoadVehicle()   │
│ - lib.callback.await    │
│   ('validateLoad')      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Server: validateLoad    │
│ 1. onBeforeLoad HOOK    │ ◄── Andere Resources können hier blockieren
│ 2. Job/Items/Money check│
│ 3. Slot check           │
└────────┬────────────────┘
         │ valid = true
         ▼
┌─────────────────────────┐
│ Client: Progress Bar    │
│ Wenn done →             │
│ TriggerServerEvent      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Server: load event      │
│ - Remove items/money    │
│ - ForceLoadInternal     │
│   - onVehicleLoaded ────┼──► Hook für andere Resources
│   - syncLoad to clients │
└─────────────────────────┘
```

---

## 🔒 Sicherheit

- Force Functions **umgehen Job/Items/Money Checks**
- Nutze sie nur in vertrauten Server-Scripts
- Hook Events sind **read-only** für andere Resources (außer Cancel)
- `cancelFunc(true, reason)` blockiert die Aktion mit Grund

---

## 📝 Tipps

1. **Bridge.Notify** nutzen für UI-konsistente Benachrichtigungen
2. Bei eigenen Loading-Animationen den `onBeforeLoad` Hook blockieren
3. Für Discord-Logs `onVehicleLoaded` & `onVehicleUnloaded` nutzen
4. Achte auf NetworkIds, da sie sich nach Vehicle Disposal ändern
