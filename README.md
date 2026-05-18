# amir_vehiclekeys

A production-ready FiveM vehicle key system for **ESX Legacy**, **ox_inventory**, **ox_lib**, and common **esx_garage** setups.

## Features

- Persistent per-plate vehicle keys backed by MySQL.
- Uses the plate as the canonical key identifier.
- `ox_inventory` key item metadata contains:
  - `plate`
  - `displayPlate`
  - `vehicle_model`
  - `owner`
  - `label`
  - `description`
- Automatic key creation for owned vehicles when spawned or entered.
- Owner-managed key sharing and revocation.
- `ox_lib` context menus, notifications, input dialogs, and progress bars.
- Driver-seat and engine immobilizer protection.
- Lock/unlock through command, menu, or key item use.
- Door lockpick and engine hotwire with server-side chance, cooldown, police alerts, alarm, and tool break risk.
- Optional job-based access and model whitelist.
- Server-side validation for sensitive actions.
- Exports for integration with other scripts.

## Installation

1. Copy this folder to your server resources directory.
2. Import `sql/install.sql` into your ESX database.
3. Add the key and lockpick items to `ox_inventory/data/items.lua`.
4. Add this resource after its dependencies in `server.cfg`:

```cfg
ensure oxmysql
ensure ox_lib
ensure es_extended
ensure ox_inventory
ensure esx_garage
ensure amir_vehiclekeys
```

## ox_inventory items

Add or adapt these items in `ox_inventory/data/items.lua`:

```lua
['vehiclekey'] = {
    label = 'Vehicle Key',
    weight = 50,
    stack = false,
    close = true,
    description = 'A programmed vehicle key.',
    client = { event = 'amir_vehiclekeys:client:useKeyItem' }
},

['keycard'] = {
    label = 'Vehicle Keycard',
    weight = 50,
    stack = false,
    close = true,
    description = 'A programmed vehicle keycard.',
    client = { event = 'amir_vehiclekeys:client:useKeyItem' }
},

['keys'] = {
    label = 'Keys',
    weight = 50,
    stack = false,
    close = true,
    description = 'A set of vehicle keys.',
    client = { event = 'amir_vehiclekeys:client:useKeyItem' }
},

['lockpick'] = {
    label = 'Lockpick',
    weight = 100,
    stack = true,
    close = true,
    description = 'A tool used to bypass vehicle door locks.'
},

['advancedlockpick'] = {
    label = 'Advanced Lockpick',
    weight = 150,
    stack = true,
    close = true,
    description = 'A tool used to hotwire vehicle engines.'
},
```

`Config.KeyItem` controls which item is given by default. `Config.AllowedKeyItems` controls which key item names the system recognizes.

## Commands and keys

- `/vlock` toggles the closest matching vehicle lock. Default key: `U`.
- `/keys` opens the vehicle key management menu. Default key: `F6`.

## ESX Legacy and esx_garage integration

The resource checks `owned_vehicles` using the normalized plate. If the player identifier matches the row owner, the server creates/repairs the persistent key record and gives a matching `ox_inventory` item.

Common garage spawn events are registered in `Config.GarageSpawnEvents`. If your `esx_garage` fork uses a different event, add it there. The handler accepts either:

- a vehicle entity handle, or
- a table containing at least `plate` and optionally `model`.

If your garage does not emit a spawn event, the player still receives keys when entering an owned vehicle, because the client asks the server to verify ownership.

## Security model

All sensitive decisions happen on the server:

- ownership is verified against `owned_vehicles`;
- sharing and revoking keys require owner/manager permission;
- target distance is verified server-side;
- lockpick/hotwire success, cooldown, item checks, and tool break are server-side;
- clients are not trusted for permission grants.

The client only performs UX tasks and local GTA vehicle lock/engine state changes after server permission checks.

## Exports

### Server

```lua
exports.amir_vehiclekeys:HasKey(source, plate, model)
exports.amir_vehiclekeys:CreateOwnedKey(source, plate, model)
exports.amir_vehiclekeys:AddKeyItem(source, plate, model, ownerIdentifier)
exports.amir_vehiclekeys:RemoveKeyItem(source, plate)
```

### Client

```lua
exports.amir_vehiclekeys:HasKey(vehicle)
exports.amir_vehiclekeys:OpenMenu(vehicle)
exports.amir_vehiclekeys:ToggleLock(vehicle)
```

## Lockpick / Hotwire configuration

`Config.Lockpick` controls:

- enabled/disabled state;
- required item names;
- progress bar duration;
- success chance;
- cooldown;
- temporary hotwire access duration;
- tool break chance;
- alarm duration;
- police alert chance.

Replace `Config.PoliceAlertEvent` with your dispatch resource event if you do not want to use the built-in police notify/blip example.

## Manual adaptation notes

- Some ESX Legacy databases store `owned_vehicles.vehicle.model` as a numeric GTA model hash. This resource stores the model as a string for display. You may replace `getVehicleModelFromOwnedRow` in `server/main.lua` if your garage stores a custom model label.
- Offline inventory item removal differs between ox_inventory setups. Revocation always updates the database. If the revoked holder is online, the key item is removed immediately. If they are offline, they will fail server-side permission checks even if an old item remains.
- If another resource controls engine state or vehicle locks, disable the overlapping feature in that resource or set `Config.EnableEngineImmobilizer` / `Config.EnablePreventDriverEntry` accordingly.

## فارسی - خلاصه نصب و تنظیمات

این اسکریپت برای ESX Legacy، ox_inventory، ox_lib و esx_garage آماده شده است. ابتدا فایل `sql/install.sql` را در دیتابیس ایمپورت کنید، آیتم‌های نمونه را به `ox_inventory/data/items.lua` اضافه کنید، سپس resource را بعد از dependencyها ensure کنید.

برای گاراژهای سفارشی، نام event اسپاون خودرو را در `Config.GarageSpawnEvents` اضافه کنید. اگر فرمت جدول `owned_vehicles` یا دیتای گاراژ شما متفاوت است، بخش `getVehicleModelFromOwnedRow` در `server/main.lua` را مطابق دیتابیس خود تغییر دهید.
