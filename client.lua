local ESX = exports['es_extended']:getSharedObject()

local PREFIX = Config.Server.eventPrefix

local robberyState = {
    activeBank = nil,
    stage = nil,
    lock = false
}

local pointStates = {}
local startPoints, weldPoints = {}, {}

local function locale(key, ...)
    local text = Config.Locale[key] or key
    if select('#', ...) > 0 then
        return text:format(...)
    end
    return text
end

local function notify(kind, msg)
    lib.notify({
        title = 'Bank Robbery',
        description = msg,
        type = kind
    })
end

local function drawMarker(pos, color)
    DrawMarker(
        Config.Markers.type,
        pos.x, pos.y, pos.z - 0.95,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        Config.Markers.scale.x, Config.Markers.scale.y, Config.Markers.scale.z,
        color.r, color.g, color.b, color.a,
        Config.Markers.bobUpAndDown,
        Config.Markers.faceCamera,
        2,
        false, nil, nil, false
    )
end

local function canInteract(bankId, stage)
    if robberyState.lock then return false end
    if stage == 'start' and robberyState.activeBank then
        notify('error', locale('robbery_busy'))
        return false
    end
    if stage == 'weld' then
        if robberyState.activeBank ~= bankId or robberyState.stage ~= 'weld' then
            return false
        end
    end
    return true
end

local function runFingerprintHack(levels, lifes, minutes)
    local promiseObj = promise.new()

    TriggerEvent('utk_fingerprint:Start', levels, lifes, minutes, function(success)
        promiseObj:resolve(success == true)
    end)

    return Citizen.Await(promiseObj)
end

local function doHack(bankId)
    notify('inform', locale('hack_start'))
    local ok = runFingerprintHack(3, 5, 3)
    if not ok then
        notify('error', locale('hack_failed'))
        TriggerServerEvent(('%s:server:resetAttempt'):format(PREFIX), bankId)
        return
    end

    local accepted = lib.callback.await(('%s:server:completeHack'):format(PREFIX), false, bankId)
    if accepted then
        robberyState.activeBank = bankId
        robberyState.stage = 'weld'
        notify('success', locale('hack_success'))
    else
        robberyState.activeBank = nil
        robberyState.stage = nil
    end
end

local function doWeld(bankId)
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_WELDING', 0, true)

    local finished = lib.progressBar({
        duration = Config.Settings.weldTimer * 1000,
        label = locale('weld_progress'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
            sprint = true
        }
    })

    ClearPedTasks(ped)

    if not finished then
        notify('error', locale('weld_canceled'))
        TriggerServerEvent(('%s:server:cancelWeld'):format(PREFIX), bankId)
        robberyState.activeBank = nil
        robberyState.stage = nil
        return
    end

    local success = lib.callback.await(('%s:server:completeWeld'):format(PREFIX), false, bankId)
    if success then
        notify('success', locale('weld_done'))
    end

    robberyState.activeBank = nil
    robberyState.stage = nil
end

local function interactStart(bankId)
    if not canInteract(bankId, 'start') then return end
    robberyState.lock = true
    local response = lib.callback.await(('%s:server:beginHack'):format(PREFIX), false, bankId)
    robberyState.lock = false

    if not response then return end

    if response.error == 'missing_item' then
        notify('error', locale('missing_item', Config.Items.hack))
        return
    end
    if response.error == 'cooldown_global' then
        notify('error', locale('cooldown_global', response.remaining))
        return
    end
    if response.error == 'cooldown_bank' then
        notify('error', locale('cooldown_bank', response.remaining))
        return
    end
    if response.error == 'need_cops' then
        notify('error', locale('need_cops', Config.Settings.mincops))
        return
    end
    if response.error then
        notify('error', locale(response.error))
        return
    end

    doHack(bankId)
end

local function interactWeld(bankId)
    if not canInteract(bankId, 'weld') then return end
    robberyState.lock = true
    local canWeld = lib.callback.await(('%s:server:beginWeld'):format(PREFIX), false, bankId)
    robberyState.lock = false

    if not canWeld then return end
    if canWeld.error == 'missing_item' then
        notify('error', locale('missing_item', Config.Items.weld))
        return
    end
    if canWeld.error then
        notify('error', locale(canWeld.error))
        return
    end

    doWeld(bankId)
end

local function registerBankPoints()
    for bankId, bank in pairs(Config.Banks) do
        pointStates[bankId] = { startInside = false, weldInside = false }

        startPoints[#startPoints + 1] = lib.points.new({
            coords = bank.start,
            distance = Config.Settings.markerDistance,
            bankId = bankId,
            stage = 'start',
            nearby = function(self)
                drawMarker(self.coords, Config.Markers.colorStart)
                if self.currentDistance <= Config.Settings.interactDistance then
                    ESX.ShowHelpNotification(locale('interact_start'))
                    if IsControlJustReleased(0, 38) then
                        interactStart(self.bankId)
                    end
                end
            end
        })

        weldPoints[#weldPoints + 1] = lib.points.new({
            coords = bank.weld,
            distance = Config.Settings.markerDistance,
            bankId = bankId,
            stage = 'weld',
            nearby = function(self)
                if robberyState.activeBank ~= self.bankId or robberyState.stage ~= 'weld' then
                    return
                end
                drawMarker(self.coords, Config.Markers.colorWeld)
                if self.currentDistance <= Config.Settings.interactDistance then
                    ESX.ShowHelpNotification(locale('interact_weld'))
                    if IsControlJustReleased(0, 38) then
                        interactWeld(self.bankId)
                    end
                end
            end
        })
    end
end

RegisterNetEvent(('%s:client:resetState'):format(PREFIX), function()
    robberyState.activeBank = nil
    robberyState.stage = nil
    robberyState.lock = false
end)

CreateThread(function()
    registerBankPoints()
end)
