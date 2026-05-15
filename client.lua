local currentFarm = nil
local currentPlants = {}
local spawnedProps = {}
local insideFarm = false

local function notify(message, notifyType)
    lib.notify({ description = message, type = notifyType or 'inform' })
end

local function isBlocked()
    return IsEntityDead(cache.ped) or IsPedFatallyInjured(cache.ped)
end

local function drawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 220)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function drawMarker(coords)
    DrawMarker(
        Config.Marker.type,
        coords.x, coords.y, coords.z + 0.2,
        0.0, 0.0, 0.0,
        0.0, 180.0, 0.0,
        Config.Marker.scale.x, Config.Marker.scale.y, Config.Marker.scale.z,
        Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
        false, true, 2, nil, nil, false
    )
end

local function fadeTeleport(coords)
    DoScreenFadeOut(650)
    while not IsScreenFadedOut() do Wait(0) end
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, true)
    Wait(250)
    DoScreenFadeIn(650)
end

local function requestModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function deleteProps()
    for _, entity in pairs(spawnedProps) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    spawnedProps = {}
end

local function spawnPlantProp(plant)
    if not insideFarm or not currentFarm or currentFarm.uuid ~= plant.farm_uuid then return end
    if spawnedProps[plant.id] and DoesEntityExist(spawnedProps[plant.id]) then return end

    local slot = Config.FarmSlots[tonumber(plant.slot_id)]
    if not slot then return end

    local hash = requestModel(plant.prop)
    if not hash then return end

    local entity = CreateObject(hash, slot.coords.x, slot.coords.y, slot.coords.z - 1.0, false, false, false)
    SetEntityHeading(entity, 0.0)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetEntityAsMissionEntity(entity, true, true)
    spawnedProps[plant.id] = entity
    SetModelAsNoLongerNeeded(hash)
end

local function rebuildPlants(plants)
    deleteProps()
    currentPlants = {}
    for _, plant in ipairs(plants or {}) do
        plant.id = tonumber(plant.id)
        plant.slot_id = tonumber(plant.slot_id)
        plant.planted_at = tonumber(plant.planted_at)
        currentPlants[plant.id] = plant
        spawnPlantProp(plant)
    end
end

local function getPlantBySlot(slotId)
    for _, plant in pairs(currentPlants) do
        if tonumber(plant.slot_id) == tonumber(slotId) then return plant end
    end
end

local function getGrowthPercent(plant)
    local elapsed = GetCloudTimeAsInt() - tonumber(plant.planted_at)
    return math.floor(math.min(100, math.max(0, elapsed / (Config.GrowthMinutes * 60) * 100)))
end

local function openStash(farm)
    if isBlocked() then return notify('در حالت مرگ نمی‌توانید منو/انبار را باز کنید.', 'error') end
    if not farm or farm.expired then return notify('زمان زمین تمام شده است.', 'error') end
    exports.ox_inventory:openInventory('stash', ('farm_%s'):format(farm.uuid))
end

local function showKeyMenu(data)
    local options = {}

    options[#options + 1] = {
        title = 'دادن کلید به بازیکن',
        description = 'فقط یک بازیکن می‌تواند کلید داشته باشد. کلید قبلی جایگزین می‌شود.',
        icon = 'key',
        onSelect = function()
            local input = lib.inputDialog('دادن کلید زمین', {
                { type = 'number', label = 'Server ID بازیکن', required = true, min = 1 }
            })
            if input and input[1] then TriggerServerEvent('amirok_farming:grantAccess', input[1]) end
        end
    }

    if data.hasKeyholder then
        options[#options + 1] = {
            title = 'لغو کلید فعلی',
            description = ('Identifier: %s'):format(data.hasKeyholder),
            icon = 'ban',
            onSelect = function() TriggerServerEvent('amirok_farming:revokeAccess') end
        }
    end

    lib.registerContext({ id = 'amirok_farm_keys', title = 'مدیریت کلید زمین', options = options })
    lib.showContext('amirok_farm_keys')
end

