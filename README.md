# Vehicle Loader System v3.2

> **Professionelles Vehicle Loading System für FiveM** - Statebag-based Sync, Race-Condition Safe, Multi-Framework Support, ox_lib Native.

---

## ⭐ Highlights

- 🚛 **Multi-Slot Loading** - Mehrere Fahrzeuge pro Anhänger
- 🌐 **Multi-Framework** - ESX / QBox / QBCore / Standalone (Auto-Detection)
- 📡 **Statebag-based Sync** - Native FiveM State Replication
- 🔒 **Race-Condition Safe** - Server-Side Slot Locking
- 🎨 **In-Game Debug Mode** - Slots live visualisieren & anpassen
- 🔊 **Sound Effects** - Native FiveM Sounds (Truck Brakes, Mechanical, etc.)
- 🚪 **Auto + Manuelle Rampe** - Trunk-Bone Animation mit Auto-Open/Close
- 💾 **Persistence** - Server-Restart sicher (oxmysql oder External Provider)
- 🔌 **Public API** - Exports & Events für andere Resources
- 🌍 **Multi-Language** - Deutsch / English (erweiterbar)
- ⚡ **High Performance** - lib.points + lib.cache + Statebags
- 🧹 **Auto-Cleanup** - Despawn-Detection, Player-Disconnect-Handling

---

## 📋 Inhaltsverzeichnis

