local ESX = exports['es_extended']:getSharedObject()

local PlayerState = {
    jobActive = false,
    hasOil = false,
    tugNetId = nil,
    tugPlate = nil,
    busy = false,
    savedSkin = nil
}

local function notify(message, notifyType)
    lib.notify({
        title = 'Oil Runner',
        description = message,
        type = notifyType or 'inform',
        position = 'top'
    })
end

local function setWaypoint(coords)
    SetNewWaypoint(coords.x, coords.y)
end

local function drawConfiguredMarker(coords, markerConfig)
    local marker = Config.Marker
    local color = markerConfig and markerConfig.color or marker.color
    local scale = markerConfig and markerConfig.scale or marker.scale
    local markerType = markerConfig and markerConfig.type or marker.type

    DrawMarker(
        markerType,
        coords.x, coords.y, coords.z - 0.95,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scale.x, scale.y, scale.z,
        color.r, color.g, color.b, color.a,
        marker.bobUpAndDown,
        marker.faceCamera,
        2,
        marker.rotate,
        nil,
        nil,
        false
    )
end

local function createStartBlip()
    local blip = AddBlipForCoord(Config.Start.x, Config.Start.y, Config.Start.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
end

local function applyWorkClothes()
    TriggerEvent('skinchanger:getSkin', function(skin)
        PlayerState.savedSkin = skin
        local sex = skin.sex == 0 and 'male' or 'female'
        TriggerEvent('skinchanger:loadClothes', skin, Config.WorkClothes[sex])
    end)
end

local function restoreClothes()
    if PlayerState.savedSkin then
        TriggerEvent('skinchanger:loadSkin', PlayerState.savedSkin)
        PlayerState.savedSkin = nil
    end
end

local function getCurrentVehicleNetId()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        return nil, nil
    end

    return NetworkGetNetworkIdFromEntity(vehicle), vehicle
end

local function isInsideRegisteredTug()
    local netId, vehicle = getCurrentVehicleNetId()

    if not netId or not PlayerState.tugNetId or vehicle == 0 then
        return false, netId, vehicle
    end

    -- Client-side check only confirms the player is in a Tug and has a registered job Tug.
    -- Exact ownership is validated server-side by net id + generated plate.
    return GetEntityModel(vehicle) == Config.TugModel, netId, vehicle
end

local function cleanupLocalTug()
    if not PlayerState.tugNetId then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(PlayerState.tugNetId)
    if entity ~= 0 and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteVehicle(entity)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    PlayerState.tugNetId = nil
    PlayerState.tugPlate = nil
end

local function spawnTug()
    if PlayerState.busy then
        return
    end

    PlayerState.busy = true
    local response = lib.callback.await('oilrunner:server:requestTugSpawn', false)
    PlayerState.busy = false

    if not response or not response.success then
        notify(response and response.message or Config.Text.exploitBlocked, 'error')
        return
    end

    local netId = response.netId
    PlayerState.tugNetId = netId
    PlayerState.tugPlate = response.plate
    PlayerState.hasOil = false

    local vehicle = 0
    local timeout = GetGameTimer() + 10000

    while GetGameTimer() < timeout do
        vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            break
        end
        Wait(50)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify('Tug ثبت شد اما در کلاینت شما قابل دسترسی نشد. دوباره وارد محدوده شوید.', 'error')
        return
    end

    local ped = PlayerPedId()
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleFuelLevel(vehicle, 100.0)
    SetVehicleEngineOn(vehicle, true, true, false)
    TaskWarpPedIntoVehicle(ped, vehicle, -1)

    setWaypoint(Config.LoadOil)
    notify(Config.Text.tugSpawned, 'success')
end

local function openSpawnMenu()
    lib.registerContext({
        id = 'oilrunner_spawn_menu',
        title = 'Oil Runner',
        options = {
            {
                title = 'Spawn Tug',
                description = ('ودیعه قابل بازگشت: $%s'):format(Config.Deposit),
                icon = 'ship',
                onSelect = spawnTug
            }
        }
    })

    lib.showContext('oilrunner_spawn_menu')
end

local function toggleJob()
    if PlayerState.busy then
        return
    end

    PlayerState.busy = true
    local response = lib.callback.await('oilrunner:server:toggleJob', false)
    PlayerState.busy = false

    if not response or not response.success then
        notify(response and response.message or Config.Text.exploitBlocked, 'error')
        return
    end

    PlayerState.jobActive = response.active
    PlayerState.hasOil = response.hasOil or false
    PlayerState.tugNetId = response.tugNetId
    PlayerState.tugPlate = response.tugPlate

    if response.active then
        applyWorkClothes()
        notify(Config.Text.jobStarted, 'success')
    else
        restoreClothes()
        cleanupLocalTug()
        notify(Config.Text.jobEnded, 'success')
    end
end

local function startLoadingOil()
    if PlayerState.busy then
        return
    end

    local inTug, netId = isInsideRegisteredTug()
    if not inTug then
        notify(Config.Text.notInRegisteredTug, 'error')
        return
    end

    PlayerState.busy = true
    local allowed = lib.callback.await('oilrunner:server:beginLoadOil', false, netId)
    if not allowed or not allowed.success then
        PlayerState.busy = false
        notify(allowed and allowed.message or Config.Text.exploitBlocked, 'error')
        return
    end

    local completed = lib.progressBar({
        duration = Config.LoadDuration,
        label = Config.Text.loading,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = false,
            car = true,
            combat = true
        }
    })

    local result = lib.callback.await('oilrunner:server:finishLoadOil', false, netId, completed == true)
    PlayerState.busy = false

    if not completed then
        notify(Config.Text.cancelled, 'error')
        return
    end

    if result and result.success then
        PlayerState.hasOil = true
        setWaypoint(Config.DeliverOil)
        notify(Config.Text.loadComplete, 'success')
    else
        notify(result and result.message or Config.Text.exploitBlocked, 'error')
    end
