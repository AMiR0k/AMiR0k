local ESX = exports.es_extended:getSharedObject()
local plantLocks = {}
local registeredStashes = {}

local function now()
    return os.time()
end

local function expiryTimestamp()
    return now() + (Config.OwnershipDays * 86400)
end

local function isExpired(farm)
    return farm and tonumber(farm.expires_at) <= now()
end

local function stashId(uuid)
    return ('farm_%s'):format(uuid)
end

local function kgToGrams(kg)
    return math.floor(kg * 1000)
end

local function notify(source, message, notifyType)
    TriggerClientEvent('ox_lib:notify', source, { description = message, type = notifyType or 'inform' })
end

local function getIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer and xPlayer.identifier
end

local function isPlayerDead(source)
    local ped = GetPlayerPed(source)
    return not ped or ped == 0 or GetEntityHealth(ped) <= 0
end


local databaseReady = false
local databaseMigrating = false

local function ensureDatabaseSchema()
    if databaseReady then return true end

    while databaseMigrating do Wait(50) end
    if databaseReady then return true end

    databaseMigrating = true
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `player_farms` (
              `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
              `uuid` VARCHAR(36) NOT NULL,
              `owner_identifier` VARCHAR(64) NOT NULL,
              `farm_slot` INT UNSIGNED NOT NULL,
              `bucket` INT UNSIGNED NOT NULL,
              `expires_at` INT UNSIGNED NOT NULL,
              `stash_capacity` INT UNSIGNED NOT NULL DEFAULT 250,
              `created_at` INT UNSIGNED NOT NULL,
              PRIMARY KEY (`id`),
              UNIQUE KEY `uniq_player_farms_uuid` (`uuid`),
              KEY `idx_player_farms_owner` (`owner_identifier`),
              KEY `idx_player_farms_expires` (`expires_at`),
              UNIQUE KEY `uniq_player_farms_slot` (`farm_slot`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `farm_plants` (
              `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
              `farm_uuid` VARCHAR(36) NOT NULL,
              `slot_id` INT UNSIGNED NOT NULL,
              `seed_item` VARCHAR(64) NOT NULL,
              `product_item` VARCHAR(64) NOT NULL,
              `prop` VARCHAR(96) NOT NULL,
              `planted_at` INT UNSIGNED NOT NULL,
              `locked` TINYINT(1) NOT NULL DEFAULT 0,
              PRIMARY KEY (`id`),
              UNIQUE KEY `uniq_farm_plants_slot` (`farm_uuid`, `slot_id`),
              KEY `idx_farm_plants_age` (`planted_at`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `farm_access` (
              `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
              `farm_uuid` VARCHAR(36) NOT NULL,
              `identifier` VARCHAR(64) NOT NULL,
              `granted_by` VARCHAR(64) NOT NULL,
              `granted_at` INT UNSIGNED NOT NULL,
              PRIMARY KEY (`id`),
              UNIQUE KEY `uniq_farm_access_farm` (`farm_uuid`),
              KEY `idx_farm_access_identifier` (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `farm_storage_upgrade` (
              `farm_uuid` VARCHAR(36) NOT NULL,
              `upgraded` TINYINT(1) NOT NULL DEFAULT 0,
              `upgraded_at` INT UNSIGNED NULL DEFAULT NULL,
              PRIMARY KEY (`farm_uuid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]])

        local databaseName = MySQL.scalar.await('SELECT DATABASE()')

        local function columnExists(tableName, columnName)
            local count = MySQL.scalar.await([[
                SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?
            ]], { databaseName, tableName, columnName })

            return tonumber(count) and tonumber(count) > 0
        end

        local function addColumnIfMissing(tableName, columnName, definition)
            if columnExists(tableName, columnName) then return end
            MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tableName, columnName, definition))
            print(('[farming] Added missing database column %s.%s'):format(tableName, columnName))
        end

        -- These checks repair servers that already had a farm_plants table from an
        -- older/different farming script. Without this, queries using farm_uuid fail
        -- with "Unknown column 'farm_uuid' in 'where clause'".
        addColumnIfMissing('player_farms', 'uuid', 'VARCHAR(36) NULL')
        addColumnIfMissing('player_farms', 'owner_identifier', 'VARCHAR(64) NULL')
        addColumnIfMissing('player_farms', 'farm_slot', 'INT UNSIGNED NULL')
        addColumnIfMissing('player_farms', 'bucket', 'INT UNSIGNED NULL')
        addColumnIfMissing('player_farms', 'expires_at', 'INT UNSIGNED NOT NULL DEFAULT 0')
        addColumnIfMissing('player_farms', 'stash_capacity', ('INT UNSIGNED NOT NULL DEFAULT %d'):format(Config.InitialStorageKg))
        addColumnIfMissing('player_farms', 'created_at', 'INT UNSIGNED NOT NULL DEFAULT 0')

        addColumnIfMissing('farm_plants', 'farm_uuid', 'VARCHAR(36) NULL')
        addColumnIfMissing('farm_plants', 'slot_id', 'INT UNSIGNED NULL')
        addColumnIfMissing('farm_plants', 'seed_item', 'VARCHAR(64) NULL')
        addColumnIfMissing('farm_plants', 'product_item', 'VARCHAR(64) NULL')
        addColumnIfMissing('farm_plants', 'prop', 'VARCHAR(96) NULL')
        addColumnIfMissing('farm_plants', 'planted_at', 'INT UNSIGNED NOT NULL DEFAULT 0')
        addColumnIfMissing('farm_plants', 'locked', 'TINYINT(1) NOT NULL DEFAULT 0')

        addColumnIfMissing('farm_access', 'farm_uuid', 'VARCHAR(36) NULL')
        addColumnIfMissing('farm_access', 'identifier', 'VARCHAR(64) NULL')
        addColumnIfMissing('farm_access', 'granted_by', 'VARCHAR(64) NULL')
        addColumnIfMissing('farm_access', 'granted_at', 'INT UNSIGNED NOT NULL DEFAULT 0')

        addColumnIfMissing('farm_storage_upgrade', 'farm_uuid', 'VARCHAR(36) NULL')
        addColumnIfMissing('farm_storage_upgrade', 'upgraded', 'TINYINT(1) NOT NULL DEFAULT 0')
        addColumnIfMissing('farm_storage_upgrade', 'upgraded_at', 'INT UNSIGNED NULL DEFAULT NULL')
    end)

    databaseMigrating = false

    if not ok then
        print(('[farming] Database schema check failed: %s'):format(err))
        return false
    end

    databaseReady = true
    return true
