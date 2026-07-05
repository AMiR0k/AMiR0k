local ESX = exports.es_extended:getSharedObject()
local spawned = {}

local function notify(src, msg, typ) TriggerClientEvent('ox_lib:notify', src, { description = msg, type = typ or 'inform', position = Config.Notifications.position }) end
local function ident(xPlayer) return xPlayer and xPlayer.identifier end
local function isAdmin(xPlayer) return xPlayer and Config.AdminGroups[xPlayer.getGroup()] == true end
local function decodeVehicle(v) return type(v) == 'table' and v or json.decode(v or '{}') end
local function encodeCoords(v) return json.encode({ x = v.x, y = v.y, z = v.z, w = v.w }) end
local function onlineByIdentifier(identifier) for _, id in ipairs(ESX.GetPlayers()) do local x = ESX.GetPlayerFromId(id); if x and x.identifier == identifier then return x end end end

local function setGarageState(plate, state)
    MySQL.update.await('UPDATE owned_vehicles SET stored = ?, parking = NULL WHERE plate = ?', { state, NormalizePlate(plate) })
end

local function spawnRental(row)
    local pos = json.decode(row.spawn_position)
    local props = decodeVehicle(row.vehicle)
    local model = props.model or joaat(row.model or 'adder')
    local veh = CreateVehicle(model, pos.x, pos.y, pos.z, pos.w or 0.0, true, true)
    if not veh or veh == 0 then return end
    while not DoesEntityExist(veh) do Wait(0) end
    Entity(veh).state:set('rentalId', row.id, true)
    Entity(veh).state:set('rentalStatus', row.status, true)
    SetVehicleNumberPlateText(veh, row.plate)
    spawned[row.id] = NetworkGetNetworkIdFromEntity(veh)
    MySQL.update('UPDATE car_rentals SET entity_net_id = ? WHERE id = ?', { spawned[row.id], row.id })
    TriggerClientEvent('amir0k_car_rental:client:applyVehicleProps', -1, spawned[row.id], props)
end

local function deleteRentalEntity(id)
    local net = spawned[id]
    if net then local ent = NetworkGetEntityFromNetworkId(net); if ent and ent ~= 0 then DeleteEntity(ent) end end
    spawned[id] = nil
end

local function expireRental(row)
    deleteRentalEntity(row.id)
    setGarageState(row.plate, Config.Rental.impoundState)
    if row.renter_identifier then local renter = onlineByIdentifier(row.renter_identifier); if renter then TriggerClientEvent('amir0k_car_rental:client:removeKeys', renter.source, row.plate); notify(renter.source, _L('expired'), 'warning') end end
    MySQL.update.await('UPDATE car_rentals SET renter_identifier = NULL, renter_name = NULL, rental_start = NULL, rental_end = NULL, status = ?, entity_net_id = NULL WHERE id = ?', { Config.Rental.status.available, row.id })
    row.status = Config.Rental.status.available; row.renter_identifier = nil; row.rental_end = nil
    spawnRental(row)
end

CreateThread(function()
    Wait(1000)
    local rows = MySQL.query.await('SELECT * FROM car_rentals WHERE status IN (?, ?)', { Config.Rental.status.available, Config.Rental.status.rented }) or {}
    for _, row in ipairs(rows) do if row.status == Config.Rental.status.rented and tonumber(row.rental_end or 0) <= os.time() then expireRental(row) else spawnRental(row) end end
    while true do
        Wait(60000)
        local expired = MySQL.query.await('SELECT * FROM car_rentals WHERE status = ? AND rental_end IS NOT NULL AND rental_end <= ?', { Config.Rental.status.rented, os.time() }) or {}
        for _, row in ipairs(expired) do expireRental(row) end
    end
end)

lib.callback.register('amir0k_car_rental:server:getJobInfo', function(source)
    local x = ESX.GetPlayerFromId(source); if not x then return end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM owned_vehicles WHERE owner = ?', { x.identifier }) or 0
    return { count = count, required = Config.JobRequirements.minimumOwnedVehicles, fee = Config.JobRequirements.licenseFee, job = x.job and x.job.name }
end)

