# Framework Support

Detaillierte Dokumentation zu allen unterstützten Frameworks.

---

## 🎯 Detection-Priorität

Die Bridge prüft Frameworks in dieser Reihenfolge:

```
1. QBox (qbx_core)         ← Höchste Priorität
2. ESX (es_extended)
3. QBCore (qb-core)
4. Standalone              ← Fallback
```

**Warum QBox zuerst?**  
QBox läuft oft mit einer `qb-core` Compat-Layer parallel. Wir wollen die moderneren QBox APIs nutzen wenn verfügbar.

---

## 📦 QBox Support (qbx_core)

### Setup
```cfg
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure qbx_core
ensure vehicle_loader
```

### Was wird genutzt?

| Feature | API |
|---------|-----|
| **Player Object** | `exports.qbx_core:GetPlayer(source)` |
| **Money** | `player.PlayerData.money[type]` |
| **Money Remove** | `player.Functions.RemoveMoney(type, amount, 'vehicle_loader')` |
| **Money Add** | `player.Functions.AddMoney(type, amount, 'vehicle_loader')` |
| **Job** | `player.PlayerData.job.name` |
| **Job Grade** | `player.PlayerData.job.grade.level` |
| **On Duty** | `player.PlayerData.job.onduty` |
| **Citizen ID** | `player.PlayerData.citizenid` |
| **Name** | `player.PlayerData.charinfo.firstname/lastname` |

### Client Events
```lua
qbx_core:client:onPlayerLoaded
QBCore:Client:OnJobUpdate
```

### Statebag Support
QBox nutzt moderne Statebags - wir hooken in `isLoggedIn`:
```lua
AddStateBagChangeHandler('isLoggedIn', ...)
```

### Job-Restriction Config
```lua
Config.Jobs = {
    ['mechanic'] = true,
    ['tow_truck'] = true,
}
```

### Money-Types
```lua
Config.Global.MoneyAccount = 'cash' -- oder 'bank'
```

---

## 📦 ESX Support (es_extended)

### Setup
```cfg
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure es_extended
ensure vehicle_loader
```

### Was wird genutzt?

| Feature | API |
|---------|-----|
| **Player Object** | `ESX.GetPlayerFromId(source)` |
| **Money Cash** | `xPlayer.getMoney()` |
| **Money Bank** | `xPlayer.getAccount('bank').money` |
| **Job** | `xPlayer.job.name` |
| **Job Grade** | `xPlayer.job.grade` |
| **Identifier** | `xPlayer.identifier` |
| **Name** | `xPlayer.getName()` |

### Client Events
```lua
esx:playerLoaded
esx:setJob
```

### ESX Legacy vs Modern
✅ ESX Legacy (`>=1.10.x`)  
✅ ESX Modern  
❌ ESX 1.1 (deprecated)

---

## 📦 QBCore Support (qb-core)

### Setup
```cfg
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure qb-core
ensure vehicle_loader
```

### Was wird genutzt?

| Feature | API |
|---------|-----|
| **Player Object** | `QBCore.Functions.GetPlayer(source)` |
| **Money** | `player.PlayerData.money[type]` |
| **Money Remove** | `player.Functions.RemoveMoney(type, amount, 'vehicle_loader')` |
| **Job** | `player.PlayerData.job.name` |
| **Job Grade** | `player.PlayerData.job.grade.level` |
| **Citizen ID** | `player.PlayerData.citizenid` |

### Client Events
```lua
QBCore:Client:OnPlayerLoaded
QBCore:Client:OnJobUpdate
```

---

## 📦 Standalone Support

### Setup
```cfg
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure vehicle_loader
```

### Was funktioniert?

✅ **Items** (via ox_inventory)  
✅ **Notifications** (via ox_lib)  
✅ **Progress Bars** (via ox_lib)  
✅ **Loading/Unloading** Vehicles  
✅ **Persistence** (via oxmysql)

### Was funktioniert NICHT?

❌ **Money Check** - kein Framework, kein Money System  
❌ **Job-Restrictions** - keine Jobs ohne Framework