end

local function registerFarmStash(farm)
    if not farm or registeredStashes[farm.uuid] then return end

    local capacity = tonumber(farm.stash_capacity) or Config.InitialStorageKg
    exports.ox_inventory:RegisterStash(stashId(farm.uuid), ('Farm Storage #%s'):format(farm.farm_slot), Config.StorageSlots, kgToGrams(capacity), false)
    registeredStashes[farm.uuid] = true
end

local function cleanupExpiredFarm(farm)
    if not ensureDatabaseSchema() then return end
    if not isExpired(farm) then return end
    MySQL.update.await('DELETE FROM farm_access WHERE farm_uuid = ?', { farm.uuid })
end

local function farmByOwner(identifier)
    if not ensureDatabaseSchema() then return nil end
    local farm = MySQL.single.await('SELECT * FROM player_farms WHERE owner_identifier = ? ORDER BY id DESC LIMIT 1', { identifier })
    if farm then cleanupExpiredFarm(farm) end
    return farm
end

local function farmByAccess(identifier)
    if not ensureDatabaseSchema() then return nil end
    local farm = MySQL.single.await([[ 
        SELECT pf.* FROM player_farms pf
        INNER JOIN farm_access fa ON fa.farm_uuid = pf.uuid
        WHERE fa.identifier = ? AND pf.expires_at > ?
        LIMIT 1
    ]], { identifier, now() })
    return farm
end

local function farmForPlayer(source)
    local identifier = getIdentifier(source)
    if not identifier then return nil end

    local owned = farmByOwner(identifier)
    if owned and not isExpired(owned) then
        owned.role = 'owner'
        return owned
    end

    local access = farmByAccess(identifier)
    if access then access.role = 'keyholder' end
    return access
end

local function isOwner(source, farm)
    return farm and farm.owner_identifier == getIdentifier(source)
end

