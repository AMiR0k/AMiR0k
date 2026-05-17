# Car Thief for ESX Legacy, ox_lib, and ox_inventory

A modern rewrite of an old ESX vehicle theft / delivery job. Players start a robbery at the configured dock location, receive a random vehicle tied to a random delivery destination, police receive live stolen-vehicle blips, and the reward is validated and paid server-side.

## File structure

```text
fxmanifest.lua
config.lua
shared/locale.lua
client/main.lua
server/main.lua
locales/en.lua
locales/fa.lua
```

## Installation

1. Place this folder in your server `resources` directory.
2. Ensure dependencies start before this resource:
   ```cfg
   ensure ox_lib
   ensure es_extended
   ensure ox_inventory
   ensure AMiR0k
   ```
3. Review `config.lua` for police jobs, cooldown, delivery payouts, vehicles, and reward account.
4. If you want inventory-based vehicle keys, enable `Config.VehicleKeys.enabled` and add the item below to `ox_inventory/data/items.lua`.

## Optional ox_inventory key item

```lua
['vehicle_key'] = {
    label = 'Vehicle Key',
    weight = 50,
    stack = false,
    close = true,
    description = 'A key for a specific vehicle.'
}
```

The default key logic only gives/removes an `ox_inventory` item with `plate` and `model` metadata. If your server uses a dedicated vehicle key resource, keep `Config.VehicleKeys.enabled = false` and integrate that export in `server/main.lua` inside `giveVehicleKey`.
