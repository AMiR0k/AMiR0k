local robbery = {
    active = false,
    token = nil,
    atm = nil,
    coords = nil,
    remaining = 0,
    drillObject = nil,
    soundId = nil,
    timerThread = false
}

local policeBlip

local function locale(key, ...)
    local language = Config.Locales[Config.Language] or Config.Locales.en
    local message = language[key] or Config.Locales.en[key] or key

    if select('#', ...) > 0 then
        return message:format(...)
    end

    return message
end

local function notify(description, notifyType, title)
    lib.notify({
        title = title or locale('alert_notify_title'),
        description = description,
        type = notifyType or 'inform'
    })
end

local function drawText3D(coords, message)
    AddTextEntry('six_atmrobbery_help', message)
    SetFloatingHelpTextWorldPosition(1, coords.x, coords.y, coords.z)
    SetFloatingHelpTextStyle(1, 1, 2, -1, 3, 0)
    BeginTextCommandDisplayHelp('six_atmrobbery_help')
    EndTextCommandDisplayHelp(2, false, false, -1)
end

local function loadModel(model)
    local modelHash = type(model) == 'number' and model or joaat(model)

    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(50)
        end
    end

    return modelHash
end

local function loadAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(50)
        end
    end
end

local function loadDrillSound()
    RequestAmbientAudioBank('DLC_HEIST_FLEECA_SOUNDSET', false)
    RequestAmbientAudioBank('DLC_MPHEIST\\HEIST_FLEECA_DRILL', false)
    RequestAmbientAudioBank('DLC_MPHEIST\\HEIST_FLEECA_DRILL_2', false)
end

local function cleanupDrilling()
    local ped = PlayerPedId()

    if robbery.drillObject and DoesEntityExist(robbery.drillObject) then
        DeleteEntity(robbery.drillObject)
    end

    if robbery.soundId then
        StopSound(robbery.soundId)
        ReleaseSoundId(robbery.soundId)
    end

    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    StopGameplayCamShaking(true)

    robbery.drillObject = nil
    robbery.soundId = nil
end

local function resetRobberyState()
    robbery.active = false
    robbery.token = nil
    robbery.atm = nil
    robbery.coords = nil
    robbery.remaining = 0
    robbery.timerThread = false
end

local function finishRobbery(success)
    local token = robbery.token

    cleanupDrilling()
    resetRobberyState()

    if not token then
        return
    end

    TriggerServerEvent('six_atmrobbery:server:finishRobbery', token, success == true)

    if not success then
        notify(locale('robbery_failed'), 'error')
    end
end

local function startRobberyTimer()
    if robbery.timerThread then
        return
    end

    robbery.remaining = Config.RobberyTime * 60
    robbery.timerThread = true

    CreateThread(function()
        while robbery.active and robbery.remaining > 0 do
            Wait(1000)
            robbery.remaining = robbery.remaining - 1
        end
    end)

    CreateThread(function()
        while robbery.active and robbery.remaining > 0 do
            local minutes = math.floor(robbery.remaining / 60)
            local seconds = robbery.remaining - (minutes * 60)
            drawText3D(vector3(robbery.coords.x, robbery.coords.y, robbery.coords.z + 2.25), locale('robbery_time', minutes, seconds))
            Wait(0)
        end
    end)
end

local function placePedAtAtm(atm)
    local ped = PlayerPedId()
    local atmCoords = GetEntityCoords(atm)
    local heading = GetEntityHeading(atm)
    local xOffset = 0.4 * math.sin(math.rad(heading))
    local yOffset = -0.85 * math.cos(math.rad(heading))

    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, atmCoords.x + xOffset, atmCoords.y + yOffset, atmCoords.z, false, false, false, false)
    SetEntityHeading(ped, heading)
end

Scaleforms = {}

function Scaleforms.LoadMovie(name)
    local scaleform = RequestScaleformMovie(name)
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end
    return scaleform
end

function Scaleforms.UnloadMovie(scaleform)
    SetScaleformMovieAsNoLongerNeeded(scaleform)
end

function Scaleforms.PopFloat(scaleform, method, value)
    PushScaleformMovieFunction(scaleform, method)
    PushScaleformMovieFunctionParameterFloat(value)
    PopScaleformMovieFunctionVoid()
end

function Scaleforms.PopInt(scaleform, method, value)
    PushScaleformMovieFunction(scaleform, method)
    PushScaleformMovieFunctionParameterInt(value)
    PopScaleformMovieFunctionVoid()
end

function Scaleforms.PopVoid(scaleform, method)
    PushScaleformMovieFunction(scaleform, method)
    PopScaleformMovieFunctionVoid()
end

Drilling = {
    Active = false,
    DisabledControls = { 30, 31, 32, 33, 34, 35 },
    Type = 'VAULT_LASER'
}

function Drilling.Start(callback)
    if Drilling.Active then
        return
    end

    Drilling.Active = true
    Drilling.Result = false
    Drilling.Init()

    while Drilling.Active do
        Drilling.Draw()
        Drilling.DisableControls()
        Drilling.HandleControls()
        Wait(0)
    end

    callback(Drilling.Result == true)
