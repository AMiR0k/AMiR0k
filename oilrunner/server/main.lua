local ESX = exports.es_extended:getSharedObject()

-- state[source] = {
--     active = boolean,
--     previousJob = { name = string, grade = number },
--     hasOil = boolean,
--     tugNetId = number,
--     busy = false | 'loading' | 'delivering'
-- }
local playerStates = {}

local function notify(source, description, notifyType)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Oil Runner',
        description = description,
        type = notifyType or 'inform'
    })
end

local function getState(source)
    playerStates[source] = playerStates[source] or {
        active = false,
        hasOil = false,
        tugNetId = nil,
        busy = false,
        previousJob = nil
    }

    return playerStates[source]
end

local function distanceFromPlayer(source, coords)
    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then
        return math.huge
    end

    return #(GetEntityCoords(ped) - coords)
end

local function isNear(source, coords, maxDistance)
    return distanceFromPlayer(source, coords) <= (maxDistance or Config.MaxActionDistance)
end

local function getPlayerTugVehicle(source)
    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then
        return 0
    end

    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or vehicle == 0 then
        return 0
    end

    if GetEntityModel(vehicle) ~= Config.TugModel then
        return 0
    end

    return vehicle
end

local function isInRegisteredTug(source, state)
    local vehicle = getPlayerTugVehicle(source)

    if vehicle == 0 then
        return false
    end

    if not state.tugNetId then
        return false
    end

    return NetworkGetNetworkIdFromEntity(vehicle) == state.tugNetId
end

local function restorePreviousJob(source, xPlayer, state)
    local previousJob = state.previousJob or {
        name = Config.FallbackJob,
        grade = Config.FallbackGrade
    }

    if not previousJob.name or previousJob.name == Config.JobName then
        previousJob.name = Config.FallbackJob
        previousJob.grade = Config.FallbackGrade
    end

    xPlayer.setJob(previousJob.name, previousJob.grade or Config.FallbackGrade)
end

local function resetOilRunnerState(source)
    playerStates[source] = nil
end

lib.callback.register('oilrunner:server:getState', function(source)
    local state = getState(source)

    return {
        active = state.active,
        hasOil = state.hasOil,
        tugNetId = state.tugNetId,
        busy = state.busy ~= false
    }
end)

lib.callback.register('oilrunner:server:toggleJob', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return { ok = false, message = 'بازیکن پیدا نشد.' }
    end

    if not isNear(source, Config.Locations.startStop, Config.MaxActionDistance) then
        return { ok = false, message = 'برای شروع یا پایان شغل باید در محل مشخص شده باشید.' }
    end

    local state = getState(source)

    if state.active then
        if state.tugNetId then
            TriggerClientEvent('oilrunner:client:deleteTug', source, state.tugNetId)
        end

        restorePreviousJob(source, xPlayer, state)
        resetOilRunnerState(source)

        return {
            ok = true,
            active = false,
            message = 'شیفت Oil Runner به پایان رسید و شغل قبلی شما بازیابی شد.'
        }
    end

    local currentJob = xPlayer.getJob()

    state.previousJob = {
        name = currentJob and currentJob.name or Config.FallbackJob,
        grade = currentJob and currentJob.grade or Config.FallbackGrade
    }
    state.active = true
    state.hasOil = false
    state.tugNetId = nil
    state.busy = false

    xPlayer.setJob(Config.JobName, Config.JobGrade)

    return {
        ok = true,
        active = true,
        message = 'شیفت Oil Runner شروع شد. لباس کاری شما اعمال می‌شود.'
    }
end)

lib.callback.register('oilrunner:server:canSpawnTug', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local state = getState(source)

    local job = xPlayer and xPlayer.getJob and xPlayer.getJob()

    if not xPlayer or not state.active or not job or job.name ~= Config.JobName then
        return { ok = false, message = 'شغل Oil Runner برای شما فعال نیست.' }
    end

    if not isNear(source, Config.Locations.tugMenu, Config.MaxActionDistance) then
        return { ok = false, message = 'برای دریافت Tug باید در محل اسپاون باشید.' }
    end

    if state.tugNetId then
        return { ok = false, message = 'شما هم‌اکنون یک Tug فعال دارید.' }
    end

    return { ok = true }
end)

RegisterNetEvent('oilrunner:server:registerTug', function(netId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local state = getState(source)

    if type(netId) ~= 'number' then
        return
    end

    local job = xPlayer and xPlayer.getJob and xPlayer.getJob()

    if not xPlayer or not state.active or not job or job.name ~= Config.JobName then
        return
    end

    if state.tugNetId then
        return
    end

    if not isNear(source, Config.Locations.afterTugSpawn, Config.MaxActionDistance + 15.0) then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)

    if entity == 0 or GetEntityModel(entity) ~= Config.TugModel then
        return
    end

    state.tugNetId = netId
    state.hasOil = false
    state.busy = false

    notify(source, 'Tug با موفقیت تحویل داده شد. GPS روی محل بارگیری تنظیم شد.', 'success')
end)


lib.callback.register('oilrunner:server:returnTug', function(source, netId)
    local state = getState(source)

    if type(netId) ~= 'number' or not state.active or state.tugNetId ~= netId then
        return { ok = false, message = 'Tug ثبت‌شده‌ای برای حذف پیدا نشد.' }
    end

    if not isNear(source, Config.Locations.tugReturn, Config.MaxActionDistance) then
        return { ok = false, message = 'برای حذف Tug باید در محل DV باشید.' }
    end

    if not isInRegisteredTug(source, state) then
        return { ok = false, message = 'برای حذف Tug باید داخل Tug ثبت‌شده خود باشید.' }
    end

    state.tugNetId = nil
    state.hasOil = false
    state.busy = false

    return { ok = true, message = 'Tug حذف شد و مسیر فعلی پاک گردید.' }
end)

