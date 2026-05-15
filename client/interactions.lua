OKGangs = OKGangs or {}
OKGangs.Client = OKGangs.Client or {}

local cuffed = false
local dragging = false
local dragger = nil

local function handsUp()
    return IsEntityPlayingAnim(cache.ped, 'missminuteman_1ig_2', 'handsup_base', 3) or IsPedUsingScenario(cache.ped, 'WORLD_HUMAN_MUSCLE_FLEX')
end

RegisterNetEvent('ok_gangs:client:cuff', function(sourceId)
    if not cuffed and not handsUp() and not IsEntityDead(cache.ped) then
        return lib.notify({ description = 'Target must have hands up or be dead', type = 'error' })
    end
    cuffed = not cuffed
    SetEnableHandcuffs(cache.ped, cuffed)
    if cuffed then
        lib.requestAnimDict('mp_arresting')
        TaskPlayAnim(cache.ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        ClearPedTasks(cache.ped)
    end
end)

RegisterNetEvent('ok_gangs:client:drag', function(sourceId)
    if not cuffed and not IsEntityDead(cache.ped) then return end
    dragging = not dragging
    dragger = sourceId
end)

CreateThread(function()
    while true do
        if dragging and dragger then
            local player = GetPlayerFromServerId(dragger)
            local ped = player ~= -1 and GetPlayerPed(player) or 0
            if ped ~= 0 then AttachEntityToEntity(cache.ped, ped, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true) end
            Wait(500)
        else
            DetachEntity(cache.ped, true, false)
            Wait(1000)
        end
    end
end)

RegisterNetEvent('ok_gangs:client:putInVehicle', function()
    if not cuffed and not IsEntityDead(cache.ped) then return end
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if vehicle then TaskWarpPedIntoVehicle(cache.ped, vehicle, 1) end
end)

RegisterNetEvent('ok_gangs:client:putOutVehicle', function()
    if IsPedInAnyVehicle(cache.ped, false) then TaskLeaveVehicle(cache.ped, GetVehiclePedIsIn(cache.ped, false), 16) end
end)
