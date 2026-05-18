local cachedKeys = {}
local lastVehicle = nil
local lastDeniedPlate = nil

local function notify(title, description, notifyType)
    lib.notify({
        title = title or 'Vehicle Keys',
        description = description,
        type = notifyType or 'inform',
        position = Config.Notifications.position
    })
end

local function getPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return VehicleKeys.NormalizePlate(GetVehicleNumberPlateText(vehicle))
end

local function getDisplayPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return VehicleKeys.DisplayPlate(GetVehicleNumberPlateText(vehicle))
end

local function getModel(vehicle)
    if not vehicle or vehicle == 0 then return 'unknown' end
    return GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
end

local function getClosestVehicle(maxDistance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = lib.getClosestVehicle(coords, maxDistance or Config.LockDistance, true)

    if vehicle and vehicle ~= 0 then
        return vehicle
    end

    vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle and vehicle ~= 0 then
        return vehicle
    end

    return nil
end

local function hasKey(vehicle)
    if not vehicle or vehicle == 0 then return false end
    local plate = getPlate(vehicle)
    if not plate then return false end

    local now = GetGameTimer()
    local cached = cachedKeys[plate]
    if cached and cached.expires > now then
        return cached.allowed
    end

    local allowed = lib.callback.await('amir_vehiclekeys:server:hasKey', false, plate, getModel(vehicle))
    cachedKeys[plate] = { allowed = allowed == true, expires = now + Config.KeyCacheTtl }
    return allowed == true
end

local function setVehicleLock(vehicle, locked)
    if not vehicle or vehicle == 0 then return end

    SetVehicleDoorsLocked(vehicle, locked and 2 or 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, locked)
    SetVehicleLights(vehicle, 2)
    Wait(150)
    SetVehicleLights(vehicle, 0)
    PlayVehicleDoorCloseSound(vehicle, 1)

    notify('Vehicle Keys', locked and 'Vehicle locked.' or 'Vehicle unlocked.', locked and 'warning' or 'success')
end

local function toggleLock(vehicle)
    vehicle = vehicle or getClosestVehicle(Config.LockDistance)
    if not vehicle then
        notify('Vehicle Keys', 'No vehicle nearby.', 'error')
        return
    end

    if not hasKey(vehicle) then
        notify('Vehicle Keys', 'You do not have a key for this vehicle.', 'error')
        return
    end

    local locked = GetVehicleDoorLockStatus(vehicle)
    setVehicleLock(vehicle, locked < 2)
end

local function ensureOwnedKey(vehicle)
    if not vehicle or vehicle == 0 or not Config.AutoGiveKeyForOwnedVehicle then return end
    local plate = getPlate(vehicle)
    if not plate then return end

    local created = lib.callback.await('amir_vehiclekeys:server:ensureOwnedKey', false, plate, getModel(vehicle))
    if created then
        cachedKeys[plate] = { allowed = true, expires = GetGameTimer() + Config.KeyCacheTtl }
    end
end

local function giveKey(vehicle)
    if not vehicle then return end

    local input = lib.inputDialog('Give Vehicle Key', {
        { type = 'number', label = 'Target server ID', description = 'The player must be nearby.', required = true, min = 1 }
    })
    if not input then return end

    local ok, message = lib.callback.await('amir_vehiclekeys:server:giveKey', false, getPlate(vehicle), getModel(vehicle), input[1])
    if not ok and message then notify('Vehicle Keys', message, 'error') end
end

local function removeKey(vehicle)
    if not vehicle then return end

    local input = lib.inputDialog('Remove Vehicle Key', {
        { type = 'input', label = 'Player identifier or online server ID', required = true }
    })
    if not input then return end

    local ok, message = lib.callback.await('amir_vehiclekeys:server:removeKey', false, getPlate(vehicle), input[1])
    notify('Vehicle Keys', ok and 'Key removed successfully.' or (message or 'Failed to remove key.'), ok and 'success' or 'error')
end

local function showHolders(vehicle)
    if not vehicle then return end

    local holders = lib.callback.await('amir_vehiclekeys:server:getHolders', false, getPlate(vehicle)) or {}
    if #holders == 0 then
        notify('Vehicle Keys', 'No holders found or you cannot manage this vehicle.', 'error')
        return
    end

    local options = {}
    for _, holder in ipairs(holders) do
        options[#options + 1] = {
            title = holder.holder_name or holder.identifier,
            description = ('%s | %s'):format(holder.permission_type or 'shared', holder.identifier),
            icon = holder.permission_type == 'owner' and 'crown' or 'key'
        }
    end

    lib.registerContext({
        id = 'amir_vehiclekeys_holders',
        title = ('Key Holders - %s'):format(getDisplayPlate(vehicle)),
        menu = 'amir_vehiclekeys_main',
        options = options
    })
    lib.showContext('amir_vehiclekeys_holders')
end

local function attemptLockpick(vehicle, mode)
    if not vehicle then return end

    local label = mode == 'door' and 'Lockpicking door...' or 'Hotwiring engine...'
    local duration = mode == 'door' and Config.Lockpick.doorDuration or Config.Lockpick.hotwireDuration
    local completed = lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'veh@break_in@0h@p_m_one@', clip = 'low_force_entry_ds' }
    })

    if not completed then return end

    local success, message, alert = lib.callback.await('amir_vehiclekeys:server:attemptLockpick', false, mode, getPlate(vehicle), getModel(vehicle))
    if success then
        if mode == 'door' then
            setVehicleLock(vehicle, false)
            notify('Lockpick', 'Door unlocked.', 'success')
        else
            cachedKeys[getPlate(vehicle)] = { allowed = true, expires = GetGameTimer() + Config.KeyCacheTtl }
            SetVehicleEngineOn(vehicle, true, true, false)
            notify('Hotwire', 'Engine bypass succeeded.', 'success')
        end
    else
        if Config.Lockpick.alarmSeconds > 0 then
            SetVehicleAlarm(vehicle, true)
            StartVehicleAlarm(vehicle)
            SetVehicleAlarmTimeLeft(vehicle, Config.Lockpick.alarmSeconds * 1000)
        end
        notify('Lockpick', message or 'Attempt failed.', alert and 'warning' or 'error')
    end
