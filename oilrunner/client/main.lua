local ESX = exports.es_extended:getSharedObject()

local jobActive = false
local hasOil = false
local tugNetId = nil
local routeBlip = nil
local startBlip = nil
local isProgressRunning = false
local activeProgressAction = nil

local function notify(description, notifyType)
    lib.notify({
        title = 'Oil Runner',
        description = description,
        type = notifyType or 'inform'
    })
end

local function drawMarker(markerConfig, coords)
    DrawMarker(
        markerConfig.type,
        coords.x, coords.y, coords.z - 1.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        markerConfig.size.x, markerConfig.size.y, markerConfig.size.z,
        markerConfig.colour.r, markerConfig.colour.g, markerConfig.colour.b, markerConfig.colour.a,
        false, true, 2, false, nil, nil, false
    )
end

local function showText(text)
    lib.showTextUI(text, {
        position = 'left-center',
        icon = 'oil-can'
    })
end

local function hideText()
    lib.hideTextUI()
end

local function createBlip(coords, blipConfig, route)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, blipConfig.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipConfig.scale)
    SetBlipColour(blip, blipConfig.colour)
    SetBlipAsShortRange(blip, not route)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipConfig.label)
    EndTextCommandSetBlipName(blip)

    if route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, blipConfig.colour)
        SetNewWaypoint(coords.x, coords.y)
    end

    return blip
end

local function clearRouteBlip()
    if routeBlip and DoesBlipExist(routeBlip) then
        SetBlipRoute(routeBlip, false)
        RemoveBlip(routeBlip)
    end

    routeBlip = nil
end

local function setRouteToLoad()
    clearRouteBlip()
    routeBlip = createBlip(Config.Locations.loadOil, Config.Blips.loadOil, true)
end

local function setRouteToDelivery()
    clearRouteBlip()
    routeBlip = createBlip(Config.Locations.deliverOil, Config.Blips.deliverOil, true)
end

local function setupStartBlip()
    if startBlip and DoesBlipExist(startBlip) then
        return
    end

    startBlip = createBlip(Config.Locations.startStop, Config.Blips.startStop, false)
end

local function loadCivilianSkin()
    -- لباس شهروندی از skin ذخیره‌شده بازیکن در ESX بازیابی می‌شود، نه از یک لباس پیش‌فرض.
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        if skin then
            TriggerEvent('skinchanger:loadSkin', skin)
        else
            notify('Skin ذخیره‌شده پیدا نشد.', 'error')
        end
    end)
end

local function applyWorkClothes()
    TriggerEvent('skinchanger:getSkin', function(skin)
        local clothes = skin.sex == 0 and Config.WorkClothes.male or Config.WorkClothes.female
        TriggerEvent('skinchanger:loadClothes', skin, clothes)
    end)
end

local function refreshServerState()
    local state = lib.callback.await('oilrunner:server:getState', false)

    if not state then
        return
    end

    jobActive = state.active
    hasOil = state.hasOil
    tugNetId = state.tugNetId

    if jobActive and tugNetId then
        if hasOil then
            setRouteToDelivery()
        else
            setRouteToLoad()
        end
    else
        clearRouteBlip()
    end
end

local function isPlayerInRegisteredTug()
    if not tugNetId then
        return false
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        return false
    end

    if GetEntityModel(vehicle) ~= Config.TugModel then
        return false
    end

    return NetworkGetNetworkIdFromEntity(vehicle) == tugNetId
end

local function setVehicleFuel(vehicle)
    SetVehicleFuelLevel(vehicle, 100.0)

    if GetResourceState('LegacyFuel') == 'started' then
        pcall(function()
            exports.LegacyFuel:SetFuel(vehicle, 100.0)
        end)
    end

    if GetResourceState('ox_fuel') == 'started' then
        Entity(vehicle).state:set('fuel', 100.0, true)
    end
end

local function loadModel(model)
    if not IsModelInCdimage(model) then
        return false
    end

    RequestModel(model)

    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        Wait(50)

        if GetGameTimer() > timeout then
            return false
        end
    end

    return true
end

