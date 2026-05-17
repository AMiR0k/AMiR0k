local ESX = exports['es_extended']:getSharedObject()

local playerData = {}
local activeMission = nil
local deliveryPoint = nil
local startPoint = nil
local deliveryBlip = nil
local policeBlip = nil
local startBlip = nil
local textUiVisible = false
local deliveryTextUiVisible = false
local lastPoliceUpdate = 0
local abandonStartedAt = nil
local warnedFinalAbandon = false
local startingMission = false

local function notify(message, notifyType)
    lib.notify({
        title = _L('vehicle_robbery'),
        description = message,
        type = notifyType or 'inform'
    })
end

local function hideStartTextUi()
    if textUiVisible then
        lib.hideTextUI()
        textUiVisible = false
    end
end

local function hideDeliveryTextUi()
    if deliveryTextUiVisible then
        lib.hideTextUI()
        deliveryTextUiVisible = false
    end
end

local function createNamedBlip(coords, data, route)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, data.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, data.scale)
    SetBlipColour(blip, data.color)
    SetBlipAsShortRange(blip, not route)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(_L(data.label))
    EndTextCommandSetBlipName(blip)

    if route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, data.color)
    end

    return blip
end

local function removeBlipSafe(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

local function deleteMissionVehicle()
    if not activeMission or not activeMission.vehicle or not DoesEntityExist(activeMission.vehicle) then
        return
    end

    SetEntityAsMissionEntity(activeMission.vehicle, true, true)
    DeleteVehicle(activeMission.vehicle)
    if DoesEntityExist(activeMission.vehicle) then
        DeleteEntity(activeMission.vehicle)
    end
end

local function resetMission(deleteVehicle)
    hideDeliveryTextUi()

    if deliveryPoint then
        deliveryPoint:remove()
        deliveryPoint = nil
    end

    removeBlipSafe(deliveryBlip)
    deliveryBlip = nil

    if deleteVehicle then
        deleteMissionVehicle()
    end

    activeMission = nil
    abandonStartedAt = nil
    warnedFinalAbandon = false
    lastPoliceUpdate = 0
end

local function isPolice()
    local jobName = playerData.job and playerData.job.name
    return jobName and Config.PoliceJobs[jobName] == true
end

local function drawConfiguredMarker(coords, marker)
    DrawMarker(
        marker.type,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        marker.size.x, marker.size.y, marker.size.z,
        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
        false, true, 2, false, nil, nil, false
    )
end

local function createDeliveryPoint(delivery)
    if deliveryPoint then
        deliveryPoint:remove()
    end

    deliveryPoint = lib.points.new({
        coords = delivery.coords,
        distance = Config.DrawDistance
    })

    function deliveryPoint:nearby()
        if not activeMission then
            return
        end

        drawConfiguredMarker(self.coords, Config.DeliveryMarker)

        if self.currentDistance <= 3.0 then
            if not deliveryTextUiVisible then
                lib.showTextUI(_L('deliver_textui'))
                deliveryTextUiVisible = true
            end

            if IsControlJustReleased(0, 38) then
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)

                if vehicle ~= activeMission.vehicle or GetEntitySpeed(vehicle) >= Config.MinDeliverySpeed then
                    notify(_L('car_provided_rule'), 'error')
                    return
                end

                if not lib.progressBar({
                    duration = 3500,
                    label = _L('delivering'),
                    canCancel = true,
                    disable = { car = true, move = true, combat = true }
                }) then
                    return
                end

                local success, message, payment = lib.callback.await('carthief:finishMission', false, {
                    netId = activeMission.netId,
                    plate = activeMission.plate
                })

                if success then
                    notify(_L('mission_finished', payment or 0), 'success')
                    resetMission(true)
                else
                    notify(message or _L('invalid_mission'), 'error')
                end
            end
        else
            hideDeliveryTextUi()
        end
    end

    function deliveryPoint:onExit()
        hideDeliveryTextUi()
    end
end

local function requestMissionModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return nil
    end

    RequestModel(hash)
    local startedAt = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() - startedAt > Config.SpawnTimeout then
            return nil
        end
    end

    return hash
end

local function spawnMissionVehicle(mission)
    local spawn = Config.VehicleSpawnPoint.coords
    local hash = requestMissionModel(mission.model)
    if not hash then
        return nil
    end

    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    SetModelAsNoLongerNeeded(hash)

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleEngineOn(vehicle, true, true, false)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)

    return vehicle, netId, ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
end

local function abortMission(reason, silent)
    if not activeMission then
        return
    end

    lib.callback.await('carthief:abortMission', false, {
        netId = activeMission.netId,
        plate = activeMission.plate,
        reason = reason or 'client_abort'
    })

    if not silent then
        notify(_L('mission_failed'), 'error')
    end

    resetMission(true)
end