1. [Installation](#-installation)
2. [Konfiguration](#-konfiguration)
3. [Features](#-features)
4. [Commands](#-commands)
5. [Workflow](#-workflow)
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

### Items in `ox_inventory/data/items.lua`:

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

### Datei: `config.lua`

```lua
Config.Global = {
    Locale = 'de',                    -- 'de' oder 'en'
    MoneyRequired = 50,
    MoneyAccount = 'cash',            -- 'cash' oder 'bank'

    LoadingTime = 5000,               -- ms zum Aufladen
    UnloadingTime = 3000,             -- ms zum Entladen

    UnloadDistance = 8.0,             -- Meter hinter Anhänger
    ConfirmUnload = false,            -- Bestätigung bei Entladen?

    EnableAnimations = true,          -- Player-Animationen
    EnableParticles = true,           -- Staub-Effekt
    EnableEffects = true,             -- Sound + Rampe-Animation

    DebugMode = true,                 -- Debug Commands aktivieren
    RefundItemsOnUnload = false,      -- Items zurückgeben?
}

-- Jobs (optional, leer lassen für jeden)
Config.Jobs = {
    -- ['mechanic'] = true,
    -- ['tow_truck'] = true,
}

-- Items
Config.RequiredItems = {
    ['tow_rope'] = 1,
    ['tow_strap'] = 2,
}

-- Persistence
Config.Storage = {
    Enabled = true,
    Provider = 'auto',                -- 'auto', 'oxmysql', 'external'
    MatchByPlate = true,
    RestoreDelay = 5000,
}

-- Anhänger Definitionen
Config.Trailers = {
    {
        model = 'flatbed',
        label = 'Standard Flatbed',
        maxVehicles = 2,

        ramp = {
            enabled = true,
            doorIndex = 5,            -- 5 = Trunk-Bone
            openTime = 500,
        },

        slots = {
            {id = 1, offset = vector3(-1.5, -2.5, 1.0), rotation = vector3(0.0, 0.0, 0.0)},
            {id = 2, offset = vector3(1.5, -5.0, 1.0), rotation = vector3(0.0, 0.0, 0.0)}
        }
    }
}
```

---

## ✨ Features

### 🚛 Multi-Slot System
Jeder Anhänger kann beliebig viele Slots haben - perfekt für Triple-Decker oder einzelne Bike-Träger.

### 🎯 ox_target Integration
Kontextabhängige Optionen:
- **Am Fahrzeug:** "Auf Anhänger laden"
- **Am Anhänger (geladen):** "Vom Anhänger entladen"
- **Am Anhänger (Rampe zu):** "Rampe öffnen"
- **Am Anhänger (Rampe offen):** "Rampe schließen"

### 🌟 Auto-Detection (lib.zones)
Fährst du mit deinem Auto auf einen Slot-Bereich, erscheint automatisch:
```
[E] Fahrzeug aufladen
```

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
- Nutzt Trunk-Bone (Door Index 5) als Default

### 🎨 In-Game Debug Mode
Slots live im Spiel anpassen:
- 3D-Boxen für jeden Slot
- Live Position adjusten (X/Y/Z)
- Config in Clipboard kopieren

### 💾 Smart Persistence
- **Built-in oxmysql** - Auto-Setup, fertig
- **External Provider** - Eigene DB? Override möglich
- **Disabled** - Keine Persistence gewünscht? Auch ok!

### 🔌 Public API
Andere Resources können:
- Daten abfragen (Exports)
- Aktionen erzwingen (Force Functions)
- Events listen (Hooks)
- Aktionen blockieren (Pre-Load/Unload)

---

## 🎮 Commands

### Client Commands

| Command | Beschreibung | Keybind |
|---------|--------------|---------|
| `/debugloader` | Debug Mode starten | F7 |
| `/debugmenu` | ox_lib Menu für Slots | - |
| `/debugzones on/off` | Zonen visualisieren | - |
| `/debugstop` | Debug beenden | - |
| `/loaderinfo` | Geladene Fahrzeuge | - |
| `/loaderframework` | Framework anzeigen | - |

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
2. Server validiert (Job/Items/Money/Slot)
   ↓
3. 🚪 Rampe öffnet (Door Index 5)
   🔊 Sound: Truck Brake Hiss
   ↓ 500ms warten
4. 👨 Player-Animation startet
   📊 Progress Bar (5s)
   ↓
5. Server entfernt Items + Geld
   ↓
6. Fahrzeug wird auf alle Clients attached
   🔊 Sound: Strap Tightening
   🚪 Rampe schließt
   ↓
7. ✅ Persistence DB updated
   📡 Event: onVehicleLoaded
```

### Beim Entladen:

```
1. Spieler triggert "Entladen" (ox_target)
   ↓
2. [Optional] Bestätigungs-Dialog
   ↓
3. 🚪 Rampe öffnet
   🔊 Sound: Truck Brake
   ↓
4. 👨 Player-Animation
   📊 Progress Bar (3s)
   ↓
5. Server entlädt
   ↓
6. Fahrzeug wird detached
   📍 Position: 8m hinter Anhänger (Ground-Z)
   🚗 Heading: 180° vom Anhänger weg
   💨 Particle: Staub-Wolke
   🔊 Sound: Crash + Truck Brake
   ↓ 2s warten
7. 🚪 Rampe schließt
   📡 Event: onVehicleUnloaded
```

---

## 🔌 API / Integration

### Server Exports (für andere Resources)

```lua
-- Daten abfragen
local loaded = exports.vehicle_loader:GetLoadedVehicles()
local isLoaded = exports.vehicle_loader:IsVehicleLoaded(vehicleNet)
local vehicles = exports.vehicle_loader:GetVehiclesOnTrailer(trailerNet)
local hasFree = exports.vehicle_loader:HasFreeSlots(trailerNet)
local freeSlots = exports.vehicle_loader:GetFreeSlots(trailerNet)
local data = exports.vehicle_loader:GetVehicleData(vehicleNet)

-- Aktionen
exports.vehicle_loader:ForceLoadVehicle(vehNet, trailerNet, slotId, source)
exports.vehicle_loader:ForceUnloadVehicle(vehicleNet)
exports.vehicle_loader:ForceUnloadAllFromTrailer(trailerNet)

-- Info
local framework = exports.vehicle_loader:GetFramework()  -- 'qbox', 'esx', etc.
local storage = exports.vehicle_loader:GetStorageInfo()
```

### Server Events (Hooks)

```lua
-- Wird gefeuert wenn geladen/entladen wurde
AddEventHandler('vehicle_loader:server:onVehicleLoaded', function(vehicleNet, trailerNet, slotId, source) end)
AddEventHandler('vehicle_loader:server:onVehicleUnloaded', function(vehicleNet, trailerNet, slotId, owner) end)

-- BEFORE Hooks (können Aktion BLOCKIEREN)
AddEventHandler('vehicle_loader:server:onBeforeLoad', function(source, vehNet, trailerNet, slotId, cancelFunc)
    if NotAllowed() then
        cancelFunc(true, 'Hier nicht aufladen!')
    end
end)

AddEventHandler('vehicle_loader:server:onBeforeUnload', function(source, vehNet, trailerNet, cancelFunc) end)
```

### Client Events

```lua
AddEventHandler('vehicle_loader:client:onVehicleLoaded', function(vehicleNet, trailerNet, slotId) end)
AddEventHandler('vehicle_loader:client:onVehicleUnloaded', function(vehicleNet, trailerNet, slotId) end)
```

### Effects Exports

```lua
exports.vehicle_loader:PlaySound('truck_brake', coords)
exports.vehicle_loader:OpenTrailerRamp(trailer, doorIndex)
exports.vehicle_loader:CloseTrailerRamp(trailer, doorIndex)
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
├── bridge/                     Framework Bridge
│   ├── server.lua              ESX/QBox/QBCore/Standalone
│   ├── client.lua
│   └── FRAMEWORKS.md           Framework Docs
│
├── api/                        Public API
│   ├── server.lua              Exports, Events, Callbacks
│   ├── client.lua
│   └── API.md                  API Docs
│
├── storage/                    Persistence
│   ├── server.lua              Storage Adapter (oxmysql/external)
│   └── STORAGE.md              Storage Docs
│
├── locales/                    Multi-Language
│   ├── de.json
│   └── en.json
│
├── server.lua                  Main Server Logic
├── client.lua                  Main Client Logic
├── effects.lua                 Sounds + Ramp Animation
├── zones.lua                   lib.zones + lib.points
└── debug.lua                   In-Game Debug System
```

---

## 🎯 Anhänger einrichten (Step-by-Step)

### 1. Anhänger Modell vorbereiten (Blender/Sollumz)
- Modell mit korrektem Trunk-Bone für Rampe
- Door Index 5 = Standard Trunk

### 2. In `config.lua` definieren
```lua
{
    model = 'mein_anhaenger',
    label = 'Mein Anhänger',
    maxVehicles = 1,
    ramp = { enabled = true, doorIndex = 5, openTime = 500 },
    slots = {
        {id = 1, offset = vector3(0.0, -3.5, 1.0), rotation = vector3(0.0, 0.0, 0.0)}
    }
}
```

### 3. Resource starten + Anhänger spawnen
```
ensure vehicle_loader
```

### 4. Debug Mode (F7 oder /debugloader)
- Mit **G** Slot wählen
- Mit **X/C/V** Achse wählen
- Mit **E/Q** Position anpassen
- Mit **B** Config in Clipboard kopieren

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
| **Event-Based** | Keine constant syncs |
| **Server-Side Validation** | Anti-Cheat by default |
| **Smart Cleanup** | Zonen werden bei Range-Out entfernt |

**Resmon (idle):** ~0.01ms  
**Resmon (active):** ~0.1ms

---

## 🐛 Troubleshooting

### "Framework: standalone" obwohl Framework läuft
→ Stelle sicher dass Framework VOR vehicle_loader startet (in server.cfg)

### Rampe öffnet sich nicht
→ Check `doorIndex` in der Trailer-Config. Probiere 5, 6, oder andere Werte.

### Fahrzeug fällt durch den Boden
→ Erhöhe `UnloadDistance` in Config oder check Ground-Z Detection

### Persistence funktioniert nicht
→ Check ob `oxmysql` läuft und Tabelle `vehicle_loader_loaded` existiert

### Auto-Detection (Zone) zeigt sich nicht
→ Erhöhe Zone-Size in `zones.lua` (`size = vec3(...)` Werte)

### Sound funktioniert nicht
→ Check `Config.Global.EnableEffects = true`

**Mehr Details:** [bridge/FRAMEWORKS.md](bridge/FRAMEWORKS.md) und [storage/STORAGE.md](storage/STORAGE.md)

---

## 📊 Feature-Matrix

| Feature | Status |
|---------|:------:|
| Multi-Slot Loading | ✅ |
| Network Sync | ✅ |
| ESX Support | ✅ |
| QBox Support | ✅ |
| QBCore Support | ✅ |
| Standalone Support | ✅ |
| Persistence (DB) | ✅ |
| Custom Storage | ✅ |
| In-Game Debug | ✅ |
| Sound Effects | ✅ |
| Auto-Ramp | ✅ |
| Manual Ramp Control | ✅ |
| Job Restrictions | ✅ |
| ox_target Integration | ✅ |
| ox_inventory Items | ✅ |
| Multi-Language | ✅ |
| Public API | ✅ |
| Event Hooks | ✅ |
| Particle Effects | ✅ |
| Player Animations | ✅ |

---

## 📦 Dependencies

| Resource | Version | Required |
|----------|---------|:--------:|
| **ox_lib** | latest | ✅ Required |
| **ox_target** | latest | ✅ Required |
| **ox_inventory** | latest | ✅ Required |
| **oxmysql** | latest | ⭕ Optional (für Persistence) |
| **qbx_core** | latest | ⭕ Optional Framework |
| **es_extended** | 1.10+ | ⭕ Optional Framework |
| **qb-core** | 1.2+ | ⭕ Optional Framework |

---

## 🎓 Best Practices

1. **Verwende QBox** wenn du einen neuen Server startest (modernste Architektur)
2. **Locale auf 'en'** wenn du internationale Spieler hast
3. **MaxVehiclesPerTrailer = 1** für realistic Server
4. **EnableParticles = false** für High-Performance Server
5. **ConfirmUnload = true** für RP-Server (verhindert versehentliches Entladen)
6. **DebugMode = false** auf Production-Servern
7. **Job-Restrictions** für Tow-Truck-Service Jobs

---

## 💡 Tipps

### Multiple Anhänger pro Server
Du kannst beliebig viele Anhänger in `Config.Trailers` definieren.

### Custom Anhänger (Blender/Sollumz)
- Trunk-Bone für Rampe konfigurieren
- Slots im Debug-Mode anpassen
- Door Index 5 oder 6 testen

### Jobs Integration
```lua
Config.Jobs = {
    ['tow_truck'] = true,
    ['mechanic'] = true,
}
```

### Discord Logging
```lua
AddEventHandler('vehicle_loader:server:onVehicleLoaded', function(vehNet, trailerNet, slotId, source)
    SendDiscordWebhook('Vehicle Loaded', ('Spieler %d hat Fahrzeug %d aufgeladen'):format(source, vehNet))
end)
```

---

## 📄 Version Info

- **Version:** 3.1.0
- **Erstellt:** Mai 2026
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
F7              # Debug starten
Slot anpassen
B               # Config kopieren

# 4. config.lua einsetzen
# 5. restart vehicle_loader

✅ Fertig!
```

---

**Built with ❤️ for the FiveM Community**
