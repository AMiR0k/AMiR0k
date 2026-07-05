local ESX = exports.es_extended:getSharedObject()
local spawned, rentalData = {}, {}
local function L(key, ...) local locale = Locales[Config.Locale] or Locales.en; return (locale[key] or key):format(...) end
local function notify(msg, type) lib.notify({ description = msg, type = type or 'inform' }) end

local function getRemainingMinutes(rental)
    if not rental.rental_end then return 0 end
    return math.max(0, math.ceil((rental.rental_end - GetCloudTimeAsInt()) / 60))
end

local function addTarget(entity, id)
    exports.ox_target:addLocalEntity(entity, {
        {
            label = L('rent_vehicle'), icon = 'fa-solid fa-key', distance = Config.TargetDistance,
            canInteract = function() return rentalData[id] and rentalData[id].status == 'available' end,
            onSelect = function() openRentalMenu(id) end
        },
        {
            label = function() return L('available_in', getRemainingMinutes(rentalData[id] or {})) end,
            icon = 'fa-solid fa-clock', distance = Config.TargetDistance,
            canInteract = function() return rentalData[id] and rentalData[id].status == 'rented' end,
            onSelect = function() notify(L('currently_rented'), 'error') end
        }
    })
end

local function spawnRental(id, rental)
    if spawned[id] or not rental.spawn_position then return end
    local p = rental.spawn_position
    if #(GetEntityCoords(cache.ped) - vec3(p.x, p.y, p.z)) > Config.SpawnDistance then return end
    lib.requestModel(rental.vehicle.model)
    local veh = CreateVehicle(rental.vehicle.model, p.x, p.y, p.z, p.w or 0.0, false, true)
    ESX.Game.SetVehicleProperties(veh, rental.vehicle)
    SetVehicleDoorsLocked(veh, rental.status == 'available' and 2 or 1)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    spawned[id] = veh
    Entity(veh).state:set('rentcar:id', id, true)
    addTarget(veh, id)
end

local function despawnFarRentals()
    local coords = GetEntityCoords(cache.ped)
    for id, veh in pairs(spawned) do
        local rental = rentalData[id]
        if not DoesEntityExist(veh) or not rental or #(coords - GetEntityCoords(veh)) > Config.DeleteDistance then
            if DoesEntityExist(veh) then DeleteEntity(veh) end
            spawned[id] = nil
        end
    end
end