local function startMission()
    if startingMission or activeMission then
        return
    end

    startingMission = true

    if not ESX.Game.IsSpawnPointClear(vec3(Config.VehicleSpawnPoint.coords.x, Config.VehicleSpawnPoint.coords.y, Config.VehicleSpawnPoint.coords.z), Config.SpawnClearRadius) then
        notify(_L('spawn_blocked'), 'error')
        startingMission = false
        return
    end

    if not lib.progressBar({
        duration = 2500,
        label = _L('starting'),
        canCancel = true,
        disable = { car = true, move = true, combat = true }
    }) then
        startingMission = false
        return
    end

    local response = lib.callback.await('carthief:startMission', false)
    if not response or not response.success then
        notify(response and response.message or _L('invalid_mission'), 'error')
        startingMission = false
        return
    end

    local vehicle, netId, plate = spawnMissionVehicle(response.mission)
    if not vehicle then
        lib.callback.await('carthief:abortMission', false, { reason = 'spawn_failed' })
        notify(_L('spawn_failed'), 'error')
        startingMission = false
        return
    end

    local registered, message = lib.callback.await('carthief:registerVehicle', false, {
        netId = netId,
        plate = plate
    })

    if not registered then
        DeleteVehicle(vehicle)
        notify(message or _L('invalid_mission'), 'error')
        startingMission = false
        return
    end

    activeMission = {
        deliveryId = response.mission.deliveryId,
        delivery = response.mission.delivery,
        model = response.mission.model,
        vehicle = vehicle,
        netId = netId,
        plate = plate
    }

    deliveryBlip = createNamedBlip(activeMission.delivery.coords, Config.DeliveryBlip, true)
    createDeliveryPoint(activeMission.delivery)
    notify(_L('mission_started'), 'success')
    startingMission = false
end

CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(250)
    end

    playerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    playerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    playerData.job = job
end)

CreateThread(function()
    startBlip = createNamedBlip(Config.StartZone.coords, Config.StartZone.blip, false)

    startPoint = lib.points.new({
        coords = Config.StartZone.coords,
        distance = Config.DrawDistance
    })

    function startPoint:nearby()
        drawConfiguredMarker(self.coords, Config.StartZone.marker)

        if self.currentDistance <= Config.StartZone.radius then
            if not textUiVisible then
                lib.showTextUI(_L('start_textui'))
                textUiVisible = true
            end

            if IsControlJustReleased(0, 38) then
                startMission()
            end
        else
            hideStartTextUi()
        end
    end

    function startPoint:onExit()
        hideStartTextUi()
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        if activeMission then
            local vehicle = activeMission.vehicle
            local ped = PlayerPedId()

            if not DoesEntityExist(vehicle) or GetEntityHealth(vehicle) <= 0 then
                notify(_L('vehicle_destroyed'), 'error')
                abortMission('vehicle_destroyed', true)
            elseif GetVehiclePedIsIn(ped, false) ~= vehicle then
                if not abandonStartedAt then
                    abandonStartedAt = GetGameTimer()
                    warnedFinalAbandon = false
                    notify(_L('get_back_car', Config.AbandonTimeout), 'warning')
                else
                    local elapsed = (GetGameTimer() - abandonStartedAt) / 1000
                    if not warnedFinalAbandon and elapsed >= Config.AbandonWarningTime then
                        warnedFinalAbandon = true
                        notify(_L('get_back_car_soon'), 'warning')
                    elseif elapsed >= Config.AbandonTimeout then
                        abortMission('abandoned_vehicle')
                    end
                end
            else
                abandonStartedAt = nil
                warnedFinalAbandon = false
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(250)

        if activeMission and GetGameTimer() - lastPoliceUpdate >= Config.BlipUpdateTime then
            lastPoliceUpdate = GetGameTimer()
            local vehicle = activeMission.vehicle

            if DoesEntityExist(vehicle) and GetVehiclePedIsIn(PlayerPedId(), false) == vehicle then
                local coords = GetEntityCoords(vehicle)
                TriggerServerEvent('carthief:updatePoliceBlip', activeMission.netId, coords)
            end
        end
    end
end)

RegisterNetEvent('carthief:policeAlert', function(coords, shouldNotify)
    if not isPolice() then
        return
    end

    if shouldNotify then
        notify(_L('police_alert'), 'warning')
    end

    removeBlipSafe(policeBlip)
    policeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(policeBlip, Config.PoliceBlip.sprite)
    SetBlipScale(policeBlip, Config.PoliceBlip.scale)
    SetBlipColour(policeBlip, Config.PoliceBlip.color)
    PulseBlip(policeBlip)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(_L(Config.PoliceBlip.label))
    EndTextCommandSetBlipName(policeBlip)
end)

RegisterNetEvent('carthief:clearPoliceBlip', function()
    removeBlipSafe(policeBlip)
    policeBlip = nil
end)

RegisterNetEvent('carthief:forceAbort', function(message)
    if activeMission then
        notify(message or _L('mission_aborted'), 'error')
        resetMission(true)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    hideStartTextUi()
    hideDeliveryTextUi()
    removeBlipSafe(startBlip)
    removeBlipSafe(deliveryBlip)
    removeBlipSafe(policeBlip)

    if activeMission then
        deleteMissionVehicle()
    end
end)
