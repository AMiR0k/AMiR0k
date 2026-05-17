local ESX = exports['es_extended']:getSharedObject()

local missions = {}
local globalActiveSource = nil
local lastFinishedAt = 0

local function now()
    return os.time()
end

local function cooldownRemaining()
    local cooldownSeconds = Config.CooldownMinutes * 60
    local elapsed = now() - lastFinishedAt
    return math.max(0, cooldownSeconds - elapsed)
end

local function getPlayer(source)
    return ESX.GetPlayerFromId(source)
end

local function isPoliceJob(jobName)
    return jobName and Config.PoliceJobs[jobName] == true
end

local function countPolice()
    local total = 0

    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xPlayer = getPlayer(playerId)
        local jobName = xPlayer and xPlayer.getJob().name
        if isPoliceJob(jobName) then
            total = total + 1
        end
    end

    return total
end

local function notifyPolice(eventName, ...)
    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xPlayer = getPlayer(playerId)
        local jobName = xPlayer and xPlayer.getJob().name
        if isPoliceJob(jobName) then
            TriggerClientEvent(eventName, playerId, ...)
        end
    end
end

local function cleanupMission(source, setCooldown)
    local mission = missions[source]
    if not mission then
        return
    end

    if mission.keyGiven and Config.VehicleKeys.enabled and Config.VehicleKeys.removeOnFinish then
        exports.ox_inventory:RemoveItem(source, Config.VehicleKeys.item, 1, mission.keyMetadata)
    end

    missions[source] = nil

    if globalActiveSource == source then
        globalActiveSource = nil
    end

    if setCooldown then
        lastFinishedAt = now()
    end

    notifyPolice('carthief:clearPoliceBlip')
end

local function giveVehicleKey(source, mission)
    if not Config.VehicleKeys.enabled then
        return true
    end

    if GetResourceState('ox_inventory') ~= 'started' then
        print(('[carthief] ox_inventory is not started, cannot give %s.'):format(Config.VehicleKeys.item))
        return false
    end

    local metadata = {
        plate = mission.plate,
        model = mission.model,
        label = ('%s | %s'):format(mission.model, mission.plate)
    }

    local added = exports.ox_inventory:AddItem(source, Config.VehicleKeys.item, 1, metadata)
    mission.keyGiven = added == true
    mission.keyMetadata = metadata

    -- Optional external key integration example:
    -- exports.your_vehiclekeys:GiveKey(source, mission.plate, mission.model)

    return added == true
end

local function addReward(xPlayer, amount)
    if Config.PayAccount == 'money' then
        xPlayer.addMoney(amount)
    else
        xPlayer.addAccountMoney(Config.PayAccount, amount)
    end
end

