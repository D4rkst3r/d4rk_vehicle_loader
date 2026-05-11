# Vehicle Loader - Storage System

Flexibles Storage System mit 3 Optionen für unterschiedliche Server-Setups.

---

## 🎯 Welche Option für mich?

```
Hat dein Server bereits ein eigenes Persistence System für Trailer/Loadings?
│
├── NEIN → Option 1: Built-in oxmysql
│
├── JA, aber kompatibel → Option 1: Built-in oxmysql
│
├── JA, eigene Tabelle → Option 2: External Provider
│
└── JA, gar keine Persistence gewünscht → Option 3: Disabled
```

---

## 📦 Option 1: Built-in oxmysql (Default)

**Empfohlen für:** Standard ESX/QBCore Server ohne eigenes Loader-System

### Setup

```lua
-- config.lua
Config.Storage = {
    Enabled = true,
    Provider = 'auto',        -- oder 'oxmysql'
    MatchByPlate = true,
    RestoreDelay = 5000,
}
```

### Was passiert?
- Eigene Tabelle `vehicle_loader_loaded` wird automatisch erstellt
- Loadings werden per **Nummernschild** identifiziert (überlebt NetID Änderungen)
- Beim Server-Start werden Fahrzeuge automatisch wieder aufgeladen
- Wenn ein Fahrzeug nicht existiert (DB-Eintrag ist verwaist) wird der Eintrag entfernt

### Datenbank Tabelle

```sql
CREATE TABLE `vehicle_loader_loaded` (
    `vehicle_plate` VARCHAR(16) NOT NULL,
    `trailer_plate` VARCHAR(16) NOT NULL,
    `slot_id` INT NOT NULL,
    `owner_id` INT DEFAULT 0,
    `loaded_at` BIGINT NOT NULL,
    PRIMARY KEY (`vehicle_plate`)
);
```

---

## 🔌 Option 2: External Provider

**Empfohlen für:** Server mit eigenem Persistence System (z.B. custom Garage, eigene DB-Struktur)

### Setup

```lua
-- config.lua
Config.Storage = {
    Enabled = true,
    Provider = 'external',
}
```

### Eigenen Provider registrieren

In deinem eigenen Server-Script:

```lua
-- Bei Resource Start
AddEventHandler('onResourceStart', function(resource)
    if resource == 'vehicle_loader' then
        Wait(500) -- Wait for vehicle_loader to load
        RegisterMyCustomStorage()
    end
end)

function RegisterMyCustomStorage()
    exports.vehicle_loader:SetStorageProvider({
        -- Speichern eines geladenen Fahrzeugs
        SaveVehicle = function(vehiclePlate, data)
            -- data = { trailerPlate, slotId, owner, loadedAt }
            MyCustomDB.save('loaded_vehicles', vehiclePlate, data)
            return true
        end,

        -- Entfernen aus DB
        RemoveVehicle = function(vehiclePlate)
            MyCustomDB.delete('loaded_vehicles', vehiclePlate)
            return true
        end,

        -- Alle geladenen Fahrzeuge laden (beim Server-Start)
        LoadAll = function()
            local data = MyCustomDB.getAll('loaded_vehicles')
            -- Muss returnen: { [vehiclePlate] = { trailerPlate, slotId, owner, loadedAt } }
            return data or {}
        end,

        -- Alle löschen (Admin Command)
        Clear = function()
            MyCustomDB.clear('loaded_vehicles')
        end,
    })
end
```

### Datenformat

Was deine Funktionen liefern müssen:

```lua
-- SaveVehicle Input
{
    trailerPlate = "ABCD1234",  -- Anhänger Nummernschild
    slotId = 1,                  -- Slot-ID (Number)
    owner = 5,                   -- Player Source ID (Number)
    loadedAt = 1715432400,       -- Unix Timestamp
}

-- LoadAll Output
{
    ["VEHICLE_PLATE"] = {
        trailerPlate = "ABCD1234",
        slotId = 1,
        owner = 5,
        loadedAt = 1715432400,
    },
    -- mehr Einträge...
}
```

---

## 🚫 Option 3: Disabled

**Empfohlen für:** Server die KEINE Persistence wünschen oder das selbst voll handhaben

```lua
-- config.lua
Config.Storage = {
    Enabled = false,
}
```

Bei Server-Restart sind alle Loadings vergessen. Stattdessen Hook Events nutzen:

```lua
-- Manuelles Tracking
AddEventHandler('vehicle_loader:server:onVehicleLoaded', function(vehicleNet, trailerNet, slotId, source)
    MyCustomTracking.add(vehicleNet, trailerNet, slotId)
end)

AddEventHandler('vehicle_loader:server:onVehicleUnloaded', function(vehicleNet)
    MyCustomTracking.remove(vehicleNet)
end)
```

---

## ⚠️ Wichtige Hinweise

### NetID vs. Plate

Wir matchen per **Nummernschild**, NICHT NetID, weil:

| | NetID | Plate |
|---|-------|-------|
| **Überlebt Restart** | ❌ Ändert sich | ✅ Bleibt gleich |
| **Performant** | ✅ Schnell | ⚠️ Etwas langsamer |
| **Unique** | ✅ Pro Session | ✅ Pro Fahrzeug |

→ Daher MUSS jedes Fahrzeug ein eindeutiges Plate haben!

### Spawn-Reihenfolge

Beim Server-Start:
1. **vehicle_loader** startet
2. **Storage** lädt Daten aus DB
3. **Warten** auf `RestoreDelay` (default 5s)
4. **Andere Resources** spawnen Fahrzeuge in dieser Zeit
5. **Restore** läuft → matched per Plate → attached

Falls dein Spawn-Script länger braucht, erhöhe `RestoreDelay`!

### Compatibility Check

```lua
-- In deinem Script
CreateThread(function()
    Wait(5000)

    local storageInfo = exports.vehicle_loader:GetStorageInfo()
    print('Storage Provider: ' .. storageInfo.Provider)
    print('Storage Ready: ' .. tostring(storageInfo.Ready))
end)
```

---

## 🐛 Troubleshooting

### "Persistence funktioniert nicht"

1. **oxmysql installiert?** `ensure oxmysql` in server.cfg
2. **Tabelle erstellt?** Check `vehicle_loader_loaded` in DB
3. **Plates unique?** Doppelte Plates verursachen Probleme
4. **RestoreDelay zu kurz?** Erhöhe auf 10000ms

### "Fahrzeuge werden nicht wiederhergestellt"

1. **Sind die Fahrzeuge gespawnt?** Check `RestoreDelay`
2. **Plates korrekt?** DB-Einträge prüfen
3. **Cleanup Logs?** Check Console für "Persistence Restore: X wiederhergestellt, Y übersprungen"

### "Ich will eigene DB nutzen"

→ Nutze **Option 2: External Provider** (siehe oben)

---

## 📋 Admin Commands

| Command | Funktion |
|---------|----------|
| `/loaderstorageinfo` | Storage Status |
| `/loaderstorageclear` | DB komplett leeren |
| `/loaderstatus` | Aktuelle Loadings |

---

## 🔗 Verwandte Dokumentation

- [API.md](../api/API.md) - Public API für andere Resources
- [README.md](../README.md) - Allgemeine Dokumentation