### Config Anpassung

```lua
Config.Global = {
    MoneyRequired = 0,        -- Auf 0 setzen!
}

Config.Jobs = {
    -- Leer lassen!
}
```

---

## 🔍 Welches Framework wird genutzt?

### Im Spiel checken:
```
/loaderframework
```

### Via Code (Server):
```lua
local fw = exports.vehicle_loader:GetFramework()
print(fw) -- "qbox", "esx", "qbcore", oder "standalone"
```

### Via Code (Client):
```lua
local fw = exports.vehicle_loader:GetFramework()
```

---

## 🛠️ Bridge API (für Entwickler)

### Server-Side
```lua
Bridge.GetPlayer(source)         -- Player Object
Bridge.GetMoney(source, type)    -- Geld abrufen
Bridge.RemoveMoney(source, amount, type)
Bridge.AddMoney(source, amount, type)
Bridge.GetJob(source)            -- Job Name
Bridge.GetJobGrade(source)       -- Job Grade
Bridge.GetName(source)           -- Spieler Name
Bridge.GetIdentifier(source)     -- Unique ID
Bridge.HasItem(source, item, amount)
Bridge.RemoveItem(source, item, amount)
Bridge.AddItem(source, item, amount)
Bridge.Notify(source, title, msg, type)
```

### Client-Side
```lua
Bridge.GetJob()
Bridge.GetJobGrade()
Bridge.IsOnDuty()
Bridge.Notify(title, msg, type)
Bridge.ProgressBar(label, duration)
```

---

## 🐛 Troubleshooting

### "Framework: standalone" obwohl ESX/QBox/QB läuft

**Lösung:** Stelle sicher dass das Framework VOR `vehicle_loader` startet:
```cfg
ensure es_extended    # ZUERST
# ... andere
ensure vehicle_loader # DANN
```

### Money funktioniert nicht (QBox)

**Lösung:** QBox nutzt manchmal noch `qb-core` als Compat. Stelle sicher dass `qbx_core` läuft:
```
restart qbx_core
restart vehicle_loader
```

### "PlayerData ist leer" (Client)

**Lösung:** Spieler-Loaded Event noch nicht gefeuert. Bridge wartet automatisch auf:
- `esx:playerLoaded`
- `QBCore:Client:OnPlayerLoaded`
- `qbx_core:client:onPlayerLoaded`

### Jobs werden ignoriert

**Lösung:** Job-Name ist case-sensitive!
```lua
-- FALSCH:
Config.Jobs = { ['Mechanic'] = true }

-- RICHTIG (lowercase):
Config.Jobs = { ['mechanic'] = true }
```

---

## 💡 Empfehlungen pro Framework

### Neue Server → **QBox** wählen
- Moderne API
- ox_lib native Integration
- Bessere Performance
- Aktive Entwicklung

### Bestehende Server → Frame behalten
- Migration ist Aufwand
- Bridge funktioniert auf allen gleich

### Roleplay-Server → **ESX** oder **QBox**
- Beste Job-Systeme
- Eingebaute Money Accounts

### Race-Server / Standalone → **Standalone**
- Weniger Overhead
- Einfacher zu warten

---

## 📊 Feature-Matrix

| Feature | QBox | ESX | QBCore | Standalone |
|---------|:----:|:---:|:------:|:----------:|
| Money System | ✅ | ✅ | ✅ | ❌ |
| Jobs | ✅ | ✅ | ✅ | ❌ |
| Job Grades | ✅ | ✅ | ✅ | ❌ |
| On-Duty | ✅ | ❌ | ✅ | ❌ |
| Items (ox_inv) | ✅ | ✅ | ✅ | ✅ |
| Notifications | ✅ | ✅ | ✅ | ✅ |
| Persistence | ✅ | ✅ | ✅ | ✅ |
| Statebags | ✅ | ❌ | ❌ | ❌ |

---

**Aktuelle Bridge-Version**: 3.0.0  
**Getestet auf**: ESX Legacy 1.10+, QBCore 1.2+, QBox latest
