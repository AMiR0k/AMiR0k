local ESX = exports.es_extended:getSharedObject()
local cooldowns = {}
local hotwiredVehicles = {}

math.randomseed(os.time())

local function notify(source, title, description, notifyType)
    TriggerClientEvent('ox_lib:notify', source, {
        title = title or 'Vehicle Keys',
        description = description,
        type = notifyType or 'inform',
        position = Config.Notifications.position
    })
end

local function getPlayer(source)
    return ESX.GetPlayerFromId(source)
end

local function getIdentifier(source)
    local xPlayer = getPlayer(source)
    return xPlayer and xPlayer.getIdentifier() or nil
end

local function getPlayerNameSafe(source)
    local xPlayer = getPlayer(source)
    if not xPlayer then return GetPlayerName(source) or 'Unknown' end
    return xPlayer.getName and xPlayer.getName() or GetPlayerName(source) or 'Unknown'
end

local function hasInventoryItem(source, itemName)
    return (exports.ox_inventory:GetItemCount(source, itemName) or 0) > 0
end

local function playerHasKeyItem(source, plate)
    local normalized = VehicleKeys.NormalizePlate(plate)

    for itemName in pairs(Config.AllowedKeyItems) do
        local slots = exports.ox_inventory:Search(source, 'slots', itemName) or {}
        for _, slot in pairs(slots) do
            local metadata = slot.metadata or {}
            if VehicleKeys.NormalizePlate(metadata.plate or metadata.displayPlate) == normalized then
                return true, itemName, slot
            end
        end
    end

    return false, nil, nil
end

local function addKeyItem(source, plate, model, ownerIdentifier)
    if playerHasKeyItem(source, plate) then return true end

    local metadata = VehicleKeys.KeyMetadata(plate, model, ownerIdentifier)
    return exports.ox_inventory:AddItem(source, Config.KeyItem, 1, metadata)
end

local function removeKeyItem(source, plate)
    local normalized = VehicleKeys.NormalizePlate(plate)
    local removed = false

    for itemName in pairs(Config.AllowedKeyItems) do
        local slots = exports.ox_inventory:Search(source, 'slots', itemName) or {}
        for _, slot in pairs(slots) do
            local metadata = slot.metadata or {}
            if VehicleKeys.NormalizePlate(metadata.plate or metadata.displayPlate) == normalized then
                exports.ox_inventory:RemoveItem(source, itemName, 1, nil, slot.slot)
                removed = true
            end
        end
    end

    return removed
end

local function getOwnedVehicle(plate)
    local normalized = VehicleKeys.NormalizePlate(plate)
    return MySQL.single.await([[
        SELECT owner, plate, vehicle
        FROM owned_vehicles
        WHERE REPLACE(UPPER(plate), ' ', '') = ?
        LIMIT 1
    ]], { normalized })
end

local function isVehicleOwner(identifier, plate)
    if not identifier then return false end
    local ownedVehicle = getOwnedVehicle(plate)
    return ownedVehicle and ownedVehicle.owner == identifier, ownedVehicle
end

local function getVehicleModelFromOwnedRow(row, fallbackModel)
    if not row or not row.vehicle then return VehicleKeys.ModelName(fallbackModel) end

    local ok, data = pcall(json.decode, row.vehicle)
    if ok and data then
        if data.model then return VehicleKeys.ModelName(data.model) end
        if data.name then return VehicleKeys.ModelName(data.name) end
    end

    return VehicleKeys.ModelName(fallbackModel)
end

