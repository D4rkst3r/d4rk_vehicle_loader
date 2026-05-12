# Vehicle Loader System v4.0

> **Professionelles Vehicle Loading System für FiveM** - Mit modernem NUI Debug-UI, Statebag-Sync, Race-Safe, Multi-Framework Support und ox_lib Integration.

---

## ⭐ Highlights

- 🚛 **Multi-Slot Loading** - Mehrere Fahrzeuge pro Anhänger
- 📏 **Per-Slot Sizes** - Bike, Auto, SUV, Truck Presets (oder Custom)
- 🌐 **Multi-Framework** - ESX / QBox / QBCore / Standalone (Auto-Detection)
- 📡 **Statebag-based Sync** - Native FiveM State Replication
- 🔒 **Race-Condition Safe** - Server-Side Slot Locking
- 🎮 **Smooth Multiplayer** - NetworkOwner-Handling + High-Precision Blending
- 🛡️ **Loader-Filter** - Nur ladender Client führt Attach aus (Anti-Race)
- 🎨 **Modern NUI Debug** - Glassmorphism UI mit Live-Updates (v6.0)
- 🎯 **Snap-to-Vehicle** - Position via Test-Auto setzen
- 🔊 **Sound Effects** - Native FiveM Sounds (Truck Brakes, Mechanical)
- 🚪 **Auto + Manuelle Rampe** - Trunk-Bone Animation
- 🚫 **Vehicle Restrictions** - Class-/Größen-Filter pro Anhänger
- 🛡️ **Anti-Theft / Owner-Lock** - Nur Owner kann entladen (optional)
- 📍 **Visual Slot Markers** - 3D Marker über freien Slots
- 💾 **Persistence** - Server-Restart sicher (oxmysql / External / Disabled)
- 🔌 **Public API** - Exports & Events für andere Resources
- 🌍 **Multi-Language** - Deutsch / English (erweiterbar)
- ⚡ **High Performance** - lib.points + lib.cache + Statebags
- 🧹 **Auto-Cleanup** - Despawn-Detection, Player-Disconnect-Handling
- 🛡️ **Security Layer** - Rate Limiting, Distance Check, Routing Bucket
- 🎮 **txAdmin Support** - Admin-Rechte automatisch erkannt

---

## 📋 Inhaltsverzeichnis