end

function Drilling.Init()
    if Drilling.Scaleform then
        Scaleforms.UnloadMovie(Drilling.Scaleform)
    end

    Drilling.Scaleform = Scaleforms.LoadMovie(Drilling.Type)
    Drilling.ExtraMethod = Drilling.Type == 'VAULT_LASER' and 'SET_LASER_WIDTH' or 'SET_SPEED'
    Drilling.DrillSpeed = 0.0
    Drilling.DrillPos = 0.0
    Drilling.DrillTemp = 0.0
    Drilling.HoleDepth = 0.0

    Scaleforms.PopVoid(Drilling.Scaleform, 'REVEAL')
    Scaleforms.PopFloat(Drilling.Scaleform, Drilling.ExtraMethod, 0.0)
    Scaleforms.PopFloat(Drilling.Scaleform, 'SET_DRILL_POSITION', 0.0)
    Scaleforms.PopFloat(Drilling.Scaleform, 'SET_TEMPERATURE', 0.0)
    Scaleforms.PopFloat(Drilling.Scaleform, 'SET_HOLE_DEPTH', 0.0)
    Scaleforms.PopInt(Drilling.Scaleform, 'SET_NUM_DISCS', 6)
end

function Drilling.Draw()
    DrawScaleformMovieFullscreen(Drilling.Scaleform, 255, 255, 255, 255, 255)
end

function Drilling.DisableControls()
    for _, control in ipairs(Drilling.DisabledControls) do
        DisableControlAction(0, control, true)
    end
end

function Drilling.HandleControls()
    local lastPos = Drilling.DrillPos

    if IsControlJustPressed(0, 172) then
        Drilling.DrillPos = math.min(1.0, Drilling.DrillPos + 0.01)
        Scaleforms.PopVoid(Drilling.Scaleform, 'burstOutSparks')
    elseif IsControlPressed(0, 172) then
        Drilling.DrillPos = math.min(1.0, Drilling.DrillPos + (0.1 * GetFrameTime() / (math.max(0.1, Drilling.DrillTemp) * 10)))
    elseif IsControlJustPressed(0, 173) then
        Drilling.DrillPos = math.max(0.0, Drilling.DrillPos - 0.01)
    elseif IsControlPressed(0, 173) then
        Drilling.DrillPos = math.max(0.0, Drilling.DrillPos - (0.1 * GetFrameTime()))
    end

    local lastSpeed = Drilling.DrillSpeed

    if IsControlJustPressed(0, 175) then
        Drilling.DrillSpeed = math.min(1.0, Drilling.DrillSpeed + 0.05)
    elseif IsControlPressed(0, 175) then
        Drilling.DrillSpeed = math.min(1.0, Drilling.DrillSpeed + (0.5 * GetFrameTime()))
    elseif IsControlJustPressed(0, 174) then
        Drilling.DrillSpeed = math.max(0.0, Drilling.DrillSpeed - 0.05)
    elseif IsControlPressed(0, 174) then
        Drilling.DrillSpeed = math.max(0.0, Drilling.DrillSpeed - (0.5 * GetFrameTime()))
    end

    local lastTemp = Drilling.DrillTemp

    if lastPos < Drilling.DrillPos then
        if Drilling.DrillSpeed > 0.4 then
            Drilling.DrillTemp = math.min(1.0, Drilling.DrillTemp + ((0.05 * GetFrameTime()) * (Drilling.DrillSpeed * 10)))
            Scaleforms.PopFloat(Drilling.Scaleform, 'SET_DRILL_POSITION', Drilling.DrillPos)
        elseif Drilling.DrillPos < 0.1 or Drilling.DrillPos < Drilling.HoleDepth then
            Scaleforms.PopFloat(Drilling.Scaleform, 'SET_DRILL_POSITION', Drilling.DrillPos)
        else
            Drilling.DrillPos = lastPos
            Drilling.DrillTemp = math.min(1.0, Drilling.DrillTemp + (0.01 * GetFrameTime()))
        end
    else
        if Drilling.DrillPos < Drilling.HoleDepth then
            Drilling.DrillTemp = math.max(0.0, Drilling.DrillTemp - ((0.05 * GetFrameTime()) * math.max(0.005, (Drilling.DrillSpeed * 10) / 2)))
        end

        if Drilling.DrillPos ~= Drilling.HoleDepth then
            Scaleforms.PopFloat(Drilling.Scaleform, 'SET_DRILL_POSITION', Drilling.DrillPos)
        end
    end

    if lastSpeed ~= Drilling.DrillSpeed then
        Scaleforms.PopFloat(Drilling.Scaleform, Drilling.ExtraMethod, Drilling.DrillSpeed)
    end

    if lastTemp ~= Drilling.DrillTemp then
        Scaleforms.PopFloat(Drilling.Scaleform, 'SET_TEMPERATURE', Drilling.DrillTemp)
    end

    if Drilling.DrillTemp >= 1.0 then
        Drilling.Result = false
        Drilling.Active = false
        Scaleforms.PopVoid(Drilling.Scaleform, 'RESET')
    elseif Drilling.DrillPos >= 1.0 then
        Drilling.Result = true
        Drilling.Active = false
        Scaleforms.PopVoid(Drilling.Scaleform, 'RESET')
    end

    Drilling.HoleDepth = Drilling.DrillPos > Drilling.HoleDepth and Drilling.DrillPos or Drilling.HoleDepth