local function ensureVehicleRecord(plate, model, ownerIdentifier, ownerName)
    local normalized = VehicleKeys.NormalizePlate(plate)
    local display = VehicleKeys.DisplayPlate(plate)
    local modelName = VehicleKeys.ModelName(model)
    local label = VehicleKeys.KeyLabel(display, modelName)

    MySQL.insert.await([[
        INSERT INTO vehicle_keys (plate, display_plate, owner_identifier, owner_name, vehicle_model, label)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            display_plate = VALUES(display_plate),
            vehicle_model = IF(vehicle_model IS NULL OR vehicle_model = '' OR vehicle_model = 'unknown', VALUES(vehicle_model), vehicle_model),
            label = VALUES(label),
            updated_at = CURRENT_TIMESTAMP
    ]], { normalized, display, ownerIdentifier, ownerName, modelName, label })

    if ownerIdentifier then
        MySQL.insert.await([[
            INSERT INTO vehicle_key_permissions (plate, identifier, holder_name, granted_by, permission_type, active)
            VALUES (?, ?, ?, ?, 'owner', 1)
            ON DUPLICATE KEY UPDATE
                holder_name = VALUES(holder_name),
                permission_type = 'owner',
                active = 1,
                revoked_at = NULL
        ]], { normalized, ownerIdentifier, ownerName or 'Owner', ownerIdentifier })
    end
end

local function dbHasActivePermission(identifier, plate)
    if not identifier then return false end
    local normalized = VehicleKeys.NormalizePlate(plate)
    local count = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM vehicle_key_permissions
        WHERE plate = ? AND identifier = ? AND active = 1
    ]], { normalized, identifier })

    return tonumber(count) ~= nil and tonumber(count) > 0
end

local function hasJobAccess(source, model)
    local xPlayer = getPlayer(source)
    if not xPlayer or not xPlayer.job then return false end

    local jobConfig = Config.JobAccess[xPlayer.job.name]
    if not jobConfig or not jobConfig.enabled then return false end

    if jobConfig.grades and not jobConfig.grades[xPlayer.job.grade] then return false end
    if jobConfig.models and not jobConfig.models[VehicleKeys.ModelName(model)] then return false end

    return true
end

local function hasTemporaryHotwire(source, plate)
    local src = tonumber(source)
    local normalized = VehicleKeys.NormalizePlate(plate)
    local expires = hotwiredVehicles[src] and hotwiredVehicles[src][normalized]
    if not expires then return false end

    if expires < os.time() then
        hotwiredVehicles[src][normalized] = nil
        return false
    end

    return true
end

local function hasServerKey(source, plate, model)
    local identifier = getIdentifier(source)
    if not identifier then return false end

    local isOwner, ownedVehicle = isVehicleOwner(identifier, plate)
    if isOwner then
        local vehicleModel = getVehicleModelFromOwnedRow(ownedVehicle, model)
        ensureVehicleRecord(plate, vehicleModel, identifier, getPlayerNameSafe(source))
        addKeyItem(source, plate, vehicleModel, identifier)
        return true, 'owner'
    end

    if dbHasActivePermission(identifier, plate) then
        if not playerHasKeyItem(source, plate) then
            local row = MySQL.single.await('SELECT vehicle_model, owner_identifier FROM vehicle_keys WHERE plate = ? LIMIT 1', { VehicleKeys.NormalizePlate(plate) })
            addKeyItem(source, plate, row and row.vehicle_model or model, row and row.owner_identifier or identifier)
        end
        return true, 'permission'
    end

    if hasTemporaryHotwire(source, plate) then
        return true, 'hotwire'
    end

    if hasJobAccess(source, model) then
        return true, 'job'
    end

    return false, 'none'
end

local function canManageKeys(source, plate)
    local identifier = getIdentifier(source)
    if not identifier then return false end

    local isOwner = isVehicleOwner(identifier, plate)
    if isOwner then return true end

    local permissionType = MySQL.scalar.await([[
        SELECT permission_type
        FROM vehicle_key_permissions
        WHERE plate = ? AND identifier = ? AND active = 1
        LIMIT 1
    ]], { VehicleKeys.NormalizePlate(plate), identifier })

    return permissionType == 'owner' or permissionType == 'manager'
end

lib.callback.register('amir_vehiclekeys:server:hasKey', function(source, plate, model)
    if not plate then return false end
    local allowed = hasServerKey(source, plate, model)
    return allowed
end)

