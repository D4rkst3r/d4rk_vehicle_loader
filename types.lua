-- Vehicle Loader Type Definitions (LuaCATS)
-- Für IDE-Support mit sumneko-lua / oxlint

---@meta

---@class TrailerSlot
---@field id number
---@field offset vector3
---@field rotation vector3
---@field type? 'bike'|'car'|'suv'|'truck' Preset für Slot-Größe
---@field size? vector3 Custom Größe (überschreibt type)

---@class RampConfig
---@field enabled boolean
---@field doorIndex number
---@field openTime number

---@class TrailerConfig
---@field model string
---@field label string
---@field maxVehicles number
---@field ramp RampConfig
---@field slots TrailerSlot[]

---@class GlobalConfig
---@field Locale 'de'|'en'
---@field MoneyRequired number
---@field MoneyAccount 'cash'|'bank'
---@field LoadingTime number
---@field UnloadingTime number
---@field UnloadDistance number
---@field ConfirmUnload boolean
---@field RefundItemsOnUnload boolean
---@field EnableAnimations boolean
---@field EnableParticles boolean
---@field EnableEffects boolean
---@field DebugMode boolean

---@class StorageConfig
---@field Enabled boolean
---@field Provider 'auto'|'oxmysql'|'external'
---@field MatchByPlate boolean
---@field RestoreDelay number

---@class VehicleLoaderConfig
---@field Global GlobalConfig
---@field Storage StorageConfig
---@field Jobs table<string, boolean>
---@field RequiredItems table<string, number>
---@field Trailers TrailerConfig[]

---@class LoadedVehicleData
---@field trailerNet number
---@field slotId number
---@field owner number
---@field loadedAt number

---@class SlotLock
---@field source number
---@field lockedAt number

---@class StatebagAttachData
---@field trailerNet number
---@field slotId number

---@class PersistedVehicleData
---@field trailerPlate string
---@field slotId number
---@field owner number
---@field loadedAt number

-- Globals
---@type VehicleLoaderConfig
Config = Config

---@type table
Bridge = Bridge

---@type table
Effects = Effects

---@type table
StatebagAPI = StatebagAPI

---@type table
Security = Security