function openRentalMenu(id)
    local rental = rentalData[id]
    if not rental then return end
    local options = {{ title = rental.vehicle_label, description = ('Plate: %s\nOwner: %s\nHourly: $%s\nDeposit: $%s'):format(rental.plate, rental.owner_name, rental.price_per_hour, rental.deposit or Config.DefaultDeposit), disabled = true }}
    for _, duration in ipairs(Config.RentalDurations) do
        local price = math.floor(rental.price_per_hour * (duration.minutes / 60)) + (rental.deposit or Config.DefaultDeposit)
        options[#options + 1] = {
            title = duration.label,
            description = ('$%s total'):format(price),
            onSelect = function()
                local methods = {}
                if Config.PaymentMethods.cash then methods[#methods + 1] = { value = 'money', label = L('cash') } end
                if Config.PaymentMethods.bank then methods[#methods + 1] = { value = 'bank', label = L('bank') } end
                local input = lib.inputDialog(L('rental_info'), {{ type = 'select', label = 'Payment', options = methods, required = true }})
                if input then lib.callback.await('amir0k_rentcar:server:rentVehicle', false, id, duration.minutes, input[1]) end
            end
        }
    end
    lib.registerContext({ id = 'rentcar_rent_' .. id, title = L('rental_info'), options = options })
    lib.showContext('rentcar_rent_' .. id)
end

RegisterNetEvent('amir0k_rentcar:client:syncRentals', function(data) rentalData = data or {} end)
RegisterNetEvent('amir0k_rentcar:client:upsertRental', function(rental) rentalData[rental.id] = rental end)
RegisterNetEvent('amir0k_rentcar:client:removeRental', function(id) rentalData[id] = nil end)
RegisterNetEvent('amir0k_rentcar:client:deleteRentalEntity', function(id) if spawned[id] and DoesEntityExist(spawned[id]) then DeleteEntity(spawned[id]) end spawned[id] = nil end)
RegisterNetEvent('amir0k_rentcar:client:rentalStarted', function(id) if spawned[id] then SetVehicleDoorsLocked(spawned[id], 1); SetVehicleDoorsLockedForPlayer(spawned[id], PlayerId(), false) end end)

RegisterNetEvent('amir0k_rentcar:client:rentalExpired', function(id, renterIdentifier)
    local rental = rentalData[id]
    if not rental then return end
    if spawned[id] and cache.vehicle == spawned[id] then
        notify(Config.Notifications.expired, 'warning')
        CreateThread(function()
            while cache.vehicle == spawned[id] do Wait(Config.RenterExitCheckSeconds * 1000) end
            TriggerServerEvent('amir0k_rentcar:server:finishAfterExit', id)
        end)
    else
        TriggerServerEvent('amir0k_rentcar:server:finishAfterExit', id)
    end
end)

CreateThread(function()
    rentalData = lib.callback.await('amir0k_rentcar:server:getRentals', false) or {}
    lib.zones.box({
        coords = Config.JobCenter.coords, size = Config.JobCenter.size, rotation = Config.JobCenter.rotation,
        onEnter = function() lib.showTextUI('[E] Join Rent Car Job') end,
        onExit = function() lib.hideTextUI() end,
        inside = function() if IsControlJustReleased(0, 38) then lib.callback.await('amir0k_rentcar:server:joinJob', false) end end
    })
    while true do
        Wait(2500)
        for id, rental in pairs(rentalData) do spawnRental(id, rental) end
        despawnFarRentals()
    end
end)

RegisterCommand('rentlistvehicle', function()
    local veh = cache.vehicle
    if not veh then return notify(Config.Notifications.positionVehicle, 'error') end
    local coords = GetEntityCoords(veh)
    local nearest, dist
    for _, lot in ipairs(Config.RentalLots) do
        local d = #(coords - vec3(lot.coords.x, lot.coords.y, lot.coords.z))
        if not dist or d < dist then nearest, dist = lot, d end
    end
    if not nearest or dist > 6.0 then return notify(Config.Notifications.positionVehicle, 'error') end
    local props = ESX.Game.GetVehicleProperties(veh)
    local input = lib.inputDialog('List rental vehicle', {
        { type = 'number', label = 'Price per hour', default = Config.DefaultPricePerHour, required = true, min = 1 },
        { type = 'input', label = 'Vehicle label', default = GetDisplayNameFromVehicleModel(props.model) }
    })
    if input then TriggerServerEvent('amir0k_rentcar:server:listVehicle', props.plate, props, nearest.id, input[1], input[2]); DeleteEntity(veh) end
end, false)

RegisterNetEvent('amir0k_rentcar:client:openOwnerPanel', function(data)
    local opts = {}
    for id, r in pairs(data) do opts[#opts+1] = { title = ('%s [%s]'):format(r.vehicle_label, r.plate), description = ('%s | %s: $%s'):format(r.status, L('revenue'), r.revenue or 0), onSelect = function() TriggerServerEvent('amir0k_rentcar:server:ownerAction', id, 'impound') end } end
    lib.registerContext({ id = 'rentcar_owner', title = L('owner_panel'), options = opts }) lib.showContext('rentcar_owner')
end)

RegisterNetEvent('amir0k_rentcar:client:openAdminPanel', function(data)
    local opts = {}
    for id, r in pairs(data) do opts[#opts+1] = { title = ('#%s %s [%s]'):format(id, r.vehicle_label, r.status), description = r.owner_identifier, onSelect = function() TriggerServerEvent('amir0k_rentcar:server:adminAction', id, 'impound') end } end
    lib.registerContext({ id = 'rentcar_admin', title = L('admin_panel'), options = opts }) lib.showContext('rentcar_admin')
end)