RegisterNetEvent('amir0k_car_rental:server:buyJob', function()
    local src = source; local x = ESX.GetPlayerFromId(src); if not x then return end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM owned_vehicles WHERE owner = ?', { x.identifier }) or 0
    if count < Config.JobRequirements.minimumOwnedVehicles then return notify(src, _L('need_vehicles', Config.JobRequirements.minimumOwnedVehicles), 'error') end
    local fee, account = Config.JobRequirements.licenseFee, Config.JobRequirements.paymentAccount
    if x.getAccount(account).money < fee then return notify(src, _L('not_enough_money'), 'error') end
    x.removeAccountMoney(account, fee, 'car-rental-license')
    x.setJob(Config.JobName, Config.JobGrade)
    notify(src, _L('job_success'), 'success')
end)

lib.callback.register('amir0k_car_rental:server:getOwnedVehicles', function(source)
    local x = ESX.GetPlayerFromId(source); if not x or x.job.name ~= Config.JobName then return {} end
    return MySQL.query.await('SELECT plate, vehicle FROM owned_vehicles WHERE owner = ? AND stored = ?', { x.identifier, Config.Rental.garageState }) or {}
end)

RegisterNetEvent('amir0k_car_rental:server:listVehicle', function(plate, locationIndex, hourlyPrice)
    local src = source; local x = ESX.GetPlayerFromId(src); if not x or x.job.name ~= Config.JobName then return notify(src, _L('not_owner_job'), 'error') end
    plate = NormalizePlate(plate); local loc = Config.Parking.locations[tonumber(locationIndex or 0)]; if not loc then return notify(src, _L('invalid'), 'error') end
    if MySQL.scalar.await('SELECT id FROM car_rentals WHERE plate = ? AND status IN (?, ?)', { plate, Config.Rental.status.available, Config.Rental.status.rented }) then return notify(src, _L('already_listed'), 'error') end
    if MySQL.scalar.await('SELECT id FROM car_rentals WHERE location_index = ? AND status IN (?, ?)', { locationIndex, Config.Rental.status.available, Config.Rental.status.rented }) then return notify(src, _L('parking_busy'), 'error') end
    local owned = MySQL.single.await('SELECT vehicle FROM owned_vehicles WHERE owner = ? AND plate = ?', { x.identifier, plate }); if not owned then return notify(src, _L('not_your_vehicle'), 'error') end
    setGarageState(plate, Config.Rental.rentalState)
    local id = MySQL.insert.await('INSERT INTO car_rentals (owner_identifier, owner_name, plate, vehicle, model, location_index, spawn_position, hourly_price, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { x.identifier, x.getName(), plate, owned.vehicle, tostring(decodeVehicle(owned.vehicle).model or ''), locationIndex, encodeCoords(loc), tonumber(hourlyPrice) or Config.Rental.defaultHourlyPrice, Config.Rental.status.available })
    local row = MySQL.single.await('SELECT * FROM car_rentals WHERE id = ?', { id }); spawnRental(row); notify(src, _L('listed'), 'success')
end)

lib.callback.register('amir0k_car_rental:server:getRentals', function(source, scope)
    local x = ESX.GetPlayerFromId(source); if not x then return {} end
    if scope == 'admin' and isAdmin(x) then return MySQL.query.await('SELECT * FROM car_rentals ORDER BY id DESC') or {} end
    return MySQL.query.await('SELECT * FROM car_rentals WHERE owner_identifier = ? ORDER BY id DESC', { x.identifier }) or {}
end)

lib.callback.register('amir0k_car_rental:server:getRental', function(_, id) return MySQL.single.await('SELECT * FROM car_rentals WHERE id = ?', { id }) end)

RegisterNetEvent('amir0k_car_rental:server:rent', function(id, minutes, method)
    if type(id) == 'table' then id, minutes, method = id[1], id[2], id[3] end
    local src = source; local x = ESX.GetPlayerFromId(src); if not x then return end
    if not Config.Rental.paymentMethods[method] then return notify(src, _L('invalid'), 'error') end
    local row = MySQL.single.await('SELECT * FROM car_rentals WHERE id = ? AND status = ?', { id, Config.Rental.status.available }); if not row then return notify(src, _L('invalid'), 'error') end
    minutes = tonumber(minutes); local ok=false; for _, d in ipairs(Config.Rental.allowedDurations) do if d.minutes == minutes then ok=true end end; if not ok then return notify(src, _L('invalid'), 'error') end
    local total = math.ceil(row.hourly_price * (minutes / 60)); local deposit = Config.Rental.deposit.enabled and Config.Rental.deposit.amount or 0; local charge = total + deposit
    if method == 'cash' then if x.getMoney() < charge then return notify(src, _L('not_enough_money'), 'error') end; x.removeMoney(charge, 'car-rental') else if x.getAccount('bank').money < charge then return notify(src, _L('not_enough_money'), 'error') end; x.removeAccountMoney('bank', charge, 'car-rental') end
    local commission = math.floor(total * Config.Rental.commissionPercent / 100); local tax = math.floor(total * Config.Rental.taxPercent / 100); local net = total - commission - tax
    local owner = onlineByIdentifier(row.owner_identifier); if owner then owner.addAccountMoney(Config.Rental.ownerRevenueAccount, net, 'car-rental-revenue') end
    MySQL.update.await('UPDATE car_rentals SET renter_identifier=?, renter_name=?, rental_start=?, rental_end=?, status=?, total_price=?, deposit=?, revenue=revenue+?, unclaimed_revenue=unclaimed_revenue+?, commission=?, tax=?, net_revenue=net_revenue+? WHERE id=?', { x.identifier, x.getName(), os.time(), os.time() + (minutes * 60), Config.Rental.status.rented, total, deposit, total, owner and 0 or net, commission, tax, net, id })
    local ent = NetworkGetEntityFromNetworkId(spawned[id] or row.entity_net_id or 0); if ent and ent ~= 0 then Entity(ent).state:set('rentalStatus', Config.Rental.status.rented, true); SetVehicleDoorsLocked(ent, 1) end
    TriggerClientEvent('amir0k_car_rental:client:giveKeys', src, row.plate); notify(src, _L('paid_success'), 'success')
end)

RegisterNetEvent('amir0k_car_rental:server:impound', function(id)
    if type(id) == 'table' then id = id[1] end
    local src = source; local x = ESX.GetPlayerFromId(src); local row = MySQL.single.await('SELECT * FROM car_rentals WHERE id=?', { id }); if not x or not row or (row.owner_identifier ~= x.identifier and not isAdmin(x)) then return notify(src, _L('no_access'), 'error') end
    deleteRentalEntity(id); setGarageState(row.plate, Config.Rental.impoundState); MySQL.update.await('UPDATE car_rentals SET status=?, entity_net_id=NULL WHERE id=?', { Config.Rental.status.impounded, id }); notify(src, _L('impounded'), 'success')
end)

RegisterNetEvent('amir0k_car_rental:server:remove', function(id)
    if type(id) == 'table' then id = id[1] end
    local src = source; local x = ESX.GetPlayerFromId(src); local row = MySQL.single.await('SELECT * FROM car_rentals WHERE id=?', { id }); if not x or not row or row.status == Config.Rental.status.rented or (row.owner_identifier ~= x.identifier and not isAdmin(x)) then return notify(src, _L('no_access'), 'error') end
    deleteRentalEntity(id); setGarageState(row.plate, Config.Rental.garageState); MySQL.update.await('UPDATE car_rentals SET status=?, entity_net_id=NULL WHERE id=?', { Config.Rental.status.cancelled, id }); notify(src, _L('removed'), 'success')
end)

RegisterNetEvent('amir0k_car_rental:server:setPrice', function(id, price)
    if type(id) == 'table' then id, price = id[1], id[2] end
    local src = source; local x = ESX.GetPlayerFromId(src); local row = MySQL.single.await('SELECT * FROM car_rentals WHERE id=?', { id })
    if not x or not row or (row.owner_identifier ~= x.identifier and not isAdmin(x)) then return notify(src, _L('no_access'), 'error') end
    price = tonumber(price); if not price or price < 1 then return notify(src, _L('invalid'), 'error') end
    MySQL.update.await('UPDATE car_rentals SET hourly_price=? WHERE id=?', { price, id }); notify(src, _L('price_changed'), 'success')
end)

RegisterNetEvent('amir0k_car_rental:server:setOwner', function(id, identifier)
    if type(id) == 'table' then id, identifier = id[1], id[2] end
    local src = source; local x = ESX.GetPlayerFromId(src); if not isAdmin(x) or type(identifier) ~= 'string' then return notify(src, _L('no_access'), 'error') end
    local target = onlineByIdentifier(identifier)
    MySQL.update.await('UPDATE car_rentals SET owner_identifier=?, owner_name=? WHERE id=?', { identifier, target and target.getName() or identifier, id }); notify(src, _L('owner_changed'), 'success')
end)