end

local function beginDrilling()
    local ped = PlayerPedId()
    local animDict = 'anim@heists@fleeca_bank@drilling'
    local animName = 'drill_straight_idle'

    loadAnimDict(animDict)
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    Wait(500)

    local drillModel = loadModel('hei_prop_heist_drill')
    local boneIndex = GetPedBoneIndex(ped, 28422)

    TaskPlayAnim(ped, animDict, animName, 1.0, -1.0, -1, 2, 0, false, false, false)
    robbery.drillObject = CreateObject(drillModel, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(robbery.drillObject, ped, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
    SetEntityAsMissionEntity(robbery.drillObject, true, true)
    SetModelAsNoLongerNeeded(drillModel)

    loadDrillSound()
    Wait(100)
    robbery.soundId = GetSoundId()
    PlaySoundFromEntity(robbery.soundId, 'Drill', robbery.drillObject, 'DLC_HEIST_FLEECA_SOUNDSET', true, 0)
    ShakeGameplayCam('SKY_DIVING_SHAKE', 0.6)

    Drilling.Type = 'VAULT_LASER'
    Drilling.Start(function(success)
        finishRobbery(success)
    end)
end

local function requestRobberyStart(atm)
    if robbery.active then
        notify(locale('robbery_busy'), 'error')
        return
    end

    local ped = PlayerPedId()

    if not IsPedOnFoot(ped) or IsPedDeadOrDying(ped, true) then
        return
    end

    local coords = GetEntityCoords(atm)
    local response = lib.callback.await('six_atmrobbery:server:startRobbery', false, {
        x = coords.x,
        y = coords.y,
        z = coords.z
    })

    if not response or not response.ok then
        if response and response.message then
            notify(response.message, response.type or 'error')
        end
        return
    end

    robbery.active = true
    robbery.token = response.token
    robbery.atm = atm
    robbery.coords = coords

    placePedAtAtm(atm)
    startRobberyTimer()
    beginDrilling()
end

local function getClosestAtm()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closestAtm
    local closestDistance = Config.Target.distance + 0.5

    for i = 1, #Config.ATM_Props do
        local atm = GetClosestObjectOfType(coords.x, coords.y, coords.z, closestDistance, joaat(Config.ATM_Props[i]), false, false, false)

        if atm ~= 0 then
            local distance = #(coords - GetEntityCoords(atm))
            if distance < closestDistance then
                closestAtm = atm
                closestDistance = distance
            end
        end
    end

    return closestAtm
end

RegisterNetEvent('six_atmrobbery:client:useDrill', function()
    local atm = getClosestAtm()

    if not atm then
        notify(locale('robbery_too_far'), 'error')
        return
    end

    requestRobberyStart(atm)
end)

RegisterNetEvent('six_atmrobbery:client:notify', function(data)
    if type(data) == 'string' then
        notify(data, 'inform')
        return
    end

    lib.notify(data)
end)

RegisterNetEvent('six_atmrobbery:client:policeAlert', function(coords)
    if policeBlip and DoesBlipExist(policeBlip) then
        RemoveBlip(policeBlip)
        policeBlip = nil
    end

    if not coords then
        notify(locale('alert_notify_ended'), 'inform')
        return
    end

    notify(locale('alert_notify_started'), 'error')

    policeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(policeBlip, 161)
    SetBlipScale(policeBlip, 0.7)
    SetBlipColour(policeBlip, 1)
    SetBlipAsShortRange(policeBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(locale('alert_blip_name'))
    EndTextCommandSetBlipName(policeBlip)

    SetTimeout(Config.PoliceBlipDuration, function()
        if policeBlip and DoesBlipExist(policeBlip) then
            RemoveBlip(policeBlip)
            policeBlip = nil
        end
    end)
end)

CreateThread(function()
    exports.ox_target:addModel(Config.ATM_Props, {
        {
            name = 'six_atmrobbery:rob_atm',
            icon = Config.Target.icon,
            label = Config.Target.label,
            distance = Config.Target.distance,
            canInteract = function(entity)
                return not robbery.active and DoesEntityExist(entity) and IsPedOnFoot(PlayerPedId())
            end,
            onSelect = function(data)
                requestRobberyStart(data.entity)
            end
        }
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    cleanupDrilling()

    if policeBlip and DoesBlipExist(policeBlip) then
        RemoveBlip(policeBlip)
    end

    exports.ox_target:removeModel(Config.ATM_Props, 'six_atmrobbery:rob_atm')
end)
