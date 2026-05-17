local ESX = exports[Config.Framework.esxExport]:getSharedObject()
AdvancedHunting = AdvancedHunting or {}
AdvancedHunting.State = AdvancedHunting.State or {active = false, currentZone = nil, previousSkin = nil}

local function saveCurrentOutfit(callback)
    if Config.Framework.appearance == 'illenium' or (Config.Framework.appearance == 'auto' and GetResourceState('illenium-appearance') == 'started') then
        AdvancedHunting.State.previousSkin = exports['illenium-appearance']:getPedAppearance(PlayerPedId())
        callback()
    elseif Config.Framework.appearance == 'esx_skin' or Config.Framework.appearance == 'auto' then
        TriggerEvent('skinchanger:getSkin', function(skin)
            AdvancedHunting.State.previousSkin = skin
            callback()
        end)
    else
        callback()
    end
end

local function applyHuntingOutfit()
    if not Config.Outfit.enabled then return end
    saveCurrentOutfit(function()
        local model = GetEntityModel(PlayerPedId())
        local outfit = model == `mp_f_freemode_01` and Config.Outfit.female or Config.Outfit.male
        if Config.Framework.appearance == 'illenium' or (Config.Framework.appearance == 'auto' and GetResourceState('illenium-appearance') == 'started') then
            TriggerEvent('skinchanger:getSkin', function(skin)
                TriggerEvent('skinchanger:loadClothes', skin, outfit)
            end)
        else
            TriggerEvent('skinchanger:getSkin', function(skin)
                TriggerEvent('skinchanger:loadClothes', skin, outfit)
            end)
        end
    end)
end

local function restoreOutfit()
    if not Config.Outfit.enabled or not AdvancedHunting.State.previousSkin then return end
    if Config.Framework.appearance == 'illenium' or (Config.Framework.appearance == 'auto' and GetResourceState('illenium-appearance') == 'started') then
        exports['illenium-appearance']:setPedAppearance(PlayerPedId(), AdvancedHunting.State.previousSkin)
    else
        TriggerEvent('skinchanger:loadSkin', AdvancedHunting.State.previousSkin)
    end
    AdvancedHunting.State.previousSkin = nil
end

local function drawText3D(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

function AdvancedHunting.Start()
    if AdvancedHunting.State.active then return end
    local coords = GetEntityCoords(PlayerPedId())
    local zoneId = AdvancedHunting.Utils.GetZoneAtCoords(coords)
    if not zoneId then return AdvancedHunting.Utils.Notify(_L('not_in_zone'), 'error') end
    AdvancedHunting.State.active = true
    TriggerServerEvent('advanced_hunting:server:setActive', true, zoneId)
    AdvancedHunting.Animations.PlayStartStop()
    applyHuntingOutfit()
    AdvancedHunting.Utils.Notify(_L('hunting_started'), 'success')
end

function AdvancedHunting.Stop()
    if not AdvancedHunting.State.active then return end
    AdvancedHunting.State.active = false
    TriggerServerEvent('advanced_hunting:server:setActive', false, AdvancedHunting.State.currentZone)
    AdvancedHunting.Spawn.CleanupZone()
    AdvancedHunting.Animations.PlayStartStop()
    restoreOutfit()
    AdvancedHunting.Utils.Notify(_L('hunting_stopped'), 'inform')
end

CreateThread(function()
    AdvancedHunting.Blips.CreateZoneBlips()
    AdvancedHunting.Blips.CreateTraderBlips()
    AdvancedHunting.Zones.Monitor()

    exports.ox_target:addSphereZone({
        coords = Config.StartStop.start,
        radius = Config.StartStop.interactDistance,
        options = {{label = _L('start_hunting'), icon = 'fa-solid fa-person-rifle', onSelect = AdvancedHunting.Start}}
    })
    exports.ox_target:addSphereZone({
        coords = Config.StartStop.stop,
        radius = Config.StartStop.interactDistance,
        options = {{label = _L('stop_hunting'), icon = 'fa-solid fa-ban', onSelect = AdvancedHunting.Stop}}
    })

    for traderId, trader in pairs(HuntingTraders) do
        exports.ox_target:addSphereZone({
            coords = vector3(trader.coords.x, trader.coords.y, trader.coords.z),
            radius = 2.0,
            options = {{
                label = trader.type == 'illegal' and _L('seller_illegal') or _L('seller_legal'),
                icon = 'fa-solid fa-dollar-sign',
                onSelect = function() TriggerServerEvent('advanced_hunting:server:sellToTrader', traderId, GetEntityCoords(PlayerPedId())) end
            }}
        })
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for _, point in ipairs({{coords = Config.StartStop.start, label = _L('start_hunting')}, {coords = Config.StartStop.stop, label = _L('stop_hunting')}}) do
            local distance = #(coords - point.coords)
            if distance < Config.StartStop.markerDistance then
                sleep = 0
                local marker = Config.StartStop.marker
                DrawMarker(marker.type, point.coords.x, point.coords.y, point.coords.z + 0.15, 0, 0, 0, 0, 0, 0, marker.scale.x, marker.scale.y, marker.scale.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, marker.bobUpAndDown, false, 2, marker.rotate, nil, nil, false)
                if distance < Config.StartStop.interactDistance then
                    drawText3D(point.coords + vector3(0, 0, 1.0), marker.text:format(point.label))
                    if IsControlJustReleased(0, 38) then
                        if point.label == _L('start_hunting') then AdvancedHunting.Start() else AdvancedHunting.Stop() end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    AdvancedHunting.Spawn.CleanupZone()
    AdvancedHunting.Blips.Cleanup()
    restoreOutfit()
end)