RegisterNetEvent('oilrunner:server:clearTug', function(netId)
    local source = source
    local state = getState(source)

    -- این رویداد فقط نقش پاک‌سازی کمکی دارد؛ حذف عادی Tug از callback امن returnTug انجام می‌شود.
    if type(netId) ~= 'number' or not state.active or state.tugNetId ~= netId then
        return
    end

    if not isNear(source, Config.Locations.tugReturn, Config.MaxActionDistance) then
        return
    end

    state.tugNetId = nil
    state.hasOil = false
    state.busy = false
    notify(source, 'Tug حذف شد و مسیر فعلی پاک گردید.', 'inform')
end)

lib.callback.register('oilrunner:server:startLoading', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local state = getState(source)

    local job = xPlayer and xPlayer.getJob and xPlayer.getJob()

    if not xPlayer or not state.active or not job or job.name ~= Config.JobName then
        return { ok = false, message = 'شغل Oil Runner فعال نیست.' }
    end

    if state.busy then
        return { ok = false, message = 'یک عملیات دیگر در حال انجام است.' }
    end

    if state.hasOil then
        return { ok = false, message = 'نفت قبلاً بارگیری شده است. ابتدا آن را تحویل دهید.' }
    end

    if not state.tugNetId or not isInRegisteredTug(source, state) then
        return { ok = false, message = 'برای بارگیری باید داخل Tug ثبت‌شده خود باشید.' }
    end

    if not isNear(source, Config.Locations.loadOil, Config.MaxActionDistance) then
        return { ok = false, message = 'از محل بارگیری بیش از حد دور هستید.' }
    end

    state.busy = 'loading'

    return { ok = true }
end)

RegisterNetEvent('oilrunner:server:finishLoading', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local state = getState(source)

    local job = xPlayer and xPlayer.getJob and xPlayer.getJob()

    if not xPlayer or not state.active or not job or job.name ~= Config.JobName then
        return
    end

    if state.busy ~= 'loading' then
        return
    end

    if state.hasOil or not state.tugNetId or not isInRegisteredTug(source, state) or not isNear(source, Config.Locations.loadOil, Config.MaxActionDistance) then
        state.busy = false
        notify(source, 'بارگیری به دلیل نامعتبر بودن شرایط لغو شد.', 'error')
        return
    end

    state.hasOil = true
    state.busy = false

    TriggerClientEvent('oilrunner:client:setHasOil', source, true)
    notify(source, 'نفت با موفقیت بارگیری شد. GPS روی محل تحویل تنظیم شد.', 'success')
end)

RegisterNetEvent('oilrunner:server:cancelProgress', function(action)
    local source = source
    local state = getState(source)

    if (action == 'loading' and state.busy == 'loading') or (action == 'delivering' and state.busy == 'delivering') then
        state.busy = false
        notify(source, 'عملیات لغو شد.', 'error')
    end
end)

lib.callback.register('oilrunner:server:startDelivery', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local state = getState(source)

    local job = xPlayer and xPlayer.getJob and xPlayer.getJob()

    if not xPlayer or not state.active or not job or job.name ~= Config.JobName then
        return { ok = false, message = 'شغل Oil Runner فعال نیست.' }
    end

    if state.busy then
        return { ok = false, message = 'یک عملیات دیگر در حال انجام است.' }
    end

    if not state.hasOil then
        return { ok = false, message = 'بدون بارگیری نفت امکان دریافت پاداش وجود ندارد.' }
    end

    if not state.tugNetId or not isInRegisteredTug(source, state) then
        return { ok = false, message = 'برای تحویل باید داخل Tug ثبت‌شده خود باشید.' }
    end

    if not isNear(source, Config.Locations.deliverOil, Config.MaxActionDistance) then
        return { ok = false, message = 'از محل تحویل بیش از حد دور هستید.' }
    end

    state.busy = 'delivering'

    return { ok = true }
end)

RegisterNetEvent('oilrunner:server:finishDelivery', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local state = getState(source)

    local job = xPlayer and xPlayer.getJob and xPlayer.getJob()

    if not xPlayer or not state.active or not job or job.name ~= Config.JobName then
        return
    end

    if state.busy ~= 'delivering' then
        return
    end

    if not state.hasOil or not state.tugNetId or not isInRegisteredTug(source, state) or not isNear(source, Config.Locations.deliverOil, Config.MaxActionDistance) then
        state.busy = false
        notify(source, 'تحویل به دلیل نامعتبر بودن شرایط لغو شد.', 'error')
        return
    end

    local reward = math.random(Config.Reward.min, Config.Reward.max)

    xPlayer.addMoney(reward, 'Oil Runner delivery')
    state.hasOil = false
    state.busy = false

    TriggerClientEvent('oilrunner:client:setHasOil', source, false)
    notify(source, ('تحویل موفق بود. پاداش شما: $%s'):format(reward), 'success')
end)

AddEventHandler('playerDropped', function()
    resetOilRunnerState(source)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for source in pairs(playerStates) do
        playerStates[source] = nil
    end
end)