local function deleteVehicleSafely(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    NetworkRequestControlOfEntity(vehicle)

    local timeout = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do
        Wait(50)
        NetworkRequestControlOfEntity(vehicle)
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)

    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
end

local function spawnTug()
    local canSpawn = lib.callback.await('oilrunner:server:canSpawnTug', false)

    if not canSpawn or not canSpawn.ok then
        notify(canSpawn and canSpawn.message or 'امکان اسپاون Tug وجود ندارد.', 'error')
        return
    end

    local model = Config.TugModel

    if not loadModel(model) then
        notify('مدل Tug بارگذاری نشد.', 'error')
        return
    end

    local spawn = Config.Locations.tugSpawn
    local vehicle = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, true)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(model)
        notify('ساخت Tug ناموفق بود.', 'error')
        return
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    setVehicleFuel(vehicle)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)

    tugNetId = netId
    hasOil = false
    SetEntityCoords(PlayerPedId(), Config.Locations.afterTugSpawn.x, Config.Locations.afterTugSpawn.y, Config.Locations.afterTugSpawn.z, false, false, false, true)
    setRouteToLoad()

    TriggerServerEvent('oilrunner:server:registerTug', netId)
    SetModelAsNoLongerNeeded(model)
end

local function openTugMenu()
    lib.registerContext({
        id = 'oilrunner_tug_menu',
        title = 'Oil Runner',
        options = {
            {
                title = 'Spawn Tug',
                description = 'دریافت یدک‌کش مخصوص شغل Oil Runner',
                icon = 'ship',
                onSelect = spawnTug
            }
        }
    })

    lib.showContext('oilrunner_tug_menu')
end

local function toggleJob()
    local result = lib.callback.await('oilrunner:server:toggleJob', false)

    if not result or not result.ok then
        notify(result and result.message or 'تغییر وضعیت شغل ناموفق بود.', 'error')
        return
    end

    jobActive = result.active
    hasOil = false
    tugNetId = nil
    clearRouteBlip()

    if jobActive then
        applyWorkClothes()
        notify(result.message, 'success')
    else
        loadCivilianSkin()
        notify(result.message, 'success')
    end
end

local function returnTug()
    if not isPlayerInRegisteredTug() then
        notify('برای حذف، باید داخل Tug ثبت‌شده خود باشید.', 'error')
        return
    end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local result = lib.callback.await('oilrunner:server:returnTug', false, netId)

    if not result or not result.ok then
        notify(result and result.message or 'حذف Tug ناموفق بود.', 'error')
        return
    end

    deleteVehicleSafely(vehicle)

    tugNetId = nil
    hasOil = false
    clearRouteBlip()
    notify(result.message, 'inform')
    SetEntityCoords(PlayerPedId(), Config.Locations.afterTugReturn.x, Config.Locations.afterTugReturn.y, Config.Locations.afterTugReturn.z, false, false, false, true)
end

local function monitorProgress(action, origin)
    CreateThread(function()
        while isProgressRunning and activeProgressAction == action do
            Wait(500)

            local ped = PlayerPedId()
            local shouldCancel = false

            if IsEntityDead(ped) then
                shouldCancel = true
            elseif #(GetEntityCoords(ped) - origin) > Config.MaxActionDistance then
                shouldCancel = true
            elseif not isPlayerInRegisteredTug() then
                shouldCancel = true
            end

            if shouldCancel then
                lib.cancelProgress()
                break
            end
        end
    end)
end

local function runOilProgress(action, label, duration, origin, serverStartCallback, serverFinishEvent)
    if isProgressRunning then
        notify('یک عملیات دیگر در حال انجام است.', 'error')
        return
    end

    if not isPlayerInRegisteredTug() then
        notify('برای انجام این عملیات باید داخل Tug ثبت‌شده خود باشید.', 'error')
        return
    end

    local startResult = lib.callback.await(serverStartCallback, false)

    if not startResult or not startResult.ok then
        notify(startResult and startResult.message or 'شرایط عملیات معتبر نیست.', 'error')
        return
    end

    isProgressRunning = true
    activeProgressAction = action
    monitorProgress(action, origin)

    local completed = lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = false,
            car = false,
            combat = true,
            mouse = false
        }
    })

    isProgressRunning = false
    activeProgressAction = nil

    if completed then
        TriggerServerEvent(serverFinishEvent)
    else
        TriggerServerEvent('oilrunner:server:cancelProgress', action)
    end