end

local function startDeliverOil()
    if PlayerState.busy then
        return
    end

    local inTug, netId = isInsideRegisteredTug()
    if not inTug then
        notify(Config.Text.notInRegisteredTug, 'error')
        return
    end

    PlayerState.busy = true
    local allowed = lib.callback.await('oilrunner:server:beginDeliverOil', false, netId)
    if not allowed or not allowed.success then
        PlayerState.busy = false
        notify(allowed and allowed.message or Config.Text.exploitBlocked, 'error')
        return
    end

    local completed = lib.progressBar({
        duration = Config.DeliverDuration,
        label = Config.Text.delivering,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = false,
            car = true,
            combat = true
        }
    })

    local result = lib.callback.await('oilrunner:server:finishDeliverOil', false, netId, completed == true)
    PlayerState.busy = false

    if not completed then
        notify(Config.Text.cancelled, 'error')
        return
    end

    if result and result.success then
        PlayerState.hasOil = false
        setWaypoint(Config.LoadOil)
        notify((Config.Text.deliverComplete):format(result.reward), 'success')
    else
        notify(result and result.message or Config.Text.exploitBlocked, 'error')
    end
end

local function returnTug()
    if PlayerState.busy then
        return
    end

    local inTug, netId = isInsideRegisteredTug()
    if not inTug then
        notify(Config.Text.notInRegisteredTug, 'error')
        return
    end

    PlayerState.busy = true
    local result = lib.callback.await('oilrunner:server:returnTug', false, netId)
    PlayerState.busy = false

    if not result or not result.success then
        notify(result and result.message or Config.Text.exploitBlocked, 'error')
        return
    end

    cleanupLocalTug()
    PlayerState.tugNetId = nil
    PlayerState.tugPlate = nil
    PlayerState.hasOil = false
    SetEntityCoords(PlayerPedId(), Config.AfterReturnTeleport.x, Config.AfterReturnTeleport.y, Config.AfterReturnTeleport.z, false, false, false, false)
    notify(Config.Text.returnComplete, 'success')
end

local function handlePoint(coords, markerConfig, helpText, action, shouldShow)
    if shouldShow and not shouldShow() then
        return false, false
    end

    local ped = PlayerPedId()
    local distance = #(GetEntityCoords(ped) - coords)

    if distance <= Config.DrawDistance then
        drawConfiguredMarker(coords, markerConfig)

        local interactDistance = markerConfig and markerConfig.interactDistance or Config.InteractDistance
        if distance <= interactDistance then
            lib.showTextUI(helpText)
            if IsControlJustReleased(0, 38) then
                action()
            end
            return true, true
        end

        return true, false
    end

    return false, false
end

CreateThread(function()
    createStartBlip()

    while true do
        local wait = 1000
        local showingTextUi = false

        local drew, showed = handlePoint(Config.Start, Config.Markers.start, Config.Text.startHelp, toggleJob)
        if drew then
            wait = 0
        end
        showingTextUi = showingTextUi or showed

        if PlayerState.jobActive then
            drew, showed = handlePoint(Config.SpawnMenu, Config.Markers.spawn, Config.Text.spawnHelp, openSpawnMenu)
            if drew then
                wait = 0
            end
            showingTextUi = showingTextUi or showed

            drew, showed = handlePoint(Config.ReturnTug, Config.Markers.returnTug, Config.Text.returnHelp, returnTug)
            if drew then
                wait = 0
            end
            showingTextUi = showingTextUi or showed

            drew, showed = handlePoint(Config.LoadOil, Config.Markers.load, Config.Text.loadHelp, startLoadingOil)
            if drew then
                wait = 0
            end
            showingTextUi = showingTextUi or showed

            if PlayerState.hasOil then
                drew, showed = handlePoint(Config.DeliverOil, Config.Markers.deliver, Config.Text.deliverHelp, startDeliverOil)
                if drew then
                    wait = 0
                end
                showingTextUi = showingTextUi or showed
            end
        end

        if not showingTextUi then
            lib.hideTextUI()
        end

        Wait(wait)
    end
end)

RegisterNetEvent('oilrunner:client:syncState', function(state)
    PlayerState.jobActive = state.jobActive or false
    PlayerState.hasOil = state.hasOil or false
    PlayerState.tugNetId = state.tugNetId
    PlayerState.tugPlate = state.tugPlate
end)

RegisterNetEvent('oilrunner:client:forceCleanup', function()
    cleanupLocalTug()
    PlayerState.jobActive = false
    PlayerState.hasOil = false
    PlayerState.busy = false
    restoreClothes()
end)

RegisterNetEvent('oilrunner:client:deleteTug', function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity ~= 0 and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteVehicle(entity)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
end)