lib.callback.register('amir_vehiclekeys:server:ensureOwnedKey', function(source, plate, model)
    if not Config.AutoGiveKeyForOwnedVehicle or not plate then return false end
    if not VehicleKeys.IsModelAllowed(model) then return false end

    local identifier = getIdentifier(source)
    local isOwner, ownedVehicle = isVehicleOwner(identifier, plate)
    if not isOwner then return false end

    local vehicleModel = getVehicleModelFromOwnedRow(ownedVehicle, model)
    ensureVehicleRecord(plate, vehicleModel, identifier, getPlayerNameSafe(source))
    addKeyItem(source, plate, vehicleModel, identifier)
    return true
end)

lib.callback.register('amir_vehiclekeys:server:giveKey', function(source, plate, model, targetId)
    targetId = tonumber(targetId)
    if not plate or not targetId or targetId == source or GetPlayerPed(targetId) == 0 then return false, 'Invalid target.' end
    if not VehicleKeys.IsModelAllowed(model) then return false, 'This vehicle model is not supported.' end
    if not canManageKeys(source, plate) then return false, 'You cannot manage keys for this vehicle.' end

    local sourcePed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed == 0 or targetPed == 0 or #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) > Config.GiveDistance then
        return false, 'Target is too far away.'
    end

    local targetIdentifier = getIdentifier(targetId)
    local ownerIdentifier = MySQL.scalar.await('SELECT owner_identifier FROM vehicle_keys WHERE plate = ? LIMIT 1', { VehicleKeys.NormalizePlate(plate) })
        or getIdentifier(source)
    if not targetIdentifier then return false, 'Target player is not loaded.' end

    ensureVehicleRecord(plate, model, ownerIdentifier, getPlayerNameSafe(source))
    MySQL.insert.await([[
        INSERT INTO vehicle_key_permissions (plate, identifier, holder_name, granted_by, permission_type, active)
        VALUES (?, ?, ?, ?, 'shared', 1)
        ON DUPLICATE KEY UPDATE
            holder_name = VALUES(holder_name),
            granted_by = VALUES(granted_by),
            permission_type = IF(permission_type = 'owner', 'owner', 'shared'),
            active = 1,
            revoked_at = NULL
    ]], { VehicleKeys.NormalizePlate(plate), targetIdentifier, getPlayerNameSafe(targetId), getIdentifier(source) })

    addKeyItem(targetId, plate, model, ownerIdentifier)
    notify(source, 'Vehicle Keys', 'Key shared successfully.', 'success')
    notify(targetId, 'Vehicle Keys', ('You received a key for %s.'):format(VehicleKeys.DisplayPlate(plate)), 'success')
    return true
end)

lib.callback.register('amir_vehiclekeys:server:removeKey', function(source, plate, targetIdentifierOrId)
    if not plate or not targetIdentifierOrId then return false, 'Missing data.' end
    if not canManageKeys(source, plate) then return false, 'You cannot manage keys for this vehicle.' end

    local targetIdentifier = tostring(targetIdentifierOrId)
    local targetSource = tonumber(targetIdentifierOrId)
    if targetSource and GetPlayerPed(targetSource) ~= 0 then
        targetIdentifier = getIdentifier(targetSource)
    end

    local ownerIdentifier = MySQL.scalar.await('SELECT owner_identifier FROM vehicle_keys WHERE plate = ? LIMIT 1', { VehicleKeys.NormalizePlate(plate) })
    if targetIdentifier == ownerIdentifier then return false, 'Owner key cannot be removed.' end

    local affected = MySQL.update.await([[
        UPDATE vehicle_key_permissions
        SET active = 0, revoked_at = CURRENT_TIMESTAMP
        WHERE plate = ? AND identifier = ? AND permission_type <> 'owner'
    ]], { VehicleKeys.NormalizePlate(plate), targetIdentifier })

    for _, playerId in ipairs(GetPlayers()) do
        if getIdentifier(tonumber(playerId)) == targetIdentifier then
            removeKeyItem(tonumber(playerId), plate)
            notify(tonumber(playerId), 'Vehicle Keys', ('Your key for %s was revoked.'):format(VehicleKeys.DisplayPlate(plate)), 'warning')
        end
    end

    local removed = tonumber(affected) ~= nil and tonumber(affected) > 0
    return removed, removed and nil or 'No removable key found.'
end)