local function getEntityFromMission(mission)
    if not mission.netId then
        return nil
    end

    local entity = NetworkGetEntityFromNetworkId(mission.netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return nil
    end

    return entity
end

local function validateMissionVehicle(source, mission, data)
    if type(data) ~= 'table' then
        return false
    end

    if tonumber(data.netId) ~= tonumber(mission.netId) then
        return false
    end

    if data.plate and mission.plate and data.plate ~= mission.plate then
        return false
    end

    local entity = getEntityFromMission(mission)
    if not entity then
        return false
    end

    local ped = GetPlayerPed(source)
    if ped == 0 then
        return false
    end

    if GetVehiclePedIsIn(ped, false) ~= entity then
        return false
    end

    if GetEntitySpeed(entity) >= Config.MinDeliverySpeed then
        return false
    end

    local coords = GetEntityCoords(entity)
    local delivery = Config.Deliveries[mission.deliveryId]
    if not delivery or #(coords - delivery.coords) > Config.FinishDistance then
        return false
    end

    return true
end

lib.callback.register('carthief:startMission', function(source)
    local xPlayer = getPlayer(source)
    if not xPlayer then
        return { success = false, message = _L('invalid_mission') }
    end

    if missions[source] then
        return { success = false, message = _L('already_have_mission') }
    end

    if Config.SingleActiveMission and globalActiveSource then
        return { success = false, message = _L('already_robbery') }
    end

    local remaining = cooldownRemaining()
    if remaining > 0 then
        return {
            success = false,
            message = _L('cooldown', math.ceil(remaining / 60))
        }
    end

    if countPolice() < Config.CopsRequired then
        return { success = false, message = _L('not_enough_cops') }
    end

    local deliveryId = math.random(1, #Config.Deliveries)
    local delivery = Config.Deliveries[deliveryId]
    local model = delivery.cars[math.random(1, #delivery.cars)]

    missions[source] = {
        source = source,
        deliveryId = deliveryId,
        model = model,
        payment = delivery.payment,
        startedAt = now(),
        registered = false
    }

    if Config.SingleActiveMission then
        globalActiveSource = source
    end

    return {
        success = true,
        mission = {
            deliveryId = deliveryId,
            model = model,
            delivery = {
                label = delivery.label,
                coords = delivery.coords
            }
        }
    }
end)

lib.callback.register('carthief:registerVehicle', function(source, data)
    local mission = missions[source]
    if not mission or mission.registered then
        return false, _L('invalid_mission')
    end

    if type(data) ~= 'table' or not data.netId or type(data.plate) ~= 'string' then
        cleanupMission(source, false)
        return false, _L('invalid_mission')
    end

    local entity = NetworkGetEntityFromNetworkId(data.netId)
    if entity == 0 or not DoesEntityExist(entity) then
        cleanupMission(source, false)
        return false, _L('invalid_mission')
    end

    if GetEntityModel(entity) ~= joaat(mission.model) then
        cleanupMission(source, false)
        return false, _L('invalid_mission')
    end

    local spawnCoords = vec3(Config.VehicleSpawnPoint.coords.x, Config.VehicleSpawnPoint.coords.y, Config.VehicleSpawnPoint.coords.z)
    if #(GetEntityCoords(entity) - spawnCoords) > 20.0 then
        cleanupMission(source, false)
        return false, _L('invalid_mission')
    end

    local owner = NetworkGetEntityOwner(entity)
    if owner ~= source then
        cleanupMission(source, false)
        return false, _L('invalid_mission')
    end

    mission.netId = data.netId
    mission.plate = data.plate
    mission.registered = true

    giveVehicleKey(source, mission)

    local coords = GetEntityCoords(entity)
    notifyPolice('carthief:policeAlert', coords, true)

    return true
end)

lib.callback.register('carthief:finishMission', function(source, data)
    local xPlayer = getPlayer(source)
    local mission = missions[source]

    if not xPlayer or not mission or not mission.registered then
        return false, _L('invalid_mission')
    end

    if not validateMissionVehicle(source, mission, data) then
        return false, _L('car_provided_rule')
    end

    local payment = mission.payment
    addReward(xPlayer, payment)
    cleanupMission(source, true)

    return true, nil, payment
end)

lib.callback.register('carthief:abortMission', function(source)
    if not missions[source] then
        return false
    end

    cleanupMission(source, true)
    return true
end)

RegisterNetEvent('carthief:updatePoliceBlip', function(netId, coords)
    local source = source
    local mission = missions[source]

    if not mission or not mission.registered or tonumber(netId) ~= tonumber(mission.netId) then
        return
    end

    if type(coords) ~= 'vector3' then
        return
    end

    local entity = getEntityFromMission(mission)
    if not entity then
        cleanupMission(source, true)
        TriggerClientEvent('carthief:forceAbort', source, _L('vehicle_destroyed'))
        return
    end

    local actualCoords = GetEntityCoords(entity)
    if #(actualCoords - coords) > 25.0 then
        coords = actualCoords
    end

    notifyPolice('carthief:policeAlert', coords, false)
end)

AddEventHandler('playerDropped', function()
    cleanupMission(source, true)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for source in pairs(missions) do
        TriggerClientEvent('carthief:forceAbort', source, _L('mission_aborted'))
    end
end)
