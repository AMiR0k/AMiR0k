local jobActive = false
local activeTugNetId = nil
local hasOil = false
local busy = false
local previousSkin = nil

local function notify(description, notifyType)
    lib.notify({
        title = Config.Job.name,
        description = description,
        type = notifyType or 'inform'
    })
end

local function createJobBlip()
    local blip = AddBlipForCoord(Config.Locations.jobStart.x, Config.Locations.jobStart.y, Config.Locations.jobStart.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.colour)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
end

local function drawMarker(coords)
    DrawMarker(
        Config.Marker.type,
        coords.x, coords.y, coords.z - 1.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        Config.Marker.scale.x, Config.Marker.scale.y, Config.Marker.scale.z,
        Config.Marker.colour.r, Config.Marker.colour.g, Config.Marker.colour.b, Config.Marker.colour.a,
        false, true, 2, false, nil, nil, false
    )
end

local function showHelp(text)
    lib.showTextUI(text, { icon = 'keyboard' })
end

local function hideHelp()
    lib.hideTextUI()
end

local function setWaypoint(coords)
    SetNewWaypoint(coords.x, coords.y)
end

local function getCurrentVehicleNetId()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil, vehicle
    end

    return NetworkGetNetworkIdFromEntity(vehicle), vehicle
end

local function isInRegisteredTug()
    local netId, vehicle = getCurrentVehicleNetId()
    return netId and activeTugNetId and netId == activeTugNetId, netId, vehicle
end

local function applyWorkOutfit()
    TriggerEvent('skinchanger:getSkin', function(skin)
        previousSkin = skin
        local outfit = skin.sex == 0 and Config.WorkOutfit.male or Config.WorkOutfit.female
        TriggerEvent('skinchanger:loadClothes', skin, outfit)
    end)
end

local function restorePreviousOutfit()
    if not previousSkin then return end

    TriggerEvent('skinchanger:loadSkin', previousSkin)
    previousSkin = nil
end

local function waitForNetworkVehicle(netId)
    local timeout = GetGameTimer() + 7000

    while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not NetworkDoesEntityExistWithNetworkId(netId) then return 0 end
    return NetToVeh(netId)
end

local function setVehicleFuel(vehicle)
    if vehicle == 0 then return end

    SetVehicleFuelLevel(vehicle, Config.Vehicle.fuel)
    Entity(vehicle).state:set('fuel', Config.Vehicle.fuel, true)

    -- Optional compatibility with common fuel resources; guarded so missing exports do not error.
    pcall(function() exports['LegacyFuel']:SetFuel(vehicle, Config.Vehicle.fuel) end)
    pcall(function() exports['cdn-fuel']:SetFuel(vehicle, Config.Vehicle.fuel) end)
    pcall(function() exports['ox_fuel']:setFuel(vehicle, Config.Vehicle.fuel) end)
end

local function spawnTug()
    if busy then return end

    if IsAnyVehicleNearPoint(
        Config.Locations.tugSpawn.x,
        Config.Locations.tugSpawn.y,
        Config.Locations.tugSpawn.z,
        Config.Vehicle.spawnCheckRadius
    ) then
        notify(Config.Notifications.spawnBlocked, 'error')
        return
    end

    busy = true
    local result = lib.callback.await('oilrunner:server:spawnTug', false)
    busy = false

    if not result or not result.success then
        notify(result and result.message or 'Unable to spawn tug.', 'error')
        return
    end

    activeTugNetId = result.netId
    hasOil = false

    local vehicle = waitForNetworkVehicle(activeTugNetId)
    if vehicle ~= 0 then
        SetEntityAsMissionEntity(vehicle, true, true)
        setVehicleFuel(vehicle)
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    end

    setWaypoint(Config.Locations.loadOil)
    notify(result.message or Config.Notifications.tugSpawned, 'success')
end

local function openTugMenu()
    lib.registerContext({
        id = 'oilrunner_tug_menu',
        title = 'Oil Runner Tug Station',
        options = {
            {
                title = 'Spawn Tug',
                description = ('Pay a refundable $%s deposit and spawn your tug.'):format(Config.Job.deposit),
                icon = 'ship',
                onSelect = spawnTug
            }
        }
    })

    lib.showContext('oilrunner_tug_menu')
end

local function toggleJob()
    if busy then return end

    busy = true
    local result = lib.callback.await('oilrunner:server:toggleJob', false)
    busy = false

    if not result or not result.success then
        notify(result and result.message or 'Unable to toggle job.', 'error')
        return
    end

    jobActive = result.active

    if jobActive then
        applyWorkOutfit()
        setWaypoint(Config.Locations.tugMenu)
        notify(result.message or Config.Notifications.started, 'success')
    else
        activeTugNetId = nil
        hasOil = false
        restorePreviousOutfit()
        notify(result.message or Config.Notifications.stopped, 'success')
    end