local function canUseFarm(source, uuid)
    if not ensureDatabaseSchema() then return false end
    local identifier = getIdentifier(source)
    if not identifier then return false end

    local farm = MySQL.single.await('SELECT * FROM player_farms WHERE uuid = ?', { uuid })
    if not farm or isExpired(farm) then
        if farm then cleanupExpiredFarm(farm) end
        return false
    end

    if farm.owner_identifier == identifier then return true, farm, 'owner' end

    local access = MySQL.single.await('SELECT id FROM farm_access WHERE farm_uuid = ? AND identifier = ? LIMIT 1', { uuid, identifier })
    if access then return true, farm, 'keyholder' end

    return false
end

local function getPlants(uuid)
    if not ensureDatabaseSchema() then return {} end
    MySQL.update.await('DELETE FROM farm_plants WHERE farm_uuid = ? AND planted_at <= ?', { uuid, now() - (Config.PlantLifeHours * 3600) })
    return MySQL.query.await('SELECT * FROM farm_plants WHERE farm_uuid = ? ORDER BY slot_id ASC', { uuid }) or {}
end

local function usedSlots(uuid)
    if not ensureDatabaseSchema() then return {} end
    local rows = MySQL.query.await('SELECT slot_id FROM farm_plants WHERE farm_uuid = ?', { uuid }) or {}
    local used = {}
    for _, row in ipairs(rows) do used[tonumber(row.slot_id)] = true end
    return used
end

local function registerAllStashes()
    if not ensureDatabaseSchema() then return end
    local farms = MySQL.query.await('SELECT * FROM player_farms') or {}
    for _, farm in ipairs(farms) do registerFarmStash(farm) end
end

local function ensureStorageUpgradeRow(uuid)
    if not ensureDatabaseSchema() then return end
    MySQL.insert.await('INSERT IGNORE INTO farm_storage_upgrade (farm_uuid, upgraded, upgraded_at) VALUES (?, 0, NULL)', { uuid })
end

CreateThread(function()
    math.randomseed(os.time())
    Wait(500)
    ensureDatabaseSchema()
    registerAllStashes()
end)

exports.ox_inventory:registerHook('swapItems', function(payload)
    local toInv = tostring(payload.toInventory or '')
    local fromInv = tostring(payload.fromInventory or '')

    -- Players may withdraw from farm stashes, but direct deposits are blocked.
    if toInv:match('^farm_') and not fromInv:match('^farm_') then
        return false
    end

    return true
end)

lib.callback.register('amirok_farming:getMenuData', function(source)
    if not ensureDatabaseSchema() then return { hasFarm = false, error = 'database' } end
    local identifier = getIdentifier(source)
    if not identifier then return { hasFarm = false } end

    local ownedFarm = farmByOwner(identifier)
    local keyFarm = farmByAccess(identifier)
    local ownedData = nil
    local keyData = nil

    if ownedFarm then
        registerFarmStash(ownedFarm)
        ownedData = {
            role = 'owner',
            expired = isExpired(ownedFarm),
            farm = ownedFarm,
            remaining = math.max(0, tonumber(ownedFarm.expires_at) - now()),
            hasKeyholder = MySQL.scalar.await('SELECT identifier FROM farm_access WHERE farm_uuid = ? LIMIT 1', { ownedFarm.uuid })
        }
    end

    if keyFarm then
        registerFarmStash(keyFarm)
        keyData = {
            role = 'keyholder',
            expired = false,
            farm = keyFarm,
            remaining = math.max(0, tonumber(keyFarm.expires_at) - now())
        }
    end

    return {
        hasFarm = ownedData ~= nil or keyData ~= nil,
        hasOwnedFarm = ownedData ~= nil,
        hasKeyFarm = keyData ~= nil,
        owned = ownedData,
        key = keyData,

        -- Compatibility fields for any third-party code still reading the old shape.
        role = ownedData and ownedData.role or (keyData and keyData.role or nil),
        expired = ownedData and ownedData.expired or (keyData and keyData.expired or nil),
        farm = ownedData and ownedData.farm or (keyData and keyData.farm or nil),
        remaining = ownedData and ownedData.remaining or (keyData and keyData.remaining or 0),
        hasKeyholder = ownedData and ownedData.hasKeyholder or nil
    }
end)

