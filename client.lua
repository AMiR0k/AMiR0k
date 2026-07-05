local ESX = exports.es_extended:getSharedObject()
local rentalZones, jobPed = {}, nil

local function notify(msg, typ) lib.notify({ description = msg, type = typ or 'inform', position = Config.Notifications.position }) end
local function addBlip(coords, data)
    if not data.enabled then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, data.sprite); SetBlipColour(blip, data.color); SetBlipScale(blip, data.scale); SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(data.label); EndTextCommandSetBlipName(blip)
end
local function drawMarkerAt(coords, marker)
    DrawMarker(marker.type, coords.x, coords.y, coords.z + 0.15, 0,0,0, 0,0,0, marker.size.x, marker.size.y, marker.size.z, marker.color.r, marker.color.g, marker.color.b, marker.color.a, false, true, 2, false, nil, nil, false)
end

local function openJobCenter()
    local info = lib.callback.await('amir0k_car_rental:server:getJobInfo', false)
    lib.registerContext({ id = 'rental_job_center', title = _L('job_center'), options = {
        { title = _L('become_owner'), description = ('Owned vehicles: %s/%s | Fee: $%s'):format(info.count, info.required, info.fee), event = 'amir0k_car_rental:client:buyJob' },
        { title = _L('owner_panel'), event = 'amir0k_car_rental:client:ownerPanel' }
    }})
    lib.showContext('rental_job_center')
end
RegisterNetEvent('amir0k_car_rental:client:buyJob', function() TriggerServerEvent('amir0k_car_rental:server:buyJob') end)

local function listVehicleMenu(locationIndex)
    local vehicles = lib.callback.await('amir0k_car_rental:server:getOwnedVehicles', false) or {}
    local opts = {}
    for _, v in ipairs(vehicles) do
        local props = json.decode(v.vehicle or '{}') or {}
        opts[#opts+1] = { title = NormalizePlate(v.plate), description = ('Model: %s'):format(props.model or 'unknown'), onSelect = function()
            local input = lib.inputDialog('Rental price', { { type = 'number', label = 'Hourly price', default = Config.Rental.defaultHourlyPrice, min = 1 } })
            if input then TriggerServerEvent('amir0k_car_rental:server:listVehicle', v.plate, locationIndex, input[1]) end
        end }
    end
    lib.registerContext({ id = 'rental_list_vehicle_' .. locationIndex, title = 'List vehicle for rent', options = opts })
    lib.showContext('rental_list_vehicle_' .. locationIndex)
end