end

local function startLoading()
    runOilProgress(
        'loading',
        'در حال بارگیری نفت...',
        Config.LoadDuration,
        Config.Locations.loadOil,
        'oilrunner:server:startLoading',
        'oilrunner:server:finishLoading'
    )
end

local function startDelivery()
    runOilProgress(
        'delivering',
        'در حال تحویل نفت...',
        Config.DeliverDuration,
        Config.Locations.deliverOil,
        'oilrunner:server:startDelivery',
        'oilrunner:server:finishDelivery'
    )
end

local function handleInteraction(point)
    if point == 'startStop' then
        toggleJob()
    elseif point == 'tugMenu' then
        openTugMenu()
    elseif point == 'tugReturn' then
        returnTug()
    elseif point == 'loadOil' then
        startLoading()
    elseif point == 'deliverOil' then
        startDelivery()
    end
end

CreateThread(function()
    setupStartBlip()
    refreshServerState()

    local visibleText

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local nearestText
        local nearestPoint

        local function processPoint(pointName, coords, markerConfig, text, enabled)
            if not enabled then
                return
            end

            local distance = #(playerCoords - coords)

            if distance <= markerConfig.drawDistance then
                sleep = 0
                drawMarker(markerConfig, coords)

                if distance <= markerConfig.interactDistance then
                    nearestText = text
                    nearestPoint = pointName
                end
            elseif distance <= markerConfig.drawDistance + 80.0 then
                sleep = math.min(sleep, 250)
            end
        end

        processPoint('startStop', Config.Locations.startStop, Config.Markers.startStop, Config.Text.pressStartStop, true)
        processPoint('tugMenu', Config.Locations.tugMenu, Config.Markers.tugMenu, Config.Text.pressTugMenu, jobActive)
        processPoint('tugReturn', Config.Locations.tugReturn, Config.Markers.tugReturn, Config.Text.pressReturnTug, jobActive and tugNetId ~= nil)
        processPoint('loadOil', Config.Locations.loadOil, Config.Markers.loadOil, Config.Text.pressLoadOil, jobActive and tugNetId ~= nil and not hasOil)
        processPoint('deliverOil', Config.Locations.deliverOil, Config.Markers.deliverOil, Config.Text.pressDeliverOil, jobActive and hasOil)

        if nearestText and not isProgressRunning then
            if visibleText ~= nearestText then
                showText(nearestText)
                visibleText = nearestText
            end

            if IsControlJustReleased(0, 38) then
                handleInteraction(nearestPoint)
            end
        elseif visibleText then
            hideText()
            visibleText = nil
        end

        Wait(sleep)
    end
end)

RegisterNetEvent('oilrunner:client:deleteTug', function(netId)
    if netId and tugNetId and netId ~= tugNetId then
        return
    end

    local vehicle = 0
    local vehicleNetId = netId or tugNetId

    if vehicleNetId then
        vehicle = NetToVeh(vehicleNetId)
    end

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        deleteVehicleSafely(vehicle)
    end

    tugNetId = nil
    hasOil = false
    clearRouteBlip()
end)

RegisterNetEvent('oilrunner:client:setHasOil', function(value)
    hasOil = value == true

    if hasOil then
        setRouteToDelivery()
    elseif jobActive and tugNetId then
        setRouteToLoad()
    else
        clearRouteBlip()
    end
end)

RegisterNetEvent('esx:setJob', function(job)
    if not job or job.name ~= Config.JobName then
        jobActive = false
        hasOil = false
        tugNetId = nil
        clearRouteBlip()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if isProgressRunning then
        lib.cancelProgress()
        TriggerServerEvent('oilrunner:server:cancelProgress', activeProgressAction)
    end

    clearRouteBlip()
    hideText()
end)