end

local function openMenu(vehicle)
    vehicle = vehicle or getClosestVehicle(Config.LockDistance)
    if not vehicle then
        notify('Vehicle Keys', 'No vehicle nearby.', 'error')
        return
    end

    local plate = getDisplayPlate(vehicle)
    lib.registerContext({
        id = 'amir_vehiclekeys_main',
        title = ('Vehicle Keys - %s'):format(plate),
        options = {
            { title = 'Give Key', description = 'Share a key with a nearby player.', icon = 'key', onSelect = function() giveKey(vehicle) end },
            { title = 'Remove Key', description = 'Revoke a shared key by ID or identifier.', icon = 'ban', onSelect = function() removeKey(vehicle) end },
            { title = 'Show Key Holders', description = 'View active holders for this plate.', icon = 'users', onSelect = function() showHolders(vehicle) end },
            { title = 'Lock/Unlock Vehicle', description = 'Toggle vehicle locks.', icon = 'lock', onSelect = function() toggleLock(vehicle) end },
            { title = 'Lockpick Door', description = 'Try to unlock without a key.', icon = 'screwdriver-wrench', disabled = not Config.Lockpick.enabled, onSelect = function() attemptLockpick(vehicle, 'door') end },
            { title = 'Lockpick Engine / Hotwire', description = 'Try to bypass the immobilizer.', icon = 'bolt', disabled = not Config.Lockpick.enabled, onSelect = function() attemptLockpick(vehicle, 'hotwire') end }
        }
    })

    lib.showContext('amir_vehiclekeys_main')
end

