local players = {}

local function getPlayerState(source)
    players[source] = players[source] or {
        active = false,
        depositPaid = false,
        tugNetId = nil,
        hasOil = false,
        loading = false,
        loadingStartedAt = nil,
        delivering = false,
        deliveryStartedAt = nil
    }

    return players[source]
end

local function notify(source, description, notifyType)
    TriggerClientEvent('ox_lib:notify', source, {
        title = Config.Job.name,
        description = description,
        type = notifyType or 'inform'
    })
end

local function getPed(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return ped
end

local function isNear(source, coords, maxDistance)
    local ped = getPed(source)
    if not ped then return false end

    local playerCoords = GetEntityCoords(ped)
    return #(playerCoords - coords) <= (maxDistance or 12.0)
end

local function getEntityFromNetId(netId)
    if type(netId) ~= 'number' then return 0 end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return 0
    end

    return entity
end

local function isRegisteredTugDriver(source, state, netId)
    if not state.tugNetId or state.tugNetId ~= netId then return false end

    local ped = getPed(source)
    local vehicle = getEntityFromNetId(netId)
    if not ped or vehicle == 0 then return false end

    local currentVehicle = GetVehiclePedIsIn(ped, false)
    return currentVehicle == vehicle and GetPedInVehicleSeat(vehicle, -1) == ped
end

local function resetRouteState(state)
    state.hasOil = false
    state.loading = false
    state.loadingStartedAt = nil
    state.delivering = false
    state.deliveryStartedAt = nil
end

local function hasTimerElapsed(startedAt, duration)
    return type(startedAt) == 'number' and GetGameTimer() - startedAt >= duration
end

lib.callback.register('oilrunner:server:toggleJob', function(source)
    local state = getPlayerState(source)

    if state.active then
        if state.depositPaid or state.tugNetId then
            notify(source, Config.Notifications.returnTugFirst, 'error')
            return { success = false, active = true, message = Config.Notifications.returnTugFirst }
        end

        state.active = false
        resetRouteState(state)
        return { success = true, active = false, message = Config.Notifications.stopped }
    end

    state.active = true
    resetRouteState(state)
    return { success = true, active = true, message = Config.Notifications.started }
end)

lib.callback.register('oilrunner:server:spawnTug', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return { success = false, message = 'Player not found.' } end

    local state = getPlayerState(source)
    if not state.active then
        return { success = false, message = 'You must start the Oil Runner job first.' }
    end

    if state.depositPaid or state.tugNetId then
        return { success = false, message = Config.Notifications.alreadyTug }
    end

    if xPlayer.getMoney() < Config.Job.deposit then
        return { success = false, message = Config.Notifications.noCash }
    end

    -- Remove the refundable deposit before creating the tug so spawn attempts cannot bypass payment.
    xPlayer.removeMoney(Config.Job.deposit)
    state.depositPaid = true

    local spawn = Config.Locations.tugSpawn
    local vehicle = CreateVehicle(joaat(Config.Vehicle.model), spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    local timeout = GetGameTimer() + 5000

    while vehicle == 0 and GetGameTimer() < timeout do
        Wait(0)
        vehicle = CreateVehicle(joaat(Config.Vehicle.model), spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        -- If creation fails immediately, refund because no active tug was issued.
        xPlayer.addMoney(Config.Job.deposit)
        state.depositPaid = false
        return { success = false, message = 'Unable to spawn the tug. Your deposit was refunded.' }
    end

    SetEntityHeading(vehicle, spawn.w)
    SetVehicleNumberPlateText(vehicle, ('OIL%03d'):format(source % 1000))
    Entity(vehicle).state:set('fuel', Config.Vehicle.fuel, true)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    state.tugNetId = netId
    resetRouteState(state)

    return { success = true, netId = netId, message = Config.Notifications.tugSpawned }
end)

lib.callback.register('oilrunner:server:startLoading', function(source, netId)
    local state = getPlayerState(source)

    if not state.active or not state.tugNetId then
        return { success = false, message = 'You do not have an active Oil Runner route.' }
    end

    if state.hasOil then return { success = false, message = Config.Notifications.alreadyOil } end
    if state.loading then return { success = false, message = 'Oil is already being loaded.' } end
    if not isNear(source, Config.Locations.loadOil, 18.0) then return { success = false, message = 'You are not at the oil loading point.' } end
    if not isRegisteredTugDriver(source, state, netId) then return { success = false, message = Config.Notifications.notInTug } end

    state.loading = true
    state.loadingStartedAt = GetGameTimer()
    return { success = true }
end)

lib.callback.register('oilrunner:server:finishLoading', function(source, netId)
    local state = getPlayerState(source)

    if not state.active or not state.loading or state.hasOil then
        return { success = false, message = 'Invalid loading state.' }
    end

    if not isNear(source, Config.Locations.loadOil, 25.0) or not isRegisteredTugDriver(source, state, netId) then
        state.loading = false
        state.loadingStartedAt = nil
        return { success = false, message = Config.Notifications.notInTug }
    end

    if not hasTimerElapsed(state.loadingStartedAt, Config.Job.loadDuration) then
        return { success = false, message = 'Oil loading is not complete yet.' }
    end

    state.loading = false
    state.loadingStartedAt = nil
    state.hasOil = true
    return { success = true, message = Config.Notifications.oilLoaded }
end)

RegisterNetEvent('oilrunner:server:cancelLoading', function()
    local state = getPlayerState(source)
    state.loading = false
    state.loadingStartedAt = nil
end)

lib.callback.register('oilrunner:server:startDelivery', function(source, netId)
    local state = getPlayerState(source)

    if not state.active or not state.tugNetId then
        return { success = false, message = 'You do not have an active Oil Runner route.' }
    end

    if not state.hasOil then return { success = false, message = 'Load oil before attempting delivery.' } end
    if state.delivering then return { success = false, message = 'Oil is already being delivered.' } end
    if not isNear(source, Config.Locations.deliverOil, 18.0) then return { success = false, message = 'You are not at the oil delivery point.' } end
    if not isRegisteredTugDriver(source, state, netId) then return { success = false, message = Config.Notifications.notInTug } end

    state.delivering = true
    state.deliveryStartedAt = GetGameTimer()
    return { success = true }
end)

lib.callback.register('oilrunner:server:finishDelivery', function(source, netId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local state = getPlayerState(source)

    if not xPlayer or not state.active or not state.delivering or not state.hasOil then
        return { success = false, message = 'Invalid delivery state.' }
    end

    if not isNear(source, Config.Locations.deliverOil, 25.0) or not isRegisteredTugDriver(source, state, netId) then
        state.delivering = false
        state.deliveryStartedAt = nil
        return { success = false, message = Config.Notifications.notInTug }
    end

    if not hasTimerElapsed(state.deliveryStartedAt, Config.Job.deliverDuration) then
        return { success = false, message = 'Oil delivery is not complete yet.' }
    end

    local reward = math.random(Config.Job.reward.min, Config.Job.reward.max)
    xPlayer.addMoney(reward)

    state.hasOil = false
    state.delivering = false
    state.deliveryStartedAt = nil

    return { success = true, reward = reward, message = Config.Notifications.deliveryPaid:format(reward) }
end)

RegisterNetEvent('oilrunner:server:cancelDelivery', function()
    local state = getPlayerState(source)
    state.delivering = false
    state.deliveryStartedAt = nil
end)

lib.callback.register('oilrunner:server:returnTug', function(source, netId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local state = getPlayerState(source)

    if not xPlayer then return { success = false, message = 'Player not found.' } end
    if not state.active then return { success = false, message = 'You do not have an active Oil Runner job.' } end
    if not state.depositPaid then return { success = false, message = 'No active tug deposit was found.' } end
    if not state.tugNetId or state.tugNetId ~= netId then return { success = false, message = 'This is not your registered tug.' } end
    if not isNear(source, Config.Locations.tugReturn, 15.0) then return { success = false, message = 'You are not at the tug return point.' } end
    if not isRegisteredTugDriver(source, state, netId) then return { success = false, message = Config.Notifications.notInTug } end

    local vehicle = getEntityFromNetId(netId)
    if vehicle == 0 then return { success = false, message = 'Registered tug could not be found.' } end

    DeleteEntity(vehicle)
    xPlayer.addMoney(Config.Job.deposit)

    state.depositPaid = false
    state.tugNetId = nil
    resetRouteState(state)

    return {
        success = true,
        teleport = {
            x = Config.Locations.returnTeleport.x,
            y = Config.Locations.returnTeleport.y,
            z = Config.Locations.returnTeleport.z
        },
        message = Config.Notifications.tugReturned
    }
end)

AddEventHandler('playerDropped', function()
    local src = source
    local state = players[src]

    -- Deposits are intentionally forfeited on disconnect. No automatic refund is issued.
    if state and state.tugNetId then
        local vehicle = getEntityFromNetId(state.tugNetId)
        if vehicle ~= 0 then DeleteEntity(vehicle) end
    end

    players[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Do not refund deposits on restart. Only clean spawned entities where possible.
    for _, state in pairs(players) do
        if state.tugNetId then
            local vehicle = getEntityFromNetId(state.tugNetId)
            if vehicle ~= 0 then DeleteEntity(vehicle) end
        end
    end
end)