lib.callback.register('amir_vehiclekeys:server:getHolders', function(source, plate)
    if not plate or not canManageKeys(source, plate) then return {} end

    return MySQL.query.await([[
        SELECT identifier, holder_name, permission_type, created_at
        FROM vehicle_key_permissions
        WHERE plate = ? AND active = 1
        ORDER BY permission_type = 'owner' DESC, holder_name ASC
    ]], { VehicleKeys.NormalizePlate(plate) }) or {}
end)

lib.callback.register('amir_vehiclekeys:server:attemptLockpick', function(source, mode, plate, model)
    if not Config.Lockpick.enabled or not plate then return false, 'Lockpick is disabled.' end
    if mode ~= 'door' and mode ~= 'hotwire' then return false, 'Invalid lockpick mode.' end
    if hasServerKey(source, plate, model) then return false, 'You already have access to this vehicle.' end

    local now = os.time()
    local key = ('%s:%s'):format(source, mode)
    if cooldowns[key] and cooldowns[key] > now then
        return false, ('Cooldown active for %s seconds.'):format(cooldowns[key] - now)
    end

    local itemName = mode == 'door' and Config.Lockpick.doorItem or Config.Lockpick.hotwireItem
    if not hasInventoryItem(source, itemName) then return false, ('You need %s.'):format(itemName) end

    cooldowns[key] = now + Config.Lockpick.cooldownSeconds
    local chance = mode == 'door' and Config.Lockpick.doorSuccessChance or Config.Lockpick.hotwireSuccessChance
    local success = math.random(100) <= chance
    local breakChance = success and Config.Lockpick.toolBreakChanceOnSuccess or Config.Lockpick.toolBreakChanceOnFail

    if math.random(100) <= breakChance then
        exports.ox_inventory:RemoveItem(source, itemName, 1)
    end

    if success and mode == 'hotwire' then
        local src = tonumber(source)
        hotwiredVehicles[src] = hotwiredVehicles[src] or {}
        hotwiredVehicles[src][VehicleKeys.NormalizePlate(plate)] = now + (Config.Lockpick.hotwireAccessMinutes * 60)
    end

    local shouldAlert = (not success and Config.Lockpick.alertPoliceOnFail and math.random(100) <= Config.Lockpick.alertPoliceChance)
    if shouldAlert then
        TriggerEvent(Config.PoliceAlertEvent, source, mode, VehicleKeys.DisplayPlate(plate), VehicleKeys.ModelName(model))
    end

    return success, success and nil or 'Lockpick attempt failed.', shouldAlert
end)

for itemName in pairs(Config.AllowedKeyItems) do
    ESX.RegisterUsableItem(itemName, function(source, item)
        local metadata = item and item.metadata or item and item.info or {}
        TriggerClientEvent('amir_vehiclekeys:client:useKeyItem', source, metadata)
    end)
end

AddEventHandler(Config.PoliceAlertEvent, function(source, mode, plate, model)
    local coords = GetEntityCoords(GetPlayerPed(source))
    for _, playerId in ipairs(GetPlayers()) do
        local xPlayer = getPlayer(tonumber(playerId))
        if xPlayer and xPlayer.job and xPlayer.job.name == 'police' then
            TriggerClientEvent('amir_vehiclekeys:client:policeAlert', tonumber(playerId), {
                mode = mode,
                plate = plate,
                model = model,
                coords = coords
            })
        end
    end
end)

AddEventHandler('playerDropped', function()
    hotwiredVehicles[source] = nil
end)

exports('HasKey', function(source, plate, model)
    return hasServerKey(source, plate, model)
end)

exports('CreateOwnedKey', function(source, plate, model)
    local identifier = getIdentifier(source)
    if not identifier or not plate then return false end
    ensureVehicleRecord(plate, model, identifier, getPlayerNameSafe(source))
    return addKeyItem(source, plate, model, identifier)
end)

exports('RemoveKeyItem', removeKeyItem)
exports('AddKeyItem', addKeyItem)