RegisterNetEvent('amir_vehiclekeys:client:useKeyItem', function(metadata)
    metadata = metadata and metadata.metadata or metadata or {}
    local targetPlate = VehicleKeys.NormalizePlate(metadata.plate or metadata.displayPlate)
    local vehicle = getClosestVehicle(Config.LockDistance)

    if not vehicle or (targetPlate ~= '' and getPlate(vehicle) ~= targetPlate) then
        notify('Vehicle Key', 'No matching vehicle nearby.', 'error')
        return
    end

    lib.registerContext({
        id = 'amir_vehiclekeys_item',
        title = metadata.label or ('Vehicle Key - %s'):format(targetPlate),
        options = {
            { title = 'Lock/Unlock Vehicle', icon = 'lock', onSelect = function() toggleLock(vehicle) end },
            { title = 'Give Key', icon = 'key', onSelect = function() giveKey(vehicle) end },
            { title = 'Open Management Menu', icon = 'bars', onSelect = function() openMenu(vehicle) end }
        }
    })
    lib.showContext('amir_vehiclekeys_item')
end)

RegisterNetEvent('amir_vehiclekeys:client:policeAlert', function(data)
    notify('Vehicle Theft Alert', ('%s attempt on %s (%s).'):format(data.mode or 'theft', data.plate or 'unknown', data.model or 'unknown'), 'warning')
    if data.coords then
        local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.9)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Vehicle Theft')
        EndTextCommandSetBlipName(blip)
        SetTimeout(60000, function() RemoveBlip(blip) end)
    end
end)

RegisterCommand(Config.LockCommand, function()
    toggleLock()
end, false)

RegisterCommand(Config.MenuCommand, function()
    openMenu()
end, false)

RegisterKeyMapping(Config.LockCommand, 'Lock/unlock vehicle with key', 'keyboard', 'U')
RegisterKeyMapping(Config.MenuCommand, 'Open vehicle keys menu', 'keyboard', 'F6')

CreateThread(function()
    while true do
        Wait(Config.VehicleCheckInterval)

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= lastVehicle then
                lastVehicle = vehicle
                ensureOwnedKey(vehicle)
            end

            if Config.EnableEngineImmobilizer and GetPedInVehicleSeat(vehicle, Config.DriverSeatIndex) == ped then
                if not hasKey(vehicle) then
                    SetVehicleEngineOn(vehicle, false, true, true)
                    DisableControlAction(0, 71, true)
                    DisableControlAction(0, 72, true)
                    if lastDeniedPlate ~= getPlate(vehicle) then
                        lastDeniedPlate = getPlate(vehicle)
                        notify('Vehicle Keys', 'You need a key to start this vehicle.', 'error')
                    end
                else
                    lastDeniedPlate = nil
                end
            end
        else
            lastVehicle = nil
            lastDeniedPlate = nil
        end
    end
end)

CreateThread(function()
    while Config.EnablePreventDriverEntry do
        Wait(250)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) and GetVehiclePedIsTryingToEnter(ped) ~= 0 then
            local vehicle = GetVehiclePedIsTryingToEnter(ped)
            local seat = GetSeatPedIsTryingToEnter(ped)
            if seat == Config.DriverSeatIndex and not hasKey(vehicle) then
                ClearPedTasks(ped)
                notify('Vehicle Keys', 'You cannot enter the driver seat without a key.', 'error')
            end
        end
    end
end)

for _, eventName in ipairs(Config.GarageSpawnEvents) do
    RegisterNetEvent(eventName, function(vehicle)
        if not Config.AutoGiveKeyFromGarage then return end
        if type(vehicle) == 'number' and DoesEntityExist(vehicle) then
            ensureOwnedKey(vehicle)
        elseif type(vehicle) == 'table' and vehicle.plate then
            lib.callback.await('amir_vehiclekeys:server:ensureOwnedKey', false, vehicle.plate, vehicle.model or 'unknown')
        else
            SetTimeout(1000, function()
                local currentVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                if currentVehicle ~= 0 then ensureOwnedKey(currentVehicle) end
            end)
        end
    end)
end

exports('HasKey', hasKey)
exports('OpenMenu', openMenu)
exports('ToggleLock', toggleLock)