end

local function returnTug()
    if busy then return end

    local valid, netId = isInRegisteredTug()
    if not valid then
        notify(Config.Notifications.notInTug, 'error')
        return
    end

    busy = true
    local result = lib.callback.await('oilrunner:server:returnTug', false, netId)
    busy = false

    if not result or not result.success then
        notify(result and result.message or 'Unable to return tug.', 'error')
        return
    end

    activeTugNetId = nil
    hasOil = false

    if result.teleport then
        local ped = PlayerPedId()
        SetEntityCoords(ped, result.teleport.x, result.teleport.y, result.teleport.z, false, false, false, true)
    end

    notify(result.message or Config.Notifications.tugReturned, 'success')
end

local function loadOil()
    if busy then return end

    local valid, netId = isInRegisteredTug()
    if not valid then
        notify(Config.Notifications.notInTug, 'error')
        return
    end

    busy = true
    local started = lib.callback.await('oilrunner:server:startLoading', false, netId)
    if not started or not started.success then
        busy = false
        notify(started and started.message or 'Unable to start loading.', 'error')
        return
    end

    notify(Config.Notifications.loadingStarted, 'inform')
    local completed = lib.progressBar({
        duration = Config.Job.loadDuration,
        label = 'Loading oil...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = true, combat = true }
    })

    if not completed then
        TriggerServerEvent('oilrunner:server:cancelLoading')
        busy = false
        notify(Config.Notifications.actionCancelled, 'error')
        return
    end

    local result = lib.callback.await('oilrunner:server:finishLoading', false, netId)
    busy = false

    if not result or not result.success then
        notify(result and result.message or 'Unable to finish loading.', 'error')
        return
    end

    hasOil = true
    setWaypoint(Config.Locations.deliverOil)
    notify(result.message or Config.Notifications.oilLoaded, 'success')
end

local function deliverOil()
    if busy then return end

    local valid, netId = isInRegisteredTug()
    if not valid then
        notify(Config.Notifications.notInTug, 'error')
        return
    end

    busy = true
    local started = lib.callback.await('oilrunner:server:startDelivery', false, netId)
    if not started or not started.success then
        busy = false
        notify(started and started.message or 'Unable to start delivery.', 'error')
        return
    end

    notify(Config.Notifications.deliveryStarted, 'inform')
    local completed = lib.progressBar({
        duration = Config.Job.deliverDuration,
        label = 'Delivering oil...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = true, combat = true }
    })

    if not completed then
        TriggerServerEvent('oilrunner:server:cancelDelivery')
        busy = false
        notify(Config.Notifications.actionCancelled, 'error')
        return
    end

    local result = lib.callback.await('oilrunner:server:finishDelivery', false, netId)
    busy = false

    if not result or not result.success then
        notify(result and result.message or 'Unable to finish delivery.', 'error')
        return
    end

    hasOil = false
    setWaypoint(Config.Locations.loadOil)
    notify(result.message or Config.Notifications.deliveryPaid:format(result.reward or 0), 'success')
end

local function handleMarker(coords, prompt, action)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - coords)

    if distance <= Config.Marker.drawDistance then
        drawMarker(coords)

        if distance <= Config.Marker.interactDistance then
            showHelp(prompt)
            if IsControlJustReleased(0, 38) then action() end
            return true
        end
    end

    return false
end

CreateThread(function()
    createJobBlip()

    while true do
        local sleep = 1000
        local showingText = false

        if handleMarker(Config.Locations.jobStart, jobActive and '[E] Stop Oil Runner' or '[E] Start Oil Runner', toggleJob) then
            sleep = 0
            showingText = true
        end

        if jobActive then
            if handleMarker(Config.Locations.tugMenu, '[E] Open Tug Menu', openTugMenu) then
                sleep = 0
                showingText = true
            end

            if activeTugNetId and handleMarker(Config.Locations.tugReturn, '[E] Return Tug', returnTug) then
                sleep = 0
                showingText = true
            end

            if activeTugNetId and not hasOil and handleMarker(Config.Locations.loadOil, '[E] Load Oil', loadOil) then
                sleep = 0
                showingText = true
            end

            if activeTugNetId and hasOil and handleMarker(Config.Locations.deliverOil, '[E] Deliver Oil', deliverOil) then
                sleep = 0
                showingText = true
            end
        end

        if not showingText then hideHelp() end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    hideHelp()
    restorePreviousOutfit()
end)
