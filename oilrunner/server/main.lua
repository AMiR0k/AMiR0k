local ESX = exports['es_extended']:getSharedObject()

local Players = {}

local function getState(source)
    if not Players[source] then
        Players[source] = {
            jobActive = false,
            hasOil = false,
            tugNetId = nil,
            tugPlate = nil,
            identifier = nil,
            depositPaid = false,
            loading = false,
            delivering = false
        }
    end

    return Players[source]
end

local function resetState(source)
    Players[source] = nil
end

local function response(success, message, extra)
    local data = extra or {}
    data.success = success
    data.message = message
    return data
end

local function syncState(source)
    local state = getState(source)
    TriggerClientEvent('oilrunner:client:syncState', source, {
        jobActive = state.jobActive,
        hasOil = state.hasOil,
        tugNetId = state.tugNetId,
        tugPlate = state.tugPlate
    })
end

local function getPed(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return nil
    end

    return ped
end

local function distanceTo(source, coords)
    local ped = getPed(source)
    if not ped then
        return math.huge
    end

    return #(GetEntityCoords(ped) - coords)
end

local function generateTugPlate(source)
    return ('OIL%04d'):format((source * 97 + math.random(0, 9999)) % 10000)
end

local function dbExecute(query, params)
    if GetResourceState('oxmysql') ~= 'started' then
        return
    end

    pcall(function()
        exports.oxmysql:execute(query, params or {})
    end)
end

local function registerTugInDatabase(state, source)
    if not state.identifier or not state.tugPlate or not state.tugNetId then
        return
    end

    dbExecute([[
        INSERT INTO oilrunner_active_tugs (identifier, source, plate, net_id, deposit_paid, has_oil)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            source = VALUES(source),
            plate = VALUES(plate),
            net_id = VALUES(net_id),
            deposit_paid = VALUES(deposit_paid),
            has_oil = VALUES(has_oil),
            updated_at = CURRENT_TIMESTAMP
    ]], { state.identifier, source, state.tugPlate, state.tugNetId, state.depositPaid and 1 or 0, state.hasOil and 1 or 0 })
end

local function updateTugOilInDatabase(state)
    if not state.identifier then
        return
    end

    dbExecute('UPDATE oilrunner_active_tugs SET has_oil = ?, updated_at = CURRENT_TIMESTAMP WHERE identifier = ?', {
        state.hasOil and 1 or 0,
        state.identifier
    })
end

local function removeTugFromDatabase(state)
    if not state.identifier then
        return
    end

    dbExecute('DELETE FROM oilrunner_active_tugs WHERE identifier = ?', { state.identifier })
end

local function isPlayerInTug(source)
    local ped = getPed(source)
    if not ped then
        return false
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    return vehicle ~= 0 and GetEntityModel(vehicle) == Config.TugModel
end

local function deleteTugEntity(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    -- Client fallback covers streaming edge-cases on older artifacts.
    TriggerClientEvent('oilrunner:client:deleteTug', -1, netId)
end

local function clearRouteState(state)
    state.hasOil = false
    state.loading = false
    state.delivering = false
end

lib.callback.register('oilrunner:server:toggleJob', function(source)
    local state = getState(source)

    if state.jobActive then
        if state.tugNetId or state.depositPaid then
            return response(false, Config.Text.mustReturnTug)
        end

        state.jobActive = false
        clearRouteState(state)
        syncState(source)
        return response(true, nil, { active = false, hasOil = false })
    end

    state.jobActive = true
    clearRouteState(state)
    syncState(source)
    return response(true, nil, { active = true, hasOil = false, tugNetId = state.tugNetId, tugPlate = state.tugPlate })
end)

lib.callback.register('oilrunner:server:requestTugSpawn', function(source)
    local state = getState(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return response(false, Config.Text.exploitBlocked)
    end

    if not state.jobActive then
        return response(false, Config.Text.exploitBlocked)
    end

    if state.tugNetId or state.depositPaid then
        return response(false, Config.Text.alreadyHasTug)
    end

    if distanceTo(source, Config.SpawnMenu) > Config.ValidationDistance then
        return response(false, Config.Text.exploitBlocked)
    end

    if xPlayer.getMoney() < Config.Deposit then
        return response(false, Config.Text.noMoney)
    end

    -- Deposit and vehicle creation are both server-side to prevent duplication/refund exploits.
    xPlayer.removeMoney(Config.Deposit)
    state.depositPaid = true
    state.hasOil = false
    state.identifier = xPlayer.identifier

    local spawn = Config.TugSpawn
    local vehicle = CreateVehicle(Config.TugModel, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        xPlayer.addMoney(Config.Deposit)
        state.depositPaid = false
        state.identifier = nil
        return response(false, 'اسپاون Tug ناموفق بود. ودیعه شما برگشت داده شد.')
    end

    local plate = generateTugPlate(source)
    SetVehicleNumberPlateText(vehicle, plate)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        DeleteEntity(vehicle)
        xPlayer.addMoney(Config.Deposit)
        state.depositPaid = false
        state.identifier = nil
        return response(false, 'ثبت Network ID خودرو ناموفق بود. ودیعه شما برگشت داده شد.')
    end

    SetEntityRoutingBucket(vehicle, GetPlayerRoutingBucket(source))
    state.tugNetId = netId
    state.tugPlate = plate
    registerTugInDatabase(state, source)
    syncState(source)

    return response(true, nil, { netId = netId, plate = plate })
end)

lib.callback.register('oilrunner:server:beginLoadOil', function(source, netId)
    local state = getState(source)

    if not state.jobActive or not state.tugNetId or not state.depositPaid then
        return response(false, Config.Text.exploitBlocked)
    end

    if state.hasOil then
        return response(false, 'شما از قبل نفت بارگیری‌شده دارید.')
    end

    if state.loading or state.delivering then
        return response(false, 'یک عملیات دیگر در حال انجام است.')
    end

    if distanceTo(source, Config.LoadOil) > Config.ValidationDistance then
        return response(false, Config.Text.exploitBlocked)
    end

    if not isPlayerInTug(source) then
        return response(false, Config.Text.notInTug)
    end

    state.loading = true
    return response(true)
end)

lib.callback.register('oilrunner:server:finishLoadOil', function(source, netId, completed)
    local state = getState(source)

    if not state.loading then
        return response(false, Config.Text.exploitBlocked)
    end

    state.loading = false

    if completed ~= true then
        return response(true)
    end

    if not state.jobActive or not state.tugNetId or not state.depositPaid then
        return response(false, Config.Text.exploitBlocked)
    end

    if distanceTo(source, Config.LoadOil) > Config.ValidationDistance then
        return response(false, Config.Text.exploitBlocked)
    end

    if not isPlayerInTug(source) then
        return response(false, Config.Text.notInTug)
    end

    state.hasOil = true
    updateTugOilInDatabase(state)
    syncState(source)
    return response(true)
end)

lib.callback.register('oilrunner:server:beginDeliverOil', function(source, netId)
    local state = getState(source)

    if not state.jobActive or not state.tugNetId or not state.depositPaid or not state.hasOil then
        return response(false, Config.Text.exploitBlocked)
    end

    if state.loading or state.delivering then
        return response(false, 'یک عملیات دیگر در حال انجام است.')
    end

    if distanceTo(source, Config.DeliverOil) > Config.ValidationDistance then
        return response(false, Config.Text.exploitBlocked)
    end

    if not isPlayerInTug(source) then
        return response(false, Config.Text.notInTug)
    end

    state.delivering = true
    return response(true)
end)

lib.callback.register('oilrunner:server:finishDeliverOil', function(source, netId, completed)
    local state = getState(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not state.delivering then
        return response(false, Config.Text.exploitBlocked)
    end

    state.delivering = false

    if completed ~= true then
        return response(true)
    end

    if not xPlayer or not state.jobActive or not state.tugNetId or not state.depositPaid or not state.hasOil then
        return response(false, Config.Text.exploitBlocked)
    end

    if distanceTo(source, Config.DeliverOil) > Config.ValidationDistance then
        return response(false, Config.Text.exploitBlocked)
    end

    if not isPlayerInTug(source) then
        return response(false, Config.Text.notInTug)
    end

    local reward = math.random(Config.Reward.min, Config.Reward.max)
    xPlayer.addMoney(reward)
    state.hasOil = false
    updateTugOilInDatabase(state)
    syncState(source)

    return response(true, nil, { reward = reward })
end)

lib.callback.register('oilrunner:server:returnTug', function(source, netId)
    local state = getState(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not state.jobActive or not state.depositPaid or not state.tugNetId then
        return response(false, Config.Text.exploitBlocked)
    end

    if state.loading or state.delivering then
        return response(false, 'ابتدا عملیات فعلی را تمام یا لغو کنید.')
    end

    if distanceTo(source, Config.ReturnTug) > Config.ValidationDistance then
        return response(false, Config.Text.exploitBlocked)
    end

    if not isPlayerInTug(source) then
        return response(false, Config.Text.notInTug)
    end

    local tugNetId = state.tugNetId

    -- Deposit refund is independent from delivery rewards and can happen only once here.
    xPlayer.addMoney(Config.Deposit)
    removeTugFromDatabase(state)
    state.depositPaid = false
    state.tugNetId = nil
    state.tugPlate = nil
    state.identifier = nil
    clearRouteState(state)
    syncState(source)

    deleteTugEntity(tugNetId)

    return response(true)
end)

AddEventHandler('playerDropped', function()
    local source = source
    local state = Players[source]

    if state and state.tugNetId then
        removeTugFromDatabase(state)
        deleteTugEntity(state.tugNetId)
    end

    -- Deposit is intentionally not refunded on disconnect.
    resetState(source)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for source, state in pairs(Players) do
        if state.tugNetId then
            removeTugFromDatabase(state)
            deleteTugEntity(state.tugNetId)
        end
        TriggerClientEvent('oilrunner:client:forceCleanup', source)
    end

    -- Deposits are intentionally not refunded on resource restart/stop.
    Players = {}
end)