local function openManagementMenu()
    if isBlocked() then return notify('در حالت مرگ نمی‌توانید منو را باز کنید.', 'error') end

    local data = lib.callback.await('amirok_farming:getMenuData', false)
    local options = {}

    if not data or not data.hasFarm then
        options[#options + 1] = {
            title = ('خرید زمین - $%s'):format(Config.PurchasePrice),
            icon = 'seedling',
            onSelect = function() TriggerServerEvent('amirok_farming:buyFarm') end
        }
    else
        local farm = data.farm
        if data.expired then
            options[#options + 1] = {
                title = ('تمدید زمین - $%s'):format(Config.PurchasePrice),
                description = 'زمان مالکیت تمام شده و کلید بازیکن دوم حذف می‌شود.',
                icon = 'rotate-right',
                onSelect = function() TriggerServerEvent('amirok_farming:renewFarm') end
            }
        else
            options[#options + 1] = {
                title = 'مشاهده انبار',
                description = ('ظرفیت: %s کیلو'):format(farm.stash_capacity),
                icon = 'box-open',
                onSelect = function() openStash(farm) end
            }

            options[#options + 1] = {
                title = 'ورود به مزرعه',
                icon = 'door-open',
                onSelect = function()
                    if isBlocked() then return notify('در حالت مرگ نمی‌توانید وارد شوید.', 'error') end
                    DoScreenFadeOut(650)
                    while not IsScreenFadedOut() do Wait(0) end
                    TriggerServerEvent('amirok_farming:enterFarm', farm.uuid)
                end
            }

            if data.role == 'owner' then
                options[#options + 1] = {
                    title = 'مدیریت کلید',
                    description = 'دادن یا لغو دسترسی یک بازیکن دیگر',
                    icon = 'key',
                    onSelect = function() showKeyMenu(data) end
                }

                if tonumber(farm.stash_capacity) < Config.UpgradedStorageKg then
                    options[#options + 1] = {
                        title = ('ارتقای انبار به %s کیلو - $%s'):format(Config.UpgradedStorageKg, Config.StorageUpgradePrice),
                        icon = 'angles-up',
                        onSelect = function() TriggerServerEvent('amirok_farming:upgradeStorage') end
                    }
                end
            end
        end

        options[#options + 1] = {
            title = 'اطلاعات زمین',
            description = ('زمان باقی‌مانده: %s | ظرفیت انبار: %s کیلو | نقش: %s'):format(FarmUtils.formatSeconds(data.remaining), farm.stash_capacity, data.role),
            icon = 'circle-info',
            disabled = true
        }
    end

    lib.registerContext({ id = 'amirok_farm_management', title = 'مدیریت زمین کشاورزی', options = options })
    lib.showContext('amirok_farm_management')
end

local function openSeedMenu(slotId)
    if isBlocked() then return notify('در حالت مرگ نمی‌توانید کشت کنید.', 'error') end

    local seeds = lib.callback.await('amirok_farming:getSeeds', false) or {}
    local options = {}

    if #seeds == 0 then
        options[#options + 1] = { title = 'هیچ بذری در inventory شما نیست.', disabled = true, icon = 'triangle-exclamation' }
    else
        for _, item in ipairs(seeds) do
            options[#options + 1] = {
                title = ('%s x%d'):format(item.crop.label, item.count),
                description = item.seed,
                icon = 'seedling',
                onSelect = function()
                    if isBlocked() then return end
                    local anim = Config.Animations.plant
                    local ok = lib.progressBar({
                        duration = anim.duration,
                        label = anim.label,
                        useWhileDead = false,
                        canCancel = true,
                        disable = { move = true, car = true, combat = true },
                        anim = { dict = anim.dict, clip = anim.clip }
                    })
                    if ok and currentFarm then
                        local coords = GetEntityCoords(cache.ped)
                        TriggerServerEvent('amirok_farming:plantSeed', currentFarm.uuid, slotId, item.seed, { x = coords.x, y = coords.y, z = coords.z })
                    end
                end
            }
        end
    end

    lib.registerContext({ id = 'amirok_seed_select', title = 'انتخاب بذر', options = options })
    lib.showContext('amirok_seed_select')
end

local function harvestPlant(plant)
    if isBlocked() then return notify('در حالت مرگ نمی‌توانید برداشت کنید.', 'error') end
    if getGrowthPercent(plant) < 100 then return notify('گیاه هنوز رشد کامل نکرده است.', 'error') end

    local anim = Config.Animations.harvest
    local ok = lib.progressBar({
        duration = anim.duration,
        label = anim.label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = anim.dict, clip = anim.clip }
    })

    if ok and currentFarm then
        local coords = GetEntityCoords(cache.ped)
        TriggerServerEvent('amirok_farming:harvestPlant', currentFarm.uuid, plant.id, { x = coords.x, y = coords.y, z = coords.z })
    end