1. [Installation](#-installation)
2. [Konfiguration](#-konfiguration)
3. [Features](#-features)
4. [Debug-Mode](#-debug-mode-v60)
5. [Commands](#-commands)
6. [API / Integration](#-api--integration)
7. [Dokumentation](#-weitere-dokumentation)
8. [Troubleshooting](#-troubleshooting)

---

## 📦 Installation

### Dependencies

```cfg
# Required
ensure ox_lib
ensure ox_target
ensure ox_inventory

# Optional (für Persistence)
ensure oxmysql

# Framework (eines davon, optional)
ensure qbx_core      # ODER
ensure es_extended   # ODER
ensure qb-core       # ODER nichts (= Standalone)

# Endlich
ensure vehicle_loader
```

### Items in `ox_inventory/data/items.lua` (optional):

```lua
['tow_rope'] = {
    label = 'Abschleppseil',
    weight = 500,
    stack = true,
    close = true,
},
['tow_strap'] = {
    label = 'Spanngurt',
    weight = 200,
    stack = true,
    close = true,
},
```

---

## ⚙️ Konfiguration

### Globale Einstellungen (`config.lua`)

```lua
Config.Global = {
    Locale = 'de',                    -- 'de' oder 'en'

    -- Geld (0 = kostenlos)
    MoneyRequired = 0,
    MoneyAccount = 'cash',            -- 'cash' oder 'bank'

    -- Loading
    LoadingTime = 5000,               -- ms zum Aufladen
    UnloadingTime = 3000,             -- ms zum Entladen
    UnloadDistance = 8.0,             -- Meter hinter Anhänger
    ConfirmUnload = false,            -- Bestätigung bei Entladen?

    -- Effects
    EnableAnimations = true,          -- Player-Animationen
    EnableParticles = true,           -- Staub-Effekt
    EnableEffects = true,             -- Sound + Rampe-Animation

    -- Anti-Theft / Owner-Lock
    OwnerOnlyUnload = false,          -- Nur Owner darf entladen?
    AllowJobUnload = true,            -- Job-Kollegen erlaubt
    AllowAdminUnload = true,          -- Admins immer erlaubt

    -- Visual Markers
    ShowSlotMarkers = true,           -- 3D Marker über freien Slots
    MarkerType = 'cylinder',          -- 'cylinder', 'arrow', 'cube'
    MarkerColor = {r=0, g=255, b=100, a=100},
    MarkerSize = 1.0,
    MarkerMaxDistance = 30.0,

    DebugMode = true,                 -- Debug-Mode aktivieren (F7)
}
```

### Vehicle Restrictions (Global)

```lua
-- Klassen die NIE geladen werden können
Config.BlacklistedClasses = {
    [14] = true,  -- Boats
    [15] = true,  -- Helicopters
    [16] = true,  -- Planes
    [21] = true,  -- Trains
}
```

### Anhänger mit Slot-Sizes

```lua
Config.Trailers = {
    {
        model = 'mein_anhaenger',
        label = 'Mein Custom Carrier',
        maxVehicles = 3,

        ramp = {
            enabled = true,
            doorIndex = 5,            -- 5 = Trunk-Bone
            openTime = 500,
        },

        -- Optional: Restrictions
        restrictions = {
            allowedClasses = {8, 13}, -- Nur Bikes (8) + Cycles (13)
            -- ODER
            blacklistedClasses = {15}, -- Keine Helis
            maxLength = 5.0,           -- Max Fahrzeuglänge
        },

        slots = {
            -- Bike-Slot (kleiner)
            { id = 1, type = 'bike', offset = vector3(-0.8, -2.0, 1.0), rotation = vector3(0,0,0) },
            -- Auto-Slot (Standard)
            { id = 2, type = 'car',  offset = vector3(0.0, -5.0, 1.0),  rotation = vector3(0,0,0) },
            -- Custom Size
            { id = 3, size = vec3(2.0, 3.0, 1.8), offset = vector3(0.8, -2.0, 1.0), rotation = vector3(0,0,0) },
        }
    }
}
```

### Slot-Type Presets

| Type | Größe (W × L × H) | Für |
|------|---------------------|-----|
| `bike` | 1.2 × 2.5 × 1.5 | 🏍️ Motorrad / Fahrrad |
| `car` | 2.2 × 4.5 × 1.8 | 🚗 Auto |
| `suv` | 2.5 × 5.0 × 2.0 | 🚙 SUV / Pickup |
| `truck` | 2.8 × 6.5 × 3.0 | 🚛 LKW |

---

## ✨ Features

### 🚛 Multi-Slot mit verschiedenen Größen
Jeder Anhänger kann Slots mit unterschiedlichen Größen haben. Bike + Auto nebeneinander? Kein Problem!

### 🎯 ox_target Integration
Kontextabhängige Optionen:
- **Am Fahrzeug:** "Auf Anhänger laden"
- **Am Anhänger (geladen):** "Vom Anhänger entladen"
- **Am Anhänger (Rampe zu):** "Rampe öffnen"
- **Am Anhänger (Rampe offen):** "Rampe schließen"

### 🌟 Auto-Detection (lib.zones)
Fährst du mit deinem Auto in einen Slot, erscheint **[E] Fahrzeug aufladen**.

### 🚫 Vehicle Restrictions
Konfigurierbar pro Anhänger oder global:
- Erlaubte Klassen (Whitelist)
- Geblockte Klassen (Blacklist)
- Max. Fahrzeuglänge

### 🛡️ Anti-Theft System
Optional - nur der Owner (oder Job-Kollegen / Admins) kann entladen.

### 📍 Visual Slot Markers
3D Marker über freien Slots - Größe passt sich dem Slot-Type an.

### 🔊 Native Sound Effects
- Truck Pneumatic Brake Hiss
- Trunk Open/Close
- Mechanical / Strap Tightening
- Crash Sound beim Drop
- Staub-Wolke beim Aufsetzen

### 🚪 Auto-Ramp System
- Rampe öffnet sich **automatisch** beim Loading
- Schließt sich **automatisch** wenn fertig
- Spieler kann auch **manuell** öffnen/schließen

### 💾 Smart Persistence
- **Built-in oxmysql** - Auto-Setup
- **External Provider** - Eigene DB? Override möglich
- **Disabled** - Keine Persistence

### 🔌 Public API
Andere Resources können:
- Daten abfragen (Exports)
- Aktionen erzwingen (Force Functions)
- Events listen (Hooks)
- Aktionen blockieren (Pre-Load/Unload)

### 🔒 Security & Performance
- **Rate Limiting** (max 5 Aktionen / 5s)
- **Distance Check** (max 15m)
- **Routing Bucket** Aware
- **Slot Locking** (Race-Condition Safe)
- **Statebags** (Auto-Sync)
- **lib.cache + lib.points** (Native Performance)

---

## 🎨 Debug-Mode v6.0

### Modernes NUI-UI mit Glassmorphism Design

**Starten:** Drücke **F7** oder `/debugloader`

### 4 Tabs:

#### 📊 **Werte-Tab**
- Slot-Typ Selector (Bike/Car/SUV/Truck)
- Position / Rotation Switcher
- X/Y/Z Input-Felder mit +/- Buttons
- Step-Selektor (0.05 / 0.1 / 0.5 / 1.0)
- "Werte anwenden" Button

#### ⚡ **Aktionen-Tab**
- 🎯 **Snap to Vehicle** - Position des nächsten Fahrzeugs übernehmen
- ↩️ **Undo / Redo** (max 20 Steps)
- 🚪 **Rampe testen** - Live öffnen/schließen
- 🔍 **Door-Index ermitteln** - Testet Door 0-6 automatisch
- 📋 **Config exportieren** - Clipboard + Console

#### 📑 **Slots-Tab**
- Liste aller Slots mit Frei/Belegt Status
- 2x2 Action Grid: Neu / Duplizieren / Spiegeln / Löschen

#### 🚗 **Test-Tab**
- 7 vordefinierte Test-Vehicles (Adder, Sultan RS, Bati, etc.)
- Spawnen 5m vor dem Spieler, Engine aus
- Direkt löschbar

### Tastatur-Shortcuts (zusätzlich):

| Taste | Funktion |
|-------|----------|
| **F** | Snap to Vehicle |
| **G** | Slot wechseln |
| **T** | Test-Vehicle spawnen |
| **Z** | Undo |
| **Y** | Redo |
| **N** | Debug beenden |

---

## 🎮 Commands

### Client Commands

| Command | Beschreibung | Keybind |
|---------|--------------|---------|
| `/debugloader` | Debug Mode starten | F7 |
| `/debugstop` | Debug beenden | - |
| `/loaderinfo` | Geladene Fahrzeuge anzeigen | - |
| `/loaderframework` | Framework anzeigen | - |
| `/togglemarkers` | Visual Markers ein/aus | - |
| `/loaderadmincheck` | Eigene Admin-Rechte prüfen | - |

### Server Commands (Admin)

| Command | Beschreibung |
|---------|--------------|
| `/loaderstatus` | Status aller Loadings |
| `/forceunloadall` | Alle Fahrzeuge entladen |
| `/loaderstorageinfo` | Storage Status |
| `/loaderstorageclear` | DB komplett leeren |

---

## 🔄 Workflow

### Beim Aufladen:

```
1. Spieler triggert "Aufladen" (ox_target oder Auto-Zone)
   ↓
2. ⏱️ Security Check (Rate Limit, Distance, Bucket)
   ↓
3. 🚫 Vehicle Restrictions Check (Class/Size)
   ↓
4. 🔒 Slot Lock erworben
   ↓
5. 🚪 Rampe öffnet (Door Index 5)
   🔊 Sound: Truck Brake Hiss
   ↓
6. 👨 Player-Animation startet
   📊 Progress Bar (5s)
   ↓
7. Server entfernt Items + Geld
   ↓
8. 📡 Statebag updated → Auto-Sync zu allen Clients
   🔊 Sound: Strap Tightening
   🚪 Rampe schließt
   ↓
9. 💾 Persistence DB updated
   📡 Event: onVehicleLoaded
```

### Beim Entladen:

```
1. Spieler triggert "Entladen" (ox_target)
   ↓
2. [Optional] Bestätigungs-Dialog
   ↓
3. 🛡️ Anti-Theft Check (Owner/Job/Admin)
   ↓
4. 🚪 Rampe öffnet
   ↓
5. 👨 Player-Animation
   📊 Progress Bar (3s)
   ↓
6. Server entlädt + Statebag clear
   ↓
7. Fahrzeug detached → 8m hinter Anhänger
   💨 Particle: Staub-Wolke
   🔊 Sound: Crash + Truck Brake
   ↓
8. 🚪 Rampe schließt
   📡 Event: onVehicleUnloaded
```

---

## 🔌 API / Integration

### Server Exports

```lua
-- Daten abfragen
local loaded = exports.vehicle_loader:GetLoadedVehicles()
local isLoaded = exports.vehicle_loader:IsVehicleLoaded(vehicleNet)
local vehicles = exports.vehicle_loader:GetVehiclesOnTrailer(trailerNet)
local hasFree = exports.vehicle_loader:HasFreeSlots(trailerNet)
local freeSlots = exports.vehicle_loader:GetFreeSlots(trailerNet)

-- Aktionen
exports.vehicle_loader:ForceLoadVehicle(vehNet, trailerNet, slotId, source)
exports.vehicle_loader:ForceUnloadVehicle(vehicleNet)
exports.vehicle_loader:ForceUnloadAllFromTrailer(trailerNet)

-- Info
local framework = exports.vehicle_loader:GetFramework()
local storage = exports.vehicle_loader:GetStorageInfo()
```

### Server Events (Hooks)

```lua
-- Wird gefeuert wenn geladen/entladen wurde
AddEventHandler('vehicle_loader:server:onVehicleLoaded', function(vehicleNet, trailerNet, slotId, source) end)
AddEventHandler('vehicle_loader:server:onVehicleUnloaded', function(vehicleNet, trailerNet, slotId, owner) end)

-- BEFORE Hooks (können Aktion BLOCKIEREN)
AddEventHandler('vehicle_loader:server:onBeforeLoad', function(source, vehNet, trailerNet, slotId, cancelFunc)
    if NotAllowed() then cancelFunc(true, 'Hier nicht!') end
end)
```

### Effects Exports (Client)

```lua
exports.vehicle_loader:PlaySound('truck_brake', coords)
exports.vehicle_loader:OpenTrailerRamp(trailer, doorIndex)
exports.vehicle_loader:CloseTrailerRamp(trailer, doorIndex)
exports.vehicle_loader:ToggleMarkers(state)
exports.vehicle_loader:ToggleZoneDebug(state)
exports.vehicle_loader:ForceRecreateZones(trailer)
```

**→ Vollständige API in [`api/API.md`](api/API.md)**

---

## 📚 Weitere Dokumentation

| Datei | Beschreibung |
|-------|--------------|
| **[api/API.md](api/API.md)** | Vollständige Public API |
| **[bridge/FRAMEWORKS.md](bridge/FRAMEWORKS.md)** | Framework Support (ESX/QBox/QBCore) |
| **[storage/STORAGE.md](storage/STORAGE.md)** | Persistence System (3 Optionen) |

---

## 🗂️ Datei-Struktur

```
vehicle_loader/
├── fxmanifest.lua              Resource Manifest
├── config.lua                  Anhänger & Settings
├── README.md                   Diese Datei
│
├── nui/                        Modern Debug UI (NUI)
│   ├── index.html
│   ├── style.css               Glassmorphism Design
│   └── script.js               Live-Updates
│
├── bridge/                     Framework Bridge
│   ├── server.lua              ESX/QBox/QBCore/Standalone + txAdmin
│   ├── client.lua
│   └── FRAMEWORKS.md
│
├── api/                        Public API
│   ├── server.lua              Exports, Events, Callbacks
│   ├── client.lua
│   └── API.md
│
├── storage/                    Persistence
│   ├── server.lua              Storage Adapter
│   └── STORAGE.md
│
├── locales/                    Multi-Language
│   ├── de.json
│   └── en.json
│
├── server.lua                  Main Server Logic
├── client.lua                  Main Client Logic
├── debug.lua                   NUI Debug System
├── statebags.lua               State Sync System
├── security.lua                Rate Limiting, Validation
├── restrictions.lua            Vehicle Class/Size Check
├── effects.lua                 Sounds + Ramp Animation
├── zones.lua                   lib.zones + lib.points + Slot Sizes
├── markers.lua                 3D Visual Markers
└── types.lua                   LuaCATS Type Definitions
```

---

## 🎯 Anhänger einrichten (Step-by-Step)

### 1. Anhänger Modell vorbereiten
- Modell mit korrektem Trunk-Bone für Rampe (Door Index 5)
- In Blender/Sollumz erstellen

### 2. In `config.lua` definieren
```lua
{
    model = 'mein_anhaenger',
    label = 'Mein Anhänger',
    maxVehicles = 1,
    ramp = { enabled = true, doorIndex = 5, openTime = 500 },
    slots = {
        { id = 1, type = 'car', offset = vector3(0,0,0), rotation = vector3(0,0,0) }
    }
}
```

### 3. Resource starten + Anhänger spawnen
```
ensure vehicle_loader
```

### 4. Debug Mode (F7) - Mit NUI!
- 🚗 Test-Vehicle Tab → "Adder" spawnen
- Auto an die gewünschte Slot-Position fahren
- 🎯 "Snap to Vehicle" klicken → Position übernommen!
- ✏️ Slot-Typ ggf. ändern (Bike/Car/SUV/Truck)
- 📋 "Config exportieren" → in Clipboard

### 5. Werte in `config.lua` einsetzen
- Strg+V in deine Slot-Definition
- Resource neu starten

✅ **Fertig!**

---

## 🛠️ Performance

| Optimierung | Wie |
|-------------|-----|
| **No Polling** | `lib.points` statt eigene Threads |
| **Caching** | `lib.cache.ped`, `cache.vehicle` |
| **Native Zones** | `lib.zones.box` mit onEnter/onExit |
| **Statebags** | Auto-Sync ohne eigene Events |
| **Race-Safe** | Server-Side Slot Locking |
| **Auto-Cleanup** | entityRemoved Event Handler |

**Resmon (idle):** ~0.01ms
**Resmon (active):** ~0.1ms
**Resmon (Debug-Mode active):** ~0.3ms

---

## 🎮 Multiplayer-Handling

Das System nutzt mehrere Techniken für **stabilen Multiplayer-Sync**:

### 1. **NetworkOwner Requesting**
Vor jedem Attach/Detach wird die Network-Ownership der Entity requestiert:
```lua
NetworkRequestControlOfEntity(vehicle)
-- Server gibt Ownership → Manipulation funktioniert
```

### 2. **Migration Lock während Transport**
Während Vehicle attached ist, kann Ownership nicht zu anderen Clients wandern:
```lua
SetNetworkIdCanMigrate(vehicleNetId, false)
```

### 3. **High-Precision Blending**
Position wird mit hochfrequentem Sync übertragen → kein Wackeln/Jitter für andere Spieler:
```lua
NetworkUseHighPrecisionBlending(vehicleNetId, true)
```

### 4. **Loader-Source Filter**
Server speichert `loaderSource` im Statebag → nur dieser Client führt physisches Attach aus:
```lua
-- Statebag enthält:
{ trailerNet, slotId, loaderSource = sourceId }

-- Client filtert:
if loaderSource == GetPlayerServerId(PlayerId()) then
    AttachVehicleToTrailer(...)
end
```

### 5. **Race-Condition Prevention**
Server-Side **Slot Locking** verhindert dass 2 Spieler gleichzeitig den gleichen Slot beanspruchen:
```lua
TryLockSlot(trailerNet, slotId, source)
-- Wenn lock erfolgreich → 15s reserviert
-- Auto-Release bei Cancel oder Timeout
```

### 6. **Mission Entity**
Vehicle bleibt geladen auch wenn Spieler weit weg sind:
```lua
SetEntityAsMissionEntity(vehicle, true, true)
-- → Verhindert auto-despawn
```

### 📊 Wie das in Edge-Cases hilft:

| Szenario | Ohne Fix | Mit Fix |
|----------|----------|---------|
| 2 Spieler laden gleichzeitig | ❌ Race | ✅ Slot-Lock |
| Anderer Spieler näher am Vehicle | ❌ Attach silent fail | ✅ Ownership Request |
| Vehicle wackelt für andere Clients | ❌ Default Sync | ✅ High-Precision |
| Spieler joint mid-transport | ❌ Inkonsistenz | ✅ Statebag sync |
| Loader fährt weit weg | ❌ Auto-Despawn | ✅ Mission Entity |
| Vehicle wird zerstört | ❌ Memory Leak | ✅ entityRemoved cleanup |

---

## 🐛 Troubleshooting

### "Framework: standalone" obwohl Framework läuft
→ Stelle sicher dass Framework VOR vehicle_loader startet (in server.cfg)

### Rampe öffnet sich nicht
→ Check `doorIndex` in der Trailer-Config. Im Debug-Mode "Door-Index ermitteln" nutzen!

### Fahrzeug fällt durch den Boden
→ Erhöhe `UnloadDistance` in Config

### Persistence funktioniert nicht
→ Check ob `oxmysql` läuft und Tabelle `vehicle_loader_loaded` existiert

### Test-Vehicle spawnt im Boden
→ Sollte in v4.0+ gefixt sein (GetGroundZFor_3dCoord)

### NUI ist schwarz
→ FiveM Cache leeren (CEF cached Frames)

### Auto wackelt auf dem Anhänger
→ Sollte in v3.4+ gefixt sein (SetEntityNoCollisionEntity)

### Auto wackelt für ANDERE Spieler
→ Sollte in v4.0+ gefixt sein (NetworkUseHighPrecisionBlending)

### Auto bleibt auf der Straße statt am Anhänger
→ Sollte in v4.0+ gefixt sein (NetworkOwner-Request + Loader-Filter)

### Race-Condition / Slot doppelt belegt
→ Sollte in v3.2+ gefixt sein (Slot Locking)

### Test-Vehicle spawnt im Boden
→ Sollte in v4.0+ gefixt sein (GetGroundZFor_3dCoord)

**Mehr Details:** [bridge/FRAMEWORKS.md](bridge/FRAMEWORKS.md) und [storage/STORAGE.md](storage/STORAGE.md)

---

## 📊 Feature-Matrix

| Feature | Status |
|---------|:------:|
| Multi-Slot Loading | ✅ |
| Per-Slot Sizes | ✅ |
| Vehicle Restrictions | ✅ |
| Anti-Theft / Owner-Lock | ✅ |
| Visual Slot Markers | ✅ |
| NUI Debug Mode | ✅ |
| Snap-to-Vehicle | ✅ |
| Undo/Redo | ✅ |
| Test-Vehicle Spawner | ✅ |
| Network Sync (Statebags) | ✅ |
| NetworkOwner Handling | ✅ |
| High-Precision Blending | ✅ |
| Migration Lock | ✅ |
| Loader-Source Filter | ✅ |
| Race-Condition Safe | ✅ |
| Security Layer | ✅ |
| Rate Limiting | ✅ |
| Routing Bucket Support | ✅ |
| ESX Support | ✅ |
| QBox Support | ✅ |
| QBCore Support | ✅ |
| Standalone Support | ✅ |
| txAdmin Admin Detection | ✅ |
| Persistence (DB) | ✅ |
| Custom Storage Provider | ✅ |
| In-Game Debug | ✅ |
| Sound Effects | ✅ |
| Auto-Ramp | ✅ |
| Manual Ramp Control | ✅ |
| Particle Effects | ✅ |
| Player Animations | ✅ |
| Job Restrictions | ✅ |
| ox_target Integration | ✅ |
| ox_inventory Items | ✅ |
| Multi-Language | ✅ |
| Public API | ✅ |
| Event Hooks (with Cancel) | ✅ |
| LuaCATS Type Definitions | ✅ |

---

## 📦 Dependencies

| Resource | Version | Required |
|----------|---------|:--------:|
| **ox_lib** | latest | ✅ Required |
| **ox_target** | latest | ✅ Required |
| **ox_inventory** | latest | ✅ Required |
| **oxmysql** | latest | ⭕ Optional (für Persistence) |
| **qbx_core** | latest | ⭕ Optional Framework (empfohlen) |
| **es_extended** | 1.10+ | ⭕ Optional Framework |
| **qb-core** | 1.2+ | ⭕ Optional Framework |
| **monitor** (txAdmin) | latest | ⭕ Optional (Admin Detection) |

---

## 🎓 Best Practices

1. **QBox** wenn du einen neuen Server startest (modernste Architektur)
2. **Locale auf 'en'** für internationale Spieler
3. **MaxVehiclesPerTrailer = 1** für realistic Server
4. **EnableParticles = false** für High-Performance
5. **ConfirmUnload = true** für RP-Server
6. **DebugMode = false** auf Production-Servern
7. **OwnerOnlyUnload = true** für Anti-Diebstahl
8. **Slot-Types nutzen** für realistische Größen-Constraints

---

## 💡 Tipps

### Mixed Vehicle Loading
```lua
slots = {
    { id = 1, type = 'bike', offset = vector3(-1.0, -2.0, 1.0), rotation = vector3(0,0,0) },
    { id = 2, type = 'bike', offset = vector3(1.0, -2.0, 1.0), rotation = vector3(0,0,0) },
    { id = 3, type = 'car',  offset = vector3(0.0, -5.0, 1.0), rotation = vector3(0,0,0) },
}
-- → 2 Bikes vorne + 1 Auto hinten
```

### Bike-Only Anhänger
```lua
restrictions = {
    allowedClasses = {8, 13},  -- Nur Motorräder + Fahrräder
}
```

### Discord Logging
```lua
AddEventHandler('vehicle_loader:server:onVehicleLoaded', function(vehNet, trailerNet, slotId, source)
    SendDiscordWebhook('Vehicle Loaded', ('Spieler %d hat Fahrzeug %d geladen'):format(source, vehNet))
end)
```

### Anti-Theft + Job
```lua
Config.Global.OwnerOnlyUnload = true
Config.Global.AllowJobUnload = true  -- Job-Kollegen können auch
Config.Jobs = {
    ['tow_truck'] = true,
}
```

---

## 📄 Version Info

- **Version:** 4.0.0
- **Debug UI:** v6.0 (NUI Glassmorphism)
- **Erstellt:** 2026
- **Lua:** 5.4
- **FX Version:** cerulean

---

## 🎯 Quick Start

```bash
# 1. Resource installieren
cp -r vehicle_loader /resources/

# 2. server.cfg
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure oxmysql
ensure vehicle_loader

# 3. Im Spiel
F7              # NUI Debug starten
Test-Tab        # Test-Vehicle spawnen
Snap-Button     # Position übernehmen
Export-Button   # Config in Clipboard

# 4. config.lua einsetzen
# 5. restart vehicle_loader

✅ Fertig!
```

---

**Built with ❤️ for the FiveM Community**

🔗 https://github.com/D4rkst3r/d4rk_vehicle_loader
