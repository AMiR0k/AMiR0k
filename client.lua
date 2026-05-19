local activeStore = nil
local robberyEndTime = 0
local policeBlips = {}

local function notify(title, description, nType)
    lib.notify({ title = title, description = description, type = nType or 'inform' })
end

local function formatTime(sec)
    local m = math.floor(sec / 60)
    local s = sec % 60
    return ('%02d:%02d'):format(m, s)
end

RegisterNetEvent('ammunation_robbery:client:robberyStarted', function(storeId, duration)
    activeStore = storeId
    robberyEndTime = GetGameTimer() + (duration * 1000)
end)

RegisterNetEvent('ammunation_robbery:client:robberyCancelled', function(reason)
    activeStore = nil
    robberyEndTime = 0
    notify('Robbery', reason or 'Robbery cancelled.', 'error')
end)

RegisterNetEvent('ammunation_robbery:client:robberyComplete', function(data)
    activeStore = nil
    robberyEndTime = 0
    notify('Robbery', ('Completed! Reward: %s (+%d ammo), gangcoin x%d'):format(data.weapon, data.ammo, data.gangcoin), 'success')
end)

RegisterNetEvent('ammunation_robbery:client:policeBlip', function(coords, label)
    local key = ('%.2f_%.2f_%.2f'):format(coords.x, coords.y, coords.z)
    if policeBlips[key] then RemoveBlip(policeBlips[key]) end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.DispatchBlip.sprite)
    SetBlipColour(blip, Config.DispatchBlip.color)
    SetBlipScale(blip, Config.DispatchBlip.scale)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or Config.DispatchBlip.label)
    EndTextCommandSetBlipName(blip)
    PulseBlip(blip)

    policeBlips[key] = blip
end)

RegisterNetEvent('ammunation_robbery:client:removePoliceBlip', function(coords)
    local key = ('%.2f_%.2f_%.2f'):format(coords.x, coords.y, coords.z)
    if policeBlips[key] then
        RemoveBlip(policeBlips[key])
        policeBlips[key] = nil
    end
end)

CreateThread(function()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)

        for storeId, store in pairs(Config.Stores) do
            local distance = #(pCoords - store.coords)

            if distance < Config.DrawDistance then
                wait = 0
                DrawMarker(
                    Config.Marker.type,
                    store.coords.x, store.coords.y, store.coords.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                    Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                    false, false, 2, false, nil, nil, false
                )

                if not activeStore and distance <= Config.InteractDistance then
                    lib.showTextUI(('[E] Rob %s'):format(store.label))
                    if IsControlJustReleased(0, 38) then
                        if Config.RequireArmed and not IsPedArmed(ped, 4) then
                            notify('Robbery', 'You need to be armed.', 'error')
                        else
                            local ok = lib.progressBar({
                                duration = 2000,
                                label = 'Intimidating clerk...',
                                useWhileDead = false,
                                canCancel = true,
                                disable = { move = true, car = true, combat = true }
                            })

                            if ok then
                                TriggerServerEvent('ammunation_robbery:server:start', storeId)
                            end
                        end
                    end
                end
            end
        end

        if wait > 0 then lib.hideTextUI() end

        if activeStore then
            wait = 0
            local store = Config.Stores[activeStore]
            local dist = #(pCoords - store.coords)
            local remaining = math.max(0, math.ceil((robberyEndTime - GetGameTimer()) / 1000))

            lib.showTextUI(('Robbery: %s | Time left: %s'):format(store.label, formatTime(remaining)))

            if dist > Config.MaxDistance then
                TriggerServerEvent('ammunation_robbery:server:cancel', activeStore)
                Wait(1000)
            elseif remaining <= 0 then
                TriggerServerEvent('ammunation_robbery:server:complete', activeStore)
                Wait(1000)
            end
        end

        Wait(wait)
    end
end)