lib.callback.register('amirok_farming:getSeeds', function(source)
    local result = {}
    for _, seed in ipairs(Config.SeedOrder) do
        local count = exports.ox_inventory:GetItemCount(source, seed) or 0
        if count > 0 then
            result[#result + 1] = { seed = seed, count = count, crop = Config.Crops[seed] }
        end
    end
    return result
end)

lib.callback.register('amirok_farming:getPlants', function(source, uuid)
    local allowed, farm = canUseFarm(source, uuid)
    if not allowed then return nil end
    registerFarmStash(farm)
    return getPlants(uuid)
end)

RegisterNetEvent('amirok_farming:buyFarm', function()
    local source = source
    if isPlayerDead(source) then return end
    local identifier = getIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not identifier or not xPlayer then return end

    local existing = farmByOwner(identifier)
    if existing then
        notify(source, 'شما از قبل یک زمین دارید.', 'error')
        return
    end

    if xPlayer.getMoney() < Config.PurchasePrice then
        notify(source, 'پول نقد کافی ندارید.', 'error')
        return
    end

    local takenRows = MySQL.query.await('SELECT farm_slot FROM player_farms') or {}
    local taken = {}
    for _, row in ipairs(takenRows) do taken[tonumber(row.farm_slot)] = true end

    local slot
    for i = 1, Config.FarmCount do
        if not taken[i] then slot = i break end
    end

    if not slot then
        notify(source, 'تمام زمین‌ها فروخته شده‌اند.', 'error')
        return
    end

    xPlayer.removeMoney(Config.PurchasePrice)
    local uuid = FarmUtils.uuid()
    local bucket = Config.Farm.baseBucket + slot

    MySQL.insert.await([[ 
        INSERT INTO player_farms (uuid, owner_identifier, farm_slot, bucket, expires_at, stash_capacity, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { uuid, identifier, slot, bucket, expiryTimestamp(), Config.InitialStorageKg, now() })

    ensureStorageUpgradeRow(uuid)
    registerFarmStash({ uuid = uuid, farm_slot = slot, stash_capacity = Config.InitialStorageKg })
    notify(source, 'زمین با موفقیت خریداری شد.', 'success')
end)

RegisterNetEvent('amirok_farming:renewFarm', function()
    local source = source
    if isPlayerDead(source) then return end
    local identifier = getIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local farm = identifier and farmByOwner(identifier)
    if not farm or not xPlayer then return end

    if not isExpired(farm) then
        notify(source, 'تا پایان زمان مالکیت امکان تمدید ندارید.', 'error')
        return
    end

    if xPlayer.getMoney() < Config.PurchasePrice then
        notify(source, 'پول نقد کافی ندارید.', 'error')
        return
    end

    xPlayer.removeMoney(Config.PurchasePrice)
    MySQL.update.await('UPDATE player_farms SET expires_at = ? WHERE uuid = ?', { expiryTimestamp(), farm.uuid })
    MySQL.update.await('DELETE FROM farm_access WHERE farm_uuid = ?', { farm.uuid })
    notify(source, 'زمین برای ۳۰ روز تمدید شد.', 'success')
end)

RegisterNetEvent('amirok_farming:upgradeStorage', function()
    local source = source
    if isPlayerDead(source) then return end
    local identifier = getIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local farm = identifier and farmByOwner(identifier)
    if not farm or not xPlayer or isExpired(farm) then return end

    if tonumber(farm.stash_capacity) >= Config.UpgradedStorageKg then
        notify(source, 'انبار قبلاً ارتقا یافته است.', 'error')
        return
    end

    if xPlayer.getMoney() < Config.StorageUpgradePrice then
        notify(source, 'پول نقد کافی ندارید.', 'error')
        return
    end

    xPlayer.removeMoney(Config.StorageUpgradePrice)
    MySQL.update.await('UPDATE player_farms SET stash_capacity = ? WHERE uuid = ?', { Config.UpgradedStorageKg, farm.uuid })
    MySQL.update.await('INSERT INTO farm_storage_upgrade (farm_uuid, upgraded, upgraded_at) VALUES (?, 1, ?) ON DUPLICATE KEY UPDATE upgraded = 1, upgraded_at = VALUES(upgraded_at)', { farm.uuid, now() })
    registeredStashes[farm.uuid] = nil
    registerFarmStash({ uuid = farm.uuid, farm_slot = farm.farm_slot, stash_capacity = Config.UpgradedStorageKg })
    notify(source, 'ظرفیت انبار به ۵۰۰ کیلو ارتقا یافت.', 'success')
end)

RegisterNetEvent('amirok_farming:grantAccess', function(targetServerId)
    local source = source
    if isPlayerDead(source) then return end
    local identifier = getIdentifier(source)
    local farm = identifier and farmByOwner(identifier)
    if not farm or isExpired(farm) then return end
    if not isOwner(source, farm) then return end

    local target = tonumber(targetServerId)
    local targetIdentifier = target and getIdentifier(target)
    if not targetIdentifier or target == source then
        notify(source, 'بازیکن معتبر نیست.', 'error')
        return
    end

    MySQL.update.await('DELETE FROM farm_access WHERE farm_uuid = ?', { farm.uuid })
    MySQL.insert.await('INSERT INTO farm_access (farm_uuid, identifier, granted_by, granted_at) VALUES (?, ?, ?, ?)', { farm.uuid, targetIdentifier, identifier, now() })
    notify(source, 'کلید زمین داده شد.', 'success')
    notify(target, 'به شما کلید یک زمین داده شد.', 'success')
end)

RegisterNetEvent('amirok_farming:revokeAccess', function()
    local source = source
    if isPlayerDead(source) then return end
    local identifier = getIdentifier(source)
    local farm = identifier and farmByOwner(identifier)
    if not farm or not isOwner(source, farm) then return end
    MySQL.update.await('DELETE FROM farm_access WHERE farm_uuid = ?', { farm.uuid })
    notify(source, 'دسترسی بازیکن دوم لغو شد.', 'success')
end)

lib.callback.register('amirok_farming:enterFarm', function(source, uuid)
    if isPlayerDead(source) then
        return { ok = false, message = 'در حالت مرگ نمی‌توانید وارد مزرعه شوید.' }
    end

    local allowed, farm = canUseFarm(source, uuid)
    if not allowed then
        return { ok = false, message = 'دسترسی به زمین ندارید یا زمان آن تمام شده است.' }
    end

    registerFarmStash(farm)
    SetPlayerRoutingBucket(source, tonumber(farm.bucket))

    return {
        ok = true,
        farm = farm,
        plants = getPlants(farm.uuid),
        serverTime = now()
    }
end)

lib.callback.register('amirok_farming:exitFarm', function(source)
    SetPlayerRoutingBucket(source, 0)
    return { ok = true }
end)

-- Backwards-compatible events for older clients; the main client now uses callbacks
-- so a failed server response can be handled without leaving the player on a black screen.
RegisterNetEvent('amirok_farming:enterFarm', function(uuid)
    local source = source
    if isPlayerDead(source) then
        TriggerClientEvent('amirok_farming:enterDenied', source, 'در حالت مرگ نمی‌توانید وارد مزرعه شوید.')
        return
    end

    local allowed, farm = canUseFarm(source, uuid)
    if not allowed then
        notify(source, 'دسترسی به زمین ندارید یا زمان آن تمام شده است.', 'error')
        TriggerClientEvent('amirok_farming:enterDenied', source)
        return
    end

    registerFarmStash(farm)
    SetPlayerRoutingBucket(source, tonumber(farm.bucket))
    TriggerClientEvent('amirok_farming:enteredFarm', source, farm, getPlants(farm.uuid))
end)

RegisterNetEvent('amirok_farming:exitFarm', function()
    local source = source
    SetPlayerRoutingBucket(source, 0)
    TriggerClientEvent('amirok_farming:exitedFarm', source)
end)

RegisterNetEvent('amirok_farming:plantSeed', function(uuid, slotId, seed, coords)
    local source = source
    if isPlayerDead(source) then return end
    local allowed, farm = canUseFarm(source, uuid)
    slotId = tonumber(slotId)

    if not allowed or not slotId or not Config.FarmSlots[slotId] or not Config.Crops[seed] then return end
    if not FarmUtils.pointInFarmRange(vector3(coords.x, coords.y, coords.z)) then return end
    if FarmUtils.distance(vector3(coords.x, coords.y, coords.z), Config.FarmSlots[slotId].coords) > 2.5 then return end

    local existing = MySQL.single.await('SELECT id FROM farm_plants WHERE farm_uuid = ? AND slot_id = ? LIMIT 1', { uuid, slotId })
    if existing then
        notify(source, 'این اسلات قبلاً کشت شده است.', 'error')
        return
    end

    local removed = exports.ox_inventory:RemoveItem(source, seed, 1)
    if not removed then
        notify(source, 'بذر کافی ندارید.', 'error')
        return
    end

    local plantTime = now()
    MySQL.insert.await([[ 
        INSERT INTO farm_plants (farm_uuid, slot_id, seed_item, product_item, prop, planted_at, locked)
        VALUES (?, ?, ?, ?, ?, ?, 0)
    ]], { uuid, slotId, seed, Config.Crops[seed].product, Config.Crops[seed].prop, plantTime })

    local plant = MySQL.single.await('SELECT * FROM farm_plants WHERE farm_uuid = ? AND slot_id = ? LIMIT 1', { uuid, slotId })
    TriggerClientEvent('amirok_farming:plantCreated', -1, uuid, plant)
end)

RegisterNetEvent('amirok_farming:harvestPlant', function(uuid, plantId, coords)
    local source = source
    if isPlayerDead(source) then return end
    local allowed, farm = canUseFarm(source, uuid)
    plantId = tonumber(plantId)
    if not allowed or not plantId then return end
    if not FarmUtils.pointInFarmRange(vector3(coords.x, coords.y, coords.z)) then return end
    if plantLocks[plantId] then return end

    plantLocks[plantId] = true
    local plant = MySQL.single.await('SELECT * FROM farm_plants WHERE id = ? AND farm_uuid = ? LIMIT 1', { plantId, uuid })

    if not plant then plantLocks[plantId] = nil return end
    if tonumber(plant.locked) == 1 then plantLocks[plantId] = nil return end

    local age = now() - tonumber(plant.planted_at)
    if age < (Config.GrowthMinutes * 60) then
        plantLocks[plantId] = nil
        notify(source, 'این گیاه هنوز آماده برداشت نیست.', 'error')
        return
    end

    if age > (Config.PlantLifeHours * 3600) then
        MySQL.update.await('DELETE FROM farm_plants WHERE id = ?', { plantId })
        plantLocks[plantId] = nil
        TriggerClientEvent('amirok_farming:plantRemoved', -1, uuid, plantId)
        return
    end

    MySQL.update.await('UPDATE farm_plants SET locked = 1 WHERE id = ?', { plantId })

    local productCount = math.random(Config.Harvest.productMin, Config.Harvest.productMax)
    local seedCount = math.random(Config.Harvest.seedMin, Config.Harvest.seedMax)
    local farmStash = stashId(farm.uuid)

    if not exports.ox_inventory:CanCarryItem(farmStash, plant.product_item, productCount) or not exports.ox_inventory:CanCarryItem(farmStash, plant.seed_item, seedCount) then
        MySQL.update.await('UPDATE farm_plants SET locked = 0 WHERE id = ?', { plantId })
        plantLocks[plantId] = nil
        notify(source, 'فضای انبار کافی نیست.', 'error')
        return
    end

    local addedProduct = exports.ox_inventory:AddItem(farmStash, plant.product_item, productCount)
    local addedSeeds = exports.ox_inventory:AddItem(farmStash, plant.seed_item, seedCount)

    if not addedProduct or not addedSeeds then
        if addedProduct then exports.ox_inventory:RemoveItem(farmStash, plant.product_item, productCount) end
        if addedSeeds then exports.ox_inventory:RemoveItem(farmStash, plant.seed_item, seedCount) end
        MySQL.update.await('UPDATE farm_plants SET locked = 0 WHERE id = ?', { plantId })
        plantLocks[plantId] = nil
        notify(source, 'فضای انبار کافی نیست.', 'error')
        return
    end

    MySQL.update.await('DELETE FROM farm_plants WHERE id = ?', { plantId })
    plantLocks[plantId] = nil
    TriggerClientEvent('amirok_farming:plantRemoved', -1, uuid, plantId)
    notify(source, ('برداشت انجام شد: %dx %s و %dx %s'):format(productCount, plant.product_item, seedCount, plant.seed_item), 'success')
end)

AddEventHandler('playerDropped', function()
    SetPlayerRoutingBucket(source, 0)
end)