end

CreateThread(function()
    local blip = AddBlipForCoord(Config.Management.coords.x, Config.Management.coords.y, Config.Management.coords.z)
    SetBlipSprite(blip, Config.Management.blip.sprite)
    SetBlipColour(blip, Config.Management.blip.color)
    SetBlipScale(blip, Config.Management.blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Management.blip.label)
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while true do
        local sleep = 800
        local coords = GetEntityCoords(cache.ped)
        local dist = #(coords - Config.Management.coords)

        if dist < Config.MarkerDrawDistance and not insideFarm then
            sleep = 0
            drawMarker(Config.Management.coords)
            if dist < Config.InteractDistance then
                drawText3D(Config.Management.coords + vector3(0, 0, 0.55), '[E] مدیریت زمین')
                if IsControlJustReleased(0, 38) then openManagementMenu() end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = insideFarm and 0 or 900
        if insideFarm and currentFarm then
            local coords = GetEntityCoords(cache.ped)

            if #(coords - Config.Farm.center) > Config.Farm.radius then
                notify('از محدوده مزرعه خارج شدید.', 'error')
                SetEntityCoords(cache.ped, Config.Farm.spawn.x, Config.Farm.spawn.y, Config.Farm.spawn.z, false, false, false, true)
            end

            drawMarker(Config.Farm.exit)
            if #(coords - Config.Farm.exit) < Config.InteractDistance then
                drawText3D(Config.Farm.exit + vector3(0, 0, 0.55), '[E] خروج از مزرعه')
                if IsControlJustReleased(0, 38) then
                    if isBlocked() then notify('در حالت مرگ نمی‌توانید خارج شوید.', 'error') else
                        DoScreenFadeOut(650)
                        while not IsScreenFadedOut() do Wait(0) end
                        TriggerServerEvent('amirok_farming:exitFarm')
                    end
                end
            end

            for _, slot in ipairs(Config.FarmSlots) do
                local plant = getPlantBySlot(slot.id)
                local slotDist = #(coords - slot.coords)
                if slotDist < 18.0 then
                    drawMarker(slot.coords)
                    if plant then
                        local percent = getGrowthPercent(plant)
                        local label = percent >= 100 and ('[E] برداشت %s%%'):format(percent) or ('رشد: %s%%'):format(percent)
                        drawText3D(slot.coords + vector3(0, 0, 0.85), label)
                        if percent >= 100 and slotDist < Config.InteractDistance and IsControlJustReleased(0, 38) then
                            harvestPlant(plant)
                        end
                    else
                        drawText3D(slot.coords + vector3(0, 0, 0.45), '[E] کاشت')
                        if slotDist < Config.InteractDistance and IsControlJustReleased(0, 38) then
                            openSeedMenu(slot.id)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('amirok_farming:enteredFarm', function(farm, plants)
    currentFarm = farm
    insideFarm = true
    fadeTeleport(Config.Farm.spawn)
    rebuildPlants(plants)
end)

RegisterNetEvent('amirok_farming:enterDenied', function()
    if IsScreenFadedOut() then DoScreenFadeIn(650) end
end)

RegisterNetEvent('amirok_farming:exitedFarm', function()
    insideFarm = false
    currentFarm = nil
    currentPlants = {}
    deleteProps()
    fadeTeleport(Config.Farm.returnTo)
end)

RegisterNetEvent('amirok_farming:plantCreated', function(uuid, plant)
    if not insideFarm or not currentFarm or currentFarm.uuid ~= uuid then return end
    plant.id = tonumber(plant.id)
    plant.slot_id = tonumber(plant.slot_id)
    plant.planted_at = tonumber(plant.planted_at)
    currentPlants[plant.id] = plant
    spawnPlantProp(plant)
end)

RegisterNetEvent('amirok_farming:plantRemoved', function(uuid, plantId)
    if not insideFarm or not currentFarm or currentFarm.uuid ~= uuid then return end
    plantId = tonumber(plantId)
    if spawnedProps[plantId] and DoesEntityExist(spawnedProps[plantId]) then DeleteEntity(spawnedProps[plantId]) end
    spawnedProps[plantId] = nil
    currentPlants[plantId] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then deleteProps() end
end)