local function rentMenu(rentalId)
    local row = lib.callback.await('amir0k_car_rental:server:getRental', false, rentalId); if not row then return notify(_L('invalid'), 'error') end
    if row.status ~= Config.Rental.status.available then return notify(_L('available_in', MinutesRemaining(row.rental_end)), 'warning') end
    local opts = {}
    for _, d in ipairs(Config.Rental.allowedDurations) do
        local total = math.ceil(row.hourly_price * (d.minutes / 60))
        opts[#opts+1] = { title = d.label, description = ('Price: $%s | Deposit: $%s'):format(total, Config.Rental.deposit.enabled and Config.Rental.deposit.amount or 0), onSelect = function()
            local pay = {}
            if Config.Rental.paymentMethods.cash then pay[#pay+1] = { title = _L('pay_cash'), serverEvent = 'amir0k_car_rental:server:rent', args = { row.id, d.minutes, 'cash' } } end
            if Config.Rental.paymentMethods.bank then pay[#pay+1] = { title = _L('pay_bank'), serverEvent = 'amir0k_car_rental:server:rent', args = { row.id, d.minutes, 'bank' } } end
            lib.registerContext({ id = 'rental_pay_' .. row.id, title = _L('select_duration'), options = pay }); lib.showContext('rental_pay_' .. row.id)
        end }
    end
    table.insert(opts, 1, { title = ('%s | %s'):format(row.model or 'Vehicle', row.plate), description = ('Owner: %s | Hourly: $%s | Max: %sh'):format(row.owner_name or 'Unknown', row.hourly_price, Config.Rental.maxHours), disabled = true })
    lib.registerContext({ id = 'rent_vehicle_' .. rentalId, title = _L('rent_vehicle'), options = opts })
    lib.showContext('rent_vehicle_' .. rentalId)
end

RegisterNetEvent('amir0k_car_rental:client:ownerPanel', function(scope)
    local rows = lib.callback.await('amir0k_car_rental:server:getRentals', false, scope == 'admin' and 'admin' or 'owner') or {}
    local opts = {}
    for _, r in ipairs(rows) do
        opts[#opts+1] = { title = ('#%s %s [%s]'):format(r.id, r.plate, r.status), description = ('Renter: %s | Remain: %sm | Revenue: $%s'):format(r.renter_name or '-', MinutesRemaining(r.rental_end), r.revenue or 0), onSelect = function()
            lib.registerContext({ id = 'rental_manage_' .. r.id, title = r.plate, options = {
                { title = 'Remove listing', serverEvent = 'amir0k_car_rental:server:remove', args = r.id },
                { title = 'Move to impound', serverEvent = 'amir0k_car_rental:server:impound', args = r.id },
                { title = 'Change hourly price', onSelect = function() local i = lib.inputDialog('Change price', { { type = 'number', label = 'Hourly price', default = r.hourly_price, min = 1 } }); if i then TriggerServerEvent('amir0k_car_rental:server:setPrice', r.id, i[1]) end end },
                { title = 'Change owner (admin)', onSelect = function() local i = lib.inputDialog('Change owner', { { type = 'input', label = 'Owner identifier', required = true } }); if i then TriggerServerEvent('amir0k_car_rental:server:setOwner', r.id, i[1]) end end }
            }}); lib.showContext('rental_manage_' .. r.id)
        end }
    end
    lib.registerContext({ id = 'rental_owner_panel', title = scope == 'admin' and 'Admin rentals' or _L('owner_panel'), options = opts })
    lib.showContext('rental_owner_panel')
end)

RegisterNetEvent('amir0k_car_rental:client:applyVehicleProps', function(netId, props)
    local veh = NetToVeh(netId); if veh ~= 0 then lib.setVehicleProperties(veh, props) end
end)
RegisterNetEvent('amir0k_car_rental:client:giveKeys', function(plate) if Config.Rental.keyExport then Config.Rental.keyExport(plate, cache.serverId) end end)
RegisterNetEvent('amir0k_car_rental:client:removeKeys', function(plate) if Config.Rental.removeKeyExport then Config.Rental.removeKeyExport(plate, cache.serverId) end end)

CreateThread(function()
    addBlip(Config.JobCenter.coords, Config.JobCenter.blip)
    if Config.JobCenter.npc.enabled then
        lib.requestModel(Config.JobCenter.npc.model)
        jobPed = CreatePed(0, Config.JobCenter.npc.model, Config.JobCenter.coords.x, Config.JobCenter.coords.y, Config.JobCenter.coords.z - 1.0, Config.JobCenter.heading, false, true)
        FreezeEntityPosition(jobPed, true); SetEntityInvincible(jobPed, true); SetBlockingOfNonTemporaryEvents(jobPed, true)
        exports.ox_target:addLocalEntity(jobPed, { { label = _L('job_center'), icon = 'fa-solid fa-car', onSelect = openJobCenter, distance = Config.JobCenter.targetDistance } })
    else
        exports.ox_target:addSphereZone({ coords = Config.JobCenter.coords, radius = Config.JobCenter.targetDistance, options = { { label = _L('job_center'), icon = 'fa-solid fa-car', onSelect = openJobCenter } } })
    end
    for i, loc in ipairs(Config.Parking.locations) do
        addBlip(vec3(loc.x, loc.y, loc.z), Config.Parking.blip)
        rentalZones[i] = exports.ox_target:addSphereZone({ coords = vec3(loc.x, loc.y, loc.z), radius = Config.Parking.targetDistance, options = { { label = 'Park rental vehicle', icon = 'fa-solid fa-square-parking', onSelect = function() listVehicleMenu(i) end } } })
    end
    exports.ox_target:addGlobalVehicle({ { label = _L('rent_vehicle'), icon = 'fa-solid fa-key', distance = 2.5, canInteract = function(entity) return Entity(entity).state.rentalId ~= nil end, onSelect = function(data) rentMenu(Entity(data.entity).state.rentalId) end } })
end)

CreateThread(function()
    while true do
        local sleep = 1000; local p = GetEntityCoords(cache.ped)
        if Config.JobCenter.marker.enabled and #(p - Config.JobCenter.coords) < Config.JobCenter.marker.drawDistance then sleep = 0; drawMarkerAt(Config.JobCenter.coords, Config.JobCenter.marker) end
        for _, loc in ipairs(Config.Parking.locations) do local c = vec3(loc.x, loc.y, loc.z); if Config.Parking.marker.enabled and #(p - c) < Config.Parking.marker.drawDistance then sleep = 0; drawMarkerAt(c, Config.Parking.marker) end end
        Wait(sleep)
    end
end)

RegisterCommand(Config.Commands.ownerPanel, function() TriggerEvent('amir0k_car_rental:client:ownerPanel') end)
RegisterCommand(Config.Commands.adminPanel, function() TriggerEvent('amir0k_car_rental:client:ownerPanel', 'admin') end)
